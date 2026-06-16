extends Node

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
		if not dir.current_is_dir() and file_name.ends_with(".gd"):
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
	if has_save_manager:
		var sm = get_node("/root/SaveManager")
		sm.save_path = "user://test_save_data.tres"
		sm.load_profile() # Reload to use the test profile path
	
	# Mock current_scene to prevent null reference errors in _ready methods of test subjects
	var dummy_current_scene = Node3D.new()
	get_tree().root.add_child(dummy_current_scene)
	get_tree().current_scene = dummy_current_scene
	
	print("\n=== STARTING TEST SUITE ===\n")
	
	for file in test_files:
		var path = cases_dir + file
		var script = load(path)
		if not script:
			print("Failed to load test script: ", path)
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
	
	# Cleanup test save file
	if has_save_manager:
		var save_dir = DirAccess.open("user://")
		if save_dir and save_dir.file_exists("test_save_data.tres"):
			save_dir.remove("test_save_data.tres")
	
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
