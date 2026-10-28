extends CanvasLayer

const FocusGrace = preload("res://ui/menus/focus_grace.gd")
const SceneTransition = preload("res://ui/transition/scene_transition.gd")

## Q4: ABANDON RUN needs a second press inside this window; the first relabels the button.
const ABANDON_TEXT := "ABANDON RUN"
const ABANDON_CONFIRM_TEXT := "CONFIRM ABANDON?"
## Seconds the confirm stays armed (real time, runs while paused).
@export var abandon_confirm_seconds: float = 2.0

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

## Q4: true between the first ABANDON RUN press and the confirm / disarm.
var abandon_armed: bool = false
## Bumped per arm/disarm so an older confirm timer never disarms a newer arm.
var _abandon_token: int = 0

func _ready() -> void:
	# Q3/Q4: presses during a FocusGrace hold are ignored.
	resume_button.pressed.connect(FocusGrace.guard(resume_button, _on_resume_pressed))
	quit_button.pressed.connect(FocusGrace.guard(quit_button, _on_quit_pressed))
	options_button.pressed.connect(FocusGrace.guard(options_button, _on_options_pressed))
	options_menu.closed.connect(_on_options_closed)
	quit_button.focus_exited.connect(_disarm_abandon)
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
	# V5: no pause while the run is over or a scene transition is fading (the tree used to load
	# the next screen paused and dead to input).
	if _transition_locked():
		return
	# Q4: any other press disarms a pending ABANDON confirm (the confirm press itself is the
	# ui_accept that reaches the focused button, and a click on it).
	if abandon_armed and _is_other_press(event):
		_disarm_abandon()
	# This node is PROCESS_MODE_ALWAYS so the toggle works while the tree is paused.
	# "pause" (Esc + joypad Start) owns the toggle; ui_cancel (which includes gamepad B =
	# Roll in gameplay) is only honoured as "back" while the menu is already open.
	if event.is_action_pressed("pause"):
		toggle()
		get_viewport().set_input_as_handled()
	elif visible and event.is_action_pressed("ui_cancel"):
		_resume()
		get_viewport().set_input_as_handled()

## `from_focus_loss`: the window lost focus (L7) -- every button is held for
## FocusGrace.FOCUS_LOSS_GRACE (Q4), the player may be clicking back into the window.
func toggle(from_focus_loss: bool = false) -> void:
	if _transition_locked():
		return
	if visible:
		_resume()
	else:
		show()
		menu_panel.show()
		_disarm_abandon()
		get_tree().paused = true
		# Nothing keeps focus from the last time the menu was open (a stale Quit focus plus a
		# held confirm would abandon the run); Resume takes focus after a short grace (U2).
		get_viewport().gui_release_focus()
		if from_focus_loss:
			FocusGrace.arm(resume_button, FocusGrace.FOCUS_LOSS_GRACE)
			FocusGrace.arm(options_button, FocusGrace.FOCUS_LOSS_GRACE, false)
			FocusGrace.arm(quit_button, FocusGrace.FOCUS_LOSS_GRACE, false)
		else:
			FocusGrace.arm(resume_button, FocusGrace.PAUSE_GRACE)

## V5: the run is over (game over / results / abandon) or SceneTransition is mid-fade.
func _transition_locked() -> bool:
	return GameManager.run_ended or SceneTransition.is_busy()

func _resume() -> void:
	if options_menu.visible:
		options_menu.close()
	_disarm_abandon()
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
	toggle(true)

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
	_disarm_abandon()
	menu_panel.hide()
	options_menu.open()

func _on_options_closed() -> void:
	menu_panel.show()
	if visible:
		options_button.grab_focus()

func _on_resume_pressed() -> void:
	_resume()

## Q4: the first press arms the confirm (relabels for abandon_confirm_seconds); the second
## press inside the window abandons.
func _on_quit_pressed() -> void:
	if not abandon_armed:
		_arm_abandon()
		return
	_disarm_abandon()
	# The orchestrator adds GameManager.abandon_run() (banks scrap/cells/cores like a death).
	# call() keeps this script parse-safe if the method is not present yet.
	if GameManager.has_method("abandon_run"):
		GameManager.call("abandon_run")
	get_tree().paused = false
	# Batch O: a demo run abandons to the title (abandon_run banked nothing), a full run to
	# Karen's Shop.
	change_scene.call(GameManager.post_run_scene())

func _change_scene_to(path: String) -> void:
	SceneTransition.go(get_tree(), path)

func _arm_abandon() -> void:
	abandon_armed = true
	_abandon_token += 1
	var token := _abandon_token
	quit_button.text = ABANDON_CONFIRM_TEXT
	get_tree().create_timer(abandon_confirm_seconds, true, false, true).timeout.connect(_on_abandon_timeout.bind(token))

func _on_abandon_timeout(token: int) -> void:
	if token == _abandon_token:
		_disarm_abandon()

func _disarm_abandon() -> void:
	if not abandon_armed:
		return
	abandon_armed = false
	_abandon_token += 1
	quit_button.text = ABANDON_TEXT

## A key / gamepad button / stick press that is not the confirm on ABANDON RUN itself.
func _is_other_press(event: InputEvent) -> bool:
	if event is InputEventMouse or event.is_echo() or not event.is_pressed():
		return false
	if quit_button.has_focus() and event.is_action("ui_accept"):
		return false
	return true
