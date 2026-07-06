## Hit spark burst — GPUParticles3D one-shot.
## Color is set via set_color() before restart() is called by the pool.
extends GPUParticles3D

signal burst_finished

var _timer: float = 0.0
var _active: bool = false

func _ready() -> void:
	one_shot = true
	emitting = false

func set_color(primary: Color, secondary: Color) -> void:
	var mat := process_material as ParticleProcessMaterial
	if mat:
		mat = mat.duplicate() as ParticleProcessMaterial
		process_material = mat
		mat.color = primary
		# Gradient: primary → secondary → transparent
		var grad := GradientTexture1D.new()
		var g := Gradient.new()
		g.set_color(0, primary)
		g.add_point(0.6, secondary)
		g.add_point(1.0, Color(secondary.r, secondary.g, secondary.b, 0.0))
		grad.gradient = g
		mat.color_ramp = grad

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
