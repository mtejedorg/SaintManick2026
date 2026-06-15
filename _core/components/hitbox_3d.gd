class_name Hitbox3D
extends Area3D

@export var damage: int = 10
@export var knockback: float = 5.0
@export var is_active: bool = false : set = set_is_active

func _ready() -> void:
	monitoring = true
	monitorable = false
	area_entered.connect(_on_area_entered)
	_update_collision()

func set_is_active(value: bool) -> void:
	is_active = value
	_update_collision()

func _update_collision() -> void:
	for child in get_children():
		if child is CollisionShape3D:
			child.set_deferred("disabled", not is_active)

func _on_area_entered(area: Area3D) -> void:
	if not is_active:
		return
		
	if area is Hurtbox3D:
		area.receive_hit(self)
