extends "res://tests/framework/test_case.gd"

# G12: the golden path must be physically walkable. Every rail Nick is snapped to is swept
# with the player's real capsule at ground + 0.1 (walking) and ground + 5.4 (a full-height
# jump, apex ~5.5 m). Any StaticBody / CSG / animatable collider that is NOT in the "gates"
# group (holo walls, the boss gate, the Zone 7 barrier -- the only obstacles allowed to be
# solid on the route, and only while the thing that opens them lies in front of them) is a
# softlock waiting to happen: C14a's 7 m barrier at x=250 sat in
# front of the Enforcer and nothing in the green test gate noticed.

const SLICE_PATH := "res://levels/slice/vertical_slice.tscn"
const RAILS := ["Path_Z1_2_3", "Path_Z4_5_6", "Path_Z7", "Path_Z8", "Path_Z10"]
const STEP := 0.5
const WALK_LIFT := 0.1
const JUMP_LIFT := 5.4
## Gaps (pits, Zone 4 planks) have no ground under the rail: such samples are skipped for
## the walking sweep and reuse the last known ground for the jump sweep.
## Sweeps use a capsule 10 % slimmer than Nick's so a ledge edge he is already standing on
## (the floor probe looks +-FOOTPRINT either side) is not reported as a wall.
const SWEEP_RADIUS_SCALE := 0.9
const FOOTPRINT := 0.45
## Overhead hazards (ceiling pistons) are solid but you walk under them; they only matter for
## the walking sweep, never for the jump-apex sweep.
const RAY_UP := 3.0
const RAY_DOWN := 25.0

var _slice: Node3D

func before_each() -> void:
	GameManager.is_test = true
	_slice = (load(SLICE_PATH) as PackedScene).instantiate()
	add_child(_slice)
	# CSG collision is built on the next idle frame and registered with the physics server
	# on the following physics frame.
	await get_tree().process_frame
	await get_tree().physics_frame
	await get_tree().physics_frame

func after_each() -> void:
	super.after_each()
	if is_instance_valid(_slice):
		_slice.free()

## A gate that is solid at rest is only legal when it sits behind the thing that opens it.
func _gate_seals_route(gate: Node) -> bool:
	var opener: Variant = gate.get("opened_by")
	if not (opener is Node3D):
		return true # solid at rest and nothing opens it
	return (gate as Node3D).global_position.x <= (opener as Node3D).global_position.x

func _is_obstacle(collider: Object, allow_hazards: bool = false) -> bool:
	if not (collider is StaticBody3D or collider is CSGShape3D or collider is AnimatableBody3D):
		return false
	var node := collider as Node
	if node.is_in_group("gates"):
		return _gate_seals_route(node)
	return not (allow_hazards and node.is_in_group("hazards"))

func _player_capsule() -> CapsuleShape3D:
	var player: Node = _slice.get_node("Player")
	for child in player.get_children():
		if child is CollisionShape3D and child.shape is CapsuleShape3D:
			return child.shape
	return null

## Highest floor under Nick's footprint at p (NAN over a gap).
func _ground_y(space: PhysicsDirectSpaceState3D, p: Vector3) -> float:
	var best := NAN
	for dx in [-FOOTPRINT, 0.0, FOOTPRINT]:
		var y := _ground_at(space, p + Vector3(dx, 0, 0))
		if not is_nan(y) and (is_nan(best) or y > best):
			best = y
	return best

func _ground_at(space: PhysicsDirectSpaceState3D, p: Vector3) -> float:
	var from := p + Vector3(0, RAY_UP, 0)
	var to := p - Vector3(0, RAY_DOWN, 0)
	var exclude: Array[RID] = []
	for _i in 8:
		var query := PhysicsRayQueryParameters3D.create(from, to, 1 | 4)
		query.exclude = exclude
		var hit := space.intersect_ray(query)
		if hit.is_empty():
			return NAN
		if _is_obstacle(hit["collider"], true):
			return (hit["position"] as Vector3).y
		exclude.append(hit["rid"]) # a gate / hazard / non-world body: look through it
	return NAN

## Sweeps one rail; returns {"obstacles": {collider_name: [x, ...]}, "samples": n}.
func _sweep(rail_name: String) -> Dictionary:
	var path: Path3D = _slice.get_node(rail_name)
	var capsule := (_player_capsule().duplicate() as CapsuleShape3D)
	capsule.radius *= SWEEP_RADIUS_SCALE
	var space := path.get_world_3d().direct_space_state
	var found := {}
	var samples := 0
	var length := path.curve.get_baked_length()
	var last_ground := NAN
	var d := 0.0
	while d <= length + 0.001:
		var p := path.to_global(path.curve.sample_baked(minf(d, length)))
		var ground := _ground_y(space, p)
		var walking_skip := false
		if is_nan(ground):
			ground = last_ground
			walking_skip = true
		else:
			last_ground = ground
			walking_skip = false
		if not is_nan(ground):
			var lifts := [JUMP_LIFT] if walking_skip else [WALK_LIFT, JUMP_LIFT]
			for lift in lifts:
				# Capsule origin is its centre; the query's origin sits half a height above the feet.
				var centre := Vector3(p.x, ground + lift + capsule.height * 0.5, p.z)
				var query := PhysicsShapeQueryParameters3D.new()
				query.shape = capsule
				query.transform = Transform3D(Basis(), centre)
				query.collision_mask = 1 | 4
				query.exclude = [(_slice.get_node("Player") as CollisionObject3D).get_rid()]
				for hit in space.intersect_shape(query, 16):
					var collider: Object = hit["collider"]
					if _is_obstacle(collider, lift == JUMP_LIFT):
						var key := "%s (lift %.1f)" % [(collider as Node).get_path(), lift]
						if not found.has(key):
							found[key] = []
						found[key].append(snappedf(p.x, 0.1))
			samples += 1
		d += STEP
	return {"obstacles": found, "samples": samples}


func test_no_rail_is_blocked_by_a_solid_that_is_not_a_gate() -> void:
	assert_not_null(_player_capsule(), "Player capsule found")
	for rail_name in RAILS:
		var result := _sweep(rail_name)
		assert_gt(result["samples"], 10, "%s was actually swept (%d samples)" % [rail_name, result["samples"]])
		for key in result["obstacles"].keys():
			var xs: Array = result["obstacles"][key]
			assert_true(false, "%s blocked by %s at x=%.1f..%.1f (%d samples)" % [rail_name, key, xs.min(), xs.max(), xs.size()])

func test_the_zone7_barrier_is_a_gate() -> void:
	assert_true(_slice.get_node("Z7_Barrier").is_in_group("gates"), "Z7_Barrier is in the gates group")
	assert_true(_slice.get_node("LeftGate").is_in_group("gates"), "LeftGate is in the gates group")
