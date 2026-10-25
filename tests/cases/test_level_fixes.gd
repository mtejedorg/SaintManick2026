extends "res://tests/framework/test_case.gd"

# C14: small level-geometry / hazard-gating fixes, asserted against the REAL slice scene
# so a later scene edit can't silently undo them.

const SLICE_PATH := "res://levels/slice/vertical_slice.tscn"
const GROUND_TOP_Z7_Z8 := -4.0

var _slice: Node3D

func before_each() -> void:
	_slice = (load(SLICE_PATH) as PackedScene).instantiate()
	add_child(_slice)

func after_each() -> void:
	super.after_each()
	if is_instance_valid(_slice):
		_slice.free()

func _box(path: String) -> CSGBox3D:
	return _slice.get_node(path) as CSGBox3D

func test_z7_barrier_is_taller_than_a_jump() -> void:
	var barrier := _box("Z7_Barrier")
	var top := barrier.global_position.y + barrier.size.y * 0.5
	assert_gt(top - GROUND_TOP_Z7_Z8, 5.5, "The Zone 7 barrier must stand above the 5.5 m jump height")
	assert_true(barrier.global_position.y - barrier.size.y * 0.5 <= GROUND_TOP_Z7_Z8, "...and reach the ground")

func test_z7_barrier_sits_behind_the_enforcer_and_opens_when_he_dies() -> void:
	var barrier := _box("Z7_Barrier")
	var enforcer: Node3D = _slice.get_node("RhythmEnforcer")
	assert_gt(barrier.global_position.x, enforcer.global_position.x, "The barrier must be behind the fight (x %.1f), not in front of the Enforcer (x %.1f)" % [barrier.global_position.x, enforcer.global_position.x])
	assert_true(barrier.use_collision and barrier.visible, "Solid before the Enforcer dies")
	SignalBus.miniboss_defeated.emit()
	await get_tree().process_frame
	assert_false(barrier.use_collision, "Barrier collision opens on miniboss_defeated")
	assert_false(barrier.visible, "Barrier hides on miniboss_defeated")

func test_zone4_trigger_no_longer_overlaps_the_zone3_room() -> void:
	var enc: Area3D = _slice.get_node("Z4_Encounter")
	var shape: CollisionShape3D = enc.get_node("CollisionShape3D")
	var left := enc.global_position.x - (shape.shape as BoxShape3D).size.x * 0.5
	var room := _box("Z3_Room/Floor")
	var room_right := room.global_position.x + room.size.x * 0.5
	assert_gt(left, room_right - 0.001, "Zone 4's trigger (left edge %.1f) must start beyond the Zone 3 room (right edge %.1f)" % [left, room_right])

func test_zone4_spawn_markers_stay_over_the_catwalk() -> void:
	# The trigger moved +12.5 m; the spawner is re-seated so markers keep their world x.
	var sniper2: Node3D = _slice.get_node("Z4_Encounter/Z4_Spawner/SniperSpawnPoint2")
	var catwalk := _box("Z4_Catwalk/SniperCatwalk2")
	assert_true(absf(sniper2.global_position.x - catwalk.global_position.x) <= catwalk.size.x * 0.5, "SniperSpawnPoint2 must be over SniperCatwalk2 (x=%.1f)" % sniper2.global_position.x)

func test_zone10_arena_gate_and_walls_span_the_whole_dock() -> void:
	var dock := _box("Zone10_Dock")
	assert_eq(dock.size.z, 14.0)
	assert_eq(_box("LeftGate/Visual").size.z, dock.size.z, "Gate visual spans the arena depth")
	assert_eq(_box("Zone10_Dock/RightWall").size.z, dock.size.z, "Right wall spans the arena depth")
	var gate_shape: CollisionShape3D = _slice.get_node("LeftGate/CollisionShape3D")
	assert_eq((gate_shape.shape as BoxShape3D).size.z, dock.size.z, "Gate collision spans the arena depth")

