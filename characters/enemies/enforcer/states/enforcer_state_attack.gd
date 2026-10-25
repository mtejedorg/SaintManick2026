extends EnforcerState

const BodyFacing = preload("res://characters/shared/body_facing.gd")

var attack_step: int = 0

func enter() -> void:
	attack_step = 0
	_execute_attack()

func _execute_attack() -> void:
	if attack_step == 2:
		# 3rd hit (beat 4) does higher knockback/stun/damage
		enforcer.hitbox.damage_info.knockback = enforcer.stats.knockback * 1.8
		enforcer.hitbox.damage_info.stun = enforcer.stats.stun * 1.5
		enforcer.hitbox.damage_info.amount = enforcer.stats.damage * 1.3
	else:
		enforcer.hitbox.damage_info.knockback = enforcer.stats.knockback
		enforcer.hitbox.damage_info.stun = enforcer.stats.stun
		enforcer.hitbox.damage_info.amount = enforcer.stats.damage

	enforcer.hitbox.is_active = true

	# Lunge towards player
	if enforcer.player:
		var dir = (enforcer.player.global_position - enforcer.global_position).normalized()
		dir.y = 0
		# use_model_front: the Enforcer mesh faces +Z, so +Z (not -Z) must point at Nick.
		# F8: target flattened to the body's height so the lunge never pitches the body.
		var target: Vector3 = BodyFacing.flat_target(enforcer, enforcer.player.global_position)
		if enforcer.global_position.distance_to(target) > 0.1:
			enforcer.look_at(target, Vector3.UP, true)
		enforcer.velocity.x = dir.x * enforcer.stats.speed * 2.0
		enforcer.velocity.z = dir.z * enforcer.stats.speed * 2.0
		
	# Deactivate hitbox after a short delay
	get_tree().create_timer(0.25, false).timeout.connect(func():
		if state_machine.current_state == self:
			enforcer.hitbox.is_active = false
	)

func exit() -> void:
	enforcer.hitbox.is_active = false

func physics_update(delta: float) -> void:
	enforcer.apply_gravity(delta)
	enforcer.velocity.x = move_toward(enforcer.velocity.x, 0, 8.0 * delta)
	enforcer.velocity.z = move_toward(enforcer.velocity.z, 0, 8.0 * delta)
	enforcer.move_and_slide()

func on_beat(layer: String, beat_index: int) -> void:
	if layer != "primary":
		return
		
	match beat_index:
		3:
			attack_step = 1
			_execute_attack()
		4:
			attack_step = 2
			_execute_attack()
		1:
			state_machine.transition_to("StateRecovery")
