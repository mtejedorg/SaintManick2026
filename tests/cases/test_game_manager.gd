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
	
	# Trigger third respawn (dies, triggers game over)
	GameManager.respawn_or_game_over()
	assert_eq(GameManager.current_lives, 0, "Lives should decrement to 0 on game over")
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
	GameManager.respawn_or_game_over() # lives 1 -> 0, game over, transfers to profile

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
