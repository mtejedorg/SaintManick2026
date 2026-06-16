extends Node

var save_path: String = "user://save_data.tres"

var profile: PlayerProfile

func _ready() -> void:
	load_profile()

func load_profile() -> void:
	if ResourceLoader.exists(save_path):
		profile = ResourceLoader.load(save_path) as PlayerProfile
		
	if not profile:
		profile = PlayerProfile.new()
		save_profile()

func save_profile() -> void:
	if profile:
		var err = ResourceSaver.save(profile, save_path)
		if err != OK:
			push_error("SaveManager: Failed to save player profile. Error: " + str(err))
