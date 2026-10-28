extends Node

## U1: Nick's motion layer, created and owned by VFXManager (pooled: ONE katana trail, ONE dash
## streak, ONE landing puff, built once, re-fired per event; nothing is instantiated per use).
##
## Nothing here edits a player scene: the katana ribbon samples a BoneAttachment3D added at
## RUNTIME to the player's own Skeleton3D, and the events are read by polling (no bus signal
## carries them). V7: the ribbon is a SCRIPT ribbon (the GPU-particle one had zero-velocity
## heads and no provable length): the last RIBBON_SAMPLES positions of the sword-hand bone are
## sampled every physics frame while the attack window is open and drawn as a camera-facing
## triangle strip on an ImmediateMesh (width 0.25 m at the head -> 0 at the tail, alpha fading
## with it, unshaded additive over-bright cyan; amber on a heavy swing).
##  - attack window = the katana/bionic-arm Hitbox3D `is_active` flag (the exact span in which
##    a swing can connect; heavy = the bionic arm), held TRAIL_HOLD s past the end so the
##    chain's one-frame hitbox re-arm does not strobe the trail;
##  - dash/roll = the player's state machine current_state.name changing to StateDash/StateRoll;
##  - landing = airborne -> floor with a fall speed above LAND_FALL_SPEED (the last airborne
##    velocity.y, since move_and_slide zeroes it on the landing frame).

const DASH_STREAK_SCENE := preload("res://vfx/dash_streak.tscn")
const LAND_DUST_SCENE := preload("res://vfx/land_dust.tscn")

## The katana hand first (the strike-window measurements in PlayerAnimationController are the
## right hand), then the other hand.
const TRAIL_BONES: Array[String] = ["mixamorig_RightHand", "mixamorig_LeftHand"]
const TRAIL_HOLD := 0.05
## V7: ribbon length in samples, head width (m) and the two swing colours (over-bright, unshaded).
const RIBBON_SAMPLES := 8
const RIBBON_WIDTH := 0.25
const COLOR_LIGHT := Color(0.0, 1.92, 2.0, 1.0)  # cyan #00F5FF x2
const COLOR_HEAVY := Color(2.0, 1.4, 0.4, 1.0)   # amber (1.0, 0.7, 0.2) x2
const LAND_FALL_SPEED := 6.0
const DASH_STATES: Array[String] = ["StateDash", "StateRoll"]
## Height above the player origin the streak bursts from (torso).
const STREAK_HEIGHT := 0.9

var player: Node3D = null
var skeleton: Skeleton3D = null
var attachment: BoneAttachment3D = null
## V7: the script ribbon (top-level, world-space vertices), its mesh / material and the samples.
var ribbon: MeshInstance3D = null
var ribbon_mesh: ImmediateMesh = null
var ribbon_material: StandardMaterial3D = null
var ribbon_points: Array[Vector3] = []
var ribbon_open: bool = false
var heavy: bool = false
var streak: GPUParticles3D = null
var dust: GPUParticles3D = null

## How many times each event fired (tests, and a cheap debugging readout).
var dash_bursts: int = 0
var land_bursts: int = 0

var _hold: float = 0.0
var _heavy: bool = false
var _last_state: String = ""
var _was_on_floor: bool = true
var _last_air_vy: float = 0.0

func _ready() -> void:
	_build_ribbon()
	streak = DASH_STREAK_SCENE.instantiate() as GPUParticles3D
	streak.name = "DashStreak"
	add_child(streak)
	dust = LAND_DUST_SCENE.instantiate() as GPUParticles3D
	dust.name = "LandDust"
	add_child(dust)
	if not bind_player(get_tree().get_first_node_in_group("player") as Node3D):
		_late_bind.call_deferred()

func _build_ribbon() -> void:
	ribbon_mesh = ImmediateMesh.new()
	ribbon_material = StandardMaterial3D.new()
	ribbon_material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	ribbon_material.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	ribbon_material.blend_mode = BaseMaterial3D.BLEND_MODE_ADD
	ribbon_material.cull_mode = BaseMaterial3D.CULL_DISABLED
	ribbon_material.vertex_color_use_as_albedo = true
	ribbon_material.albedo_color = COLOR_LIGHT
	ribbon = MeshInstance3D.new()
	ribbon.name = "KatanaRibbon"
	ribbon.mesh = ribbon_mesh
	ribbon.top_level = true # vertices are written in world space
	ribbon.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	ribbon.extra_cull_margin = 16384.0 # the mesh is rebuilt every frame; never cull it by a stale AABB
	ribbon.visible = false
	add_child(ribbon)
	ribbon.global_transform = Transform3D.IDENTITY

## The player may enter its group a moment after this node (scene order): one retry.
func _late_bind() -> void:
	if player == null and is_inside_tree():
		bind_player(get_tree().get_first_node_in_group("player") as Node3D)

## Attaches the trail to the player's sword-hand bone. Returns false when there is no player or
## no skeleton with one of TRAIL_BONES (the rest of the layer then still runs on the player).
func bind_player(new_player: Node3D) -> bool:
	if new_player == null:
		return false
	player = new_player
	_last_state = _state_name()
	var skel := player.find_child("Skeleton3D", true, false) as Skeleton3D
	if skel == null:
		return false
	for bone in TRAIL_BONES:
		if skel.find_bone(bone) < 0:
			continue
		skeleton = skel
		attachment = BoneAttachment3D.new()
		attachment.name = "KatanaTrailAttachment"
		attachment.bone_name = bone
		skel.add_child(attachment)
		return true
	return false

