## Audit capture driver (game-audit skill, Phase 1). Run with a REAL window (not --headless):
##   Godot_console.exe --path "<proj>" res://tools/capture/capture_scene.tscn -- --out=res://Captures/<name>/
## Loads the vertical slice with every autoload live, pauses the tree, then walks the REAL drone
## camera through every zone (side-scroll and top-down framings), a character lineup, the HUD, and
## every menu scene. Writes PNGs + inventory_desktop.json into --out. Always quits at the end.
extends Node

const SLICE_PATH := "res://levels/slice/vertical_slice.tscn"
const SIDE_OFFSET := Vector3(0, 3, 10)
const TOP_OFFSET := Vector3(0, 15, 5)
const TOP_ROT := Vector3(-PI / 3.0, 0, 0)

var out_dir := "res://Captures/audit_latest/"
var slice: Node3D
var player: Node3D
var camera: Camera3D
var _done := false

## Gameplay-camera shot list: real follow-camera framings at each zone's playable spot.
var zone_shots := [
	{"name": "mc_z01_street",        "pos": Vector3(12, 1.0, 0),    "mode": "side"},
	{"name": "mc_z02_pistons",       "pos": Vector3(52, 1.0, 0),    "mode": "side"},
	{"name": "mc_z03_security",      "pos": Vector3(110, 1.0, 0),   "mode": "top"},
	{"name": "mc_z03_security_side", "pos": Vector3(100, 1.0, 0),   "mode": "side"},
	{"name": "mc_z04_scaffold",      "pos": Vector3(147, 1.0, 0),   "mode": "side"},
	{"name": "mc_z05_market",        "pos": Vector3(180, 1.0, 0),   "mode": "side"},
	{"name": "mc_z06_plaza",         "pos": Vector3(225, -3.0, 0),  "mode": "top"},
	{"name": "mc_z07_enforcer",      "pos": Vector3(254, -3.0, 0),  "mode": "side"},
	{"name": "mc_z08_escape",        "pos": Vector3(300, -3.5, 0),  "mode": "side"},
	{"name": "mc_z09_elevator",      "pos": Vector3(349, -3.5, 0),  "mode": "side"},
	{"name": "mc_z10_headliner",     "pos": Vector3(360, 15.5, 0),  "mode": "side"},
	{"name": "mc_z10_headliner_top", "pos": Vector3(360, 15.5, 0),  "mode": "top"},
	{"name": "mc_z10_headliner_inside", "pos": Vector3(360, 15.5, 0), "mode": "inside"},
	{"name": "mc_z10_headliner_high", "pos": Vector3(362, 15.5, 0), "mode": "high"},
]

## Context-only overviews (free camera).
var overview_shots := [
	{"name": "ov_z01_z03", "from": Vector3(60, 30, 60),  "at": Vector3(60, 0, 0)},
	{"name": "ov_z04_z07", "from": Vector3(190, 35, 70), "at": Vector3(190, 0, 0)},
	{"name": "ov_z08_z10", "from": Vector3(330, 40, 70), "at": Vector3(330, 5, 0)},
	{"name": "ov_topdown_all", "from": Vector3(185, 160, 1), "at": Vector3(185, 0, 0)},
]

func _ready() -> void:
	for arg in OS.get_cmdline_user_args():
		if arg.begins_with("--out="):
			out_dir = arg.trim_prefix("--out=")
	if not out_dir.ends_with("/"):
		out_dir += "/"
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(out_dir))
	# Safety net: never leave the window open.
	get_tree().create_timer(240.0).timeout.connect(func(): _finish("TIMEOUT"))
	_run()

