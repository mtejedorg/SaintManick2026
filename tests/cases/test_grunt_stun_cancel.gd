extends "res://tests/framework/test_case.gd"

## F4: a stunning hit mid-attack cancels the grunt's attack sequence — it must not stay
## armed and lunge without a new tell, nor keep its hitbox live through the stun.

func _stun_hit() -> DamageInfo:
	var hit := DamageInfo.new()
	hit.amount = 1.0
	hit.stun = 0.5
	hit.is_guard_breaking = true # gets through the Bruiser's HP shield too
	return hit

func test_runner_in_active_step_is_disarmed_by_a_stunning_hit() -> void:
	var runner: RunnerEnemy = load("res://characters/enemies/runner/runner.tscn").instantiate()
	runner.position = Vector3(0.0, 0.0, 3700.0)
	add_child(runner)
	runner.is_active = true
	runner.attack_step = 2
	runner.hitbox.is_active = true
	runner.character_visual.flash_telegraph()

	runner.get_node("Hurtbox3D").receive_hit(_stun_hit())
	assert_true(runner.combat_comp.is_stunned(), "Precondition: the hit stuns")
	assert_eq(runner.attack_step, 0, "A stunning hit resets the attack step")
	assert_false(runner.hitbox.is_active, "A stunning hit disarms the hitbox")
	assert_eq(runner.character_visual.get_base_rim_color(), runner.character_visual.get_default_rim_color(), "The resting rim is the faction rim again")
	runner.queue_free()

func test_bruiser_in_telegraph_is_cancelled_by_a_stunning_hit() -> void:
	var bruiser: BruiserEnemy = load("res://characters/enemies/bruiser/bruiser.tscn").instantiate()
	bruiser.position = Vector3(0.0, 0.0, 3720.0)
	add_child(bruiser)
	bruiser.is_active = true
	bruiser.attack_step = BruiserEnemy.AttackStep.TELEGRAPH

	bruiser.get_node("Hurtbox3D").receive_hit(_stun_hit())
	assert_true(bruiser.combat_comp.is_stunned(), "Precondition: the guard-breaking hit stuns")
	assert_eq(bruiser.attack_step, BruiserEnemy.AttackStep.IDLE, "A stunning hit cancels the telegraph")
	assert_false(bruiser.hitbox.is_active, "The hitbox stays off")
	bruiser.queue_free()
