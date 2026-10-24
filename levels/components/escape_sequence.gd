class_name EscapeSequence
extends Node3D

signal escape_completed

@export var path_z8: Path3D
@export var kill_wall: Node3D
@export var end_trigger: Area3D
## Rare Scrap ("cells" in code, GDD §5.1) awarded for completing the Zone 8 rhythmic
## escape sequence — one of the "successfully completing the rhythmic/musical sections"
## rewards called out alongside stronger mid-journey enemy drops.
@export var cells_reward: int = 10

var is_active: bool = false

## How far behind Nick the wall starts (and restarts after a respawn), in metres.
@export var wall_start_gap: float = 10.0

func _ready() -> void:
	SignalBus.miniboss_defeated.connect(_on_miniboss_defeated)
	SignalBus.player_respawned.connect(_on_player_respawned)
	if end_trigger:
		end_trigger.body_entered.connect(_on_end_trigger_body_entered)

func _on_miniboss_defeated() -> void:
	is_active = true
	# Shift camera to Path_Z8
	SignalBus.camera_shift_requested.emit(false, path_z8, 1.5)
	# The wall is authored far ahead of the Enforcer arena and dormant (monitoring off):
	# park it behind Nick's current position, THEN start it (which arms its damage area).
	var player := _find_player()
	if kill_wall and player:
		kill_wall.global_position.x = player.global_position.x - wall_start_gap
	if kill_wall and kill_wall.has_method("start_moving"):
		kill_wall.start_moving()

## Dying mid-escape respawns Nick at the zone checkpoint: re-park the wall behind THAT spot
## (it keeps moving), otherwise it would be 100+ m ahead of or on top of him.
func _on_player_respawned() -> void:
	if not is_active or not kill_wall:
		return
	kill_wall.global_position.x = GameManager.checkpoint_position.x - wall_start_gap

func _physics_process(_delta: float) -> void:
	if not is_active or not kill_wall or not end_trigger:
		return
	# Once the wall has swept past the exit it has nothing left to chase: park it.
	if kill_wall.get("is_moving") and kill_wall.global_position.x >= end_trigger.global_position.x 			and kill_wall.has_method("stop_moving"):
		kill_wall.stop_moving()

func _find_player() -> Node3D:
	var scene := get_tree().current_scene
	if scene == null:
		return null
	return scene.get_node_or_null("Player") as Node3D

func _on_end_trigger_body_entered(body: Node3D) -> void:
	if not is_active:
		return
	if body is PlayerController:
		is_active = false
		if kill_wall and kill_wall.has_method("stop_moving"):
			kill_wall.stop_moving()
		if cells_reward > 0:
			GameManager.add_cells(cells_reward)
		escape_completed.emit()
		print("Escape sequence completed!")
