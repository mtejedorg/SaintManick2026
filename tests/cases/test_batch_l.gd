extends "res://tests/framework/test_case.gd"

# Batch L (owner decisions, level / systems / menus): L1 Double Jump starts unlocked (D1),
# L2+L3 Zone 3/4/5 wave compositions (D9, D16), L4 faster escape wall on a ~120 m course with
# a second door and sign (D10), L5 holo-gate soft screen-lock + GO cue on the side-scroll
# encounters (D23), L6 control prompts until the first Zone 2 entry ever (D34), L7 auto-pause
# on focus loss (D29), L8 minimal options menu (D25).

const SLICE_PATH := "res://levels/slice/vertical_slice.tscn"
const PLAYER_SCENE := "res://characters/player/player.tscn"
const SHOP_SCRIPT := "res://ui/shop/karens_shop.gd"
const DOUBLE_JUMP_UPGRADE := "res://_core/persistence/shop_upgrades/upgrade_double_jump.tres"
const ONBOARDING_SCRIPT := "res://levels/components/onboarding_prompts.gd"
const PAUSE_SCENE := "res://ui/menus/pause_menu.tscn"
const TITLE_SCENE := "res://ui/menus/title_screen.tscn"
const OPTIONS_SCENE := "res://ui/menus/options_menu.tscn"
const GO_BANNER := "GO ->"

## Real zone names use an em dash ("SECTOR NN -- DESCRIPTION"); kept out of the source bytes.
var zone_1: String = "SECTOR 01 " + String.chr(0x2014) + " STREET ENTRANCE"
var zone_2: String = "SECTOR 02 " + String.chr(0x2014) + " PISTON GAUNTLET"

var _slice: Node3D
var _extra: Array[Node] = []
var _profile_backup: Dictionary = {}
var _run_ended_before: bool = false

func before_each() -> void:
	GameManager.is_test = true
	_run_ended_before = GameManager.run_ended
	var p: PlayerProfile = SaveManager.profile
	_profile_backup = {
		"seen_controls": p.seen_controls,
		"master_volume": p.master_volume,
		"music_volume": p.music_volume,
		"sfx_volume": p.sfx_volume,
		"fullscreen": p.fullscreen,
	}

func after_each() -> void:
	super.after_each()
	get_tree().paused = false
	GameManager.run_ended = _run_ended_before
	var p: PlayerProfile = SaveManager.profile
	for key in _profile_backup.keys():
		p.set(key, _profile_backup[key])
	SaveManager.apply_settings()
	for n in _extra:
		if is_instance_valid(n):
			n.free()
	_extra.clear()
	if is_instance_valid(_slice):
		_slice.free()

func _keep(node: Node) -> Node:
	_extra.append(node)
	return node

func _spawn_slice() -> Node3D:
	_slice = (load(SLICE_PATH) as PackedScene).instantiate()
	add_child(_slice)
	return _slice

func _collect_banners() -> Array[String]:
	var got: Array[String] = []
	SignalBus.banner_requested.connect(func(text: String, _hold: float): got.append(text))
	return got

## Enemy counts of a wave by scene file ("runner" -> 3, ...).
func _composition(wave: WaveDef) -> Dictionary:
	var out := {}
	for scene in wave.enemies:
		var key: String = (scene as PackedScene).resource_path.get_file().get_basename()
		out[key] = int(out.get(key, 0)) + 1
	return out

func _x_span(box: CSGBox3D) -> Vector2:
	return Vector2(box.global_position.x - box.size.x * 0.5, box.global_position.x + box.size.x * 0.5)

func _trigger_span(trigger: Area3D) -> Vector2:
	var shape := (trigger.get_node("CollisionShape3D") as CollisionShape3D).shape as BoxShape3D
	return Vector2(trigger.global_position.x - shape.size.x * 0.5, trigger.global_position.x + shape.size.x * 0.5)

# --- L1 ------------------------------------------------------------------------------

