extends "res://tests/framework/test_case.gd"

# H2: grunts hold position at a ledge instead of chasing into the pit (knockback still can
# push them in), scene-placed grunts with a wake_zone wake on their zone entry instead of
# through walls, and the Zone 2 toxic water burns grunts through the one-way damage path.

const RUNNER_SCENE := "res://characters/enemies/runner/runner.tscn"
const ZONE_07 := "SECTOR 07 — ENFORCER"
const ZONE_06 := "SECTOR 06 — PLAZA BRAWL"

var _nodes: Array[Node] = []

func _keep(node: Node) -> Node:
	_nodes.append(node)
	return node

func after_each() -> void:
	super.after_each()
	for n in _nodes:
		if is_instance_valid(n):
			n.queue_free()
	_nodes.clear()

func _make_platform(top_center: Vector3, size: Vector3) -> StaticBody3D:
	var body := StaticBody3D.new() # layer 1 = world
	var shape := CollisionShape3D.new()
	var box := BoxShape3D.new()
	box.size = size
	shape.shape = box
	body.add_child(shape)
	add_child(body)
	body.global_position = top_center - Vector3(0.0, size.y * 0.5, 0.0)
	return _keep(body) as StaticBody3D

func _spawn_runner(pos: Vector3, wake_zone: String = "") -> RunnerEnemy:
	var runner: RunnerEnemy = load(RUNNER_SCENE).instantiate()
	runner.position = pos
	runner.wake_zone = wake_zone
	add_child(runner)
	return _keep(runner) as RunnerEnemy

func _spawn_nick_stub(pos: Vector3) -> Node3D:
	var nick := Node3D.new()
	add_child(nick)
	nick.global_position = pos
	return _keep(nick) as Node3D

func test_runner_holds_at_a_ledge_instead_of_chasing_off_it() -> void:
	var origin := Vector3(0.0, 0.0, 8100.0)
	_make_platform(origin, Vector3(2.0, 1.0, 2.0)) # top at y 0, x -1..1
	var runner := _spawn_runner(origin + Vector3(0.0, 0.95, 0.0))
	var nick := _spawn_nick_stub(origin + Vector3(6.0, 0.9, 0.0)) # beyond the edge
	runner.player = nick
	runner.is_active = true
	for i in 60: # one second
		await get_tree().physics_frame
	assert_gt(runner.global_position.y, -0.1, "The runner must not fall off the platform (y %.2f)" % runner.global_position.y)
	assert_lt(runner.global_position.x - origin.x, 1.0, "...it stops at the edge (x %.2f)" % (runner.global_position.x - origin.x))
	assert_gt(runner.global_position.x - origin.x, 0.1, "...after really chasing toward Nick on solid floor")

func test_ledge_probe_allows_a_one_metre_step_down() -> void:
	var origin := Vector3(0.0, 0.0, 8110.0)
	var upper := _make_platform(origin, Vector3(2.0, 1.0, 2.0))
	var lower := _make_platform(origin + Vector3(3.0, -1.0, 0.0), Vector3(4.0, 1.0, 2.0))
	await get_tree().physics_frame
	var runner := _spawn_runner(origin + Vector3(0.6, 0.95, 0.0))
	await get_tree().physics_frame
	assert_true(EnemyStats.has_floor_ahead(runner, Vector3.RIGHT, EnemyStats.feet_offset_of(runner)), "A 1 m step down (the Zone 5 tiers) still counts as floor")
	# Drop both platforms 10 m: the same edge is now a pit-deep drop.
	upper.global_position.y -= 10.0
	lower.global_position.y -= 10.0
	await get_tree().physics_frame
	await get_tree().physics_frame
	assert_false(EnemyStats.has_floor_ahead(runner, Vector3.RIGHT, EnemyStats.feet_offset_of(runner)), "A pit-deep drop does not")

func test_zone_gated_runner_ignores_distance_and_wakes_on_its_zone() -> void:
	var runner := _spawn_runner(Vector3(0.0, 50.0, 8120.0), "07")
	runner.set_physics_process(false)
	runner.player = _spawn_nick_stub(Vector3(5.0, 50.0, 8120.0)) # well inside aggro_range
	runner._on_beat("primary", 1)
	runner._on_beat("primary", 2)
	assert_false(runner.is_active, "A wake_zone grunt stays dormant across beats with Nick 5 m away")
	SignalBus.zone_entered.emit(ZONE_06)
	assert_false(runner.is_active, "Another zone does not wake it")
	SignalBus.zone_entered.emit(ZONE_07)
	assert_true(runner.is_active, "Its own zone entry wakes it")

func test_runner_without_wake_zone_keeps_distance_aggro() -> void:
	var runner := _spawn_runner(Vector3(0.0, 50.0, 8130.0))
	runner.set_physics_process(false)
	runner.player = _spawn_nick_stub(Vector3(5.0, 50.0, 8130.0))
	runner._on_beat("primary", 1)
	assert_true(runner.is_active, "Wave/plain grunts still wake by distance")

func test_toxic_pit_burns_a_runner_on_the_beat() -> void:
	var origin := Vector3(0.0, 0.0, 8140.0)
	var pit: ToxicPit = load("res://levels/components/toxic_pit.tscn").instantiate()
	pit.position = origin # volume spans y -2..0 around the origin
	add_child(pit)
	_keep(pit)
	var runner := _spawn_runner(origin + Vector3(0.0, -1.0, 0.0))
	runner.set_physics_process(false) # float in the water
	for i in 3:
		await get_tree().physics_frame
	var before := runner.health_component.current_health
	pit._on_beat("primary", 1)
	assert_lt(runner.health_component.current_health, before, "A runner standing in the toxic water loses HP on a beat")
	assert_almost_eq(before - runner.health_component.current_health, pit.damage_per_beat, 0.001, "...the pit damage per beat")
	pit._on_beat("offbeat", 1)
	assert_almost_eq(before - runner.health_component.current_health, pit.damage_per_beat, 0.001, "Only primary beats burn")

	var flags := {"died": false}
	var on_died := func(_pos: Vector3): flags.died = true
	SignalBus.enemy_died.connect(on_died)
	runner.health_component.current_health = 1.0
	pit._on_beat("primary", 2)
	assert_true(flags.died, "A lethal tick kills through the normal death path (scrap + enemy_died)")
	SignalBus.enemy_died.disconnect(on_died)
