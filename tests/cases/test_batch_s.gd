extends "res://tests/framework/test_case.gd"

# Batch S (round-4 level items): S1 a landmark + back-lane dressing kit per zone (decorative
# only, never on the rail), S2 staged wave entrances on the beat, S3 the Headliner's stage,
# S4 the elevator as a ride with stops, S5 the escape climax (third door + third sign).

const SLICE_PATH := "res://levels/slice/vertical_slice.tscn"
const RUNNER_SCENE := "res://characters/enemies/runner/runner.tscn"
const MARQUEE_SCRIPT := "res://levels/components/headliner_marquee.gd"

var _slice: Node3D
var _extra: Array[Node] = []

func before_each() -> void:
	GameManager.is_test = true

func after_each() -> void:
	super.after_each()
	for n in _extra:
		if is_instance_valid(n):
			n.free()
	_extra.clear()
	if is_instance_valid(_slice):
		_slice.free()
	GameManager.has_checkpoint = false
	GameManager.checkpoint_path = null
	GameManager.checkpoint_top_down = true

func _keep(node: Node) -> Node:
	_extra.append(node)
	return node

func _spawn_slice() -> Node3D:
	_slice = (load(SLICE_PATH) as PackedScene).instantiate()
	add_child(_slice)
	return _slice

func _dummy_scene() -> PackedScene:
	var dummy := Node3D.new()
	var scene := PackedScene.new()
	scene.pack(dummy)
	dummy.free()
	return scene

func _wave(scene: PackedScene, count: int, stagger: float, entry: String) -> WaveDef:
	var wave := WaveDef.new()
	var enemies: Array[PackedScene] = []
	for i in count:
		enemies.append(scene)
	wave.enemies = enemies
	wave.stagger_beats = stagger
	wave.entry = entry
	return wave

## A staged spawner far from everything else in the tree, with `markers` markers 3 m apart.
func _staged_spawner(markers: int, origin: Vector3 = Vector3(0.0, 600.0, 3000.0)) -> WaveSpawner:
	var spawner: WaveSpawner = _keep(WaveSpawner.new())
	spawner.staged_entries = true
	add_child(spawner)
	spawner.global_position = origin
	for i in markers:
		var marker := Marker3D.new()
		marker.name = "SpawnPoint%d" % (i + 1)
		spawner.add_child(marker)
		marker.position = Vector3(3.0 * i, 1.0, 0.0)
	return spawner

func _visible_rings(spawner: WaveSpawner) -> int:
	var n := 0
	for child in spawner.get_children():
		if String(child.name).begins_with("EntryRing") and (child as Node3D).visible:
			n += 1
	return n

func _beat() -> void:
	SignalBus.beat.emit("primary", 1)

# --- S2 ------------------------------------------------------------------------------

func test_s2_a_bare_spawner_still_spawns_the_whole_wave_at_once() -> void:
	var spawner: WaveSpawner = _keep(WaveSpawner.new())
	add_child(spawner)
	spawner.add_child(Marker3D.new())
	assert_false(spawner.staged_entries, "Staging is opt-in per spawner")
	spawner.spawn_wave(_wave(_dummy_scene(), 3, 0.5, "drop"))
	assert_eq(spawner.active_enemies.size(), 3, "Legacy spawn: the whole wave in one frame")
	assert_eq(spawner.pending_count(), 0, "...nothing pending")

