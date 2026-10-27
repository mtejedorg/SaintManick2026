extends "res://tests/framework/test_case.gd"

# Batch P (round-4 no-decision items): holo gates / shield bubbles (P2), SSR (P3), sky and
# skylines (P4), district key light (P5), graded hit-stop (P6), Bruiser shield (P7), camera
# look-ahead (P8), shock ring + phase-2 moment (P10), Zone 5 props (P12). P1 lives in
# test_vfx_draw_passes.gd, P9 in test_batch_k.gd, P11 in test_level_fixes.gd.

const SLICE_PATH := "res://levels/slice/vertical_slice.tscn"
const Atmo = preload("res://levels/components/zone_atmosphere.gd")
const ShockRingScript = preload("res://vfx/shock_ring.gd")

var _nodes: Array[Node] = []

func after_each() -> void:
	super.after_each()
	for n in _nodes:
		if is_instance_valid(n):
			n.free()
	_nodes.clear()
	Engine.time_scale = 1.0
	var hs = get_node_or_null("/root/HitStop")
	if hs:
		hs.hit_stop_timer = 0.0

func _keep(n: Node) -> Node:
	_nodes.append(n)
	return n

func _slice() -> Node3D:
	var s: Node3D = _keep((load(SLICE_PATH) as PackedScene).instantiate())
	add_child(s)
	return s

# --- P2 ------------------------------------------------------------------------------

func test_p2_gates_are_faint_additive_holograms_3_2_m_deep() -> void:
	var slice := _slice()
	for path in ["Z1_Gates/GateEntrance", "Z4_Gates/GateExit", "Z5_Gates/GateEntrance", "Z6_Plaza/WallExit", "Zone10_Dock/NearWall"]:
		var box := slice.get_node(path) as CSGBox3D
		var mat := box.material as ShaderMaterial
		assert_true(mat != null and mat.shader.code.contains("blend_add"), "%s uses the additive holo shader" % path)
		assert_true(mat != null and mat.shader.code.contains("depth_draw_never") and mat.shader.code.contains("unshaded"), "%s: no depth write, unshaded" % path)
	assert_almost_eq((slice.get_node("Z1_Gates/GateExit") as CSGBox3D).size.z, 3.2, 0.0001, "Gate depth 8 -> 3.2")
	assert_almost_eq((slice.get_node("Z1_Gates/GateExit") as CSGBox3D).size.y, 12.0, 0.0001, "...height kept")

func test_p2_boss_shield_bubbles_are_additive_with_a_fresnel_rim() -> void:
	for scene_path in ["res://characters/enemies/enforcer/enforcer.tscn", "res://characters/enemies/headliner/headliner.tscn"]:
		var boss: Node = _keep((load(scene_path) as PackedScene).instantiate())
		var mat := (boss.get_node("ShieldBubble") as MeshInstance3D).get_surface_override_material(0) as StandardMaterial3D
		assert_eq(mat.blend_mode, BaseMaterial3D.BLEND_MODE_ADD, "%s bubble adds light" % scene_path)
		assert_true(mat.albedo_color.a <= 0.1001, "%s bubble fill alpha 0.10" % scene_path)
		assert_almost_eq(mat.emission_energy_multiplier, 0.5, 0.0001, "%s bubble emission x0.5" % scene_path)
		assert_true(mat.albedo_color.b > mat.albedo_color.r, "%s shield still reads blue" % scene_path)
		var rim := mat.next_pass as ShaderMaterial
		assert_true(rim != null and rim.shader.code.contains("fresnel"), "%s bubble has the fresnel rim pass" % scene_path)

# --- P3 / P4 / P5 (slice) ------------------------------------------------------------------

func test_p3_p5_the_runtime_environment_reflects_and_takes_ambient_from_the_sky() -> void:
	var slice := _slice()
	var env := (slice.get_node("WorldEnvironment") as WorldEnvironment).environment
	assert_true(env.ssr_enabled, "The duplicated Environment keeps SSR")
	assert_eq(env.ssr_max_steps, 64)
	assert_eq(env.ambient_light_source, Environment.AMBIENT_SOURCE_SKY, "Ambient from the sky")
	assert_almost_eq(env.ambient_light_energy, 1.0, 0.0001)
	var floor_mat := load("res://assets/materials/floor_wet.tres") as StandardMaterial3D
	assert_almost_eq(floor_mat.roughness, 0.10, 0.0001, "Wet floor roughness")
	assert_almost_eq(floor_mat.metallic, 0.3, 0.0001)
	assert_true(floor_mat.roughness_texture is NoiseTexture2D and floor_mat.uv1_triplanar, "Puddle noise, triplanar")