func test_l1_a_new_profile_has_the_double_jump() -> void:
	var p := PlayerProfile.new()
	assert_true(p.double_jump_unlocked, "D1: a fresh profile starts with the double jump unlocked")

func test_l1_the_shop_row_reads_owned_on_a_fresh_profile() -> void:
	var shop: Control = load(SHOP_SCRIPT).new()
	var upgrade: ShopUpgrade = load(DOUBLE_JUMP_UPGRADE)
	var row: String = shop._row_text(upgrade, PlayerProfile.new())
	assert_true(row.begins_with("[OWNED]"), "The Double Jump row is [OWNED] on a fresh profile (%s)" % row)
	assert_true(shop._is_upgrade_owned(upgrade, PlayerProfile.new()), "...and cannot be bought again")
	shop.free()

# --- L2 / L3 -------------------------------------------------------------------------

func test_l2_l3_zone_3_4_5_wave_compositions() -> void:
	var slice := _spawn_slice()
	var z3: ZoneEncounter = slice.get_node("Z3_Encounter")
	assert_eq(z3.waves.size(), 2, "Zone 3 keeps two waves")
	assert_eq(_composition(z3.waves[1]), {"runner": 3}, "D16: Zone 3 wave 2 is three Runners, no Bruiser")
	var z4: ZoneEncounter = slice.get_node("Z4_Encounter")
	assert_eq(z4.waves.size(), 1, "D9: Zone 4 is one wave")
	assert_eq(_composition(z4.waves[0]), {"runner": 3, "bruiser": 1, "sniper": 2}, "D9+D16: 3 Runners + the Bruiser debut + 2 catwalk Snipers")
	var w4: WaveDef = z4.waves[0]
	for i in w4.enemies.size():
		var is_sniper: bool = (w4.enemies[i] as PackedScene).resource_path.get_file().begins_with("sniper")
		assert_eq(w4.is_blocking(i), not is_sniper, "Slot %d: snipers are non-blocking, the rest blocking" % i)
		if is_sniper:
			assert_true(w4.spawn_markers[i].begins_with("SniperSpawnPoint"), "Slot %d sniper spawns on a catwalk marker" % i)
			assert_not_null(z4.spawner.get_node_or_null(w4.spawn_markers[i]), "...that exists (%s)" % w4.spawn_markers[i])
	var z5: ZoneEncounter = slice.get_node("Z5_Encounter")
	assert_eq(z5.waves.size(), 1, "D9: Zone 5 is one wave")
	assert_eq(_composition(z5.waves[0]), {"runner": 3, "bruiser": 1}, "D9: 3 Runners + 1 Bruiser")
	var z6: ZoneEncounter = slice.get_node("Z6_Encounter")
	assert_eq(z6.waves.size(), 2, "Zone 6 unchanged")
	assert_eq(_composition(z6.waves[0]), {"runner": 8, "bruiser": 2}, "Zone 6 wave 1 unchanged")
	assert_eq(_composition(z6.waves[1]), {"sniper": 3}, "Zone 6 wave 2 unchanged")

func test_l2_the_removed_wave_resources_are_gone_from_the_scene() -> void:
	var text := FileAccess.get_file_as_string(SLICE_PATH)
	for rid in ["Resource_z4_w2", "Resource_z4_w3", "Resource_z5_w2", "Resource_z5_w3"]:
		assert_false(text.contains(rid), "%s was removed" % rid)
	var ext := text.count("[ext_resource")
	var sub := text.count("[sub_resource")
	assert_true(text.begins_with("[gd_scene load_steps=%d " % (ext + sub + 1)), "load_steps = ext + sub + 1 (%d)" % (ext + sub + 1))

# --- L4 ------------------------------------------------------------------------------

