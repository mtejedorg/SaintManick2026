extends PlayerState

## T4: a touchdown faster than this (m/s of downward speed) plays the "land" crouch clip,
## fitted to LAND_FIT_SECONDS (the clip is in the library and the controller's map since R).
const LAND_MIN_FALL_SPEED := 6.0
const LAND_FIT_SECONDS := 0.2

var is_jumping: bool = false

func _init() -> void:
	anim_key = "fall"

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
		elif player.can_double_jump and player.is_double_jump_available():
			# Q3: GameManager (demo mode) or the profile decides the Double Jump.
			player.consume_jump_buffer()
			player.velocity.y = player.jump_force
			player.can_double_jump = false
		
	# Air combos
	if player.take_buffered_attack():
		transition_requested.emit("StateAttack")
		return
		
	var fall_speed := -player.velocity.y # move_and_slide() zeroes it on touchdown
	player.move_and_slide()
	
	if player.is_on_floor():
		# F10: a jump pressed just before touching down fires on landing.
		if player.is_jump_enabled and player.consume_jump_buffer():
			_ground_jump()
			return
		# H3: an attack latched just before touchdown fires on landing.
		if player.take_buffered_attack():
			transition_requested.emit("StateAttack")
			return
		if input_dir != Vector2.ZERO:
			transition_requested.emit("StateRun")
		else:
			transition_requested.emit("StateIdle")
		# The next state's enter() has just started its own clip; the landing crouch plays
		# over it and the controller hands back to that state's resting clip when done.
		_play_landing(fall_speed)

## T4: the impact crouch of a hard landing (no-op without the clip or a controller).
func _play_landing(fall_speed: float) -> void:
	if fall_speed <= LAND_MIN_FALL_SPEED:
		return
	var anim := _anim()
	if anim and anim.animation_map.has("land"):
		anim.play_fitted("land", LAND_FIT_SECONDS)
