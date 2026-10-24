extends EnforcerState

const BodyFacing = preload("res://characters/shared/body_facing.gd")

func enter() -> void:
	enforcer.is_shield_active = true
	if enforcer.shield_bubble:
		enforcer.shield_bubble.visible = true

func exit() -> void:
	enforcer.is_shield_active = false
	if enforcer.shield_bubble:
		enforcer.shield_bubble.visible = false

func physics_update(delta: float) -> void:
	enforcer.apply_gravity(delta)
	
	if enforcer.player:
		# F8: ease the yaw toward Nick (mesh faces +Z) instead of snapping; never pitch.
		BodyFacing.turn_toward(enforcer, enforcer.player.global_position, EnforcerEnemy.TURN_RATE, delta)
			
		var dist = enforcer.global_position.distance_to(enforcer.player.global_position)
		if dist > 3.0:
			var dir = (enforcer.player.global_position - enforcer.global_position).normalized()
			dir.y = 0
			enforcer.velocity.x = dir.x * enforcer.stats.speed
			enforcer.velocity.z = dir.z * enforcer.stats.speed
		else:
			enforcer.velocity.x = move_toward(enforcer.velocity.x, 0, 10.0 * delta)
			enforcer.velocity.z = move_toward(enforcer.velocity.z, 0, 10.0 * delta)
	else:
		enforcer.velocity.x = move_toward(enforcer.velocity.x, 0, 10.0 * delta)
		enforcer.velocity.z = move_toward(enforcer.velocity.z, 0, 10.0 * delta)
		
	enforcer.move_and_slide()

func on_beat(layer: String, beat_index: int) -> void:
	if layer != "primary":
		return
		
	if beat_index == 1 and enforcer.player:
		var dist = enforcer.global_position.distance_to(enforcer.player.global_position)
		if dist <= 4.0:
			state_machine.transition_to("StateTelegraph")

func on_shield_broken() -> void:
	var state_recovery = state_machine.states.get("StateRecovery")
	if state_recovery:
		state_recovery.is_from_shield_break = true
	state_machine.transition_to("StateRecovery")
