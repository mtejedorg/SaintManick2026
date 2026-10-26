class_name StateTopDown
extends CameraState

func enter() -> void:
	camera.offset = DroneCamera.TOP_DOWN_OFFSET
	camera.rotation = DroneCamera.TOP_DOWN_ROTATION
	if camera.target and "is_jump_enabled" in camera.target:
		camera.target.is_jump_enabled = false

func physics_update(delta: float) -> void:
	if not camera.target:
		return
	var target_position = camera.target.global_position + camera.offset
	camera.base_position = camera.base_position.lerp(target_position, camera.smooth_speed * delta)
	camera.rotation = DroneCamera.TOP_DOWN_ROTATION

