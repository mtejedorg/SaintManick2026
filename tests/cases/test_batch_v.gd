extends "res://tests/framework/test_case.gd"

# Batch V (the re-grade regressions and the last small lifts): V1 horizon seam, V2 dressing vs the
# telegraph colour language, V3 hazard blocks, V4 shield bubbles, V5 pause during the scene fade,
# V6 boss punctuation / Reduce Flashes / StageLight double connect, V9 Zone 6 markers, V10 generic
# hit values in PlayerTuning, V11 HUD SIZE, V12 neon flicker + Reduce Flashes, V13 death beat knob.
# (V7, the script ribbon, is covered in test_batch_u.gd; V8 is the Nick texture, in test_batch_t.)

const SLICE_PATH := "res://levels/slice/vertical_slice.tscn"
const PLAYER_SCENE := "res://characters/player/player.tscn"
const ENFORCER_SCENE := "res://characters/enemies/enforcer/enforcer.tscn"
const HEADLINER_SCENE := "res://characters/enemies/headliner/headliner.tscn"
const PAUSE_SCENE := "res://ui/menus/pause_menu.tscn"
const OPTIONS_SCENE := "res://ui/menus/options_menu.tscn"
const HUD_SCENE := "res://ui/hud/hud.tscn"
const SceneTransition := preload("res://ui/transition/scene_transition.gd")
const Atmo := preload("res://levels/components/zone_atmosphere.gd")
const NeonFlickerScript := preload("res://vfx/neon_flicker.gd")
const VfxManagerScript := preload("res://vfx/vfx_manager.gd")

var _nodes: Array[Node] = []
var _slice: Node3D = null
var _reduce_before: bool = false
var _hud_before: Array = []

func before_each() -> void:
	GameManager.is_test = true
	_reduce_before = SaveManager.profile.reduce_flashes
	_hud_before = [SaveManager.profile.hud_scale, SaveManager.profile.hud_scale_chosen]

func after_each() -> void:
	super.after_each()
	SaveManager.profile.reduce_flashes = _reduce_before
	SaveManager.profile.hud_scale = _hud_before[0]
	SaveManager.profile.hud_scale_chosen = _hud_before[1]
	GameManager.run_ended = false
	for n in _nodes:
		if is_instance_valid(n):
			n.free()
	_nodes.clear()
	if is_instance_valid(_slice):
		_slice.free()
	_slice = null

func _keep(n: Node) -> Node:
	_nodes.append(n)
	return n

func _spawn_slice() -> Node3D:
	_slice = (load(SLICE_PATH) as PackedScene).instantiate()
	add_child(_slice)
	return _slice

func _player(z: float) -> PlayerController:
	var p: PlayerController = _keep(load(PLAYER_SCENE).instantiate())
	p.position = Vector3(0.0, 500.0, z)
	add_child(p)
	return p

# --- V1 ------------------------------------------------------------------------------------

func test_v1_the_ground_horizon_follows_the_sky_horizon_without_a_seam() -> void:
	for zone in Atmo.TABLE:
		var atmosphere: Dictionary = Atmo.get_atmosphere(zone)
		var sky: Color = atmosphere["sky_horizon"]
		var ground: Color = atmosphere["ground_horizon"]
		assert_true(ground.r >= sky.r * 0.85 - 0.0001 and ground.g >= sky.g * 0.85 - 0.0001 and ground.b >= sky.b * 0.85 - 0.0001, "Zone %d: ground horizon %s >= 0.85 x sky horizon %s" % [zone, ground, sky])
	assert_true(Atmo.GROUND_HORIZON_RATIO >= 0.85, "The ratio itself is >= 0.85")

func test_v1_the_authored_sky_matches_ground_and_sky_curves() -> void:
	var slice := _spawn_slice()
	var env: Environment = (slice.get_node("WorldEnvironment") as WorldEnvironment).environment
	var sky_mat := env.sky.sky_material as ProceduralSkyMaterial
	assert_not_null(sky_mat, "The slice has a procedural sky")
	if sky_mat == null:
		return
	assert_almost_eq(sky_mat.ground_curve, sky_mat.sky_curve, 0.001, "ground_curve matches sky_curve (0.12)")
	assert_almost_eq(sky_mat.ground_curve, 0.12, 0.001, "...0.12")

