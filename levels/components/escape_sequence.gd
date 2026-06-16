class_name EscapeSequence
extends Node3D

signal escape_completed

@export var path_z8: Path3D
@export var kill_wall: Node3D
@export var end_trigger: Area3D

var is_active: bool = false

func _ready() -> void:
	SignalBus.miniboss_defeated.connect(_on_miniboss_defeated)
	if end_trigger:
		end_trigger.body_entered.connect(_on_end_trigger_body_entered)

func _on_miniboss_defeated() -> void:
	is_active = true
	# Shift camera to Path_Z8
	SignalBus.camera_shift_requested.emit(false, path_z8, 1.5)
	# Start moving the kill wall
	if kill_wall and kill_wall.has_method("start_moving"):
		kill_wall.start_moving()

func _on_end_trigger_body_entered(body: Node3D) -> void:
	if not is_active:
		return
	if body is PlayerController:
		is_active = false
		if kill_wall and kill_wall.has_method("stop_moving"):
			kill_wall.stop_moving()
		escape_completed.emit()
		print("Escape sequence completed!")
