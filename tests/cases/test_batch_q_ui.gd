extends "res://tests/framework/test_case.gd"

# Batch Q-UI: a demo-ready front end. Q1 demo kit + loadout, Q2 RunBooster catalog, Q3 end
# screens + run stats, Q4 pause safety / alternate keys / accessibility options, Q5 zone tag +
# boss card, Q6 action-gated hint strip + one-shot hints, Q7 scene transitions, Q8 vitals +
# low-HP vignette. (Q4b lives in test_hud_banners / test_hud_rebuild.)

const FocusGrace = preload("res://ui/menus/focus_grace.gd")
const SceneTransition = preload("res://ui/transition/scene_transition.gd")
const KarensShop = preload("res://ui/shop/karens_shop.gd")
const RunBoosterRes = preload("res://_core/persistence/run_booster.gd")
const HUD_SCENE := "res://ui/hud/hud.tscn"
const HINTS_SCENE := "res://ui/hud/hud_hints.tscn"
const GAME_OVER_SCENE := "res://ui/menus/game_over_screen.tscn"
const RESULTS_SCENE := "res://ui/menus/run_results_screen.tscn"
const PAUSE_SCENE := "res://ui/menus/pause_menu.tscn"
const OPTIONS_SCENE := "res://ui/menus/options_menu.tscn"
const ONBOARDING_SCRIPT := "res://levels/components/onboarding_prompts.gd"
const SLICE_SCENE := "res://levels/slice/vertical_slice.tscn"
const THEME_PATH := "res://ui/theme/neon_theme.tres"

var zone_3: String = "SECTOR 03 " + String.chr(0x2014) + " ROOFTOPS"

var _nodes: Array[Node] = []
var _requested: Array[String] = []

func before_each() -> void:
	GameManager.is_test = true
	GameManager.run_ended = false
	_requested.clear()

func after_each() -> void:
	super.after_each()
	get_tree().paused = false
	for action in ["jump", "dash", "roll", "attack_light", "attack_heavy"]:
		Input.action_release(action)
	for n in _nodes:
		if is_instance_valid(n):
			n.free()
	_nodes.clear()
	GameManager.demo_boosters.clear()
	GameManager.set("_session_seen_controls", false)
	GameManager.set("_session_seen_hints", 0)
	GameManager.start_new_run()

func _add(scene_path: String) -> Node:
	var n: Node = (load(scene_path) as PackedScene).instantiate()
	add_child(n)
	_nodes.append(n)
	return n

func _record(path: String) -> void:
	_requested.append(path)

func _collect_banners() -> Array[String]:
	var got: Array[String] = []
	SignalBus.banner_requested.connect(func(text: String, _hold: float): got.append(text))
	return got

func _wait_real(seconds: float) -> void:
	await get_tree().create_timer(seconds, true, false, true).timeout

# --- Q1 ------------------------------------------------------------------------------

func test_q1_demo_unlocks_every_combo_and_the_double_jump() -> void:
	var p: PlayerProfile = SaveManager.profile
	p.unlocked_combos.clear()
	p.double_jump_unlocked = false
	GameManager.start_new_run()
	assert_false(GameManager.is_combo_unlocked("HL"), "A full run reads the profile's combo tree")
	assert_false(GameManager.double_jump_available(), "...and the profile's Double Jump")
	p.unlocked_combos.append("HL")
	assert_true(GameManager.is_combo_unlocked("HL"), "A purchased route is unlocked")
	GameManager.start_new_run(true)
	assert_true(GameManager.is_combo_unlocked("LLH") and GameManager.is_combo_unlocked("anything"), "A demo run plays every route")
	assert_true(GameManager.double_jump_available(), "...and always has the Double Jump")
	assert_false(p.unlocked_combos.has("LLH"), "...without writing anything to the profile")

# --- Q2 ------------------------------------------------------------------------------

