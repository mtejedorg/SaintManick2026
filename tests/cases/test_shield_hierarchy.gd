extends "res://tests/framework/test_case.gd"

# T2: heavies stop deleting shields outright. Only Battery Ram (ComboDef.is_shield_breaker)
# and Bass Drop genuinely shatter a shield; every other heavy pressures it harder via
# DamageInfo.shield_damage_multiplier, and any overflow that reaches HP is scaled back
# down to the base hit amount.

func test_generic_heavy_pressures_but_does_not_zero_a_shield() -> void:
	var health = HealthComponent.new()
	health.max_health = 100.0
	health.max_shield = 90.0
	add_child(health)
	health.current_health = 100.0
	health.current_shield = 90.0

	var player = load("res://characters/player/player.tscn").instantiate()
	add_child(player)
	var attack_state = player.state_machine.get_node("StateAttack")
	attack_state.enter()
	attack_state.current_sequence.clear()
	attack_state._start_attack(true) # unmatched/generic heavy

	assert_false(player.bionic_arm_hitbox.damage_info.is_shield_breaker, "Generic heavy should not be a shield breaker")

	health.take_damage(player.bionic_arm_hitbox.damage_info)

	assert_gt(health.current_shield, 0.0, "A single generic heavy should not zero a 90 shield")
	assert_eq(health.current_health, 100.0, "Shield should still be absorbing; HP should be untouched")

	player.queue_free()
	health.queue_free()

func test_battery_ram_zeroes_the_shield() -> void:
	assert_not_null(SaveManager.profile, "SaveManager profile should exist for combo gating")
	var was_unlocked = SaveManager.profile.unlocked_combos.has("BB")
	if not was_unlocked:
		SaveManager.profile.unlocked_combos.append("BB")

	var bruiser = load("res://characters/enemies/bruiser/bruiser.tscn").instantiate()
	add_child(bruiser)
	var health = bruiser.get_node("HealthComponent")
	assert_eq(health.current_shield, 80.0, "K5 (D7): Bruiser should start with its full 80 shield")

	var player = load("res://characters/player/player.tscn").instantiate()
	add_child(player)
	var attack_state = player.state_machine.get_node("StateAttack")

	attack_state.enter()
	attack_state.current_sequence.clear()
	attack_state._start_attack(true) # B
	attack_state.buffered_attack = true
	attack_state.buffered_heavy = true
	attack_state.attack_timer = 0.0
	attack_state.physics_update(0.0) # BB (Battery Ram)

	assert_true(player.bionic_arm_hitbox.damage_info.is_shield_breaker, "Battery Ram should be a shield breaker")

	health.take_damage(player.bionic_arm_hitbox.damage_info)

	assert_eq(health.current_shield, 0.0, "Battery Ram should zero the Bruiser's shield")
	assert_lt(health.current_health, bruiser.stats.max_health, "Battery Ram's full damage should carry through to HP")

	if not was_unlocked:
		SaveManager.profile.unlocked_combos.erase("BB")
	player.queue_free()
	bruiser.queue_free()

func test_generic_heavy_no_longer_launches() -> void:
	var player = load("res://characters/player/player.tscn").instantiate()
	add_child(player)
	var attack_state = player.state_machine.get_node("StateAttack")

	attack_state.enter()
	attack_state.current_sequence.clear()
	attack_state._start_attack(true) # unmatched/generic heavy

	assert_false(player.bionic_arm_hitbox.damage_info.is_launcher, "Generic heavy no longer launches — that's the Launcher route's identity")

	player.queue_free()

func test_light_attack_shield_damage_unchanged() -> void:
	var health = HealthComponent.new()
	health.max_health = 100.0
	health.max_shield = 40.0
	add_child(health)
	health.current_health = 100.0
	health.current_shield = 40.0

	var player = load("res://characters/player/player.tscn").instantiate()
	add_child(player)
	var attack_state = player.state_machine.get_node("StateAttack")
	attack_state.enter() # no heavy input pressed in test env -> light

	assert_eq(player.katana_hitbox.damage_info.shield_damage_multiplier, 1.0, "Light attacks should keep a 1x shield multiplier")

	health.take_damage(player.katana_hitbox.damage_info)
	assert_eq(health.current_shield, 40.0 - 12.0, "Light shield damage should equal the raw hit amount, unchanged by T2")

	player.queue_free()
	health.queue_free()

func test_bass_drop_breaks_boss_shield_state() -> void:
	var boss_scene = load("res://characters/enemies/headliner/headliner.tscn")
	var boss = boss_scene.instantiate()
	add_child(boss)
	boss.activate_boss()
	assert_eq(boss.state_machine.current_state.name, "StateShield", "Boss should start in StateShield after activation")

	var player = load("res://characters/player/player.tscn").instantiate()
	add_child(player)
	player.global_position = boss.global_position
	if not SignalBus.downbeat.is_connected(player._on_downbeat):
		SignalBus.downbeat.connect(player._on_downbeat)

	player.ability_meter = player.MAX_ABILITY_METER
	player.try_arm_bass_drop()
	SignalBus.downbeat.emit("primary", 1)

	assert_eq(boss.state_machine.current_state.name, "StateRecovery", "Bass Drop should break the boss shield state, same as any other shield breaker")

	player.queue_free()
	boss.queue_free()
