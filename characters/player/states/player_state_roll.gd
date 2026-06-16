extends PlayerState

var roll_duration: float = 0.4
var roll_timer: float = 0.0
var roll_direction: Vector2 = Vector2.RIGHT

func enter() -> void:
	roll_timer = roll_duration
	var input_dir = player.get_movement_input()
	roll_direction = input_dir if input_dir != Vector2.ZERO else (Vector2.RIGHT if player.is_facing_right else Vector2.LEFT)
	player.face_direction(roll_direction.x if roll_direction.x != 0 else roll_direction.y)
	if player.health_component:
		player.health_component.is_invincible = true

func exit() -> void:
	if player.health_component:
		player.health_component.is_invincible = false

func physics_update(delta: float) -> void:
	player.apply_gravity(delta)
	
	roll_timer -= delta
	
	var path_dir = player.get_path_direction(roll_direction)
	player.velocity.x = path_dir.x * player.roll_speed
	player.velocity.z = path_dir.z * player.roll_speed
	
	player.move_and_slide()
	
	if roll_timer <= 0:
		if not player.is_on_floor():
			transition_requested.emit("StateAirborne")
		else:
			transition_requested.emit("StateIdle")

