class_name EnemyAnimator
extends Node

## R2: drives the clips of the shared rigged enemy body (enemy_body_visual.tscn, which uses
## Nick's clip library). A child Node of the enemy body; the enemy script reports its beat
## sequence (on_attack_step), the combat component its stuns (on_stun_started) and the body
## its death (on_died). Locomotion (idle / run) follows the body's horizontal velocity and only
## changes clip on an edge, never every frame.
##   step 1 (telegraph): attack clip frozen at its wind-up (segment start), held for the beat.
##   step 2 (active):    the wind-up -> strike window resumed, fitted to one beat.
##   stun:               hit_react window fitted to the running stun.
##   death:              the collapse window fitted to death_anim_seconds; CharacterVisual
##                       delays its shrink by this much (it reads it via has_node).

enum Action { NONE, TELEGRAPH, STRIKE, STUN, DEATH }

## The CharacterVisual root whose AnimationPlayer this drives (found recursively).
@export var visual_path: NodePath = ^"../MeshInstance3D"
## The swing clip: Runner attack_light, Bruiser attack_heavy.
@export var attack_key: String = "attack_light"
## Horizontal speed (m/s) at or above which the body plays run instead of idle.
@export var move_threshold: float = 0.3
@export var run_speed_scale: float = 1.15
@export var idle_speed_scale: float = 1.0
## Seconds the death clip plays before the CharacterVisual shrink starts.
@export var death_anim_seconds: float = 0.35
## Cross-fade between clips (AnimationPlayer.playback_default_blend_time).
@export var blend_time: float = 0.12
## The hit_react window used when no stun time can be read.
@export var fallback_stun_seconds: float = 0.3

var anim_player: AnimationPlayer = null
var action: Action = Action.NONE
## The locomotion key currently playing ("" = none: an action owns the player).
var locomotion_key: String = ""
## Every clip start this animator issued (tests prove change-edge playback with it).
var play_count: int = 0

func _ready() -> void:
	var visual := get_node_or_null(visual_path)
	if visual:
		anim_player = _find_animation_player(visual)
	if anim_player == null:
		push_warning("EnemyAnimator: no AnimationPlayer under %s" % visual_path)
		return
	anim_player.playback_default_blend_time = blend_time
	anim_player.animation_finished.connect(_on_animation_finished)
	_update_locomotion() # posed idle from the first frame, never the bind pose

func _physics_process(_delta: float) -> void:
	_update_locomotion()

func _update_locomotion() -> void:
	if anim_player == null or action != Action.NONE:
		return
	var body := get_parent() as CharacterBody3D
	var speed := Vector2(body.velocity.x, body.velocity.z).length() if body else 0.0
	var key := "run" if speed >= move_threshold else "idle"
	if key == locomotion_key:
		return
	locomotion_key = key
	_start(key, 0.0, -1.0, run_speed_scale if key == "run" else idle_speed_scale)

## The enemy's attack sequence changed (0 idle, 1 telegraph, 2 active, 3 recovery).
func on_attack_step(step: int) -> void:
	if anim_player == null or action == Action.DEATH:
		return
	var window := window_of(attack_key)
	match step:
		1:
			action = Action.TELEGRAPH
			locomotion_key = ""
			_start(attack_key, window.x, window.y, 0.0) # frozen at the wind-up
		2:
			action = Action.STRIKE
			locomotion_key = ""
			var hold := anim_player.current_animation_position if _is_playing(attack_key) else window.x
			var span := maxf(window.y - hold, 0.01)
			_start(attack_key, hold, window.y, span / beat_seconds())
		_:
			if action == Action.TELEGRAPH:
				_release() # cancelled tell
			# Recovery: the strike window plays out and hands back on animation_finished.

## EnemyCombatComponent.stun_started: hit_react fitted to the running stun.
func on_stun_started() -> void:
	if anim_player == null or action == Action.DEATH:
		return
	action = Action.STUN
	locomotion_key = ""
	var window := window_of("hit_react")
	var stun := _stun_seconds()
	_start("hit_react", window.x, window.y, (window.y - window.x) / stun)

## The enemy died: the collapse window over death_anim_seconds; nothing plays after it.
func on_died() -> void:
	if anim_player == null or action == Action.DEATH:
		return
	action = Action.DEATH
	locomotion_key = ""
	var window := window_of("death")
	_start("death", window.x, window.y, (window.y - window.x) / maxf(death_anim_seconds, 0.05))

## One beat of the world's current tempo.
func beat_seconds() -> float:
	return 60.0 / maxf(Conductor.bpm, 1.0)

## The [t_in, t_out] window of `key` (PlayerAnimationController.SEGMENTS, the same library),
## or the whole clip.
func window_of(key: String) -> Vector2:
	var length := 0.0
	if anim_player and anim_player.has_animation(key):
		length = anim_player.get_animation(key).length
	if PlayerAnimationController.SEGMENTS.has(key):
		var w: Array = PlayerAnimationController.SEGMENTS[key]
		return Vector2(clampf(w[0], 0.0, length), clampf(w[1], 0.0, length))
	return Vector2(0.0, length)

func _start(key: String, from: float, to: float, speed: float) -> void:
	if not anim_player.has_animation(key):
		return
	var end := to if to >= 0.0 else -1.0
	anim_player.play_section(key, from, end, -1.0, speed)
	anim_player.seek(from, true)
	play_count += 1

func _is_playing(key: String) -> bool:
	return String(anim_player.current_animation) == key

func _release() -> void:
	action = Action.NONE
	locomotion_key = ""
	_update_locomotion()

func _on_animation_finished(_clip: StringName) -> void:
	if action == Action.STRIKE or action == Action.STUN:
		_release()

func _stun_seconds() -> float:
	var comp: Variant = get_parent().get("combat_comp") if get_parent() else null
	if comp is Node and is_instance_valid(comp) and (comp as Node).has_method("is_stunned"):
		var t: float = (comp as Node).get("stun_timer")
		if t > 0.0:
			return t
	return fallback_stun_seconds

func _find_animation_player(node: Node) -> AnimationPlayer:
	for child in node.get_children():
		if child is AnimationPlayer:
			return child
		var found := _find_animation_player(child)
		if found:
			return found
	return null
