## Mesh gallery (windowed): renders each candidate 3D asset auto-framed by its bounds, with a
## 2 m reference capsule beside it, so unwired assets can be judged before wiring.
##   Godot_console.exe --path "<proj>" --script res://tools/capture/mesh_gallery.gd -- --out=res://Captures/<name>/
extends SceneTree

const ASSETS := {
	"enforcer_fists": "res://3D_Assets/enforcers_ai/clean/Enforcer_Fists.glb",
	"enforcer_hammer": "res://3D_Assets/enforcers_ai/clean/Enforcer_Hammer.glb",
	"enforcer_sword": "res://3D_Assets/enforcers_ai/clean/Enforcer_Sword.glb",
	"enforcer_fists_rigged": "res://3D_Assets/generated/enforcer_fists_rigged.glb",
	"headliner_raw": "res://3D_Assets/generated/headliner_brutalizer_raw.glb",
	"headliner_base_wired": "res://3D_Assets/Characters/Headliner/boss_brutalizer_base.glb",
	"nick_body_v2_glb": "res://3D_Assets/Characters/Nick/nick_body_v2.glb",
	"nick_proto": "res://3D_Assets/Characters/Nick/NickProto.fbx",
	"drone_fbx": "res://3D_Assets/Props_and_Misc/dron fbx.fbx",
	"drone3_fbx": "res://3D_Assets/Props_and_Misc/dron 3 fbx.fbx",
	"enforcer_trellis_textured": "res://3D_Assets/generated/enforcer_trellis_textured.glb",
	"city": "res://3D_Assets/Environments/City/city.FBX",
}

var out_dir := "res://Captures/mesh_gallery/"
var cam: Camera3D
var rig: Node3D
var frame := 0
var keys: Array = []
var idx := 0
var current: Node3D = null
var settle := 0

func _initialize() -> void:
	for arg in OS.get_cmdline_user_args():
		if arg.begins_with("--out="):
			out_dir = arg.trim_prefix("--out=")
	if not out_dir.ends_with("/"):
		out_dir += "/"
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(out_dir))
	root.size = Vector2i(1280, 720)
	rig = Node3D.new()
	root.add_child(rig)
	var env := WorldEnvironment.new()
	var e := Environment.new()
	e.background_mode = Environment.BG_COLOR
	e.background_color = Color(0.05, 0.05, 0.09)
	e.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	e.ambient_light_color = Color(0.35, 0.35, 0.45)
	e.ambient_light_energy = 1.0
	env.environment = e
	rig.add_child(env)
	var sun := DirectionalLight3D.new()
	sun.rotation_degrees = Vector3(-45, 35, 0)
	sun.light_energy = 1.5
	sun.shadow_enabled = true
	rig.add_child(sun)
	var fill := OmniLight3D.new()
	fill.position = Vector3(-4, 3, 4)
	fill.light_color = Color(0.0, 0.95, 1.0)
	fill.light_energy = 1.0
	fill.omni_range = 20
	rig.add_child(fill)
	cam = Camera3D.new()
	rig.add_child(cam)
	cam.current = true
	keys = ASSETS.keys()

func _process(_delta: float) -> bool:
	frame += 1
	if frame < 3:
		return false
	if current == null:
		if idx >= keys.size():
			print("GALLERY_DONE")
			quit(0)
			return true
		_load(str(keys[idx]))
		settle = 0
		return false
	settle += 1
	if settle == 4:
		var img := root.get_texture().get_image()
		var path: String = out_dir + "mesh_" + str(keys[idx]) + ".png"
		img.save_png(path)
		print("GALLERY ", keys[idx], " ", path)
		current.queue_free()
		current = null
		idx += 1
	return false

func _load(key: String) -> void:
	var path: String = str(ASSETS[key])
	var ps: Resource = load(path)
	if not (ps is PackedScene):
		print("GALLERY_SKIP ", key, " not a scene")
		current = Node3D.new()
		rig.add_child(current)
		return
	current = (ps as PackedScene).instantiate()
	rig.add_child(current)
	# Bounds from mesh instances (world space).
	var aabb := AABB()
	var first := true
	for mi in current.find_children("*", "MeshInstance3D", true, false):
		if not mi.mesh:
			continue
		var b: AABB = mi.global_transform * mi.get_aabb()
		if first:
			aabb = b
			first = false
		else:
			aabb = aabb.merge(b)
	if first:
		aabb = AABB(Vector3.ZERO, Vector3.ONE)
	var center := aabb.get_center()
	var radius: float = max(aabb.size.length() * 0.5, 0.01)
	# Reference capsule (2 m tall) next to the asset, scaled to the asset's own size class.
	var ref := MeshInstance3D.new()
	var cap := CapsuleMesh.new()
	cap.radius = 0.5
	cap.height = 2.0
	ref.mesh = cap
	var mat := StandardMaterial3D.new()
	mat.albedo_color = Color(0.2, 0.2, 0.25)
	mat.emission_enabled = true
	mat.emission = Color(0.0, 0.95, 1.0)
	mat.emission_energy_multiplier = 0.3
	ref.material_override = mat
	# Place the capsule at the asset's left edge, feet on the asset's floor; scale the capsule
	# only if the asset is enormous (city) so it remains visible.
	var cap_scale: float = clamp(radius / 6.0, 1.0, 100.0)
	ref.scale = Vector3.ONE * cap_scale
	ref.position = Vector3(aabb.position.x - 0.8 * cap_scale, aabb.position.y + 1.0 * cap_scale, center.z)
	current.add_child(ref)
	var dist: float = radius * 2.2 + 0.5
	cam.position = center + Vector3(dist * 0.55, dist * 0.35, dist * 0.8)
	cam.look_at(center, Vector3.UP)
	cam.far = max(4000.0, dist * 4.0)
	print("GALLERY_BOUNDS %s pos=%s size=%s" % [key, str(aabb.position), str(aabb.size)])
