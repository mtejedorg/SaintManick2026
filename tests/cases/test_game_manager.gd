extends "res://tests/framework/test_case.gd"

var original_max_hp_upgrades: int
var original_max_lives_upgrades: int
var original_shield_upgrades: int
var original_scrap: int
var original_cells: int
var original_cores: int
var original_boosters: Array[String] = []

func before_each() -> void:
	# Backup original profile state if it exists
	if SaveManager and SaveManager.profile:
		original_max_hp_upgrades = SaveManager.profile.max_hp_upgrades
		original_max_lives_upgrades = SaveManager.profile.max_lives_upgrades
		original_shield_upgrades = SaveManager.profile.shield_upgrades
		original_scrap = SaveManager.profile.scrap
		original_cells = SaveManager.profile.cells
		original_cores = SaveManager.profile.cores
		original_boosters = SaveManager.profile.equipped_run_boosters.duplicate()
		# Isolate from whatever boosters the local save has equipped.
		SaveManager.profile.equipped_run_boosters.clear()

	GameManager.is_test = true

func after_each() -> void:
	# Restore original profile state
	if SaveManager and SaveManager.profile:
		SaveManager.profile.max_hp_upgrades = original_max_hp_upgrades
		SaveManager.profile.max_lives_upgrades = original_max_lives_upgrades
		SaveManager.profile.shield_upgrades = original_shield_upgrades
		SaveManager.profile.scrap = original_scrap
		SaveManager.profile.cells = original_cells
		SaveManager.profile.cores = original_cores
		SaveManager.profile.equipped_run_boosters = original_boosters
		SaveManager.save_profile()
	GameManager.start_new_run() # don't leak booster modifiers into later tests

func test_start_new_run_resets_and_applies_upgrades() -> void:
	if not SaveManager or not SaveManager.profile:
		_fail("SaveManager profile not available")
		return
		
	# Configure upgrades
	SaveManager.profile.max_hp_upgrades = 2     # +40HP (160 total)
	SaveManager.profile.max_lives_upgrades = 1  # +1 Life (4 total)
	SaveManager.profile.shield_upgrades = 3     # +30 Shield (70 total)
	
	GameManager.start_new_run()
	
	assert_eq(GameManager.max_hp, 160.0, "Max HP should scale with upgrades")
	assert_eq(GameManager.max_lives, 4, "Max Lives should scale with upgrades")
	assert_eq(GameManager.max_shield, 70.0, "Max Shield should scale with upgrades")
	
	assert_eq(GameManager.current_hp, 160.0, "Current HP should reset to max")
	assert_eq(GameManager.current_lives, 4, "Current Lives should reset to max")
	assert_eq(GameManager.current_shield, 70.0, "Current Shield should reset to max")
	assert_eq(GameManager.scrap, 0, "Run scrap should reset to 0")

func test_scrap_modification_and_spending() -> void:
	if not SaveManager or not SaveManager.profile:
		_fail("SaveManager profile not available")
		return
		
	# Test volatile run scrap
	GameManager.scrap = 0
	GameManager.add_scrap(25)
	assert_eq(GameManager.scrap, 25, "Add scrap should increase volatile run scrap")
	
	# Test persistent scrap spending
	SaveManager.profile.scrap = 50
	
	var success = GameManager.spend_scrap(30)
	assert_true(success, "Should successfully spend scrap")
	assert_eq(SaveManager.profile.scrap, 20, "Persistent scrap should decrease")
	
	var fail = GameManager.spend_scrap(30)
	assert_false(fail, "Should fail when not enough scrap")
	assert_eq(SaveManager.profile.scrap, 20, "Persistent scrap should not change on failure")

