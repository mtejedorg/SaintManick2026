extends HeadlinerState

var is_from_shield_break: bool = false
var beat_counter: int = 0

func enter() -> void:
	boss.is_vulnerable = true
	boss.velocity.x = 0
	boss.velocity.z = 0
	if boss.mesh_instance:
		boss.mesh_instance.set_surface_override_material(0, boss.vulnerable_material)
	beat_counter = 0

func exit() -> void:
	boss.is_vulnerable = false
	if boss.mesh_instance:
		boss.mesh_instance.set_surface_override_material(0, boss.base_material)
	is_from_shield_break = false

func physics_update(delta: float) -> void:
	boss.apply_gravity(delta)
	boss.velocity.x = move_toward(boss.velocity.x, 0, 10.0 * delta)
	boss.velocity.z = move_toward(boss.velocity.z, 0, 10.0 * delta)
	boss.move_and_slide()

func on_beat(layer: String, beat_index: int) -> void:
	if layer != "primary":
		return
		
	beat_counter += 1
	
	var next_state = "StateEnraged" if boss.phase_2_triggered else "StateShield"
	
	if is_from_shield_break:
		# Vulnerable/stunned for 2 beats, then transition
		if beat_counter >= 3:
			state_machine.transition_to(next_state)
	else:
		# Normal recovery on beats 1-2, transition on beat 3
		if beat_index == 3:
			state_machine.transition_to(next_state)
