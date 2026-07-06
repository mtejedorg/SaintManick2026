class_name ComboDef
extends Resource

@export var combo_name: String = "Basic Combo"
@export var input_chain: Array[String] = []
@export var damage_multipliers: Array[float] = []
@export var stun_time: float = 0.5

## Base damage the final hit of the route deals before damage_multipliers are applied.
## (Route-specific values replace the generic light/heavy damage once the full
## input_chain matches — see player_state_attack.gd.)
@export var damage: float = 20.0
## Duration (seconds) the final hit's active/recovery window lasts.
@export var duration: float = 0.5
@export var knockback: float = 8.0
## Uniform scale applied to the katana hitbox for this route's final hit (crowd-control
## routes like the Sweeper widen it).
@export var hitbox_scale: Vector3 = Vector3.ONE
@export var is_launcher: bool = false
@export var is_guard_breaking: bool = false
## Ability meter cost to perform this route's finishing hit. 0 = free (all current routes
## are free basic inputs per GDD §3.3 — reserved for future paid routes).
@export var meter_cost: float = 0.0
