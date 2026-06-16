extends EnforcerState

var is_from_shield_break: bool = false
var beat_counter: int = 0

func enter() -> void:
	enforcer.is_vulnerable = true
	enforcer.velocity.x = 0
	enforcer.velocity.z = 0
	enforcer.mesh_instance.set_surface_override_material(0, enforcer.vulnerable_material)
	beat_counter = 0

func exit() -> void:
	enforcer.is_vulnerable = false
	enforcer.mesh_instance.set_surface_override_material(0, enforcer.base_material)
	is_from_shield_break = false

func physics_update(delta: float) -> void:
	enforcer.apply_gravity(delta)
	enforcer.velocity.x = move_toward(enforcer.velocity.x, 0, 10.0 * delta)
	enforcer.velocity.z = move_toward(enforcer.velocity.z, 0, 10.0 * delta)
	enforcer.move_and_slide()

func on_beat(layer: String, beat_index: int) -> void:
	if layer != "primary":
		return
		
	beat_counter += 1
	
	if is_from_shield_break:
		# Vulnerable/stunned for 2 beats, then transition to StateIdle
		if beat_counter >= 3:
			state_machine.transition_to("StateIdle")
	else:
		# Normal recovery on beats 1-2, transition on beat 3
		if beat_index == 3:
			state_machine.transition_to("StateShield")
