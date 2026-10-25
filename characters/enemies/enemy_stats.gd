class_name EnemyStats
extends Resource

## Grunts that fall below this Y are out of the world (lowest slice floor ~ -4.5, the
## player's own fall kill sits at -15). They despawn silently — no scrap, no enemy_died —
## and a WaveSpawner's tree_exited tracking counts them as cleared.
const KILL_PLANE_Y: float = -20.0

## H2: grunts never walk off a ledge on their own (knockback still can). Before applying
## chase velocity a ray is cast from LEDGE_PROBE_AHEAD m ahead, LEDGE_PROBE_LIFT m above the
## body origin, down to LEDGE_PROBE_DROP m below the FEET -- so every slice step (<= 1 m,
## the Zone 5 tiers) is walkable while every pit (>= 3 m) and the void are not.
const LEDGE_PROBE_AHEAD: float = 0.6
const LEDGE_PROBE_LIFT: float = 0.5
const LEDGE_PROBE_DROP: float = 1.5
const WORLD_LAYER_MASK: int = 1

## True when there is world floor (layer 1) under the point `move_dir` ahead of `body`.
## `feet_offset` = distance from the body origin down to its feet (capsule half height).
static func has_floor_ahead(body: CharacterBody3D, move_dir: Vector3, feet_offset: float) -> bool:
	if not body.is_inside_tree():
		return true
	var space := body.get_world_3d().direct_space_state
	var from := body.global_position + move_dir * LEDGE_PROBE_AHEAD + Vector3.UP * LEDGE_PROBE_LIFT
	var to := from + Vector3.DOWN * (LEDGE_PROBE_LIFT + feet_offset + LEDGE_PROBE_DROP)
	var query := PhysicsRayQueryParameters3D.create(from, to, WORLD_LAYER_MASK)
	query.exclude = [body.get_rid()]
	return not space.intersect_ray(query).is_empty()

## J11: below this |dz| (m) to the player the depth fallback probe is not tried.
const DEPTH_PROBE_MIN_DZ: float = 0.1

## J11: the chase direction for a grunt heading along `dir` (flattened, toward the player):
## `dir` itself when there is floor ahead; else pure depth toward the player's z (slides
## along a deck edge until it lines up with the plank) when there is floor that way; else
## ZERO (hold at the ledge).
static func chase_direction(body: CharacterBody3D, dir: Vector3, feet_offset: float, dz: float) -> Vector3:
	var flat := Vector3(dir.x, 0.0, dir.z)
	if flat.length_squared() > 0.0 and has_floor_ahead(body, flat.normalized(), feet_offset):
		return flat
	if absf(dz) > DEPTH_PROBE_MIN_DZ:
		var depth := Vector3(0.0, 0.0, signf(dz))
		if has_floor_ahead(body, depth, feet_offset):
			return depth
	return Vector3.ZERO

## H2: the zone number in a "SECTOR NN -- DESCRIPTION" name (first integer word, the same
## parse as AudioManager.tier_for_zone). 0 when there is none.
static func zone_number(zone_name: String) -> int:
	for part in zone_name.split(" "):
		var n := part.to_int()
		if n > 0:
			return n
	return 0

## H2: half the height of `body`'s CollisionShape3D capsule (0 if it has none).
static func feet_offset_of(body: Node) -> float:
	var col := body.get_node_or_null("CollisionShape3D") as CollisionShape3D
	if col and col.shape is CapsuleShape3D:
		return (col.shape as CapsuleShape3D).height * 0.5
	return 0.0

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