func test_l4_wall_runs_5_5_and_nick_still_beats_it_by_two_seconds() -> void:
	var slice := _spawn_slice()
	var wall: EscapeKillWall = slice.get_node("EscapeSequence/EscapeKillWall")
	assert_almost_eq(wall.speed, 5.5, 0.0001, "D10: the kill wall moves at 5.5 m/s")
	var fresh := EscapeKillWall.new()
	assert_almost_eq(fresh.speed, 5.5, 0.0001, "...also as the script default")
	fresh.free()
	var end_x: float = (slice.get_node("EscapeSequence/EscapeEndTrigger") as Node3D).global_position.x
	var barrier_x: float = (slice.get_node("Z7_Barrier") as Node3D).global_position.x
	assert_true(end_x - barrier_x >= 115.0, "The Zone 8 course is ~120 m (barrier x %.1f -> exit x %.1f)" % [barrier_x, end_x])
	var nick: PlayerController = load(PLAYER_SCENE).instantiate()
	var run_speed: float = nick.max_speed
	nick.free()
	var wall_time := (end_x - 269.0) / wall.speed
	var nick_time := (end_x - 280.0) / run_speed
	assert_true(wall_time - nick_time >= 2.0, "Wall from x 269 (%.1f s) reaches the exit >= 2 s after Nick from x 280 at %.1f m/s (%.1f s)" % [wall_time, run_speed, nick_time])

func test_l4_second_door_and_sign_run_out_of_phase() -> void:
	var slice := _spawn_slice()
	var door1: EscapeDoorHazard = slice.get_node("EscapeDoorHazard")
	var door2: EscapeDoorHazard = slice.get_node("EscapeDoorHazard2")
	var sign1: EscapeFallingHazard = slice.get_node("EscapeFallingHazard")
	var sign2: EscapeFallingHazard = slice.get_node("EscapeFallingHazard2")
	assert_almost_eq(door2.global_position.x, 330.0, 2.0, "Second blast door at ~x 330")
	assert_almost_eq(sign2.global_position.x, 360.0, 2.0, "Second falling sign at ~x 360")
	assert_eq(door2.close_beat_interval, 4, "Door 2 runs a 4-beat cycle")
	assert_eq(sign2.beat_interval, 8, "Sign 2 runs an 8-beat cycle")
	assert_eq(door2.global_position.y, door1.global_position.y, "Door 2 closes flush like door 1")
	assert_eq(sign2.fall_distance, sign1.fall_distance, "Sign 2 reaches the floor like sign 1")
	# Same beats from here on: the counters keep their offset, so the pairs never sync.
	assert_true(posmod(door2.local_beat_counter - door1.local_beat_counter, 4) != 0, "Doors are not in phase")
	assert_true(posmod(sign2.local_beat_counter - sign1.local_beat_counter, 8) != 0, "Signs are not in phase")
	var closed_together := 0
	for i in 8:
		door1._on_beat("primary", i)
		door2._on_beat("primary", i)
		if door1.is_closed and door2.is_closed:
			closed_together += 1
	assert_lt(closed_together, 2, "The two doors are never shut on the same beats")

func test_l4_course_keeps_its_gap_and_runs_floor_to_the_elevator() -> void:
	var slice := _spawn_slice()
	var g1 := _x_span(slice.get_node("Z8_Ground1"))
	var g2 := _x_span(slice.get_node("Z8_Ground2"))
	assert_almost_eq(g2.x - g1.y, 5.0, 0.001, "The 5 m gap stays")
	assert_almost_eq((slice.get_node("EscapeCollapsingHazard") as Node3D).global_position.x, 313.0, 0.001, "The collapsing platform stays")
	var platform: Node3D = slice.get_node("ElevatorPlatform")
	var platform_half := ((platform.get_node("CollisionShape3D") as CollisionShape3D).shape as BoxShape3D).size.x * 0.5
	assert_almost_eq(g2.y, platform.global_position.x - platform_half, 0.001, "The floor runs on to the shifted elevator")
	var trim := _x_span(slice.get_node("Trims/Z8_Trim2"))
	assert_almost_eq(trim.x, g2.x, 0.001, "Z8 trim follows the longer floor")
	assert_almost_eq(trim.y, g2.y, 0.001, "...to its end")
	assert_almost_eq((slice.get_node("Zone10_Trigger") as Node3D).global_position.x, 417.0, 0.001, "Zone 10 trigger moved +60 (357 -> 417)")
	var sign2: Node3D = slice.get_node("EscapeFallingHazard2")
	assert_true(sign2.global_position.x > g2.x and sign2.global_position.x < g2.y, "Sign 2 drops onto the floor")

