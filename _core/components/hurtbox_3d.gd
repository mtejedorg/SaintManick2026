class_name Hurtbox3D
extends Area3D

signal hit_received(hitbox: Hitbox3D)

@export var health_component: HealthComponent

func _ready() -> void:
	monitoring = false
	monitorable = true

func receive_hit(hitbox: Hitbox3D) -> void:
	if health_component:
		health_component.take_damage(hitbox.damage)
	hit_received.emit(hitbox)
