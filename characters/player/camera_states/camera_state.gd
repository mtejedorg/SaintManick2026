class_name CameraState
extends State

var camera: DroneCamera

func _ready() -> void:
	# Wait for the root node of the scene (DroneCamera) to be ready
	await owner.ready
	camera = owner as DroneCamera
