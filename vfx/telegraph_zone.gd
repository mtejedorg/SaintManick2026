extends MeshInstance3D

## U2: the telegraph footprint, a flat glowing disc on the floor under the spot an attack is
## about to hit. Built from the enemy's own Hitbox3D shape (read once, at attach time), parented
## to the enemy so it follows it, and shown for the telegraph beat only: alpha 0.15 -> 0.6 over
## one beat, hidden the moment the hitbox arms. One zone per enemy, created in its _ready
## (a few live at once; never instantiated per attack).

## Loaded lazily (a preload would be a cyclic reference: the scene points back at this script).
const SCENE_PATH := "res://vfx/telegraph_zone.tscn"
const COLOR_MAGENTA := Color(1.0, 0.0, 0.667, 1.0)  # Runner / Bruiser / Enforcer
const COLOR_AMBER := Color(1.0, 0.7, 0.2, 1.0)      # Headliner
const ALPHA_START := 0.15
const ALPHA_END := 0.6
## Lift above the floor (m): clears z-fighting with the ground.
const FLOOR_LIFT := 0.02
## Albedo multiplier: ~4x linear brightness so the disc blooms (unshaded drops EMISSION).
const HDR_BOOST := 1.5

var _material: StandardMaterial3D = null
var _tween: Tween = null
var _color: Color = COLOR_MAGENTA

## Creates a zone under `enemy`, sized to `hitbox`'s collision shape, lying on the floor
## below the enemy. Returns null without an enemy/hitbox.
static func attach(enemy: Node3D, hitbox: Node, color: Color) -> MeshInstance3D:
	if enemy == null or hitbox == null:
		return null
	var zone := (load(SCENE_PATH) as PackedScene).instantiate() as MeshInstance3D
	zone.name = "TelegraphZone"
	enemy.add_child(zone)
	var footprint := footprint_of(hitbox)
	zone.configure(footprint.size, color)
	# The hitbox shape's centre, flattened onto the floor.
	var centre: Vector3 = (hitbox as Node3D).position + footprint.centre
	var feet: float = EnemyStats.feet_offset_of(enemy)
	zone.position = Vector3(centre.x, -feet + FLOOR_LIFT, centre.z)
	return zone

## { size: Vector2 (x, z metres), centre: Vector3 (offset of the shape inside the hitbox) } of
## the hitbox's first CollisionShape3D (capsule/sphere: the diameter; box: its x/z).
static func footprint_of(hitbox: Node) -> Dictionary:
	var out := {"size": Vector2.ONE, "centre": Vector3.ZERO}
	for child in hitbox.get_children():
		var col := child as CollisionShape3D
		if col == null or col.shape == null:
			continue
		out["centre"] = col.position
		if col.shape is CapsuleShape3D:
			var d := (col.shape as CapsuleShape3D).radius * 2.0
			out["size"] = Vector2(d, d)
		elif col.shape is SphereShape3D:
			var d := (col.shape as SphereShape3D).radius * 2.0
			out["size"] = Vector2(d, d)
		elif col.shape is BoxShape3D:
			var s := (col.shape as BoxShape3D).size
			out["size"] = Vector2(s.x, s.z)
		break
	return out

func _ready() -> void:
	visible = false
	cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	# Private material: each zone is tinted and faded on its own.
	if mesh and (mesh as PrimitiveMesh).material:
		_material = (mesh as PrimitiveMesh).material.duplicate() as StandardMaterial3D
		mesh = mesh.duplicate()
		(mesh as PrimitiveMesh).material = _material
		_set_alpha(ALPHA_START)

func configure(size: Vector2, color: Color) -> void:
	_color = color
	if mesh is QuadMesh:
		(mesh as QuadMesh).size = size
	if _material:
		_set_alpha(ALPHA_START)

## Shows the zone and fades it in over `seconds` (one beat).
func show_telegraph(seconds: float) -> void:
	_kill_tween()
	visible = true
	_set_alpha(ALPHA_START)
	_tween = create_tween()
	_tween.tween_method(_set_alpha, ALPHA_START, ALPHA_END, maxf(seconds, 0.01))

## The hitbox armed (or the attack was cancelled): gone.
func hide_telegraph() -> void:
	_kill_tween()
	visible = false

func is_showing() -> bool:
	return visible

func _kill_tween() -> void:
	if _tween and _tween.is_valid():
		_tween.kill()
	_tween = null

func _set_alpha(alpha: float) -> void:
	if _material:
		_material.albedo_color = Color(_color.r * HDR_BOOST, _color.g * HDR_BOOST, _color.b * HDR_BOOST, alpha)

## Current disc alpha (tests).
func current_alpha() -> float:
	return _material.albedo_color.a if _material else 0.0
