extends "res://tests/framework/test_case.gd"

# C9: Zones 9-10 were unreachable because Curve3D_z8 stopped at x=340 while the elevator
# entry trigger sat at x=347 -- the player is snapped to his rail every frame, so he could
# never touch it. These tests read the REAL slice scene: every zone trigger must lie inside
# the x range of the rail Nick is walking when it has to fire, and a real player body walked
# along the Zone 8 rail must actually start the elevator encounter.

const SLICE_PATH := "res://levels/slice/vertical_slice.tscn"

# Rail -> the triggers that must be reachable while Nick is on it.
const RAIL_TRIGGERS := {
	"Path_Z1_2_3": ["Z1_Encounter", "Z2_Trigger", "Z3_Encounter"],
	"Path_Z4_5_6": ["Z4_Encounter", "Z5_Encounter", "Z6_Encounter"],
	"Path_Z7": ["Z7_Trigger", "Z8_Trigger"],
	"Path_Z8": ["Z9_Trigger", "ElevatorEncounter/ElevatorEntryTrigger"],
	"Path_Z10": ["Zone10_Trigger"],
}

func _rail_x_range(path: Path3D) -> Vector2:
	var lo := INF
	var hi := -INF
	for i in path.curve.point_count:
		var x: float = path.to_global(path.curve.get_point_position(i)).x
		lo = minf(lo, x)
		hi = maxf(hi, x)
	return Vector2(lo, hi)

func _trigger_half_width(trigger: Node3D) -> float:
	for child in trigger.get_children():
		if child is CollisionShape3D and child.shape is BoxShape3D:
			return (child.shape as BoxShape3D).size.x * 0.5
	return 0.0

func _spawn_slice() -> Node3D:
	var slice: Node3D = (load(SLICE_PATH) as PackedScene).instantiate()
	add_child(slice)
	return slice

func test_every_zone_trigger_lies_inside_its_rails_x_range() -> void:
	var slice := _spawn_slice()
	for rail_name in RAIL_TRIGGERS.keys():
		var path: Path3D = slice.get_node(rail_name)
		var range_x := _rail_x_range(path)
		for trigger_name in RAIL_TRIGGERS[rail_name]:
			var trigger: Node3D = slice.get_node(trigger_name)
			var half := _trigger_half_width(trigger)
			var lo: float = trigger.global_position.x - half
			var hi: float = trigger.global_position.x + half
			assert_true(hi >= range_x.x and lo <= range_x.y,
				"%s (x %.1f..%.1f) must be reachable on %s (x %.1f..%.1f)" % [trigger_name, lo, hi, rail_name, range_x.x, range_x.y])
			assert_true(trigger.global_position.x >= range_x.x - 4.0 and trigger.global_position.x <= range_x.y + 4.0,
				"%s centre x=%.1f is too far off %s" % [trigger_name, trigger.global_position.x, rail_name])
	slice.free()

func test_consecutive_rails_overlap_so_nick_is_never_snapped_across_a_gap() -> void:
	var slice := _spawn_slice()
	var chain := ["Path_Z1_2_3", "Path_Z4_5_6", "Path_Z7", "Path_Z8", "Path_Z10"]
	for i in range(chain.size() - 1):
		var a := _rail_x_range(slice.get_node(chain[i]))
		var b := _rail_x_range(slice.get_node(chain[i + 1]))
		# Nick hands over from rail A to rail B somewhere in A's range: B must already
		# have started by A's end, otherwise the first snap teleports him along x.
		assert_true(b.x <= a.y, "%s must start (x=%.1f) at or before %s ends (x=%.1f)" % [chain[i + 1], b.x, chain[i], a.y])
	slice.free()

