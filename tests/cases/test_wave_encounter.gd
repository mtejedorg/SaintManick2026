extends "res://tests/framework/test_case.gd"

var spawner: WaveSpawner
var encounter: ZoneEncounter
var mock_player: PlayerController
var dummy_enemy_scene: PackedScene

func before_each() -> void:
	var node = Node3D.new()
	dummy_enemy_scene = PackedScene.new()
	var err = dummy_enemy_scene.pack(node)
	node.free()
	
	spawner = WaveSpawner.new()
	encounter = ZoneEncounter.new()
	mock_player = PlayerController.new()

func after_each() -> void:
	if is_instance_valid(spawner):
		spawner.queue_free()
	if is_instance_valid(encounter):
		encounter.queue_free()
	if is_instance_valid(mock_player):
		mock_player.free()

func test_wave_spawner_clears_wave_on_enemy_tree_exit() -> void:
	add_child(spawner)
	
	var wave_def = WaveDef.new()
	var enemies_list: Array[PackedScene] = [dummy_enemy_scene, dummy_enemy_scene]
	wave_def.enemies = enemies_list
	
	var flags = {"wave_cleared": false}
	spawner.wave_cleared.connect(func(): flags.wave_cleared = true)
	
	spawner.spawn_wave(wave_def)
	assert_eq(spawner.active_enemies.size(), 2, "Spawner should have 2 active enemies")
	assert_false(flags.wave_cleared, "Wave should not be cleared yet")
	
	# Manually trigger the defeated callback for the first enemy
	var enemy1 = spawner.active_enemies[0]
	spawner._on_enemy_defeated(enemy1)
	
	assert_eq(spawner.active_enemies.size(), 1, "Spawner should have 1 active enemy remaining")
	assert_false(flags.wave_cleared, "Wave should not be cleared yet")
	
	# Manually trigger the defeated callback for the second enemy
	var enemy2 = spawner.active_enemies[0]
	spawner._on_enemy_defeated(enemy2)
	
	assert_eq(spawner.active_enemies.size(), 0, "Spawner should have 0 active enemies")
	assert_true(flags.wave_cleared, "Wave should be cleared")

func test_zone_encounter_gate_locks_and_wave_progression() -> void:
	var gate = CSGBox3D.new()
	add_child(gate)
	
	# Set up properties BEFORE adding encounter to the tree so _ready runs correctly
	encounter.gates = [gate]
	encounter.spawner = spawner
	
	var wave_def_1 = WaveDef.new()
	var enemies_list_1: Array[PackedScene] = [dummy_enemy_scene]
	wave_def_1.enemies = enemies_list_1
	
	var wave_def_2 = WaveDef.new()
	var enemies_list_2: Array[PackedScene] = [dummy_enemy_scene]
	wave_def_2.enemies = enemies_list_2
	
	encounter.waves = [wave_def_1, wave_def_2]
	
	# Add nodes to tree
	add_child(spawner)
	add_child(encounter)
	
	var flags = {"encounter_completed": false}
	encounter.encounter_completed.connect(func(): flags.encounter_completed = true)
	
	# Initially (post-ready), gates should be unlocked
	assert_false(gate.visible, "Gate should be invisible initially")
	assert_false(gate.use_collision, "Gate collision should be disabled initially")
	
	# Player enters
	encounter._on_body_entered(mock_player)
	
	assert_true(encounter.active, "Encounter should be active")
	assert_true(gate.visible, "Gate should lock (become visible)")
	assert_true(gate.use_collision, "Gate collision should lock")
	assert_eq(encounter.current_wave_index, 0, "Should start at wave index 0")
	assert_eq(spawner.active_enemies.size(), 1, "Spawner should have 1 enemy for wave 1")
	
	# Defeat enemy of wave 1
	var enemy1 = spawner.active_enemies[0]
	spawner._on_enemy_defeated(enemy1)
	
	assert_eq(encounter.current_wave_index, 1, "Should advance to wave index 1")
	assert_eq(spawner.active_enemies.size(), 1, "Spawner should spawn 1 enemy for wave 2")
	assert_false(flags.encounter_completed, "Encounter should not be completed yet")
	
	# Defeat enemy of wave 2
	var enemy2 = spawner.active_enemies[0]
	spawner._on_enemy_defeated(enemy2)
	
	assert_true(flags.encounter_completed, "Encounter should complete")
	assert_false(gate.visible, "Gate should unlock (become invisible)")
	assert_false(gate.use_collision, "Gate collision should unlock")
	
	gate.queue_free()
