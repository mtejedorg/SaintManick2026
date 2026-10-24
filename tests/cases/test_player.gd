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

# GDD §3.1: up/down are dead inputs while plane-locked (side-scroll); they only steer in
# free (top-down) movement.
func test_up_down_ignored_while_plane_locked() -> void:
	var player = load("res://characters/player/player.tscn").instantiate()
	add_child(player)
	var path := Path3D.new()
	path.curve = Curve3D.new()
	path.curve.add_point(Vector3.ZERO)
	path.curve.add_point(Vector3(10.0, 0.0, 0.0))
	add_child(path)

	Input.action_press("ui_up")
	player.current_path = path
	var locked: Vector2 = player.get_movement_input()
	player.current_path = null
	var free: Vector2 = player.get_movement_input()
	Input.action_release("ui_up")

	assert_eq(locked, Vector2.ZERO, "Up should do nothing while plane-locked to a Path3D")
	assert_eq(free, Vector2(0.0, -1.0), "Up should still steer in free (top-down) movement")

	path.queue_free()
	player.queue_free()