func test_s2_the_slice_stages_every_spawner_and_beams_in_the_top_down_rims() -> void:
	var slice := _spawn_slice()
	for path in ["Z1_Encounter/Z1_Spawner", "Z3_Encounter/Z3_Spawner", "Z4_Encounter/Z4_Spawner", "Z5_Encounter/Z5_Spawner", "Z6_Encounter/Z6_Spawner", "ElevatorPlatform/ElevatorSpawner"]:
		assert_true((slice.get_node(path) as WaveSpawner).staged_entries, "%s stages its waves" % path)
	for enc_name in ["Z3_Encounter", "Z6_Encounter"]:
		for wave in (slice.get_node(enc_name) as ZoneEncounter).waves:
			assert_eq(wave.entry, "beam", "%s waves beam in (top-down rim)" % enc_name)
	for enc_name in ["Z1_Encounter", "Z4_Encounter", "Z5_Encounter"]:
		for wave in (slice.get_node(enc_name) as ZoneEncounter).waves:
			assert_eq(wave.entry, "drop", "%s waves drop in" % enc_name)
			assert_almost_eq(wave.stagger_beats, 0.5, 0.0001, "%s staggers half a beat" % enc_name)
	var elevator: ElevatorEncounter = slice.get_node("ElevatorEncounter")
	assert_almost_eq(elevator.waves[1].drop_height, 8.0, 0.0001, "Elevator wave 2 drops out of the shaft from +8 m")

func test_s2_arrivals_land_on_the_beat_one_at_a_time_after_a_ring() -> void:
	var spawner := _staged_spawner(3)
	var cleared := {"n": 0}
	spawner.wave_cleared.connect(func(): cleared.n += 1)
	spawner.spawn_wave(_wave(_dummy_scene(), 3, 1.0, "drop"))
	assert_eq(spawner.active_enemies.size(), 0, "Nothing lands in the spawn frame")
	assert_eq(spawner.pending_count(), 3, "Three arrivals pending")
	assert_eq(_visible_rings(spawner), 1, "The first landing spot is ringed one beat early")
	_beat()
	assert_eq(spawner.active_enemies.size(), 1, "Beat 1: the first enemy lands")
	var first: Node3D = spawner.active_enemies[0]
	var marker1: Node3D = spawner.get_node("SpawnPoint1")
	assert_almost_eq(first.global_position.x, marker1.global_position.x, 0.001, "...over its marker")
	assert_almost_eq(first.global_position.y, marker1.global_position.y + 6.0, 0.001, "...released 6 m above it")
	spawner._on_enemy_defeated(first)
	assert_eq(cleared.n, 0, "Killing the only live enemy does not clear a wave with arrivals pending")
	_beat()
	_beat()
	assert_eq(spawner.pending_count(), 0, "All three arrived on beats 2 and 3")
	assert_eq(spawner.active_enemies.size(), 2, "Two still alive")
	for enemy in spawner.active_enemies.duplicate():
		spawner._on_enemy_defeated(enemy)
	assert_eq(cleared.n, 1, "wave_cleared fires once, after the last staggered arrival died")

func test_s2_half_beat_stagger_lands_two_per_beat() -> void:
	var spawner := _staged_spawner(4)
	spawner.spawn_wave(_wave(_dummy_scene(), 4, 0.5, "beam"))
	_beat()
	assert_eq(spawner.active_enemies.size(), 2, "0.5-beat stagger: two arrivals land on beat 1")
	_beat()
	assert_eq(spawner.active_enemies.size(), 4, "...two more on beat 2")
	assert_eq(_visible_rings(spawner), 0, "Rings are released once their enemy has beamed in")

func test_s2_a_respawn_cancels_pending_staggered_spawns() -> void:
	var spawner := _staged_spawner(2)
	var encounter: ZoneEncounter = _keep(ZoneEncounter.new())
	encounter.spawner = spawner
	var waves: Array[WaveDef] = [_wave(_dummy_scene(), 4, 1.0, "drop")]
	encounter.waves = waves
	add_child(encounter)
	encounter.global_position = Vector3(0.0, 600.0, 3100.0)
	var cleared := {"n": 0}
	spawner.wave_cleared.connect(func(): cleared.n += 1)
	encounter._on_body_entered(_keep(PlayerController.new()))
	await get_tree().process_frame # the first wave starts deferred
	assert_gt(spawner.pending_count(), 0, "Arrivals are queued")
	var landed := spawner.active_enemies.size()
	SignalBus.player_respawned.emit()
	assert_eq(spawner.pending_count(), 0, "The respawn cancels every pending arrival")
	assert_eq(_visible_rings(spawner), 0, "...and hides their rings")
	for i in 4:
		_beat()
	assert_eq(spawner.active_enemies.size(), 0, "No enemy lands after the respawn")
	assert_eq(cleared.n, 0, "...and the cancelled wave never reports cleared")
	assert_true(landed <= 1, "At most one arrival could land in the frame before the respawn")

