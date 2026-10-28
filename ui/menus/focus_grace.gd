extends RefCounted
## U2: input grace for end screens and the pause menu. Space / gamepad A is both Jump and
## ui_accept, so a press held at the moment of death (or of pausing) would otherwise skip
## the screen. The timer is process_always: these screens can be shown while the tree is paused.
## Q3: the grace no longer disables the button (a lone disabled button rendered grey for 0.8 s).
## arm() takes the button out of focus (focus_mode = FOCUS_NONE, so ui_accept cannot reach it)
## and flags it held; the screens ignore `pressed` while is_held() (a mouse click still emits
## it). When the grace ends the focus mode is restored and the button grabs focus (unless
## armed with take_focus = false -- the secondary buttons of a screen).
##
## Usage: const FocusGrace = preload("res://ui/menus/focus_grace.gd"); FocusGrace.arm(button, 0.8)

## End screens (game over / run results) — the long grace, a death press is a full swing.
const END_SCREEN_GRACE := 0.8
## Pause menu Resume — short, the pause key is not the confirm key.
const PAUSE_GRACE := 0.3
## Q4: a pause opened by a window focus loss holds every pause button this long.
const FOCUS_LOSS_GRACE := 0.4
## Per-button generation counter: re-arming (pause, unpause, pause) restarts the grace
## instead of letting the earlier timer release the button early.
const TOKEN_META := &"focus_grace_token"
## Set while the grace runs; read through is_held().
const HELD_META := &"focus_grace_held"
## The focus_mode the button had before the first arm() of a grace.
const MODE_META := &"focus_grace_mode"

static func arm(button: Control, seconds: float, take_focus: bool = true) -> void:
	if button == null or not button.is_inside_tree():
		return
	var token: int = int(button.get_meta(TOKEN_META, 0)) + 1
	button.set_meta(TOKEN_META, token)
	if not is_held(button):
		button.set_meta(MODE_META, button.focus_mode)
	button.set_meta(HELD_META, true)
	if button.has_focus():
		button.release_focus()
	button.focus_mode = Control.FOCUS_NONE
	var target: WeakRef = weakref(button)
	# J12: real seconds -- a hit-stop's time_scale must not stretch the grace.
	button.get_tree().create_timer(seconds, true, false, true).timeout.connect(func() -> void:
		var held := target.get_ref() as Control
		if held == null or int(held.get_meta(TOKEN_META, 0)) != token:
			return
		release(held)
		if take_focus and held.is_visible_in_tree():
			held.grab_focus()
	)

## A `pressed` handler that ignores presses while `button` is held:
## button.pressed.connect(FocusGrace.guard(button, _on_button_pressed)).
static func guard(button: Control, action: Callable) -> Callable:
	return func() -> void:
		if not is_held(button):
			action.call()

## True while `button` is inside a grace: its screen must ignore a `pressed` now.
static func is_held(button: Control) -> bool:
	return button != null and bool(button.get_meta(HELD_META, false))

## Ends a grace early (restores the focus mode, no focus grab).
static func release(button: Control) -> void:
	if button == null or not is_held(button):
		return
	button.focus_mode = int(button.get_meta(MODE_META, Control.FOCUS_ALL)) as Control.FocusMode
	button.remove_meta(HELD_META)
	button.remove_meta(MODE_META)