func test_v1_a_backdrop_tower_covers_the_zone_8_gap() -> void:
	var slice := _spawn_slice()
	var tower := slice.get_node_or_null("Skyline_Z7_9/Tower5") as CSGBox3D
	assert_not_null(tower, "Skyline_Z7_9/Tower5 closes the backdrop gap")
	if tower == null:
		return
	assert_true(tower.position.x - tower.size.x * 0.5 <= 360.0 and tower.position.x + tower.size.x * 0.5 >= 380.0, "...and spans world x 360-380")

# --- V2 ------------------------------------------------------------------------------------

func _is_telegraph_colour(c: Color) -> bool:
	var magenta := c.r > 0.6 and c.b > 0.35 and c.g < 0.4
	var amber := c.r > 0.6 and c.g > 0.3 and c.g < 0.8 and c.b < 0.4
	return magenta or amber

func test_v2_no_large_dressing_ring_reuses_the_telegraph_colours() -> void:
	var slice := _spawn_slice()
	var tori := slice.find_children("*", "CSGTorus3D", true, false)
	assert_gt(tori.size(), 0, "Precondition: the slice has rings")
	for node in tori:
		var torus := node as CSGTorus3D
		if torus.outer_radius <= 2.0:
			continue
		var mat := torus.material as StandardMaterial3D
		if mat == null or not mat.emission_enabled:
			continue
		assert_false(_is_telegraph_colour(mat.emission), "%s (r %.1f) must not glow magenta/amber (%s)" % [torus.name, torus.outer_radius, mat.emission])
		assert_true(mat.emission_energy_multiplier <= 1.0, "%s emission <= 1.0" % torus.name)

func test_v2_the_stage_gets_white_ticks_and_the_signs_clear_the_boss() -> void:
	var slice := _spawn_slice()
	var ticks := slice.get_node("Z10_Dressing").find_children("StageTick*", "CSGBox3D", false, false)
	assert_eq(ticks.size(), 12, "A white tick every 30 degrees")
	var marquee := slice.get_node("Z10_Dressing/Marquee") as Label3D
	assert_gt(marquee.position.y, 21.0, "The marquee sits above the y 21 truss")
	var sign_live := slice.get_node("Z10_Dressing/SignHeadlinerLive") as Label3D
	assert_lt(sign_live.position.x, 425.0, "HEADLINER LIVE moved to the left of the stage")

# --- V3 ------------------------------------------------------------------------------------

func test_v3_hazard_blocks_are_dark_with_lit_edges_and_the_falling_ones_ghost() -> void:
	var mat := load("res://assets/materials/hazard_orange.tres") as StandardMaterial3D
	assert_true(not mat.emission_enabled or mat.emission_energy_multiplier <= 0.8, "hazard_orange emission <= 0.8")
	var slice := _spawn_slice()
	for name in ["EscapeFallingHazard", "EscapeFallingHazard2", "EscapeFallingHazard3"]:
		var body := slice.get_node(name + "/HazardBody") as CSGBox3D
		var ghost := body.material as ShaderMaterial
		assert_not_null(ghost, "%s body is a ShaderMaterial" % name)
		if ghost:
			assert_lt(float(ghost.get_shader_parameter("base_alpha")), 0.4, "%s body is transparent (alpha 0.35)" % name)
			assert_true((ghost.get_shader_parameter("rim_color") as Color).r > 0.9, "...orange")
		assert_true(body.use_collision, "%s keeps its collision" % name)
		assert_not_null(body.get_node_or_null("EdgeTop"), "%s has a lit top edge" % name)
	for name in ["EscapeDoorHazard", "EscapeDoorHazard2", "EscapeDoorHazard3"]:
		var body := slice.get_node(name + "/DoorBody") as CSGBox3D
		assert_true(body.use_collision, "%s keeps its collision" % name)
		var edge := body.get_node_or_null("EdgeTop") as MeshInstance3D
		assert_not_null(edge, "%s has a lit top edge" % name)
		if edge:
			var edge_mat := edge.get_surface_override_material(0) as StandardMaterial3D
			assert_true(edge_mat != null and edge_mat.emission_enabled and edge_mat.emission_energy_multiplier >= 2.0, "...an emissive trim")

# --- V4 ------------------------------------------------------------------------------------

func _rim_of(scene_path: String) -> ShaderMaterial:
	var boss: Node3D = _keep(load(scene_path).instantiate())
	boss.position = Vector3(0.0, 300.0, 16400.0)
	add_child(boss)
	var bubble := boss.get_node("ShieldBubble") as MeshInstance3D
	var base := bubble.get_surface_override_material(0) as StandardMaterial3D
	assert_true(base.albedo_color.a <= 0.04 + 0.0001, "%s bubble fill alpha <= 0.04" % scene_path)
	return base.next_pass as ShaderMaterial

