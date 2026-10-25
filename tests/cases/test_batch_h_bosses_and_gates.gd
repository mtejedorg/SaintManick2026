extends "res://tests/framework/test_case.gd"

# H1: bosses are never lost to the void (kill plane -> back to their spawn, also on the
# respawn reset), the Zone 7 arena seals behind Nick while the Enforcer fight is live, and
# a cleared top-down room keeps its gates shut until the camera shift back has landed.

const ENFORCER_SCENE := "res://characters/enemies/enforcer/enforcer.tscn"
const HEADLINER_SCENE := "res://characters/enemies/headliner/headliner.tscn"
const ZONE_07 := "SECTOR 07 — ENFORCER"

class MockCameraTarget extends Node3D:
	var current_path: Path3D = null
	var is_jump_enabled: bool = true

func _make_gate() -> StaticBody3D:
	var gate := StaticBody3D.new()
	gate.name = "Z7_EntryGate"
	var col := CollisionShape3D.new()
	col.name = "CollisionShape3D"
	col.shape = BoxShape3D.new()
	col.disabled = true
	gate.add_child(col)
	var visual := CSGBox3D.new()
	visual.name = "Visual"
	visual.visible = false
	gate.add_child(visual)
	return gate

func _spawn_enforcer(pos: Vector3) -> EnforcerEnemy:
	var enforcer: EnforcerEnemy = load(ENFORCER_SCENE).instantiate()
	enforcer.position = pos
	add_child(enforcer)
	enforcer.set_physics_process(false) # stepped by hand
	return enforcer

func test_enforcer_below_the_kill_plane_returns_to_its_spawn() -> void:
	var enforcer := _spawn_enforcer(Vector3(0.0, 2.0, 8000.0))
	var spawn := enforcer.global_position
	enforcer.global_position = Vector3(5.0, EnemyStats.KILL_PLANE_Y - 5.0, 8000.0)
	enforcer.velocity = Vector3(0.0, -30.0, 0.0)
	enforcer._physics_process(0.016)
	assert_true(is_instance_valid(enforcer) and not enforcer.is_queued_for_deletion(), "A boss is never freed by the kill plane")
	assert_lt(enforcer.global_position.distance_to(spawn), 0.001, "The Enforcer is put back at its spawn (%s)" % str(enforcer.global_position))
	assert_eq(enforcer.velocity, Vector3.ZERO, "...at rest")
	enforcer.queue_free()

func test_headliner_below_the_kill_plane_returns_to_its_spawn() -> void:
	var boss: HeadlinerBoss = load(HEADLINER_SCENE).instantiate()
	boss.position = Vector3(0.0, 2.0, 8020.0)
	add_child(boss)
	boss.set_physics_process(false)
	var spawn := boss.global_position
	boss.global_position = Vector3(3.0, EnemyStats.KILL_PLANE_Y - 1.0, 8020.0)
	boss.velocity = Vector3(1.0, -20.0, 0.0)
	boss._physics_process(0.016)
	assert_true(is_instance_valid(boss) and not boss.is_queued_for_deletion(), "The Headliner is never freed by the kill plane")
	assert_lt(boss.global_position.distance_to(spawn), 0.001, "The Headliner is put back at its spawn")
	assert_eq(boss.velocity, Vector3.ZERO, "...at rest")
	boss.queue_free()

func test_enforcer_respawn_reset_restores_its_spawn_position() -> void:
	var enforcer := _spawn_enforcer(Vector3(0.0, 2.0, 8040.0))
	var spawn := enforcer.global_position
	SignalBus.zone_entered.emit(ZONE_07)
	assert_true(enforcer.is_active, "SECTOR 07 activates the Enforcer")
	enforcer.global_position += Vector3(6.0, 0.0, 1.0)
	enforcer.velocity = Vector3(4.0, 0.0, 0.0)
	SignalBus.player_respawned.emit()
	assert_false(enforcer.is_active, "Back to dormant")
	assert_lt(enforcer.global_position.distance_to(spawn), 0.001, "The respawn reset puts the Enforcer back at its spawn")
	assert_eq(enforcer.velocity, Vector3.ZERO, "...at rest")
	enforcer.queue_free()

