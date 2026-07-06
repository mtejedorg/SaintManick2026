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
@export var equipped_run_booster: String = ""
## GDD §5.3: Nick starts with 1 Run Booster slot; the shop's cores-unique upgrade grants +1.
@export var booster_slots: int = 1
