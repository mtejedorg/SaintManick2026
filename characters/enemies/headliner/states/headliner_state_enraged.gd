extends HeadlinerState

func enter() -> void:
	boss.speed_multiplier = 1.2
	boss.is_shield_active = false
	if boss.shield_bubble:
		boss.shield_bubble.visible = false
	if boss.character_visual:
		boss.character_visual.update_rim_strength(HeadlinerBoss.ENRAGED_RIM_STRENGTH)

	# Shift camera back to 2.5D sidescroll along Path_Z10
	SignalBus.camera_shift_requested.emit(false, boss.path_z10, 2.0)

func exit() -> void:
	pass

func physics_update(delta: float) -> void:
	boss.apply_gravity(delta)
	
	if boss.player:
		var target_pos = boss.player.global_position
		target_pos.y = boss.global_position.y
		if boss.global_position.distance_to(target_pos) > 0.1:
			boss.look_at(target_pos, Vector3.UP, true) # mesh faces +Z
			
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