func test_v4_shield_bubbles_carry_their_own_rim_colour_and_a_thin_fresnel() -> void:
	var enforcer := _rim_of(ENFORCER_SCENE)
	var headliner := _rim_of(HEADLINER_SCENE)
	assert_eq(enforcer.get_shader_parameter("rim_color"), Color(1.0, 0.2, 0.7, 1.0), "Enforcer: magenta")
	assert_eq(headliner.get_shader_parameter("rim_color"), Color(1.0, 0.6, 0.15, 1.0), "Headliner: amber")
	for rim in [enforcer, headliner]:
		assert_almost_eq(float(rim.get_shader_parameter("intensity")), 1.6, 0.0001, "intensity 1.6")
		assert_almost_eq(float(rim.get_shader_parameter("fresnel_power")), 4.5, 0.0001, "fresnel power 4.5")

func test_v4_the_shielded_bruiser_rim_is_magenta_white() -> void:
	assert_eq(BruiserEnemy.SHIELD_RIM_COLOR, Color(1.0, 0.55, 1.0), "(1.0, 0.55, 1.0)")

# --- V5 ------------------------------------------------------------------------------------

func _pause_menu() -> CanvasLayer:
	var pm: CanvasLayer = _keep(load(PAUSE_SCENE).instantiate())
	add_child(pm)
	return pm

func _pause_press() -> InputEventAction:
	var ev := InputEventAction.new()
	ev.action = "pause"
	ev.pressed = true
	return ev

func test_v5_pause_after_the_run_ended_leaves_the_tree_unpaused() -> void:
	var pm := _pause_menu()
	GameManager.run_ended = true
	pm._input(_pause_press())
	assert_false(get_tree().paused, "Esc after run_ended does not pause")
	assert_false(pm.visible, "...and shows no menu")
	pm.toggle()
	assert_false(get_tree().paused, "toggle() is guarded too")
	GameManager.run_ended = false
	pm._input(_pause_press())
	assert_true(get_tree().paused, "Control: a live run still pauses")
	pm.call("_resume")
	assert_false(get_tree().paused, "...and resumes")

func test_v5_pause_during_a_transition_is_refused() -> void:
	var pm := _pause_menu()
	SceneTransition._busy = true
	pm._input(_pause_press())
	assert_false(get_tree().paused, "Esc during the fade does not pause")
	SceneTransition._busy = false
	assert_false(SceneTransition.is_busy(), "is_busy() mirrors the flag")

func test_v5_the_swap_unpauses_and_input_is_blocked_while_busy() -> void:
	var tree := get_tree()
	var keep: Node = tree.current_scene
	var temp := Node3D.new()
	tree.root.add_child(temp)
	tree.current_scene = temp
	tree.paused = true
	SceneTransition._busy = true
	var cover: CanvasLayer = SceneTransition.new()
	cover.set("target_path", OPTIONS_SCENE)
	tree.root.add_child(cover)
	assert_true(SceneTransition.is_busy(), "Busy while the cover is up")
	assert_true(tree.root.gui_disable_input, "V5: GUI input is disabled while busy")
	var swapped_unpaused := false
	for i in 120: # <= ~3 s of real time
		await tree.create_timer(0.025, true, false, true).timeout
		var scene := tree.current_scene
		if scene and scene.scene_file_path == OPTIONS_SCENE:
			swapped_unpaused = not tree.paused
			break
	assert_true(swapped_unpaused, "V5: the swap lands on an unpaused tree")
	assert_false(tree.paused, "...and it stays unpaused")
	for i in 80:
		if not SceneTransition.is_busy():
			break
		await tree.create_timer(0.025, true, false, true).timeout
	assert_false(SceneTransition.is_busy(), "The transition finishes")
	assert_false(tree.root.gui_disable_input, "V5: GUI input is back after the fade")
	tree.paused = false
	var reached: Node = tree.current_scene
	if reached and reached != keep:
		reached.queue_free()
	tree.current_scene = keep
	await tree.process_frame

# --- V6 ------------------------------------------------------------------------------------

