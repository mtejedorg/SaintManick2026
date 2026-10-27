class_name Hurtbox3D
extends Area3D

signal hit_received(damage_info: DamageInfo)

## F12: a light shake so an absorbed (blocked) hit still reads as contact.
const BLOCKED_SHAKE_STRENGTH := 0.03
const BLOCKED_SHAKE_DURATION := 0.08
## P7: DamageInfo meta set on every player_hit_landed this hurtbox emits -- true when a
## HealthComponent shield absorbed the whole hit (HitStop skips the freeze for it).
const SHIELD_ABSORBED_META := &"shield_absorbed"

@export var health_component: HealthComponent

func _ready() -> void:
	monitoring = false
	monitorable = true
	# Tag by side so AoE abilities (e.g. Bass Drop) can find valid targets without a
	# scene-tree group system elsewhere in the project. Checked via the owner type rather
	# than health_component.is_player, which children's _ready() can race against (the
	# owning controller sets is_player in its own _ready(), which runs AFTER its children's).
	add_to_group("player_hurtbox" if owner is PlayerController else "enemy_hurtbox")

## F12: a hit absorbed by a state shield (EnforcerHurtbox/HeadlinerHurtbox). The combat
## component still hears it (hit_received — it ignores absorbed hits itself); when Nick
## threw it, it counts as contact for the combo (hit_blocked) with a light shake. No damage,
## no player_hit_landed, no meter.
func receive_blocked_hit(damage_info: DamageInfo) -> void:
	hit_received.emit(damage_info)
	if damage_info.source is PlayerController:
		SignalBus.hit_blocked.emit(global_position)
		SignalBus.camera_shake_requested.emit(BLOCKED_SHAKE_STRENGTH, BLOCKED_SHAKE_DURATION)

func receive_hit(damage_info: DamageInfo) -> void:
	var was_invincible = health_component and health_component.is_invincible
	var shield_before: float = health_component.current_shield if health_component else 0.0
	if health_component:
		health_component.take_damage(damage_info)
	hit_received.emit(damage_info)
	if damage_info.source is PlayerController and not was_invincible:
		# P7: a HealthComponent shield (the Bruiser's) took the hit and is still up -- it still
		# feeds the combo/meter (player_hit_landed, flagged so HitStop skips the freeze), but
		# it reads as a steel clink (hit_blocked), not a cyan/magenta hit spark.
		var absorbed := shield_before > 0.0 and health_component != null and health_component.current_shield > 0.0
		damage_info.set_meta(SHIELD_ABSORBED_META, absorbed)
		SignalBus.player_hit_landed.emit(damage_info)
		if absorbed:
			SignalBus.hit_blocked.emit(global_position)
			SignalBus.camera_shake_requested.emit(BLOCKED_SHAKE_STRENGTH, BLOCKED_SHAKE_DURATION)
			return
		var hit_type := "heavy" if damage_info.amount >= DamageInfo.HEAVY_THRESHOLD else "light"
		SignalBus.hit_landed.emit(global_position, hit_type)
		# Camera shake: light hit 0.05 strength / 0.12s, heavy hit 0.1 / 0.2s.
		var shake_strength := 0.1 if hit_type == "heavy" else 0.05
		var shake_dur := 0.2 if hit_type == "heavy" else 0.12
		SignalBus.camera_shake_requested.emit(shake_strength, shake_dur)

