extends PlayerState

var is_jumping: bool = false

func enter() -> void:
	if not player and owner:
		player = owner as PlayerController
	is_jumping = false
	if player and player.is_jump_enabled and player.is_on_floor() and player.consume_jump_buffer():
		_ground_jump()
	else:
		var anim := _anim()
		if anim:
			anim.play("fall")

## A jump off the ground (or within coyote time): does not spend the double jump.
func _ground_jump() -> void:
	player.velocity.y = player.jump_force
	player.clear_coyote_time()
	is_jumping = true
	var anim := _anim()
	if anim:
		anim.play("jump")

func physics_update(delta: float) -> void:
	player.apply_gravity(delta)
	
	var input_dir = player.get_movement_input()
	player.face_direction(input_dir.x if input_dir.x != 0 else input_dir.y)
	
	if input_dir != Vector2.ZERO:
		var path_dir = player.get_path_direction(input_dir)
		player.velocity.x = move_toward(player.velocity.x, path_dir.x * player.max_speed, player.acceleration * delta)
		player.velocity.z = move_toward(player.velocity.z, path_dir.z * player.max_speed, player.acceleration * delta)
	else:
		player.velocity.x = move_toward(player.velocity.x, 0, player.friction * delta * 0.5) # Less friction in air
		player.velocity.z = move_toward(player.velocity.z, 0, player.friction * delta * 0.5)
		
	# F10: coyote ground jump first, then the double jump. A press neither can use stays
	# buffered and fires on landing (below).
	if player.has_buffered_jump() and player.is_jump_enabled:
		if player.has_coyote_time():
			player.consume_jump_buffer()
			_ground_jump()
		elif player.can_double_jump:
			player.consume_jump_buffer()
			player.velocity.y = player.jump_force
			player.can_double_jump = false
		
	# Air combos
	if Input.is_action_just_pressed("attack_light") or Input.is_action_just_pressed("attack_heavy"):
		transition_requested.emit("StateAttack")
		return
		
	player.move_and_slide()
	
	if player.is_on_floor():
		# F10: a jump pressed just before touching down fires on landing.
		if player.is_jump_enabled and player.consume_jump_buffer():
			_ground_jump()
			return
		if input_dir != Vector2.ZERO:
			transition_requested.emit("StateRun")
		else:
			transition_requested.emit("StateIdle")