# --- L5 ------------------------------------------------------------------------------

func test_l5_side_scroll_encounters_have_a_holo_gate_pair() -> void:
	var slice := _spawn_slice()
	for enc_name in ["Z1_Encounter", "Z4_Encounter", "Z5_Encounter"]:
		var enc: ZoneEncounter = slice.get_node(enc_name)
		assert_false(enc.is_top_down, "%s is side-scroll" % enc_name)
		assert_eq(enc.gates.size(), 2, "%s has two gates" % enc_name)
		if enc.gates.size() != 2:
			continue
		var trigger := _trigger_span(enc)
		for gate in enc.gates:
			assert_true(gate is CSGBox3D, "%s gate is a CSGBox3D" % enc_name)
			var box := gate as CSGBox3D
			# P2: 3.2 m deep (was 8: an opaque slab filling the frame edges), still 12 m tall.
			assert_eq(box.size, Vector3(1, 12, 3.2), "%s/%s is 1 x 12 x 3.2 (taller than the double jump)" % [enc_name, gate.name])
			var mat := box.material as ShaderMaterial
			assert_true(mat != null and mat.shader != null and mat.shader.code.contains("blend_add"), "%s/%s is an additive hologram" % [enc_name, gate.name])
			assert_true(gate.is_in_group("gates"), "%s/%s is a legal golden-path obstacle" % [enc_name, gate.name])
			assert_false(box.use_collision or box.visible, "%s/%s is open at rest" % [enc_name, gate.name])
		var entrance := _x_span(enc.gates[0])
		var exit := _x_span(enc.gates[1])
		# Nick (r 0.5) is fully past the entrance when the trigger fires, so a locking gate
		# never closes on him.
		assert_true(entrance.y <= trigger.x - 1.0 + 0.001, "%s entrance (x %.1f..%.1f) is behind the trigger (from %.1f)" % [enc_name, entrance.x, entrance.y, trigger.x])
		assert_gt(exit.x, trigger.y, "%s exit is ahead of the trigger" % enc_name)
	var nick_x: float = (slice.get_node("Player") as Node3D).global_position.x
	assert_true(_x_span(slice.get_node("Z1_Gates/GateEntrance")).y <= nick_x - 0.5, "Zone 1's entrance gate is behind Nick's start")
	var lower := _x_span(slice.get_node("Z5_Market/LowerTier"))
	var z5_exit := _x_span(slice.get_node("Z5_Gates/GateExit"))
	assert_true(z5_exit.y <= lower.y + 0.001, "Zone 5 exit gate stands on the lower tier; the ramp to Zone 6 stays outside")

func test_l5_real_gates_lock_and_open_with_a_go_cue() -> void:
	var slice := _spawn_slice()
	var enc: ZoneEncounter = slice.get_node("Z4_Encounter")
	var got := _collect_banners()
	enc.set_gate_locked(true)
	await get_tree().process_frame
	for gate in enc.gates:
		assert_true(gate.visible and (gate as CSGBox3D).use_collision, "%s locks" % gate.name)
	enc.active = true
	enc._complete_encounter()
	await get_tree().process_frame
	for gate in enc.gates:
		assert_false(gate.visible or (gate as CSGBox3D).use_collision, "%s opens on completion" % gate.name)
	assert_true(got.has(GO_BANNER), "A cleared side-scroll encounter cues GO (%s)" % str(got))