func test_s2_dropped_enemies_land_on_their_markers_with_a_small_shake() -> void:
	var origin := Vector3(0.0, 300.0, 3300.0)
	var floor_body: StaticBody3D = _keep(StaticBody3D.new())
	var shape := CollisionShape3D.new()
	var box := BoxShape3D.new()
	box.size = Vector3(20.0, 1.0, 20.0)
	shape.shape = box
	floor_body.add_child(shape)
	add_child(floor_body)
	floor_body.global_position = origin + Vector3(3.0, -0.5, 0.0)
	var spawner := _staged_spawner(2, origin)
	for marker in spawner.get_children():
		(marker as Node3D).position.y = 0.95 # a grunt's capsule centre over the floor top
	var shakes: Array[float] = []
	SignalBus.camera_shake_requested.connect(func(strength: float, _duration: float): shakes.append(strength))
	spawner.spawn_wave(_wave(load(RUNNER_SCENE), 2, 1.0, "drop"))
	_beat()
	_beat()
	assert_eq(spawner.active_enemies.size(), 2, "Both runners released")
	for i in 150:
		await get_tree().physics_frame
		var all_down := true
		for enemy in spawner.active_enemies:
			if not (enemy as CharacterBody3D).is_on_floor():
				all_down = false
		if all_down:
			break
	# The spawner (the runners' parent) ticks before them: it sees the touchdown a frame later.
	await get_tree().physics_frame
	await get_tree().physics_frame
	for i in spawner.active_enemies.size():
		var enemy: CharacterBody3D = spawner.active_enemies[i]
		var marker: Node3D = spawner.get_node("SpawnPoint%d" % (i + 1))
		assert_true(enemy.is_on_floor(), "Runner %d touched down" % i)
		assert_almost_eq(enemy.global_position.x, marker.global_position.x, 0.05, "Runner %d lands on its marker (x)" % i)
		assert_almost_eq(enemy.global_position.z, marker.global_position.z, 0.05, "Runner %d lands on its marker (z)" % i)
		assert_lt(absf(enemy.global_position.y - marker.global_position.y), 0.5, "Runner %d stands at marker height" % i)
	assert_true(shakes.count(WaveSpawner.LANDING_SHAKE_STRENGTH) >= 2, "Each touchdown shakes the camera (0.1)")
	assert_eq(_visible_rings(spawner), 0, "Landing rings are released on touchdown")

# --- S4 ------------------------------------------------------------------------------

func _ride() -> Dictionary:
	var platform: AnimatableBody3D = _keep(AnimatableBody3D.new())
	platform.sync_to_physics = false
	platform.position.y = -4.5
	var spawner: WaveSpawner = _keep(WaveSpawner.new())
	spawner.add_child(Marker3D.new())
	var light: OmniLight3D = _keep(OmniLight3D.new())
	light.light_energy = 2.5
	var elevator: ElevatorEncounter = _keep(ElevatorEncounter.new())
	elevator.platform = platform
	elevator.spawner = spawner
	elevator.target_y = 14.5
	elevator.speed = 2.0
	elevator.wave_cooldown = 0.0
	elevator.cells_reward = 0
	elevator.ride_light = light
	var waves: Array[WaveDef] = [_wave(_dummy_scene(), 1, 0.5, "drop"), _wave(_dummy_scene(), 1, 0.5, "drop")]
	elevator.waves = waves
	elevator.exit_path = _keep(Path3D.new())
	add_child(platform)
	add_child(spawner)
	add_child(light)
	add_child(elevator)
	return {"elevator": elevator, "platform": platform, "spawner": spawner, "light": light}

