class_name EnforcerStateMachine
extends Node

@export var initial_state: EnforcerState

var current_state: EnforcerState
var states: Dictionary = {}

func init(enforcer: EnforcerEnemy) -> void:
	for child in get_children():
		if child is EnforcerState:
			states[child.name] = child
			child.enforcer = enforcer
			child.state_machine = self
			
	if initial_state:
		transition_to(initial_state.name)

func transition_to(state_name: String) -> void:
	if not states.has(state_name):
		push_error("EnforcerStateMachine: State " + state_name + " not found!")
		return
		
	if current_state:
		current_state.exit()
		
	current_state = states[state_name]
	current_state.enter()

func physics_process(delta: float) -> void:
	if current_state:
		current_state.physics_update(delta)

func handle_beat(layer: String, beat_index: int) -> void:
	if current_state:
		current_state.on_beat(layer, beat_index)
