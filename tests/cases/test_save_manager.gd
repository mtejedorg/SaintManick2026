extends "res://tests/framework/test_case.gd"

var original_save_path: String
var original_profile: PlayerProfile

func before_each() -> void:
	if SaveManager:
		original_save_path = SaveManager.save_path
		original_profile = SaveManager.profile
		SaveManager.save_path = "user://test_save_manager_case.tres"
		
		# Ensure test file doesn't exist initially
		var dir = DirAccess.open("user://")
		if dir and dir.file_exists("test_save_manager_case.tres"):
			dir.remove("test_save_manager_case.tres")
		SaveManager.profile = null

func after_each() -> void:
	if SaveManager:
		var dir = DirAccess.open("user://")
		if dir and dir.file_exists("test_save_manager_case.tres"):
			dir.remove("test_save_manager_case.tres")
		SaveManager.save_path = original_save_path
		SaveManager.profile = original_profile

func test_fallback_to_default_profile_when_missing() -> void:
	SaveManager.load_profile()
	
	assert_not_null(SaveManager.profile, "Profile should fallback to a new profile if missing")
	assert_eq(SaveManager.profile.persistent_scrap, 0, "Default scrap should be 0")
	assert_eq(SaveManager.profile.max_hp_upgrades, 0, "Default hp upgrades should be 0")
	assert_eq(SaveManager.profile.max_lives_upgrades, 0, "Default lives upgrades should be 0")
	assert_eq(SaveManager.profile.shield_upgrades, 0, "Default shield upgrades should be 0")

func test_save_and_load_profile() -> void:
	# Initialize default profile
	SaveManager.load_profile()
	
	# Modify profile
	SaveManager.profile.persistent_scrap = 250
	SaveManager.profile.max_hp_upgrades = 3
	SaveManager.profile.shield_upgrades = 4
	SaveManager.profile.unlocked_combos = ["combo_heavy_slam", "combo_light_spin"]
	
	# Save profile
	SaveManager.save_profile()
	
	# Verify file exists
	var dir = DirAccess.open("user://")
	assert_true(dir.file_exists("test_save_manager_case.tres"), "Save file should be written to user://")
	
	# Clear memory representation
	SaveManager.profile = null
	
	# Reload
	SaveManager.load_profile()
	
	# Assert values were correctly deserialized
	assert_not_null(SaveManager.profile, "Loaded profile should not be null")
	assert_eq(SaveManager.profile.persistent_scrap, 250, "Persistent scrap should match saved value")
	assert_eq(SaveManager.profile.max_hp_upgrades, 3, "Max HP upgrades should match saved value")
	assert_eq(SaveManager.profile.shield_upgrades, 4, "Shield upgrades should match saved value")
	assert_eq(SaveManager.profile.unlocked_combos.size(), 2, "Should deserialize correct array size")
	assert_true(SaveManager.profile.unlocked_combos.has("combo_heavy_slam"), "Should contain combo_heavy_slam")
	assert_true(SaveManager.profile.unlocked_combos.has("combo_light_spin"), "Should contain combo_light_spin")
