## Headless mesh probe (see memory: godot-render-probe). Prints one JSON line per asset:
## skeleton/bones, animation clips, vertex & triangle counts, AABB, and vertex-distance
## percentiles from origin (p50/p90/max). Degenerate AI meshes show as giant p50/max.
##   Godot_console.exe --headless --path "<proj>" --script res://tools/capture/probe_meshes.gd
extends SceneTree

const ASSETS := [
	"res://3D_Assets/Characters/Nick/NickProto.fbx",
	"res://Animations/Pro Sword and Shield Pack/nick_body_v2.fbx",
	"res://3D_Assets/Characters/Nick/nick_body_v2.glb",
	"res://3D_Assets/Characters/Headliner/boss_brutalizer_base.glb",
	"res://3D_Assets/generated/boss_brutalizer_base.glb",
	"res://3D_Assets/generated/headliner_brutalizer.glb",
	"res://3D_Assets/generated/headliner_brutalizer_raw.glb",
	"res://3D_Assets/generated/headliner_brutalizer_rigged.glb",
	"res://3D_Assets/enforcers_ai/clean/Enforcer_Fists.glb",
	"res://3D_Assets/enforcers_ai/clean/Enforcer_Hammer.glb",
	"res://3D_Assets/enforcers_ai/clean/Enforcer_Sword.glb",
	"res://3D_Assets/generated/enforcer_fists_rigged.glb",
	"res://3D_Assets/generated/enforcer.glb",
	"res://3D_Assets/generated/enforcer_v2.glb",
	"res://3D_Assets/generated/enforcer_trellis_textured.glb",
	"res://3D_Assets/generated/enforcer_eval.glb",
	"res://3D_Assets/Props_and_Misc/dron 3 fbx.fbx",
	"res://3D_Assets/Props_and_Misc/dron fbx 2.fbx",
	"res://3D_Assets/Props_and_Misc/dron fbx.fbx",
	"res://3D_Assets/Environments/City/city.FBX",
]

func _initialize() -> void:
	for path in ASSETS:
		_probe(path)
	quit(0)

func _probe(path: String) -> void:
	var r := {"asset": path}
	if not ResourceLoader.exists(path):
		r["error"] = "not imported / missing"
		print("PROBE ", JSON.stringify(r))
		return
	var ps: Resource = load(path)
	if not (ps is PackedScene):
		r["error"] = "not a PackedScene (%s)" % (ps.get_class() if ps else "null")
		print("PROBE ", JSON.stringify(r))
		return
	var inst: Node = ps.instantiate()
	root.add_child(inst)
	var skels := inst.find_children("*", "Skeleton3D", true, false)
	r["skeletons"] = skels.size()
	r["bones"] = skels[0].get_bone_count() if skels.size() > 0 else 0
	if skels.size() > 0:
		var names := []
		for i in min(5, skels[0].get_bone_count()):
			names.append(skels[0].get_bone_name(i))
		r["bone_sample"] = names
	var aps := inst.find_children("*", "AnimationPlayer", true, false)
	r["anim_players"] = aps.size()
	r["clips"] = Array(aps[0].get_animation_list()) if aps.size() > 0 else []
	var meshes := inst.find_children("*", "MeshInstance3D", true, false)
	r["mesh_instances"] = meshes.size()
	var dists := PackedFloat32Array()
	var tris := 0
	var verts_total := 0
	var mats := []
	var aabb := AABB()
	var first := true
	for mi in meshes:
		if not mi.mesh:
			continue
		var xf: Transform3D = mi.global_transform
		for s in mi.mesh.get_surface_count():
			var arrays: Array = mi.mesh.surface_get_arrays(s)
			var verts = arrays[Mesh.ARRAY_VERTEX]
			var idx = arrays[Mesh.ARRAY_INDEX]
			if verts:
				verts_total += verts.size()
				tris += (idx.size() / 3) if idx else (verts.size() / 3)
				for v in verts:
					var wv: Vector3 = xf * v
					dists.append(wv.length())
					if first:
						aabb = AABB(wv, Vector3.ZERO)
						first = false
					else:
						aabb = aabb.expand(wv)
			var m: Material = mi.mesh.surface_get_material(s)
			var om: Material = mi.get_surface_override_material(s)
			var use: Material = om if om else m
			if use:
				var d := {"class": use.get_class()}
				if use is BaseMaterial3D:
					d["albedo_tex"] = use.albedo_texture != null
					d["albedo"] = str(use.albedo_color)
					d["emission"] = use.emission_enabled
				mats.append(d)
	r["vertices"] = verts_total
	r["triangles"] = tris
	r["aabb_pos"] = str(aabb.position)
	r["aabb_size"] = str(aabb.size)
	r["height_y"] = aabb.size.y
	if dists.size() > 0:
		var arr := Array(dists)
		arr.sort()
		r["dist_p50"] = arr[int(arr.size() * 0.5)]
		r["dist_p90"] = arr[int(arr.size() * 0.9)]
		r["dist_max"] = arr[arr.size() - 1]
	r["materials"] = mats.slice(0, 4)
	r["material_count"] = mats.size()
	print("PROBE ", JSON.stringify(r))
	inst.queue_free()
