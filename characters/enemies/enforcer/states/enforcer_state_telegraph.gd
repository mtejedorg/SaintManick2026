extends EnforcerState

func enter() -> void:
	enforcer.is_shield_active = false
	if enforcer.shield_bubble:
		enforcer.shield_bubble.visible = false
	enforcer.character_visual.flash_telegraph()
	enforcer.character_visual.lean_forward(EnforcerEnemy.TELEGRAPH_LEAN_DEGREES, 60.0 / maxf(Conductor.bpm, 1.0))
	enforcer.velocity.x = 0
	enforcer.velocity.z = 0
	# U2: where the 3-hit burst will land, until the hitbox arms (the next state).
	enforcer.show_telegraph_zone()

func exit() -> void:
	enforcer.hide_telegraph_zone()

func physics_update(delta: float) -> void:
	enforcer.apply_gravity(delta)
	enforcer.velocity.x = move_toward(enforcer.velocity.x, 0, 10.0 * delta)
	enforcer.velocity.z = move_toward(enforcer.velocity.z, 0, 10.0 * delta)
	enforcer.move_and_slide()

func on_beat(layer: String, beat_index: int) -> void:
	if layer != "primary":
		return
		
	if beat_index == 2:
		state_machine.transition_to("State3HitBurst")
