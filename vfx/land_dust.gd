extends GPUParticles3D

## U1: the landing dust puff. ONE pooled instance (owned by PlayerMotionFx) re-fired per hard landing.

signal burst_fired

func _ready() -> void:
	one_shot = true
	emitting = false

func burst(pos: Vector3) -> void:
	global_position = pos
	restart()
	emitting = true
	burst_fired.emit()