func test_l5_activation_locks_and_completion_unlocks() -> void:
	var node := Node3D.new()
	var dummy := PackedScene.new()
	dummy.pack(node)
	node.free()
	var spawner: WaveSpawner = _keep(WaveSpawner.new())
	spawner.add_child(Marker3D.new())
	var enc: ZoneEncounter = _keep(ZoneEncounter.new())
	var mock: PlayerController = _keep(PlayerController.new())
	var g1: CSGBox3D = _keep(CSGBox3D.new())
	var g2: CSGBox3D = _keep(CSGBox3D.new())
	add_child(g1)
	add_child(g2)
	var gates: Array[Node3D] = [g1, g2]
	enc.gates = gates
	enc.spawner = spawner
	var wave := WaveDef.new()
	var enemies: Array[PackedScene] = [dummy]
	wave.enemies = enemies
	var waves: Array[WaveDef] = [wave]
	enc.waves = waves
	add_child(spawner)
	add_child(enc)
	var got := _collect_banners()
	enc._on_body_entered(mock)
	await get_tree().process_frame
	assert_true(g1.use_collision and g2.use_collision and g1.visible and g2.visible, "Activation locks both gates")
	assert_eq(got.size(), 0, "No GO cue while the fight runs")
	assert_eq(spawner.active_enemies.size(), 1, "The wave spawned")
	if spawner.active_enemies.size() == 1:
		spawner._on_enemy_defeated(spawner.active_enemies[0])
	await get_tree().process_frame
	assert_true(enc.completed, "Encounter completed")
	assert_false(g1.use_collision or g2.use_collision or g1.visible or g2.visible, "Completion opens both gates")
	assert_eq(got.size(), 1, "...with one cue")
	if got.size() == 1:
		assert_eq(got[0], GO_BANNER, "...GO")

func test_l5_top_down_completion_shows_no_go_cue() -> void:
	var gate: CSGBox3D = _keep(CSGBox3D.new())
	add_child(gate)
	var enc: ZoneEncounter = _keep(ZoneEncounter.new())
	var gates: Array[Node3D] = [gate]
	enc.gates = gates
	enc.is_top_down = true
	add_child(enc)
	enc.active = true
	var got := _collect_banners()
	enc._complete_encounter()
	SignalBus.camera_shift_finished.emit(false)
	await get_tree().process_frame
	assert_false(gate.use_collision, "The room opens once the shift lands")
	assert_eq(got.size(), 0, "Top-down rooms get no GO cue (%s)" % str(got))

# --- L6 ------------------------------------------------------------------------------

func _prompts() -> Node:
	var prompts: Node = load(ONBOARDING_SCRIPT).new()
	prompts.first_delay = 0.0
	prompts.replay_delay = 0.0
	prompts.spacing = 0.02
	prompts.top_down_delay = 0.0
	add_child(prompts)
	return _keep(prompts)

func test_l6_seen_controls_skips_the_zone_one_cards() -> void:
	SaveManager.profile.seen_controls = true
	_prompts()
	var got := _collect_banners()
	SignalBus.zone_entered.emit(zone_1)
	await get_tree().create_timer(0.15).timeout
	assert_eq(got.size(), 0, "No Zone 1 card once the controls were seen (%s)" % str(got))
	# The once-per-run extra cards are not gated by the flag.
	SignalBus.camera_shift_finished.emit(true)
	SignalBus.ability_meter_changed.emit(100.0, 100.0)
	assert_eq(got.size(), 2, "TOP-DOWN and BASS DROP still fire (%s)" % str(got))

func test_l6_first_zone_two_entry_marks_the_controls_seen() -> void:
	SaveManager.profile.seen_controls = false
	assert_false(PlayerProfile.new().seen_controls, "A fresh profile has not seen the controls")
	_prompts()
	var got := _collect_banners()
	SignalBus.zone_entered.emit(zone_1)
	await get_tree().create_timer(0.15).timeout
	assert_eq(got.size(), 3, "A fresh profile plays the three Zone 1 cards")
	assert_false(SaveManager.profile.seen_controls, "Zone 1 alone does not mark them seen")
	SignalBus.zone_entered.emit(zone_2)
	assert_true(SaveManager.profile.seen_controls, "The first Zone 2 entry marks the controls as seen")
	SignalBus.run_started.emit()
	SignalBus.zone_entered.emit(zone_1)
	await get_tree().create_timer(0.15).timeout
	assert_eq(got.size(), 3, "The next run skips them")

