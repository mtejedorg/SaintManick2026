extends HeadlinerState

func enter() -> void:
	boss.is_shield_active = true
	if boss.shield_bubble:
		boss.shield_bubble.visible = true

func exit() -> void:
	# Note: do not set is_shield_active to false here if we want shield logic to persist,
	# but telegraph/melee usually disables shield as per the design notes.
	boss.is_shield_active = false
	if boss.shield_bubble:
		boss.shield_bubble.visible = false

func physics_update(delta: float) -> void:
	boss.apply_gravity(delta)
	
	if boss.player:
		var target_pos = boss.player.global_position
		target_pos.y = boss.global_position.y
		if boss.global_position.distance_to(target_pos) > 0.1:
			boss.look_at(target_pos, Vector3.UP)
			
		var dist = boss.global_position.distance_to(boss.player.global_position)
		if dist > 3.0:
			var dir = (boss.player.global_position - boss.global_position).normalized()
			dir.y = 0
			var speed = boss.stats.speed * boss.speed_multiplier
			boss.velocity.x = dir.x * speed
			boss.velocity.z = dir.z * speed
		else:
			boss.velocity.x = move_toward(boss.velocity.x, 0, 10.0 * delta)
			boss.velocity.z = move_toward(boss.velocity.z, 0, 10.0 * delta)
	else:
		boss.velocity.x = move_toward(boss.velocity.x, 0, 10.0 * delta)
		boss.velocity.z = move_toward(boss.velocity.z, 0, 10.0 * delta)
		
	boss.move_and_slide()

func on_beat(layer: String, beat_index: int) -> void:
	if layer != "primary":
		return
		
	if beat_index == 1 and boss.player:
		var dist = boss.global_position.distance_to(boss.player.global_position)
		if dist <= 4.0:
			state_machine.transition_to("StateTelegraph")

func on_shield_broken() -> void:
	var state_recovery = state_machine.states.get("StateRecovery")
	if state_recovery:
		state_recovery.is_from_shield_break = true
	state_machine.transition_to("StateRecovery")
