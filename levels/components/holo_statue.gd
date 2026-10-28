extends Node3D

## S1 (Zone 6 plaza): a read-only hologram of an instanced character visual -- the Headliner
## foreshadowed as a monument before the player ever meets him. Every mesh under this node
## gets `holo_material` as its override (the model's own materials and rim overlay are
## dropped), and the first child is scaled so the whole figure stands `target_height` metres
## tall with its feet on this node's origin. No script logic beyond that: no hurtbox, no AI.

@export var holo_material: ShaderMaterial
@export var target_height: float = 6.0
## Scan lines per world metre (the shader counts them in mesh-local units).
@export var scan_lines_per_metre: float = 1.5

func _ready() -> void:
	var figure := _figure()
	if figure == null:
		return
	var meshes: Array[MeshInstance3D] = []
	for node in figure.find_children("*", "MeshInstance3D", true, false):
		var mesh_instance := node as MeshInstance3D
		if mesh_instance.mesh:
			meshes.append(mesh_instance)
	if figure is MeshInstance3D and (figure as MeshInstance3D).mesh:
		meshes.append(figure as MeshInstance3D)
	var bounds := _bounds(meshes)
	if bounds.size.y > 0.001:
		var factor := target_height / bounds.size.y
		figure.scale *= factor
		figure.position.y -= bounds.position.y * factor
	if holo_material == null:
		return
	for mesh_instance in meshes:
		var mat := holo_material.duplicate() as ShaderMaterial
		# Mesh-local units -> metres: keep the scan lines ~scan_lines_per_metre in the world.
		var world_per_local := mesh_instance.global_transform.basis.get_scale().y
		mat.set_shader_parameter("scan_lines_per_metre", scan_lines_per_metre * maxf(world_per_local, 0.001))
		mesh_instance.material_override = mat
		mesh_instance.material_overlay = null
		# The gate shader's top/bottom edge bands sit at +-half_height (instance uniform, default
		# 6) in MESH-LOCAL units; a ~1-unit generated mesh never reaches them, so none show.
		mesh_instance.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF

func _figure() -> Node3D:
	for child in get_children():
		if child is Node3D:
			return child
	return null

## Merged AABB of the meshes in this node's space.
func _bounds(meshes: Array[MeshInstance3D]) -> AABB:
	var inverse := global_transform.affine_inverse()
	var merged := AABB()
	var first := true
	for mesh_instance in meshes:
		var box: AABB = (inverse * mesh_instance.global_transform) * mesh_instance.get_aabb()
		if first:
			merged = box
			first = false
		else:
			merged = merged.merge(box)
	return merged