func test_v6_headliner_phase_two_and_death_flash_the_screen() -> void:
	var boss: HeadlinerBoss = _keep(load(HEADLINER_SCENE).instantiate())
	boss.position = Vector3(0.0, 300.0, 16800.0)
	add_child(boss)
	var flashes: Array = []
	SignalBus.screen_flash_requested.connect(func(a: float, d: float): flashes.append(Vector2(a, d)))
	var bpm_before: float = Conductor.target_bpm
	boss._play_phase_2_moment()
	assert_true(flashes.has(Vector2(0.3, 0.05)), "Phase 2 requests a (0.3, 0.05) flash (%s)" % str(flashes))
	flashes.clear()
	boss._play_victory_punctuation()
	assert_true(flashes.has(Vector2(0.3, 0.05)), "The kill flashes too")
	var ring := get_node_or_null("VictoryRing") as Node3D
	assert_not_null(ring, "...with an amber shock ring")
	if ring:
		_keep(ring)
		var mat := (ring as MeshInstance3D).mesh.material as StandardMaterial3D
		assert_true(mat.albedo_color.r > mat.albedo_color.b and mat.albedo_color.g > 0.8, "...amber (%s)" % mat.albedo_color)
	Conductor.target_bpm = bpm_before

func test_v6_the_enforcer_kill_flashes_the_screen() -> void:
	var boss: Node3D = _keep(load(ENFORCER_SCENE).instantiate())
	boss.position = Vector3(0.0, 300.0, 17200.0)
	add_child(boss)
	var flashes: Array = []
	SignalBus.screen_flash_requested.connect(func(a: float, d: float): flashes.append(Vector2(a, d)))
	boss._on_died()
	assert_true(flashes.has(Vector2(0.3, 0.05)), "boss_died: a (0.3, 0.05) flash (%s)" % str(flashes))

func test_v6_a_boss_kill_fires_three_pooled_death_bursts() -> void:
	var vfx: Node = _keep(VfxManagerScript.new())
	add_child(vfx)
	SignalBus.enemy_died.emit(Vector3(1.0, 2.0, 3.0))
	var after_enemy: int = vfx._death_busy.count(true)
	SignalBus.boss_died.emit()
	await get_tree().process_frame
	assert_eq(vfx._death_busy.count(true) - after_enemy, VfxManagerScript.BOSS_DEATH_BURSTS, "Three extra pooled enemy_death bursts")

func test_v6_heavy_hits_finishers_and_boss_kills_burst_the_vcr_at_0_4x() -> void:
	var vcr: CanvasLayer = _keep(load("res://ui/vcr/vcr_overlay.tscn").instantiate())
	add_child(vcr)
	var strength: float = vcr.burst_strength
	assert_gt(strength, 0.0, "Precondition: the VCR is on")
	var light := DamageInfo.new()
	light.amount = 12.0
	SignalBus.player_hit_landed.emit(light)
	assert_almost_eq(float(vcr._material.get_shader_parameter("aberration_strength")), 0.0, 0.00001, "A light hit does not burst")
	var finisher := DamageInfo.new()
	finisher.amount = 32.0
	SignalBus.player_hit_landed.emit(finisher)
	assert_almost_eq(float(vcr._material.get_shader_parameter("aberration_strength")), strength * 0.4, 0.00001, "A finisher (>= 32): 0.4x")
	assert_almost_eq(vcr._burst_total, 0.12, 0.00001, "...for 0.12 s")
	vcr.trigger_burst(0.0, 0.01)
	vcr._burst_timer = 0.0
	vcr._material.set_shader_parameter("aberration_strength", 0.0)
	SignalBus.boss_died.emit()
	assert_almost_eq(float(vcr._material.get_shader_parameter("aberration_strength")), strength * 0.4, 0.00001, "A boss kill: 0.4x")

func test_v6_reduce_flashes_halves_the_combo_flash() -> void:
	var flash: CanvasLayer = _keep(load("res://vfx/combo_flash.tscn").instantiate())
	add_child(flash)
	SaveManager.profile.reduce_flashes = false
	flash.flash(0.3, 0.05)
	assert_almost_eq(flash.rect.color.a, 0.3, 0.0001, "Normal: the requested alpha")
	flash._tween.kill()
	flash._tween = null
	SaveManager.profile.reduce_flashes = true
	flash.flash(0.3, 0.05)
	assert_almost_eq(flash.rect.color.a, 0.15, 0.0001, "Reduce Flashes: half")

func test_v6_the_stage_light_survives_a_second_ready_without_double_connecting() -> void:
	var light: Node = _keep(load("res://levels/components/stage_light.gd").new())
	add_child(light)
	light._ready()
	var connections := 0
	for c in SignalBus.beat.get_connections():
		if c.callable.get_object() == light:
			connections += 1
	assert_eq(connections, 1, "One beat connection after two _ready() calls")

