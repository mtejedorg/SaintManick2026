extends RefCounted
## Preload as `const BodyFacing = preload("res://characters/shared/body_facing.gd")`.

## Yaw-only facing for character bodies whose model front is +Z (Enforcer, Headliner).
## The body never pitches or rolls toward a target above/below it, and the turn eases in
## instead of snapping.

## The global yaw at which a +Z-front body at `from` faces `to` (height ignored).
static func yaw_to(from: Vector3, to: Vector3) -> float:
	return atan2(to.x - from.x, to.z - from.z)

## Turns `body` toward `target` at roughly `rate` rad/s (lerp_angle weight rate * delta),
## yaw only — pitch and roll are always zeroed. No-op when the target is (nearly) on top.
static func turn_toward(body: Node3D, target: Vector3, rate: float, delta: float) -> void:
	var flat := target - body.global_position
	flat.y = 0.0
	if flat.length_squared() < 0.01:
		return
	var yaw := lerp_angle(body.global_rotation.y, yaw_to(body.global_position, target), clampf(rate * delta, 0.0, 1.0))
	body.global_rotation = Vector3(0.0, yaw, 0.0)

## `target` moved to the body's own height, so look_at never pitches the body.
static func flat_target(body: Node3D, target: Vector3) -> Vector3:
	return Vector3(target.x, body.global_position.y, target.z)
