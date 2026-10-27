## Enemy death burst — GPUParticles3D one-shot.
## Called by the pool via burst(position). Emits burst_finished when done.
## P1: magenta embers (draw_pass_1 was null, so nothing ever drew) plus a child `Smoke` puff
## restarted with the burst.
extends GPUParticles3D

signal burst_finished

var _timer: float = 0.0
var _active: bool = false

@onready var smoke: GPUParticles3D = get_node_or_null("Smoke")

func _ready() -> void:
	one_shot = true
	emitting = false

func burst(pos: Vector3) -> void:
	global_position = pos
	restart()
	emitting = true
	if smoke:
		smoke.restart()
		smoke.emitting = true
	_timer = maxf(lifetime, smoke.lifetime if smoke else 0.0) + 0.1
	_active = true

func _process(delta: float) -> void:
	if not _active:
		return
	_timer -= delta
	if _timer <= 0.0:
		_active = false
		emitting = false
		burst_finished.emit()
