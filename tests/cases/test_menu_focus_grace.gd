extends "res://tests/framework/test_case.gd"

# Batch H (UI) U2: Space / gamepad A is both Jump and ui_accept. The end screens and the
# pause menu ignore confirm for a short grace so a press at the moment of death cannot skip.
# Q3: the grace holds the button out of focus (FocusGrace.is_held) instead of disabling it.

const FocusGrace = preload("res://ui/menus/focus_grace.gd")

func after_each() -> void:
	get_tree().paused = false
	super.after_each()

func test_game_over_button_is_held_for_the_grace() -> void:
	var screen = load("res://ui/menus/game_over_screen.tscn").instantiate()
	add_child(screen)
	assert_true(FocusGrace.is_held(screen.return_button), "Held on the first frame")
	assert_false(screen.return_button.disabled, "...but never disabled (no grey button)")
	assert_eq(screen.return_button.focus_mode, Control.FOCUS_NONE, "...out of focus, so ui_accept cannot reach it")
	var requested: Array[String] = []
	screen.change_scene = func(path: String): requested.append(path)
	screen.return_button.pressed.emit()
	assert_eq(requested.size(), 0, "A press during the grace is ignored")
	await get_tree().process_frame
	assert_true(FocusGrace.is_held(screen.return_button), "Still held a frame later")
	await get_tree().create_timer(FocusGrace.END_SCREEN_GRACE + 0.1).timeout
	assert_false(FocusGrace.is_held(screen.return_button), "Released after the 0.8 s grace")
	assert_eq(screen.return_button.focus_mode, Control.FOCUS_ALL, "...focus mode restored")
	assert_true(screen.return_button.has_focus(), "...and focused for the gamepad")
	screen.queue_free()

func test_run_results_button_is_held_for_the_grace() -> void:
	var screen = load("res://ui/menus/run_results_screen.tscn").instantiate()
	add_child(screen)
	var button: Button = screen.get_node("CenterBox/ContinueButton")
	assert_true(FocusGrace.is_held(button), "Held on the first frame")
	assert_false(button.disabled, "...not disabled")
	await get_tree().create_timer(FocusGrace.END_SCREEN_GRACE + 0.1).timeout
	assert_false(FocusGrace.is_held(button), "Released after the grace")
	screen.queue_free()

func test_pause_resume_is_held_briefly_even_while_paused() -> void:
	var menu = load("res://ui/menus/pause_menu.tscn").instantiate()
	add_child(menu)
	menu.toggle()
	assert_true(get_tree().paused, "Pausing pauses the tree")
	assert_true(FocusGrace.is_held(menu.resume_button), "Resume is held for the pause grace")
	await get_tree().create_timer(FocusGrace.PAUSE_GRACE + 0.1).timeout
	assert_false(FocusGrace.is_held(menu.resume_button), "The grace timer runs while the tree is paused")
	assert_true(menu.resume_button.has_focus(), "Resume takes focus after the grace")
	menu.toggle()
	assert_false(get_tree().paused, "Toggling again resumes")
	menu.queue_free()

func test_rearming_restarts_the_grace() -> void:
	var button := Button.new()
	add_child(button)
	FocusGrace.arm(button, 0.2)
	await get_tree().create_timer(0.1).timeout
	FocusGrace.arm(button, 0.3) # re-armed before the first grace ended
	await get_tree().create_timer(0.15).timeout
	assert_true(FocusGrace.is_held(button), "The first timer must not release a re-armed button")
	assert_eq(button.focus_mode, Control.FOCUS_NONE, "...still out of focus")
	await get_tree().create_timer(0.25).timeout
	assert_false(FocusGrace.is_held(button), "The second grace releases it")
	assert_eq(button.focus_mode, Control.FOCUS_ALL, "...with the original focus mode, not the held one")
	button.queue_free()
