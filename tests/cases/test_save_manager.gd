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
	assert_eq(SaveManager.profile.scrap, 0, "Default scrap should be 0")
	assert_eq(SaveManager.profile.max_hp_upgrades, 0, "Default hp upgrades should be 0")
	assert_eq(SaveManager.profile.max_lives_upgrades, 0, "Default lives upgrades should be 0")
	assert_eq(SaveManager.profile.shield_upgrades, 0, "Default shield upgrades should be 0")
	assert_false(SaveManager.profile.double_jump_unlocked, "Default double_jump_unlocked should be false")
	# M8: a brand new profile still ships with the basic combo chains unlocked
	# (Tri-Cut/Launcher) so Nick can fight before ever visiting the shop.
	assert_true(SaveManager.profile.unlocked_combos.has("AAA"), "Fresh profile should have Tri-Cut unlocked")
	assert_true(SaveManager.profile.unlocked_combos.has("AAB"), "Fresh profile should have Launcher unlocked")

func test_save_and_load_profile() -> void:
	# Initialize default profile
	SaveManager.load_profile()
	
	# Modify profile
	SaveManager.profile.scrap = 250
	SaveManager.profile.max_hp_upgrades = 3
	SaveManager.profile.shield_upgrades = 4
	SaveManager.profile.double_jump_unlocked = true
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
	assert_eq(SaveManager.profile.scrap, 250, "Persistent scrap should match saved value")
	assert_eq(SaveManager.profile.max_hp_upgrades, 3, "Max HP upgrades should match saved value")
	assert_eq(SaveManager.profile.shield_upgrades, 4, "Shield upgrades should match saved value")
	assert_true(SaveManager.profile.double_jump_unlocked, "double_jump_unlocked should match saved value")
	# _grant_starter_combos() tops up AAA/AAB on every load, so a saved array of 2 custom
	# entries becomes 4 after reload — assert the saved entries persisted rather than an
	# exact size.
	assert_true(SaveManager.profile.unlocked_combos.has("combo_heavy_slam"), "Should contain combo_heavy_slam")
	assert_true(SaveManager.profile.unlocked_combos.has("combo_light_spin"), "Should contain combo_light_spin")

func test_legacy_persistent_scrap_migrates_to_scrap() -> void:
	# C3: PlayerProfile.persistent_scrap was renamed to `scrap`. ResourceLoader silently
	# drops unknown properties, so an old save file must be recovered via text-fallback
	# migration instead of losing the player's banked scrap.
	var fixture_text := """[gd_resource type="Resource" script_class="PlayerProfile" load_steps=2 format=3]

[ext_resource type="Script" path="res://_core/persistence/player_profile.gd" id="1_legacy"]

[resource]
script = ExtResource("1_legacy")
persistent_scrap = 500
max_hp_upgrades = 2
max_lives_upgrades = 1
shield_upgrades = 0
double_jump_unlocked = true
"""
	var file = FileAccess.open(SaveManager.save_path, FileAccess.WRITE)
	assert_not_null(file, "Should be able to write legacy fixture save")
	file.store_string(fixture_text)
	file.close()

	SaveManager.profile = null
	SaveManager.load_profile()

	assert_not_null(SaveManager.profile, "Profile should load from legacy fixture")
	assert_eq(SaveManager.profile.scrap, 500, "Legacy persistent_scrap should migrate into scrap")

	# Migration must persist so the recovered value survives a subsequent load
	# without relying on the legacy text still being present.
	SaveManager.profile = null
	SaveManager.load_profile()
	assert_eq(SaveManager.profile.scrap, 500, "Migrated scrap should be persisted, not just recovered in-memory")
