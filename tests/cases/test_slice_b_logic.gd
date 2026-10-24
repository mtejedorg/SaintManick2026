extends "res://tests/framework/test_case.gd"

const EscapeSequence = preload("res://levels/components/escape_sequence.gd")
const EscapeKillWall = preload("res://levels/components/escape_kill_wall.gd")
const EscapeDoorHazard = preload("res://levels/components/escape_door_hazard.gd")
const ElevatorEncounter = preload("res://levels/components/elevator_encounter.gd")

var dummy_enemy_scene: PackedScene

func before_each() -> void:
	var node = Node3D.new()
	dummy_enemy_scene = PackedScene.new()
	dummy_enemy_scene.pack(node)
	node.free()

func test_flow_rewire() -> void:
	var enforcer = EnforcerEnemy.new()
	var mock_stats = EnemyStats.new()
	mock_stats.scrap = 50
	enforcer.stats = mock_stats
	
	GameManager.scrap = 0
	GameManager.is_test = true
	
	var flags = {"miniboss_defeated": false}
	var connection = func(): flags.miniboss_defeated = true
	SignalBus.miniboss_defeated.connect(connection)
	
	enforcer._on_died()
	
	assert_true(flags.miniboss_defeated, "miniboss_defeated signal should be emitted")
	assert_eq(GameManager.scrap, 50, "Should add scrap from enforcer stats")
	
	SignalBus.miniboss_defeated.disconnect(connection)
	enforcer.free()

func test_escape_activation() -> void:
	var escape_seq = EscapeSequence.new()
	var path_z8 = Path3D.new()
	var kill_wall = Node3D.new()
	
	var wall_script = GDScript.new()
	wall_script.source_code = "extends Node3D\nvar is_moving = false\nfunc start_moving(): is_moving = true"
	wall_script.reload()
	kill_wall.set_script(wall_script)
	
	escape_seq.path_z8 = path_z8
	escape_seq.kill_wall = kill_wall
	
	add_child(escape_seq)
	add_child(path_z8)
	add_child(kill_wall)
	
	var camera_shift_flags = {"called": false, "top_down": true, "path": null}
	var camera_connection = func(top_down, path, transition_time):
		camera_shift_flags.called = true
		camera_shift_flags.top_down = top_down
		camera_shift_flags.path = path
	SignalBus.camera_shift_requested.connect(camera_connection)
	
	SignalBus.miniboss_defeated.emit()
	
	assert_true(escape_seq.is_active, "Escape sequence should be active")
	assert_true(camera_shift_flags.called, "Camera shift should be requested")
	assert_false(camera_shift_flags.top_down, "Camera shift should not be top-down")
	assert_eq(camera_shift_flags.path, path_z8, "Camera shift path should be path_z8")
	assert_true(kill_wall.is_moving, "Kill wall should start moving")
	
	SignalBus.camera_shift_requested.disconnect(camera_connection)
	escape_seq.queue_free()
	path_z8.queue_free()
	kill_wall.queue_free()

func test_escape_hazards_damage_non_instant() -> void:
	var kill_wall = EscapeKillWall.new()
	kill_wall.damage = 15.0
	add_child(kill_wall)
	
	var player_scene = load("res://characters/player/player.tscn")
	var player = player_scene.instantiate()
	add_child(player)
	
	var player_health = player.health_component
	player_health.max_health = 100.0
	player_health.current_health = 100.0
	player_health.max_shield = 40.0
	player_health.current_shield = 40.0
	
	# Simulate player entering the kill wall area
	kill_wall._on_body_entered(player)
	
	assert_eq(player_health.current_shield, 25.0, "Shield should absorb 15 damage")
	assert_eq(player_health.current_health, 100.0, "Health should remain untouched")
	
	# Simulate a beat trigger
	kill_wall._on_beat("primary", 1)
	assert_eq(player_health.current_shield, 10.0, "Shield should absorb another 15 damage on beat")
	
	kill_wall._on_body_exited(player)
	
	var door_hazard = EscapeDoorHazard.new()
	door_hazard.damage = 12.0
	add_child(door_hazard)
	
	assert_not_null(door_hazard.hitbox, "Hitbox should be created")
	
	var damage_info = door_hazard.hitbox.damage_info
	assert_eq(damage_info.amount, 12.0, "Door hazard damage should be configured on hitbox")
	
	player_health.take_damage(damage_info)
	assert_eq(player_health.current_shield, 0.0, "Shield should be depleted")
	assert_eq(player_health.current_health, 98.0, "Health should absorb the spillover")
	
	kill_wall.queue_free()
	door_hazard.queue_free()
	player.queue_free()