func _clear_wave(spawner: WaveSpawner) -> void:
	for enemy in spawner.active_enemies.duplicate():
		spawner._on_enemy_defeated(enemy)

func test_s4_the_platform_waits_at_each_stop_until_its_wave_is_cleared() -> void:
	var r := _ride()
	var elevator: ElevatorEncounter = r.elevator
	var platform: AnimatableBody3D = r.platform
	var spawner: WaveSpawner = r.spawner
	var light: OmniLight3D = r.light
	var shakes: Array[float] = []
	SignalBus.camera_shake_requested.connect(func(strength: float, _d: float): shakes.append(strength))
	var done := {"n": 0}
	elevator.encounter_completed.connect(func(): done.n += 1)
	elevator.start_encounter()
	for i in 20:
		elevator._physics_process(0.5)
	assert_almost_eq(platform.position.y, 5.0, 0.001, "Wave 1 is fought parked at y 5")
	assert_eq(shakes.count(ElevatorEncounter.LURCH_SHAKE_STRENGTH), 1, "One 0.2 lurch on arrival")
	assert_lt(light.light_energy, 2.5, "The ride light stutters on the lurch")
	for i in 3:
		SignalBus.beat.emit("primary", i + 1)
	assert_almost_eq(light.light_energy, 2.5, 0.001, "...for three beats, then holds steady")
	_clear_wave(spawner)
	for i in 20:
		elevator._physics_process(0.5)
	assert_almost_eq(platform.position.y, 10.0, 0.001, "Wave 2 climbs to y 10 and is fought there")
	assert_eq(spawner.active_enemies.size(), 1, "Wave 2 spawned on the climb")
	assert_eq(done.n, 0, "Not complete with wave 2 alive")
	_clear_wave(spawner)
	for i in 20:
		elevator._physics_process(0.5)
	assert_almost_eq(platform.position.y, 14.5, 0.001, "The last leg ends at target_y 14.5 (unchanged)")
	assert_eq(done.n, 1, "Completion rule unchanged: top reached with every wave beaten")
	assert_true(elevator.completed, "...completed")

func test_s4_the_slice_elevator_keeps_its_final_height_and_handover() -> void:
	var slice := _spawn_slice()
	var elevator: ElevatorEncounter = slice.get_node("ElevatorEncounter")
	assert_eq(elevator.stop_heights, [5.0, 10.0, 14.5] as Array[float], "Stops at y 5, 10, 14.5")
	assert_almost_eq(elevator.target_y, 14.5, 0.0001, "Final height unchanged")
	assert_eq(elevator.exit_path, slice.get_node("Path_Z10"), "Dock handover unchanged")
	assert_eq(elevator.ride_light, slice.get_node("ElevatorPlatform/Z9_ElevatorLight"), "The platform light flickers on each stop")
	for n in ["WindowBand1", "WindowBand2"]:
		var band: CSGBox3D = slice.get_node("Z9_Dressing/" + n)
		assert_almost_eq(band.global_position.z, -3.575, 0.01, "%s sits on the shaft wall" % n)

# --- S5 ------------------------------------------------------------------------------

