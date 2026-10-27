extends CanvasLayer

const FocusGrace = preload("res://ui/menus/focus_grace.gd")

@onready var resume_button: Button = $Root/MenuPanel/PanelVBox/ButtonContainer/ResumeButton
@onready var quit_button:   Button = $Root/MenuPanel/PanelVBox/ButtonContainer/QuitButton
@onready var options_button: Button = $Root/MenuPanel/PanelVBox/ButtonContainer/OptionsButton
@onready var menu_panel: Control = $Root/MenuPanel
@onready var options_menu: Control = $Root/OptionsMenu

## L7 (D29): open the menu when the window loses focus. Tools that drive the slice in a real
## window (the capture tool) switch it off -- a paused tree renders black frames.
@export var auto_pause_on_focus_loss: bool = true
## L7: the Headliner's victory hold (boss_died after boss_spawned("Headliner")) -- the run
## is over in all but the scene change, so a focus loss must not pause it.
const VICTORY_BOSS := "Headliner"
var _last_boss: String = ""
var _victory_hold: bool = false

## Scene-change hook (path) -> void; a seam so tests can observe ABANDON RUN's navigation.
var change_scene: Callable = _change_scene_to

func _ready() -> void:
	resume_button.pressed.connect(_on_resume_pressed)
	quit_button.pressed.connect(_on_quit_pressed)
	options_button.pressed.connect(_on_options_pressed)
	options_menu.closed.connect(_on_options_closed)
	SignalBus.boss_spawned.connect(_on_boss_spawned)
	SignalBus.boss_died.connect(_on_boss_died)
	SignalBus.boss_reset.connect(_on_boss_reset)
	SignalBus.run_started.connect(_on_boss_reset)

	# Visible state driven by toggle; start hidden
	hide()

func _input(event: InputEvent) -> void:
	# L8: the open options panel owns ui_cancel / pause (both mean "back" there).
	if options_menu.visible:
		return
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
		menu_panel.show()
		get_tree().paused = true
		# Nothing keeps focus from the last time the menu was open (a stale Quit focus plus a
		# held confirm would abandon the run); Resume takes focus after a short grace (U2).
		get_viewport().gui_release_focus()
		FocusGrace.arm(resume_button, FocusGrace.PAUSE_GRACE)

func _resume() -> void:
	if options_menu.visible:
		options_menu.close()
	hide()
	get_tree().paused = false

## L7: NOTIFICATION_APPLICATION_FOCUS_OUT reaches every node in the tree.
func _notification(what: int) -> void:
	if what == NOTIFICATION_APPLICATION_FOCUS_OUT:
		_on_focus_lost()

func _on_focus_lost() -> void:
	if not auto_pause_on_focus_loss or not is_inside_tree() or visible:
		return
	if get_tree().paused or GameManager.run_ended or _victory_hold:
		return
	toggle()

func _on_boss_spawned(boss_name: String) -> void:
	_last_boss = boss_name

func _on_boss_died() -> void:
	if _last_boss == VICTORY_BOSS:
		_victory_hold = true

func _on_boss_reset() -> void:
	_last_boss = ""
	_victory_hold = false

## L8: the options panel replaces the menu panel until it closes.
func _on_options_pressed() -> void:
	menu_panel.hide()
	options_menu.open()

func _on_options_closed() -> void:
	menu_panel.show()
	if visible:
		options_button.grab_focus()

func _on_resume_pressed() -> void:
	_resume()

func _on_quit_pressed() -> void:
	# The orchestrator adds GameManager.abandon_run() (banks scrap/cells/cores like a death).
	# call() keeps this script parse-safe if the method is not present yet.
	if GameManager.has_method("abandon_run"):
		GameManager.call("abandon_run")
	get_tree().paused = false
	# Batch O: a demo run abandons to the title (abandon_run banked nothing), a full run to
	# Karen's Shop.
	change_scene.call(GameManager.post_run_scene())

func _change_scene_to(path: String) -> void:
	get_tree().change_scene_to_file(path)
