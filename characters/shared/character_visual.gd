extends MeshInstance3D
class_name CharacterVisual

## Shared character visual root: owns the base material policy and the per-instance neon
## rim overlay for every child mesh of the instanced model.
##
## Base material policy:
##   tint == WHITE  -> keep the model's own imported materials/textures. Never overridden.
##   any other tint -> ONE dark base material (near-black, 18 % toward the tint) on every
##                     child mesh. Feedback (telegraph, vulnerable, phase change) is carried
##                     by the RIM, never by swapping base materials.
@export var tint: Color = Color.WHITE

## Selects the default rim colour: PLAYER -> cyan #00F5FF, ENEMY -> magenta #FF00AA.
enum Faction { PLAYER, ENEMY }
@export var faction: Faction = Faction.ENEMY
## Rim colour override. Alpha 0 (the default) means "use the faction colour".
@export var rim_color: Color = Color(0.0, 0.0, 0.0, 0.0)
@export var rim_strength: float = 3.0

const PLAYER_RIM_COLOR := Color(0.0, 0.960784, 1.0, 1.0)     # #00F5FF cyan
const ENEMY_RIM_COLOR := Color(1.0, 0.0, 0.666667, 1.0)      # #FF00AA magenta
## Shared telegraph language: a white-hot rim one beat before the hit.
const TELEGRAPH_RIM_COLOR := Color(1.0, 1.0, 1.0, 1.0)
const TELEGRAPH_RIM_STRENGTH := 6.0
## Vulnerable window (post-attack recovery / shield break).
const VULNERABLE_RIM_COLOR := Color(0.2, 0.6, 1.0, 1.0)

const DARK_BASE_ALBEDO := Color(0.05, 0.05, 0.08, 1.0)
const DARK_BASE_TINT_WEIGHT := 0.18
const DARK_BASE_ROUGHNESS := 0.55

const RIM_MATERIAL := preload("res://assets/shaders/neon_rim_material.tres")

var skinned_meshes: Array[MeshInstance3D] = []
## The dark base material (null for a WHITE tint — the model keeps its own materials).
var base_material: StandardMaterial3D = null
## Per-instance rim overlay so changing one character's rim never touches another's.
var _rim_material_instance: ShaderMaterial = null
## The rim the character returns to after a flash (changed by update_rim_color/strength).
var _base_rim_color: Color
var _base_rim_strength: float
var _rim_tween: Tween = null

func _ready() -> void:
	skinned_meshes.clear()
	_find_mesh_instances_recursive(self)

	if tint != Color.WHITE:
		base_material = StandardMaterial3D.new()
		base_material.albedo_color = DARK_BASE_ALBEDO.lerp(tint, DARK_BASE_TINT_WEIGHT)
		base_material.roughness = DARK_BASE_ROUGHNESS
		base_material.metallic = 0.0
		base_material.emission_enabled = false
		for sm in skinned_meshes:
			sm.material_override = base_material

	_base_rim_color = get_default_rim_color()
	_base_rim_strength = rim_strength
	_rim_material_instance = RIM_MATERIAL.duplicate() as ShaderMaterial
	_rim_material_instance.set_shader_parameter("rim_color", _base_rim_color)
	_rim_material_instance.set_shader_parameter("rim_strength", _base_rim_strength)
	for sm in skinned_meshes:
		sm.material_overlay = _rim_material_instance

	var anim_player := _find_animation_player_recursive(self)
	if anim_player:
		var anim_list := anim_player.get_animation_list()
		if anim_list.size() > 0:
			var clip_name: String = "Animation" if "Animation" in anim_list else anim_list[0]
			var anim := anim_player.get_animation(clip_name)
			if anim:
				anim.loop_mode = Animation.LOOP_LINEAR
			if owner == null or not owner.has_node("PlayerAnimationController"):
				# Auto-play the model's own clip only when no controller drives it.
				anim_player.play(clip_name)

func _find_mesh_instances_recursive(node: Node) -> void:
	for child in node.get_children():
		if child is MeshInstance3D:
			skinned_meshes.append(child)
		_find_mesh_instances_recursive(child)

func _find_animation_player_recursive(node: Node) -> AnimationPlayer:
	for child in node.get_children():
		if child is AnimationPlayer:
			return child
		var res := _find_animation_player_recursive(child)
		if res:
			return res
	return null

## Sets the rim the character rests at (e.g. vulnerable blue, Headliner phase-2 magenta).
## Cancels any running flash.
func update_rim_color(color: Color) -> void:
	_kill_rim_tween()
	_base_rim_color = color
	_set_rim(color, _base_rim_strength)

## Sets the rim strength the character rests at (e.g. Headliner enraged).
func update_rim_strength(strength: float) -> void:
	_kill_rim_tween()
	_base_rim_strength = strength
	_set_rim(_base_rim_color, strength)

## Flash the rim to `color`/`strength`, hold it for the first half of `seconds`, then tween
## back to the resting rim over the second half.
func flash_rim(color: Color, strength: float, seconds: float) -> void:
	if _rim_material_instance == null:
		return
	_kill_rim_tween()
	_set_rim(color, strength)
	if not is_inside_tree():
		return
	_rim_tween = create_tween().set_parallel(true)
	_rim_tween.tween_property(_rim_material_instance, "shader_parameter/rim_color", _base_rim_color, seconds * 0.5).set_delay(seconds * 0.5)
	_rim_tween.tween_property(_rim_material_instance, "shader_parameter/rim_strength", _base_rim_strength, seconds * 0.5).set_delay(seconds * 0.5)

## The shared enemy telegraph: white-hot rim for one beat of the world's current tempo.
func flash_telegraph() -> void:
	flash_rim(TELEGRAPH_RIM_COLOR, TELEGRAPH_RIM_STRENGTH, 60.0 / maxf(Conductor.bpm, 1.0))

## The authored resting rim: the rim_color export, or the faction colour when unset.
func get_default_rim_color() -> Color:
	return rim_color if rim_color.a > 0.0 else get_faction_rim_color()

## Returns the default rim colour for this character's faction.
func get_faction_rim_color() -> Color:
	return PLAYER_RIM_COLOR if faction == Faction.PLAYER else ENEMY_RIM_COLOR

## The colour the rim shows right now (mid-flash included).
func get_current_rim_color() -> Color:
	if _rim_material_instance == null:
		return Color(0, 0, 0, 0)
	return _rim_material_instance.get_shader_parameter("rim_color")

func get_current_rim_strength() -> float:
	if _rim_material_instance == null:
		return 0.0
	return _rim_material_instance.get_shader_parameter("rim_strength")

func get_base_rim_color() -> Color:
	return _base_rim_color

func get_base_rim_strength() -> float:
	return _base_rim_strength

func _set_rim(color: Color, strength: float) -> void:
	if _rim_material_instance == null:
		return
	_rim_material_instance.set_shader_parameter("rim_color", color)
	_rim_material_instance.set_shader_parameter("rim_strength", strength)

func _kill_rim_tween() -> void:
	if _rim_tween and _rim_tween.is_valid():
		_rim_tween.kill()
	_rim_tween = null
