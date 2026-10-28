extends Node

## Q1: the suite never touches the real profile. Every test runs against a throwaway
## PlayerProfile saved (if at all) to test_save_path, reset after EACH test so no order can
## leak state; the real save_path + profile come back at the end and the temp file goes.
## One file per process (user://test_profile_<pid>.tres): two suites may run side by side.
const REAL_SAVE_PATH := "user://save_data.tres"
var test_save_path: String = "user://test_profile_%d.tres" % OS.get_process_id()

## Read by test_hermetic_profile.gd (the test's parent is this runner): the real save's
## modification time when the suite started (0 = no real save on disk).
var real_save_mtime_at_start: int = 0
var _saved_save_path: String = ""
var _saved_profile: Resource = null

## `-- --only=<substring>` runs just the case files whose name contains it (local loops).
func _only_filter() -> String:
	for arg in OS.get_cmdline_user_args():
		if arg.begins_with("--only="):
			return arg.substr("--only=".length())
	return ""

static func real_save_mtime() -> int:
	return FileAccess.get_modified_time(REAL_SAVE_PATH) if FileAccess.file_exists(REAL_SAVE_PATH) else 0

## A fresh profile as a brand-new save gets it (the starter combos granted).
func _reset_test_profile(sm: Node) -> void:
	sm.profile = PlayerProfile.new()
	if sm.has_method("_grant_starter_combos"):
		sm._grant_starter_combos()
	else:
		for combo_id in sm.STARTER_COMBOS:
			sm.profile.unlocked_combos.append(combo_id)
	# Bus volumes follow the fresh profile (100 %) so an options test cannot leak a mix.
	if sm.has_method("apply_settings"):
		sm.apply_settings()

func _remove_test_save() -> void:
	for path in [test_save_path, test_save_path.get_basename() + ".tmp.tres"]:
		if FileAccess.file_exists(path):
			DirAccess.remove_absolute(ProjectSettings.globalize_path(path))

func run_all_tests() -> bool:
	var cases_dir = "res://tests/cases/"
	var dir = DirAccess.open(cases_dir)
	if not dir:
		print("TestRunner Error: Cannot open tests directory: ", cases_dir)
		return false
	
	dir.list_dir_begin()
	var file_name = dir.get_next()
	var test_files: Array[String] = []
	
	while file_name != "":
		if not dir.current_is_dir() and file_name.ends_with(".gd") and (_only_filter() == "" or file_name.contains(_only_filter())):
			test_files.append(file_name)
		file_name = dir.get_next()
	dir.list_dir_end()
	
	# Sort test files for deterministic execution order
	test_files.sort()
	
	var total_tests = 0
	var passed_tests = 0
	var failed_tests = 0
	var all_failures: Array[String] = []
	
	# Setup global test seams
	var has_game_manager = Engine.has_singleton("GameManager") or get_node_or_null("/root/GameManager") != null
	var has_save_manager = Engine.has_singleton("SaveManager") or get_node_or_null("/root/SaveManager") != null
	
	if has_game_manager:
		var gm = get_node("/root/GameManager")
		gm.is_test = true
	var sm: Node = get_node_or_null("/root/SaveManager") if has_save_manager else null
	if sm:
		real_save_mtime_at_start = real_save_mtime()
		_saved_save_path = sm.save_path
		_saved_profile = sm.profile
		sm.save_path = test_save_path
		_reset_test_profile(sm)
	
	# Mock current_scene to prevent null reference errors in _ready methods of test subjects
	var dummy_current_scene = Node3D.new()
	get_tree().root.add_child(dummy_current_scene)
	get_tree().current_scene = dummy_current_scene
	
	print("\n=== STARTING TEST SUITE ===\n")
	
	for file in test_files:
		var path = cases_dir + file
		var script = load(path)
		# A script that fails to parse still loads as a GDScript that cannot instantiate --
		# report it as a failure instead of crashing the whole run on .new().
		if not script or not script.can_instantiate():
			print("Failed to load test script: ", path)
			failed_tests += 1
			all_failures.append("Failed to load: " + path)
			continue
			
		var test_instance = script.new()
		if not test_instance.has_method("assert_eq"):
			print("Warning: Test file ", file, " does not extend TestCase. Skipping.")
			test_instance.free()
			continue
			
		add_child(test_instance)
		
		# Find test methods
		var methods = test_instance.get_method_list()
		var test_methods: Array[String] = []
		for m in methods:
			if m.name.begins_with("test_"):
				test_methods.append(m.name)
		
		# Sort test methods for deterministic execution order
		test_methods.sort()
		
		if test_methods.is_empty():
			remove_child(test_instance)
			test_instance.queue_free()
			continue
			
		print("Running suite: ", file)
		
		for method_name in test_methods:
			total_tests += 1
			test_instance.current_test_name = method_name
			test_instance.failures.clear()
			
			# Run before_each
			await test_instance.before_each()
			
			# Run the test method
			print("  -> ", method_name, " ... ")
			
			await test_instance.call(method_name)
			
			# Run after_each
			await test_instance.after_each()
			# K11: a death beat a test started (a lethal hit on Nick) resolves before the next
			# test -- the respawn refills GameManager HP as the old one-frame deferral did. A
			# pending final death outside is_test is only cancelled (no scene change here).
			var gm = get_node_or_null("/root/GameManager")
			if gm and gm.get("death_beat_pending"):
				if gm.current_lives > 0 or gm.is_test:
					gm.finish_death_beat_now()
				else:
					gm.cancel_death_beat()
			# Q1: the next test starts from a brand-new profile on the temp path (a test that
			# swapped save_path for its own file gets the temp path back too).
			if sm:
				sm.save_path = test_save_path
				_reset_test_profile(sm)
			
			if test_instance.failures.is_empty():
				passed_tests += 1
				print("     [PASS]")
			else:
				failed_tests += 1
				print("     [FAIL]")
				for failure in test_instance.failures:
					var fail_msg = "%s:%s -> %s" % [file, method_name, failure]
					print("       Error: ", failure)
					all_failures.append(fail_msg)
		
		remove_child(test_instance)
		test_instance.queue_free()
	
	# Clean up mocked current_scene
	get_tree().current_scene = null
	if is_instance_valid(dummy_current_scene):
		dummy_current_scene.queue_free()
	
	# Q1: the real profile comes back untouched; the temp file goes.
	if sm:
		sm.save_path = _saved_save_path
		sm.profile = _saved_profile
		if sm.has_method("apply_settings"):
			sm.apply_settings()
		_remove_test_save()
		if real_save_mtime() != real_save_mtime_at_start:
			failed_tests += 1
			all_failures.append("test_runner: the suite modified the real save %s (mtime %d -> %d)" % [REAL_SAVE_PATH, real_save_mtime_at_start, real_save_mtime()])
	
	print("\n=== TEST SUITE SUMMARY ===")
	print("Total Tests Run: ", total_tests)
	print("Passed:          ", passed_tests)
	print("Failed:          ", failed_tests)
	
	if failed_tests > 0:
		print("\nDetailed Failures:")
		for fail in all_failures:
			print("  * ", fail)
		print("\nResult: FAILURE")
		return false
	else:
		print("\nResult: SUCCESS")
		return true
