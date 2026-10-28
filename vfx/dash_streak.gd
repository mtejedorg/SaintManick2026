extends GPUParticles3D

## U1: the dash/roll speed streak. ONE pooled instance (owned by PlayerMotionFx) re-fired per
## dash: a one-shot burst of thin cyan quads thrown backwards along `direction`.

signal burst_fired

func _ready() -> void:
	one_shot = true
	emitting = false

## `direction` is the world-space way the streaks fly (opposite to Nick's travel).
func burst(pos: Vector3, direction: Vector3) -> void:
	var dir := Vector3(direction.x, 0.0, direction.z)
	if dir.length() < 0.001:
		dir = Vector3.LEFT
	dir = dir.normalized()
	global_position = pos
	# The process material throws particles along local +X; yaw that onto `dir`.
	rotation = Vector3(0.0, atan2(-dir.z, dir.x), 0.0)
	restart()
	emitting = true
	burst_fired.emit()
