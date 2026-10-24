extends "res://tests/framework/test_case.gd"

# A2: hits absorbed by a boss state shield (Enforcer/Headliner `is_shield_active`)
# must not knock back or stun the boss — stun freezes the boss state machine.

func _absorbed_hit() -> DamageInfo:
	var dmg = DamageInfo.new()
	dmg.amount = 50.0
	dmg.knockback = 10.0
	dmg.stun = 0.5
	dmg.is_shield_breaker = false
	dmg.is_guard_breaking = false
	return dmg

func test_headliner_shield_absorbs_without_stun_or_knockback() -> void:
	var boss = load("res://characters/enemies/headliner/headliner.tscn").instantiate()
	add_child(boss)
	boss.activate_boss()
	assert_eq(boss.state_machine.current_state.name, "StateShield")
	assert_true(boss.is_shield_active, "Headliner shield should be up in StateShield")

	boss.velocity = Vector3.ZERO
	boss.hurtbox.receive_hit(_absorbed_hit())

	assert_false(boss.combat_comp.is_stunned(), "Absorbed shield hit should not stun the Headliner")
	assert_eq(boss.velocity, Vector3.ZERO, "Absorbed shield hit should not knock the Headliner back")
	assert_eq(boss.state_machine.current_state.name, "StateShield", "Headliner should stay in StateShield")

	boss.queue_free()

func test_enforcer_shield_absorbs_without_stun_or_knockback() -> void:
	var enforcer = load("res://characters/enemies/enforcer/enforcer.tscn").instantiate()
	add_child(enforcer)
	enforcer.is_active = true
	enforcer.state_machine.transition_to("StateShield")
	assert_true(enforcer.is_shield_active, "Enforcer shield should be up in StateShield")

	var hurtbox: Hurtbox3D = null
	for child in enforcer.get_children():
		if child is Hurtbox3D:
			hurtbox = child
			break
	assert_not_null(hurtbox, "Enforcer should have a Hurtbox3D child")

	enforcer.velocity = Vector3.ZERO
	hurtbox.receive_hit(_absorbed_hit())

	assert_false(enforcer.combat_comp.is_stunned(), "Absorbed shield hit should not stun the Enforcer")
	assert_eq(enforcer.velocity, Vector3.ZERO, "Absorbed shield hit should not knock the Enforcer back")

	enforcer.queue_free()