# --- L7 ------------------------------------------------------------------------------

func _pause_menu() -> CanvasLayer:
	var pm: CanvasLayer = load(PAUSE_SCENE).instantiate()
	add_child(pm)
	return _keep(pm) as CanvasLayer

func test_l7_focus_loss_opens_the_pause_menu() -> void:
	GameManager.run_ended = false
	var pm := _pause_menu()
	assert_false(pm.visible, "Hidden at rest")
	pm.notification(Node.NOTIFICATION_APPLICATION_FOCUS_OUT)
	assert_true(get_tree().paused, "Focus loss pauses the game")
	assert_true(pm.visible, "...through the pause menu")
	pm.call("_resume")
	assert_false(get_tree().paused, "Resume unpauses")

func test_l7_focus_loss_after_the_run_ended_does_not_pause() -> void:
	var pm := _pause_menu()
	GameManager.run_ended = true
	pm.notification(Node.NOTIFICATION_APPLICATION_FOCUS_OUT)
	assert_false(get_tree().paused, "No pause in the game-over / results transition")
	assert_false(pm.visible, "...and no menu")

func test_l7_focus_loss_in_the_victory_hold_or_while_paused_does_not_toggle() -> void:
	GameManager.run_ended = false
	var pm := _pause_menu()
	SignalBus.boss_spawned.emit("Enforcer")
	SignalBus.boss_died.emit()
	pm.notification(Node.NOTIFICATION_APPLICATION_FOCUS_OUT)
	assert_true(get_tree().paused and pm.visible, "The Enforcer's death is no victory hold")
	pm.call("_resume")
	SignalBus.boss_spawned.emit("Headliner")
	SignalBus.boss_died.emit()
	pm.notification(Node.NOTIFICATION_APPLICATION_FOCUS_OUT)
	assert_false(get_tree().paused or pm.visible, "No pause inside the Headliner's victory hold")
	SignalBus.boss_reset.emit()
	get_tree().paused = true # paused by something else
	pm.notification(Node.NOTIFICATION_APPLICATION_FOCUS_OUT)
	assert_false(pm.visible, "An already paused tree is left alone")

# --- L8 ------------------------------------------------------------------------------

func _options() -> Control:
	var om: Control = load(OPTIONS_SCENE).instantiate()
	add_child(om)
	return _keep(om) as Control

func test_l8_options_scene_has_three_sliders_and_a_toggle() -> void:
	var om := _options()
	var sliders := om.find_children("*", "HSlider", true, false)
	assert_eq(sliders.size(), 3, "Master / Music / SFX sliders")
	for s in sliders:
		assert_eq((s as HSlider).max_value, 100.0, "%s runs 0-100" % s.name)
	var toggle: Button = om.get_node("Panel/VBox/FullscreenToggle")
	assert_true(toggle.toggle_mode, "Fullscreen is a toggle")
	assert_false(om.visible, "Hidden until opened")
	# Gamepad navigation: the column wraps.
	var master: HSlider = om.get_node("Panel/VBox/Grid/MasterSlider")
	var back: Button = om.get_node("Panel/VBox/BackButton")
	assert_eq(master.get_node(master.focus_neighbor_bottom), om.get_node("Panel/VBox/Grid/MusicSlider"), "Down from Master is Music")
	assert_eq(back.get_node(back.focus_neighbor_bottom), master, "Down from BACK wraps to Master")
	om.call("open")
	assert_true(om.visible and master.has_focus(), "open() shows the panel with Master focused")

