extends GPUParticles3D

## U5: the ambient life between beats. ONE emitter, parented to the drone camera at runtime
## (drone_camera.gd adds it in _ready), filling a 12 x 8 x 6 m box in front of the lens with
## tiny unshaded over-bright quads: cyan dust (Zones 1-3), falling rain streaks (4-5), magenta
## motes (6-10). Colour, count and style per zone come from ZoneAtmosphere.TABLE
## (ambient_color / ambient_amount / ambient_style) and are applied on SignalBus.zone_entered.
## The emitter is a child of the camera but top_level, copying only the camera's POSITION (plus
## FOLLOW_DISTANCE along its view): the box stays world-aligned, so rain falls straight down
## in the top-down framing too.
## Budget: the table never exceeds 60 particles (<= 80 live ambient particles).

const ZoneAtmosphereScript := preload("res://levels/components/zone_atmosphere.gd")
## Over-bright multiplier (sRGB): the quads sit above glow_hdr_threshold and bloom.
const HDR_BOOST := 2.0

## The box is centred this far in front of the camera (the player sits ~10-13 m away).
const FOLLOW_DISTANCE := 10.0

## A camera jump (respawn, checkpoint, a capture teleport) farther than this in one frame leaves
## the box empty (particles live in world space); the system restarts, and its preprocess
## re-fills the new volume at once.
const JUMP_RESTART_DISTANCE := 8.0

const DUST_SIZE := Vector2(0.03, 0.03)
const MOTE_SIZE := Vector2(0.045, 0.045)
const RAIN_SIZE := Vector2(0.015, 0.5)
const DRIFT_LIFETIME := 6.0
const RAIN_LIFETIME := 0.9

var current_zone: int = 0
var current_style: String = ""
var current_color: Color = Color.WHITE

## How many times a camera jump re-filled the box (tests).
var jump_restarts: int = 0

var _last_follow_position: Vector3 = Vector3.INF
var _process_mat: ParticleProcessMaterial = null
var _material: StandardMaterial3D = null
var _quad: QuadMesh = null

func _ready() -> void:
	top_level = true
	# Keep following the camera even when something disables it (the capture tool freezes the
	# camera with process_mode DISABLED, which would otherwise strand the box where it was).
	process_mode = Node.PROCESS_MODE_ALWAYS
	# Private copies: zone changes must never write into the cached scene resources.
	_process_mat = (process_material as ParticleProcessMaterial).duplicate() as ParticleProcessMaterial
	process_material = _process_mat
	_quad = (draw_pass_1 as QuadMesh).duplicate() as QuadMesh
	_material = _quad.material.duplicate() as StandardMaterial3D
	_quad.material = _material
	draw_pass_1 = _quad
	SignalBus.zone_entered.connect(_on_zone_entered)
	apply_zone(1)
	follow_camera()

func _process(_delta: float) -> void:
	follow_camera()

## Moves the world-aligned box to FOLLOW_DISTANCE in front of the parent camera.
func follow_camera() -> void:
	var cam := get_parent() as Node3D
	if cam and cam.is_inside_tree() and is_inside_tree():
		var target := cam.global_position - cam.global_basis.z * FOLLOW_DISTANCE
		global_transform = Transform3D(Basis.IDENTITY, target)
		if _last_follow_position != Vector3.INF and target.distance_to(_last_follow_position) > JUMP_RESTART_DISTANCE:
			jump_restarts += 1
			restart()
		_last_follow_position = target

func _on_zone_entered(zone_name: String) -> void:
	apply_zone(ZoneAtmosphereScript.parse_zone_number(zone_name))

## Applies a zone's row of the atmosphere table (unknown zone: no change).
func apply_zone(zone: int) -> void:
	var row: Dictionary = ZoneAtmosphereScript.get_atmosphere(zone)
	if row.is_empty():
		return
	current_zone = zone
	current_color = row["ambient_color"]
	_set_style(row["ambient_style"])
	_material.albedo_color = Color(current_color.r * HDR_BOOST, current_color.g * HDR_BOOST, current_color.b * HDR_BOOST, 1.0)
	var count: int = row["ambient_amount"]
	if amount != count:
		amount = count

func _set_style(style: String) -> void:
	if style == current_style:
		return
	current_style = style
	match style:
		"rain":
			# Streaks fall from the top of the box and live just long enough to cross it.
			lifetime = RAIN_LIFETIME
			_quad.size = RAIN_SIZE
			_material.billboard_mode = BaseMaterial3D.BILLBOARD_DISABLED
			_process_mat.particle_flag_align_y = true
			_process_mat.emission_shape_offset = Vector3(0.0, 4.0, 0.0)
			_process_mat.emission_box_extents = Vector3(6.0, 0.5, 3.0)
			_process_mat.direction = Vector3(0.0, -1.0, 0.0)
			_process_mat.spread = 2.0
			_process_mat.initial_velocity_min = 9.0
			_process_mat.initial_velocity_max = 13.0
		_:
			lifetime = DRIFT_LIFETIME
			_quad.size = MOTE_SIZE if style == "mote" else DUST_SIZE
			_material.billboard_mode = BaseMaterial3D.BILLBOARD_PARTICLES
			_process_mat.particle_flag_align_y = false
			_process_mat.emission_shape_offset = Vector3.ZERO
			_process_mat.emission_box_extents = Vector3(6.0, 4.0, 3.0)
			_process_mat.direction = Vector3(0.0, 0.3, 0.0)
			_process_mat.spread = 180.0
			_process_mat.initial_velocity_min = 0.1
			_process_mat.initial_velocity_max = 0.35 if style == "dust" else 0.5
	restart()