func test_s5_the_last_stretch_has_a_third_door_and_sign_and_a_glowing_mouth() -> void:
	var slice := _spawn_slice()
	var door3: EscapeDoorHazard = slice.get_node("EscapeDoorHazard3")
	var sign3: EscapeFallingHazard = slice.get_node("EscapeFallingHazard3")
	assert_almost_eq(door3.global_position.x, 378.0, 0.001, "Door 3 at x 378")
	assert_eq([door3.close_beat_interval, door3.cycle_offset, door3.closed_duration_beats], [4, 1, 2], "Door 3 cycle")
	assert_almost_eq(door3.slide_distance, 3.0, 0.001, "Door 3 slides 3 m like the others")
	assert_eq(door3.global_position.y, (slice.get_node("EscapeDoorHazard2") as Node3D).global_position.y, "Door 3 closes flush")
	assert_almost_eq(sign3.global_position.x, 388.0, 0.001, "Sign 3 at x 388")
	assert_eq([sign3.beat_interval, sign3.cycle_offset, sign3.telegraph_beats], [8, 6, 2], "Sign 3 cycle")
	var end_x: float = (slice.get_node("EscapeSequence/EscapeEndTrigger") as Node3D).global_position.x
	assert_true(sign3.global_position.x < end_x and door3.global_position.x < end_x, "Both before the end trigger")
	var gap: OmniLight3D = slice.get_node("ZoneLights/Z9_GapLight")
	assert_true(gap.global_position.is_equal_approx(Vector3(405.0, -2.0, 0.0)), "The gap light glows at the elevator mouth")
	assert_almost_eq(gap.light_energy, 3.0, 0.001, "...at energy 3")
	# Margin: wall from x 275 at its speed vs Nick at max_speed from x 280 + 1 s per door.
	var wall: EscapeKillWall = slice.get_node("EscapeSequence/EscapeKillWall")
	var nick_speed: float = (slice.get_node("Player") as PlayerController).max_speed
	var wall_time := (end_x - 275.0) / wall.speed
	var nick_time := (end_x - 280.0) / nick_speed + 3.0
	assert_gt(wall_time - nick_time, 2.0, "Escape margin with three doors: wall %.1f s vs Nick %.1f s" % [wall_time, nick_time])

# --- S3 ------------------------------------------------------------------------------

func test_s3_the_headliner_plays_on_a_stage() -> void:
	var slice := _spawn_slice()
	var ring: CSGTorus3D = slice.get_node("Z10_Dressing/StageRing")
	assert_true(ring.global_position.is_equal_approx(Vector3(425.0, 15.0, 0.0)), "Stage ring on the phase-2 spot")
	assert_almost_eq((ring.inner_radius + ring.outer_radius) * 0.5, 5.0, 0.001, "5 m ring")
	assert_false(ring.use_collision, "The ring is paint, not a step")
	var marquee: Label3D = slice.get_node("Z10_Dressing/Marquee")
	assert_eq(marquee.text, "THE HEADLINER", "Marquee text")
	assert_true(marquee.global_position.is_equal_approx(Vector3(425.0, 23.0, -6.7)), "Marquee over the far wall (V2: above the truss)")
	assert_eq(slice.get_node("Z10_Dressing/Truss/Z10_SpotL").global_position, Vector3(415.0, 14.0, -3.0), "SpotL keeps its world position under the truss")
	assert_eq(slice.get_node("Z10_Dressing/Truss/Z10_SpotR").global_position, Vector3(435.0, 14.0, -3.0), "SpotR keeps its world position under the truss")
	var p1: Node3D = slice.get_node("Zone10_Dock/Pillar1")
	var p2: Node3D = slice.get_node("Zone10_Dock/Pillar2")
	assert_true(p1.global_position.is_equal_approx(Vector3(415.0, 16.25, -5.0)) and p2.global_position.is_equal_approx(Vector3(435.0, 16.25, -5.0)), "Pillars in symmetric back corners")
	var stage_lights := 0
	for child in slice.get_node("Z10_Dressing").get_children():
		if child is OmniLight3D and child.get_script() == load("res://levels/components/stage_light.gd"):
			stage_lights += 1
	assert_eq(stage_lights, 4, "Four speaker stacks carry beat-pulsed StageLights")

