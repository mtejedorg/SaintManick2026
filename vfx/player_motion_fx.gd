extends Node

## U1: Nick's motion layer, created and owned by VFXManager (pooled: ONE katana trail, ONE dash
## streak, ONE landing puff, built once, re-fired per event; nothing is instantiated per use).
##
## Nothing here edits a player scene: the trail is attached at RUNTIME to the player's own
## Skeleton3D through a BoneAttachment3D, and the events are read by polling (no bus signal
## carries them):
##  - attack window = the katana/bionic-arm Hitbox3D `is_active` flag (the exact span in which
##    a swing can connect; heavy = the bionic arm), held TRAIL_HOLD s past the end so the
##    chain's one-frame hitbox re-arm does not strobe the trail;
##  - dash/roll = the player's state machine current_state.name changing to StateDash/StateRoll;
##  - landing = airborne -> floor with a fall speed above LAND_FALL_SPEED (the last airborne
##    velocity.y, since move_and_slide zeroes it on the landing frame).

const KATANA_TRAIL_SCENE := preload("res://vfx/katana_trail.tscn")
const DASH_STREAK_SCENE := preload("res://vfx/dash_streak.tscn")
const LAND_DUST_SCENE := preload("res://vfx/land_dust.tscn")

## The katana hand first (the strike-window measurements in PlayerAnimationController are the
## right hand), then the other hand.
const TRAIL_BONES: Array[String] = ["mixamorig_RightHand", "mixamorig_LeftHand"]
const TRAIL_HOLD := 0.05
const LAND_FALL_SPEED := 6.0
const DASH_STATES: Array[String] = ["StateDash", "StateRoll"]
## Height above the player origin the streak bursts from (torso).
const STREAK_HEIGHT := 0.9

var player: Node3D = null
var skeleton: Skeleton3D = null
var attachment: BoneAttachment3D = null
var trail: GPUParticles3D = null
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
	streak = DASH_STREAK_SCENE.instantiate() as GPUParticles3D
	streak.name = "DashStreak"
	add_child(streak)
	dust = LAND_DUST_SCENE.instantiate() as GPUParticles3D
	dust.name = "LandDust"
	add_child(dust)
	if not bind_player(get_tree().get_first_node_in_group("player") as Node3D):
		_late_bind.call_deferred()

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
		trail = KATANA_TRAIL_SCENE.instantiate() as GPUParticles3D
		trail.name = "KatanaTrail"
		attachment.add_child(trail)
		return true
	return false

func _exit_tree() -> void:
	# The attachment lives on the player's skeleton, outside this node's subtree.
	if attachment and is_instance_valid(attachment):
		attachment.queue_free()
	attachment = null
	trail = null

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
	if player is CharacterBody3D:
		var body := player as CharacterBody3D
		update_landing(body.is_on_floor(), body.velocity.y)

## The trail emits while a swing's hitbox is live (+ TRAIL_HOLD); heavy swings tint amber.
func update_attack_window(katana_active: bool, arm_active: bool, delta: float) -> void:
	if trail == null:
		return
	if katana_active or arm_active:
		_hold = TRAIL_HOLD
		_heavy = arm_active
	elif _hold > 0.0:
		_hold -= delta
	var open := katana_active or arm_active or _hold > 0.0
	if trail.has_method("set_heavy") and trail.get("heavy") != _heavy:
		trail.set_heavy(_heavy)
	trail.emitting = open

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
