extends "res://tests/framework/test_case.gd"

# Define a mock target with the required properties to avoid PlayerController's @onready dependencies
class MockCameraTarget extends Node3D:
	var current_path: Path3D = null
	var is_jump_enabled: bool = true

var camera: DroneCamera
var mock_target: MockCameraTarget
var dummy_path: Path3D

func before_each() -> void:
	var camera_scene = load("res://characters/player/drone_camera.tscn")
	camera = camera_scene.instantiate()
	add_child(camera)
	
	mock_target = MockCameraTarget.new()
	add_child(mock_target)
	camera.target = mock_target
	
	dummy_path = Path3D.new()
	add_child(dummy_path)

func after_each() -> void:
	if is_instance_valid(camera):
		camera.queue_free()
	if is_instance_valid(mock_target):
		mock_target.queue_free()
	if is_instance_valid(dummy_path):
		dummy_path.queue_free()

func test_initial_state_is_sidescroll() -> void:
	var state_machine = camera.state_machine
	assert_not_null(state_machine.current_state, "Current state should not be null")
	assert_eq(state_machine.current_state.name, "Sidescroll", "Initial state should be Sidescroll")
	assert_true(mock_target.is_jump_enabled, "Jump should be enabled in Sidescroll")

func test_transition_to_topdown() -> void:
	var state_machine = camera.state_machine
	
	# Request transition to top-down (is_top_down = true)
	SignalBus.camera_shift_requested.emit(true, dummy_path, 0.05)
	
	# Should immediately transition to Transitioning state
	assert_eq(state_machine.current_state.name, "Transitioning", "Should shift to Transitioning state")
	
	# Wait for the transition tween to finish
	var transitioning_state = state_machine.states["transitioning"]
	assert_not_null(transitioning_state.current_tween, "Tween should be running")
	await transitioning_state.current_tween.finished
	
	# After tween finish, state machine should transition to TopDown
	assert_eq(state_machine.current_state.name, "TopDown", "Should shift to TopDown state after transition completes")
	assert_eq(mock_target.current_path, dummy_path, "Target's current_path should be updated to dummy_path")
	assert_false(mock_target.is_jump_enabled, "Target's jump should be disabled in top-down view")

func test_transition_back_to_sidescroll() -> void:
	var state_machine = camera.state_machine
	
	# Force transition to top-down first
	SignalBus.camera_shift_requested.emit(true, dummy_path, 0.01)
	var transitioning_state = state_machine.states["transitioning"]
	await transitioning_state.current_tween.finished
	assert_eq(state_machine.current_state.name, "TopDown")
	
	# Request transition back to sidescroll
	SignalBus.camera_shift_requested.emit(false, null, 0.05)
	assert_eq(state_machine.current_state.name, "Transitioning", "Should shift back to Transitioning state")
	
	assert_not_null(transitioning_state.current_tween, "Tween should be running for transition back")
	await transitioning_state.current_tween.finished
	
	assert_eq(state_machine.current_state.name, "Sidescroll", "Should transition back to Sidescroll")
	assert_null(mock_target.current_path, "Target's current_path should be reset to null")
	assert_true(mock_target.is_jump_enabled, "Target's jump should be re-enabled in Sidescroll")