func test_enforcer_seals_the_arena_entry_while_the_fight_is_live() -> void:
	var gate := _make_gate()
	add_child(gate)
	var col := gate.get_node("CollisionShape3D") as CollisionShape3D
	var visual := gate.get_node("Visual") as Node3D
	var enforcer: EnforcerEnemy = load(ENFORCER_SCENE).instantiate()
	enforcer.position = Vector3(0.0, 2.0, 8060.0)
	enforcer.entry_gate = gate
	add_child(enforcer)
	enforcer.set_physics_process(false)

	SignalBus.zone_entered.emit(ZONE_07)
	await get_tree().process_frame # the collision flip is deferred
	assert_false(col.disabled, "Activation closes the entry gate")
	assert_true(visual.visible, "...and shows it")

	SignalBus.player_respawned.emit()
	await get_tree().process_frame
	assert_true(col.disabled, "The respawn reset re-opens the gate")
	assert_false(visual.visible, "...and hides it")

	SignalBus.zone_entered.emit(ZONE_07)
	await get_tree().process_frame
	assert_false(col.disabled, "Re-entering the zone seals it again")
	enforcer._on_died()
	await get_tree().process_frame
	assert_true(col.disabled, "Defeating the Enforcer opens the gate for good")
	assert_false(visual.visible, "...and hides it")
	if is_instance_valid(enforcer):
		enforcer.queue_free()
	gate.queue_free()

func _make_top_down_encounter(gate: CSGBox3D) -> ZoneEncounter:
	var enc := ZoneEncounter.new()
	var gates: Array[Node3D] = [gate]
	enc.gates = gates
	enc.is_top_down = true
	add_child(enc)
	enc.active = true
	enc.set_gate_locked(true)
	return enc

func test_cleared_top_down_room_stays_shut_until_the_camera_shift_lands() -> void:
	var gate := CSGBox3D.new()
	add_child(gate)
	var enc := _make_top_down_encounter(gate)
	enc._complete_encounter()
	assert_true(enc.completed, "Encounter completed")
	assert_true(gate.use_collision and gate.visible, "Gates stay locked while the camera tweens back")
	SignalBus.camera_shift_finished.emit(true)
	assert_true(gate.use_collision, "A shift INTO top-down does not open the room")
	SignalBus.camera_shift_finished.emit(false)
	assert_false(gate.use_collision, "The landed shift back to side-scroll opens the gates")
	assert_false(gate.visible, "...and hides them")
	# One-shot: a later shift does not touch the gates any more.
	enc.set_gate_locked(true)
	SignalBus.camera_shift_finished.emit(false)
	assert_true(gate.use_collision, "The unlock listener is one-shot")
	enc.queue_free()
	gate.queue_free()

func test_cleared_top_down_room_also_opens_on_respawn() -> void:
	var gate := CSGBox3D.new()
	add_child(gate)
	var enc := _make_top_down_encounter(gate)
	enc._complete_encounter()
	assert_true(gate.use_collision, "Locked while the shift is pending")
	SignalBus.player_respawned.emit()
	assert_false(gate.use_collision, "A respawn never leaves a cleared room shut")
	enc.queue_free()
	gate.queue_free()

func test_side_scroll_encounter_still_unlocks_immediately() -> void:
	var gate := CSGBox3D.new()
	add_child(gate)
	var enc := _make_top_down_encounter(gate)
	enc.is_top_down = false
	enc._complete_encounter()
	assert_false(gate.use_collision, "No camera shift to wait for -- gates open at once")
	enc.queue_free()
	gate.queue_free()

func test_camera_transition_emits_camera_shift_finished_when_it_lands() -> void:
	var camera: DroneCamera = load("res://characters/player/drone_camera.tscn").instantiate()
	add_child(camera)
	var target := MockCameraTarget.new()
	add_child(target)
	camera.target = target
	var got := {"count": 0, "top_down": true}
	var on_finished := func(top_down: bool):
		got.count += 1
		got.top_down = top_down
	SignalBus.camera_shift_finished.connect(on_finished)
	SignalBus.camera_shift_requested.emit(false, null, 0.02)
	var transitioning = camera.state_machine.states["transitioning"]
	assert_eq(got.count, 0, "Nothing is announced before the tween lands")
	await transitioning.current_tween.finished
	assert_eq(got.count, 1, "camera_shift_finished fires once when the tween lands")
	assert_false(got.top_down, "...carrying the side-scroll target")
	SignalBus.camera_shift_finished.disconnect(on_finished)
	camera.queue_free()
	target.queue_free()
