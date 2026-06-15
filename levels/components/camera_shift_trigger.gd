class_name CameraShiftTrigger
extends Area3D

@export var top_down: bool = true
@export var transition_time: float = 1.5
@export var target_path: Path3D

func _ready() -> void:
	body_entered.connect(_on_body_entered)

func _on_body_entered(body: Node3D) -> void:
	if body is PlayerController:
		var currently_sidescroll = body.current_path != null
		var target_top_down = currently_sidescroll
		var path_to_pass = null if target_top_down else target_path
		
		SignalBus.camera_shift_requested.emit(target_top_down, path_to_pass, transition_time)
