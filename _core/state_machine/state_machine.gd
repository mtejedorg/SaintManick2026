class_name StateMachine
extends Node

@export var initial_state: State

var current_state: State
var states: Dictionary = {}

func _ready() -> void:
	for child in get_children():
		if child is State:
			states[child.name.to_lower()] = child
			child.transition_requested.connect(_on_transition_requested)
	
	if initial_state:
		initial_state.enter()
		current_state = initial_state

func _process(delta: float) -> void:
	if current_state:
		current_state.update(delta)

func _physics_process(delta: float) -> void:
	if current_state:
		current_state.physics_update(delta)

func _unhandled_input(event: InputEvent) -> void:
	if current_state:
		current_state.handle_input(event)

## Q5: the public way in for callers outside the machine (the owner, a camera, a test):
## enters the state named `state_name` (case-insensitive). An unknown name is an error, a
## transition to the running state is a no-op. Deferrable as
## `state_machine.transition_to.call_deferred("StateDead")`.
func transition_to(state_name: String) -> void:
	var key := state_name.to_lower()
	if not states.has(key):
		push_error("StateMachine: state " + state_name + " does not exist.")
		return
	_enter_state(states[key])

## A child state's transition_requested signal. Kept lenient (a warning) -- states only
## ever request their siblings.
func _on_transition_requested(new_state_name: String) -> void:
	var key := new_state_name.to_lower()
	if not states.has(key):
		push_warning("State Machine: state " + new_state_name + " does not exist.")
		return
	_enter_state(states[key])

func _enter_state(next: State) -> void:
	if current_state == next:
		return
	if current_state:
		current_state.exit()
	current_state = next
	current_state.enter()
