extends "res://tests/framework/test_case.gd"

## E5: the Sniper reads as a hovering laser turret — drone mesh, orange rim, a beam that
## widens aim -> lock -> fire, and it only starts a cycle with Nick inside attack_range.

func _spawn(offset_to_player: Vector3) -> Array:
	var sniper: SniperEnemy = load("res://characters/enemies/sniper/sniper.tscn").instantiate()
	sniper.position = Vector3(0.0, 300.0, 4300.0)
	add_child(sniper)
	sniper.process_mode = Node.PROCESS_MODE_DISABLED # no gravity/look_at drift during the test
	var player_stub := Node3D.new()
	add_child(player_stub)
	player_stub.global_position = sniper.global_position + offset_to_player
	sniper.player = player_stub
	sniper.is_active = true
	return [sniper, player_stub]

func test_beam_widens_through_aim_lock_fire_in_range() -> void:
	var pair := _spawn(Vector3(10.0, 0.0, 0.0))
	var sniper: SniperEnemy = pair[0]
	sniper._on_beat("primary", 3)
	assert_true(sniper.laser_beam.visible, "Aim beat paints the beam")
	assert_eq(sniper.laser_beam.scale, SniperEnemy.AIM_BEAM_SCALE, "Aim beam is 0.15 m wide")
	assert_false(sniper.laser_hitbox.is_active, "Aiming never hurts")
	sniper._on_beat("primary", 4)
	assert_eq(sniper.laser_beam.scale, SniperEnemy.LOCK_BEAM_SCALE, "Lock beam is 0.3 m wide")
	assert_true(sniper.is_aim_locked, "Lock beat freezes the aim")
	assert_eq(sniper.character_visual.get_current_rim_color(), CharacterVisual.TELEGRAPH_RIM_COLOR, "Lock beat is the white-hot telegraph")
	sniper._on_beat("primary", 1)
	assert_eq(sniper.laser_beam.scale, SniperEnemy.FIRE_BEAM_SCALE, "Fire beam is 0.6 m wide")
	assert_true(sniper.laser_hitbox.is_active, "Fire beat is live")
	assert_gt(sniper.laser_material.albedo_color.r, 1.0, "Beam albedo is HDR (energy 3) so it blooms")
	sniper._on_beat("primary", 2)
	assert_false(sniper.laser_beam.visible, "Beam clears after the shot")
	assert_false(sniper.laser_hitbox.is_active, "Hitbox clears after the shot")
	sniper.queue_free()
	pair[1].queue_free()

func test_no_cycle_when_player_beyond_attack_range() -> void:
	var pair := _spawn(Vector3(20.0, 0.0, 0.0))
	var sniper: SniperEnemy = pair[0]
	assert_almost_eq(sniper.stats.attack_range, 16.0, 0.001, "Sniper attack_range is 16 m")
	for beat in [3, 4, 1]:
		sniper._on_beat("primary", beat)
		assert_false(sniper.laser_beam.visible, "Out of range: no beam on beat %d" % beat)
		assert_false(sniper.laser_hitbox.is_active, "Out of range: never live on beat %d" % beat)
	sniper.queue_free()
	pair[1].queue_free()

func test_drone_visual_is_dark_metal_orange_rim_and_hovers() -> void:
	var pair := _spawn(Vector3(10.0, 0.0, 0.0))
	var sniper: SniperEnemy = pair[0]
	var visual: CharacterVisual = sniper.character_visual
	assert_true(visual.get_base_rim_color().is_equal_approx(Color(1.0, 0.501961, 0.0)), "Sniper rim is orange #FF8000")
	assert_gt(visual.skinned_meshes.size(), 0, "Drone mesh found")
	var drone: MeshInstance3D = visual.skinned_meshes[0]
	var metal := drone.material_override as StandardMaterial3D
	assert_not_null(metal, "Drone wears the dark-metal override")
	assert_almost_eq(metal.metallic, 0.6, 0.001, "Dark metal metallic 0.6")
	var box: AABB = drone.global_transform * drone.get_aabb()
	assert_almost_eq(box.size.y, 1.07, 0.2, "Drone scaled x22 stands ~1.1 m")
	visual.process_mode = Node.PROCESS_MODE_ALWAYS
	var y0: float = visual.pivot.position.y
	var moved := 0.0
	for i in 20:
		await get_tree().process_frame
		moved = maxf(moved, absf(visual.pivot.position.y - y0))
	assert_gt(moved, 0.01, "The drone bobs")
	assert_lt(moved, 0.31, "The bob stays within +/- 0.15 m")
	sniper.queue_free()
	pair[1].queue_free()
