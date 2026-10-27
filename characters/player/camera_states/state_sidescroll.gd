class_name StateSidescroll
extends CameraState

## P8: the side-scroll drone leads Nick by LOOK_AHEAD metres in the direction he faces (the
## lead eases over at LEAD_SPEED per second, so a turn swings the frame rather than snapping
## it), and holds its height while he is airborne: y only follows when he stands on a floor
## or strays more than VERTICAL_DEAD_ZONE from the held height (then it trails at the zone's
## edge), so the ground no longer bobs on every hop.
const LOOK_AHEAD := 2.5
const LEAD_SPEED := 3.0
const VERTICAL_DEAD_ZONE := 2.5

## Current horizontal lead (world x metres, signed).
var lead: float = 0.0
## The height the frame is anchored to (the last ground height, or the dead-zone edge).
var held_y: float = 0.0
var _has_held_y: bool = false

func enter() -> void:
	camera.offset = DroneCamera.SIDESCROLL_OFFSET
	camera.rotation = Vector3.ZERO
	_has_held_y = false
	if camera.target and "is_jump_enabled" in camera.target:
		camera.target.is_jump_enabled = true

func physics_update(delta: float) -> void:
	if not camera.target:
		return
	var target_pos: Vector3 = camera.target.global_position
	lead = lerpf(lead, facing_sign() * LOOK_AHEAD, clampf(LEAD_SPEED * delta, 0.0, 1.0))
	_update_held_y(target_pos.y)
	var target_position := Vector3(target_pos.x + lead, held_y, target_pos.z) + camera.offset
	camera.base_position = camera.base_position.lerp(target_position, camera.smooth_speed * delta)
	camera.rotation = Vector3.ZERO

## +1 facing right (the default for targets without a facing), -1 facing left.
func facing_sign() -> float:
	var facing = camera.target.get("is_facing_right")
	return -1.0 if facing == false else 1.0

func _update_held_y(target_y: float) -> void:
	if not _has_held_y or _is_grounded():
		held_y = target_y
		_has_held_y = true
		return
	var dy := target_y - held_y
	if absf(dy) > VERTICAL_DEAD_ZONE:
		held_y = target_y - signf(dy) * VERTICAL_DEAD_ZONE

## Targets that are not a CharacterBody3D (test mocks, cinematics) count as grounded.
func _is_grounded() -> bool:
	if camera.target.has_method("is_on_floor"):
		return camera.target.is_on_floor()
	return true