func test_l8_moving_a_slider_writes_the_bus_and_the_profile() -> void:
	var om := _options()
	om.call("open")
	var music: HSlider = om.get_node("Panel/VBox/Grid/MusicSlider")
	var idx := AudioServer.get_bus_index(SaveManager.BUS_MUSIC)
	assert_true(idx >= 0, "Music bus exists")
	var base: float = SaveManager.bus_base_db(SaveManager.BUS_MUSIC)
	music.value = 50.0
	assert_almost_eq(SaveManager.profile.music_volume, 0.5, 0.0001, "The profile stores 0.5")
	assert_almost_eq(AudioServer.get_bus_volume_db(idx), base + linear_to_db(0.5), 0.01, "The Music bus drops ~6 dB below its authored level")
	music.value = 100.0
	assert_almost_eq(AudioServer.get_bus_volume_db(idx), base, 0.01, "100 % restores the authored level (mix contract kept)")
	var master: HSlider = om.get_node("Panel/VBox/Grid/MasterSlider")
	master.value = 0.0
	assert_almost_eq(SaveManager.profile.master_volume, 0.0, 0.0001, "Master 0 stored")
	assert_almost_eq(AudioServer.get_bus_volume_db(AudioServer.get_bus_index(SaveManager.BUS_MASTER)), SaveManager.MUTE_DB, 0.01, "Master 0 mutes")

func test_l8_settings_persist_and_apply_at_boot() -> void:
	var defaults := PlayerProfile.new()
	assert_eq([defaults.master_volume, defaults.music_volume, defaults.sfx_volume, defaults.fullscreen], [1.0, 1.0, 1.0, false], "Defaults")
	var original_path: String = SaveManager.save_path
	var original_profile: PlayerProfile = SaveManager.profile
	SaveManager.save_path = "user://test_batch_l_options.tres"
	SaveManager.profile = PlayerProfile.new()
	SaveManager.profile.sfx_volume = 0.25
	SaveManager.profile.fullscreen = true
	SaveManager.save_profile()
	SaveManager.profile = null
	SaveManager.load_profile()
	assert_almost_eq(SaveManager.profile.sfx_volume, 0.25, 0.0001, "sfx_volume persists")
	assert_true(SaveManager.profile.fullscreen, "fullscreen persists")
	SaveManager.apply_settings()
	var idx := AudioServer.get_bus_index(SaveManager.BUS_SFX)
	assert_almost_eq(AudioServer.get_bus_volume_db(idx), SaveManager.bus_base_db(SaveManager.BUS_SFX) + linear_to_db(0.25), 0.01, "apply_settings() sets the SFX bus")
	DirAccess.remove_absolute(ProjectSettings.globalize_path(SaveManager.save_path))
	SaveManager.save_path = original_path
	SaveManager.profile = original_profile

func test_l8_title_and_pause_reach_the_options() -> void:
	var title: CanvasLayer = load(TITLE_SCENE).instantiate()
	add_child(title)
	_keep(title)
	var options_button := title.get_node_or_null("Root/ButtonContainer/OptionsButton") as Button
	assert_not_null(options_button, "The title screen has an OptionsButton")
	if options_button == null:
		return
	var title_options: Control = title.get_node("Root/OptionsMenu")
	options_button.pressed.emit()
	assert_true(title_options.visible, "OPTIONS opens the panel")
	assert_false((title.get_node("Root/ButtonContainer") as Control).visible, "...in place of the title buttons")
	title_options.call("close")
	assert_true((title.get_node("Root/ButtonContainer") as Control).visible, "Closing brings the buttons back")
	assert_true(options_button.has_focus(), "...with OPTIONS focused")

	GameManager.run_ended = false
	var pm := _pause_menu()
	pm.call("toggle")
	var pause_options: Control = pm.get_node("Root/OptionsMenu")
	(pm.get_node("Root/MenuPanel/PanelVBox/ButtonContainer/OptionsButton") as Button).pressed.emit()
	assert_true(pause_options.visible, "The pause menu opens the same panel")
	assert_false((pm.get_node("Root/MenuPanel") as Control).visible, "...in place of its own")
	var cancel := InputEventAction.new()
	cancel.action = "ui_cancel"
	cancel.pressed = true
	pause_options.call("_input", cancel)
	assert_false(pause_options.visible, "ui_cancel returns from the options")
	assert_true((pm.get_node("Root/MenuPanel") as Control).visible, "...to the pause menu")
	assert_true(get_tree().paused, "...still paused")
	pm.call("_resume")
