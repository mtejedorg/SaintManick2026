extends "res://tests/framework/test_case.gd"

## E2: every enemy visual is sized to its capsule (capsule height / 1.8) with its feet on
## the capsule bottom — the shared NickProto visual used to render ~0.84 m tall.

func _visual_bounds(visual: Node3D) -> AABB:
	# R1: a skinned body (the rigged enemy body) is measured from its posed skeleton — the
	# mesh AABB of a Mixamo skin is in bind space, not where the body actually stands.
	var sk := visual.find_child("Skeleton3D", true, false) as Skeleton3D
	if sk:
		var box := AABB(sk.global_transform * sk.get_bone_global_pose(0).origin, Vector3.ZERO)
		for i in sk.get_bone_count():
			box = box.expand(sk.global_transform * sk.get_bone_global_pose(i).origin)
		return box
	var merged := AABB()
	var first := true
	for mi in visual.find_children("*", "MeshInstance3D", true, false):
		var m := mi as MeshInstance3D
		if m.mesh == null:
			continue
		var box: AABB = m.global_transform * m.get_aabb()
		merged = box if first else merged.merge(box)
		first = false
	return merged

func _check(scene_path: String, capsule_height: float, label: String) -> void:
	var enemy: Node3D = load(scene_path).instantiate()
	enemy.position = Vector3(0.0, 300.0, 4000.0)
	add_child(enemy)
	enemy.process_mode = Node.PROCESS_MODE_DISABLED
	var bounds := _visual_bounds(enemy.get_node("MeshInstance3D"))
	var feet := bounds.position.y - enemy.global_position.y
	var height := bounds.size.y
	assert_almost_eq(feet, -capsule_height * 0.5, 0.15, "%s feet should sit on the capsule bottom (got %.2f)" % [label, feet])
	assert_almost_eq(height, capsule_height, capsule_height * 0.2, "%s visual should be about capsule height (got %.2f m)" % [label, height])
	enemy.queue_free()

func test_runner_visual_matches_capsule() -> void:
	_check("res://characters/enemies/runner/runner.tscn", 1.8, "Runner")

func test_bruiser_visual_matches_capsule() -> void:
	_check("res://characters/enemies/bruiser/bruiser.tscn", 2.2, "Bruiser")

func test_enforcer_visual_matches_capsule() -> void:
	_check("res://characters/enemies/enforcer/enforcer.tscn", 3.0, "Enforcer")

func test_enforcer_keeps_its_materials_and_telegraphs_with_rim_and_lean() -> void:
	var enforcer: EnforcerEnemy = load("res://characters/enemies/enforcer/enforcer.tscn").instantiate()
	enforcer.position = Vector3(0.0, 300.0, 4100.0)
	add_child(enforcer)
	var visual: CharacterVisual = enforcer.character_visual
	assert_not_null(visual.pivot, "enforcer_visual.tscn has a Pivot for procedural motion")
	for sm in visual.skinned_meshes:
		assert_null(sm.material_override, "Enforcer_Hammer.glb keeps its own materials")
	assert_almost_eq(visual.get_base_rim_strength(), 3.5, 0.001, "Enforcer rim strength 3.5")
	assert_eq(visual.get_base_rim_color(), CharacterVisual.ENEMY_RIM_COLOR, "Enforcer rim is magenta")

	enforcer.state_machine.transition_to("StateTelegraph")
	assert_eq(visual.get_current_rim_color(), CharacterVisual.TELEGRAPH_RIM_COLOR, "Telegraph flashes the rim white-hot")
	# Track the peak over the telegraph beat (frame timing in the test runner is uneven).
	var peak := 0.0
	for i in 40:
		await get_tree().process_frame
		peak = maxf(peak, visual.pivot.rotation.x)
	assert_gt(peak, deg_to_rad(7.0), "Telegraph leans the Enforcer ~8 deg toward its front (peak %.3f rad)" % peak)
	enforcer.queue_free()