func test_q2_catalog_has_three_boosters_with_todays_values() -> void:
	assert_eq(GameManager.RUN_BOOSTERS.size(), 3, "Three run boosters")
	var names: Array[String] = []
	for b in GameManager.RUN_BOOSTERS:
		assert_true(b.resource_path.begins_with("res://_core/persistence/run_boosters/"), "%s is a .tres in run_boosters/" % b.display_name)
		names.append(b.display_name)
	assert_eq(names, ["Tempo Shield", "Adrenaline", "Scrap Magnet"] as Array[String], "Catalog order = shop cycle order")
	var tempo: RunBoosterRes = GameManager.find_run_booster("Tempo Shield")
	assert_eq(tempo.effect, RunBoosterRes.Effect.SHIELD_MULT)
	assert_almost_eq(tempo.value, 1.5, 0.0001, "Tempo Shield x1.5 shield")
	assert_eq(GameManager.find_run_booster("adrenaline").effect, RunBoosterRes.Effect.SPEED_MULT, "Lookup by id works too")
	assert_almost_eq(GameManager.find_run_booster("Adrenaline").value, 1.2, 0.0001, "Adrenaline x1.2 speed")
	assert_almost_eq(GameManager.find_run_booster("Scrap Magnet").value, 2.0, 0.0001, "Scrap Magnet x2")
	assert_null(GameManager.find_run_booster("None"), "None is no booster")

func test_q2_effects_apply_from_the_resources() -> void:
	var p: PlayerProfile = SaveManager.profile
	p.shield_upgrades = 0
	p.booster_slots = 3
	p.equipped_run_boosters = ["Tempo Shield", "Adrenaline", "Scrap Magnet"] as Array[String]
	GameManager.start_new_run()
	assert_eq(GameManager.max_shield, 60.0, "40 x 1.5 shield")
	assert_almost_eq(GameManager.run_speed_multiplier, 1.2, 0.0001, "x1.2 speed")
	assert_eq(GameManager.scrap_multiplier, 2, "x2 scrap (int)")
	GameManager.add_scrap(5)
	assert_eq(GameManager.scrap, 10, "...doubling pickups")
	p.equipped_run_boosters = [] as Array[String]
	GameManager.start_new_run()
	assert_eq([GameManager.max_shield, GameManager.run_speed_multiplier, GameManager.scrap_multiplier], [40.0, 1.0, 1], "No booster -> no modifier")

func test_q2_shop_cycle_reads_the_catalog() -> void:
	assert_eq(KarensShop.booster_names(), ["None", "Tempo Shield", "Adrenaline", "Scrap Magnet"] as Array[String], "The shop cycles None + the catalog")
	var text := FileAccess.get_file_as_string("res://ui/menus/demo_loadout.gd")
	assert_false(text.contains("karens_shop.gd"), "The demo loadout no longer preloads the shop")
	var gm_text := FileAccess.get_file_as_string("res://_core/game_manager.gd")
	assert_false(gm_text.contains("\"Tempo Shield\":"), "start_new_run no longer string-matches booster names")

# --- Q3 ------------------------------------------------------------------------------

func test_q3_run_time_counts_while_a_run_is_active() -> void:
	GameManager.start_new_run()
	assert_almost_eq(GameManager.run_time, 0.0, 0.05, "A new run starts the clock at 0")
	var t0: float = GameManager.run_time
	GameManager._process(1.0)
	assert_almost_eq(GameManager.run_time - t0, 1.0, 0.0001, "A live run counts the frame's delta")
	get_tree().paused = true
	var t1: float = GameManager.run_time
	GameManager._process(1.0)
	assert_eq(GameManager.run_time, t1, "...not while paused")
	get_tree().paused = false
	GameManager.run_ended = true
	GameManager._process(1.0)
	assert_eq(GameManager.run_time, t1, "...and not once the run has ended")
	assert_false(GameManager.is_run_active())

