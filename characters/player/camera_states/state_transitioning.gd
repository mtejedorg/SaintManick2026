class_name StateTransitioning
extends CameraState

var target_top_down: bool
var target_path: Path3D
var duration: float = 1.5

var current_tween: Tween

func setup_transition(top_down: bool, path: Path3D, time: float) -> void:
	target_top_down = top_down
	target_path = path
	duration = time

func enter() -> void:
	if current_tween:
		current_tween.kill()
		
	current_tween = camera.create_tween()
	
	var target_offset = Vector3(0, 15, 5) if target_top_down else Vector3(0, 3, 10)
	var target_rotation = Vector3(-PI/3.0, 0, 0) if target_top_down else Vector3(0, 0, 0)
	
	# Tween offset and rotation of the camera
	current_tween.tween_property(camera, "offset", target_offset, duration).set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_IN_OUT)
	current_tween.parallel().tween_property(camera, "rotation", target_rotation, duration).set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_IN_OUT)
	
	current_tween.finished.connect(_on_tween_finished)

func exit() -> void:
	if current_tween:
		current_tween.kill()
		current_tween = null

func physics_update(delta: float) -> void:
	if not camera.target:
		return
	# Standard player tracking during the transition
	var target_position = camera.target.global_position + camera.offset
	camera.global_position = camera.global_position.lerp(target_position, camera.smooth_speed * delta)

func _on_tween_finished() -> void:
	if camera.target:
		if "current_path" in camera.target:
			camera.target.current_path = target_path
		if "is_jump_enabled" in camera.target:
			camera.target.is_jump_enabled = not target_top_down
			
	var next_state = "topdown" if target_top_down else "sidescroll"
	transition_requested.emit(next_state)
