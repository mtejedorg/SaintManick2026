extends CanvasLayer

@onready var return_button: Button = $Root/CenterBox/ReturnButton

func _ready() -> void:
	return_button.pressed.connect(_on_return_pressed)
	# Gamepad navigation: focus the only button.
	return_button.grab_focus()

func _on_return_pressed() -> void:
	get_tree().change_scene_to_file("res://ui/shop/karens_shop.tscn")
