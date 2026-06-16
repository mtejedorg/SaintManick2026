extends "res://tests/framework/test_case.gd"

# Regression: falling out of the world must return Nick to his last safe ground and cost HP
# (never an infinite fall, never a full level reload).
func test_fall_returns_to_safe_position_and_costs_hp() -> void:
	GameManager.is_test = true
	GameManager.current_lives = 3

	var player_scene = load("res://characters/player/player.tscn")
	var player = player_scene.instantiate()
	add_child(player)

	# Isolate HP from shield for a clean assertion.
	player.health_component.max_shield = 0.0
	player.health_component.current_shield = 0.0
	player.health_component.max_health = 120.0
	player.health_component.current_health = 120.0
	player.fall_damage = 20.0

	player.current_path = null
	var safe := Vector3(10.0, 1.0, 0.0)
	player.last_safe_position = safe
	var lives_before := GameManager.current_lives

	# Drop below the kill plane.
	player.global_position = Vector3(0.0, PlayerController.FALL_KILL_Y - 5.0, 0.0)
	player._physics_process(0.016)

	assert_eq(player.global_position, safe, "Fall should return Nick to his last safe position")
	assert_eq(player.health_component.current_health, 100.0, "Fall should cost fall_damage HP")
	assert_eq(GameManager.current_lives, lives_before, "A survivable fall must NOT cost a life or reload")
	assert_eq(player.velocity, Vector3.ZERO, "Velocity should be reset after a fall")

	# Above the kill plane: no fall handling.
	player.global_position = Vector3(0.0, 5.0, 0.0)
	player.health_component.current_health = 100.0
	player._physics_process(0.016)
	assert_eq(player.health_component.current_health, 100.0, "Above the kill plane should not cost HP")

	player.queue_free()
