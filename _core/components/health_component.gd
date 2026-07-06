class_name HealthComponent
extends Node

signal health_changed(new_health: float, max_health: float)
signal shield_changed(new_shield: float, max_shield: float)
signal died()
signal damaged(damage_info: DamageInfo)

@export var max_health: float = 100.0
var current_health: float

@export var max_shield: float = 40.0
var current_shield: float

@export var shield_regen_rate: float = 12.0
@export var shield_regen_delay: float = 3.0
var regen_timer: float = 0.0

@export var is_player: bool = false
var is_invincible: bool = false

func _ready() -> void:
	current_health = max_health
	current_shield = max_shield

func _process(delta: float) -> void:
	if regen_timer > 0.0:
		regen_timer -= delta
	elif current_shield < max_shield and current_health > 0.0:
		current_shield = min(max_shield, current_shield + shield_regen_rate * delta)
		shield_changed.emit(current_shield, max_shield)
		if is_player:
			SignalBus.player_shield_changed.emit(current_shield, max_shield)
			var gm = get_node_or_null("/root/GameManager")
			if gm:
				gm.current_shield = current_shield

func take_damage(damage_info: DamageInfo) -> void:
	if is_invincible:
		return
	if current_health <= 0.0:
		return

		
	# Reset shield regen timer
	regen_timer = shield_regen_delay
	
	var dmg_amount = damage_info.amount
	
	if damage_info.is_shield_breaker:
		current_shield = 0.0
		current_health = max(0.0, current_health - dmg_amount)
	else:
		if current_shield > 0.0:
			if current_shield >= dmg_amount:
				current_shield -= dmg_amount
				dmg_amount = 0.0
			else:
				dmg_amount -= current_shield
				current_shield = 0.0
		
		if dmg_amount > 0.0:
			current_health = max(0.0, current_health - dmg_amount)

	damaged.emit(damage_info)
	health_changed.emit(current_health, max_health)
	shield_changed.emit(current_shield, max_shield)

	if is_player:
		SignalBus.player_health_changed.emit(current_health, max_health)
		SignalBus.player_shield_changed.emit(current_shield, max_shield)
		var gm = get_node_or_null("/root/GameManager")
		if gm:
			gm.current_hp = current_health
			gm.current_shield = current_shield

	if current_health <= 0.0:
		died.emit()
		if is_player:
			SignalBus.player_died.emit()
			var gm = get_node_or_null("/root/GameManager")
			if gm:
				gm.respawn_or_game_over()
