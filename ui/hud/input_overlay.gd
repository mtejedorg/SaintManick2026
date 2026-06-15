extends CanvasLayer

@onready var jump_label: Label = $VBoxContainer/JumpLabel
@onready var dash_label: Label = $VBoxContainer/DashLabel
@onready var roll_label: Label = $VBoxContainer/RollLabel
@onready var attack_l_label: Label = $VBoxContainer/AttackLLabel
@onready var attack_h_label: Label = $VBoxContainer/AttackHLabel

func _process(_delta: float) -> void:
	_update_label(jump_label, "ui_accept", "JUMP (Space)")
	_update_label(dash_label, "dash", "DASH (Shift)")
	_update_label(roll_label, "roll", "ROLL (Ctrl)")
	_update_label(attack_l_label, "attack_light", "LIGHT ATTACK (J)")
	_update_label(attack_h_label, "attack_heavy", "HEAVY ATTACK (K)")

func _update_label(label: Label, action: String, text: String) -> void:
	if Input.is_action_pressed(action):
		label.text = "> " + text + " <"
		label.modulate = Color(0, 1, 0) # Green when pressed
	else:
		label.text = text
		label.modulate = Color(1, 1, 1) # White normally
