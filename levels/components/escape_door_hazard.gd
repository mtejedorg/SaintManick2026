class_name EscapeDoorHazard
extends Node3D

@export var close_beat_interval: int = 4
@export var closed_duration_beats: int = 2
@export var slide_distance: float = 3.0
@export var close_duration: float = 0.1
@export var open_duration: float = 0.3
@export var damage: float = 12.0
## Pre-close telegraph: the beat before the door slams it flashes this colour (C6).
@export var warn_color: Color = Color(1.0, 0.117647, 0.352941, 1.0)
@export var warn_emission_energy: float = 3.0

@onready var door_body: Node3D = get_node_or_null("DoorBody")
@onready var hitbox: Hitbox3D = get_node_or_null("DoorBody/Hitbox3D")

var initial_y: float
var tween: Tween
var local_beat_counter: int = 0
var is_closed: bool = false
var is_warning: bool = false
var _material: StandardMaterial3D
var _rest_color: Color
var _rest_energy: float = 0.0

func _ready() -> void:
	if not door_body:
		door_body = self
	
	if not hitbox:
		# Search children
		for child in door_body.get_children():
			if child is Hitbox3D:
				hitbox = child
				break
		if not hitbox:
			hitbox = Hitbox3D.new()
			door_body.add_child(hitbox)

	initial_y = door_body.position.y
	hitbox.is_active = false

	# The door's glow material is a shared resource: flash a private copy.
	if door_body is CSGPrimitive3D and door_body.material is StandardMaterial3D:
		_material = (door_body.material as StandardMaterial3D).duplicate() as StandardMaterial3D
		door_body.material = _material
		_rest_color = _material.emission
		_rest_energy = _material.emission_energy_multiplier
	
	hitbox.collision_layer = 8192
	hitbox.collision_mask = 1024
	if not hitbox.damage_info:
		hitbox.damage_info = DamageInfo.new()
	hitbox.damage_info.amount = damage
	hitbox.damage_info.source = self
	
	# Create a dummy CollisionShape3D if none exists, so it can detect overlaps in tests
	var has_shape = false
	for child in hitbox.get_children():
		if child is CollisionShape3D:
			has_shape = true
			break
	if not has_shape:
		var shape = CollisionShape3D.new()
		shape.shape = BoxShape3D.new()
		hitbox.add_child(shape)
		
	SignalBus.beat.connect(_on_beat)

func _on_beat(layer: String, beat_index: int) -> void:
	if layer != "primary":
		return
		
	local_beat_counter = (local_beat_counter + 1) % close_beat_interval
	
	# One beat before the slam: flash the warning colour.
	if local_beat_counter == (close_beat_interval - 1) % close_beat_interval and not is_closed:
		_set_warning(true)

	if local_beat_counter == 0:
		close_door()
	elif local_beat_counter == closed_duration_beats % close_beat_interval:
		open_door()

func close_door() -> void:
	if tween:
		tween.kill()
	_set_warning(false)
	is_closed = true
	tween = create_tween()
	tween.tween_property(door_body, "position:y", initial_y - slide_distance, close_duration)\
		.set_trans(Tween.TRANS_QUAD)\
		.set_ease(Tween.EASE_IN)
	tween.tween_callback(func():
		hitbox.is_active = true
		SignalBus.camera_shake_requested.emit(0.3, 0.1)
	)

func open_door() -> void:
	if tween:
		tween.kill()
	is_closed = false
	hitbox.is_active = false
	tween = create_tween()
	tween.tween_property(door_body, "position:y", initial_y, open_duration)\
		.set_trans(Tween.TRANS_QUAD)\
		.set_ease(Tween.EASE_OUT)

## Warning flash on/off (no-op when the door has no StandardMaterial3D to drive).
func _set_warning(active: bool) -> void:
	is_warning = active
	if _material == null:
		return
	_material.emission_enabled = true
	_material.emission = warn_color if active else _rest_color
	_material.emission_energy_multiplier = warn_emission_energy if active else _rest_energy
