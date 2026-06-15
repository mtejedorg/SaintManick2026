extends PlayerState

var is_jumping: bool = false

func enter() -> void:
	if Input.is_action_just_pressed("ui_accept") and player.is_on_floor():
		player.velocity.y = player.jump_force
		is_jumping = true
	else:
		is_jumping = false

func physics_update(delta: float) -> void:
	player.apply_gravity(delta)
	
	var input_dir = player.get_movement_input()
	player.face_direction(input_dir)
	
	if input_dir != 0:
		var path_dir = player.get_path_direction(input_dir)
		player.velocity.x = move_toward(player.velocity.x, path_dir.x * player.max_speed, player.acceleration * delta)
		player.velocity.z = move_toward(player.velocity.z, path_dir.z * player.max_speed, player.acceleration * delta)
	else:
		player.velocity.x = move_toward(player.velocity.x, 0, player.friction * delta * 0.5) # Less friction in air
		player.velocity.z = move_toward(player.velocity.z, 0, player.friction * delta * 0.5)
		
	# Double Jump logic
	if Input.is_action_just_pressed("ui_accept") and player.can_double_jump:
		player.velocity.y = player.jump_force
		player.can_double_jump = false
		
	# Air combos
	if Input.is_action_just_pressed("attack_light") or Input.is_action_just_pressed("attack_heavy"):
		transition_requested.emit("StateAttack")
		return
		
	player.move_and_slide()
	
	if player.is_on_floor():
		if input_dir != 0:
			transition_requested.emit("StateRun")
		else:
			transition_requested.emit("StateIdle")
