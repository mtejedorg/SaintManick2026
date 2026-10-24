extends "res://tests/framework/test_case.gd"

## Headless hit-registration tests: the REAL player.tscn swings at the REAL runner.tscn
## placed 1.6 m in front of Nick in the fighting lane (+X, facing right) and we count
## SignalBus.hit_landed. Physics frames actually step, so these exercise the hitbox
## geometry (D0) and the Area3D re-overlap behaviour across chained hits (D8).

var _hits: int = 0

func _on_hit_landed(_pos: Vector3, _type: String) -> void:
	_hits += 1

## Builds floor + player (facing right) + runner 1.6 m ahead. The runner is frozen in place
## (no physics process, huge HP) so the test isolates hit REGISTRATION from knockback drift.
func _setup_arena() -> Dictionary:
	_hits = 0
	var floor_body := StaticBody3D.new()
	var floor_shape := CollisionShape3D.new()
	var box := BoxShape3D.new()
	box.size = Vector3(40.0, 1.0, 40.0)
	floor_shape.shape = box
	floor_body.add_child(floor_shape)
	floor_body.position = Vector3(0.0, -1.5, 0.0)
	add_child(floor_body)

	var player: PlayerController = load("res://characters/player/player.tscn").instantiate()
	player.position = Vector3.ZERO
	add_child(player)
	player.health_component.is_invincible = true
	player.is_facing_right = true
	player.mesh.rotation.y = PI / 2.0

	var runner: Node = load("res://characters/enemies/runner/runner.tscn").instantiate()
	runner.position = Vector3(1.6, -0.1, 0.0)
	add_child(runner)
	runner.set_physics_process(false)
	runner.health_component.max_health = 10000.0
	runner.health_component.current_health = 10000.0

	SignalBus.hit_landed.connect(_on_hit_landed)
	return {"player": player, "runner": runner, "floor": floor_body}

func _teardown(arena: Dictionary) -> void:
	if SignalBus.hit_landed.is_connected(_on_hit_landed):
		SignalBus.hit_landed.disconnect(_on_hit_landed)
	for key in arena:
		var n: Node = arena[key]
		if is_instance_valid(n):
			n.queue_free()
	Engine.time_scale = 1.0

func _physics_frames(count: int) -> void:
	for i in count:
		await get_tree().physics_frame

func test_single_light_attack_hits_runner_in_front() -> void:
	var arena := _setup_arena()
	var player: PlayerController = arena["player"]
	await _physics_frames(3)
	player.state_machine._on_transition_requested("StateAttack")
	await _physics_frames(30)
	assert_eq(_hits, 1, "One light attack must land on a Runner 1.6 m in front (got %d hits)" % _hits)
	_teardown(arena)
