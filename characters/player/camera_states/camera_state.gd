class_name CameraState
extends State

var camera: DroneCamera

func _ready() -> void:
	# Resolve synchronously: owner (the DroneCamera scene root) is valid at _ready time.
	# Do NOT await owner.ready here — the StateMachine calls initial_state.enter() from its
	# own _ready (which runs after these child _ready calls), and enter() sets camera.offset,
	# so `camera` must already be assigned by then. Awaiting would leave it null on first enter.
	camera = owner as DroneCamera
