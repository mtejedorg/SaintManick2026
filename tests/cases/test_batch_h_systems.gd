extends "res://tests/framework/test_case.gd"

# H4: tempo rests at the Conductor resting tempo (and a boss fight starts there), elevator
# boarding rail-locks Nick at once, an unreadable save is backed up (and saves are atomic),
# the telegraph rim holds through its beat, and the Headliner phase 2 cues a banner.

const RUNNER_SCENE := "res://characters/enemies/runner/runner.tscn"
const HEADLINER_SCENE := "res://characters/enemies/headliner/headliner.tscn"
const VISUAL_SCENE := "res://characters/shared/character_visual.tscn"
const CORRUPT_SAVE := "user://test_h4_corrupt_save.tres"

func _reconnect_intensity(ic: IntensityController) -> void:
	# The framework after_each() drops every SignalBus connection (see test_grunt_dormancy).
	if not SignalBus.beat.is_connected(ic._on_beat):
		SignalBus.beat.connect(ic._on_beat)
	if not SignalBus.boss_reset.is_connected(ic._on_boss_reset):
		SignalBus.boss_reset.connect(ic._on_boss_reset)
	if not SignalBus.boss_spawned.is_connected(ic._on_boss_spawned):
		SignalBus.boss_spawned.connect(ic._on_boss_spawned)

func test_tempo_rests_at_the_conductor_resting_bpm_and_bosses_start_there() -> void:
	await get_tree().process_frame # flush grunts other suites queue_free()d
	var ic: IntensityController = Conductor.intensity_controller
	_reconnect_intensity(ic)
	var saved_rest: float = Conductor._resting_bpm
	var saved_target: float = Conductor.target_bpm
	Conductor._resting_bpm = 140.0
	ic._boss_active = true

	SignalBus.boss_reset.emit()
	SignalBus.beat.emit("primary", 1)
	assert_eq(ic.get_active_enemy_count(), 0, "No stray active enemies in the tree")
	assert_eq(Conductor.target_bpm, 140.0, "The world rests at the Conductor resting tempo, not a hard-coded 128")

	var runners: Array[Node] = []
	for i in 3:
		var runner: RunnerEnemy = load(RUNNER_SCENE).instantiate()
		runner.position = Vector3(float(i) * 3.0, 50.0, 8300.0)
		add_child(runner)
		runner.set_physics_process(false)
		runner.is_active = true
		runners.append(runner)
	SignalBus.beat.emit("primary", 2)
	assert_eq(Conductor.target_bpm, 140.0 + 3.0 * ic.per_enemy_boost, "Three active grunts push the tempo")
	SignalBus.boss_spawned.emit("Enforcer")
	assert_eq(Conductor.target_bpm, 140.0, "A boss fight starts at the resting tempo")
	SignalBus.beat.emit("primary", 3)
	assert_eq(Conductor.target_bpm, 140.0, "...and the boss lock keeps it there")

	for r in runners:
		r.free()
	ic._boss_active = false
	Conductor._resting_bpm = saved_rest
	Conductor.target_bpm = saved_target

func test_boarding_the_elevator_rail_locks_nick_immediately() -> void:
	var trigger := Area3D.new()
	var shaft := Path3D.new()
	shaft.curve = Curve3D.new()
	shaft.curve.add_point(Vector3(0.0, 0.0, 8320.0))
	shaft.curve.add_point(Vector3(0.0, 20.0, 8320.0))
	var elevator := ElevatorEncounter.new()
	elevator.entry_trigger = trigger
	elevator.target_path = shaft
	add_child(trigger)
	add_child(shaft)
	add_child(elevator)
	var player: PlayerController = load("res://characters/player/player.tscn").instantiate()
	player.position = Vector3(0.0, 50.0, 8320.0)
	add_child(player)
	player.set_physics_process(false)
	player.current_path = null

	elevator._on_entry_trigger_entered(player)
	assert_eq(player.current_path, shaft, "Nick is on the shaft rail before any frame passes")

	# free() synchronously so the deferred start_encounter never runs on the stub.
	elevator.free()
	player.free()
	shaft.free()
	trigger.free()

func _remove_user_file(path: String) -> void:
	if FileAccess.file_exists(path):
		DirAccess.remove_absolute(ProjectSettings.globalize_path(path))

func test_unreadable_profile_is_backed_up_and_replaced_by_a_fresh_one() -> void:
	var saved_path: String = SaveManager.save_path
	var saved_profile: PlayerProfile = SaveManager.profile
	SaveManager.save_path = CORRUPT_SAVE
	var bak: String = SaveManager.backup_path()
	var tmp: String = SaveManager.temp_path()
	for p in [CORRUPT_SAVE, bak, tmp]:
		_remove_user_file(p)
	var garbage := "this is not a resource {{{ \n"
	var file := FileAccess.open(CORRUPT_SAVE, FileAccess.WRITE)
	file.store_string(garbage)
	file.close()

	SaveManager.profile = null
	SaveManager.load_profile()

	assert_true(FileAccess.file_exists(bak), "The unreadable profile is copied to %s first" % bak)
	assert_eq(FileAccess.get_file_as_string(bak), garbage, "...byte for byte")
	assert_not_null(SaveManager.profile, "A fresh profile takes over")
	assert_eq(SaveManager.profile.scrap, 0, "...a fresh one")
	assert_false(FileAccess.file_exists(tmp), "The atomic save left no temp file behind")
	assert_true(ResourceLoader.load(CORRUPT_SAVE, "", ResourceLoader.CACHE_MODE_IGNORE) is PlayerProfile, "The fresh profile was written over the broken file")

	for p in [CORRUPT_SAVE, bak, tmp]:
		_remove_user_file(p)
	SaveManager.save_path = saved_path
	SaveManager.profile = saved_profile