func _run() -> void:
	var win := get_window()
	win.mode = Window.MODE_WINDOWED
	win.size = Vector2i(1920, 1080)
	win.position = Vector2i(0, 0)
	await _frames(2)

	slice = (load(SLICE_PATH) as PackedScene).instantiate()
	add_child(slice)
	await _frames(12)   # let autoloads, HUD, VCR, materials and the camera FSM settle

	player = slice.get_node("Player")
	camera = slice.get_node("DroneCamera")
	var hud: CanvasLayer = slice.get_node("HUD")
	var vcr: CanvasLayer = slice.get_node("VcrOverlay")

	_freeze_gameplay()
	var input_overlay: CanvasLayer = hud.get_node_or_null("InputOverlay")

	# HUD as shipped (debug controls overlay included), then with the overlay hidden and a
	# populated state (damage taken, shield partial, meter half, combo, boss bar) so every
	# HUD element is visible for the UI lens.
	_place(zone_shots[0]["pos"], "side")
	await _frames(3)
	_save("hud_z01_street")
	if input_overlay:
		input_overlay.visible = false
	SignalBus.player_health_changed.emit(70.0, 120.0)
	SignalBus.player_shield_changed.emit(18.0, 40.0)
	SignalBus.ability_meter_changed.emit(55.0, 100.0)
	SignalBus.combo_increased.emit(12)
	SignalBus.boss_spawned.emit("Headliner")
	SignalBus.boss_health_changed.emit(900, 1500)
	await _frames(3)
	_save("hud_full_state")
	SignalBus.boss_reset.emit()

	# Gameplay camera, UI hidden.
	hud.visible = false
	vcr.visible = false
	if input_overlay:
		input_overlay.visible = false
	for shot in zone_shots:
		_place(shot["pos"], shot["mode"])
		await _frames(3)
		_save(shot["name"])

	# VCR-only variant of one zone so the overlay can be judged in isolation.
	vcr.visible = true
	_place(zone_shots[4]["pos"], "side")
	await _frames(3)
	_save("mc_z04_scaffold_vcr")
	vcr.visible = false

	# Overviews.
	for shot in overview_shots:
		camera.global_position = shot["from"]
		camera.look_at(shot["at"], Vector3.UP)
		await _frames(3)
		_save(shot["name"])

	# Character lineup: every archetype at real scale side by side, gameplay-camera distance.
	await _lineup()

	# Menus.
	slice.visible = false
	await _menu_shot("res://ui/menus/title_screen.tscn", "menu_title")
	await _menu_shot("res://ui/shop/karens_shop.tscn", "menu_shop")
	await _menu_shot("res://ui/menus/game_over_screen.tscn", "menu_game_over")
	await _menu_shot("res://ui/menus/run_results_screen.tscn", "menu_run_results")
	slice.visible = true
	hud.visible = true
	vcr.visible = true
	var pause: CanvasLayer = slice.get_node("PauseMenu")
	_place(zone_shots[4]["pos"], "side")
	pause.show()
	await _frames(3)
	_save("menu_pause")
	pause.hide()

	_write_inventory()
	_finish("OK")

func _place(pos: Vector3, mode: String) -> void:
	player.global_position = pos
	player.velocity = Vector3.ZERO
	var offset := SIDE_OFFSET
	var rot := Vector3.ZERO
	match mode:
		"top":
			offset = TOP_OFFSET
			rot = TOP_ROT
		"inside":
			offset = Vector3(0, 3, 5.5)
		"high":
			offset = Vector3(0, 9, 11)
			rot = Vector3(-PI / 5.0, 0, 0)
	camera.base_position = pos + offset
	camera.global_position = pos + offset
	camera.rotation = rot
	# Keep Nick facing right so the lineup/zones are comparable.
	var mesh: Node3D = player.get_node("MeshInstance3D")
	mesh.rotation.y = PI / 2.0

func _lineup() -> void:
	var rig := Node3D.new()
	rig.name = "Lineup"
	rig.position = Vector3(0, 400, 0)
	slice.add_child(rig)
	var floor := MeshInstance3D.new()
	var box := BoxMesh.new()
	box.size = Vector3(40, 1, 10)
	floor.mesh = box
	floor.position = Vector3(10, -0.5, 0)
	rig.add_child(floor)
	var light := OmniLight3D.new()
	light.light_energy = 2.0
	light.omni_range = 40.0
	light.position = Vector3(10, 6, 4)
	rig.add_child(light)
	var scenes := [
		["res://characters/enemies/runner/runner.tscn", 0.0, 0.9],
		["res://characters/enemies/bruiser/bruiser.tscn", 4.0, 1.1],
		["res://characters/enemies/sniper/sniper.tscn", 8.0, 0.9],
		["res://characters/enemies/enforcer/enforcer.tscn", 13.0, 1.5],
		["res://characters/enemies/headliner/headliner.tscn", 21.0, 3.0],
	]
	for s in scenes:
		var inst: Node3D = (load(s[0]) as PackedScene).instantiate()
		rig.add_child(inst)
		inst.global_position = rig.global_position + Vector3(s[1], s[2], 0)
		inst.process_mode = Node.PROCESS_MODE_DISABLED
	# Nick stands at the left of the lineup.
	player.global_position = rig.global_position + Vector3(-4, 1.0, 0)
	player.get_node("MeshInstance3D").rotation.y = PI / 2.0
	await _frames(6)
	camera.global_position = rig.global_position + Vector3(8, 4, 18)
	camera.look_at(rig.global_position + Vector3(8, 2, 0), Vector3.UP)
	await _frames(3)
	_save("lineup_all")
	# Close-ups: 4 angles of Nick, one of each enemy.
	var nick_pos: Vector3 = player.global_position
	var angles := {"front": Vector3(0, 1, 5), "back": Vector3(0, 1, -5), "left": Vector3(-5, 1, 0), "right": Vector3(5, 1, 0)}
	for key in angles.keys():
		camera.global_position = nick_pos + angles[key]
		camera.look_at(nick_pos + Vector3(0, 0.2, 0), Vector3.UP)
		await _frames(2)
		_save("closeup_nick_%s" % key)
	var names := ["runner", "bruiser", "sniper", "enforcer", "headliner"]
	for i in scenes.size():
		var p: Vector3 = rig.global_position + Vector3(scenes[i][1], scenes[i][2], 0)
		var dist: float = 5.0 + scenes[i][2] * 1.5
		camera.global_position = p + Vector3(dist * 0.6, dist * 0.35, dist)
		camera.look_at(p, Vector3.UP)
		await _frames(2)
		_save("closeup_%s" % names[i])

