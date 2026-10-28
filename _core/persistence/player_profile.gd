class_name PlayerProfile
extends Resource

@export var scrap: int = 0
@export var cells: int = 0
@export var cores: int = 0
@export var max_hp_upgrades: int = 0
@export var max_lives_upgrades: int = 0
@export var shield_upgrades: int = 0
@export var unlocked_combos: Array[String] = []
## L1 (D1): the demo has no shop gate on the double jump -- a fresh profile starts with it.
## ResourceSaver never writes a default value, so an old save that never bought it has no
## key and loads it unlocked too.
@export var double_jump_unlocked: bool = true
## LEGACY single-slot field — kept only so SaveManager.load_profile() can migrate old
## saves into equipped_run_boosters. Do not read/write it anywhere else.
@export var equipped_run_booster: String = ""
## GDD §5.3 Run Boosters, one entry per filled slot in slot order. "None" is never stored.
@export var equipped_run_boosters: Array[String] = []
## GDD §5.3: Nick starts with 1 Run Booster slot; the shop's cores-unique upgrade grants +1.
@export var booster_slots: int = 1

## Q6: set once every chip of the HUD hint strip (ui/hud/hud_hints.gd) has fired; from then
## on the strip is skipped. (Was L6: the first Zone 2 entry; the Zone 1 cards are gone.) A demo
## run never saves it -- GameManager.mark_controls_seen() keeps it in memory there.
@export var seen_controls: bool = false
## Q6: bitmask of the one-shot gameplay hints already shown (OnboardingPrompts.HINT_* bits).
@export var seen_hints: int = 0

## L8 (D25) options. Volumes are linear 0..1 on top of each bus's default_bus_layout level
## (SaveManager.apply_settings); fullscreen toggles the window mode.
@export var master_volume: float = 1.0
@export var music_volume: float = 1.0
@export var sfx_volume: float = 1.0
@export var fullscreen: bool = false
## Q4 accessibility: camera shake scale (0 / 0.5 / 1.0), the VCR drone-feed overlay on/off, and
## reduced flashes (no low-HP vignette pulse, no full-screen flashes). Read via GameManager's
## shake_multiplier() / vcr_enabled() / reduce_flashes().
@export var screen_shake: float = 1.0
@export var vcr_effects: bool = true
@export var reduce_flashes: bool = false

## The boosters a run actually applies: distinct, non-empty, non-"None" entries in slot
## order, trimmed to booster_slots.
func get_active_run_boosters() -> Array[String]:
	var result: Array[String] = []
	for booster in equipped_run_boosters:
		if result.size() >= booster_slots:
			break
		if booster == "" or booster == "None" or result.has(booster):
			continue
		result.append(booster)
	return result
