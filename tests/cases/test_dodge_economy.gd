extends "res://tests/framework/test_case.gd"

var player: PlayerController

func before_each() -> void:
	player = load("res://characters/player/player.tscn").instantiate()
	add_child(player)
	if not SignalBus.downbeat.is_connected(player._on_downbeat):
		SignalBus.downbeat.connect(player._on_downbeat)
	if not SignalBus.player_hit_landed.is_connected(player._on_player_hit_landed):
		SignalBus.player_hit_landed.connect(player._on_player_hit_landed)
	# Push the real Conductor autoload's primary layer to the middle of a beat so tests
	# that don't care about beat alignment aren't accidentally rewarded/exempted.
	Conductor.layers["primary"].time_accumulator = (60.0 / Conductor.bpm) * 0.5

func after_each() -> void:
	if is_instance_valid(player):
		player.queue_free()

func test_cooldown_blocks_immediate_redodge_from_idle() -> void:
	var fsm = player.state_machine
	var dash_state = fsm.get_node("StateDash")
	dash_state.enter()
	dash_state.exit()
	assert_false(player.can_dodge(), "Dodge cooldown should be active immediately after an unaligned dash exits")

func test_roll_is_vulnerable_during_recovery_tail() -> void:
	var fsm = player.state_machine
	var roll_state = fsm.get_node("StateRoll")
	roll_state.enter()
	assert_true(player.health_component.is_invincible, "Roll should grant i-frames on enter")

	# Drive just past the i-frame portion but still inside the recovery tail.
	roll_state.physics_update(roll_state.roll_iframe_duration + 0.01)
	assert_false(player.health_component.is_invincible, "Roll should lose invincibility once i-frames end, before the state exits")

func test_beat_aligned_dodge_grants_meter_and_skips_cooldown() -> void:
	Conductor.layers["primary"].time_accumulator = 0.0
	player.ability_meter = 0.0
	var fsm = player.state_machine
	var dash_state = fsm.get_node("StateDash")
	dash_state.enter()
	assert_eq(player.ability_meter, player.beat_aligned_dodge_meter, "Beat-aligned dash should grant the dodge meter reward")
	dash_state.exit()
	assert_true(player.can_dodge(), "Beat-aligned dash should skip starting the dodge cooldown")

func test_emp_dash_cancel_still_works_with_cooldown_active() -> void:
	player.start_dodge_cooldown()
	assert_false(player.can_dodge(), "Cooldown should be active")

	player.ability_meter = 25.0
	var fsm = player.state_machine
	var attack_state = fsm.get_node("StateAttack")
	var dash_state = fsm.get_node("StateDash")
	attack_state.enter()

	var cancelled = attack_state._try_emp_dash_cancel()

	assert_true(cancelled, "EMP Dash-Cancel should bypass the dodge cooldown check")
	assert_eq(fsm.current_state, dash_state, "EMP Dash-Cancel should transition to StateDash despite an active cooldown")
