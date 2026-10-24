extends "res://tests/framework/test_case.gd"

## F2: Runner and Bruiser yaw their visual root toward the player / their move direction
## (the NickProto body faces +Z), like PlayerController.face_direction. Dormant grunts keep
## their yaw.

func _spawn(scene_path: String, pos: Vector3, player: Node3D) -> CharacterBody3D:
	var enemy: CharacterBody3D = load(scene_path).instantiate()
	enemy.position = pos
	add_child(enemy)
	enemy.player = player
	enemy.set_physics_process(false) # drive the ticks by hand
	return enemy

func _player_at(pos: Vector3) -> Node3D:
	var player := Node3D.new()
	add_child(player)
	player.global_position = pos
	return player

func test_runner_turns_to_face_player_on_its_left() -> void:
	var player := _player_at(Vector3(-10.0, 0.0, 3500.0))
	var runner := _spawn("res://characters/enemies/runner/runner.tscn", Vector3(0.0, 0.0, 3500.0), player)
	runner.is_active = true
	for i in 30:
		runner._physics_process(0.016)
	assert_almost_eq(runner.mesh_instance.rotation.y, -PI / 2.0, 0.05, "A runner with the player to its left should face -X")
	runner.queue_free()
	player.queue_free()

func test_bruiser_turns_to_face_player_on_its_right() -> void:
	var player := _player_at(Vector3(10.0, 0.0, 3520.0))
	var bruiser := _spawn("res://characters/enemies/bruiser/bruiser.tscn", Vector3(0.0, 0.0, 3520.0), player)
	bruiser.is_active = true
	for i in 30:
		bruiser._physics_process(0.016)
	assert_almost_eq(bruiser.mesh_instance.rotation.y, PI / 2.0, 0.05, "A bruiser with the player to its right should face +X")
	bruiser.queue_free()
	player.queue_free()

func test_dormant_runner_keeps_its_yaw() -> void:
	var player := _player_at(Vector3(-10.0, 0.0, 3540.0))
	var runner := _spawn("res://characters/enemies/runner/runner.tscn", Vector3(0.0, 0.0, 3540.0), player)
	var yaw: float = runner.mesh_instance.rotation.y
	for i in 10:
		runner._physics_process(0.016)
	assert_almost_eq(runner.mesh_instance.rotation.y, yaw, 0.001, "A dormant runner must not turn")
	runner.queue_free()
	player.queue_free()
