class_name ToxicPit
extends Area3D

## Size of the pit volume (collision + visual). The slice stretches it over the whole Zone 2
## platform run so a fall anywhere between the platforms lands in the toxic water.
@export var pit_size: Vector3 = Vector3(10, 2, 5)

var is_player_inside: bool = false
var player_health: HealthComponent = null

func _ready() -> void:
	_apply_pit_size()
	body_entered.connect(_on_body_entered)
	body_exited.connect(_on_body_exited)
	SignalBus.beat.connect(_on_beat)

func _apply_pit_size() -> void:
	# Shapes/meshes are shared sub-resources of the scene: duplicate before resizing.
	var shape_node := get_node_or_null("CollisionShape3D") as CollisionShape3D
	if shape_node and shape_node.shape is BoxShape3D:
		var box := (shape_node.shape as BoxShape3D).duplicate() as BoxShape3D
		box.size = pit_size
		shape_node.shape = box
	var visual := get_node_or_null("VisualBounds") as MeshInstance3D
	if visual and visual.mesh is BoxMesh:
		var mesh := (visual.mesh as BoxMesh).duplicate() as BoxMesh
		mesh.size = pit_size
		visual.mesh = mesh

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
