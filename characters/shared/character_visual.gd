extends MeshInstance3D
class_name CharacterVisual

@export var tint: Color = Color.WHITE

## Determines which neon rim colour is applied as a material_overlay on all child meshes.
## PLAYER → cyan #00F5FF  |  ENEMY → magenta #FF00AA
enum Faction { PLAYER, ENEMY }
@export var faction: Faction = Faction.ENEMY

const RIM_MATERIAL_CYAN    := preload("res://assets/shaders/neon_rim_material.tres")
const RIM_MATERIAL_MAGENTA := preload("res://assets/shaders/neon_rim_material_magenta.tres")

var base_tint_material: StandardMaterial3D
var last_material: Material = null
var skinned_meshes: Array[MeshInstance3D] = []
## Per-instance overlay material — duplicated on first update_rim_color() call so
## changing one character's rim does not affect all characters sharing the same resource.
var _rim_material_instance: ShaderMaterial = null

func _ready() -> void:
	# Create a dummy mesh with 1 surface so native get/set surface override material works
	var dummy_mesh = BoxMesh.new()
	dummy_mesh.size = Vector3.ZERO
	self.mesh = dummy_mesh
	
	# Recursively find all child MeshInstance3D nodes (excluding self)
	skinned_meshes.clear()
	_find_mesh_instances_recursive(self)
	
	# Create base albedo/emission material from tint
	base_tint_material = StandardMaterial3D.new()
	base_tint_material.albedo_color = tint
	base_tint_material.emission_enabled = true
	base_tint_material.emission = tint * 0.2
	
	# Assign to dummy mesh so it's returned by mesh.material
	dummy_mesh.material = base_tint_material

	# Set initial material to child meshes — but only when a tint is actually
	# requested. A WHITE tint (Nick) means "keep the model's own imported
	# textures"; overriding would flatten the GLB to an untextured white.
	if tint != Color.WHITE:
		_apply_material_to_skinned_meshes(base_tint_material)

	# Apply neon rim overlay on top of the base material — does not replace it.
	var rim_base: ShaderMaterial = RIM_MATERIAL_CYAN if faction == Faction.PLAYER else RIM_MATERIAL_MAGENTA
	# Duplicate so each CharacterVisual instance owns its overlay; update_rim_color() can
	# then safely mutate parameters without affecting other characters.
	_rim_material_instance = rim_base.duplicate() as ShaderMaterial
	_apply_rim_overlay(_rim_material_instance)

	var anim_player = _find_animation_player_recursive(self)
	if anim_player:
		var anim_list = anim_player.get_animation_list()
		if anim_list.size() > 0:
			var clip_name: String = "Animation" if "Animation" in anim_list else anim_list[0]
			var anim = anim_player.get_animation(clip_name)
			if anim:
				anim.loop_mode = Animation.LOOP_LINEAR
			if not owner.has_node("PlayerAnimationController"):
				# auto-play bind pose only if no controller is present
				anim_player.play(clip_name)
		# If no clips exist (bind-pose only), leave the AnimationPlayer idle — expected
		# until Mixamo clips are added.

func _process(_delta: float) -> void:
	# Poll for material changes from the enemy scripts
	var current_mat = get_surface_override_material(0)
	if current_mat != last_material:
		last_material = current_mat
		_apply_material_to_skinned_meshes(current_mat if current_mat else base_tint_material)

func _find_mesh_instances_recursive(node: Node) -> void:
	for child in node.get_children():
		if child is MeshInstance3D:
			skinned_meshes.append(child)
		_find_mesh_instances_recursive(child)

func _find_animation_player_recursive(node: Node) -> AnimationPlayer:
	for child in node.get_children():
		if child is AnimationPlayer:
			return child
		var res = _find_animation_player_recursive(child)
		if res:
			return res
	return null

func _apply_material_to_skinned_meshes(mat: Material) -> void:
	for sm in skinned_meshes:
		sm.material_override = mat

func _apply_rim_overlay(mat: ShaderMaterial) -> void:
	for sm in skinned_meshes:
		sm.material_overlay = mat

## Temporarily change the rim colour — useful for telegraph flashes (enemy about to attack).
## Call with the target color, then restore with the faction default:
##   visual.update_rim_color(Color(1, 0, 0))          # flash red
##   await get_tree().create_timer(0.15).timeout
##   visual.update_rim_color(visual.get_faction_rim_color())
func update_rim_color(color: Color) -> void:
	if _rim_material_instance == null:
		return
	_rim_material_instance.set_shader_parameter("rim_color", color)

## Returns the default rim colour for this character's faction.
func get_faction_rim_color() -> Color:
	if faction == Faction.PLAYER:
		return Color(0.0, 0.960784, 1.0, 1.0)   # #00F5FF cyan
	return Color(1.0, 0.0, 0.666667, 1.0)        # #FF00AA magenta