func test_p4_skyline_towers_are_dark_silhouettes_under_a_lit_horizon() -> void:
	var slice := _slice()
	var dark := load("res://assets/materials/skyline_dark.tres") as StandardMaterial3D
	var env := (slice.get_node("WorldEnvironment") as WorldEnvironment).environment
	var sky := env.sky.sky_material as ProceduralSkyMaterial
	assert_almost_eq(sky.sky_energy_multiplier, 1.0, 0.0001, "Sky energy 0.25 -> 1.0")
	var towers := 0
	for group in ["Skyline_Z1_2", "Skyline_Z7_9", "Skyline_Z10"]:
		for n in slice.get_node(group).get_children():
			if String(n.name).contains("Strip"):
				continue
			towers += 1
			assert_eq((n as CSGBox3D).material, dark, "%s/%s uses skyline_dark" % [group, n.name])
	assert_eq(towers, 10, "Ten tower bodies")
	for zone in range(1, 11):
		var horizon: Color = Atmo.get_atmosphere(zone)["sky_horizon"]
		assert_lt(dark.albedo_color.get_luminance(), horizon.get_luminance(), "Towers are darker than the Zone %d horizon" % zone)

# --- P12 -----------------------------------------------------------------------------------

func test_p12_zone5_stall_and_crate_moved_into_the_back_lane() -> void:
	var slice := _slice()
	var stall := slice.get_node("Z5_Market/MarketStallR") as CSGBox3D
	var crate := slice.get_node("Z5_Market/Crate2") as CSGBox3D
	assert_eq(stall.position, Vector3(171, 0.1, -2))
	assert_eq(crate.position, Vector3(186, -1, -1.45))
	for box in [stall, crate]:
		assert_true(box.use_collision, "%s keeps its collision" % box.name)
		assert_true(box.position.z + box.size.z * 0.5 < 0.0, "%s sits behind the rail (z < 0), not in front of Nick" % box.name)

# --- P4 / P5 (ZoneAtmosphere) ---------------------------------------------------------------

func _atmosphere_rig() -> Dictionary:
	var holder: WorldEnvironment = _keep(WorldEnvironment.new())
	var env := Environment.new()
	var sky_mat := ProceduralSkyMaterial.new()
	env.sky = Sky.new()
	env.sky.sky_material = sky_mat
	holder.environment = env
	var sun := DirectionalLight3D.new()
	var rim := DirectionalLight3D.new()
	holder.add_child(sun)
	holder.add_child(rim)
	var atmo = Atmo.new()
	atmo.sun_light = sun
	atmo.rim_light = rim
	holder.add_child(atmo)
	add_child(holder) # _ready: private Environment + sky copy, Zone 1 applied instantly
	return {"holder": holder, "atmo": atmo, "sun": sun, "rim": rim, "authored_sky": sky_mat}

func test_p4_every_zone_has_a_horizon_and_zone_1_applies_it_on_entry() -> void:
	for zone in range(1, 11):
		var row: Dictionary = Atmo.TABLE[zone]
		assert_true(row.has("sky_horizon"), "Zone %d has a sky_horizon" % zone)
	assert_eq(Atmo.TABLE[1]["sky_horizon"], Color(0.45, 0.18, 0.04), "Zones 1-4: sodium")
	assert_eq(Atmo.TABLE[6]["sky_horizon"], Color(0.35, 0.05, 0.35), "Zones 5-8: magenta")
	assert_eq(Atmo.TABLE[10]["sky_horizon"], Color(0.18, 0.05, 0.35), "Zones 9-10: violet")
	var rig := _atmosphere_rig()
	var atmo = rig["atmo"]
	SignalBus.zone_entered.emit("SECTOR 07 — X")
	atmo.active_tween.custom_step(Atmo.TWEEN_TIME + 0.1)
	SignalBus.zone_entered.emit("SECTOR 01 — STREET ENTRANCE")
	atmo.active_tween.custom_step(Atmo.TWEEN_TIME + 0.1)
	var sky := (rig["holder"] as WorldEnvironment).environment.sky.sky_material as ProceduralSkyMaterial
	assert_true(sky.sky_horizon_color.is_equal_approx(Color(0.45, 0.18, 0.04)), "Zone 1 horizon applied after zone_entered (%s)" % str(sky.sky_horizon_color))
	assert_true(sky != rig["authored_sky"], "The tween drives a private sky material")
	assert_true((rig["authored_sky"] as ProceduralSkyMaterial).sky_horizon_color != sky.sky_horizon_color, "...the authored one is untouched")

