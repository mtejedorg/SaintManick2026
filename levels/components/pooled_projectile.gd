class_name PooledProjectile
extends Area3D

@export var speed: float = 10.0
@export var damage: float = 10.0
@export var lifetime: float = 5.0

var direction: Vector3 = Vector3.FORWARD
var current_lifetime: float = 5.0
var pool: ObjectPool = null

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
	global_position += direction * speed * delta
	
	current_lifetime -= delta
	if current_lifetime <= 0.0:
		release_to_pool()
		return
		
	var center = Vector3(365, 15, 0)
	if global_position.distance_to(center) > 50.0:
		release_to_pool()

func _on_hitbox_area_entered(area: Area3D) -> void:
	if area is Hurtbox3D:
		call_deferred("release_to_pool")

func on_acquire() -> void:
	current_lifetime = lifetime
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
