class_name HealthComponent
extends Node

signal health_changed(new_health: float, max_health: float)
signal shield_changed(new_shield: float, max_shield: float)
signal died()
signal damaged(damage_info: DamageInfo)

@export var max_health: float = 100.0
var current_health: float

@export var max_shield: float = 0.0
var current_shield: float

@export var shield_regen_rate: float = 12.0
@export var shield_regen_delay: float = 3.0
var regen_timer: float = 0.0

@export var is_player: bool = false
## Whether a hit is blocked right now: the owner's own i-frames (dash/roll, boss phase
## transitions -- they write this) OR the respawn grace below. I2: writing it only touches
## the i-frame flag, so a dash/roll exit can no longer cut the respawn grace short.
var is_invincible: bool:
	get:
		return _iframes or grace_invincible
	set(value):
		_iframes = value
var _iframes: bool = false
## I2: post-respawn grace, owned by GameManager (grant_respawn_grace). Dodges never touch it.
var grace_invincible: bool = false

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
	if grace_invincible:
		return
	if _iframes and not damage_info.ignores_iframes:
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
		# T2: shield takes amount*multiplier (generic heavies pressure shields at 2x)
		# rather than the raw hit amount; any leftover that breaks through carries to
		# HP scaled back down to the base amount, so HP damage tuning stays untouched
		# by the shield multiplier.
		var mult = damage_info.shield_damage_multiplier if damage_info.shield_damage_multiplier > 0.0 else 1.0
		if current_shield > 0.0:
			var shield_dmg = dmg_amount * mult
			if current_shield >= shield_dmg:
				current_shield -= shield_dmg
				dmg_amount = 0.0
			else:
				var leftover_shield_dmg = shield_dmg - current_shield
				current_shield = 0.0
				dmg_amount = leftover_shield_dmg / mult

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
				gm.record_lethal_hit(damage_info) # I6: the Game Over "DESTROYED BY" line
				# J13: deferred once -- a lethal Hitbox overlap lands here inside the physics
				# flush (area_entered), and the respawn listeners flip monitoring/collision.
				# K11: the 0.9 s death beat runs first, then respawn_or_game_over.
				gm.call_deferred("begin_death_beat")
