class_name StateTopDown
extends CameraState

func enter() -> void:
	camera.offset = Vector3(0, 15, 5)
	camera.rotation = Vector3(-PI/3.0, 0, 0)
	if camera.target and "is_jump_enabled" in camera.target:
		camera.target.is_jump_enabled = false

func physics_update(delta: float) -> void:
	if not camera.target:
		return
	var target_position = camera.target.global_position + camera.offset
	camera.global_position = camera.global_position.lerp(target_position, camera.smooth_speed * delta)
	camera.rotation = Vector3(-PI/3.0, 0, 0)
