extends PlayerState

@export var dash_duration: float = 0.25
var dash_timer: float = 0.0
var dash_direction: Vector2 = Vector2.RIGHT

func enter() -> void:
	if not player and owner:
		player = owner as PlayerController
	if player and player.health_component:
		player.health_component.is_invincible = true
	dash_timer = dash_duration
	var input_dir = player.get_movement_input() if player else Vector2.ZERO
	dash_direction = input_dir if input_dir != Vector2.ZERO else (Vector2.RIGHT if player and player.is_facing_right else Vector2.LEFT)
	if player:
		player.velocity.y = 0
	if player and player.animation_controller:
		player.animation_controller.play("dash")

func exit() -> void:
	if player and player.health_component:
		player.health_component.is_invincible = false

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
