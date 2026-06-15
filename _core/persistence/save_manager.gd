extends Node

const SAVE_PATH = "user://save_data.tres"

var profile: PlayerProfile

func _ready() -> void:
	load_profile()

func load_profile() -> void:
	if ResourceLoader.exists(SAVE_PATH):
		profile = ResourceLoader.load(SAVE_PATH) as PlayerProfile
		
	if not profile:
		profile = PlayerProfile.new()
		save_profile()

func save_profile() -> void:
	if profile:
		var err = ResourceSaver.save(profile, SAVE_PATH)
		if err != OK:
			push_error("SaveManager: Failed to save player profile. Error: " + str(err))