func test_respawn_or_game_over_flow() -> void:
	if not SaveManager or not SaveManager.profile:
		_fail("SaveManager profile not available")
		return
		
	SaveManager.profile.max_hp_upgrades = 0
	SaveManager.profile.max_lives_upgrades = 0
	SaveManager.profile.shield_upgrades = 0
	SaveManager.profile.scrap = 10
	
	GameManager.start_new_run() # 3 lives, 120 HP, 40 Shield, 0 scrap
	GameManager.scrap = 15 # Gather some run scrap
	
	# Lower HP/shield to verify they reload
	GameManager.current_hp = 30.0
	GameManager.current_shield = 0.0
	
	# Trigger first respawn
	GameManager.respawn_or_game_over()
	
	assert_eq(GameManager.current_lives, 2, "Lives should decrement by 1")
	assert_eq(GameManager.current_hp, 120.0, "HP should reset to max on respawn")
	assert_eq(GameManager.current_shield, 40.0, "Shield should reset to max on respawn")
	
	# Trigger second respawn
	GameManager.current_hp = 10.0
	GameManager.respawn_or_game_over()
	assert_eq(GameManager.current_lives, 1, "Lives should decrement to 1")
	
	# GDD §5: "permadeath only when HP hits 0 with 0 lives remaining" — three lives mean
	# three respawns. The third death spends the last life but still respawns...
	GameManager.respawn_or_game_over()
	assert_eq(GameManager.current_lives, 0, "Third death spends the last life")
	assert_eq(GameManager.current_hp, 120.0, "Third death still respawns with a full HP refill")
	assert_eq(SaveManager.profile.scrap, 10, "No banking yet — the run is still alive on 0 lives")
	assert_false(GameManager.run_ended, "The run must not end while Nick respawned on his last life")
	
	# ...and only the fourth death (0 lives remaining) is game over.
	GameManager.respawn_or_game_over()
	assert_eq(GameManager.current_lives, 0, "Lives stay at 0 on game over")
	assert_true(GameManager.run_ended, "Fourth death with 0 lives remaining is game over")
	assert_eq(SaveManager.profile.scrap, 25, "Run scrap (15) should transfer to persistent scrap (10 + 15 = 25) on game over")

func test_enemies_and_zones_tracking() -> void:
	# Reconnect signals since the test framework's after_each() disconnects all SignalBus connections
	if not SignalBus.enemy_died.is_connected(GameManager._on_enemy_died):
		SignalBus.enemy_died.connect(GameManager._on_enemy_died)
	if not SignalBus.zone_entered.is_connected(GameManager._on_zone_entered):
		SignalBus.zone_entered.connect(GameManager._on_zone_entered)

	GameManager.start_new_run()
	assert_eq(GameManager.enemies_defeated, 0, "enemies_defeated should start at 0")
	assert_eq(GameManager.zones_cleared, 0, "zones_cleared should start at 0")

	# Emit signals
	SignalBus.enemy_died.emit(Vector3.ZERO)
	assert_eq(GameManager.enemies_defeated, 1, "enemies_defeated should increment on enemy_died")

	SignalBus.zone_entered.emit("Zone 1")
	assert_eq(GameManager.zones_cleared, 1, "zones_cleared should increment on zone_entered")

	# Start new run should reset
	GameManager.start_new_run()
	assert_eq(GameManager.enemies_defeated, 0, "enemies_defeated should reset to 0 on new run")
	assert_eq(GameManager.zones_cleared, 0, "zones_cleared should reset to 0 on new run")

func test_cells_and_cores_accumulate_and_reset() -> void:
	GameManager.start_new_run()
	assert_eq(GameManager.cells, 0, "cells should start at 0")
	assert_eq(GameManager.cores, 0, "cores should start at 0")

	GameManager.add_cells(15) # e.g. Enforcer kill
	GameManager.add_cells(10) # e.g. Zone 8 escape completion
	assert_eq(GameManager.cells, 25, "cells should accumulate across sources")

	GameManager.add_cores(1) # e.g. Headliner kill
	assert_eq(GameManager.cores, 1, "cores should accumulate")

	GameManager.start_new_run()
	assert_eq(GameManager.cells, 0, "cells should reset to 0 on new run")
	assert_eq(GameManager.cores, 0, "cores should reset to 0 on new run")

