extends CanvasLayer

const FocusGrace = preload("res://ui/menus/focus_grace.gd")

@onready var resume_button: Button = $Root/MenuPanel/PanelVBox/ButtonContainer/ResumeButton
@onready var quit_button:   Button = $Root/MenuPanel/PanelVBox/ButtonContainer/QuitButton

func _ready() -> void:
	resume_button.pressed.connect(_on_resume_pressed)
	quit_button.pressed.connect(_on_quit_pressed)

	# Visible state driven by toggle; start hidden
	hide()

func _input(event: InputEvent) -> void:
	# This node is PROCESS_MODE_ALWAYS so the toggle works while the tree is paused.
	# "pause" (Esc + joypad Start) owns the toggle; ui_cancel (which includes gamepad B =
	# Roll in gameplay) is only honoured as "back" while the menu is already open.
	if event.is_action_pressed("pause"):
		toggle()
		get_viewport().set_input_as_handled()
	elif visible and event.is_action_pressed("ui_cancel"):
		_resume()
		get_viewport().set_input_as_handled()

func toggle() -> void:
	if visible:
		_resume()
	else:
		show()
		get_tree().paused = true
		# Nothing keeps focus from the last time the menu was open (a stale Quit focus plus a
		# held confirm would abandon the run); Resume takes focus after a short grace (U2).
		get_viewport().gui_release_focus()
		FocusGrace.arm(resume_button, FocusGrace.PAUSE_GRACE)

func _resume() -> void:
	hide()
	get_tree().paused = false

func _on_resume_pressed() -> void:
	_resume()

func _on_quit_pressed() -> void:
	# The orchestrator adds GameManager.abandon_run() (banks scrap/cells/cores like a death).
	# call() keeps this script parse-safe if the method is not present yet.
	if GameManager.has_method("abandon_run"):
		GameManager.call("abandon_run")
	get_tree().paused = false
	get_tree().change_scene_to_file("res://ui/shop/karens_shop.tscn")
