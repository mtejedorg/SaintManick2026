class_name HeadlinerStateMachine
extends Node

@export var initial_state: HeadlinerState

var current_state: HeadlinerState
var states: Dictionary = {}

func init(boss: HeadlinerBoss) -> void:
	for child in get_children():
		if child is HeadlinerState:
			states[child.name] = child
			child.boss = boss
			child.state_machine = self
			
	if initial_state:
		transition_to(initial_state.name)

func transition_to(state_name: String) -> void:
	if not states.has(state_name):
		push_error("HeadlinerStateMachine: State " + state_name + " not found!")
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