func _menu_shot(path: String, shot_name: String) -> void:
	var inst: Node = (load(path) as PackedScene).instantiate()
	add_child(inst)
	await _frames(4)
	_save(shot_name)
	inst.queue_free()
	await _frames(1)

func _save(shot_name: String) -> void:
	var img := get_viewport().get_texture().get_image()
	var path := out_dir + shot_name + ".png"
	var err := img.save_png(path)
	print("CAPTURE %s %s %dx%d" % [("OK" if err == OK else "FAIL"), path, img.get_width(), img.get_height()])

func _frames(n: int) -> void:
	for i in n:
		await RenderingServer.frame_post_draw

func _write_inventory() -> void:
	var inv := {
		"godot": Engine.get_version_info()["string"],
		"renderer": RenderingServer.get_current_rendering_method(),
		"viewport": [get_viewport().size.x, get_viewport().size.y],
		"msaa_3d": get_viewport().msaa_3d,
		"screen_space_aa": get_viewport().screen_space_aa,
		"scaling_3d_scale": get_viewport().scaling_3d_scale,
		"camera": {"fov": camera.fov, "near": camera.near, "far": camera.far, "projection": camera.projection},
		"environment": {}, "lights": [], "meshes": [], "csg": [],
	}
	var we: WorldEnvironment = slice.get_node("WorldEnvironment")
	var env: Environment = we.environment
	inv["environment"] = {
		"background_mode": env.background_mode, "background_color": str(env.background_color),
		"ambient_source": env.ambient_light_source, "ambient_color": str(env.ambient_light_color),
		"ambient_energy": env.ambient_light_energy, "tonemap_mode": env.tonemap_mode,
		"tonemap_exposure": env.tonemap_exposure, "glow": env.glow_enabled,
		"glow_intensity": env.glow_intensity, "glow_bloom": env.glow_bloom,
		"glow_hdr_threshold": env.glow_hdr_threshold, "ssao": env.ssao_enabled, "ssil": env.ssil_enabled,
		"sdfgi": env.sdfgi_enabled, "fog": env.fog_enabled, "volumetric_fog": env.volumetric_fog_enabled,
	}
	_walk(slice, inv)
	var f := FileAccess.open(out_dir + "inventory_desktop.json", FileAccess.WRITE)
	f.store_string(JSON.stringify(inv, "  "))
	f.close()
	print("INVENTORY written: %d meshes, %d csg, %d lights" % [inv["meshes"].size(), inv["csg"].size(), inv["lights"].size()])

func _walk(node: Node, inv: Dictionary) -> void:
	if node.name == "Lineup":
		return
	if node is Light3D:
		inv["lights"].append({"path": str(slice.get_path_to(node)), "type": node.get_class(),
			"color": str(node.light_color), "energy": node.light_energy, "shadow": node.shadow_enabled,
			"range": node.omni_range if node is OmniLight3D else 0.0})
	elif node is CSGBox3D:
		var mat: Material = node.material
		inv["csg"].append({"path": str(slice.get_path_to(node)), "size": str(node.size),
			"collision": node.use_collision, "material": (mat.get_class() if mat else "none"),
			"albedo": (str(mat.albedo_color) if mat is StandardMaterial3D else ""),
			"emission": (str(mat.emission) if (mat is StandardMaterial3D and mat.emission_enabled) else "")})
	elif node is MeshInstance3D and node.mesh:
		var tris := 0
		for s in node.mesh.get_surface_count():
			var arrays: Array = node.mesh.surface_get_arrays(s)
			var idx = arrays[Mesh.ARRAY_INDEX]
			var verts = arrays[Mesh.ARRAY_VERTEX]
			tris += (idx.size() / 3) if idx else ((verts.size() / 3) if verts else 0)
		inv["meshes"].append({"path": str(slice.get_path_to(node)), "mesh": node.mesh.get_class(),
			"surfaces": node.mesh.get_surface_count(), "tris": tris, "aabb_size": str(node.get_aabb().size),
			"override": (node.material_override.get_class() if node.material_override else ""),
			"overlay": (node.material_overlay.get_class() if node.material_overlay else ""),
			"visible": node.is_visible_in_tree(), "cast_shadow": node.cast_shadow})
	for c in node.get_children():
		_walk(c, inv)

## Freeze the player, the camera FSM and every scene-placed enemy so teleports stick and
## nothing chases; everything still renders. (Pausing the whole tree left CSG and the
## camera unbuilt → black frames.)
func _freeze_gameplay() -> void:
	player.process_mode = Node.PROCESS_MODE_DISABLED
	camera.process_mode = Node.PROCESS_MODE_DISABLED
	for body in slice.find_children("*", "CharacterBody3D", true, false):
		body.process_mode = Node.PROCESS_MODE_DISABLED

func _finish(status: String) -> void:
	if _done:
		return
	_done = true
	print("CAPTURE_RUN_DONE ", status)
	get_tree().quit()
