extends Node

var save_path: String = "user://save_data.tres"

var profile: PlayerProfile

## Combo tree entries with no prerequisite and 0 cost (Tri-Cut/Launcher) — granted to every
## profile so a fresh save can still throw the two basic chains without a shop visit first
## (GDD §5.2 "basic chains" vs. purchased "advanced juggles or heavy sweeps").
const STARTER_COMBOS: Array[String] = ["AAA", "AAB"]

func _ready() -> void:
	load_profile()

func load_profile() -> void:
	if ResourceLoader.exists(save_path):
		profile = ResourceLoader.load(save_path) as PlayerProfile

	if not profile:
		profile = PlayerProfile.new()
		_grant_starter_combos()
		save_profile()
		return

	_migrate_legacy_persistent_scrap()
	_grant_starter_combos()

## Ensures the basic combo chains are always present, even on saves created before this
## upgrade shipped (mirrors the spirit of _migrate_legacy_persistent_scrap — an existing
## save must not regress to fewer combos than a brand new one).
func _grant_starter_combos() -> void:
	var changed = false
	for combo_id in STARTER_COMBOS:
		if not profile.unlocked_combos.has(combo_id):
			profile.unlocked_combos.append(combo_id)
			changed = true
	if changed:
		save_profile()

## One-time migration: PlayerProfile used to export `persistent_scrap`; the property was
## renamed to `scrap` (+ new `cells`/`cores`). ResourceLoader silently drops properties that
## no longer exist on the script, so an old save file loads with scrap == 0 and the bank is
## gone unless we recover it. Fix: if scrap is 0, re-read the file as text and look for the
## legacy key; if found, migrate it once and persist immediately.
func _migrate_legacy_persistent_scrap() -> void:
	if profile.scrap != 0:
		return
	if not FileAccess.file_exists(save_path):
		return

	var file = FileAccess.open(save_path, FileAccess.READ)
	if not file:
		return
	var text = file.get_as_text()
	file.close()

	var regex = RegEx.new()
	regex.compile("persistent_scrap\\s*=\\s*(\\d+)")
	var result = regex.search(text)
	if not result:
		return

	var legacy_scrap = result.get_string(1).to_int()
	if legacy_scrap <= 0:
		return

	profile.scrap = legacy_scrap
	save_profile()

func save_profile() -> void:
	if profile:
		var err = ResourceSaver.save(profile, save_path)
		if err != OK:
			push_error("SaveManager: Failed to save player profile. Error: " + str(err))
