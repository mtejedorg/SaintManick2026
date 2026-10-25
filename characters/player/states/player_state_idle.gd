extends PlayerState

func _init() -> void:
	anim_key = "idle"

func enter() -> void:
	if not player and owner:
		player = owner as PlayerController
	var anim := _anim()
	if anim:
		anim.play("idle")

func physics_update(delta: float) -> void:
	player.apply_gravity(delta)
	
	player.velocity.x = move_toward(player.velocity.x, 0, player.friction * delta)
	# H3: top-down has a free z axis -- without this Nick slid on after a release.
	player.velocity.z = move_toward(player.velocity.z, 0, player.friction * delta)
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

	if player.get_movement_input() != Vector2.ZERO:
		transition_requested.emit("StateRun")
