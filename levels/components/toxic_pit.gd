class_name ToxicPit
extends Area3D

var is_player_inside: bool = false
var player_health: HealthComponent = null

func _ready() -> void:
	body_entered.connect(_on_body_entered)
	body_exited.connect(_on_body_exited)
	SignalBus.beat.connect(_on_beat)

func _on_body_entered(body: Node3D) -> void:
	if body is PlayerController:
		is_player_inside = true
		player_health = body.health_component

func _on_body_exited(body: Node3D) -> void:
	if body is PlayerController:
		is_player_inside = false
		player_health = null

func _on_beat(layer: String, beat_index: int) -> void:
	if layer != "primary":
		return
		
	if is_player_inside and player_health:
		var damage_info = DamageInfo.new()
		damage_info.amount = 5.0
		damage_info.source = self
		player_health.take_damage(damage_info)