func test_elevator_encounter_movement_and_wave_cooldown() -> void:
	var elevator = ElevatorEncounter.new()
	var platform = AnimatableBody3D.new()
	platform.sync_to_physics = false
	var spawner = WaveSpawner.new()
	
	elevator.platform = platform
	elevator.spawner = spawner
	elevator.speed = 10.0
	elevator.target_y = 5.0
	elevator.wave_cooldown = 0.5
	
	var wave1 = WaveDef.new()
	var enemies1: Array[PackedScene] = [dummy_enemy_scene]
	wave1.enemies = enemies1
	var wave2 = WaveDef.new()
	var enemies2: Array[PackedScene] = [dummy_enemy_scene]
	wave2.enemies = enemies2
	var waves_list: Array[WaveDef] = [wave1, wave2]
	elevator.waves = waves_list
	
	add_child(elevator)
	add_child(platform)
	add_child(spawner)
	
	assert_false(elevator.is_active, "Elevator should not be active initially")
	assert_eq(platform.position.y, 0.0, "Platform Y should be 0")
	
	elevator.start_encounter()
	assert_true(elevator.is_active, "Elevator should be active after start")
	assert_eq(elevator.current_wave_index, 0, "Current wave index should be 0")
	
	elevator._physics_process(0.1)
	assert_gt(platform.position.y, 0.0, "Platform Y should have increased")
	assert_eq(platform.position.y, 1.0, "Platform Y should increase by speed * delta")
	
	# Simulate clearing the spawned enemies
	for enemy in spawner.active_enemies:
		spawner._on_enemy_defeated(enemy)
		
	assert_eq(elevator.current_wave_index, 1, "Should advance to wave 1")
	assert_true(elevator.is_cooldown, "Should enter cooldown after wave clear")
	assert_eq(elevator.cooldown_timer, 0.5, "Cooldown timer should be set")
	
	elevator._physics_process(0.3)
	assert_true(elevator.is_cooldown, "Should still be in cooldown after 0.3s")
	
	elevator._physics_process(0.25)
	assert_false(elevator.is_cooldown, "Should exit cooldown after total 0.55s")
	
	elevator.queue_free()
	platform.queue_free()
	spawner.queue_free()

func test_elevator_completion() -> void:
	var elevator = ElevatorEncounter.new()
	var platform = AnimatableBody3D.new()
	platform.sync_to_physics = false
	var spawner = WaveSpawner.new()
	
	elevator.platform = platform
	elevator.spawner = spawner
	elevator.speed = 10.0
	elevator.target_y = 5.0
	elevator.wave_cooldown = 0.0
	
	var wave1 = WaveDef.new()
	var enemies1: Array[PackedScene] = [dummy_enemy_scene]
	wave1.enemies = enemies1
	var waves_list: Array[WaveDef] = [wave1]
	elevator.waves = waves_list
	
	add_child(elevator)
	add_child(platform)
	add_child(spawner)
	
	var flags = {"completed": false}
	var connection = func(): flags.completed = true
	elevator.encounter_completed.connect(connection)
	
	elevator.start_encounter()
	
	elevator._physics_process(0.6)
	assert_eq(platform.position.y, 5.0, "Platform should stop rising at target_y")
	assert_false(flags.completed, "Encounter should not complete because waves remain")
	
	# Clear the remaining wave
	for enemy in spawner.active_enemies:
		spawner._on_enemy_defeated(enemy)
		
	assert_true(flags.completed, "Encounter should complete now")
	assert_false(elevator.is_active, "Elevator should no longer be active")
	
	flags.completed = false
	platform.position.y = 0.0
	elevator.current_wave_index = 0
	elevator.start_encounter()
	
	# Clear wave immediately
	for enemy in spawner.active_enemies:
		spawner._on_enemy_defeated(enemy)
		
	assert_eq(elevator.current_wave_index, 1, "All waves cleared")
	assert_false(flags.completed, "Encounter should not complete because platform is not at top")
	
	elevator._physics_process(0.6)
	assert_eq(platform.position.y, 5.0, "Platform reached top")
	assert_true(flags.completed, "Encounter should complete upon reaching top since waves are cleared")
	
	elevator.encounter_completed.disconnect(connection)
	elevator.queue_free()
	platform.queue_free()
	spawner.queue_free()

# C6: the door telegraphs its slam with a one-beat emission flash.
func test_door_flashes_one_beat_before_closing() -> void:
	var door = EscapeDoorHazard.new()
	door.close_beat_interval = 4
	var body := CSGBox3D.new()
	body.name = "DoorBody"
	var mat := StandardMaterial3D.new()
	mat.emission_enabled = true
	mat.emission = Color(1.0, 0.352941, 0.0)
	mat.emission_energy_multiplier = 2.0
	body.material = mat
	door.add_child(body)
	add_child(door)

	door._on_beat("primary", 1) # counter 1
	door._on_beat("primary", 2) # counter 2
	assert_false(door.is_warning, "No flash early in the cycle")
	door._on_beat("primary", 3) # counter 3 == interval - 1: the pre-close beat
	assert_true(door.is_warning, "The beat before the slam flashes the door")
	var live: StandardMaterial3D = body.material
	assert_eq(live.emission, door.warn_color, "Flash colour is #FF1E5A")
	assert_almost_eq(live.emission_energy_multiplier, 3.0, 0.001, "Flash energy is x3")
	assert_eq(mat.emission_energy_multiplier, 2.0, "The shared source material is never mutated")
	door._on_beat("primary", 4) # counter 0: slam
	assert_false(door.is_warning, "The flash ends when the door closes")
	assert_true(door.is_closed, "The door closes right after the flash beat")
	assert_almost_eq(live.emission_energy_multiplier, 2.0, 0.001, "Glow returns to rest")
	door.queue_free()
