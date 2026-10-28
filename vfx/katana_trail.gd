extends GPUParticles3D

## U1: the katana trail. One GPUParticles3D ribbon parented (at runtime, by PlayerMotionFx) to
## a BoneAttachment3D on Nick's sword hand. The emitter is top_level and only copies the bone's
## POSITION each frame, so the flat ribbon always faces the side-scroll camera instead of
## twisting with the wrist. Emitting is driven from outside (the attack window).

const COLOR_LIGHT := Color(0.0, 1.92, 2.0, 1.0)  # cyan #00F5FF x2: over-bright, unshaded
const COLOR_HEAVY := Color(2.0, 1.4, 0.4, 1.0)   # amber (1.0, 0.7, 0.2) x2

var heavy: bool = false
var _material: StandardMaterial3D = null

func _ready() -> void:
	top_level = true
	emitting = false
	# Private copy of the draw material so the tint never writes into the cached scene resource.
	var mesh := draw_pass_1
	if mesh:
		mesh = mesh.duplicate()
		_material = (mesh as PrimitiveMesh).material.duplicate() as StandardMaterial3D
		(mesh as PrimitiveMesh).material = _material
		draw_pass_1 = mesh
	set_heavy(false)

## Heavy swings tint amber, light swings cyan.
func set_heavy(value: bool) -> void:
	heavy = value
	if _material:
		_material.albedo_color = COLOR_HEAVY if value else COLOR_LIGHT

func _process(_delta: float) -> void:
	var parent := get_parent() as Node3D
	if parent:
		global_transform = Transform3D(Basis.IDENTITY, parent.global_position)
