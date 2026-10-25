extends "res://tests/framework/test_case.gd"

# G1: Z7_Trigger used to sit at x=242 (box 239..245) and reached back over the Zone 6
# plaza exit gate (x 239.5..240.5): brushing the gate mid-brawl fired SECTOR 07 (Enforcer
# activation + a checkpoint inside the plaza). Every gated arena must be free of any
# other zone's trigger volume along x.

const SLICE_PATH := "res://levels/slice/vertical_slice.tscn"

func _spawn_slice() -> Node3D:
	var slice: Node3D = (load(SLICE_PATH) as PackedScene).instantiate()
	add_child(slice)
	return slice

func _trigger_half_width(trigger: Node3D) -> float:
	for child in trigger.get_children():
		if child is CollisionShape3D and child.shape is BoxShape3D:
			return (child.shape as BoxShape3D).size.x * 0.5
	return 0.0

func _arena_x_span(encounter: ZoneEncounter) -> Vector2:
	var lo := INF
	var hi := -INF
	for gate in encounter.gates:
		if gate == null:
			continue
		var half := 0.0
		if gate is CSGBox3D:
			half = (gate as CSGBox3D).size.x * 0.5
		lo = minf(lo, gate.global_position.x - half)
		hi = maxf(hi, gate.global_position.x + half)
	return Vector2(lo, hi)

func test_no_zone_trigger_reaches_into_another_zones_gated_arena() -> void:
	var slice := _spawn_slice()
	var arenas := 0
	for encounter in slice.get_children():
		if not (encounter is ZoneEncounter) or (encounter as ZoneEncounter).gates.is_empty():
			continue
		arenas += 1
		var span := _arena_x_span(encounter)
		for other in slice.get_children():
			if other == encounter or not (other is Node3D) or not ("zone_name" in other):
				continue
			var half := _trigger_half_width(other)
			var lo: float = other.global_position.x - half
			var hi: float = other.global_position.x + half
			var overlaps: bool = hi > span.x and lo < span.y
			assert_false(overlaps,
				"%s (x %.1f..%.1f) must not reach into the %s arena (x %.1f..%.1f)" % [other.name, lo, hi, encounter.name, span.x, span.y])
	assert_eq(arenas, 2, "Expected the two gated arenas (Z3_Encounter, Z6_Encounter)")
	slice.free()

## J9: arenas sealed by something other than a ZoneEncounter's gates -- [left wall, right
## wall, the arena's own triggers]. Z8_Trigger used to reach over the Z7_Barrier: standing at
## the barrier mid-fight fired SECTOR 08 (card, music, checkpoint past the dormant Enforcer).
const EXTRA_ARENAS := [
	["Z7_EntryGate", "Z7_Barrier", ["Z7_Trigger"]],
	["LeftGate", "Zone10_Dock/RightWall", ["Zone10_Trigger"]],
]

## Half the x extent of a wall/gate: a CSGBox3D's size, else its BoxShape3D collision child.
func _x_half(node: Node3D) -> float:
	if node is CSGBox3D:
		return (node as CSGBox3D).size.x * 0.5
	return _trigger_half_width(node)

func test_no_zone_trigger_reaches_into_the_enforcer_arena_or_the_dock() -> void:
	var slice := _spawn_slice()
	for arena in EXTRA_ARENAS:
		var left: Node3D = slice.get_node(arena[0])
		var right: Node3D = slice.get_node(arena[1])
		var span := Vector2(left.global_position.x - _x_half(left), right.global_position.x + _x_half(right))
		assert_lt(span.x, span.y, "%s..%s is a real span" % [arena[0], arena[1]])
		for other in slice.get_children():
			if not (other is Node3D) or not ("zone_name" in other) or (arena[2] as Array).has(String(other.name)):
				continue
			var half := _trigger_half_width(other)
			var lo: float = other.global_position.x - half
			var hi: float = other.global_position.x + half
			assert_false(hi > span.x and lo < span.y,
				"%s (x %.1f..%.1f) must not reach into the %s..%s arena (x %.2f..%.2f)" % [other.name, lo, hi, arena[0], arena[1], span.x, span.y])
	slice.free()
