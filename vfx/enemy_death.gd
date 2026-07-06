## Enemy death burst — GPUParticles3D one-shot.
## Called by the pool via burst(position). Emits burst_finished when done.
extends GPUParticles3D

signal burst_finished

var _timer: float = 0.0
var _active: bool = false

func _ready() -> void:
	one_shot = true
	emitting = false

func burst(pos: Vector3) -> void:
	global_position = pos
	restart()
	emitting = true
	_timer = lifetime + 0.1
	_active = true

func _process(delta: float) -> void:
	if not _active:
		return
	_timer -= delta
	if _timer <= 0.0:
		_active = false
		emitting = false
		burst_finished.emit()
