extends PlayerState

## I1: Nick's stagger. Entered from PlayerController._on_damaged when a hit that got through
## carries stun (i-frames and the respawn grace block the hit before it ever gets here).
## Applies the hit's knockback away from its source, ignores input for the stun, then hands
## back to Idle/Airborne. Zero-stun hits never come here (plain flinch clip).

## The longest a stagger ever locks Nick out -- never a whole beat.
@export var max_stun: float = 0.4
## Deceleration (m/s^2) of the knockback slide while staggered.
@export var knockback_friction: float = 20.0

var hurt_timer: float = 0.0

func _init() -> void:
	anim_key = ""

func enter() -> void:
	if not player and owner:
		player = owner as PlayerController
	var info: DamageInfo = player.pending_hurt if player else null
	if player:
		player.pending_hurt = null
	hurt_timer = minf(info.stun, max_stun) if info else 0.0
	if player:
		# Presses made before the hit must not fire the moment the stagger ends.
		player.clear_attack_buffer()
		player.clear_dodge_buffer()
		player.consume_jump_buffer()
		player.pending_attack_heavy = false
		if info:
			_apply_knockback(info)
	var anim := _anim()
	if anim and hurt_timer > 0.0:
		anim.play_fitted("hit_react", hurt_timer)

## Away from the source on x (the rail plane); off-rail (top-down) on x and z.
func _apply_knockback(info: DamageInfo) -> void:
	var away := Vector3.ZERO
	if is_instance_valid(info.source):
		away = player.global_position - info.source.global_position
	away.y = 0.0
	if player.current_path != null:
		away.z = 0.0
	if away.length() < 0.001:
		# No usable source: pushed back against the way Nick faces.
		away = Vector3(-1.0 if player.is_facing_right else 1.0, 0.0, 0.0)
	away = away.normalized()
	player.velocity.x = away.x * info.knockback
	player.velocity.z = away.z * info.knockback

func physics_update(delta: float) -> void:
	player.apply_gravity(delta)
	player.velocity.x = move_toward(player.velocity.x, 0.0, knockback_friction * delta)
	player.velocity.z = move_toward(player.velocity.z, 0.0, knockback_friction * delta)
	player.move_and_slide()

	hurt_timer -= delta
	if hurt_timer <= 0.0:
		transition_requested.emit("StateIdle" if player.is_on_floor() else "StateAirborne")