func _exit_tree() -> void:
	# The attachment lives on the player's skeleton, outside this node's subtree.
	if attachment and is_instance_valid(attachment):
		attachment.queue_free()
	attachment = null
	ribbon_points.clear()

func _process(delta: float) -> void:
	if player == null or not is_instance_valid(player):
		return
	var katana := player.get("katana_hitbox") as Hitbox3D
	var arm := player.get("bionic_arm_hitbox") as Hitbox3D
	update_attack_window(katana != null and katana.is_active, arm != null and arm.is_active, delta)
	update_state(_state_name())

func _physics_process(_delta: float) -> void:
	if player == null or not is_instance_valid(player):
		return
	if ribbon_open and attachment and is_instance_valid(attachment) and attachment.is_inside_tree():
		add_ribbon_sample(attachment.global_position)
	if player is CharacterBody3D:
		var body := player as CharacterBody3D
		update_landing(body.is_on_floor(), body.velocity.y)

## The ribbon is shown while a swing's hitbox is live (+ TRAIL_HOLD); heavy swings tint amber.
## Closing the window drops the samples (the next swing starts a fresh ribbon).
func update_attack_window(katana_active: bool, arm_active: bool, delta: float) -> void:
	if attachment == null:
		return
	if katana_active or arm_active:
		_hold = TRAIL_HOLD
		_heavy = arm_active
	elif _hold > 0.0:
		_hold -= delta
	var open := katana_active or arm_active or _hold > 0.0
	if _heavy != heavy:
		heavy = _heavy
		ribbon_material.albedo_color = COLOR_HEAVY if heavy else COLOR_LIGHT
	if open and not ribbon_open:
		ribbon_points.clear()
	ribbon_open = open
	if not open and not ribbon_points.is_empty():
		ribbon_points.clear()
		_rebuild_ribbon()
	ribbon.visible = open and ribbon_points.size() >= 2

## V7: appends one world-space sample (the newest at the end), keeps RIBBON_SAMPLES of them and
## rebuilds the strip.
func add_ribbon_sample(position: Vector3) -> void:
	ribbon_points.append(position)
	while ribbon_points.size() > RIBBON_SAMPLES:
		ribbon_points.pop_front()
	_rebuild_ribbon()
	ribbon.visible = ribbon_open and ribbon_points.size() >= 2

## Two vertices per sample (a triangle strip): the head is RIBBON_WIDTH wide, the tail 0, and the
## vertex alpha fades the same way. The strip faces the active camera so the flat ribbon reads
## from the side-scroll and the top-down framing alike.
func _rebuild_ribbon() -> void:
	ribbon_mesh.clear_surfaces()
	var count := ribbon_points.size()
	if count < 2:
		return
	var view := Vector3(0.0, 0.0, -1.0)
	var cam := get_viewport().get_camera_3d() if is_inside_tree() else null
	if cam:
		view = -cam.global_transform.basis.z
	ribbon_mesh.surface_begin(Mesh.PRIMITIVE_TRIANGLE_STRIP, ribbon_material)
	for i in count:
		var along := ribbon_points[mini(i + 1, count - 1)] - ribbon_points[maxi(i - 1, 0)]
		var side := along.cross(view)
		side = side.normalized() if side.length() > 0.0001 else Vector3.UP
		var t := float(i) / float(count - 1)
		var half := RIBBON_WIDTH * 0.5 * t
		ribbon_mesh.surface_set_color(Color(1.0, 1.0, 1.0, t))
		ribbon_mesh.surface_add_vertex(ribbon_points[i] + side * half)
		ribbon_mesh.surface_set_color(Color(1.0, 1.0, 1.0, t))
		ribbon_mesh.surface_add_vertex(ribbon_points[i] - side * half)
	ribbon_mesh.surface_end()

## One streak per entry into StateDash/StateRoll (the same state twice in a row is one event).
func update_state(state_name: String) -> void:
	if state_name == _last_state:
		return
	_last_state = state_name
	if state_name in DASH_STATES:
		_burst_streak()

## One puff per airborne -> floor transition faster than LAND_FALL_SPEED.
func update_landing(on_floor: bool, velocity_y: float) -> void:
	if on_floor:
		if not _was_on_floor and -_last_air_vy > LAND_FALL_SPEED:
			_burst_dust()
		_was_on_floor = true
	else:
		_was_on_floor = false
		_last_air_vy = velocity_y

func _state_name() -> String:
	if player == null or not is_instance_valid(player):
		return ""
	var machine = player.get("state_machine")
	if machine == null or machine.get("current_state") == null:
		return ""
	return String((machine.current_state as Node).name)

func _burst_streak() -> void:
	if streak == null or player == null:
		return
	var back := Vector3.ZERO
	var body := player as CharacterBody3D
	if body and Vector2(body.velocity.x, body.velocity.z).length() > 0.5:
		back = -Vector3(body.velocity.x, 0.0, body.velocity.z)
	else:
		var facing_right = player.get("is_facing_right")
		back = Vector3.LEFT if facing_right == null or facing_right else Vector3.RIGHT
	dash_bursts += 1
	streak.burst(player.global_position + Vector3(0.0, STREAK_HEIGHT, 0.0), back)

func _burst_dust() -> void:
	if dust == null or player == null:
		return
	land_bursts += 1
	dust.burst(player.global_position - Vector3(0.0, EnemyStats.feet_offset_of(player), 0.0))
