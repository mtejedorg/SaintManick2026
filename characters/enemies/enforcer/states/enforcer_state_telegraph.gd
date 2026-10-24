extends EnforcerState

func enter() -> void:
	enforcer.is_shield_active = false
	if enforcer.shield_bubble:
		enforcer.shield_bubble.visible = false
	enforcer.character_visual.flash_telegraph()
	enforcer.velocity.x = 0
	enforcer.velocity.z = 0

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
