class_name DamageInfo
extends Resource

## Damage at or above this counts as a "heavy" hit for SFX/VFX/shake purposes
## (heavy attacks deal 28, light deal 12).
const HEAVY_THRESHOLD: float = 20.0

@export var amount: float = 10.0
@export var knockback: float = 0.0
@export var stun: float = 0.0
@export var is_shield_breaker: bool = false
## Runtime-only reference to the attacker. NOT exported: Godot forbids exporting a
## Node reference on a Resource (resources are shared/serialized and cannot hold scene nodes).
var source: Node3D = null
var is_launcher: bool = false
var is_guard_breaking: bool = false
## Set on ability-spender hits (e.g. Bass Drop) so they don't refill the very meter they
## just spent via the normal player_hit_landed -> add_ability_meter path.
var is_ability_hit: bool = false

