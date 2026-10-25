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
	var existed := ResourceLoader.exists(save_path) or FileAccess.file_exists(save_path)
	if existed:
		profile = ResourceLoader.load(save_path) as PlayerProfile

	if not profile and existed:
		# H4: a profile that exists but will not load is never overwritten silently -- keep
		# a copy next to it before the fresh profile replaces it.
		var bak := backup_path()
		push_error("SaveManager: %s exists but failed to load -- backing it up to %s and starting a fresh profile." % [save_path, bak])
		var err := DirAccess.copy_absolute(ProjectSettings.globalize_path(save_path), ProjectSettings.globalize_path(bak))
		if err != OK:
			push_error("SaveManager: backup copy failed (error %d)." % err)

	if not profile:
		profile = PlayerProfile.new()
		_grant_starter_combos()
		save_profile()
		return

	_migrate_legacy_persistent_scrap()
	_migrate_legacy_run_booster()
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

## One-time migration: the single `equipped_run_booster` string became the multi-slot
## `equipped_run_boosters` array. Move a legacy value in once (unless the array is already
## populated or the old shop stored the "None" placeholder), clear the string, persist.
func _migrate_legacy_run_booster() -> void:
	var legacy: String = profile.equipped_run_booster
	if legacy == "":
		return
	if profile.equipped_run_boosters.is_empty() and legacy != "None":
		profile.equipped_run_boosters.append(legacy)
	profile.equipped_run_booster = ""
	save_profile()

func save_profile() -> void:
	if profile:
		# H4: write a temp file, then rename it over the real one, so a crash mid-write can
		# never leave a half-written profile behind.
		var tmp := temp_path()
		var err := ResourceSaver.save(profile, tmp)
		if err != OK:
			push_error("SaveManager: Failed to save player profile. Error: " + str(err))
			return
		var real_abs := ProjectSettings.globalize_path(save_path)
		var tmp_abs := ProjectSettings.globalize_path(tmp)
		err = DirAccess.rename_absolute(tmp_abs, real_abs)
		if err != OK and FileAccess.file_exists(save_path):
			# Some platforms refuse to rename over an existing file.
			DirAccess.remove_absolute(real_abs)
			err = DirAccess.rename_absolute(tmp_abs, real_abs)
		if err != OK:
			push_error("SaveManager: Failed to move the saved profile into place. Error: " + str(err))

## H4: the temp file next to save_path, keeping the .tres extension (ResourceSaver picks
## the format from it, so a bare .tmp suffix is unrecognised).
func temp_path() -> String:
	return "%s.tmp.%s" % [save_path.get_basename(), save_path.get_extension()]

## H4: the backup of an unreadable profile (save_data.bak.tres for save_data.tres).
func backup_path() -> String:
	return "%s.bak.%s" % [save_path.get_basename(), save_path.get_extension()]
