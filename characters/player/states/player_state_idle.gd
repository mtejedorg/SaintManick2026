extends PlayerState

func physics_update(delta: float) -> void:
	player.apply_gravity(delta)
	
	player.velocity.x = move_toward(player.velocity.x, 0, player.friction * delta)
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

	if player.get_movement_input() != 0:
		transition_requested.emit("StateRun")
