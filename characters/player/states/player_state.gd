class_name PlayerState
extends State

var player: PlayerController

func _ready() -> void:
	await owner.ready
	player = owner as PlayerController
	if not player:
		push_warning("PlayerState must be a child of a PlayerController scene.")