func test_falling_hazard_reaches_the_floor_and_door_closes_flush() -> void:
	var fall: EscapeFallingHazard = _slice.get_node("EscapeFallingHazard")
	var body := _box("EscapeFallingHazard/HazardBody")
	var bottom_after_fall := fall.global_position.y - fall.fall_distance - body.size.y * 0.5
	assert_true(bottom_after_fall <= GROUND_TOP_Z7_Z8 + 0.01, "The falling sign must reach the floor (bottom %.2f)" % bottom_after_fall)
	var door: EscapeDoorHazard = _slice.get_node("EscapeDoorHazard")
	var door_body := _box("EscapeDoorHazard/DoorBody")
	var closed_bottom := door.global_position.y - door.slide_distance - door_body.size.y * 0.5
	assert_true(closed_bottom <= GROUND_TOP_Z7_Z8 + 0.01, "A closed door must reach the floor (bottom %.2f)" % closed_bottom)
	assert_gt(door.global_position.y - door_body.size.y * 0.5, GROUND_TOP_Z7_Z8 + 1.5, "An open door must clear Nick's head")

func test_zone2_to_zone3_gap_is_split_by_platform7() -> void:
	var p6 := _box("Z2_Platforms/Platform6")
	var p7 := _box("Z2_Platforms/Platform7")
	var floor3 := _box("Z3_Room/Floor")
	assert_true(p7.use_collision, "Platform7 must be solid")
	var gap_a := (p7.global_position.x - p7.size.x * 0.5) - (p6.global_position.x + p6.size.x * 0.5)
	var gap_b := (floor3.global_position.x - floor3.size.x * 0.5) - (p7.global_position.x + p7.size.x * 0.5)
	assert_true(gap_a > 0.0 and gap_a <= 4.0, "Platform6 -> Platform7 gap %.1f must be comfortably jumpable" % gap_a)
	assert_true(gap_b > 0.0 and gap_b <= 4.0, "Platform7 -> Zone 3 floor gap %.1f must be comfortably jumpable" % gap_b)

func test_zone6_cover_pillars_are_real_cover() -> void:
	var count := 0
	for n in _slice.get_node("Z6_Plaza").get_children():
		if n.name.begins_with("CoverPillar"):
			count += 1
			assert_gt((n as CSGBox3D).size.y, 2.9, "%s should be at least 3 m tall" % n.name)
	assert_eq(count, 4, "Four cover pillars around the plaza")

func test_bomb_grid_only_runs_during_its_live_encounter() -> void:
	var grid: BombGrid = _slice.get_node("BombGrid")
	var enc: ZoneEncounter = _slice.get_node("Z3_Encounter")
	assert_eq(grid.encounter, enc, "BombGrid is bound to the Zone 3 encounter in the scene")

	var indicators_visible := func() -> int:
		var n := 0
		for cell in grid.get_children():
			var ind = cell.get_node_or_null("Indicator")
			if ind and ind.visible:
				n += 1
		return n

	# Not started: nothing warns or ignites.
	grid._on_downbeat("primary", 1)
	assert_eq(indicators_visible.call(), 0, "No warnings before the encounter starts")

	# Live: odd measure warns set A only.
	enc.active = true
	grid._on_downbeat("primary", 1)
	assert_eq(indicators_visible.call(), grid.set_a.size(), "Live encounter warns set A")

	# Cleared: everything stands down.
	enc.completed = true
	grid._on_downbeat("primary", 2)
	assert_eq(indicators_visible.call(), 0, "A cleared encounter silences the grid")

