extends HeadlinerState

func enter() -> void:
	if boss.health_component:
		boss.health_component.is_invincible = true
	boss.velocity = Vector3.ZERO
	boss.is_shield_active = false
	if boss.shield_bubble:
		boss.shield_bubble.visible = false

	# Request top-down camera shift
	SignalBus.camera_shift_requested.emit(true, boss.path_z10, 2.0)

	# Wait for transition time to complete, then enter Bullet Hell
	get_tree().create_timer(2.0).timeout.connect(func():
		if state_machine.current_state == self:
			state_machine.transition_to("StateBulletHell")
	)

func exit() -> void:
	if boss.health_component:
		# Note: In bullet hell, the boss is shielded rather than fully invulnerable,
		# but let's make sure it is not invincibility-protected.
		boss.health_component.is_invincible = false

func physics_update(delta: float) -> void:
	boss.apply_gravity(delta)
	boss.velocity.x = 0
	boss.velocity.z = 0
	boss.move_and_slide()
