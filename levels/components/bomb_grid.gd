class_name BombGrid
extends Node3D

@export var grid_size: float = 5.0
@export var damage: float = 15.0
@export var explosion_duration: float = 0.5

var set_a: Array[Node3D] = []
var set_b: Array[Node3D] = []

func _ready() -> void:
	# Group child nodes starting with "Cell" into Set A and Set B based on coordinates
	for child in get_children():
		if child.name.begins_with("Cell"):
			var gx = roundi(child.position.x / grid_size)
			var gz = roundi(child.position.z / grid_size)
			
			# Setup cell components
			var hitbox = child.get_node_or_null("Hitbox3D")
			if hitbox and hitbox is Hitbox3D:
				hitbox.is_active = false
				hitbox.collision_layer = 8192 # Layer 14
				hitbox.collision_mask = 1024 # Layer 11
				hitbox.damage_info = DamageInfo.new()
				hitbox.damage_info.amount = damage
				hitbox.damage_info.knockback = 6.0
				hitbox.damage_info.source = self
				
			var indicator = child.get_node_or_null("Indicator")
			if indicator:
				indicator.visible = false
				
			var explosion = child.get_node_or_null("ExplosionVisual")
			if explosion:
				explosion.visible = false
				
			if (gx + gz) % 2 == 0:
				set_a.append(child)
			else:
				set_b.append(child)
				
	SignalBus.downbeat.connect(_on_downbeat)

func _on_downbeat(layer: String, measure_index: int) -> void:
	if layer != "primary":
		return
		
	if measure_index % 2 == 1:
		# Odd measure (e.g. 1, 3, 5...)
		if measure_index > 1:
			_ignite_cells(set_b)
		_warn_cells(set_a)
		_clear_warning(set_b)
	else:
		# Even measure (e.g. 2, 4, 6...)
		_ignite_cells(set_a)
		_warn_cells(set_b)
		_clear_warning(set_a)

func _warn_cells(cells: Array[Node3D]) -> void:
	for cell in cells:
		var indicator = cell.get_node_or_null("Indicator")
		if indicator:
			indicator.visible = true

func _clear_warning(cells: Array[Node3D]) -> void:
	for cell in cells:
		var indicator = cell.get_node_or_null("Indicator")
		if indicator:
			indicator.visible = false

func _ignite_cells(cells: Array[Node3D]) -> void:
	for cell in cells:
		var explosion = cell.get_node_or_null("ExplosionVisual")
		if explosion:
			explosion.visible = true
			
		var hitbox = cell.get_node_or_null("Hitbox3D")
		if hitbox and hitbox is Hitbox3D:
			hitbox.is_active = true
			
	# Schedule deactivation
	var timer = get_tree().create_timer(explosion_duration)
	timer.timeout.connect(func():
		for cell in cells:
			var explosion = cell.get_node_or_null("ExplosionVisual")
			if explosion:
				explosion.visible = false
				
			var hitbox = cell.get_node_or_null("Hitbox3D")
			if hitbox and hitbox is Hitbox3D:
				hitbox.is_active = false
	)