func test_q3_max_combo_and_lives_lost_track() -> void:
	# The framework disconnects SignalBus after each test: reconnect GameManager's listeners.
	if not SignalBus.combo_increased.is_connected(GameManager._on_combo_increased):
		SignalBus.combo_increased.connect(GameManager._on_combo_increased)
	if not SignalBus.player_life_lost.is_connected(GameManager._on_player_life_lost):
		SignalBus.player_life_lost.connect(GameManager._on_player_life_lost)
	GameManager.start_new_run()
	assert_eq([GameManager.max_combo, GameManager.lives_lost], [0, 0], "Reset by start_new_run")
	SignalBus.combo_increased.emit(4)
	SignalBus.combo_increased.emit(9)
	SignalBus.combo_increased.emit(2)
	assert_eq(GameManager.max_combo, 9, "max_combo keeps the best chain")
	GameManager.respawn_or_game_over()
	assert_eq(GameManager.lives_lost, 1, "A spent life counts")
	GameManager.start_new_run()
	assert_eq([GameManager.max_combo, GameManager.lives_lost], [0, 0], "...and resets with the next run")

func test_q3_demo_game_over_has_a_focused_retry() -> void:
	GameManager.start_new_run(true)
	var demo: Array[String] = ["Adrenaline"]
	GameManager.demo_boosters = demo
	var screen: CanvasLayer = _add(GAME_OVER_SCENE)
	screen.change_scene = _record
	assert_true(screen.retry_button.visible, "Demo game over offers RETRY")
	assert_eq(screen.retry_button.get_index() < screen.return_button.get_index(), true, "...above RETURN TO TITLE")
	assert_eq(screen.return_button.text, "RETURN TO TITLE")
	assert_false(screen.retry_button.disabled, "No grey button during the grace")
	screen.retry_button.pressed.emit()
	assert_eq(_requested.size(), 0, "A press inside the grace is ignored")
	await _wait_real(FocusGrace.END_SCREEN_GRACE + 0.1)
	assert_true(screen.retry_button.has_focus(), "RETRY is the focused primary")
	GameManager.run_ended = true
	screen.retry_button.pressed.emit()
	assert_eq(_requested, [SLICE_SCENE] as Array[String], "RETRY goes straight back into the slice")
	assert_true(GameManager.demo_mode and not GameManager.run_ended, "...as a fresh demo run")
	assert_almost_eq(GameManager.run_speed_multiplier, 1.2, 0.0001, "...with the same loadout")
	GameManager.start_new_run()
	var normal: CanvasLayer = _add(GAME_OVER_SCENE)
	assert_false(normal.retry_button.visible, "A full run's game over is unchanged (no RETRY)")
	assert_eq(normal.primary_button(), normal.return_button)

func test_q3_results_grid_rows_and_rank() -> void:
	GameManager.start_new_run()
	GameManager.zones_cleared = 10
	GameManager.run_time = 125.4
	GameManager.max_combo = 17
	GameManager.lives_lost = 1
	GameManager.add_scrap(42)
	GameManager.add_cells(3)
	GameManager.add_cores(1)
	var screen: CanvasLayer = _add(RESULTS_SCENE)
	var grid: GridContainer = screen.stats_grid
	assert_eq(grid.columns, 2, "Two columns")
	var keys: Array[String] = []
	var values: Array[String] = []
	for i in grid.get_child_count():
		var label := grid.get_child(i) as Label
		if i % 2 == 0:
			keys.append(label.text)
		else:
			values.append(label.text)
			assert_eq(label.horizontal_alignment, HORIZONTAL_ALIGNMENT_RIGHT, "Values are right-aligned")
	assert_eq(keys, ["ZONES CLEARED", "TIME", "MAX COMBO", "LIVES LOST", "SCRAP", "CELLS", "CORES"] as Array[String])
	assert_eq(values, ["10 / 10", "2:05", "x17", "1", "42", "3", "1"] as Array[String])
	for label in keys:
		assert_false(label.contains("   "), "No space-padded strings")
	assert_eq(screen.rank_label.text, "RANK  S", "2 min with a life lost is still S")
	assert_false(screen.play_again_button.visible or screen.demo_thanks_label.visible, "No demo extras on a full run")

func test_q3_rank_letters() -> void:
	var rs = load("res://ui/menus/run_results_screen.gd")
	assert_eq(rs.rank_for(300.0, 2), "S", "Under 6 min -> S")
	assert_eq(rs.rank_for(400.0, 1), "A", "Under 9 min -> A")
	assert_eq(rs.rank_for(400.0, 0), "S", "...a deathless run climbs a tier")
	assert_eq(rs.rank_for(600.0, 3), "B")
	assert_eq(rs.rank_for(900.0, 3), "C")
	assert_eq(rs.rank_for(900.0, 0), "B", "Deathless C -> B")
	assert_eq(rs.format_time(61.9), "1:01")

