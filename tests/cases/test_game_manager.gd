extends "res://tests/framework/test_case.gd"

var original_max_hp_upgrades: int
var original_max_lives_upgrades: int
var original_shield_upgrades: int
var original_scrap: int

func before_each() -> void:
	# Backup original profile state if it exists
	if SaveManager and SaveManager.profile:
		original_max_hp_upgrades = SaveManager.profile.max_hp_upgrades
		original_max_lives_upgrades = SaveManager.profile.max_lives_upgrades
		original_shield_upgrades = SaveManager.profile.shield_upgrades
		original_scrap = SaveManager.profile.scrap
	
	GameManager.is_test = true

func after_each() -> void:
	# Restore original profile state
	if SaveManager and SaveManager.profile:
		SaveManager.profile.max_hp_upgrades = original_max_hp_upgrades
		SaveManager.profile.max_lives_upgrades = original_max_lives_upgrades
		SaveManager.profile.shield_upgrades = original_shield_upgrades
		SaveManager.profile.scrap = original_scrap
		SaveManager.save_profile()

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

