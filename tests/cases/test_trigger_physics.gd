extends "res://tests/framework/test_case.gd"

# A9: a REAL physics test (no direct _on_body_entered call). Nick's body must sit on the
# "player" physics layer (2) so the zone triggers/encounters (mask 2) actually fire when
# he walks into them. With the old default layer 1 nothing ever tripped.

func test_player_body_trips_zone_encounter_through_physics() -> void:
	var dummy := Node3D.new()
	var dummy_scene := PackedScene.new()
	dummy_scene.pack(dummy)
	dummy.free()
	var wave := WaveDef.new()
	var enemies: Array[PackedScene] = [dummy_scene]
	wave.enemies = enemies

	var spawner := WaveSpawner.new()
	add_child(spawner)

	var encounter: ZoneEncounter = load("res://levels/components/zone_encounter.tscn").instantiate()
	encounter.spawner = spawner
	var waves: Array[WaveDef] = [wave]
	encounter.waves = waves
	add_child(encounter)
	# Far from anything else the suite may have in the tree.
	encounter.global_position = Vector3(0.0, 500.0, 2000.0)

	var player = load("res://characters/player/player.tscn").instantiate()
	add_child(player)
	player.current_path = null
	player.global_position = encounter.global_position

	assert_true((player.collision_layer & encounter.collision_mask) != 0, "Player body layer must be in the encounter's mask")
	assert_false(encounter.active, "Encounter should not be active before physics runs")

	for i in 3:
		await get_tree().physics_frame

	assert_true(encounter.active, "Walking Nick into the encounter volume should activate it via physics")
	assert_eq(spawner.active_enemies.size(), 1, "Activated encounter should spawn its first wave")

	player.queue_free()
	encounter.queue_free()
	spawner.queue_free()
