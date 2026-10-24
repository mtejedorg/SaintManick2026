extends "res://tests/framework/test_case.gd"

## F10: coyote time (0.10 s), jump buffer (0.12 s) and dodge buffer (0.15 s). Driven by hand:
## the player and its StateMachine have physics processing switched off so the engine
## never steps the states between the assertions.

var _floor: StaticBody3D

func _spawn_player(pos: Vector3) -> PlayerController:
	var player: PlayerController = load("res://characters/player/player.tscn").instantiate()
	player.position = pos
	add_child(player)
	player.current_path = null
	player.double_jump_unlocked = false
	player.can_double_jump = false
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

func _state(player: PlayerController) -> String:
	return String(player.state_machine.current_state.name)

func after_each() -> void:
	super.after_each()
	if is_instance_valid(_floor):
		_floor.queue_free()

func test_coyote_time_allows_a_late_ground_jump() -> void:
	var player := _spawn_player(Vector3(0.0, 50.0, 6000.0)) # nothing underneath
	_freeze(player)
	player.state_machine._on_transition_requested("StateIdle")
	var idle = player.state_machine.current_state
	idle.physics_update(0.016)
	assert_eq(_state(player), "StateAirborne", "Walking off the floor enters StateAirborne")
	assert_true(player.has_coyote_time(), "Leaving the floor without jumping starts coyote time")

	player._tick_input_buffers(0.05) # still inside the 0.10 s window
	player.buffer_jump()
	player.state_machine.current_state.physics_update(0.016)
	assert_gt(player.velocity.y, player.jump_force * 0.9, "A jump inside coyote time is a full ground jump")
	assert_false(player.has_coyote_time(), "The coyote jump uses up the window")
	assert_false(player.has_buffered_jump(), "...and the press")
	player.queue_free()

func test_coyote_time_expires() -> void:
	var player := _spawn_player(Vector3(0.0, 50.0, 6020.0))
	_freeze(player)
	player.state_machine._on_transition_requested("StateIdle")
	player.state_machine.current_state.physics_update(0.016)
	player._tick_input_buffers(0.11) # past the 0.10 s window
	player.buffer_jump()
	player.state_machine.current_state.physics_update(0.016)
	assert_lt(player.velocity.y, player.jump_force * 0.5, "After coyote time (and without a double jump) the press does not jump")
	assert_true(player.has_buffered_jump(), "The unused press stays buffered for a landing")
	player.queue_free()

func test_jump_pressed_just_before_landing_fires_on_landing() -> void:
	var origin := Vector3(0.0, 0.0, 6040.0)
	_make_floor(origin - Vector3(0.0, 1.0, 0.0)) # capsule bottom rests on y = -1
	var player := _spawn_player(origin)
	for i in 3:
		await get_tree().physics_frame
	assert_true(player.is_on_floor(), "Precondition: Nick stands on the floor")
	_freeze(player)
	player.state_machine._on_transition_requested("StateAirborne") # e.g. the last frame of a fall
	assert_false(player.has_buffered_jump(), "Precondition: no buffered jump")

	player.buffer_jump()           # pressed a moment before touching down
	player._tick_input_buffers(0.1) # still inside the 0.12 s buffer
	player.state_machine.current_state.physics_update(0.016)
	assert_eq(_state(player), "StateAirborne", "The buffered jump fires on landing instead of settling into Idle")
	assert_almost_eq(player.velocity.y, player.jump_force, 0.001, "...with a full ground jump")
	player.queue_free()

func test_jump_buffer_expires() -> void:
	var player := _spawn_player(Vector3(0.0, 50.0, 6060.0))
	_freeze(player)
	player.buffer_jump()
	player._tick_input_buffers(0.13)
	assert_false(player.has_buffered_jump(), "A press older than 0.12 s is dropped")
	player.queue_free()

func test_dodge_pressed_during_cooldown_fires_when_allowed() -> void:
	var origin := Vector3(0.0, 0.0, 6080.0)
	_make_floor(origin - Vector3(0.0, 1.0, 0.0))
	var player := _spawn_player(origin)
	for i in 3:
		await get_tree().physics_frame
	_freeze(player)
	player.state_machine._on_transition_requested("StateIdle")
	var idle = player.state_machine.current_state

	player.start_dodge_cooldown()
	player.buffer_dodge("StateRoll")
	idle.physics_update(0.016)
	assert_eq(_state(player), "StateIdle", "No roll while the dodge cooldown runs")

	player._dodge_cooldown_timer = 0.0 # cooldown ends 0.1 s later, inside the buffer
	player._tick_input_buffers(0.1)
	idle.physics_update(0.016)
	assert_eq(_state(player), "StateRoll", "The buffered roll fires as soon as the cooldown allows")
	assert_eq(player.take_buffered_dodge(), "", "Entering the roll consumed the buffer")
	player.queue_free()

func test_dodge_pressed_during_attack_recovery_fires_when_the_attack_ends() -> void:
	var origin := Vector3(0.0, 0.0, 6100.0)
	_make_floor(origin - Vector3(0.0, 1.0, 0.0))
	var player := _spawn_player(origin)
	for i in 3:
		await get_tree().physics_frame
	_freeze(player)
	player.state_machine._on_transition_requested("StateAttack")
	var attack = player.state_machine.current_state
	attack.attack_timer = 0.05 # in recovery, about to end
	player.buffer_dodge("StateDash")
	attack.physics_update(0.1)
	assert_eq(_state(player), "StateDash", "A dash buffered during recovery fires the moment the attack ends")
	player.queue_free()

func test_dodge_buffer_expires() -> void:
	var player := _spawn_player(Vector3(0.0, 50.0, 6120.0))
	_freeze(player)
	player.buffer_dodge("StateDash")
	player._tick_input_buffers(0.16)
	assert_eq(player.take_buffered_dodge(), "", "A dodge press older than 0.15 s is dropped")
	player.queue_free()