func test_q3_demo_results_play_again_and_thanks() -> void:
	GameManager.start_new_run(true)
	var screen: CanvasLayer = _add(RESULTS_SCENE)
	screen.change_scene = _record
	assert_eq(screen.primary_button(), screen.play_again_button, "PLAY AGAIN is the demo's primary")
	assert_true(screen.demo_thanks_label.visible, "One thank-you line")
	assert_eq(screen.demo_thanks_label.text, "THANKS FOR PLAYING THE DEMO", "...with no CTA until the owner supplies one")
	assert_eq(String(screen.demo_thanks_label.theme_type_variation), "DimLabel")
	screen._on_play_again()
	assert_eq(_requested, [SLICE_SCENE] as Array[String], "PLAY AGAIN starts the slice again")
	assert_true(GameManager.demo_mode)

# --- Q4 ------------------------------------------------------------------------------

func _key_event(keycode: Key) -> InputEventKey:
	var ev := InputEventKey.new()
	ev.physical_keycode = keycode
	ev.keycode = keycode
	ev.pressed = true
	return ev

func test_q4_abandon_first_press_only_arms_the_confirm() -> void:
	GameManager.start_new_run()
	var menu: CanvasLayer = _add(PAUSE_SCENE)
	menu.change_scene = _record
	menu.toggle()
	menu._on_quit_pressed()
	assert_eq(_requested.size(), 0, "The first press does not call the seam")
	assert_false(GameManager.run_ended, "...nor abandon the run")
	assert_eq(menu.quit_button.text, "CONFIRM ABANDON?", "...it relabels the button")
	assert_true(menu.abandon_armed)
	menu._on_quit_pressed()
	assert_eq(_requested, [GameManager.SHOP_SCENE] as Array[String], "The second press abandons")
	assert_true(GameManager.run_ended)
	assert_eq(menu.quit_button.text, "ABANDON RUN", "...and the label is restored")

func test_q4_abandon_confirm_disarms_on_timeout_and_other_input() -> void:
	var menu: CanvasLayer = _add(PAUSE_SCENE)
	menu.change_scene = _record
	menu.abandon_confirm_seconds = 0.1
	menu.toggle()
	menu._on_quit_pressed()
	await _wait_real(0.2)
	assert_false(menu.abandon_armed, "The 2 s window (0.1 s here) times out")
	assert_eq(menu.quit_button.text, "ABANDON RUN", "...restoring the label")
	menu._on_quit_pressed()
	menu._input(_key_event(KEY_W))
	assert_false(menu.abandon_armed, "Any other key disarms it")
	menu._on_quit_pressed()
	menu._on_quit_pressed() # armed again, then confirmed
	assert_eq(_requested.size(), 1, "Only an armed second press abandons")

func test_q4_focus_loss_pause_holds_all_three_buttons() -> void:
	GameManager.run_ended = false
	var menu: CanvasLayer = _add(PAUSE_SCENE)
	menu.notification(Node.NOTIFICATION_APPLICATION_FOCUS_OUT)
	assert_true(menu.visible, "Focus loss opens the pause menu")
	for b in [menu.resume_button, menu.options_button, menu.quit_button]:
		assert_true(FocusGrace.is_held(b), "%s is held" % b.name)
	menu.quit_button.pressed.emit()
	assert_false(menu.abandon_armed, "A click inside the grace does nothing")
	await _wait_real(FocusGrace.FOCUS_LOSS_GRACE + 0.1)
	for b in [menu.resume_button, menu.options_button, menu.quit_button]:
		assert_false(FocusGrace.is_held(b), "%s released after 0.4 s" % b.name)
	assert_true(menu.resume_button.has_focus(), "Resume takes the focus")
	menu.toggle()
	menu.toggle()
	assert_false(FocusGrace.is_held(menu.options_button), "A normal pause holds only Resume")