# C4: geometry/readability defects.
func test_zone4_vista_is_not_hidden_by_a_background_wall() -> void:
	assert_null(_slice.get_node_or_null("Z4_Catwalk/BackgroundWall"), "BackgroundWall hid the Central Tower and must stay deleted")
	var towers := _slice.get_node("Z4_BackgroundTowers")
	var bg := 0
	for n in towers.get_children():
		if n.name.begins_with("BgTower") and not n.name.contains("Strip"):
			bg += 1
			assert_false((n as CSGBox3D).use_collision, "Background towers are scenery: no collision")
	assert_eq(bg, 6, "Six background towers frame the skyline")

func test_zone10_near_wall_is_a_low_holo_rail_the_camera_can_see_over() -> void:
	var rail := _box("Zone10_Dock/NearWall")
	assert_almost_eq(rail.size.y, 0.6, 0.001, "The near wall is a 0.6 m rail")
	assert_true(rail.use_collision, "...that still collides")

func test_falling_hazard_warning_mesh_is_wired() -> void:
	var fall: EscapeFallingHazard = _slice.get_node("EscapeFallingHazard")
	assert_not_null(fall.warning_mesh, "warning_mesh must be assigned so the telegraph is visible")
	assert_eq(fall.warning_mesh.name, &"Warning")

func test_escape_kill_wall_has_a_visible_body() -> void:
	var wall := _slice.get_node("EscapeSequence/EscapeKillWall")
	var meshes := wall.find_children("*", "MeshInstance3D", false, false)
	assert_eq(meshes.size(), 2, "Glow body + white-hot core")

func test_zone7_runners_stand_outside_the_zone6_plaza() -> void:
	var plaza := _box("Z6_Plaza/Floor")
	var plaza_right := plaza.global_position.x + plaza.size.x * 0.5
	for n in ["Runner1", "Runner2", "Runner3"]:
		var runner: Node3D = _slice.get_node("Z7_Enemies/" + n)
		assert_gt(runner.global_position.x, plaza_right, "%s (x %.1f) must stand beyond the plaza edge (%.1f)" % [n, runner.global_position.x, plaza_right])

func test_zone4_sega_stops_before_the_plank_gap() -> void:
	var seg_a := _box("Z4_Catwalk/SegA")
	var seg_b := _box("Z4_Catwalk/SegB")
	var room := _box("Z3_Room/Floor")
	var a_left := seg_a.global_position.x - seg_a.size.x * 0.5
	var a_right := seg_a.global_position.x + seg_a.size.x * 0.5
	var b_left := seg_b.global_position.x - seg_b.size.x * 0.5
	assert_gt(a_left, room.global_position.x + room.size.x * 0.5 - 0.001, "SegA must not run back into the Zone 3 room")
	assert_gt(b_left - a_right, 2.5, "The PlankA gap (%.1f m) must exist again" % (b_left - a_right))
	for n in ["SpawnPoint5", "SpawnPoint7"]:
		var marker: Node3D = _slice.get_node("Z4_Encounter/Z4_Spawner/" + n)
		assert_true(marker.global_position.x >= b_left and marker.global_position.x <= seg_b.global_position.x + seg_b.size.x * 0.5, "%s must land on SegB (x %.1f)" % [n, marker.global_position.x])

func test_zone5_lower_tier_connects_to_the_plaza_by_a_ramp() -> void:
	var ramp := _box("Z5_Market/Z5_ExitRamp")
	var lower := _box("Z5_Market/LowerTier")
	var plaza := _box("Z6_Plaza/Floor")
	assert_true(ramp.use_collision, "The ramp must be solid")
	var half_run := ramp.size.x * 0.5 * cos(ramp.rotation.z)
	var left := ramp.global_position.x - half_run
	var right := ramp.global_position.x + half_run
	assert_true(absf(left - (lower.global_position.x + lower.size.x * 0.5)) < 0.6, "Ramp starts at the lower tier's edge (%.2f)" % left)
	assert_true(absf(right - (plaza.global_position.x - plaza.size.x * 0.5)) < 0.6, "Ramp ends at the plaza's edge (%.2f)" % right)

