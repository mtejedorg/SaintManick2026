class_name DroneCamera
extends Camera3D

@export var target: Node3D
@export var smooth_speed: float = 5.0

# Current active offset and rotation (managed by states and tweened in transition)
var offset: Vector3 = Vector3(0, 3, 10)

var base_position: Vector3 = Vector3.ZERO
var shake_strength: float = 0.0
var shake_duration: float = 0.0
var shake_timer: float = 0.0
var shake_offset: Vector3 = Vector3.ZERO

@onready var state_machine: StateMachine = $StateMachine

func _ready() -> void:
	SignalBus.camera_shift_requested.connect(_on_camera_shift_requested)
	SignalBus.camera_shake_requested.connect(_on_camera_shake_requested)
	state_machine.process_priority = -1
	state_machine.process_physics_priority = -1
	base_position = global_position

func _physics_process(delta: float) -> void:
	if shake_timer > 0.0:
		shake_timer -= delta
		if shake_timer <= 0.0:
			shake_timer = 0.0
			shake_offset = Vector3.ZERO
		else:
			var current_strength := current_shake_strength()
			shake_offset = Vector3(
				randf_range(-current_strength, current_strength),
				randf_range(-current_strength, current_strength),
				randf_range(-current_strength, current_strength)
			)
	else:
		shake_offset = Vector3.ZERO
		
	global_position = base_position + shake_offset

## J2: overlapping shakes merge like HitStop's stops -- a weaker request (a light hit's
## 0.05) never cancels a running stronger one (piston 0.4, Bass Drop 0.3): it only replaces
## the shake when it is at least as strong as the current decayed strength; otherwise the
## stronger shake keeps going, stretched to the longer remaining time.
func _on_camera_shake_requested(strength: float, duration: float) -> void:
	var current := current_shake_strength()
	if strength >= current:
		shake_strength = strength
		shake_duration = duration
		shake_timer = duration
		return
	if duration > shake_timer:
		# Re-base on the current strength so the stretch does not jump the amplitude.
		shake_strength = current
		shake_duration = duration
		shake_timer = duration

## The decayed amplitude of the running shake (0 when none).
func current_shake_strength() -> float:
	if shake_timer <= 0.0 or shake_duration <= 0.0:
		return 0.0
	return (shake_timer / shake_duration) * shake_strength

## Respawn/teleport: jump straight to a mode with no transition tween. Leaving
## Transitioning kills its tween (Tween.kill() never emits finished), so an in-flight shift
## can't land afterwards and re-apply its own rail/jump settings.
func snap_to_mode(top_down: bool) -> void:
	var transitioning_state = state_machine.states.get("transitioning")
	if transitioning_state and transitioning_state.current_tween:
		transitioning_state.current_tween.kill()
		transitioning_state.current_tween = null
	var mode := "topdown" if top_down else "sidescroll"
	if state_machine.current_state == state_machine.states.get(mode):
		state_machine.current_state.enter() # already there — re-apply offset/rotation/jump
	else:
		state_machine._on_transition_requested(mode)

## True while the camera FSM is tweening between modes.
func is_shifting() -> bool:
	var transitioning_state = state_machine.states.get("transitioning")
	return transitioning_state != null and state_machine.current_state == transitioning_state

## Where the in-flight shift is heading (top_down, path). Only meaningful while is_shifting().
## Top-down is always free movement, so its path is null whatever was requested.
func shift_destination() -> Dictionary:
	var transitioning_state = state_machine.states.get("transitioning")
	if transitioning_state == null:
		return {"top_down": false, "path": null}
	var top_down: bool = transitioning_state.target_top_down
	var path: Path3D = null if top_down else transitioning_state.target_path
	return {"top_down": top_down, "path": path}

func _on_camera_shift_requested(top_down: bool, target_path: Path3D, transition_time: float) -> void:
	var transitioning_state = state_machine.states.get("transitioning")
	if transitioning_state:
		transitioning_state.setup_transition(top_down, target_path, transition_time)
		state_machine._on_transition_requested("Transitioning")

