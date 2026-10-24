extends "res://tests/framework/test_case.gd"

## D7: scene-placed grunts stay dormant (no chase, no telegraph, not counted by the
## IntensityController) until Nick is within EnemyStats.aggro_range, and grunts that
## fall out of the world despawn silently instead of living forever at y -> -inf.

func _spawn_runner(pos: Vector3, player: Node3D) -> RunnerEnemy:
	var runner: RunnerEnemy = load("res://characters/enemies/runner/runner.tscn").instantiate()
	runner.position = pos
	add_child(runner)
	runner.player = player # what _ready resolves from current_scene/Player in the real slice
	return runner

func test_runner_below_kill_plane_despawns_silently() -> void:
	var runner := _spawn_runner(Vector3(0.0, -25.0, 3000.0), null)
	var flags = {"died": false}
	var on_died = func(_p): flags.died = true
	SignalBus.enemy_died.connect(on_died)
	var scrap_before: int = GameManager.scrap

	await get_tree().physics_frame
	assert_true(not is_instance_valid(runner) or runner.is_queued_for_deletion(), "A runner below the kill plane should despawn after one physics tick")
	await get_tree().process_frame
	assert_false(is_instance_valid(runner), "The fallen runner should be freed")
	assert_false(flags.died, "Kill-plane despawn must not emit enemy_died")
	assert_eq(GameManager.scrap, scrap_before, "Kill-plane despawn must not award scrap")
	SignalBus.enemy_died.disconnect(on_died)

func test_far_runner_stays_dormant_and_near_runner_wakes_on_beat() -> void:
	var player := Node3D.new()
	add_child(player)
	player.global_position = Vector3(0.0, 0.0, 3000.0)

	var far := _spawn_runner(Vector3(40.0, 0.0, 3000.0), player)
	var near := _spawn_runner(Vector3(10.0, 0.0, 3000.0), player)
	assert_false(far.is_active, "Scene-placed runners start dormant")
	assert_false(near.is_active, "Scene-placed runners start dormant")

	far._on_beat("primary", 1)
	near._on_beat("primary", 1)
	assert_false(far.is_active, "A runner 40 m away (aggro_range %.0f) must stay dormant" % far.stats.aggro_range)
	assert_eq(far.attack_step, 0, "A dormant runner never telegraphs")
	assert_true(near.is_active, "A runner within aggro_range should wake on the next primary beat")

	# Dormant grunts don't chase: one physics tick leaves the far runner's x velocity at 0.
	await get_tree().physics_frame
	assert_almost_eq(far.velocity.x, 0.0, 0.001, "A dormant runner must not chase")

	far.queue_free()
	near.queue_free()
	player.queue_free()

func test_slice_at_load_rests_at_base_tempo() -> void:
	# Real slice, Nick at x=0: the scene-placed Zone 2/7/8 runners and the dormant bosses
	# must not drive the tempo. Zone triggers are disarmed so only the at-load state counts
	# (the Zone 1 trigger straddles x=0 and would legitimately spawn its first wave).
	var ic: IntensityController = Conductor.intensity_controller
	if not SignalBus.beat.is_connected(ic._on_beat):
		SignalBus.beat.connect(ic._on_beat)
	ic._boss_active = false
	var saved_target: float = Conductor.target_bpm

	var slice: Node3D = (load("res://levels/slice/vertical_slice.tscn") as PackedScene).instantiate()
	add_child(slice)
	var player: Node3D = slice.get_node("Player")
	player.global_position = Vector3(0.0, 1.0, 0.0)
	for area in slice.find_children("*", "Area3D", false, true):
		if area.get_parent() == slice and not (area is Hitbox3D) and not (area is Hurtbox3D):
			area.set_deferred("monitoring", false)
	for grunt in slice.find_children("*", "CharacterBody3D", true, false):
		if "is_active" in grunt and "player" in grunt:
			grunt.player = player # _ready resolved current_scene/Player — the suite's dummy scene

	# Two primary beats so the IntensityController re-evaluates with grunts' aggro checks done.
	var beats = [0]
	var on_beat = func(layer, _i): if layer == "primary": beats[0] += 1
	SignalBus.beat.connect(on_beat)
	var guard := 0
	while beats[0] < 2 and guard < 240:
		await get_tree().process_frame
		guard += 1
	SignalBus.beat.disconnect(on_beat)

	assert_eq(ic.get_active_enemy_count(), 0, "No enemy should be active at load with Nick at x=0")
	assert_eq(Conductor.target_bpm, 128.0, "The slice should rest at 128 BPM at load")

	slice.free()
	Conductor.target_bpm = saved_target
