class_name RunBooster
extends Resource
## Batch Q2: one GDD §5.3 Run Booster. The catalog is GameManager.RUN_BOOSTERS (one .tres per
## booster in _core/persistence/run_boosters/); start_new_run() applies `effect` with `value`.
## The profile keeps storing display names ("Tempo Shield"), so saves need no migration.

enum Effect {
	SHIELD_MULT, ## max shield x value for the run (rounded)
	SPEED_MULT,  ## run-wide movement speed multiplier = value
	SCRAP_MULT,  ## scrap pickup multiplier = int(value)
}

@export var id: String = ""
## The name the profile stores and the menus show ("Tempo Shield").
@export var display_name: String = ""
## One dim line for the shop / demo loadout ("+50 % shield").
@export var description: String = ""
@export var effect: Effect = Effect.SHIELD_MULT
@export var value: float = 1.0
