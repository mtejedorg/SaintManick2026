class_name EscapeKillWall
extends Area3D

@export var speed: float = 3.0
@export var damage: float = 15.0
@export var damage_beat_interval: int = 1

var is_player_inside: bool = false
var player_health: HealthComponent = null
var is_moving: bool = false
var local_beat_counter: int = 0

func _ready() -> void:
	_set_body_visible(false) # dormant: no glow in the Enforcer arena
	body_entered.connect(_on_body_entered)
	body_exited.connect(_on_body_exited)
	SignalBus.beat.connect(_on_beat)

## Starts the chase and arms the damage area (it is authored with monitoring off so it
## cannot hurt Nick before the escape begins). Deferred: start_moving can be reached from
## inside a physics callback (the Enforcer's death), where monitoring changes are blocked.
func start_moving() -> void:
	is_moving = true
	_set_body_visible(true)
	set_deferred("monitoring", true)

func stop_moving() -> void:
	is_moving = false
	_set_body_visible(false)
	set_deferred("monitoring", false)
	is_player_inside = false
	player_health = null

## Shows/hides the glow body and hot core (children named WallMesh / HotCore).
func _set_body_visible(shown: bool) -> void:
	for node_name in ["WallMesh", "HotCore"]:
		var node := get_node_or_null(node_name) as Node3D
		if node:
			node.visible = shown

func _physics_process(delta: float) -> void:
	if is_moving:
		global_position.x += speed * delta

func _on_body_entered(body: Node3D) -> void:
	if body is PlayerController:
		is_player_inside = true
		player_health = body.health_component
		_deal_damage()

func _on_body_exited(body: Node3D) -> void:
	if body is PlayerController:
		is_player_inside = false
		player_health = null

func _on_beat(layer: String, beat_index: int) -> void:
	if layer != "primary":
		return
	local_beat_counter += 1
	if is_player_inside and player_health and (local_beat_counter % damage_beat_interval == 0):
		_deal_damage()

func _deal_damage() -> void:
	if player_health:
		var damage_info = DamageInfo.new()
		damage_info.amount = damage
		damage_info.source = self
		player_health.take_damage(damage_info)
		SignalBus.camera_shake_requested.emit(0.1, 0.2)
