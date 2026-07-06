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
	assert_true(player.katana_hitbox.damage_info.is_shield_breaker, "Heavy hit should still be a shield breaker")

func test_battery_ram_sets_guard_breaking_at_zero_meter() -> void:
	# BB (Battery Ram) must be reachable with an empty meter and must set is_guard_breaking —
	# it's the answer to Bruiser's shield, and the meter must never block it.
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
	assert_true(player.katana_hitbox.damage_info.is_guard_breaking, "Battery Ram should set is_guard_breaking")
