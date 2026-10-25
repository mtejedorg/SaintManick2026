class_name PlayerAnimationController
extends Node

# Populate in Inspector once FBX clips are imported into Godot
@export var animation_map: Dictionary = {}
## Cross-fade applied between every clip change (AnimationPlayer.playback_default_blend_time).
@export var blend_time: float = 0.1

var anim_player: AnimationPlayer = null
## Bumped by every play()/play_once()/play_fitted(): a play_once coroutine only falls back
## to idle if no other clip has been requested since it started.
var _play_once_token: int = 0

func _ready() -> void:
	var visual = owner.get_node_or_null("MeshInstance3D/CharacterVisual")
	if visual:
		anim_player = visual._find_animation_player_recursive(visual)
		if not anim_player:
			push_warning("PlayerAnimationController: AnimationPlayer not found recursively in CharacterVisual.")
	else:
		push_warning("PlayerAnimationController: CharacterVisual node not found at MeshInstance3D/CharacterVisual.")
	if anim_player:
		anim_player.playback_default_blend_time = blend_time

## Resolves a semantic key to an AnimationPlayer clip name, or "" (with a warning when the
## map is populated but the key/clip is missing).
func _resolve_clip(anim_name: String) -> String:
	if not anim_player:
		return ""
	if animation_map.is_empty():
		# Expected until Mixamo clips are imported and mapped — stay silent.
		return ""
	if not animation_map.has(anim_name):
		push_warning("PlayerAnimationController: no clip mapped for '%s'" % anim_name)
		return ""
	var clip: String = animation_map[anim_name]
	if not anim_player.has_animation(clip):
		push_warning("PlayerAnimationController: clip '%s' not found in AnimationPlayer" % clip)
		return ""
	return clip

func play(anim_name: String) -> void:
	var clip := _resolve_clip(anim_name)
	if clip == "":
		return
	_play_once_token += 1 # any pending play_once must not override this clip with idle
	anim_player.play(clip)

func play_once(anim_name: String) -> void:
	var clip := _resolve_clip(anim_name)
	if clip == "":
		return
	_play_once_token += 1
	var token := _play_once_token
	anim_player.play(clip)
	await anim_player.animation_finished
	# Only fall back if nothing else was requested since we started -- to the current
	# state resting clip (H3: a hit react while running resumes the run), else idle.
	if token == _play_once_token:
		play(_fallback_key())

## H3: the anim_key of the owner current PlayerState, or "idle".
func _fallback_key() -> String:
	var sm: Node = owner.get_node_or_null("StateMachine") if owner else null
	var state: Variant = sm.get("current_state") if sm else null
	if state is PlayerState and (state as PlayerState).anim_key != "":
		return (state as PlayerState).anim_key
	return "idle"


## Plays a clip time-stretched to last exactly `duration` seconds (custom_speed =
## clip_length / duration) so a 1.0-3.5 s Mixamo clip fits a 0.25-0.65 s gameplay state
## instead of being cut off mid-motion.
func play_fitted(anim_name: String, duration: float) -> void:
	var clip := _resolve_clip(anim_name)
	if clip == "":
		return
	_play_once_token += 1
	var length: float = anim_player.get_animation(clip).length
	var speed: float = length / duration if duration > 0.0 and length > 0.0 else 1.0
	anim_player.play(clip, -1.0, speed)