func test_p5_zone_entry_tints_the_key_and_rim_lights() -> void:
	for zone in range(1, 11):
		assert_true(Atmo.TABLE[zone].has("sun_color") and Atmo.TABLE[zone].has("rim_color"), "Zone %d carries key/rim colours" % zone)
	var rig := _atmosphere_rig()
	var sun: DirectionalLight3D = rig["sun"]
	var rim: DirectionalLight3D = rig["rim"]
	assert_true(sun.light_color.is_equal_approx(Atmo.TABLE[1]["sun_color"]), "Zone 1 key is sodium at start")
	SignalBus.zone_entered.emit("SECTOR 05 — NEON MARKET")
	rig["atmo"].active_tween.custom_step(Atmo.TWEEN_TIME + 0.1)
	assert_true(sun.light_color.is_equal_approx(Atmo.TABLE[5]["sun_color"]), "Zone 5 key is magenta (%s)" % str(sun.light_color))
	assert_almost_eq(sun.light_energy, 0.7, 0.001, "...at 0.7")
	assert_almost_eq(rim.light_energy, 0.25, 0.001, "Cyan rim fill at 0.25 in the Neon District")

# --- P6 ---------------------------------------------------------------------------------

func _hit(amount: float) -> DamageInfo:
	var info := DamageInfo.new()
	info.amount = amount
	return info

func _reset_stop(hs: Node) -> void:
	hs.hit_stop_timer = 0.0
	Engine.time_scale = 1.0

func test_p6_hit_stop_is_graded_by_damage() -> void:
	var hs := get_node("/root/HitStop")
	_reset_stop(hs)
	hs._on_player_hit_landed(_hit(10.0))
	assert_almost_eq(hs.hit_stop_timer, 0.04, 0.0001, "Light hit: 0.04 s")
	assert_almost_eq(Engine.time_scale, 0.10, 0.0001, "...at 0.10")
	_reset_stop(hs)
	hs._on_player_hit_landed(_hit(28.0))
	assert_almost_eq(hs.hit_stop_timer, 0.07, 0.0001, "Heavy hit: 0.07 s")
	assert_almost_eq(Engine.time_scale, 0.08, 0.0001, "...at 0.08")
	_reset_stop(hs)
	hs._on_player_hit_landed(_hit(40.0))
	assert_almost_eq(hs.hit_stop_timer, 0.11, 0.0001, "Finisher (40): 0.11 s")
	assert_almost_eq(Engine.time_scale, 0.05, 0.0001, "...at 0.05")
	# Merge rule: a light hit landing during the finisher's stop keeps the longer/deeper one.
	hs._on_player_hit_landed(_hit(10.0))
	assert_almost_eq(hs.hit_stop_timer, 0.11, 0.0001, "The merge keeps the longer stop")
	assert_almost_eq(Engine.time_scale, 0.05, 0.0001, "...and the deeper scale")
	_reset_stop(hs)
	var absorbed := _hit(28.0)
	absorbed.set_meta(Hurtbox3D.SHIELD_ABSORBED_META, true)
	hs._on_player_hit_landed(absorbed)
	assert_eq(hs.hit_stop_timer, 0.0, "A shield-absorbed hit does not stop")
	_reset_stop(hs)

func test_p6_a_kill_adds_a_beat_and_a_shake() -> void:
	var hs := get_node("/root/HitStop")
	_reset_stop(hs)
	var shakes: Array = []
	SignalBus.camera_shake_requested.connect(func(s: float, d: float): shakes.append(Vector2(s, d)))
	hs._on_enemy_died(Vector3.ZERO)
	assert_almost_eq(hs.hit_stop_timer, 0.12, 0.0001, "enemy_died: 0.12 s")
	assert_almost_eq(Engine.time_scale, 0.05, 0.0001, "...at 0.05")
	assert_true(shakes.has(Vector2(0.12, 0.2)), "...plus a (0.12, 0.2) shake")
	_reset_stop(hs)

# --- P7 ---------------------------------------------------------------------------------

func _bruiser() -> Node3D:
	var b: Node3D = _keep(load("res://characters/enemies/bruiser/bruiser.tscn").instantiate())
	b.position = Vector3(0.0, 600.0, 15300.0)
	add_child(b)
	b.set_physics_process(false)
	return b