func test_save_profile_round_trips_through_the_temp_file() -> void:
	var saved_path: String = SaveManager.save_path
	var saved_profile: PlayerProfile = SaveManager.profile
	SaveManager.save_path = CORRUPT_SAVE
	_remove_user_file(CORRUPT_SAVE)
	SaveManager.profile = PlayerProfile.new()
	SaveManager.profile.scrap = 77
	SaveManager.save_profile()
	SaveManager.profile.scrap = 78
	SaveManager.save_profile() # second save renames over an existing file
	var loaded := ResourceLoader.load(CORRUPT_SAVE, "", ResourceLoader.CACHE_MODE_IGNORE) as PlayerProfile
	assert_not_null(loaded, "The saved profile loads")
	assert_eq(loaded.scrap if loaded else -1, 78, "...with the latest value")
	assert_false(FileAccess.file_exists(SaveManager.temp_path()), "No temp file is left behind")
	_remove_user_file(CORRUPT_SAVE)
	SaveManager.save_path = saved_path
	SaveManager.profile = saved_profile

func test_telegraph_rim_holds_through_its_beat() -> void:
	var visual: CharacterVisual = load(VISUAL_SCENE).instantiate()
	add_child(visual)
	var saved_bpm: float = Conductor.bpm
	var saved_target: float = Conductor.target_bpm
	Conductor.bpm = 30.0 # a 2 s beat so frame jitter cannot blur the hold/fade boundary
	Conductor.target_bpm = 30.0
	visual.flash_telegraph()
	await get_tree().create_timer(2.0 * 0.85, false).timeout
	var strength := visual.get_current_rim_strength()
	Conductor.bpm = saved_bpm
	Conductor.target_bpm = saved_target
	assert_true(strength >= 0.9 * CharacterVisual.TELEGRAPH_RIM_STRENGTH, "85 %% into the beat the telegraph rim is still >= 90 %% (%.2f)" % strength)
	visual.queue_free()

func test_flash_rim_default_hold_is_still_half() -> void:
	var visual: CharacterVisual = load(VISUAL_SCENE).instantiate()
	visual.rim_strength = 3.0
	add_child(visual)
	visual.flash_rim(Color.WHITE, 6.0, 1.0)
	await get_tree().create_timer(0.8, false).timeout
	assert_lt(visual.get_current_rim_strength(), 5.0, "Plain flashes keep the old half hold / half fade")
	visual.queue_free()

func test_bullet_hell_cues_its_banners_and_heats_the_bubble() -> void:
	var boss: HeadlinerBoss = load(HEADLINER_SCENE).instantiate()
	boss.position = Vector3(0.0, 50.0, 8340.0)
	add_child(boss)
	boss.set_physics_process(false)
	boss.activate_boss()
	var banners: Array = []
	var on_banner := func(text: String, hold: float): banners.append([text, hold])
	SignalBus.banner_requested.connect(on_banner)

	boss.phase_2_triggered = true
	boss.state_machine.transition_to("StateBulletHell")
	var bh = boss.state_machine.current_state
	assert_eq(String(bh.name), "StateBulletHell")
	assert_eq(banners.size(), 1, "Entering the bullet hell requests exactly one banner")
	assert_eq(banners[0][0], "PROJECTION STORM — SURVIVE")
	assert_almost_eq(banners[0][1], 2.0, 0.001, "...held 2 s")

	var mat := boss.shield_bubble.get_active_material(0) as StandardMaterial3D
	var start_albedo: Color = mat.albedo_color
	var half: int = int(bh.max_beats * 0.5)
	for i in half:
		bh.on_beat("primary", (i % 4) + 1)
	var mid_albedo: Color = (boss.shield_bubble.get_active_material(0) as StandardMaterial3D).albedo_color
	assert_gt(mid_albedo.r + mid_albedo.g + mid_albedo.b, start_albedo.r + start_albedo.g + start_albedo.b + 0.3, "The bubble heats toward white as the overheat nears")
	for i in range(half, bh.max_beats):
		bh.on_beat("primary", (i % 4) + 1)
	assert_eq(String(boss.state_machine.current_state.name), "StateEnraged", "Overheated")
	assert_eq(banners.size(), 2, "The overheat requests one more banner")
	assert_eq(banners[1][0], "SHIELD DOWN")
	assert_almost_eq(banners[1][1], 1.0, 0.001, "...held 1 s")
	SignalBus.banner_requested.disconnect(on_banner)
	boss.queue_free()
