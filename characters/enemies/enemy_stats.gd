class_name EnemyStats
extends Resource

## Grunts that fall below this Y are out of the world (lowest slice floor ~ -4.5, the
## player's own fall kill sits at -15). They despawn silently — no scrap, no enemy_died —
## and a WaveSpawner's tree_exited tracking counts them as cleared.
const KILL_PLANE_Y: float = -20.0

@export var max_health: float = 30.0
@export var damage: float = 8.0
@export var speed: float = 3.0
@export var scrap: int = 8
@export var knockback: float = 5.0
@export var stun: float = 0.5
## Distance at which the enemy stops chasing and can melee.
@export var melee_range: float = 1.8
## Scene-placed grunts stay dormant (no chase, no telegraph, not counted by the
## IntensityController) until the player comes within this distance — checked once per
## primary beat. Wave-spawned grunts are activated by their WaveSpawner.
@export var aggro_range: float = 22.0
## Ranged attackers (Sniper) only start an attack cycle while the player is within this
## distance. 0 = no limit.
@export var attack_range: float = 0.0
## Starting shield: soaks every hit's damage first; while > 0 only guard-breaking hits knock back/stun. 0 = no shield.
@export var shield: float = 0.0
## Rare Scrap ("cells" in code, GDD §5.1) awarded on this enemy's death. 0 = doesn't drop any
## (most grunts only drop scrap; cells are reserved for stronger mid-journey enemies like
## the Enforcer miniboss).
@export var cells: int = 0
