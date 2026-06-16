class_name CeilingPiston
extends Node3D

@export var beat_interval: int = 4
@export var min_beat_interval: int = 2
@export var slam_distance: float = 4.0
@export var slam_duration: float = 0.1
@export var hold_duration: float = 0.2
@export var retract_duration: float = 0.5
@export var accelerate_pattern: bool = false
@export var start_accelerating_distance: float = 15.0
@export var damage: float = 15.0

@onready var piston_body: Node3D = $PistonBody
@onready var hitbox: Hitbox3D = $PistonBody/Hitbox3D

var initial_y: float
var tween: Tween
var player: Node3D
var local_beat_counter: int = 0

func _ready() -> void:
	initial_y = piston_body.position.y
	hitbox.is_active = false
	
	hitbox.collision_layer = 8192 # Layer 14
	hitbox.collision_mask = 1024 # Layer 11
	hitbox.damage_info = DamageInfo.new()
	hitbox.damage_info.amount = damage
	hitbox.damage_info.knockback = 5.0
	hitbox.damage_info.source = self
	
	player = get_tree().current_scene.get_node_or_null("Player")
	SignalBus.beat.connect(_on_beat)

func _on_beat(layer: String, beat_index: int) -> void:
	if layer != "primary":
		return
		
	local_beat_counter += 1
	
	# Find player dynamically if not set
	if not player:
		player = get_tree().current_scene.get_node_or_null("Player")
		
	var current_interval = beat_interval
	if accelerate_pattern and player:
		var distance = global_position.distance_to(player.global_position)
		if distance < start_accelerating_distance:
			var t = clampf((start_accelerating_distance - distance) / start_accelerating_distance, 0.0, 1.0)
			current_interval = int(lerp(float(beat_interval), float(min_beat_interval), t))
			current_interval = max(1, current_interval)
			
	if local_beat_counter % current_interval == 0:
		slam()

func slam() -> void:
	if tween:
		tween.kill()
		
	piston_body.position.y = initial_y
	hitbox.is_active = false
	
	tween = create_tween()
	# Slam down rapidly
	tween.tween_property(piston_body, "position:y", initial_y - slam_distance, slam_duration)\
		.set_trans(Tween.TRANS_QUAD)\
		.set_ease(Tween.EASE_IN)
	
	# Activate hitbox on impact
	tween.tween_callback(func():
		hitbox.is_active = true
		SignalBus.camera_shake_requested.emit(0.4, 0.2)
	)

	
	# Hold
	tween.tween_interval(hold_duration)
	
	# Deactivate hitbox and retract slowly
	tween.tween_callback(func(): hitbox.is_active = false)
	tween.tween_property(piston_body, "position:y", initial_y, retract_duration)\
		.set_trans(Tween.TRANS_QUAD)\
		.set_ease(Tween.EASE_OUT)
