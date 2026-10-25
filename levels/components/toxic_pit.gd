class_name ToxicPit
extends Area3D

## Size of the pit volume (collision + visual). The slice stretches it over the whole Zone 2
## platform run so a fall anywhere between the platforms lands in the toxic water.
@export var pit_size: Vector3 = Vector3(10, 2, 5)
## Damage per primary beat while standing in the water (Nick and grunts alike).
@export var damage_per_beat: float = 5.0

var is_player_inside: bool = false
var player_health: HealthComponent = null
## H2: enemy hurtboxes (group "enemy_hurtbox", layer 13) currently in the water. The pit
## masks that layer, so knocked-in grunts burn through the same one-way damage path as any
## hit: Hurtbox3D.receive_hit(DamageInfo) -> HealthComponent (normal scrap on death).
var _enemy_hurtboxes: Array[Hurtbox3D] = []

func _ready() -> void:
	_apply_pit_size()
	body_entered.connect(_on_body_entered)
	body_exited.connect(_on_body_exited)
	area_entered.connect(_on_area_entered)
	area_exited.connect(_on_area_exited)
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

func _on_area_entered(area: Area3D) -> void:
	if area is Hurtbox3D and area.is_in_group("enemy_hurtbox") and not _enemy_hurtboxes.has(area):
		_enemy_hurtboxes.append(area as Hurtbox3D)

func _on_area_exited(area: Area3D) -> void:
	if area is Hurtbox3D:
		_enemy_hurtboxes.erase(area as Hurtbox3D)

func _make_damage() -> DamageInfo:
	var damage_info := DamageInfo.new()
	damage_info.amount = damage_per_beat
	damage_info.source = self
	return damage_info

func _on_beat(layer: String, _beat_index: int) -> void:
	if layer != "primary":
		return

	if is_player_inside and player_health:
		player_health.take_damage(_make_damage())

	# Iterate a copy: a lethal tick frees the grunt (and its hurtbox exits mid-loop).
	for hurtbox in _enemy_hurtboxes.duplicate():
		if not is_instance_valid(hurtbox):
			_enemy_hurtboxes.erase(hurtbox)
			continue
		hurtbox.receive_hit(_make_damage())
