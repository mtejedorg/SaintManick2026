class_name ShockRing
extends RefCounted

## P10: the one-shot shock ring shared by Nick's Bass Drop and the Headliner's phase-2 slam.
## An unshaded, alpha-blended torus at HDR brightness (Godot's unshaded mode drops EMISSION,
## so the glow rides on an over-bright albedo past glow_hdr_threshold 1.0) that grows from
## START_SCALE to `radius` over `seconds` and fades its alpha 1 -> 0 over the last
## FADE_FRACTION of that time, then frees itself. Created and freed rather than pooled: each
## owner fires at most one per long cooldown (a full ability meter, a boss phase).

const START_SCALE := 0.5
const FADE_FRACTION := 0.4
## Albedo multiplier (sRGB) -- ~4x linear brightness, so the ring blooms.
const HDR_BOOST := 2.0
const INNER_RADIUS := 0.9
const OUTER_RADIUS := 1.0

## Spawns the ring under `host` at `position` (world). Returns it (null without a host in
## the tree).
static func spawn(host: Node, position: Vector3, radius: float, color: Color, seconds: float, ring_name: String = "ShockRing") -> MeshInstance3D:
	if host == null or not host.is_inside_tree():
		return null
	var torus := TorusMesh.new()
	torus.inner_radius = INNER_RADIUS
	torus.outer_radius = OUTER_RADIUS
	torus.material = make_material(color)
	var ring := MeshInstance3D.new()
	ring.name = ring_name
	ring.mesh = torus
	ring.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	host.add_child(ring)
	ring.global_position = position
	ring.scale = Vector3(START_SCALE, 1.0, START_SCALE)
	var mat := torus.material as StandardMaterial3D
	var tween := ring.create_tween()
	tween.tween_property(ring, "scale", Vector3(radius, 1.0, radius), seconds).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	tween.parallel().tween_property(mat, "albedo_color:a", 0.0, seconds * FADE_FRACTION).set_delay(seconds * (1.0 - FADE_FRACTION))
	tween.tween_callback(ring.queue_free)
	return ring

## The ring material: unshaded, alpha-blended, HDR albedo.
static func make_material(color: Color) -> StandardMaterial3D:
	var mat := StandardMaterial3D.new()
	mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	mat.cull_mode = BaseMaterial3D.CULL_DISABLED
	mat.albedo_color = Color(color.r * HDR_BOOST, color.g * HDR_BOOST, color.b * HDR_BOOST, 1.0)
	return mat
