extends Node

var save_path: String = "user://save_data.tres"

var profile: PlayerProfile

## Combo tree entries with no prerequisite and 0 cost (Tri-Cut/Launcher) — granted to every
## profile so a fresh save can still throw the two basic chains without a shop visit first
## (GDD §5.2 "basic chains" vs. purchased "advanced juggles or heavy sweeps").
const STARTER_COMBOS: Array[String] = ["AAA", "AAB"]

## L8: the audio buses the options menu drives (names from default_bus_layout.tres).
const BUS_MASTER := &"Master"
const BUS_MUSIC := &"Music"
const BUS_SFX := &"SFX"
## A volume at or below this is treated as mute (linear_to_db(0) is -inf).
const MUTE_LINEAR := 0.001
const MUTE_DB := -80.0

## L8: each bus's authored level (Music -6 dB, ...), read once before any setting is applied.
## A slider at 100 % restores that level; lower values attenuate from it, so the options
## never flatten the mix contract in default_bus_layout.tres.
var _bus_base_db: Dictionary = {}

func _ready() -> void:
	_capture_bus_baselines()
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

## L8: applies the profile's options (bus volumes + window mode). Called by the title screen
## at boot, after the profile has loaded.
func apply_settings() -> void:
	if not profile:
		return
	set_bus_volume_linear(BUS_MASTER, profile.master_volume)
	set_bus_volume_linear(BUS_MUSIC, profile.music_volume)
	set_bus_volume_linear(BUS_SFX, profile.sfx_volume)
	apply_fullscreen(profile.fullscreen)

## L8: linear 0..1 volume for a bus, relative to its authored level. Unknown bus = no-op.
func set_bus_volume_linear(bus: StringName, value: float) -> void:
	var idx := AudioServer.get_bus_index(bus)
	if idx < 0:
		return
	if not _bus_base_db.has(bus):
		_bus_base_db[bus] = AudioServer.get_bus_volume_db(idx)
	var db: float = MUTE_DB if value <= MUTE_LINEAR else float(_bus_base_db[bus]) + linear_to_db(clampf(value, 0.0, 1.0))
	AudioServer.set_bus_volume_db(idx, db)

## L8: the authored level of a bus (what 100 % maps to).
func bus_base_db(bus: StringName) -> float:
	if not _bus_base_db.has(bus):
		var idx := AudioServer.get_bus_index(bus)
		return AudioServer.get_bus_volume_db(idx) if idx >= 0 else 0.0
	return float(_bus_base_db[bus])

## L8: fullscreen on/off. Only switches when the mode actually differs (a maximised window
## stays maximised when fullscreen is off); a no-op on the headless display server.
func apply_fullscreen(on: bool) -> void:
	if DisplayServer.get_name() == "headless":
		return
	var mode := DisplayServer.window_get_mode()
	var is_full := mode == DisplayServer.WINDOW_MODE_FULLSCREEN or mode == DisplayServer.WINDOW_MODE_EXCLUSIVE_FULLSCREEN
	if on and not is_full:
		DisplayServer.window_set_mode(DisplayServer.WINDOW_MODE_FULLSCREEN)
	elif not on and is_full:
		DisplayServer.window_set_mode(DisplayServer.WINDOW_MODE_WINDOWED)

func _capture_bus_baselines() -> void:
	for bus in [BUS_MASTER, BUS_MUSIC, BUS_SFX]:
		var idx := AudioServer.get_bus_index(bus)
		if idx >= 0 and not _bus_base_db.has(bus):
			_bus_base_db[bus] = AudioServer.get_bus_volume_db(idx)

## H4: the temp file next to save_path, keeping the .tres extension (ResourceSaver picks
## the format from it, so a bare .tmp suffix is unrecognised).
func temp_path() -> String:
	return "%s.tmp.%s" % [save_path.get_basename(), save_path.get_extension()]

## H4: the backup of an unreadable profile (save_data.bak.tres for save_data.tres).
func backup_path() -> String:
	return "%s.bak.%s" % [save_path.get_basename(), save_path.get_extension()]
