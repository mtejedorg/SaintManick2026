class_name PlayerProfile
extends Resource

@export var scrap: int = 0
@export var cells: int = 0
@export var cores: int = 0
@export var max_hp_upgrades: int = 0
@export var max_lives_upgrades: int = 0
@export var shield_upgrades: int = 0
@export var unlocked_combos: Array[String] = []
@export var double_jump_unlocked: bool = false
## LEGACY single-slot field — kept only so SaveManager.load_profile() can migrate old
## saves into equipped_run_boosters. Do not read/write it anywhere else.
@export var equipped_run_booster: String = ""
## GDD §5.3 Run Boosters, one entry per filled slot in slot order. "None" is never stored.
@export var equipped_run_boosters: Array[String] = []
## GDD §5.3: Nick starts with 1 Run Booster slot; the shop's cores-unique upgrade grants +1.
@export var booster_slots: int = 1

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