func test_zone9_shaft_has_a_back_wall_with_strips() -> void:
	var wall := _box("Z9_Shaft/BackWall")
	assert_false(wall.use_collision, "The shaft back wall is visual only")
	assert_true(wall.global_position.y - wall.size.y * 0.5 <= -4.0 and wall.global_position.y + wall.size.y * 0.5 >= 16.0, "Back wall spans y -4..16")
	assert_gt(_slice.get_node("Z9_Shaft").get_child_count(), 6, "Shaft needs magenta strips every 3 m")

# ---------------- H1 / H2 (round-2 audit) ----------------

const MARKER_ZONES := ["Z1_Encounter/Z1_Spawner", "Z4_Encounter/Z4_Spawner", "Z5_Encounter/Z5_Spawner", "Z6_Encounter/Z6_Spawner"]
## Grunt capsules are origin-centred (runner half height 0.9): a ground marker sits at least
## this high above the floor under it.
const MARKER_MIN_LIFT := 0.9

func _encounter_box(enc: Area3D) -> AABB:
	var col := enc.get_node("CollisionShape3D") as CollisionShape3D
	var size: Vector3 = (col.shape as BoxShape3D).size
	return AABB(col.global_position - size * 0.5, size)

func test_ground_spawn_markers_stand_on_a_floor_outside_their_trigger() -> void:
	# CSG collision is built on the next idle frame, registered on the following physics frame.
	await get_tree().process_frame
	await get_tree().physics_frame
	await get_tree().physics_frame
	var space := _slice.get_world_3d().direct_space_state
	var checked := 0
	for spawner_path in MARKER_ZONES:
		var spawner: Node3D = _slice.get_node(spawner_path)
		var trigger_box := _encounter_box(spawner.get_parent() as Area3D)
		for marker in spawner.get_children():
			if not (marker is Marker3D) or String(marker.name).begins_with("Sniper"):
				continue
			checked += 1
			var p: Vector3 = (marker as Marker3D).global_position
			var label := "%s/%s at %s" % [spawner_path, marker.name, str(p)]
			var query := PhysicsRayQueryParameters3D.create(p + Vector3.UP * 0.5, p + Vector3.DOWN * 6.0, 1)
			var hit := space.intersect_ray(query)
			assert_false(hit.is_empty(), "%s must have a floor under it (x and z)" % label)
			if not hit.is_empty():
				var floor_y: float = (hit["position"] as Vector3).y
				assert_true(p.y - floor_y >= MARKER_MIN_LIFT - 0.001, "%s must sit >= %.1f m above its floor (%.2f)" % [label, MARKER_MIN_LIFT, p.y - floor_y])
			assert_false(trigger_box.has_point(p), "%s must not lie inside its zone trigger box" % label)
	assert_gt(checked, 15, "All ground markers of Zones 1/4/5/6 were checked (%d)" % checked)

func test_zone7_floor_meets_the_plaza_and_the_entry_gate_is_wired() -> void:
	var plaza := _box("Z6_Plaza/Floor")
	var ground := _box("Z7_Ground")
	var plaza_right := plaza.global_position.x + plaza.size.x * 0.5
	assert_true(ground.global_position.x - ground.size.x * 0.5 <= plaza_right + 0.001, "No void between the plaza and the Zone 7 floor")
	var trim := _box("Trims/Z7_Trim")
	assert_almost_eq(trim.global_position.x, ground.global_position.x, 0.001, "Z7 trim follows the floor")
	assert_almost_eq(trim.size.x, ground.size.x, 0.001, "...and its length")
	var gate: Node3D = _slice.get_node("Z7_EntryGate")
	var enforcer: Node = _slice.get_node("RhythmEnforcer")
	assert_eq(enforcer.get("entry_gate"), gate, "The Enforcer owns the Zone 7 entry gate")
	assert_true(gate.is_in_group("gates"), "The entry gate is a legal (gates) obstacle")
	assert_true((gate.get_node("CollisionShape3D") as CollisionShape3D).disabled, "Open at rest")
	assert_false((gate.get_node("Visual") as Node3D).visible, "...and hidden")
	var trigger_left: float = (_slice.get_node("Z7_Trigger") as Node3D).global_position.x - 3.0
	assert_true(gate.global_position.x + 0.25 <= trigger_left - 0.5 - 0.001, "Nick (r 0.5) is fully past the gate when the Z7 trigger fires")
	assert_gt(gate.global_position.x, plaza_right, "...and the gate stands outside the plaza")

