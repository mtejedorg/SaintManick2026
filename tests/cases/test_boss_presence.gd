extends "res://tests/framework/test_case.gd"

## F8: Headliner/Enforcer presence. Bodies yaw toward Nick without pitching or snapping,
## the Headliner leans into its telegraph, and the Enforcer bubble fits its 3 m model
## with the leftover pink wire surface hidden.

func _player_at(pos: Vector3) -> Node3D:
	var p := Node3D.new()
	add_child(p)
	p.global_position = pos
	return p

func test_enforcer_bubble_fits_the_three_metre_model() -> void:
	var enforcer: EnforcerEnemy = load("res://characters/enemies/enforcer/enforcer.tscn").instantiate()
	enforcer.position = Vector3(0.0, 300.0, 4300.0)
	add_child(enforcer)
	var sphere := enforcer.shield_bubble.mesh as SphereMesh
	assert_not_null(sphere, "ShieldBubble is a SphereMesh")
	assert_almost_eq(sphere.radius, 2.3, 0.001, "Bubble radius 2.3 m")
	assert_almost_eq(sphere.height, 4.6, 0.001, "Bubble height 4.6 m")
	enforcer.queue_free()

func test_enforcer_wire_surface_is_hidden() -> void:
	var visual: Node3D = load("res://characters/enemies/enforcer/enforcer_visual.tscn").instantiate()
	add_child(visual)
	var body: MeshInstance3D = visual.get_node("Pivot/EnforcerHammer/Enforcer_Hammer")
	var wire := body.get_surface_override_material(1) as StandardMaterial3D
	assert_not_null(wire, "The pink wire surface has an override")
	if wire:
		assert_eq(wire.transparency, BaseMaterial3D.TRANSPARENCY_ALPHA, "The override is alpha-blended")
		assert_almost_eq(wire.albedo_color.a, 0.0, 0.001, "The override is fully transparent")
	visual.queue_free()

func test_enforcer_eases_its_yaw_toward_nick_and_never_pitches() -> void:
	var enforcer: EnforcerEnemy = load("res://characters/enemies/enforcer/enforcer.tscn").instantiate()
	enforcer.position = Vector3(0.0, 300.0, 4320.0)
	add_child(enforcer)
	enforcer.set_physics_process(false)
	# Nick to the right (+X) and well above.
	var player := _player_at(Vector3(10.0, 305.0, 4320.0))
	enforcer.player = player
	enforcer.state_machine.transition_to("StateShield")
	var state = enforcer.state_machine.current_state
	state.physics_update(0.016)
	var off_after_one := absf(angle_difference(enforcer.global_rotation.y, PI / 2.0))
	assert_lt(off_after_one, PI / 2.0 - 0.01, "One tick turns toward Nick")
	assert_gt(off_after_one, 0.3, "One tick does not snap")
	for i in 60:
		state.physics_update(0.016)
	assert_almost_eq(angle_difference(enforcer.global_rotation.y, PI / 2.0), 0.0, 0.02, "The Enforcer ends up facing Nick (+Z front -> yaw PI/2)")
	assert_almost_eq(enforcer.global_rotation.x, 0.0, 0.0001, "No pitch toward a Nick above it")
	assert_almost_eq(enforcer.global_rotation.z, 0.0, 0.0001, "No roll")
	enforcer.queue_free()
	player.queue_free()

func test_attack_lunge_look_at_is_flattened() -> void:
	var enforcer: EnforcerEnemy = load("res://characters/enemies/enforcer/enforcer.tscn").instantiate()
	enforcer.position = Vector3(0.0, 300.0, 4340.0)
	add_child(enforcer)
	enforcer.set_physics_process(false)
	var player := _player_at(Vector3(-6.0, 304.0, 4340.0))
	enforcer.player = player
	enforcer.state_machine.transition_to("State3HitBurst")
	assert_almost_eq(enforcer.global_rotation.x, 0.0, 0.0001, "The lunge never pitches the body")
	assert_almost_eq(angle_difference(enforcer.global_rotation.y, -PI / 2.0), 0.0, 0.01, "The lunge faces Nick (-X)")
	enforcer.queue_free()
	player.queue_free()

func test_headliner_telegraph_leans_forward() -> void:
	var boss: HeadlinerBoss = load("res://characters/enemies/headliner/headliner.tscn").instantiate()
	boss.position = Vector3(0.0, 300.0, 4360.0)
	add_child(boss)
	var pivot: Node3D = boss.character_visual.pivot
	var base_x: float = pivot.rotation.x
	boss.state_machine.transition_to("StateTelegraph")
	var peak := 0.0
	for i in 30:
		await get_tree().process_frame
		peak = maxf(peak, pivot.rotation.x - base_x)
	assert_gt(peak, deg_to_rad(5.0), "The Headliner leans ~6 deg into its telegraph (peak %.3f rad)" % peak)
	boss.queue_free()
