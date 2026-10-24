class_name PlayerState
extends State

var player: PlayerController

func _ready() -> void:
	await owner.ready
	player = owner as PlayerController
	if not player:
		push_warning("PlayerState must be a child of a PlayerController scene.")

## Self-healing animation-controller lookup for enter(). The StateMachine enters its
## initial state from its own _ready(), BEFORE PlayerController's @onready
## animation_controller is assigned (the owner readies after its children) — so fall back
## to the sibling node, whose own _ready has already resolved its AnimationPlayer.
func _anim() -> PlayerAnimationController:
	if not player and owner:
		player = owner as PlayerController
	if player and player.animation_controller:
		return player.animation_controller
	if owner:
		return owner.get_node_or_null("PlayerAnimationController") as PlayerAnimationController
	return null
