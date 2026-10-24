extends HeadlinerState

const BodyFacing = preload("res://characters/shared/body_facing.gd")

func enter() -> void:
	if boss.hitbox:
		boss.hitbox.damage_info.amount = boss.stats.damage
		boss.hitbox.damage_info.knockback = boss.stats.knockback
		boss.hitbox.damage_info.stun = boss.stats.stun
		boss.hitbox.damage_info.source = boss
		boss.hitbox.is_active = true

	# Lunge towards player
	if boss.player:
		var dir = (boss.player.global_position - boss.global_position).normalized()
		dir.y = 0
		# F8: target flattened to the body's height so the lunge never pitches the body.
		var target: Vector3 = BodyFacing.flat_target(boss, boss.player.global_position)
		if boss.global_position.distance_to(target) > 0.1:
			boss.look_at(target, Vector3.UP, true) # mesh faces +Z
		var lunge_speed = boss.stats.speed * 2.0 * boss.speed_multiplier
		boss.velocity.x = dir.x * lunge_speed
		boss.velocity.z = dir.z * lunge_speed

	# Deactivate hitbox after a short delay
	get_tree().create_timer(0.25).timeout.connect(func():
		if state_machine.current_state == self:
			if boss.hitbox:
				boss.hitbox.is_active = false
	)

func exit() -> void:
	if boss.hitbox:
		boss.hitbox.is_active = false

func physics_update(delta: float) -> void:
	boss.apply_gravity(delta)
	boss.velocity.x = move_toward(boss.velocity.x, 0, 8.0 * delta)
	boss.velocity.z = move_toward(boss.velocity.z, 0, 8.0 * delta)
	boss.move_and_slide()

func on_beat(layer: String, beat_index: int) -> void:
	if layer != "primary":
		return
		
	# Transition to Recovery on beat 3
	if beat_index == 3:
		state_machine.transition_to("StateRecovery")
