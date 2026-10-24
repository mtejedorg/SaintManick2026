class_name PooledProjectile
extends Area3D

@export var speed: float = 10.0
@export var damage: float = 10.0
@export var lifetime: float = 5.0
## Distance from the spawn point at which the projectile returns to the pool.
@export var max_range: float = 50.0

var direction: Vector3 = Vector3.FORWARD
var current_lifetime: float = 5.0
var pool: ObjectPool = null

# Where this shot was fired from. The emitter positions the projectile right after
# ObjectPool.acquire(), so on_acquire() only clears it and the first physics tick
# captures it (before the projectile moves).
var _spawn_origin: Vector3 = Vector3.ZERO
var _has_spawn_origin: bool = false

@onready var hitbox: Hitbox3D = $Hitbox3D

func _ready() -> void:
	if get_parent() is ObjectPool:
		pool = get_parent()
	if hitbox:
		hitbox.area_entered.connect(_on_hitbox_area_entered)
		# Ensure hitbox gets a default DamageInfo if none set
		if not hitbox.damage_info:
			hitbox.damage_info = DamageInfo.new()

func _physics_process(delta: float) -> void:
	if not _has_spawn_origin:
		_spawn_origin = global_position
		_has_spawn_origin = true

	global_position += direction * speed * delta
	
	current_lifetime -= delta
	if current_lifetime <= 0.0:
		release_to_pool()
		return
		
	if global_position.distance_to(_spawn_origin) > max_range:
		release_to_pool()

func _on_hitbox_area_entered(area: Area3D) -> void:
	if area is Hurtbox3D:
		call_deferred("release_to_pool")

func on_acquire() -> void:
	current_lifetime = lifetime
	_has_spawn_origin = false
	if hitbox:
		hitbox.is_active = true
		if hitbox.damage_info:
			hitbox.damage_info.amount = damage
			hitbox.damage_info.source = owner if owner else self

func on_release() -> void:
	if hitbox:
		hitbox.is_active = false

func release_to_pool() -> void:
	if pool:
		pool.release(self)
	elif get_parent() is ObjectPool:
		get_parent().release(self)
