class_name ShopUpgrade
extends Resource

enum Currency { SCRAP, CELLS, CORES }

## What buying this upgrade actually does to PlayerProfile. Keeps karens_shop.gd generic —
## it applies effects by kind instead of hardcoding what each button does.
enum Effect {
	MAX_HP,          ## +1 to max_hp_upgrades
	MAX_SHIELD,      ## +1 to shield_upgrades
	MAX_LIVES,       ## +1 to max_lives_upgrades
	DOUBLE_JUMP,     ## unlocks double_jump_unlocked (not repeatable)
	UNLOCK_COMBO,    ## adds combo_id to unlocked_combos (not repeatable)
	BOOSTER_SLOT,    ## +1 to booster_slots (not repeatable)
}

@export var id: String = ""
@export var name: String = ""
@export var description: String = ""
@export var cost: int = 0
@export var currency: Currency = Currency.SCRAP
@export var prerequisite_id: String = ""
@export var is_repeatable: bool = false
@export var effect: Effect = Effect.MAX_HP
## Used only by UNLOCK_COMBO — the combo id added to PlayerProfile.unlocked_combos
## (matches the ComboDef input_chain key used by player_state_attack.gd, e.g. "AAA").
@export var combo_id: String = ""
