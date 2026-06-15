class_name DroneCamera
extends Camera3D

@export var target: Node3D
@export var smooth_speed: float = 5.0

# Current active offset and rotation (managed by states and tweened in transition)
var offset: Vector3 = Vector3(0, 3, 10)

@onready var state_machine: StateMachine = $StateMachine

func _ready() -> void:
	SignalBus.camera_shift_requested.connect(_on_camera_shift_requested)

func _on_camera_shift_requested(top_down: bool, target_path: Path3D, transition_time: float) -> void:
	var transitioning_state = state_machine.states.get("transitioning")
	if transitioning_state:
		transitioning_state.setup_transition(top_down, target_path, transition_time)
		state_machine._on_transition_requested("Transitioning")