func test_q4_profile_round_trips_the_accessibility_fields() -> void:
	var fresh := PlayerProfile.new()
	assert_eq([fresh.screen_shake, fresh.vcr_effects, fresh.reduce_flashes], [1.0, true, false], "Defaults")
	var original_path: String = SaveManager.save_path
	SaveManager.save_path = "user://test_q4_options.tres"
	SaveManager.profile = PlayerProfile.new()
	SaveManager.profile.screen_shake = 0.5
	SaveManager.profile.vcr_effects = false
	SaveManager.profile.reduce_flashes = true
	SaveManager.profile.seen_hints = 5
	SaveManager.save_profile()
	SaveManager.profile = null
	SaveManager.load_profile()
	var p: PlayerProfile = SaveManager.profile
	assert_eq([p.screen_shake, p.vcr_effects, p.reduce_flashes, p.seen_hints], [0.5, false, true, 5], "All four persist")
	assert_almost_eq(GameManager.shake_multiplier(), 0.5, 0.0001, "GameManager.shake_multiplier() reads it")
	assert_false(GameManager.vcr_enabled(), "vcr_enabled()")
	assert_true(GameManager.reduce_flashes(), "reduce_flashes()")
	DirAccess.remove_absolute(ProjectSettings.globalize_path(SaveManager.save_path))
	SaveManager.save_path = original_path

func test_q4_options_rows_exist_and_cycle() -> void:
	var om: Control = _add(OPTIONS_SCENE)
	assert_eq(String((om.get_node("Panel/VBox/Header") as Label).theme_type_variation), "HeadingLabel", "Header matches its siblings")
	var shake: Button = om.get_node("Panel/VBox/ShakeButton")
	var vcr: Button = om.get_node("Panel/VBox/VcrToggle")
	var flash: Button = om.get_node("Panel/VBox/FlashToggle")
	assert_eq(shake.text, "SCREEN SHAKE: 100%")
	shake.pressed.emit()
	assert_eq(SaveManager.profile.screen_shake, 0.0, "100 % -> OFF")
	assert_eq(shake.text, "SCREEN SHAKE: OFF")
	shake.pressed.emit()
	assert_eq(SaveManager.profile.screen_shake, 0.5, "OFF -> 50 %")
	om.cycle_shake(1)
	assert_eq(SaveManager.profile.screen_shake, 1.0, "50 % -> 100 %")
	assert_eq(vcr.text, "VCR EFFECTS: ON")
	vcr.button_pressed = false
	assert_false(SaveManager.profile.vcr_effects, "VCR toggle writes the profile")
	assert_eq(vcr.text, "VCR EFFECTS: OFF")
	flash.button_pressed = true
	assert_true(SaveManager.profile.reduce_flashes, "Reduce Flashes writes the profile")
	assert_eq(flash.text, "REDUCE FLASHES: ON")
	var back: Button = om.get_node("Panel/VBox/BackButton")
	assert_eq(om.get_node("Panel/VBox/FullscreenToggle").get_node(om.get_node("Panel/VBox/FullscreenToggle").focus_neighbor_bottom), shake, "Gamepad: FULLSCREEN -> SHAKE")
	var hud_size: Button = om.get_node("Panel/VBox/HudSizeButton")
	assert_eq(flash.get_node(flash.focus_neighbor_bottom), hud_size, "...-> REDUCE FLASHES -> HUD SIZE (V11)")
	assert_eq(hud_size.get_node(hud_size.focus_neighbor_bottom), back, "...-> HUD SIZE -> BACK")

func test_q4_theme_styles_the_sliders() -> void:
	var theme: Theme = load(THEME_PATH)
	for style in [&"slider", &"grabber_area", &"grabber_area_highlight"]:
		assert_true(theme.has_stylebox(style, &"HSlider"), "HSlider/%s" % style)
	var track := theme.get_stylebox(&"slider", &"HSlider") as StyleBoxFlat
	assert_almost_eq(track.content_margin_top + track.content_margin_bottom, 6.0, 0.01, "6 px track")
	for icon in [&"grabber", &"grabber_highlight"]:
		var tex: Texture2D = theme.get_icon(icon, &"HSlider")
		assert_eq(tex.get_size(), Vector2(18, 18), "%s is an 18x18 diamond" % icon)
		var img := tex.get_image()
		assert_lt(img.get_pixel(0, 0).a, 0.05, "...transparent in the corner")
		assert_gt(img.get_pixel(9, 9).a, 0.95, "...solid in the middle")