func test_p7_bruiser_shield_breaks_once_with_a_steel_rim_that_restores() -> void:
	var b := _bruiser()
	var hc: HealthComponent = b.get_node("HealthComponent")
	var visual: CharacterVisual = b.get_node("MeshInstance3D")
	assert_eq(hc.current_shield, 80.0, "Precondition: 80 shield")
	assert_eq(visual.get_base_rim_color(), BruiserEnemy.SHIELD_RIM_COLOR, "Shield up: steel-white rim")
	assert_almost_eq(visual.get_base_rim_strength(), 3.5, 0.001, "...at strength 3.5")
	var broken: Array = []
	SignalBus.shield_broken.connect(func(p: Vector3): broken.append(p))
	for i in 4:
		hc.take_damage(_hit(30.0)) # 80 -> 50 -> 20 -> 0 (break) -> HP
	assert_eq(broken.size(), 1, "shield_broken fires exactly once when the 80 shield is exhausted")
	assert_eq(visual.get_base_rim_color(), CharacterVisual.ENEMY_RIM_COLOR, "The rim restores to the magenta default")
	assert_almost_eq(visual.get_base_rim_strength(), 3.0, 0.001, "...at the default strength")
	assert_eq(visual.get_current_rim_color(), Color.WHITE, "The break flashes white-hot first")

func test_p7_a_shield_absorbed_hit_emits_hit_blocked_not_hit_landed() -> void:
	var b := _bruiser()
	var player: PlayerController = _keep(load("res://characters/player/player.tscn").instantiate())
	player.position = Vector3(0.0, 600.0, 15330.0)
	add_child(player)
	var hurtbox: Hurtbox3D = b.get_node("Hurtbox3D")
	var got := {"landed": 0, "blocked": 0, "player_landed": 0}
	SignalBus.hit_landed.connect(func(_p, _t): got.landed += 1)
	SignalBus.hit_blocked.connect(func(_p): got.blocked += 1)
	SignalBus.player_hit_landed.connect(func(_i): got.player_landed += 1)
	var info := _hit(12.0)
	info.source = player
	hurtbox.receive_hit(info) # 80 -> 68: absorbed
	assert_eq(got.blocked, 1, "Absorbed by the shield: hit_blocked (steel clink)")
	assert_eq(got.landed, 0, "...not the cyan/magenta hit_landed")
	assert_eq(got.player_landed, 1, "The hit still feeds the combo/meter")
	assert_true(info.get_meta(Hurtbox3D.SHIELD_ABSORBED_META, false), "...flagged so HitStop skips it")
	var breaker := _hit(70.0)
	breaker.source = player
	hurtbox.receive_hit(breaker) # 68 -> 0: breaks through
	assert_eq(got.landed, 1, "The breaking hit is a real hit_landed")
	assert_false(breaker.get_meta(Hurtbox3D.SHIELD_ABSORBED_META, true), "...not flagged")

# --- P8 ---------------------------------------------------------------------------------

class MockFacingTarget extends Node3D:
	var current_path: Path3D = null
	var is_jump_enabled: bool = true
	var is_facing_right: bool = true
	var on_floor: bool = true
	func is_on_floor() -> bool:
		return on_floor

func _camera_rig() -> Dictionary:
	var cam: DroneCamera = _keep(load("res://characters/player/drone_camera.tscn").instantiate())
	var target: MockFacingTarget = _keep(MockFacingTarget.new())
	add_child(target)
	add_child(cam)
	cam.target = target
	cam.set_physics_process(false)
	cam.state_machine.set_physics_process(false)
	return {"cam": cam, "target": target, "side": cam.state_machine.states["sidescroll"]}

func test_p8_lead_follows_facing() -> void:
	var rig := _camera_rig()
	var side = rig["side"]
	for i in 120:
		side.physics_update(1.0 / 60.0)
	assert_almost_eq(side.lead, 2.5, 0.05, "Facing right: the frame leads +2.5 m")
	rig["target"].is_facing_right = false
	side.physics_update(1.0 / 60.0)
	assert_gt(side.lead, 2.0, "The lead eases over (no snap on a turn)")
	for i in 180:
		side.physics_update(1.0 / 60.0)
	assert_almost_eq(side.lead, -2.5, 0.05, "Facing left: the lead flips to -2.5 m")

func test_p8_height_holds_through_a_jump_inside_the_dead_zone() -> void:
	var rig := _camera_rig()
	var side = rig["side"]
	var target: MockFacingTarget = rig["target"]
	side.physics_update(1.0 / 60.0)
	assert_almost_eq(side.held_y, 0.0, 0.0001, "Grounded: the frame anchors at his height")
	target.on_floor = false
	target.position.y = 2.0
	side.physics_update(1.0 / 60.0)
	assert_almost_eq(side.held_y, 0.0, 0.0001, "A 2 m hop keeps the ground still")
	target.position.y = 4.0
	side.physics_update(1.0 / 60.0)
	assert_almost_eq(side.held_y, 1.5, 0.0001, "Past the 2.5 m dead zone it trails at the zone's edge")
	target.on_floor = true
	side.physics_update(1.0 / 60.0)
	assert_almost_eq(side.held_y, 4.0, 0.0001, "Landing re-anchors")

