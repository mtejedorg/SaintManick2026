extends "res://tests/framework/test_case.gd"

# G4: the first wave (ZoneEncounter) and the elevator start (ElevatorEncounter) are
# deferred out of the body_entered callback. A respawn reset landing in the same frame
# used to let the deferred call run anyway, leaving an orphan wave on an inactive encounter.

var dummy_enemy_scene: PackedScene
var mock_player: PlayerController

func before_each() -> void:
	var node := Node3D.new()
	dummy_enemy_scene = PackedScene.new()
	dummy_enemy_scene.pack(node)
	node.free()
	mock_player = PlayerController.new()

func after_each() -> void:
	super.after_each()
	if is_instance_valid(mock_player):
		mock_player.free()

func _make_wave() -> WaveDef:
	var wave := WaveDef.new()
	var enemies: Array[PackedScene] = [dummy_enemy_scene]
	wave.enemies = enemies
	return wave

func test_respawn_in_the_activation_frame_cancels_the_deferred_first_wave() -> void:
	var spawner := WaveSpawner.new()
	add_child(spawner)
	var encounter := ZoneEncounter.new()
	encounter.spawner = spawner
	var waves: Array[WaveDef] = [_make_wave()]
	encounter.waves = waves
	add_child(encounter)

	encounter._on_body_entered(mock_player)
	assert_true(encounter.active, "Precondition: the encounter activated")
	SignalBus.player_respawned.emit() # same frame, before the deferred spawn runs
	await get_tree().process_frame

	assert_true(spawner.active_enemies.is_empty(), "A stale deferred spawn must not place an orphan wave")
	assert_false(encounter.active, "The respawn reset leaves the encounter inactive and re-armed")

	encounter.free()
	spawner.free()

func test_respawn_in_the_boarding_frame_cancels_the_deferred_elevator_start() -> void:
	var platform := AnimatableBody3D.new()
	platform.sync_to_physics = false
	var spawner := WaveSpawner.new()
	var trigger := Area3D.new()
	var elevator := ElevatorEncounter.new()
	elevator.platform = platform
	elevator.spawner = spawner
	elevator.entry_trigger = trigger
	var waves: Array[WaveDef] = [_make_wave()]
	elevator.waves = waves
	add_child(platform)
	add_child(spawner)
	add_child(trigger)
	add_child(elevator)

	elevator._on_entry_trigger_entered(mock_player)
	SignalBus.player_respawned.emit() # same frame, before the deferred start runs
	await get_tree().process_frame

	assert_false(elevator.is_active, "A stale deferred start must leave the elevator idle")
	assert_true(spawner.active_enemies.is_empty(), "No wave may spawn from a stale start")
	assert_true(trigger.monitoring, "The entry trigger must be re-armed so Nick can board again")

	elevator.free()
	trigger.free()
	spawner.free()
	platform.free()
