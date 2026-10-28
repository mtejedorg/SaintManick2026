class_name PlayerAnimationController
extends Node

# Populate in Inspector once FBX clips are imported into Godot
@export var animation_map: Dictionary = {}
## Cross-fade applied between every clip change (AnimationPlayer.playback_default_blend_time).
@export var blend_time: float = 0.1

## R3: the strike window [t_in, t_out] (seconds) of each clip. play_fitted() plays only this
## window, so a 0.3 s swing shows the strike at <= 2x instead of the whole 1-3.5 s clip at
## 5-12x. Measured from the bone-speed peak of each clip (right hand for the katana slashes,
## hips/head for reactions), t_in = strike - 0.25, t_out = strike + 0.15, then clamped to
## the clip. Shared with EnemyAnimator (same library). Keys without a window fit the whole clip.
const SEGMENTS: Dictionary = {
	"attack_light": [0.18, 0.58], # right-hand peak 0.43 s (clip 1.0 s)
	"attack_heavy": [1.10, 1.50], # two-handed slam, hands + hips low at 1.35 s (clip 2.43 s)
	"attack_combo": [0.98, 1.38], # second slash, right-hand peak 1.23 s (clip 3.53 s)
	"hit_react": [0.0, 0.30],     # recoil snap, peak 0.07-0.10 s (clip 0.77 s)
	"death": [0.9, 1.6],          # the collapse, hips 0.49 -> 0.09 (clip 2.3 s; enemies only)
	"land": [0.0, 0.4],           # impact crouch, hands peak 0.13 s (clip 2.0 s)
	"run_stop": [0.0, 0.3],       # the plant, peak 0.20 s (clip 0.9 s)
}

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
## R3: a key with a SEGMENTS window plays only that window (play_segment) — the attack
## state calls this unchanged.
func play_fitted(anim_name: String, duration: float) -> void:
	if SEGMENTS.has(anim_name):
		var window: Array = SEGMENTS[anim_name]
		play_segment(anim_name, window[0], window[1], duration)
		return
	var clip := _resolve_clip(anim_name)
	if clip == "":
		return
	_play_once_token += 1
	var length: float = anim_player.get_animation(clip).length
	var speed: float = length / duration if duration > 0.0 and length > 0.0 else 1.0
	anim_player.play(clip, -1.0, speed)

## R3: plays the clip's [t_in, t_out] window stretched to `duration` seconds (speed =
## (t_out - t_in) / duration), starting at t_in. When the window ends the current state's
## resting clip (its anim_key) takes over; a state without one (attack, hurt) holds the
## window's last pose until it plays its own next clip.
func play_segment(anim_name: String, t_in: float, t_out: float, duration: float) -> void:
	var clip := _resolve_clip(anim_name)
	if clip == "":
		return
	_play_once_token += 1
	var token := _play_once_token
	var length: float = anim_player.get_animation(clip).length
	var start := clampf(t_in, 0.0, length)
	var end := clampf(t_out, start, length)
	var span := end - start
	var speed: float = span / duration if duration > 0.0 and span > 0.0 else 1.0
	anim_player.play_section(clip, start, end, -1.0, speed)
	anim_player.seek(start, true) # restart even when the same clip is mid-play (combo 2 -> 3)
	await anim_player.animation_finished
	if token == _play_once_token and is_instance_valid(anim_player):
		var rest := _resting_key()
		if rest != "":
			play(rest)

## The owner's current PlayerState anim_key, or "" when it has none.
func _resting_key() -> String:
	var sm: Node = owner.get_node_or_null("StateMachine") if owner else null
	var state: Variant = sm.get("current_state") if sm else null
	if state is PlayerState:
		return (state as PlayerState).anim_key
	return ""

## J3: play_fitted() plus the play_once() fallback -- the zero-stun flinch squeezes
## hit_react into `duration` seconds, then returns to the current state's resting clip
## (unless another clip was requested meanwhile).
func play_once_fitted(anim_name: String, duration: float) -> void:
	if _resolve_clip(anim_name) == "":
		return
	play_fitted(anim_name, duration)
	var token := _play_once_token
	await anim_player.animation_finished
	if token == _play_once_token:
		play(_fallback_key())
