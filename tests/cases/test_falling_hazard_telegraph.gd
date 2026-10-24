extends "res://tests/framework/test_case.gd"

## F7: the falling-hazard warning is visible on both telegraph beats (it used to toggle off
## on the very beat that started the telegraph).

func _make_hazard() -> EscapeFallingHazard:
	var hazard := EscapeFallingHazard.new()
	var warning := MeshInstance3D.new()
	warning.name = "Warning"
	warning.visible = false
	hazard.add_child(warning)
	hazard.warning_mesh = warning
	hazard.position = Vector3(0.0, 0.0, 3800.0)
	add_child(hazard)
	return hazard

func test_warning_is_visible_on_both_telegraph_beats() -> void:
	var hazard := _make_hazard()
	var telegraph_start := hazard.beat_interval - hazard.telegraph_beats
	for i in telegraph_start - 1:
		hazard._on_beat("primary", 1)
	assert_false(hazard.warning_mesh.visible, "No warning before the telegraph")
	hazard._on_beat("primary", 1) # counter == telegraph_start -> start_telegraph()
	assert_true(hazard.is_telegraphing, "Precondition: telegraph started")
	assert_true(hazard.warning_mesh.visible, "The warning shows on the beat the telegraph starts")
	hazard._on_beat("primary", 1)
	assert_true(hazard.warning_mesh.visible, "...and stays on the second telegraph beat")
	hazard._on_beat("primary", 1) # counter wraps to 0 -> fall()
	assert_false(hazard.warning_mesh.visible, "The warning goes dark when the hazard falls")
	hazard.queue_free()
