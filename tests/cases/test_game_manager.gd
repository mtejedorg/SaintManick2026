extends "res://tests/framework/test_case.gd"

var original_max_hp_upgrades: int
var original_max_lives_upgrades: int
var original_shield_upgrades: int
var original_persistent_scrap: int

func before_each() -> void:
	# Backup original profile state if it exists
	if SaveManager and SaveManager.profile:
		original_max_hp_upgrades = SaveManager.profile.max_hp_upgrades
		original_max_lives_upgrades = SaveManager.profile.max_lives_upgrades
		original_shield_upgrades = SaveManager.profile.shield_upgrades
		original_persistent_scrap = SaveManager.profile.persistent_scrap
	
	GameManager.is_test = true

func after_each() -> void:
	# Restore original profile state
	if SaveManager and SaveManager.profile:
		SaveManager.profile.max_hp_upgrades = original_max_hp_upgrades
		SaveManager.profile.max_lives_upgrades = original_max_lives_upgrades
		SaveManager.profile.shield_upgrades = original_shield_upgrades
		SaveManager.profile.persistent_scrap = original_persistent_scrap
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
	SaveManager.profile.persistent_scrap = 50
	
	var spend_success = GameManager.spend_scrap(30)
	assert_true(spend_success, "Should succeed spending scrap when balance is sufficient")
	assert_eq(SaveManager.profile.persistent_scrap, 20, "Persistent scrap should decrease")
	
	spend_success = GameManager.spend_scrap(30)
	assert_false(spend_success, "Should fail spending scrap when balance is insufficient")
	assert_eq(SaveManager.profile.persistent_scrap, 20, "Persistent scrap should not change on failure")

func test_respawn_or_game_over_flow() -> void:
	if not SaveManager or not SaveManager.profile:
		_fail("SaveManager profile not available")
		return
		
	SaveManager.profile.max_hp_upgrades = 0
	SaveManager.profile.max_lives_upgrades = 0
	SaveManager.profile.shield_upgrades = 0
	SaveManager.profile.persistent_scrap = 10
	
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
	assert_eq(SaveManager.profile.persistent_scrap, 25, "Run scrap (15) should transfer to persistent scrap (10 + 15 = 25) on game over")