func test_s3_the_marquee_turns_magenta_in_phase_two_and_back_on_reset() -> void:
	# The real boss script as a plain property holder (never added to the tree).
	var boss: Node = _keep(load("res://characters/enemies/headliner/headliner.gd").new() as Node)
	var marquee: Label3D = _keep(Label3D.new())
	marquee.set_script(load(MARQUEE_SCRIPT))
	marquee.set("headliner", boss)
	add_child(marquee)
	assert_false(marquee.get("is_phase_2"), "Starts amber")
	var amber: Color = marquee.modulate
	assert_true(amber.r > amber.g and amber.g > amber.b, "...amber")
	SignalBus.boss_health_changed.emit(1000, 1500)
	assert_false(marquee.get("is_phase_2"), "Phase 1 damage keeps it amber")
	boss.set("phase_2_triggered", true)
	SignalBus.boss_health_changed.emit(700, 1500)
	assert_true(marquee.get("is_phase_2"), "Phase 2 turns the marquee magenta")
	assert_true(marquee.modulate.b > marquee.modulate.g, "...magenta (blue over green)")
	SignalBus.boss_reset.emit()
	assert_false(marquee.get("is_phase_2"), "A boss reset puts the amber back")
	assert_eq(marquee.modulate, amber, "...same amber")

# --- S1 ------------------------------------------------------------------------------

## Side-scroll rail points bucketed per 0.5 m of x (the nearest baked point per bucket).
func _rail_buckets(slice: Node3D) -> Dictionary:
	var buckets := {}
	for rail_name in ["Path_Z1_2_3", "Path_Z4_5_6", "Path_Z7", "Path_Z8", "Path_Z10"]:
		var path: Path3D = slice.get_node(rail_name)
		for p in path.curve.get_baked_points():
			var g := path.to_global(p)
			var key := roundi(g.x * 2.0)
			if not buckets.has(key) or absf((buckets[key] as Vector3).x - key * 0.5) > absf(g.x - key * 0.5):
				buckets[key] = g
	return buckets

func test_s1_every_zone_has_dressing_that_never_blocks_or_crowds_the_rail() -> void:
	var slice := _spawn_slice()
	await get_tree().process_frame # CSG meshes build on the next idle frame
	await get_tree().process_frame
	var rails := _rail_buckets(slice)
	for zone in range(1, 11):
		var dressing: Node = slice.get_node_or_null("Z%d_Dressing" % zone)
		assert_not_null(dressing, "Zone %d has a Z%d_Dressing kit" % [zone, zone])
		if dressing == null:
			continue
		assert_gt(dressing.find_children("*", "", true, false).size(), 3, "Zone %d dressing is more than a token prop" % zone)
		for node in dressing.find_children("*", "CSGShape3D", true, false):
			var csg := node as CSGShape3D
			assert_false(csg.use_collision, "%s is decorative (no collision)" % csg.get_path())
			var box: AABB = csg.global_transform * csg.get_aabb()
			if box.size == Vector3.ZERO:
				continue
			# Sample the rail across the piece's x span: nothing taller than 0.3 m stands within
			# 0.8 m of it at walking height (overhead gantries/canopies above 2.5 m are fine).
			var x := box.position.x
			while x <= box.end.x + 0.001:
				var key := roundi(x * 2.0)
				if rails.has(key):
					var r: Vector3 = rails[key]
					var near_z := box.position.z <= r.z + 0.8 and box.end.z >= r.z - 0.8
					var walk_band := box.end.y > r.y + 0.3 and box.position.y < r.y + 2.5
					assert_false(near_z and walk_band, "%s crowds the rail at x %.1f (aabb %s)" % [csg.get_path(), x, str(box)])
				x += 0.5
	var statue: Node3D = slice.get_node("Z6_Dressing/HeadlinerStatue")
	assert_true(statue.find_children("*", "Hurtbox3D", true, false).is_empty(), "The holo statue has no hurtbox")
	assert_eq(slice.get_node("Z1_Dressing/SignRamen").text, "RAMEN 24H", "Z1 signs (Label3D fallback)")
	assert_eq(slice.get_node("Z10_Dressing/SignHeadlinerLive").text, "HEADLINER LIVE", "Z10 sign")
