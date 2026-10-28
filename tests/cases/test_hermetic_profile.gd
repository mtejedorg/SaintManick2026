extends "res://tests/framework/test_case.gd"

## Q1: the suite never touches the real profile. The runner (this case's parent) swaps
## SaveManager onto a throwaway profile + save path for the whole run and resets it after
## every test; the real save's modification time must not move.

const REAL_SAVE_PATH := "user://save_data.tres"

func _runner() -> Node:
	return get_parent()

func test_a_the_suite_runs_on_a_throwaway_profile_and_path() -> void:
	var runner := _runner()
	assert_true(SaveManager.save_path != REAL_SAVE_PATH, "Tests never save to the real profile path (got %s)" % SaveManager.save_path)
	assert_eq(SaveManager.save_path, runner.test_save_path, "...they save to the runner temp path")
	assert_eq(runner.real_save_mtime(), runner.real_save_mtime_at_start, "The real save is unchanged so far in this run")
	# Dirty the test profile on purpose and save it: the next test must not see any of it.
	SaveManager.profile.scrap = 4242
	SaveManager.profile.seen_controls = true
	SaveManager.profile.double_jump_unlocked = false
	SaveManager.profile.unlocked_combos.append("BB")
	SaveManager.save_profile()
	assert_true(FileAccess.file_exists(runner.test_save_path), "The save landed on the temp file")
	assert_eq(runner.real_save_mtime(), runner.real_save_mtime_at_start, "...and the real save still did not move")

func test_b_the_previous_test_left_nothing_behind() -> void:
	var p: PlayerProfile = SaveManager.profile
	assert_eq(p.scrap, 0, "A fresh profile per test: no scrap leaks from the previous test")
	assert_false(p.seen_controls, "...no seen_controls")
	assert_true(p.double_jump_unlocked, "...the default Double Jump is back")
	assert_eq(p.unlocked_combos, SaveManager.STARTER_COMBOS, "...exactly the starter combos")
	assert_true(SaveManager.save_path != REAL_SAVE_PATH, "...still on the temp path")
