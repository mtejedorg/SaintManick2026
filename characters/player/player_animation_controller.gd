class_name PlayerAnimationController
extends Node

# Populate in Inspector once FBX clips are imported into Godot
@export var animation_map: Dictionary = {}

var anim_player: AnimationPlayer = null
var _current_play_once_clip: String = ""

func _ready() -> void:
	var visual = owner.get_node_or_null("MeshInstance3D/CharacterVisual")
	if visual:
		anim_player = visual._find_animation_player_recursive(visual)
		if not anim_player:
			push_warning("PlayerAnimationController: AnimationPlayer not found recursively in CharacterVisual.")
	else:
		push_warning("PlayerAnimationController: CharacterVisual node not found at MeshInstance3D/CharacterVisual.")

func play(anim_name: String) -> void:
	if not anim_player:
		return
	if animation_map.is_empty():
		# Expected until Mixamo clips are imported and mapped — stay silent.
		return
	if not animation_map.has(anim_name):
		push_warning("PlayerAnimationController: no clip mapped for '%s'" % anim_name)
		return
	var clip = animation_map[anim_name]
	if not anim_player.has_animation(clip):
		push_warning("PlayerAnimationController: clip '%s' not found in AnimationPlayer" % clip)
		return
	anim_player.play(clip)

func play_once(anim_name: String) -> void:
	if not anim_player:
		return
	if animation_map.is_empty():
		return
	if not animation_map.has(anim_name):
		push_warning("PlayerAnimationController: no clip mapped for '%s'" % anim_name)
		return
	var clip = animation_map[anim_name]
	if not anim_player.has_animation(clip):
		push_warning("PlayerAnimationController: clip '%s' not found in AnimationPlayer" % clip)
		return
	_current_play_once_clip = clip
	anim_player.play(clip)
	await anim_player.animation_finished
	# Only fall back to idle if no other play_once has taken over since we started
	if _current_play_once_clip == clip:
		_current_play_once_clip = ""
		play("idle")
