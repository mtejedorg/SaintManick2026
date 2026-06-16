class_name PlayerController
extends CharacterBody3D

@export var max_speed: float = 8.0
@export var acceleration: float = 40.0
@export var friction: float = 60.0
@export var jump_force: float = 18.0
@export var gravity_multiplier: float = 3.0
@export var dash_speed: float = 18.0
@export var roll_speed: float = 18.0

@export var current_path: Path3D

var can_double_jump: bool = true
var is_facing_right: bool = true
var is_jump_enabled: bool = true

@onready var state_machine: Node = $StateMachine
@onready var mesh: MeshInstance3D = $MeshInstance3D
@onready var katana_hitbox: Area3D = $MeshInstance3D/KatanaHitbox
@onready var health_component: HealthComponent = $HealthComponent

func _ready() -> void:
	health_component.is_player = true
	var gm = get_node_or_null("/root/GameManager")
	if gm:
		health_component.max_health = gm.max_hp
		health_component.current_health = gm.current_hp
		health_component.max_shield = gm.max_shield
		health_component.current_shield = gm.current_shield
	health_component.died.connect(_on_died)

func _on_died() -> void:
	# Handled centrally by HealthComponent, but can trigger player-specific visuals here
	pass

func _physics_process(_delta: float) -> void:
	if current_path and current_path.curve:
		# Snap the player X and Z to the closest point on the path to prevent drifting
		var local_pos = current_path.to_local(global_position)
		var closest_pt = current_path.to_global(current_path.curve.get_closest_point(local_pos))
		global_position.x = closest_pt.x
		global_position.z = closest_pt.z

func apply_gravity(delta: float) -> void:
	if not is_on_floor():
		velocity += get_gravity() * gravity_multiplier * delta
	else:
		can_double_jump = true

func get_movement_input() -> Vector2:
	return Vector2(
		Input.get_axis("ui_left", "ui_right"),
		Input.get_axis("ui_up", "ui_down")
	)

func get_path_direction(input_dir: Vector2) -> Vector3:
	if not current_path or not current_path.curve:
		return Vector3(input_dir.x, 0, input_dir.y).normalized() * input_dir.length()
		
	var local_pos = current_path.to_local(global_position)
	var offset = current_path.curve.get_closest_offset(local_pos)
	
	# Sample a point slightly ahead to get the tangent direction
	var current_pt = current_path.to_global(current_path.curve.sample_baked(offset))
	var next_pt = current_path.to_global(current_path.curve.sample_baked(offset + 0.1))
	
	var dir = (next_pt - current_pt).normalized()
	dir.y = 0
	# For Path3D, only the X input moves us along the path
	return dir * input_dir.x

func face_direction(direction: float) -> void:
	if direction == 0:
		return
	is_facing_right = direction > 0
	# Smooth rotation for the 3D MeshInstance3D parent to face left/right.
	# This correctly propagates rotation to both the KatanaHitbox and the CharacterVisual.
	var target_rotation = PI / 2.0 if is_facing_right else -PI / 2.0
	mesh.rotation.y = lerp_angle(mesh.rotation.y, target_rotation, 0.2)