# --- Q5 ------------------------------------------------------------------------------

func test_q5_zone_tag_after_zone_entered() -> void:
	var p: PlayerProfile = SaveManager.profile
	p.booster_slots = 1
	p.equipped_run_boosters = ["Adrenaline"] as Array[String]
	GameManager.start_new_run()
	var hud: CanvasLayer = _add(HUD_SCENE)
	assert_false(hud.zone_tag.visible, "No tag before the first zone")
	SignalBus.zone_entered.emit(zone_3)
	assert_true(hud.zone_tag.visible)
	assert_eq(hud.zone_tag.text, "SECTOR 03 / 10 · ADRENALINE", "Sector of ten plus the run booster")
	assert_eq(String(hud.zone_tag.theme_type_variation), "DimLabel")
	assert_eq(hud.zone_tag.get_parent(), hud.cores_label.get_parent(), "...in the top-left column")
	assert_gt(hud.zone_tag.get_index(), hud.cores_label.get_index(), "...under CORES")
	p.equipped_run_boosters = [] as Array[String]
	GameManager.start_new_run()
	SignalBus.zone_entered.emit("SECTOR 10 " + String.chr(0x2014) + " HEADLINER STAGE")
	assert_eq(hud.zone_tag.text, "SECTOR 10 / 10", "No booster -> no suffix")

func test_q5_boss_spawned_plays_a_priority_card_then_the_bar() -> void:
	var hud: CanvasLayer = _add(HUD_SCENE)
	hud.boss_card_hold = 0.05
	SignalBus.boss_spawned.emit("Headliner")
	var card: Control = hud.zone_title_card
	assert_eq(card.label.text, "HEADLINER", "The card names the boss")
	assert_true(card.eyebrow_label.visible and card.eyebrow_label.text == "LIVE ON AIR", "...under a LIVE ON AIR eyebrow")
	assert_true(card._priority_active, "...as a priority card")
	assert_almost_eq(hud.boss_bar_container.modulate.a, 0.0, 0.01, "The boss bar waits for the card")
	SignalBus.zone_entered.emit(zone_3)
	assert_eq(card.label.text, "HEADLINER", "A zone entry cannot cut the boss card")
	await _wait_real(0.4 + 0.05 + 0.4 + 0.2)
	assert_true(hud.boss_bar_container.visible, "Then the bar is up")
	assert_almost_eq(hud.boss_bar_container.modulate.a, 1.0, 0.01, "...faded in")
	SignalBus.boss_died.emit()
	assert_false(hud.boss_bar_container.visible, "boss_died hides it")

# --- Q6 ------------------------------------------------------------------------------

func _hints() -> Control:
	SaveManager.profile.seen_controls = false
	return _add(HINTS_SCENE) as Control

func test_q6_a_chip_fades_on_its_action() -> void:
	GameManager.start_new_run()
	var hints := _hints()
	assert_true(hints.visible, "A fresh profile shows the strip")
	assert_eq(hints.get_child_count(), 5, "Five chips")
	assert_eq(hints.chip_text("dash"), "SHIFT/Q DASH")
	assert_eq(hints.chip_text("roll"), "CTRL/E ROLL")
	Input.action_press("jump")
	hints._process(0.016)
	Input.action_release("jump")
	assert_true(hints.is_fired("jump"), "The jump action fired the JUMP chip")
	assert_false(hints.is_fired("dash"), "...and only that chip")
	var guard := 0
	while guard < 120 and hints.chip("jump").visible:
		await get_tree().process_frame
		guard += 1
	assert_false(hints.chip("jump").visible, "The chip faded out (0.4 s)")
	assert_true(hints.chip("dash").visible, "The others stay")

