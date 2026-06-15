class_name StateSidescroll
extends CameraState

func enter() -> void:
	camera.offset = Vector3(0, 3, 10)
	camera.rotation = Vector3.ZERO
	if camera.target and "is_jump_enabled" in camera.target:
		camera.target.is_jump_enabled = true

func physics_update(delta: float) -> void:
	if not camera.target:
		return
	var target_position = camera.target.global_position + camera.offset
	camera.global_position = camera.global_position.lerp(target_position, camera.smooth_speed * delta)
	camera.rotation = Vector3.ZERO
