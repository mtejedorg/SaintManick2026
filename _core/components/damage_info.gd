class_name DamageInfo
extends Resource

## Damage at or above this counts as a "heavy" hit for SFX/VFX/shake purposes
## (heavy attacks deal 28, light deal 12).
const HEAVY_THRESHOLD: float = 20.0

@export var amount: float = 10.0
@export var knockback: float = 0.0
@export var stun: float = 0.0
@export var is_shield_breaker: bool = false
## T2: non-shield-breaker hits pressure the shield at this multiple of `amount` (e.g.
## generic heavies hit shields 2x as hard as HP) before any leftover carries to HP,
## scaled back down to base `amount`. is_shield_breaker hits ignore this entirely.
@export var shield_damage_multiplier: float = 1.0
## Runtime-only reference to the attacker. NOT exported: Godot forbids exporting a
## Node reference on a Resource (resources are shared/serialized and cannot hold scene nodes).
var source: Node3D = null
var is_launcher: bool = false
var is_guard_breaking: bool = false
## Set on ability-spender hits (e.g. Bass Drop) so they don't refill the very meter they
## just spent via the normal player_hit_landed -> add_ability_meter path.
var is_ability_hit: bool = false
## J4: applied through the owner's dash/roll i-frames (the fall cost). The respawn grace
## (HealthComponent.grace_invincible) still blocks it.
var ignores_iframes: bool = false
