extends "res://tests/framework/test_case.gd"

# H3: real move_up/move_down actions, no top-down z slide after a release or a dodge, a
# clean respawn hand-off, play_once falling back to the current state clip, and attack
# presses latched through dodges / the last combo hit.

var _floor: StaticBody3D

func _spawn_player(pos: Vector3) -> PlayerController:
	var player: PlayerController = load("res://characters/player/player.tscn").instantiate()
	player.position = pos
	add_child(player)
	player.current_path = null
	return player

func _freeze(player: PlayerController) -> void:
	player.set_physics_process(false)
	player.state_machine.set_physics_process(false)

func _make_floor(top_center: Vector3) -> void:
	_floor = StaticBody3D.new()
	var shape := CollisionShape3D.new()
	var box := BoxShape3D.new()
	box.size = Vector3(20.0, 1.0, 20.0)
	shape.shape = box
	_floor.add_child(shape)
	add_child(_floor)
	_floor.global_position = top_center - Vector3(0.0, 0.5, 0.0)

## Nick standing on a fresh floor at origin, physics frozen (states stepped by hand).
func _grounded_player(origin: Vector3) -> PlayerController:
	_make_floor(origin - Vector3(0.0, 1.0, 0.0))
	var player := _spawn_player(origin)
	for i in 3:
		await get_tree().physics_frame
	_freeze(player)
	return player

func _state(player: PlayerController) -> String:
	return String(player.state_machine.current_state.name)

func after_each() -> void:
	super.after_each()
	Input.action_release("move_up")
	if is_instance_valid(_floor):
		_floor.queue_free()

func _has_key(action: String, physical_keycode: int) -> bool:
	for ev in InputMap.action_get_events(action):
		if ev is InputEventKey and (ev as InputEventKey).physical_keycode == physical_keycode:
			return true
	return false

func test_move_up_and_down_are_real_gameplay_actions() -> void:
	assert_true(InputMap.has_action("move_up") and InputMap.has_action("move_down"), "move_up/move_down exist")
	assert_true(_has_key("move_up", KEY_W) and _has_key("move_up", KEY_UP), "W and Up steer up")
	assert_true(_has_key("move_down", KEY_S) and _has_key("move_down", KEY_DOWN), "S and Down steer down")

func test_w_moves_nick_on_z_in_free_movement() -> void:
	var player: PlayerController = await _grounded_player(Vector3(0.0, 0.0, 7000.0))
	var start_z := player.global_position.z
	Input.action_press("move_up")
	assert_eq(player.get_movement_input(), Vector2(0.0, -1.0), "W (move_up) reads as up in free movement")
	player.state_machine._on_transition_requested("StateRun")
	var run = player.state_machine.current_state
	for i in 10:
		run.physics_update(0.05)
	Input.action_release("move_up")
	assert_lt(player.velocity.z, 0.0, "Run drives Nick toward -z")
	assert_lt(player.global_position.z, start_z - 0.1, "...and he actually moves on z (%.2f)" % (player.global_position.z - start_z))
	player.queue_free()

func test_idle_brakes_residual_z_velocity_in_top_down() -> void:
	var player: PlayerController = await _grounded_player(Vector3(0.0, 0.0, 7020.0))
	assert_eq(_state(player), "StateIdle")
	var idle = player.state_machine.current_state
	player.velocity.z = 8.0
	var t := 0.0
	while t < 0.3:
		idle.physics_update(1.0 / 60.0)
		t += 1.0 / 60.0
	assert_lt(absf(player.velocity.z), 0.1, "Idle damps z with the ground friction (z %.2f)" % player.velocity.z)
	player.queue_free()

func test_dodge_exit_clears_residual_z_in_top_down() -> void:
	var player: PlayerController = await _grounded_player(Vector3(0.0, 0.0, 7040.0))
	player.state_machine._on_transition_requested("StateDash")
	player.velocity.z = player.dash_speed
	player.state_machine._on_transition_requested("StateIdle")
	assert_eq(player.velocity.z, 0.0, "Leaving a top-down dash leaves no z slide")
	player._dodge_cooldown_timer = 0.0
	player.state_machine._on_transition_requested("StateRoll")
	player.velocity.z = -player.roll_speed
	player.state_machine._on_transition_requested("StateIdle")
	assert_eq(player.velocity.z, 0.0, "...same for a roll")
	player.queue_free()

