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
