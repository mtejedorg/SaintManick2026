extends PlayerState

func physics_update(delta: float) -> void:
	player.apply_gravity(delta)
	
	var input_dir = player.get_movement_input()
	player.face_direction(input_dir)
	
	if input_dir != 0:
		var path_dir = player.get_path_direction(input_dir)
		player.velocity.x = move_toward(player.velocity.x, path_dir.x * player.max_speed, player.acceleration * delta)
		player.velocity.z = move_toward(player.velocity.z, path_dir.z * player.max_speed, player.acceleration * delta)
	else:
		transition_requested.emit("StateIdle")
		return
		
	player.move_and_slide()
	
	if not player.is_on_floor():
		transition_requested.emit("StateAirborne")
		return
		
	if Input.is_action_just_pressed("ui_accept"):
		transition_requested.emit("StateAirborne")
		return
		
	if Input.is_action_just_pressed("dash"):
		transition_requested.emit("StateDash")
		return
		
	if Input.is_action_just_pressed("roll"):
		transition_requested.emit("StateRoll")
		return
		
	if Input.is_action_just_pressed("attack_light") or Input.is_action_just_pressed("attack_heavy"):
		transition_requested.emit("StateAttack")
		return
