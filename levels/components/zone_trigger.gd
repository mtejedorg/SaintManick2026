class_name ZoneTrigger
extends Area3D
## Lightweight single-use trigger that emits SignalBus.zone_entered.
## Use for zones that don't have a ZoneEncounter (platforming, escape, elevator, boss).

@export var zone_name: String = ""

func _ready() -> void:
	body_entered.connect(_on_body_entered)

func _on_body_entered(body: Node3D) -> void:
	if body is PlayerController and zone_name != "":
		SignalBus.zone_entered.emit(zone_name)
		# Fire once only
		set_deferred("monitoring", false)
