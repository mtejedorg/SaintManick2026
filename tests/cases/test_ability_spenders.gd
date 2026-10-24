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
	# T1: a fresh Conductor sits at time_accumulator == 0.0, which reads as beat-aligned.
	# Push it to mid-beat so entering StateDash here doesn't incidentally trigger the
	# beat-aligned dodge reward (that behavior has its own coverage in test_dodge_economy.gd).
	Conductor.layers["primary"].time_accumulator = (60.0 / Conductor.bpm) * 0.5

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

# F9: the armed cue — signal for the HUD, white-hot rim while armed, hit-stop + shock ring on
# detonation.
func test_arming_bass_drop_emits_the_armed_signal_and_holds_a_white_rim() -> void:
	var got := {"armed": []}
	var on_armed := func(a: bool): got.armed.append(a)
	SignalBus.bass_drop_armed.connect(on_armed)
	player.ability_meter = player.MAX_ABILITY_METER
	player.try_arm_bass_drop()
	assert_eq(got.armed, [true], "Arming emits bass_drop_armed(true)")
	assert_eq(player.character_visual.get_base_rim_color(), Color.WHITE, "Armed Nick rests at a white rim")
	assert_almost_eq(player.character_visual.get_base_rim_strength(), 5.0, 0.001, "...at strength 5")

	var stops := {"n": 0}
	var on_stop := func(d, _s): if is_equal_approx(d, 0.12): stops.n += 1
	SignalBus.hit_stop_requested.connect(on_stop)
	SignalBus.downbeat.emit("primary", 1)
	SignalBus.bass_drop_armed.disconnect(on_armed)
	SignalBus.hit_stop_requested.disconnect(on_stop)
	Engine.time_scale = 1.0
	var hs = get_node_or_null("/root/HitStop")
	if hs:
		hs.hit_stop_timer = 0.0

	assert_eq(got.armed, [true, false], "Detonation emits bass_drop_armed(false)")
	assert_eq(stops.n, 1, "Detonation requests a 0.12 s hit-stop")
	assert_eq(player.character_visual.get_base_rim_color(), CharacterVisual.PLAYER_RIM_COLOR, "The cyan rim returns after detonation")
	var ring: MeshInstance3D = get_node_or_null("BassDropRing")
	assert_not_null(ring, "Detonation spawns a shock ring next to Nick")
	if ring:
		assert_almost_eq(ring.global_position.y, player.global_position.y - 1.0, 0.01, "The ring sits at Nick's feet")
		await get_tree().create_timer(0.45).timeout
		assert_false(is_instance_valid(ring), "The ring frees itself after growing to the radius")