func test_respawn_resets_state_buffers_and_bass_drop() -> void:
	var player: PlayerController = await _grounded_player(Vector3(0.0, 0.0, 7060.0))
	player.ability_meter = PlayerController.MAX_ABILITY_METER
	assert_true(player.try_arm_bass_drop(), "Bass Drop armed")
	player.state_machine._on_transition_requested("StateDash")
	player.buffer_jump()
	player.start_coyote_time()
	player.buffer_dodge("StateRoll")
	player.buffer_attack(true)
	player.start_dodge_cooldown()
	player.velocity = Vector3(5.0, 3.0, 2.0)
	player.health_component.is_invincible = true # the GameManager respawn grace
	var got := {"armed": true}
	var on_armed := func(armed: bool): got.armed = armed
	SignalBus.bass_drop_armed.connect(on_armed)

	SignalBus.player_respawned.emit()

	assert_false(player.bass_drop_armed, "Respawn disarms Bass Drop")
	assert_false(got.armed, "...and tells the HUD")
	assert_eq(_state(player), "StateIdle", "Respawn hands Nick back in Idle")
	assert_false(player.has_buffered_jump(), "Jump buffer cleared")
	assert_false(player.has_coyote_time(), "Coyote time cleared")
	assert_eq(player.take_buffered_dodge(), "", "Dodge buffer cleared")
	assert_false(player.has_buffered_attack(), "Attack buffer cleared")
	assert_true(player.can_dodge(), "Dodge cooldown zeroed")
	assert_eq(player.velocity, Vector3.ZERO, "At rest")
	assert_true(player.health_component.is_invincible, "The dash exit must not cancel the respawn grace")
	assert_eq(String(player.animation_controller.anim_player.current_animation), "idle", "Idle clip playing")
	SignalBus.bass_drop_armed.disconnect(on_armed)
	player.queue_free()

func test_play_once_falls_back_to_the_current_state_clip() -> void:
	var player: PlayerController = await _grounded_player(Vector3(0.0, 0.0, 7080.0))
	player.state_machine._on_transition_requested("StateRun")
	var ctrl := player.animation_controller
	ctrl.play_once("hit_react")
	assert_eq(String(ctrl.anim_player.current_animation), "hit_react")
	ctrl.anim_player.animation_finished.emit(&"hit_react")
	assert_eq(String(ctrl.anim_player.current_animation), "run", "A hit react while running resumes the run clip")
	player.queue_free()

func test_heavy_pressed_during_a_dash_fires_a_heavy_attack() -> void:
	var player: PlayerController = await _grounded_player(Vector3(0.0, 0.0, 7100.0))
	player.state_machine._on_transition_requested("StateDash")
	var dash = player.state_machine.current_state
	player.buffer_attack(true)
	dash.dash_timer = 0.01
	dash.physics_update(0.02)
	assert_eq(_state(player), "StateAttack", "The latched press fires when the dash ends")
	var attack = player.state_machine.current_state
	assert_eq(attack.current_sequence, ["B"] as Array[String], "...as a heavy")
	assert_false(player.has_buffered_attack(), "The press was used")
	player.queue_free()

func test_attack_buffer_expires() -> void:
	var player := _spawn_player(Vector3(0.0, 50.0, 7120.0))
	_freeze(player)
	player.buffer_attack(false)
	player._tick_input_buffers(0.16)
	assert_false(player.take_buffered_attack(), "An attack press older than 0.15 s is dropped")
	player.queue_free()

func test_press_in_the_last_hit_recovery_starts_a_new_chain() -> void:
	var player: PlayerController = await _grounded_player(Vector3(0.0, 0.0, 7140.0))
	player.state_machine._on_transition_requested("StateAttack")
	var attack = player.state_machine.current_state
	attack.max_combo_step = attack.combo_step # capped: the combo window cannot take the press
	attack.attack_timer = 0.05
	player.buffer_attack(true)
	attack.physics_update(0.1)
	assert_eq(_state(player), "StateAttack", "The latched press is not dropped at the end of the chain")
	assert_eq(attack.combo_step, 0, "...it starts a fresh chain")
	assert_eq(attack.current_sequence, ["B"] as Array[String], "...with the latched heavy")
	assert_gt(attack.attack_timer, 0.0, "...that is running")
	player.queue_free()
