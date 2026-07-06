class_name Hurtbox3D
extends Area3D

signal hit_received(damage_info: DamageInfo)

@export var health_component: HealthComponent

func _ready() -> void:
	monitoring = false
	monitorable = true

func receive_hit(damage_info: DamageInfo) -> void:
	var was_invincible = health_component and health_component.is_invincible
	if health_component:
		health_component.take_damage(damage_info)
	hit_received.emit(damage_info)
	if damage_info.source is PlayerController and not was_invincible:
		SignalBus.player_hit_landed.emit(damage_info)
		var hit_type := "heavy" if damage_info.amount >= DamageInfo.HEAVY_THRESHOLD else "light"
		SignalBus.hit_landed.emit(global_position, hit_type)
		# Camera shake: light hit 0.05 strength / 0.12s, heavy hit 0.1 / 0.2s.
		var shake_strength := 0.1 if hit_type == "heavy" else 0.05
		var shake_dur := 0.2 if hit_type == "heavy" else 0.12
		SignalBus.camera_shake_requested.emit(shake_strength, shake_dur)

