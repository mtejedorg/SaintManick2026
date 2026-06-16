extends SceneTree

func _initialize() -> void:
	# Let the scene tree/autoloads initialize
	await process_frame
	
	var runner_script = load("res://tests/framework/test_runner.gd")
	var runner = runner_script.new()
	root.add_child(runner)
	
	var success = await runner.run_all_tests()
	
	runner.queue_free()
	
	if success:
		print("All tests passed successfully.")
		quit(0)
	else:
		print("Test suite failed.")
		quit(1)