func test_q6_chip_text_follows_the_last_device() -> void:
	var hints := _hints()
	var pad := InputEventJoypadButton.new()
	pad.button_index = JOY_BUTTON_A
	pad.pressed = true
	hints._input(pad)
	assert_true(hints.uses_gamepad_labels())
	assert_eq([hints.chip_text("attack_light"), hints.chip_text("attack_heavy"), hints.chip_text("jump"), hints.chip_text("dash"), hints.chip_text("roll")], ["X ATTACK", "Y HEAVY", "A JUMP", "RB DASH", "B ROLL"], "Gamepad labels")
	hints._input(_key_event(KEY_J))
	assert_eq(hints.chip_text("attack_light"), "J ATTACK", "A key press swaps back to keyboard labels")

func test_q6_every_chip_marks_the_controls_seen_but_a_demo_saves_nothing() -> void:
	var path: String = SaveManager.save_path
	if FileAccess.file_exists(path):
		DirAccess.remove_absolute(ProjectSettings.globalize_path(path))
	GameManager.start_new_run(true)
	var hints := _hints()
	for spec in hints.CHIPS:
		hints.fire(spec[0])
	assert_true(GameManager.controls_seen(), "Demo: the controls count as seen for the session")
	assert_false(SaveManager.profile.seen_controls, "...but the profile is untouched")
	var prompts: Node = load(ONBOARDING_SCRIPT).new()
	add_child(prompts)
	_nodes.append(prompts)
	SignalBus.hit_blocked.emit(Vector3.ZERO)
	assert_eq(SaveManager.profile.seen_hints, 0, "...and no hint bit reaches the profile")
	assert_false(FileAccess.file_exists(path), "Nothing was saved during the demo")
	var again := _add(HINTS_SCENE) as Control
	assert_false(again.visible, "The next HUD this session skips the strip")
	GameManager.set("_session_seen_controls", false)
	GameManager.start_new_run()
	var full := _hints()
	for spec in full.CHIPS:
		full.fire(spec[0])
	assert_true(SaveManager.profile.seen_controls, "A full run saves seen_controls")
	assert_true(FileAccess.file_exists(path), "...to disk")

func test_q6_one_shot_hints_fire_once() -> void:
	GameManager.start_new_run()
	var prompts: Node = load(ONBOARDING_SCRIPT).new()
	add_child(prompts)
	_nodes.append(prompts)
	var got := _collect_banners()
	SignalBus.hit_blocked.emit(Vector3.ZERO)
	SignalBus.hit_blocked.emit(Vector3.ZERO)
	assert_eq(got, ["SHIELDED — HEAVY HEAVY (K K) BREAKS THE GUARD"] as Array[String], "First blocked hit -> one SHIELDED hint")
	SignalBus.combo_increased.emit(2)
	assert_eq(got.size(), 1, "A 2-chain is not yet the TRI-CUT hint")
	SignalBus.combo_increased.emit(3)
	SignalBus.combo_increased.emit(3)
	SignalBus.run_started.emit()
	SignalBus.combo_increased.emit(4)
	assert_eq(got.size(), 2, "The chain hint fires once, not once per run")
	assert_eq(got[1], "CHAIN J J J = TRI-CUT")
	assert_eq(SaveManager.profile.seen_hints, prompts.HINT_SHIELD | prompts.HINT_CHAIN, "Both bits saved")
	if SignalBus.has_signal("enemy_telegraphed"):
		assert_true(SignalBus.is_connected("enemy_telegraphed", prompts._on_enemy_telegraphed), "The telegraph hint listens when the signal exists")
	prompts._on_enemy_telegraphed()
	prompts._on_enemy_telegraphed()
	assert_eq(got.size(), 3, "The telegraph hint fires once")
	assert_eq(got[2], "WHITE RIM = HIT INCOMING — DODGE")

# --- Q7 ------------------------------------------------------------------------------

func test_q7_transition_reaches_the_target_scene_in_headless() -> void:
	assert_true(SceneTransition.is_instant(get_tree()), "--headless skips the fade")
	var tree := get_tree()
	var keep: Node = tree.current_scene
	var temp := Node3D.new()
	tree.root.add_child(temp)
	tree.current_scene = temp
	SceneTransition.go(tree, OPTIONS_SCENE)
	await tree.process_frame
	await tree.process_frame
	var reached: Node = tree.current_scene
	assert_not_null(reached, "A scene is current")
	if reached:
		assert_eq(reached.scene_file_path, OPTIONS_SCENE, "SceneTransition.go reached the target")
		assert_false(tree.root.get_children().any(func(n): return n.get_script() == SceneTransition), "No cover layer left behind")
		reached.queue_free()
	tree.current_scene = keep
	await tree.process_frame

