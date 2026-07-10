extends "res://tests/framework/test_case.gd"

## Mocks the Enforcer's dormancy contract (a scene-root property named "is_active")
## so the dormant-exclusion test can attach a real Hurtbox3D under a node shaped like
## the real miniboss without dragging in the full enforcer.gd scene/state machine.
class MockDormantMinibossOwner extends Node3D:
	var is_active: bool = false

## Mocks the Headliner's dormancy contract (a scene-root property named "is_active_boss").
class MockDormantBossOwner extends Node3D:
	var is_active_boss: bool = false

var controller: IntensityController
var original_target_bpm: float
var created_enemies: Array[Node] = []

func before_each() -> void:
	if Conductor:
		original_target_bpm = Conductor.target_bpm
	
	var controller_script = load("res://_core/intensity_controller.gd")
	controller = controller_script.new()
	add_child(controller)

func after_each() -> void:
	for enemy in created_enemies:
		if is_instance_valid(enemy):
			enemy.free()
	created_enemies.clear()
	
	if is_instance_valid(controller):
		controller.free()
		controller = null
		
	if Conductor:
		Conductor.target_bpm = original_target_bpm
	super()

func create_mock_enemy(hp: float = 100.0) -> Node:
	var mock_health = HealthComponent.new()
	mock_health.max_health = 100.0
	mock_health.current_health = hp
	
	var mock_hurtbox = Hurtbox3D.new()
	mock_hurtbox.health_component = mock_health
	mock_hurtbox.add_child(mock_health)
	
	add_child(mock_hurtbox)
	created_enemies.append(mock_hurtbox)
	return mock_hurtbox

## Builds a Hurtbox3D parented under (and owned by) a dormancy-flagged mock scene root,
## mirroring how Hurtbox3D.owner actually resolves for Enforcer/Headliner in the real scene.
func create_dormant_hurtbox(owner_node: Node3D, hp: float = 100.0) -> Hurtbox3D:
	add_child(owner_node)
	created_enemies.append(owner_node)

	var mock_health = HealthComponent.new()
	mock_health.max_health = 100.0
	mock_health.current_health = hp

	var mock_hurtbox = Hurtbox3D.new()
	mock_hurtbox.health_component = mock_health
	mock_hurtbox.add_child(mock_health)

	owner_node.add_child(mock_hurtbox)
	mock_hurtbox.owner = owner_node
	created_enemies.append(mock_hurtbox)
	return mock_hurtbox

func test_tempo_boost_calculations() -> void:
	# 0 enemies
	controller.update_tempo()
	assert_eq(Conductor.target_bpm, 128.0, "BPM should be base_bpm (128.0) with 0 enemies")
	
	# 1 enemy
	var enemy1 = create_mock_enemy(100.0)
	controller.update_tempo()
	assert_eq(Conductor.target_bpm, 130.0, "BPM should be 130.0 with 1 active enemy")
	
	# 2 enemies
	var enemy2 = create_mock_enemy(50.0)
	controller.update_tempo()
	assert_eq(Conductor.target_bpm, 132.0, "BPM should be 132.0 with 2 active enemies")
	
	# 1 dead enemy
	enemy2.health_component.current_health = 0.0
	controller.update_tempo()
	assert_eq(Conductor.target_bpm, 130.0, "BPM should drop back to 130.0 if one enemy dies")

func test_tempo_boost_clamp_limit() -> void:
	# Add 10 enemies -> boost should be min(10 * 2.0, 16.0) = 16.0. target_bpm = 128.0 + 16.0 = 144.0
	for i in range(10):
		create_mock_enemy(100.0)
	controller.update_tempo()
	assert_eq(Conductor.target_bpm, 144.0, "BPM should clamp to 144.0 (max boost of 16.0)")

func test_boss_suspension_logic() -> void:
	var enemy = create_mock_enemy(100.0)
	controller.update_tempo()
	assert_eq(Conductor.target_bpm, 130.0)
	
	# Spawn boss -> should suspend
	SignalBus.boss_spawned.emit("Enforcer")
	
	# Manually set Conductor target_bpm to a custom boss tempo (e.g. 150.0)
	Conductor.target_bpm = 150.0
	
	# Trigger a beat or manual update, Conductor target_bpm should NOT be overwritten
	SignalBus.beat.emit("primary", 1)
	assert_eq(Conductor.target_bpm, 150.0, "Conductor target_bpm should remain at custom boss tempo while boss is active")
	
	controller.update_tempo()
	assert_eq(Conductor.target_bpm, 150.0, "Conductor target_bpm should remain at custom boss tempo even on explicit update")
	
	# Add another enemy, should still remain unchanged
	var enemy2 = create_mock_enemy(100.0)
	controller.update_tempo()
	assert_eq(Conductor.target_bpm, 150.0)
	
	# Boss dies -> should resume and immediately re-evaluate
	SignalBus.boss_died.emit()
	assert_eq(Conductor.target_bpm, 132.0, "Conductor target_bpm should immediately update after boss dies")
	
	# Check boss reset suspension
	SignalBus.boss_spawned.emit("Headliner")
	Conductor.target_bpm = 160.0
	
	# Boss reset -> should resume and immediately re-evaluate
	SignalBus.boss_reset.emit()
	assert_eq(Conductor.target_bpm, 132.0, "Conductor target_bpm should immediately update after boss resets")

## Regression coverage for the scene-load inflation bug: the vertical slice's RhythmEnforcer
## and Headliner both sit dormant in "enemy_hurtbox" from the moment the scene loads (they
## activate on zone-07 entry / activate_boss() respectively). Uncounted-for, they would add
## +2 to the active count (and +4 BPM) permanently, so the game would never rest at base_bpm.
func test_dormant_boss_and_miniboss_hurtboxes_excluded_from_count() -> void:
	create_dormant_hurtbox(MockDormantMinibossOwner.new())
	create_dormant_hurtbox(MockDormantBossOwner.new())

	assert_eq(controller.get_active_enemy_count(), 0, "Dormant boss/miniboss hurtboxes must not count as active enemies")

	controller.update_tempo()
	assert_eq(Conductor.target_bpm, 128.0, "BPM must rest at base_bpm while only dormant bosses are present in the scene")

	# A real active enemy dropped in alongside the dormant bosses should still register.
	create_mock_enemy(100.0)
	controller.update_tempo()
	assert_eq(Conductor.target_bpm, 130.0, "An active regular enemy should still register normally alongside dormant bosses")
