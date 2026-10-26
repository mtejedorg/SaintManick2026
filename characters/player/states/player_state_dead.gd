extends PlayerState

## K11 (D20): the death beat. Entered (deferred) from PlayerController._on_died on the
## lethal hit; holds the death clip with no input until the respawn hands Nick back to
## StateIdle (_on_player_respawned) or the game over changes the scene. Gravity and
## friction still run so he settles on the floor. Never leaves on its own.

func _init() -> void:
	anim_key = "" # no resting clip: a flinch never plays over the death clip

func enter() -> void:
	if not player and owner:
		player = owner as PlayerController
	if player:
		player.velocity.x = 0.0
		player.velocity.z = 0.0
	var anim := _anim()
	if anim:
		anim.play("death") # held -- no fallback to idle when it ends

func physics_update(delta: float) -> void:
	player.apply_gravity(delta)
	player.velocity.x = move_toward(player.velocity.x, 0.0, player.friction * delta)
	player.velocity.z = move_toward(player.velocity.z, 0.0, player.friction * delta)
	player.move_and_slide()
