class_name EscapeCollapsingHazard
extends Node3D

@export var shake_duration: float = 0.5
@export var fall_distance: float = 10.0
@export var fall_duration: float = 0.5
@export var reset_delay: float = 3.0
@export var shake_amplitude: float = 0.1

@onready var platform_body: StaticBody3D = get_node_or_null("PlatformBody")
@onready var collision_shape: CollisionShape3D = get_node_or_null("PlatformBody/CollisionShape3D")
@onready var step_detector: Area3D = get_node_or_null("StepDetector")

var initial_y: float
var tween: Tween
var is_triggered: bool = false
var is_shaking: bool = false
var shake_timer: float = 0.0

func _ready() -> void:
	if not platform_body:
		platform_body = StaticBody3D.new()
		add_child(platform_body)
	if not collision_shape:
		collision_shape = CollisionShape3D.new()
		collision_shape.shape = BoxShape3D.new()
		platform_body.add_child(collision_shape)
	if not step_detector:
		step_detector = Area3D.new()
		var shape = CollisionShape3D.new()
		shape.shape = BoxShape3D.new()
		step_detector.add_child(shape)
		add_child(step_detector)

	initial_y = platform_body.position.y
	step_detector.body_entered.connect(_on_body_entered)

func _on_body_entered(body: Node3D) -> void:
	if is_triggered:
		return
	if body is PlayerController:
		trigger_collapse()

func trigger_collapse() -> void:
	is_triggered = true
	is_shaking = true
	shake_timer = shake_duration
	
	if tween:
		tween.kill()
	
	# After shake_duration, collapse
	get_tree().create_timer(shake_duration).timeout.connect(_collapse)

func _process(delta: float) -> void:
	if is_shaking:
		shake_timer -= delta
		if shake_timer <= 0.0:
			is_shaking = false
			platform_body.position = Vector3(0, initial_y, 0)
		else:
			platform_body.position = Vector3(
				randf_range(-shake_amplitude, shake_amplitude),
				initial_y + randf_range(-shake_amplitude, shake_amplitude),
				randf_range(-shake_amplitude, shake_amplitude)
			)

func _collapse() -> void:
	is_shaking = false
	platform_body.position = Vector3(0, initial_y, 0)
	
	# Disable collision
	collision_shape.set_deferred("disabled", true)
	
	# Fall Tween
	tween = create_tween()
	tween.tween_property(platform_body, "position:y", initial_y - fall_distance, fall_duration)\
		.set_trans(Tween.TRANS_QUAD)\
		.set_ease(Tween.EASE_IN)
		
	# Reset after delay
	get_tree().create_timer(reset_delay).timeout.connect(reset_platform)

func reset_platform() -> void:
	if tween:
		tween.kill()
	
	# Move back and enable collision
	platform_body.position.y = initial_y
	collision_shape.set_deferred("disabled", false)
	is_triggered = false
	is_shaking = false