func test_full_clear_banks_scrap_cells_and_cores() -> void:
	# M7b acceptance: a full clear banks scrap + cells + 1 core into the persistent profile.
	if not SaveManager or not SaveManager.profile:
		_fail("SaveManager profile not available")
		return

	SaveManager.profile.scrap = 0
	SaveManager.profile.cells = 0
	SaveManager.profile.cores = 0

	GameManager.start_new_run()
	GameManager.add_scrap(40)   # grunt kills
	GameManager.add_cells(15)   # Enforcer kill
	GameManager.add_cells(10)   # Zone 8 escape
	GameManager.add_cells(10)   # Zone 9 elevator
	GameManager.add_cores(1)    # Headliner kill

	GameManager.complete_run()

	assert_eq(SaveManager.profile.scrap, 40, "Run scrap should transfer to persistent scrap on full clear")
	assert_eq(SaveManager.profile.cells, 35, "Run cells should transfer to persistent cells on full clear")
	assert_eq(SaveManager.profile.cores, 1, "Run cores should transfer to persistent cores on full clear")

func test_cells_and_cores_transfer_on_game_over_too() -> void:
	if not SaveManager or not SaveManager.profile:
		_fail("SaveManager profile not available")
		return

	SaveManager.profile.scrap = 0
	SaveManager.profile.cells = 0
	SaveManager.profile.cores = 0
	SaveManager.profile.max_lives_upgrades = 0

	GameManager.start_new_run() # 3 lives
	GameManager.add_cells(15)
	GameManager.add_cores(1)

	GameManager.respawn_or_game_over() # lives 3 -> 2
	GameManager.respawn_or_game_over() # lives 2 -> 1
	GameManager.respawn_or_game_over() # lives 1 -> 0, still respawns (GDD §5)
	GameManager.respawn_or_game_over() # 0 lives remaining -> game over, transfers to profile

	assert_eq(SaveManager.profile.cells, 15, "Cells should transfer to profile on game over, not just full clear")
	assert_eq(SaveManager.profile.cores, 1, "Cores should transfer to profile on game over, not just full clear")


func test_tempo_shield_booster_is_an_overshield() -> void:
	if not SaveManager or not SaveManager.profile:
		_fail("SaveManager profile not available")
		return

	SaveManager.profile.shield_upgrades = 0
	SaveManager.profile.equipped_run_boosters = ["Tempo Shield"]

	GameManager.start_new_run()

	assert_eq(GameManager.max_shield, 60.0, "Tempo Shield should raise max shield by 50% (40 -> 60)")
	assert_eq(GameManager.current_shield, 60.0, "Run should start with the overshield full")

func test_every_distinct_equipped_booster_applies() -> void:
	if not SaveManager or not SaveManager.profile:
		_fail("SaveManager profile not available")
		return

	var original_slots: int = SaveManager.profile.booster_slots
	SaveManager.profile.shield_upgrades = 0
	SaveManager.profile.booster_slots = 2
	SaveManager.profile.equipped_run_boosters = ["Tempo Shield", "Scrap Magnet"]

	GameManager.start_new_run()

	assert_eq(GameManager.max_shield, 60.0, "Slot 1 Tempo Shield should apply")
	assert_eq(GameManager.scrap_multiplier, 2, "Slot 2 Scrap Magnet should apply")
	assert_eq(GameManager.run_speed_multiplier, 1.0, "Unequipped Adrenaline should not apply")

	# Boosters beyond booster_slots are trimmed, never applied.
	SaveManager.profile.booster_slots = 1
	GameManager.start_new_run()
	assert_eq(GameManager.max_shield, 60.0, "Slot 1 booster still applies with one slot")
	assert_eq(GameManager.scrap_multiplier, 1, "A booster past booster_slots should not apply")

	SaveManager.profile.booster_slots = original_slots

