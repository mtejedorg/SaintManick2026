extends PlayerState

func _init() -> void:
	anim_key = "run"

func enter() -> void:
	if not player and owner:
		player = owner as PlayerController
	var anim := _anim()
	if anim:
		anim.play("run")

func physics_update(delta: float) -> void:
	player.apply_gravity(delta)
	
	var input_dir = player.get_movement_input()
	player.face_direction(input_dir.x if input_dir.x != 0 else input_dir.y) # Face roughly movement dir
	
	if input_dir != Vector2.ZERO:
		var path_dir = player.get_path_direction(input_dir)
		player.velocity.x = move_toward(player.velocity.x, path_dir.x * player.max_speed, player.acceleration * delta)
		player.velocity.z = move_toward(player.velocity.z, path_dir.z * player.max_speed, player.acceleration * delta)
	else:
		if player.current_path == null:
			# H3: top-down release -- start braking z here too (Idle finishes the job).
			player.velocity.z = move_toward(player.velocity.z, 0, player.friction * delta)
		transition_requested.emit("StateIdle")
		return
		
	player.move_and_slide()
	
	if not player.is_on_floor():
		# F10: walked off a ledge without jumping -> coyote time for a late ground jump.
		player.start_coyote_time()
		transition_requested.emit("StateAirborne")
		return

	# F10: presses arrive through the player's buffers (this frame's press included).
	if player.has_buffered_jump() and player.is_jump_enabled:
		transition_requested.emit("StateAirborne")
		return

	var dodge_state := player.take_buffered_dodge()
	if dodge_state != "":
		transition_requested.emit(dodge_state)
		return
		
	if player.take_buffered_attack():
		transition_requested.emit("StateAttack")
		return
