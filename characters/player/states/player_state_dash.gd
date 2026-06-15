extends PlayerState

var dash_duration: float = 0.15
var dash_timer: float = 0.0
var dash_direction: float = 1.0

func enter() -> void:
	dash_timer = dash_duration
	dash_direction = 1.0 if player.is_facing_right else -1.0
	player.velocity.y = 0

func physics_update(delta: float) -> void:
	dash_timer -= delta
	
	var path_dir = player.get_path_direction(dash_direction)
	player.velocity.x = path_dir.x * player.dash_speed
	player.velocity.z = path_dir.z * player.dash_speed
	
	player.move_and_slide()
	
	if dash_timer <= 0:
		if not player.is_on_floor():
			transition_requested.emit("StateAirborne")
		else:
			transition_requested.emit("StateIdle")