func test_p8_top_down_state_is_unchanged() -> void:
	var rig := _camera_rig()
	var cam: DroneCamera = rig["cam"]
	var top = cam.state_machine.states["topdown"]
	assert_false("lead" in top, "The top-down state has no look-ahead")
	cam.offset = DroneCamera.TOP_DOWN_OFFSET
	var target: MockFacingTarget = rig["target"]
	target.on_floor = false
	target.position = Vector3(3.0, 5.0, 1.0)
	cam.base_position = target.position + DroneCamera.TOP_DOWN_OFFSET
	top.physics_update(1.0 / 60.0)
	assert_true(cam.base_position.is_equal_approx(target.position + DroneCamera.TOP_DOWN_OFFSET), "Top-down follows the target on every axis")

# --- P10 --------------------------------------------------------------------------------

func test_p10_the_shock_ring_is_hdr_and_fades_out() -> void:
	var host: Node3D = _keep(Node3D.new())
	add_child(host)
	var ring := ShockRingScript.spawn(host, Vector3(0.0, 700.0, 0.0), 10.0, Color(1.0, 0.0, 0.666667), 0.3, "TestRing")
	assert_not_null(ring, "The ring spawns")
	var mat := (ring.mesh as TorusMesh).material as StandardMaterial3D
	assert_eq(mat.shading_mode, BaseMaterial3D.SHADING_MODE_UNSHADED)
	assert_eq(mat.transparency, BaseMaterial3D.TRANSPARENCY_ALPHA, "Alpha-blended so it can fade")
	assert_gt(mat.albedo_color.r, 1.0, "HDR (emissive) brightness: it blooms")
	assert_almost_eq(mat.albedo_color.a, 1.0, 0.0001, "Opaque at the start")
	await get_tree().create_timer(0.1).timeout
	assert_almost_eq(mat.albedo_color.a, 1.0, 0.0001, "No fade during the first 60 %")
	await get_tree().create_timer(0.16).timeout
	assert_lt(mat.albedo_color.a, 0.6, "Fading over the last 40 % (a %.2f)" % mat.albedo_color.a)
	await get_tree().create_timer(0.15).timeout
	assert_false(is_instance_valid(ring), "The ring frees itself")

func test_p10_bass_drop_flash_plays_on_the_combo_flash_overlay() -> void:
	var flash: CanvasLayer = _keep(load("res://vfx/combo_flash.tscn").instantiate())
	add_child(flash)
	SignalBus.screen_flash_requested.emit(0.35, 0.05)
	assert_almost_eq(flash.rect.color.a, 0.35, 0.0001, "screen_flash_requested snaps the overlay to 0.35")
	SignalBus.combo_increased.emit(3)
	assert_almost_eq(flash.rect.color.a, 0.35, 0.0001, "A weaker combo flash does not cut it")

func test_p10_headliner_phase_two_shakes_stops_and_rings() -> void:
	var boss: HeadlinerBoss = _keep(load("res://characters/enemies/headliner/headliner.tscn").instantiate())
	boss.position = Vector3(0.0, 300.0, 15400.0)
	add_child(boss)
	var bpm_before: float = Conductor.target_bpm
	var shakes: Array = []
	var stops: Array = []
	SignalBus.camera_shake_requested.connect(func(s: float, d: float): shakes.append(Vector2(s, d)))
	SignalBus.hit_stop_requested.connect(func(d: float, s: float): stops.append(Vector2(d, s)))
	var max_hp: float = boss.stats.max_health
	boss._on_health_changed(max_hp * 0.4, max_hp)
	assert_true(boss.phase_2_triggered, "Precondition: phase 2")
	assert_true(shakes.has(Vector2(0.55, 0.5)), "Phase 2 requests a (0.55, 0.5) shake (%s)" % str(shakes))
	assert_true(stops.has(Vector2(0.15, 0.05)), "...and a 0.15 s stop at 0.05")
	var ring: Node = get_node_or_null("PhaseTwoRing")
	assert_not_null(ring, "...and a shock ring at the boss's feet")
	if ring:
		_keep(ring)
		assert_almost_eq((ring as Node3D).global_position.y, boss.global_position.y - 3.0, 0.01, "The ring sits at the feet")
	Conductor.target_bpm = bpm_before
