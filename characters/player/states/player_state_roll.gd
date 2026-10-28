extends PlayerState

## GDD §3.2: roll grants i-frames for the first portion only; the tail is a vulnerable
## recovery window so it can't be chained into permanent invincibility.
@export var roll_iframe_duration: float = 0.45
@export var roll_recovery_duration: float = 0.2

var roll_timer: float = 0.0
var roll_direction: Vector2 = Vector2.RIGHT
var _iframes_ended: bool = false
## Set on enter() when the roll landed within the Conductor beat-align window; if true,
## exit() starts the shared dodge cooldown with the K3 refund (the reward-only bonus).
var _beat_aligned: bool = false

func enter() -> void:
	if not player and owner:
		player = owner as PlayerController
	roll_timer = roll_iframe_duration + roll_recovery_duration
	player.clear_dodge_buffer() # this dodge used the press
	_iframes_ended = false
	var input_dir = player.get_movement_input()
	roll_direction = input_dir if input_dir != Vector2.ZERO else (Vector2.RIGHT if player.is_facing_right else Vector2.LEFT)
	player.face_direction(roll_direction.x if roll_direction.x != 0 else roll_direction.y)
	var anim := _anim()
	if anim:
		anim.play_fitted("roll", roll_iframe_duration + roll_recovery_duration)
	player.set_dodge_iframes(true) # K8: invincible and through enemy bodies
	_beat_aligned = player.try_beat_aligned_dodge_reward()

func exit() -> void:
	player.set_dodge_iframes(false)
	player.start_dodge_cooldown(_beat_aligned)
	# H3: top-down roll -- no residual z slide once it ends.
	if player.current_path == null:
		player.velocity.z = 0.0

func physics_update(delta: float) -> void:
	player.apply_gravity(delta)

	roll_timer -= delta

	var total_duration = roll_iframe_duration + roll_recovery_duration
	var elapsed = total_duration - roll_timer
	if not _iframes_ended and elapsed >= roll_iframe_duration:
		_iframes_ended = true
		player.set_dodge_iframes(false) # K8: the vulnerable tail collides with enemies again

	var path_dir = player.get_path_direction(roll_direction)
	player.velocity.x = path_dir.x * player.tuning.roll_speed
	player.velocity.z = path_dir.z * player.tuning.roll_speed

	player.move_and_slide()

	if roll_timer <= 0:
		if not player.is_on_floor():
			transition_requested.emit("StateAirborne")
		elif player.take_buffered_attack():
			transition_requested.emit("StateAttack") # H3: attack latched during the roll
		else:
			transition_requested.emit("StateIdle")