func test_elevator_hands_nick_to_the_dock_rail_and_boss_gate_closes_behind_him() -> void:
	var slice := _spawn_slice()
	var elevator: ElevatorEncounter = slice.get_node("ElevatorEncounter")
	assert_eq(elevator.exit_path, slice.get_node("Path_Z10"), "ElevatorEncounter.exit_path should be Path_Z10")
	# Platform top must be flush with the dock top (platform box 1 m tall, dock centre 14.5 + 0.5).
	var dock: Node3D = slice.get_node("Zone10_Dock")
	assert_eq(elevator.target_y, dock.position.y, "Elevator arrives with its top flush with the dock top")
	# The boss gate (x 352-353) must close behind Nick: trigger sits past it.
	var gate: Node3D = slice.get_node("LeftGate")
	var trigger: Node3D = slice.get_node("Zone10_Trigger")
	assert_gt(trigger.global_position.x - 1.0, gate.global_position.x + 0.5, "Zone10_Trigger must be east of LeftGate")
	# Completion must hand the camera/rail to Path_Z10, not auto-activate the boss.
	var flags := {"path": null}
	var on_shift := func(_td, path, _t): flags.path = path
	SignalBus.camera_shift_requested.connect(on_shift)
	elevator.platform.sync_to_physics = false # a position write is otherwise ignored until the first physics step
	elevator.platform.position.y = elevator.target_y
	elevator.current_wave_index = elevator.waves.size()
	elevator.is_active = true
	elevator._check_completion()
	assert_eq(flags.path, elevator.exit_path, "Elevator completion should request the Path_Z10 rail")
	SignalBus.camera_shift_requested.disconnect(on_shift)
	slice.free()

func test_player_walking_the_zone8_rail_boards_the_elevator() -> void:
	var slice := _spawn_slice()
	# Strip everything that could hurt/interrupt Nick on the way; this is a pure rail test.
	for n in ["Z7_Enemies", "Z8_Enemies", "RhythmEnforcer", "EscapeDoorHazard", "EscapeFallingHazard", "EscapeCollapsingHazard"]:
		var node := slice.get_node_or_null(n)
		if node:
			slice.remove_child(node)
			node.free()
	var player: PlayerController = slice.get_node("Player")
	var elevator: ElevatorEncounter = slice.get_node("ElevatorEncounter")
	# The state the escape leaves him in: on the Zone 8 rail.
	player.current_path = slice.get_node("Path_Z8")
	player.health_component.is_invincible = true
	assert_false(elevator.is_active, "Elevator must be idle before Nick boards")

	var x := 240.0
	while x <= 348.0:
		player.global_position = Vector3(x, -3.0, 0.0)
		player.velocity = Vector3.ZERO
		await get_tree().physics_frame
		x += 4.0
	# Hold at the end of the rail (x=348) -- inside the entry trigger (x 346..348).
	for i in 4:
		player.global_position = Vector3(348.0, -3.0, 0.0)
		player.velocity = Vector3.ZERO
		await get_tree().physics_frame
	await get_tree().process_frame # start_encounter is deferred out of the body_entered callback

	assert_true(player.global_position.x > 345.0, "The Zone 8 rail must carry Nick to the elevator (x=%.1f)" % player.global_position.x)
	assert_true(elevator.is_active, "Reaching the end of the Zone 8 rail must start the elevator encounter")
	slice.free()

# C11: scene-placed enemies must stand on collidable geometry, not hang over a gap and fall forever.
func test_scene_placed_enemies_stand_on_solid_ground() -> void:
	var slice := _spawn_slice()
	var boxes: Array[CSGBox3D] = []
	for node in slice.find_children("*", "CSGBox3D", true, false):
		if node.use_collision:
			boxes.append(node)
	var checked := 0
	for group_name in ["Z2_Enemies", "Z7_Enemies", "Z8_Enemies"]:
		for enemy in slice.get_node(group_name).get_children():
			checked += 1
			var p: Vector3 = enemy.global_position
			var supported := false
			for box in boxes:
				var c := box.global_position
				var h := box.size * 0.5
				var top := c.y + h.y
				if absf(p.x - c.x) <= h.x and absf(p.z - c.z) <= h.z and p.y >= top - 0.01 and p.y - top < 3.0:
					supported = true
					break
			assert_true(supported, "%s/%s at %s has no collidable ground beneath it" % [group_name, enemy.name, str(p)])
	assert_gt(checked, 5, "Expected to check the Zone 2/7/8 scene-placed enemies")
	assert_eq(slice.get_node("Z2_Enemies").get_child_count(), 3, "Zone 2 is three Runners (VerticalSlice.md)")
	slice.free()
