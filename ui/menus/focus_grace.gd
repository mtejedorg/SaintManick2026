extends RefCounted
## U2: input grace for end screens and the pause menu. Space / gamepad A is both Jump and
## ui_accept, so a press held at the moment of death (or of pausing) would otherwise skip
## the screen. arm() disables the primary button for `seconds`, then re-enables it and gives
## it focus. The timer is process_always: these screens can be shown while the tree is paused.
##
## Usage: const FocusGrace = preload("res://ui/menus/focus_grace.gd"); FocusGrace.arm(button, 0.8)

## End screens (game over / run results) — the long grace, a death press is a full swing.
const END_SCREEN_GRACE := 0.8
## Pause menu Resume — short, the pause key is not the confirm key.
const PAUSE_GRACE := 0.3
## Per-button generation counter: re-arming (pause, unpause, pause) restarts the grace
## instead of letting the earlier timer release the button early.
const TOKEN_META := &"focus_grace_token"

static func arm(button: Button, seconds: float) -> void:
	if button == null or not button.is_inside_tree():
		return
	var token: int = int(button.get_meta(TOKEN_META, 0)) + 1
	button.set_meta(TOKEN_META, token)
	button.disabled = true
	var target: WeakRef = weakref(button)
	# J12: real seconds -- a hit-stop's time_scale must not stretch the grace.
	button.get_tree().create_timer(seconds, true, false, true).timeout.connect(func() -> void:
		var held := target.get_ref() as Button
		if held == null or int(held.get_meta(TOKEN_META, 0)) != token:
			return
		held.disabled = false
		if held.is_visible_in_tree():
			held.grab_focus()
	)
