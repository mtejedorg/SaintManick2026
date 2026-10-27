extends "res://tests/framework/test_case.gd"

func test_bruiser_shield_and_guard_break() -> void:
	var bruiser = load("res://characters/enemies/bruiser/bruiser.tscn").instantiate()
	add_child(bruiser)
	
	var health = bruiser.get_node("HealthComponent")
	var combat = bruiser.get_node("EnemyCombatComponent")
	var hurtbox = bruiser.get_node("Hurtbox3D")
	
	assert_eq(health.current_shield, 80.0, "K5 (D7): Bruiser starts with 80 shield")
	
	# Normal hit (10 damage, not guard breaking)
	var dmg_normal = DamageInfo.new()
	dmg_normal.amount = 10.0
	dmg_normal.stun = 0.5
	hurtbox.receive_hit(dmg_normal)
	
	assert_eq(health.current_shield, 70.0, "Shield absorbs damage")
	assert_false(combat.is_stunned(), "Bruiser not stunned while shield is up")
	
	# Guard break hit (10 damage, guard breaking)
	var dmg_guard_break = DamageInfo.new()
	dmg_guard_break.amount = 10.0
	dmg_guard_break.stun = 1.0
	dmg_guard_break.is_guard_breaking = true
	hurtbox.receive_hit(dmg_guard_break)
	
	assert_eq(health.current_shield, 60.0, "Shield absorbs guard break damage")
	assert_true(combat.is_stunned(), "Guard breaking attack stuns despite shield")
	
	# Clear stun
	combat.stun_timer = 0.0
	
	# Break shield completely
	var dmg_heavy = DamageInfo.new()
	dmg_heavy.amount = 60.0
	dmg_heavy.stun = 0.5
	hurtbox.receive_hit(dmg_heavy)
	
	assert_eq(health.current_shield, 0.0, "Shield is broken")
	# Stun applies because shield is 0 (it broke during this hit... wait, actually it applies because the shield was reduced to 0!)
	# Wait, my logic checks `current_shield > 0`. If it's 0, it WILL stun. Let's verify.
	assert_true(combat.is_stunned(), "Hit that breaks shield causes stun")

	bruiser.queue_free()

func test_bruiser_hitbox_inactive_by_default() -> void:
	# M6b: the original hitbox-clarity violation — Bruiser must not deal permanent
	# contact damage. Hitbox starts inactive; only the beat-gated attack step turns it on.
	var bruiser = load("res://characters/enemies/bruiser/bruiser.tscn").instantiate()
	add_child(bruiser)

	assert_eq(bruiser.attack_step, BruiserEnemy.AttackStep.IDLE, "Bruiser should start idle")
	assert_false(bruiser.hitbox.is_active, "Hitbox must be inactive by default (no untelegraphed contact damage)")

	bruiser.queue_free()

func test_bruiser_telegraphs_one_beat_before_downbeat() -> void:
	var bruiser = load("res://characters/enemies/bruiser/bruiser.tscn").instantiate()
	add_child(bruiser)
	var player_stub = Node3D.new()
	player_stub.name = "PlayerStub"
	add_child(player_stub)
	bruiser.player = player_stub
	player_stub.global_position = bruiser.global_position # within melee_range

	# Conductor's primary layer defaults to 4 beats/measure — beat_index == 4 is one
	# beat before the downbeat (beat_index wraps to a fresh downbeat at 1).
	bruiser._on_beat("primary", 4)

	assert_eq(bruiser.attack_step, BruiserEnemy.AttackStep.TELEGRAPH, "Bruiser should enter TELEGRAPH one beat before the downbeat")
	assert_false(bruiser.hitbox.is_active, "Hitbox should still be inactive during telegraph")
	var visual: CharacterVisual = bruiser.character_visual
	assert_eq(visual.get_current_rim_color(), CharacterVisual.TELEGRAPH_RIM_COLOR, "Telegraph flashes the rim white-hot")
	assert_almost_eq(visual.get_current_rim_strength(), CharacterVisual.TELEGRAPH_RIM_STRENGTH, 0.01, "Telegraph rim strength is 6")
	# P7: a shielded Bruiser rests at the steel shield rim; the flash returns to it.
	assert_eq(visual.get_base_rim_color(), BruiserEnemy.SHIELD_RIM_COLOR, "The flash returns to the steel shield rim")

	bruiser.queue_free()
	player_stub.queue_free()

func test_bruiser_hitbox_active_only_on_downbeat_then_recovers() -> void:
	var bruiser = load("res://characters/enemies/bruiser/bruiser.tscn").instantiate()
	add_child(bruiser)
	var player_stub = Node3D.new()
	add_child(player_stub)
	bruiser.player = player_stub
	player_stub.global_position = bruiser.global_position

	bruiser._on_beat("primary", 4) # arm telegraph
	assert_eq(bruiser.attack_step, BruiserEnemy.AttackStep.TELEGRAPH)

	bruiser._on_downbeat("primary", 1) # downbeat -> active, hitbox on
	assert_eq(bruiser.attack_step, BruiserEnemy.AttackStep.ACTIVE, "Bruiser should become ACTIVE on the downbeat")
	assert_true(bruiser.hitbox.is_active, "Hitbox should be active only during the ACTIVE step")

	bruiser._on_beat("primary", 2) # very next beat -> recovery, hitbox off (one-beat active window)
	assert_eq(bruiser.attack_step, BruiserEnemy.AttackStep.RECOVERY, "Bruiser should move to RECOVERY on the beat after its active downbeat")
	assert_false(bruiser.hitbox.is_active, "Hitbox should switch off once recovery starts")

	bruiser._on_beat("primary", 3) # any subsequent beat while in recovery returns to idle
	assert_eq(bruiser.attack_step, BruiserEnemy.AttackStep.IDLE, "Bruiser should return to IDLE after recovery")

	bruiser.queue_free()
	player_stub.queue_free()

func test_bruiser_does_not_telegraph_out_of_range() -> void:
	var bruiser = load("res://characters/enemies/bruiser/bruiser.tscn").instantiate()
	add_child(bruiser)
	var player_stub = Node3D.new()
	add_child(player_stub)
	bruiser.player = player_stub
	player_stub.global_position = bruiser.global_position + Vector3(100, 0, 0) # far away

	bruiser._on_beat("primary", 4)

	assert_eq(bruiser.attack_step, BruiserEnemy.AttackStep.IDLE, "Bruiser should not telegraph an attack on a player far outside melee_range")

	bruiser.queue_free()
	player_stub.queue_free()
