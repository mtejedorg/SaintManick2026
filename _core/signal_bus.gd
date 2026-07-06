extends Node
## Global Signal Bus Autoload
## All cross-domain events should be routed through here to decouple systems.

# --- Player Events ---
signal player_health_changed(new_health: float, max_health: float)
signal player_shield_changed(new_shield: float, max_shield: float)
signal player_died()
signal player_life_lost(current_lives: int)
signal ability_meter_changed(current: float, max_meter: float)

# --- Combat Events ---
signal combo_increased(current_combo: int)
signal combo_dropped()
signal combo_reset()  # Alias emitted alongside combo_dropped for HUD clarity
signal hit_stop_requested(duration: float, time_scale: float)
signal camera_shake_requested(strength: float, duration: float)
signal player_hit_landed(damage_info: DamageInfo)
## Emitted by Hurtbox3D when a player attack connects. hit_type: "light" or "heavy".
signal hit_landed(position: Vector3, hit_type: String)
## Emitted by enemy _on_died() before queue_free so VFX can burst at the death position.
signal enemy_died(position: Vector3)


# --- Music/Rhythm Events ---
signal beat(layer: String, beat_index: int)
signal downbeat(layer: String, measure_index: int)
signal tempo_changed(new_bpm: float)

# --- Camera Events ---
signal camera_shift_requested(top_down: bool, target_path: Path3D, transition_time: float)
signal miniboss_defeated()

# --- Zone Events ---
signal zone_entered(zone_name: String)

# --- Boss Events ---
signal boss_spawned(boss_name: String)
signal boss_health_changed(current: int, maximum: int)
signal boss_died()

func _ready():
	_register_input("dash", KEY_SHIFT)
	_register_input("roll", KEY_CTRL)
	_register_input("attack_light", KEY_J)
	_register_input("attack_heavy", KEY_K)
	# Temporary binding for Bass Drop (M5b) — an unused key until M9 lands a real
	# [input] section in project.godot with a dedicated action + gamepad binding.
	_register_input("ability_ultimate", KEY_L)

func _register_input(action_name: String, key_code: int):
	if not InputMap.has_action(action_name):
		InputMap.add_action(action_name)
		var ev = InputEventKey.new()
		ev.physical_keycode = key_code
		InputMap.action_add_event(action_name, ev)
