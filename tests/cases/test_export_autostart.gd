extends "res://tests/framework/test_case.gd"

# D32: the exported exe cannot take a scene path, so the title screen honours a user arg
# (`-- --start-run`) and jumps straight into the slice. Guards the parser only; the jump
# itself is exercised by the export smoke in the gate.

const TITLE := preload("res://ui/menus/title_screen.gd")

func test_start_run_user_arg_is_recognised() -> void:
	assert_true(TITLE.wants_autostart(PackedStringArray(["--start-run"])), "--start-run alone")
	assert_true(TITLE.wants_autostart(PackedStringArray(["--foo", "--start-run"])), "--start-run among others")
	assert_false(TITLE.wants_autostart(PackedStringArray([])), "no user args")
	assert_false(TITLE.wants_autostart(PackedStringArray(["--startrun"])), "near miss is not accepted")
