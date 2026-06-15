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

@onready var state_machine: StateMachine = $StateMachine
@onready var mesh: MeshInstance3D = $MeshInstance3D
@onready var katana_hitbox: Hitbox3D = $MeshInstance3D/KatanaHitbox

func _ready() -> void:
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

func get_movement_input() -> float:
	return Input.get_axis("ui_left", "ui_right")

func get_path_direction(input_dir: float) -> Vector3:
	if not current_path or not current_path.curve:
		return Vector3(input_dir, 0, 0)
		
	var local_pos = current_path.to_local(global_position)
	var offset = current_path.curve.get_closest_offset(local_pos)
	
	# Sample a point slightly ahead to get the tangent direction
	var current_pt = current_path.to_global(current_path.curve.sample_baked(offset))
	var next_pt = current_path.to_global(current_path.curve.sample_baked(offset + 0.1))
	
	var dir = (next_pt - current_pt).normalized()
	dir.y = 0 # Keep movement purely horizontal along the path
	return dir * input_dir

func face_direction(direction: float) -> void:
	if direction == 0:
		return
	is_facing_right = direction > 0
	# Smooth rotation for the 3D mesh to face left/right
	var target_rotation = PI / 2.0 if is_facing_right else -PI / 2.0
	mesh.rotation.y = lerp_angle(mesh.rotation.y, target_rotation, 0.2)