# --- V9 ------------------------------------------------------------------------------------

func test_v9_zone_6_south_markers_stay_inside_the_top_down_frame() -> void:
	var slice := _spawn_slice()
	var spawner := slice.get_node("Z6_Encounter/Z6_Spawner")
	var checked := 0
	for marker in spawner.get_children():
		if marker is Marker3D:
			checked += 1
			assert_true((marker as Marker3D).position.z <= 8.0, "%s south edge z %.1f <= 8" % [marker.name, (marker as Marker3D).position.z])
	assert_eq(checked, 10, "Ten markers")
	assert_eq((spawner.get_node("SpawnPoint10") as Marker3D).position, Vector3(12.0, 2.0, 8.0), "SpawnPoint10 at (12, 2, 8)")

# --- V10 -----------------------------------------------------------------------------------

func test_v10_a_generic_hit_reads_the_tuning_resource() -> void:
	var player := _player(17600.0)
	var custom: PlayerTuning = player.tuning.duplicate()
	custom.light_damage = 17.5
	custom.light_knockback = 5.5
	custom.light_stun = 0.31
	custom.heavy_damage = 33.0
	custom.heavy_knockback = 9.5
	custom.heavy_stun = 0.52
	player.tuning = custom
	var attack: Node = player.state_machine.get_node("StateAttack")
	attack.enter()
	attack.current_sequence.clear()
	attack._start_attack(false)
	var info: DamageInfo = player.katana_hitbox.damage_info
	assert_eq([info.amount, info.knockback, info.stun], [17.5, 5.5, 0.31], "A generic light reads exactly the resource values")
	attack.current_sequence.clear()
	attack._start_attack(true)
	var heavy: DamageInfo = player.bionic_arm_hitbox.damage_info
	assert_eq([heavy.amount, heavy.knockback, heavy.stun], [33.0, 9.5, 0.52], "...and so does a generic heavy")
	assert_true(custom.validate(), "The edited resource still validates")

func test_v10_the_shipped_generic_values_keep_their_old_numbers() -> void:
	var t: PlayerTuning = load("res://characters/player/player_tuning.tres")
	assert_eq([t.light_damage, t.heavy_damage, t.light_knockback, t.heavy_knockback, t.light_stun, t.heavy_stun], [12.0, 28.0, 4.0, 8.0, 0.25, 0.4], "12/28, 4/8, 0.25/0.4")
	assert_true(t.validate(), "The shipped generic values validate")

# --- V11 -----------------------------------------------------------------------------------

func test_v11_the_hud_size_row_cycles_and_persists() -> void:
	var menu: Control = _keep(load(OPTIONS_SCENE).instantiate())
	add_child(menu)
	var p: PlayerProfile = SaveManager.profile
	p.hud_scale = 1.0
	p.hud_scale_chosen = true
	menu._refresh_labels()
	assert_eq(menu.hud_size_button.text, "HUD SIZE: 100 %", "Starts at 100 %")
	menu.cycle_hud_scale(1)
	assert_eq([p.hud_scale, menu.hud_size_button.text], [1.25, "HUD SIZE: 125 %"], "-> 125 %")
	menu.cycle_hud_scale(1)
	assert_eq([p.hud_scale, menu.hud_size_button.text], [1.5, "HUD SIZE: 150 %"], "-> 150 %")
	menu.cycle_hud_scale(1)
	assert_eq(p.hud_scale, 1.0, "...wraps to 100 %")
	menu.cycle_hud_scale(-1)
	assert_eq(p.hud_scale, 1.5, "...and steps back")
	assert_true(p.hud_scale_chosen, "A pick marks the scale as chosen")
	var saved := ResourceLoader.load(SaveManager.save_path, "", ResourceLoader.CACHE_MODE_IGNORE) as PlayerProfile
	assert_not_null(saved, "The profile was written")
	if saved:
		assert_eq(saved.hud_scale, 1.5, "The pick persists")

func test_v11_a_small_window_auto_selects_125_until_the_player_chooses() -> void:
	var p := PlayerProfile.new()
	assert_eq(p.effective_hud_scale(1080.0), 1.0, "1080 px: 100 %")
	assert_eq(p.effective_hud_scale(899.0), 1.25, "< 900 px with the default: 125 %")
	p.hud_scale_chosen = true
	assert_eq(p.effective_hud_scale(720.0), 1.0, "An explicit 100 % is respected")
	p.hud_scale = 1.5
	assert_eq(p.effective_hud_scale(720.0), 1.5, "...and so is 150 %")

