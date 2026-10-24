extends "res://tests/framework/test_case.gd"

## E1: CharacterVisual never flattens a textured model. A WHITE tint keeps the model's own
## materials (no material_override at all); any other tint applies ONE dark base material.
## Feedback lives on the per-instance rim overlay.

const VISUAL_SCENE := "res://characters/shared/character_visual.tscn"

func _child_meshes(visual: CharacterVisual) -> Array[MeshInstance3D]:
	return visual.skinned_meshes

func test_white_tint_keeps_model_materials() -> void:
	var visual: CharacterVisual = load(VISUAL_SCENE).instantiate()
	visual.tint = Color.WHITE
	add_child(visual)
	await get_tree().process_frame
	assert_gt(_child_meshes(visual).size(), 0, "The visual should find the model's meshes")
	for sm in _child_meshes(visual):
		assert_null(sm.material_override, "WHITE tint must never override %s" % sm.name)
		assert_not_null(sm.material_overlay, "Every mesh still gets the rim overlay")
	visual.queue_free()

func test_non_white_tint_applies_one_dark_base() -> void:
	var visual: CharacterVisual = load(VISUAL_SCENE).instantiate()
	visual.tint = Color(1.0, 0.0, 0.0)
	add_child(visual)
	await get_tree().process_frame
	var mat: StandardMaterial3D = visual.base_material
	assert_not_null(mat, "A non-white tint builds a base material")
	assert_false(mat.emission_enabled, "The dark base has no emission")
	assert_lt(mat.albedo_color.r, 0.3, "The dark base stays dark (18 % toward the tint)")
	for sm in _child_meshes(visual):
		assert_eq(sm.material_override, mat, "All meshes share the one dark base")
	visual.queue_free()

func test_rim_defaults_overrides_and_flash_returns() -> void:
	var visual: CharacterVisual = load(VISUAL_SCENE).instantiate()
	visual.rim_color = Color(1.0, 0.5, 0.0)
	visual.rim_strength = 4.0
	add_child(visual)
	assert_eq(visual.get_current_rim_color(), Color(1.0, 0.5, 0.0), "rim_color export overrides the faction colour")
	assert_almost_eq(visual.get_current_rim_strength(), 4.0, 0.001, "rim_strength export is applied")

	visual.flash_rim(Color.WHITE, 6.0, 0.1)
	assert_eq(visual.get_current_rim_color(), Color.WHITE, "Flash sets the rim immediately")
	await get_tree().create_timer(0.25).timeout
	assert_true(visual.get_current_rim_color().is_equal_approx(Color(1.0, 0.5, 0.0)), "Flash tweens back to the resting rim")
	assert_almost_eq(visual.get_current_rim_strength(), 4.0, 0.01, "Flash tweens the strength back too")

	visual.update_rim_color(CharacterVisual.VULNERABLE_RIM_COLOR)
	assert_eq(visual.get_base_rim_color(), CharacterVisual.VULNERABLE_RIM_COLOR, "update_rim_color sets the resting rim")
	visual.queue_free()

func test_default_rim_by_faction() -> void:
	var visual: CharacterVisual = load(VISUAL_SCENE).instantiate()
	visual.faction = CharacterVisual.Faction.PLAYER
	add_child(visual)
	assert_eq(visual.get_current_rim_color(), CharacterVisual.PLAYER_RIM_COLOR, "Player faction rests at cyan")
	visual.queue_free()
