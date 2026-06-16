extends MeshInstance3D
class_name CharacterVisual

@export var tint: Color = Color.WHITE

var base_tint_material: StandardMaterial3D
var last_material: Material = null
var skinned_meshes: Array[MeshInstance3D] = []

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
	
	# Set initial material to child meshes
	_apply_material_to_skinned_meshes(base_tint_material)
	
	var anim_player = _find_animation_player_recursive(self)
	if anim_player:
		var anim = anim_player.get_animation("Animation")
		if anim:
			anim.loop_mode = Animation.LOOP_LINEAR
		anim_player.play("Animation")

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