func test_v11_the_safe_area_scale_follows_the_profile() -> void:
	var hud: CanvasLayer = _keep(load(HUD_SCENE).instantiate())
	add_child(hud)
	var p: PlayerProfile = SaveManager.profile
	p.hud_scale = 1.5
	p.hud_scale_chosen = true
	p.emit_changed()
	assert_eq(hud.safe_area.scale, Vector2(1.5, 1.5), "SafeArea scales 1.5x")
	assert_eq(hud.safe_area.pivot_offset, Vector2.ZERO, "About its top-left corner")
	var rect: Vector2 = hud.get_viewport().get_visible_rect().size
	assert_almost_eq(hud.safe_area.size.x * 1.5, rect.x, 0.5, "...with its size shrunk so the corners stay on screen")
	assert_almost_eq(hud.safe_area.size.y * 1.5, rect.y, 0.5, "...vertically too")
	p.hud_scale = 1.0
	p.emit_changed()
	assert_eq(hud.safe_area.scale, Vector2.ONE, "Back to 100 %")

func test_v11_chips_and_the_zone_tag_use_at_least_20_px() -> void:
	var hud: CanvasLayer = _keep(load(HUD_SCENE).instantiate())
	add_child(hud)
	assert_true(hud.zone_tag.get_theme_font_size("font_size") >= 20, "Zone tag >= 20 px")
	var chips := 0
	for chip in hud.hud_hints.get_children():
		var label := chip.get_node_or_null("Label") as Label
		if label:
			chips += 1
			assert_true(label.get_theme_font_size("font_size") >= 20, "%s >= 20 px" % chip.name)
	assert_gt(chips, 0, "Precondition: the hint strip has chips")

# --- V12 -----------------------------------------------------------------------------------

func test_v12_reduce_flashes_softens_the_neon_pulse_and_stops_dropouts() -> void:
	var fx: Node = _keep(NeonFlickerScript.new())
	add_child(fx)
	var mat: StandardMaterial3D = fx.materials[0]
	var base: float = fx.base_of(mat)
	SaveManager.profile.reduce_flashes = false
	SignalBus.beat.emit("primary", 1)
	assert_almost_eq(mat.emission_energy_multiplier, base * 1.3, 0.0001, "Normal: +30 %")
	fx.pulse() # reset to a known tween state
	SaveManager.profile.reduce_flashes = true
	SignalBus.beat.emit("primary", 2)
	assert_true(fx.reduced, "The beat re-reads the option")
	assert_almost_eq(mat.emission_energy_multiplier, base * 1.1, 0.0001, "Reduce Flashes: +10 %")
	var before: int = fx.dropouts
	fx.drop_out(mat)
	assert_eq(fx.dropouts, before, "No dropouts while reduced")
	fx.dropouts_enabled = true
	fx.rng.seed = 1
	for i in 600:
		fx._process(0.1)
	assert_eq(fx.dropouts, before, "...not even over a minute of random rolls")
	SaveManager.profile.reduce_flashes = false
	fx.apply_accessibility()
	fx.drop_out(mat)
	assert_eq(fx.dropouts, before + 1, "Control: dropouts work with the option off")

# --- V13 -----------------------------------------------------------------------------------

func test_v13_the_death_beat_follows_the_tuning_resource() -> void:
	GameManager.start_new_run()
	var player := _player(18000.0)
	assert_almost_eq(GameManager.death_beat_length(), player.tuning.death_beat_seconds, 0.0001, "The shipped resource drives the beat")
	var custom: PlayerTuning = player.tuning.duplicate()
	custom.death_beat_seconds = 0.2
	player.tuning = custom
	assert_almost_eq(GameManager.death_beat_length(), 0.2, 0.0001, "death_beat_length() reads the player's tuning")
	var holds: Array[float] = []
	SignalBus.banner_requested.connect(func(_text: String, hold: float): holds.append(hold))
	GameManager.begin_death_beat()
	assert_true(GameManager.death_beat_pending, "The beat is pending")
	assert_almost_eq(holds[0] if holds.size() > 0 else -1.0, 0.2, 0.0001, "The banner holds the tuned length")
	await get_tree().create_timer(0.45, true, false, true).timeout
	assert_false(GameManager.death_beat_pending, "The timer fired at 0.2 s, not the 0.9 s const")
	GameManager.start_new_run()
