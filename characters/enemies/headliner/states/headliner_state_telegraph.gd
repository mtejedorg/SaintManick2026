extends HeadlinerState

func enter() -> void:
	boss.is_shield_active = false
	if boss.shield_bubble:
		boss.shield_bubble.visible = false
	if boss.mesh_instance:
		boss.mesh_instance.set_surface_override_material(0, boss.telegraph_material)
	boss.velocity.x = 0
	boss.velocity.z = 0

func exit() -> void:
	if boss.mesh_instance:
		boss.mesh_instance.set_surface_override_material(0, boss.base_material)

func physics_update(delta: float) -> void:
	boss.apply_gravity(delta)
	boss.velocity.x = move_toward(boss.velocity.x, 0, 10.0 * delta)
	boss.velocity.z = move_toward(boss.velocity.z, 0, 10.0 * delta)
	boss.move_and_slide()

func on_beat(layer: String, beat_index: int) -> void:
	if layer != "primary":
		return
		
	# On beat 2, transition to Melee strike execution state
	if beat_index == 2:
		state_machine.transition_to("StateMelee")
