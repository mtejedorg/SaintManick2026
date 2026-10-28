extends RefCounted

## U3: the reactive half of a boss shield bubble (Enforcer, Headliner). Owns the per-instance
## copies of the bubble materials (so two bosses never share shader uniforms), the hit ripple on
## the rim shader (assets/shaders/shield_bubble.gdshader: hit_pos / hit_time) and the break
## flash. Used through `preload`, one instance per boss, created in the boss's _ready.
##
## The bubble itself is hidden by the boss states (exit() of the shield states), which run
## BEFORE any later code of the same break; so the break flash plays on a persistent "ghost"
## copy of the bubble mesh that outlives the hide.

const RIPPLE_SECONDS := 0.35
const BREAK_SECONDS := 0.1
const BREAK_SCALE := 1.1
const BREAK_ALPHA := 0.9
## A blocked hit counts for this bubble when it lands within radius + this margin (metres).
const HIT_RANGE_MARGIN := 2.0

var bubble: MeshInstance3D = null
## Per-instance copy of the bubble's StandardMaterial3D (the one the overheat tint drives).
var base_material: StandardMaterial3D = null
## Per-instance copy of its next_pass: the fresnel + ripple ShaderMaterial.
var rim_material: ShaderMaterial = null
var ripple_tween: Tween = null
var break_tween: Tween = null
var ripples: int = 0
var breaks: int = 0
var _ghost: MeshInstance3D = null
var _ghost_material: StandardMaterial3D = null

func _init(target: MeshInstance3D = null) -> void:
	if target:
		setup(target)

## Duplicates the bubble's material chain once and installs the copies. False without a bubble
## or without its StandardMaterial3D.
func setup(target: MeshInstance3D) -> bool:
	bubble = target
	var source := bubble.get_surface_override_material(0) as StandardMaterial3D
	if source == null:
		return false
	base_material = source.duplicate() as StandardMaterial3D
	if source.next_pass is ShaderMaterial:
		rim_material = (source.next_pass as ShaderMaterial).duplicate() as ShaderMaterial
		base_material.next_pass = rim_material
	bubble.set_surface_override_material(0, base_material)
	if rim_material:
		rim_material.set_shader_parameter("hit_time", 1.0)
		# The ring must be able to reach the far side of the sphere (its diameter).
		rim_material.set_shader_parameter("ripple_radius", radius() * 2.0)
	return true

## World radius of the bubble sphere (mesh radius x scale).
func radius() -> float:
	if bubble and bubble.mesh is SphereMesh:
		var world_scale := bubble.global_transform.basis.get_scale().x if bubble.is_inside_tree() else bubble.scale.x
		return (bubble.mesh as SphereMesh).radius * world_scale
	return 1.0

## True when a blocked hit at `position` is on this bubble.
func is_hit_in_range(position: Vector3) -> bool:
	return bubble != null and position.distance_to(bubble.global_position) <= radius() + HIT_RANGE_MARGIN

## Starts the ripple where the hit lands on the bubble surface. Blocked hits report the
## hurtbox centre (the boss's own origin), so with no usable direction in `position` the
## ripple heads toward `fallback_toward` (Nick).
func ripple(position: Vector3, fallback_toward: Vector3 = Vector3.ZERO) -> void:
	if bubble == null or rim_material == null:
		return
	var origin := bubble.global_position
	var dir := position - origin
	if dir.length() < 0.5 and fallback_toward != Vector3.ZERO:
		dir = fallback_toward - origin
	dir = dir.normalized() if dir.length() > 0.001 else Vector3.RIGHT
	rim_material.set_shader_parameter("hit_pos", origin + dir * radius())
	rim_material.set_shader_parameter("hit_time", 0.0)
	ripples += 1
	if ripple_tween and ripple_tween.is_valid():
		ripple_tween.kill()
	ripple_tween = bubble.create_tween()
	ripple_tween.tween_method(_set_hit_time, 0.0, 1.0, RIPPLE_SECONDS)

func _set_hit_time(value: float) -> void:
	if rim_material:
		rim_material.set_shader_parameter("hit_time", value)

## The shield broke: a white flash that swells 1.0 -> BREAK_SCALE over BREAK_SECONDS and fades,
## on a ghost copy of the bubble (the real one is hidden by the state change).
func break_flash() -> void:
	if bubble == null or not bubble.is_inside_tree() or bubble.get_parent() == null:
		return
	if _ghost == null:
		_ghost_material = StandardMaterial3D.new()
		_ghost_material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
		_ghost_material.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
		_ghost_material.blend_mode = BaseMaterial3D.BLEND_MODE_ADD
		_ghost_material.cull_mode = BaseMaterial3D.CULL_DISABLED
		_ghost_material.albedo_color = Color(2.0, 2.0, 2.0, BREAK_ALPHA)
		_ghost = MeshInstance3D.new()
		_ghost.name = "ShieldBreakFlash"
		_ghost.mesh = bubble.mesh
		_ghost.material_override = _ghost_material
		_ghost.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		bubble.get_parent().add_child(_ghost)
	breaks += 1
	_ghost.transform = bubble.transform
	var base_scale := bubble.scale
	_ghost.scale = base_scale
	_ghost_material.albedo_color.a = BREAK_ALPHA
	_ghost.visible = true
	if break_tween and break_tween.is_valid():
		break_tween.kill()
	break_tween = _ghost.create_tween().set_parallel(true)
	break_tween.tween_property(_ghost, "scale", base_scale * BREAK_SCALE, BREAK_SECONDS)
	break_tween.tween_property(_ghost_material, "albedo_color:a", 0.0, BREAK_SECONDS)
	break_tween.chain().tween_callback(_hide_ghost)

func _hide_ghost() -> void:
	if _ghost:
		_ghost.visible = false