func test_q7_every_seam_defaults_to_the_transition() -> void:
	for path in ["res://ui/menus/title_screen.gd", "res://ui/menus/demo_loadout.gd", "res://ui/shop/karens_shop.gd", "res://ui/menus/pause_menu.gd", "res://ui/menus/game_over_screen.gd", "res://ui/menus/run_results_screen.gd", "res://_core/game_manager.gd"]:
		var text := FileAccess.get_file_as_string(path)
		assert_false(text.contains("change_scene_to_file"), "%s no longer calls change_scene_to_file" % path)
		assert_true(text.contains("SceneTransition.go("), "%s routes through SceneTransition" % path)
	var screen: CanvasLayer = _add(GAME_OVER_SCENE)
	screen.change_scene = _record
	FocusGrace.release(screen.return_button)
	screen.return_button.pressed.emit()
	assert_eq(_requested, [GameManager.post_run_scene()] as Array[String], "The seam still receives the path")

# --- Q8 ------------------------------------------------------------------------------

func test_q8_vitals_cluster_and_ability_segments() -> void:
	var hud: CanvasLayer = _add(HUD_SCENE)
	var bar: Control = hud.get_node("SafeArea/MarginContainer/VBoxContainer/LowerRow/AbilityBar")
	assert_eq(bar.segments.get_child_count(), 10, "10 HudSegment cells")
	assert_eq(bar.segments.get_child_count(), bar.SEGMENTS)
	assert_almost_eq(hud.battery_bar.get_parent().custom_minimum_size.x, 360.0, 0.01, "The battery spans ~360 px")
	assert_eq(hud.battery_segments.get_child_count(), 12, "...still 12 cells")
	assert_true(hud.get_node("SafeArea") is MarginContainer, "The corners live in a MarginContainer")

func test_q8_vignette_alpha_follows_hp() -> void:
	SaveManager.profile.reduce_flashes = false
	var hud: CanvasLayer = _add(HUD_SCENE)
	SignalBus.player_health_changed.emit(120.0, 120.0)
	assert_eq(hud.vignette_alpha(), 0.0, "Full HP -> no vignette")
	assert_false(hud.low_hp_vignette.visible, "...hidden")
	SignalBus.player_health_changed.emit(24.0, 120.0)
	assert_gt(hud.vignette_alpha(), 0.0, "20 % HP -> the vignette shows")
	assert_true(hud.low_hp_vignette.visible)
	assert_almost_eq(hud.vignette_alpha(), 1.0 - smoothstep(0.1, 0.35, 0.2), 0.0001, "alpha = smoothstep(0.35, 0.1, ratio)")
	assert_true(hud.low_hp_vignette.get_index() < hud.get_node("SafeArea").get_index(), "Drawn under the HUD widgets")
	SaveManager.profile.reduce_flashes = true
	SignalBus.player_health_changed.emit(24.0, 120.0)
	assert_eq(hud.vignette_alpha(), 0.0, "Reduce Flashes turns it off")
	assert_false(hud.low_hp_vignette.visible)

func test_q8_safe_area_clamps_to_16_9() -> void:
	var hud: CanvasLayer = _add(HUD_SCENE)
	var safe: MarginContainer = hud.safe_area
	var size: Vector2 = hud.get_viewport().get_visible_rect().size
	var expected_x := 20.0
	if size.x / size.y > 16.0 / 9.0:
		expected_x += (size.x - size.y * 16.0 / 9.0) / 2.0
	assert_eq(safe.get_theme_constant("margin_left"), roundi(expected_x), "Left margin = 20 px + any letterbox beyond 16:9")
	assert_eq(safe.get_theme_constant("margin_right"), safe.get_theme_constant("margin_left"), "Symmetric")
