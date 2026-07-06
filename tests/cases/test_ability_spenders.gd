extends "res://tests/framework/test_case.gd"

var player: PlayerController

func before_each() -> void:
	player = load("res://characters/player/player.tscn").instantiate()
	add_child(player)
	# Test framework's after_each() disconnects ALL SignalBus connections — reconnect
	# what player.gd wires in _ready() so spender logic (Bass Drop arms via input,
	# detonates on downbeat) works under test.
	if not SignalBus.downbeat.is_connected(player._on_downbeat):
		SignalBus.downbeat.connect(player._on_downbeat)
	if not SignalBus.player_hit_landed.is_connected(player._on_player_hit_landed):
		SignalBus.player_hit_landed.connect(player._on_player_hit_landed)

func after_each() -> void:
	if is_instance_valid(player):
		player.queue_free()

func test_emp_dash_cancel_consumes_meter_and_transitions_to_dash() -> void:
	player.ability_meter = 25.0
	var fsm = player.state_machine
	var attack_state = fsm.get_node("StateAttack")
	var dash_state = fsm.get_node("StateDash")
	assert_not_null(dash_state, "Player should have StateDash node")

	attack_state.enter()

	var cancelled = attack_state._try_emp_dash_cancel()

	assert_true(cancelled, "EMP Dash-Cancel should succeed with 25 meter available")
	assert_eq(player.ability_meter, 0.0, "EMP Dash-Cancel should consume the full 25 meter")
	assert_eq(fsm.current_state, dash_state, "EMP Dash-Cancel should transition straight to StateDash")

func test_emp_dash_cancel_fails_without_enough_meter() -> void:
	player.ability_meter = 10.0
	var fsm = player.state_machine
	var attack_state = fsm.get_node("StateAttack")

	attack_state.enter()

	var cancelled = attack_state._try_emp_dash_cancel()

	assert_false(cancelled, "EMP Dash-Cancel should fail with only 10 meter")
	assert_eq(player.ability_meter, 10.0, "Insufficient meter should not be consumed")
	assert_ne(fsm.current_state, fsm.get_node("StateDash"), "Should not transition to StateDash without enough meter")

func assert_ne(actual, not_expected, msg: String = "") -> void:
	if actual == not_expected:
		_fail(msg if msg != "" else "Expected values to differ, but they were equal")

func test_hitbox_disabled_during_recovery_window() -> void:
	var fsm = player.state_machine
	var attack_state = fsm.get_node("StateAttack")
	attack_state.enter()
	attack_state.current_hit_duration = 1.0
	# Still inside the active window (60% of duration).
	attack_state.attack_timer = 0.5
	attack_state.physics_update(0.0)
	assert_true(player.katana_hitbox.is_active, "Hitbox should still be active mid-attack")

	# Past the active window -> recovery.
	attack_state.attack_timer = 0.3
	attack_state.physics_update(0.0)
	assert_false(player.katana_hitbox.is_active, "Hitbox should switch off once recovery starts")

func test_bass_drop_arms_only_at_full_meter() -> void:
	player.ability_meter = 99.0
	assert_false(player.try_arm_bass_drop(), "Bass Drop should not arm below full meter")
	assert_false(player.bass_drop_armed)

	player.ability_meter = player.MAX_ABILITY_METER
	assert_true(player.try_arm_bass_drop(), "Bass Drop should arm at full meter")
	assert_true(player.bass_drop_armed)

func test_bass_drop_detonates_on_downbeat_and_resets_meter() -> void:
	player.ability_meter = player.MAX_ABILITY_METER
	player.try_arm_bass_drop()
	assert_true(player.bass_drop_armed)

	SignalBus.downbeat.emit("primary", 1)

	assert_false(player.bass_drop_armed, "Bass Drop should consume the arm state on downbeat")
	assert_eq(player.ability_meter, 0.0, "Bass Drop should zero the meter on detonation")

func test_bass_drop_does_not_detonate_without_arming() -> void:
	player.ability_meter = 50.0
	SignalBus.downbeat.emit("primary", 1)
	assert_eq(player.ability_meter, 50.0, "Downbeat should not affect meter unless Bass Drop is armed")

func test_bass_drop_damages_enemies_in_radius() -> void:
	var bruiser = load("res://characters/enemies/bruiser/bruiser.tscn").instantiate()
	add_child(bruiser)
	bruiser.global_position = player.global_position + Vector3(2, 0, 0)

	var far_bruiser = load("res://characters/enemies/bruiser/bruiser.tscn").instantiate()
	add_child(far_bruiser)
	far_bruiser.global_position = player.global_position + Vector3(50, 0, 0)

	var health = bruiser.get_node("HealthComponent")
	var far_health = far_bruiser.get_node("HealthComponent")
	var starting_shield = health.current_shield

	player.ability_meter = player.MAX_ABILITY_METER
	player.try_arm_bass_drop()
	SignalBus.downbeat.emit("primary", 1)

	assert_lt(health.current_shield + health.current_health, starting_shield + bruiser.stats.max_health, "In-range enemy should take Bass Drop damage")
	assert_eq(far_health.current_shield, far_health.max_shield, "Out-of-range enemy should be untouched")

	bruiser.queue_free()
	far_bruiser.queue_free()
