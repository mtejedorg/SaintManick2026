class_name EscapeFallingHazard
extends Node3D

@export var beat_interval: int = 8
@export var telegraph_beats: int = 2
@export var reset_delay_beats: int = 3
@export var fall_distance: float = 6.0
@export var fall_duration: float = 0.15
@export var retract_duration: float = 1.0
@export var damage: float = 15.0

@onready var hazard_body: Node3D = get_node_or_null("HazardBody")
@onready var hitbox: Hitbox3D = get_node_or_null("HazardBody/Hitbox3D")
@export var warning_mesh: MeshInstance3D # If assigned, we flash its emission or visibility

var initial_y: float
var tween: Tween
var local_beat_counter: int = 0
var is_telegraphing: bool = false
var flash_state: bool = false

func _ready() -> void:
	if not hazard_body:
		hazard_body = self
	
	if not hitbox:
		# Search children
		for child in hazard_body.get_children():
			if child is Hitbox3D:
				hitbox = child
				break
		if not hitbox:
			hitbox = Hitbox3D.new()
			hazard_body.add_child(hitbox)

	initial_y = hazard_body.position.y
	hitbox.is_active = false
	
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
		
	local_beat_counter = (local_beat_counter + 1) % beat_interval
	
	# Determine behavior based on counter
	var telegraph_start = (beat_interval - telegraph_beats) % beat_interval
	
	if local_beat_counter == telegraph_start:
		start_telegraph()
	elif local_beat_counter == 0:
		fall()
	elif local_beat_counter == reset_delay_beats % beat_interval:
		retract()
		
	# Flash warning if telegraphing
	if is_telegraphing:
		flash_state = not flash_state
		_update_warning_visuals(flash_state)
	else:
		_update_warning_visuals(false)

func start_telegraph() -> void:
	is_telegraphing = true
	flash_state = true

func fall() -> void:
	is_telegraphing = false
	_update_warning_visuals(false)
	
	if tween:
		tween.kill()
	tween = create_tween()
	tween.tween_property(hazard_body, "position:y", initial_y - fall_distance, fall_duration)\
		.set_trans(Tween.TRANS_QUAD)\
		.set_ease(Tween.EASE_IN)
	tween.tween_callback(func():
		hitbox.is_active = true
		SignalBus.camera_shake_requested.emit(0.5, 0.2)
	)

func retract() -> void:
	if tween:
		tween.kill()
	hitbox.is_active = false
	tween = create_tween()
	tween.tween_property(hazard_body, "position:y", initial_y, retract_duration)\
		.set_trans(Tween.TRANS_QUAD)\
		.set_ease(Tween.EASE_OUT)

func _update_warning_visuals(active: bool) -> void:
	if warning_mesh:
		warning_mesh.visible = active
