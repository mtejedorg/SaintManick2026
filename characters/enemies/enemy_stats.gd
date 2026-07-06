class_name EnemyStats
extends Resource

@export var max_health: float = 30.0
@export var damage: float = 8.0
@export var speed: float = 3.0
@export var scrap: int = 8
@export var knockback: float = 5.0
@export var stun: float = 0.5
## Distance at which the enemy stops chasing and can melee.
@export var melee_range: float = 1.8
## Starting shield (hyper-armor while > 0; only guard-breaking hits get through). 0 = no shield.
@export var shield: float = 0.0
## Rare Scrap ("cells" in code, GDD §5.1) awarded on this enemy's death. 0 = doesn't drop any
## (most grunts only drop scrap; cells are reserved for stronger mid-journey enemies like
## the Enforcer miniboss).
@export var cells: int = 0
