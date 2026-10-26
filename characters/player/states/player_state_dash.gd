extends PlayerState

@export var dash_duration: float = 0.25
var dash_timer: float = 0.0
var dash_direction: Vector2 = Vector2.RIGHT
## Set on enter() when the dash landed within the Conductor beat-align window; if true,
## exit() starts the shared dodge cooldown with the K3 refund (the reward-only bonus).
var _beat_aligned: bool = false

func enter() -> void:
	if not player and owner:
		player = owner as PlayerController
	if player:
		player.set_dodge_iframes(true) # K8: invincible and through enemy bodies
	dash_timer = dash_duration
	if player:
		player.clear_dodge_buffer() # this dodge used the press (EMP cancel included)
	var input_dir = player.get_movement_input() if player else Vector2.ZERO
	dash_direction = input_dir if input_dir != Vector2.ZERO else (Vector2.RIGHT if player and player.is_facing_right else Vector2.LEFT)
	if player:
		player.velocity.y = 0
	var anim := _anim()
	if anim:
		anim.play_fitted("dash", dash_duration)
	_beat_aligned = player.try_beat_aligned_dodge_reward() if player else false

func exit() -> void:
	if player:
		player.set_dodge_iframes(false)
	# EMP Dash-Cancel enters this state straight from StateAttack (bypassing can_dodge()),
	# but it's fine — and intended — for the cooldown to still start here on exit.
	if player:
		player.start_dodge_cooldown(_beat_aligned)
	# H3: top-down dash -- no residual z slide once it ends.
	if player and player.current_path == null:
		player.velocity.z = 0.0

func physics_update(delta: float) -> void:
	dash_timer -= delta

	var path_dir = player.get_path_direction(dash_direction)
	player.velocity.x = path_dir.x * player.dash_speed
	player.velocity.z = path_dir.z * player.dash_speed

	player.move_and_slide()

	if dash_timer <= 0:
		if not player.is_on_floor():
			transition_requested.emit("StateAirborne")
		elif player.take_buffered_attack():
			transition_requested.emit("StateAttack") # H3: attack latched during the dash
		else:
			transition_requested.emit("StateIdle")
