extends "res://tests/framework/test_case.gd"

func test_bruiser_shield_and_guard_break() -> void:
	var bruiser = load("res://characters/enemies/bruiser/bruiser.tscn").instantiate()
	add_child(bruiser)
	
	var health = bruiser.get_node("HealthComponent")
	var combat = bruiser.get_node("EnemyCombatComponent")
	var hurtbox = bruiser.get_node("Hurtbox3D")
	
	assert_eq(health.current_shield, 50.0, "Bruiser starts with 50 shield")
	
	# Normal hit (10 damage, not guard breaking)
	var dmg_normal = DamageInfo.new()
	dmg_normal.amount = 10.0
	dmg_normal.stun = 0.5
	hurtbox.receive_hit(dmg_normal)
	
	assert_eq(health.current_shield, 40.0, "Shield absorbs damage")
	assert_false(combat.is_stunned(), "Bruiser not stunned while shield is up")
	
	# Guard break hit (10 damage, guard breaking)
	var dmg_guard_break = DamageInfo.new()
	dmg_guard_break.amount = 10.0
	dmg_guard_break.stun = 1.0
	dmg_guard_break.is_guard_breaking = true
	hurtbox.receive_hit(dmg_guard_break)
	
	assert_eq(health.current_shield, 30.0, "Shield absorbs guard break damage")
	assert_true(combat.is_stunned(), "Guard breaking attack stuns despite shield")
	
	# Clear stun
	combat.stun_timer = 0.0
	
	# Break shield completely
	var dmg_heavy = DamageInfo.new()
	dmg_heavy.amount = 40.0
	dmg_heavy.stun = 0.5
	hurtbox.receive_hit(dmg_heavy)
	
	assert_eq(health.current_shield, 0.0, "Shield is broken")
	# Stun applies because shield is 0 (it broke during this hit... wait, actually it applies because the shield was reduced to 0!)
	# Wait, my logic checks `current_shield > 0`. If it's 0, it WILL stun. Let's verify.
	assert_true(combat.is_stunned(), "Hit that breaks shield causes stun")
	
	bruiser.queue_free()
