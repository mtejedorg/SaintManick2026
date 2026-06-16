extends "res://tests/framework/test_case.gd"

# Regression: falling out of the world must cost a life via the universal death rule,
# never an infinite fall.
func test_fall_out_of_world_costs_life() -> void:
	GameManager.is_test = true
	GameManager.max_hp = 120.0
	GameManager.current_hp = 120.0
	GameManager.max_shield = 40.0
	GameManager.current_shield = 40.0
	GameManager.current_lives = 3

	var player_scene = load("res://characters/player/player.tscn")
	var player = player_scene.instantiate()
	add_child(player)

	var lives_before := GameManager.current_lives

	# No current_path -> no snap; drop the player below the kill plane.
	player.current_path = null
	player.global_position = Vector3(0, PlayerController.FALL_KILL_Y - 5.0, 0)

	player._physics_process(0.016)

	assert_true(player._fall_handled, "Fall should be handled once below the kill plane")
	assert_eq(player.health_component.current_health, 0.0, "Falling out of the world should zero HP")
	assert_eq(GameManager.current_lives, lives_before - 1, "Falling should cost exactly one life")

	# Above the kill plane must NOT trigger a fall death.
	var player2 = player_scene.instantiate()
	add_child(player2)
	player2.current_path = null
	player2.global_position = Vector3(0, 5.0, 0)
	player2._physics_process(0.016)
	assert_false(player2._fall_handled, "Above the kill plane should not trigger a fall death")

	player.queue_free()
	player2.queue_free()
