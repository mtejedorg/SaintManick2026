extends "res://tests/framework/test_case.gd"

## Q4: chain reach vs knockback. The REAL player.tscn swings full chains at an UNFROZEN
## runner.tscn standing 1.5 m in front of Nick, on real physics frames and the real chain
## timing (every next press buffered as early as the combo window takes it). The knockback
## of the opening hits must not push the target out of reach of the finisher: every hit of
## the chain lands. test_combo_hit_registration freezes the runner to isolate registration;
## this one keeps the drift in.

const PLAYER_SCENE := "res://characters/player/player.tscn"
const RUNNER_SCENE := "res://characters/enemies/runner/runner.tscn"
## Far from every other test body.
const ORIGIN := Vector3(0.0, 0.0, 7000.0)
const START_GAP := 1.5

var _hits: int = 0
## Runner - Nick distance along the facing at every landed hit.
var _gaps: Array[float] = []
var _arena: Dictionary = {}

func after_each() -> void:
	super.after_each()
	for key in _arena:
		var n: Node = _arena[key]
		if is_instance_valid(n):
			n.queue_free()
	_arena.clear()

func _setup() -> Dictionary:
	_hits = 0
	_gaps.clear()
	var floor_body := StaticBody3D.new()
	var floor_shape := CollisionShape3D.new()
	var box := BoxShape3D.new()
	box.size = Vector3(400.0, 1.0, 40.0)
	floor_shape.shape = box
	floor_body.add_child(floor_shape)
	floor_body.position = ORIGIN + Vector3(0.0, -1.5, 0.0)
	add_child(floor_body)

	var player: PlayerController = load(PLAYER_SCENE).instantiate()
	player.position = ORIGIN
	add_child(player)
	player.health_component.is_invincible = true
	player.is_facing_right = true
	player.mesh.rotation.y = PI / 2.0

	# Unfrozen: physics runs, so knockback really moves it (dormant -- no player to chase).
	var runner: Node = load(RUNNER_SCENE).instantiate()
	runner.position = ORIGIN + Vector3(START_GAP, -0.1, 0.0)
	add_child(runner)
	runner.health_component.max_health = 10000.0
	runner.health_component.current_health = 10000.0

	_arena = {"player": player, "runner": runner, "floor": floor_body}
	SignalBus.hit_landed.connect(func(_pos: Vector3, _type: String):
		_hits += 1
		if is_instance_valid(runner) and is_instance_valid(player):
			_gaps.append(runner.global_position.x - player.global_position.x))
	return _arena

## Runs `chain` ("AAA", "AAB", "BB") through StateAttack: the opener enters the state, every
## later press is buffered each frame until the combo window consumes it. Returns the frames
## it took to leave the attack state.
func _run_chain(chain: String) -> void:
	var arena := _setup()
	var player: PlayerController = arena["player"]
	var attack: Node = player.state_machine.get_node("StateAttack")
	for i in 3:
		await get_tree().physics_frame
	player.pending_attack_heavy = chain[0] == "B"
	player.state_machine.transition_to("StateAttack")
	for i in 150:
		if player.state_machine.current_state != attack:
			break
		var next: int = attack.combo_step + 1
		if next < chain.length():
			attack.buffered_attack = true
			attack.buffered_heavy = chain[next] == "B"
		await get_tree().physics_frame
	# Let the finisher's knockback play out.
	for i in 120:
		await get_tree().physics_frame

func _report(chain: String) -> float:
	var runner: Node3D = _arena["runner"]
	var player: Node3D = _arena["player"]
	var drift: float = runner.global_position.x - (ORIGIN.x + START_GAP)
	var gaps := PackedStringArray()
	for g in _gaps:
		gaps.append("%.2f" % g)
	print("     Q4 %s  hits %d  gap at each hit [%s] m  target drift after the chain %.2f m  (Nick moved %.2f m)" % [chain, _hits, ", ".join(gaps), drift, player.global_position.x - ORIGIN.x])
	return drift

func test_tri_cut_finisher_lands_on_an_unfrozen_runner() -> void:
	await _run_chain("AAA")
	_report("AAA")
	assert_eq(_hits, 3, "A-A-A: all three hits land on a Runner that is free to slide (got %d)" % _hits)

func test_launcher_finisher_lands_and_moves_the_target_about_four_metres() -> void:
	await _run_chain("AAB")
	var drift := _report("AAB")
	assert_eq(_hits, 3, "A-A-B: the Launcher lands after two knockback hits (got %d)" % _hits)
	assert_lt(drift, 6.0, "The Launcher does not fling the target across the arena (%.2f m)" % drift)

func test_battery_ram_finisher_lands_on_an_unfrozen_runner() -> void:
	SaveManager.profile.unlocked_combos.append("BB") # the runner resets the profile afterwards
	await _run_chain("BB")
	_report("BB")
	assert_eq(_hits, 2, "B-B: Battery Ram lands after the opening heavy (got %d)" % _hits)
