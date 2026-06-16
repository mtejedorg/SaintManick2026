class_name DamageInfo
extends Resource

@export var amount: float = 10.0
@export var knockback: float = 0.0
@export var stun: float = 0.0
@export var is_shield_breaker: bool = false
## Runtime-only reference to the attacker. NOT exported: Godot forbids exporting a
## Node reference on a Resource (resources are shared/serialized and cannot hold scene nodes).
var source: Node3D = null
var is_launcher: bool = false

