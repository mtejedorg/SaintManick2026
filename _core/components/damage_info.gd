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

