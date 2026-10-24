class_name HoloGate
extends CSGBox3D

## A barrier that stays solid until the Enforcer (Zone 7 mini-boss) is defeated, then drops
## its collision and disappears so the route to Zone 8 opens behind the fight.
## Joins the "gates" group: the golden-path traversal test treats gates as the only legal
## static obstacles on a rail.

## The enemy whose death opens this gate. A gate that is solid at rest may only sit BEHIND
## its opener along the rail, or it seals the route before anything can open it
## (test_golden_path_traversal enforces this).
@export var opened_by: Node3D

func _ready() -> void:
	add_to_group("gates")
	SignalBus.miniboss_defeated.connect(open)

## Deferred collision change: miniboss_defeated can be emitted from inside a physics callback
## (the Enforcer's death), where shape changes are blocked.
func open() -> void:
	set_deferred("use_collision", false)
	set_deferred("visible", false)