func test_zone2_pit_reaches_the_zone3_floor_and_has_end_walls() -> void:
	var pit_floor := _box("ToxicPitFloor")
	var room := _box("Z3_Room/Floor")
	var pit_right := pit_floor.global_position.x + pit_floor.size.x * 0.5
	assert_almost_eq(pit_right, room.global_position.x - room.size.x * 0.5, 0.001, "The pit floor runs to the Zone 3 floor")
	assert_almost_eq(pit_floor.global_position.x - pit_floor.size.x * 0.5, 30.0, 0.001, "...from the Zone 1 floor end")
	var pit: Node3D = _slice.get_node("ToxicPit")
	assert_almost_eq(pit.global_position.x, pit_floor.global_position.x, 0.001, "Pit volume centred on its floor")
	assert_almost_eq((pit.get("pit_size") as Vector3).x, pit_floor.size.x, 0.001, "...and as long")
	assert_almost_eq(_box("ToxicPitEdge").size.x, pit_floor.size.x, 0.001, "The edge strip matches")
	for n in ["ToxicPitWallL", "ToxicPitWallR"]:
		var wall := _box(n)
		assert_true(wall.use_collision, "%s is solid" % n)
		assert_true(wall.global_position.y + wall.size.y * 0.5 <= -1.0 + 0.001, "%s stays under the platform line" % n)
		assert_true(wall.global_position.y - wall.size.y * 0.5 <= pit_floor.global_position.y + 0.5, "%s reaches the pit floor" % n)

func test_zone5_top_tier_no_longer_buries_step1_and_crate1() -> void:
	var top := _box("Z5_Market/TopTier")
	var step := _box("Z5_Market/Step1")
	var middle := _box("Z5_Market/MiddleTier")
	var crate := _box("Z5_Market/Crate1")
	assert_true(top.global_position.x + top.size.x * 0.5 <= step.global_position.x - step.size.x * 0.5 + 0.001, "TopTier ends where Step1 starts")
	var trim := _box("Trims/Z5_TrimTop")
	assert_almost_eq(trim.global_position.x, top.global_position.x, 0.001, "Top trim follows the tier")
	assert_almost_eq(trim.size.x, top.size.x, 0.001, "...and its length")
	var middle_top := middle.global_position.y + middle.size.y * 0.5
	assert_almost_eq(crate.global_position.y - crate.size.y * 0.5, middle_top, 0.001, "Crate1 stands on MiddleTier")
	assert_true(absf(crate.global_position.x - middle.global_position.x) <= middle.size.x * 0.5 - crate.size.x * 0.5, "...within its length")

func test_zone10_pillar1_no_longer_hides_nick_at_the_fight_start() -> void:
	var pillar := _box("Zone10_Dock/Pillar1")
	assert_almost_eq(pillar.position.z, -5.0, 0.001, "Pillar1 moved behind the fight line, next to Pillar2")

func test_scene_placed_grunts_wake_on_their_own_zone() -> void:
	for n in ["Runner1", "Runner2", "Runner3"]:
		assert_eq(_slice.get_node("Z2_Enemies/" + n).get("wake_zone"), "02", "Z2 %s wakes on SECTOR 02" % n)
		assert_eq(_slice.get_node("Z7_Enemies/" + n).get("wake_zone"), "07", "Z7 %s wakes on SECTOR 07" % n)
