class_name Hurtbox3D
extends Area3D

signal hit_received(damage_info: DamageInfo)

@export var health_component: HealthComponent

func _ready() -> void:
	monitoring = false
	monitorable = true

func receive_hit(damage_info: DamageInfo) -> void:
	if health_component:
		health_component.take_damage(damage_info)
	hit_received.emit(damage_info)
