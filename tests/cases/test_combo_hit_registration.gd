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

## Drives StateAttack through a full chain on real physics frames, re-buffering the
## next press every frame (the combo window consumes it) — the headless equivalent of
## mashing. Returns the attack state's final combo_step.
func _drive_chain(player: PlayerController, heavy: bool, frames: int) -> int:
	var attack_state = player.state_machine.get_node("StateAttack")
	var max_step := 0
	for i in frames:
		if player.state_machine.current_state == attack_state:
			attack_state.buffered_attack = true
			attack_state.buffered_heavy = heavy
			max_step = maxi(max_step, attack_state.combo_step)
		await get_tree().physics_frame
	return max_step

func test_light_chain_registers_every_hit_on_a_target_still_in_the_box() -> void:
	var arena := _setup_arena()
	var player: PlayerController = arena["player"]
	await _physics_frames(3)
	player.state_machine._on_transition_requested("StateAttack")
	var max_step: int = await _drive_chain(player, false, 90)
	print("    D8 A-A-A hit_landed count = %d (combo steps reached: %d)" % [_hits, max_step + 1])
	assert_eq(max_step, 2, "Precondition: the chain should reach its third hit")
	assert_eq(_hits, 3, "A-A-A on a Runner that stays inside the katana box should land 3 hits (got %d)" % _hits)
	_teardown(arena)

func test_battery_ram_ends_the_chain_without_a_third_hit() -> void:
	var had_bb: bool = SaveManager.profile.unlocked_combos.has("BB")
	if not had_bb:
		SaveManager.profile.unlocked_combos.append("BB")
	var arena := _setup_arena()
	var player: PlayerController = arena["player"]
	var attack_state = player.state_machine.get_node("StateAttack")
	await _physics_frames(3)

	# B-B via the state's own entry path: enter as a heavy, then mash heavy.
	player.state_machine._on_transition_requested("StateAttack")
	attack_state.current_sequence.clear()
	attack_state._start_attack(true)
	var max_step: int = await _drive_chain(player, true, 120)

	assert_eq("".join(attack_state.current_sequence), "BB", "Battery Ram should be the full sequence")
	assert_eq(max_step, 1, "Battery Ram (B-B) must end the chain — no third generic hit")
	assert_eq(player.state_machine.current_state.name, "StateIdle", "The chain should end back in Idle")

	# A fresh attack is uncapped again.
	player.state_machine._on_transition_requested("StateAttack")
	assert_eq(attack_state.max_combo_step, 2, "enter() should reset max_combo_step")

	_teardown(arena)
	if not had_bb:
		SaveManager.profile.unlocked_combos.erase("BB")
