extends "res://tests/framework/test_case.gd"

var player: PlayerController

func before_each() -> void:
	player = load("res://characters/player/player.tscn").instantiate()
	add_child(player)

func after_each() -> void:
	if is_instance_valid(player):
		player.queue_free()

func test_ability_meter_fill() -> void:
	assert_eq(player.ability_meter, 0.0, "Starts at 0")
	player.add_ability_meter(20.0)
	assert_eq(player.ability_meter, 20.0, "Fills correctly")
	player.add_ability_meter(100.0)
	assert_eq(player.ability_meter, player.MAX_ABILITY_METER, "Caps at max")

func test_heavy_attack_free_at_zero_meter() -> void:
	# GDD §3.2/§3.3: heavy (Hit B) is a free basic input. The Ability Bar is a reward
	# meter and must never gate a basic attack, regardless of how empty it is.
	player.ability_meter = 0.0
	var fsm = player.state_machine
	var attack_state = fsm.get_node("StateAttack")

	attack_state.enter()
	attack_state.current_sequence.clear()
	attack_state._start_attack(true)

	assert_eq(player.ability_meter, 0.0, "Heavy attack must not consume ability meter")
	assert_eq("".join(attack_state.current_sequence), "B", "Heavy attack registered as heavy even at 0 meter")
	# T2: a generic (unmatched) heavy no longer shatters shields outright — only Battery
	# Ram (ComboDef.is_shield_breaker) and Bass Drop do. It still pressures shields harder
	# than a light via shield_damage_multiplier.
	assert_false(player.bionic_arm_hitbox.damage_info.is_shield_breaker, "Generic heavy hit should NOT be a shield breaker (Battery Ram's identity alone)")
	assert_eq(player.bionic_arm_hitbox.damage_info.shield_damage_multiplier, attack_state.generic_heavy_shield_multiplier, "Generic heavy should pressure shields at the configured multiplier")

func test_battery_ram_sets_guard_breaking_at_zero_meter() -> void:
	# BB (Battery Ram) must be reachable with an empty meter and must set is_guard_breaking —
	# it's the answer to Bruiser's shield, and the meter must never block it.
	# M8: Battery Ram is gated behind the Combo Skill Tree, independent of the meter —
	# unlock it here so this test isolates the meter behavior specifically.
	assert_not_null(SaveManager.profile, "SaveManager profile should exist for combo gating")
	var was_unlocked = SaveManager.profile.unlocked_combos.has("BB")
	if not was_unlocked:
		SaveManager.profile.unlocked_combos.append("BB")

	player.ability_meter = 0.0
	var fsm = player.state_machine
	var attack_state = fsm.get_node("StateAttack")

	attack_state.enter()
	attack_state.current_sequence.clear()
	attack_state._start_attack(true) # First heavy (B)
	attack_state.buffered_attack = true
	attack_state.buffered_heavy = true
	attack_state.attack_timer = 0.0
	attack_state.physics_update(0.0) # Second heavy (BB)

	assert_eq(player.ability_meter, 0.0, "Battery Ram must not require or consume ability meter")
	assert_eq("".join(attack_state.current_sequence), "BB", "Battery Ram sequence should register")
	assert_true(player.bionic_arm_hitbox.damage_info.is_guard_breaking, "Battery Ram should set is_guard_breaking")

	if not was_unlocked:
		SaveManager.profile.unlocked_combos.erase("BB")

func test_meter_fill_classifies_by_heavy_threshold_not_damage_scale() -> void:
	# C5: fill must be exported flat constants classified via DamageInfo.HEAVY_THRESHOLD,
	# not damage * 0.5. A light hit (12 dmg, below threshold) fills meter_per_light_hit;
	# a heavy hit (28 dmg, at/above threshold) fills meter_per_heavy_hit — regardless of
	# exact damage value, as long as it's on the correct side of HEAVY_THRESHOLD.
	player.ability_meter = 0.0

	var light_hit = DamageInfo.new()
	light_hit.source = player
	light_hit.amount = 12.0
	assert_lt(light_hit.amount, DamageInfo.HEAVY_THRESHOLD)
	SignalBus.player_hit_landed.emit(light_hit)
	assert_eq(player.ability_meter, player.meter_per_light_hit, "Light hit should fill exactly meter_per_light_hit")

	player.ability_meter = 0.0
	var heavy_hit = DamageInfo.new()
	heavy_hit.source = player
	heavy_hit.amount = 28.0
	assert_true(heavy_hit.amount >= DamageInfo.HEAVY_THRESHOLD)
	SignalBus.player_hit_landed.emit(heavy_hit)
	assert_eq(player.ability_meter, player.meter_per_heavy_hit, "Heavy hit should fill exactly meter_per_heavy_hit")

	# A much bigger heavy hit (e.g. Battery Ram at 40 dmg) must fill the SAME flat amount —
	# proves fill is not damage * scale.
	player.ability_meter = 0.0
	var big_heavy_hit = DamageInfo.new()
	big_heavy_hit.source = player
	big_heavy_hit.amount = 40.0
	SignalBus.player_hit_landed.emit(big_heavy_hit)
	assert_eq(player.ability_meter, player.meter_per_heavy_hit, "Bigger heavy hit should fill the same flat meter_per_heavy_hit, not scale with damage")

func test_meter_decays_out_of_combat_but_not_immediately() -> void:
	# C5: decay only kicks in after meter_decay_delay seconds without a landed hit.
	player.ability_meter = 50.0
	player._meter_decay_timer = player.meter_decay_delay

	# Still within the delay window — no decay yet.
	player._process(player.meter_decay_delay - 0.1)
	assert_eq(player.ability_meter, 50.0, "Meter should not decay before the out-of-combat delay elapses")

	# This tick crosses the delay threshold to exactly 0 — still no decay this frame.
	player._process(0.1)
	assert_eq(player.ability_meter, 50.0, "Meter should not decay on the exact frame the delay expires")

	# Delay has fully elapsed — subsequent ticks should now drain the bar.
	player._process(0.2)
	assert_lt(player.ability_meter, 50.0, "Meter should decay once out-of-combat delay has elapsed")

func test_meter_decay_stops_at_zero() -> void:
	player.ability_meter = 0.0
	player._meter_decay_timer = 0.0
	player._process(1.0)
	assert_eq(player.ability_meter, 0.0, "Meter should not go negative from decay")
