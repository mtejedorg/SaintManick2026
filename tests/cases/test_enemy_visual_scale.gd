extends "res://tests/framework/test_case.gd"

## E2: every enemy visual is sized to its capsule (capsule height / 1.8) with its feet on
## the capsule bottom — the shared NickProto visual used to render ~0.84 m tall.

func _visual_bounds(visual: Node3D) -> AABB:
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
