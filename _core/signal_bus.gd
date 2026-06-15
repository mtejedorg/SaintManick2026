extends Node
## Global Signal Bus Autoload
## All cross-domain events should be routed through here to decouple systems.

# --- Player Events ---
signal player_health_changed(new_health: int, max_health: int)
signal player_died()

# --- Combat Events ---
signal combo_increased(current_combo: int)
signal combo_dropped()

# --- Music/Rhythm Events ---
signal beat_hit(is_heavy_beat: bool)

func _ready():
	_register_input("dash", KEY_SHIFT)
	_register_input("roll", KEY_CTRL)
	_register_input("attack_light", KEY_J)
	_register_input("attack_heavy", KEY_K)

func _register_input(action_name: String, key_code: int):
	if not InputMap.has_action(action_name):
		InputMap.add_action(action_name)
		var ev = InputEventKey.new()
		ev.physical_keycode = key_code
		InputMap.action_add_event(action_name, ev)