func test_abandon_run_banks_currencies_and_clears_run_state() -> void:
	if not SaveManager or not SaveManager.profile:
		_fail("SaveManager profile not available")
		return

	SaveManager.profile.scrap = 10
	SaveManager.profile.cells = 0
	SaveManager.profile.cores = 0

	GameManager.start_new_run()
	GameManager.scrap = 50
	GameManager.cells = 5
	GameManager.cores = 1

	GameManager.abandon_run()

	assert_eq(SaveManager.profile.scrap, 60, "Abandon should bank the run's 50 scrap (10 + 50)")
	assert_eq(SaveManager.profile.cells, 5, "Abandon should bank the run's cells")
	assert_eq(SaveManager.profile.cores, 1, "Abandon should bank the run's cores")
	assert_eq(GameManager.scrap, 0, "Run scrap should be cleared after abandoning")
	assert_eq(GameManager.cells, 0, "Run cells should be cleared after abandoning")
	assert_eq(GameManager.cores, 0, "Run cores should be cleared after abandoning")

func test_complete_run_twice_banks_once() -> void:
	# D1: a second terminal event in the same run (e.g. a last-life death inside the
	# Headliner's victory hold) must not bank the run a second time.
	if not SaveManager or not SaveManager.profile:
		_fail("SaveManager profile not available")
		return

	SaveManager.profile.scrap = 0
	GameManager.start_new_run()
	GameManager.add_scrap(30)

	GameManager.complete_run()
	GameManager.complete_run()
	assert_eq(SaveManager.profile.scrap, 30, "complete_run twice should bank the run's scrap once")

	# A game over after the run already completed must not bank again either.
	GameManager.current_lives = 0
	GameManager.respawn_or_game_over()
	assert_eq(SaveManager.profile.scrap, 30, "A game over after complete_run should not bank again")

	GameManager.start_new_run()
	assert_false(GameManager.run_ended, "start_new_run should clear run_ended")

func test_start_new_run_resets_tempo_boss_audio_and_checkpoint_state() -> void:
	# D4: a game over/abandon mid-boss must not leak 160 BPM, the IntensityController boss
	# lock, AudioManager's boss-music flag or the old checkpoint into the next run.
	# The framework disconnects every SignalBus connection between tests — reconnect.
	var ic: IntensityController = Conductor.intensity_controller
	var handlers: Array[Callable] = [Conductor._on_run_started, ic._on_run_started, AudioManager._on_run_started]
	for h in handlers:
		if not SignalBus.run_started.is_connected(h):
			SignalBus.run_started.connect(h)

	var saved_bpm: float = Conductor.bpm
	Conductor.bpm = 160.0
	Conductor.target_bpm = 160.0
	Conductor.layers["primary"].beat_index = 37
	Conductor.layers["primary"].measure_index = 9
	ic._boss_active = true
	AudioManager._boss_music_active = true
	AudioManager._current_music = "zone_corporate"
	GameManager.has_checkpoint = true
	GameManager.checkpoint_zone = "SECTOR 10 — HEADLINER"
	GameManager.checkpoint_position = Vector3(365.0, 15.0, 0.0)
	GameManager.checkpoint_top_down = true

	GameManager.start_new_run()

	assert_eq(Conductor.bpm, 128.0, "Conductor bpm should return to the resting tempo")
	assert_eq(Conductor.target_bpm, 128.0, "Conductor target_bpm should return to the resting tempo")
	assert_eq(Conductor.layers["primary"].beat_index, 0, "Primary layer beat counter should reset")
	assert_eq(Conductor.layers["primary"].measure_index, 0, "Primary layer measure counter should reset")
	assert_false(ic._boss_active, "IntensityController boss lock should clear")
	assert_false(AudioManager._boss_music_active, "AudioManager boss-music flag should clear")
	assert_eq(AudioManager._current_music, "", "AudioManager should forget the last track")
	assert_false(GameManager.has_checkpoint, "Checkpoint should clear on a new run")
	assert_eq(GameManager.checkpoint_zone, "", "Checkpoint zone should clear")
	assert_eq(GameManager.checkpoint_position, Vector3.ZERO, "Checkpoint position should clear")
	assert_null(GameManager.checkpoint_path, "Checkpoint rail should clear")
	assert_false(GameManager.checkpoint_top_down, "Checkpoint camera mode should clear")

	for h in handlers:
		if SignalBus.run_started.is_connected(h):
			SignalBus.run_started.disconnect(h)
	Conductor.bpm = saved_bpm
	Conductor.target_bpm = saved_bpm
