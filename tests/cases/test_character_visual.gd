extends "res://tests/framework/test_case.gd"

## E1: CharacterVisual never flattens a textured model. A WHITE tint keeps the model's own
## materials (no material_override at all); any other tint applies ONE dark base material.
## Feedback lives on the per-instance rim overlay.

const VISUAL_SCENE := "res://characters/shared/character_visual.tscn"
const EnemyCombatComponentScript := preload("res://_core/components/enemy_combat_component.gd")

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

func test_play_death_returns_a_tween_that_shrinks_the_visual() -> void:
	# F3: the shared death presentation — white-hot rim + shrink, returns the tween.
	var visual: CharacterVisual = load(VISUAL_SCENE).instantiate()
	add_child(visual)
	var start_scale: Vector3 = visual.scale
	var tween: Tween = visual.play_death(0.1)
	assert_not_null(tween, "play_death should return its tween")
	assert_eq(visual.get_current_rim_color(), Color.WHITE, "Death flashes the rim white")
	assert_almost_eq(visual.get_current_rim_strength(), CharacterVisual.DEATH_RIM_STRENGTH, 0.001, "Death rim is white-hot")
	await tween.finished
	assert_lt(visual.scale.length(), start_scale.length() * 0.01, "The visual should shrink to nothing")
	visual.queue_free()

func test_runner_death_disarms_then_frees_after_the_tween() -> void:
	# F3: scrap/enemy_died are immediate; the body disarms, plays the death tween and only
	# then frees.
	var runner: RunnerEnemy = load("res://characters/enemies/runner/runner.tscn").instantiate()
	runner.position = Vector3(0.0, 0.0, 3600.0)
	add_child(runner)
	var flags = {"died": false}
	var on_died = func(_p): flags.died = true
	SignalBus.enemy_died.connect(on_died)
	var hurtbox: Hurtbox3D = runner.get_node("Hurtbox3D")
	var kill := DamageInfo.new()
	kill.amount = 9999.0
	hurtbox.receive_hit(kill)
	assert_true(flags.died, "enemy_died is emitted immediately")
	assert_true(is_instance_valid(runner), "The runner stays for its death tween")
	assert_false(hurtbox.is_in_group("enemy_hurtbox"), "A dying runner is no longer an AoE target")
	assert_false(runner.hitbox.is_active, "A dying runner's hitbox is off")
	await get_tree().create_timer(EnemyCombatComponentScript.DEATH_SECONDS + 0.15).timeout
	assert_false(is_instance_valid(runner), "The runner frees once the death tween ends")
	SignalBus.enemy_died.disconnect(on_died)

func test_non_absorbed_hit_flashes_the_enemy_rim_white() -> void:
	# F3: every non-absorbed hit flashes the enemy's rim white-hot.
	var runner: RunnerEnemy = load("res://characters/enemies/runner/runner.tscn").instantiate()
	runner.position = Vector3(0.0, 0.0, 3620.0)
	add_child(runner)
	var hit := DamageInfo.new()
	hit.amount = 1.0
	runner.get_node("Hurtbox3D").receive_hit(hit)
	assert_eq(runner.character_visual.get_current_rim_color(), Color.WHITE, "A landed hit flashes the rim white")
	assert_almost_eq(runner.character_visual.get_current_rim_strength(), 5.0, 0.001, "Hit flash strength is 5")
	runner.queue_free()
