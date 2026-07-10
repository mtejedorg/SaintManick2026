class_name ZoneTrigger
extends Area3D
## Lightweight single-use trigger that emits SignalBus.zone_entered.
## Use for zones that don't have a ZoneEncounter (platforming, escape, elevator, boss).

@export var zone_name: String = ""

func _ready() -> void:
	body_entered.connect(_on_body_entered)
	SignalBus.player_respawned.connect(_on_player_respawned)

func _on_body_entered(body: Node3D) -> void:
	if body is PlayerController and zone_name != "":
		SignalBus.zone_entered.emit(zone_name)
		# Fire once only
		set_deferred("monitoring", false)

## T3: a checkpoint respawn re-arms the trigger so crossing back into the zone
## re-announces it — boss activations (Enforcer SECTOR 07, Headliner Zone10_Trigger)
## and zone music hang off zone_entered, and GameManager._zones_seen already prevents
## double-counting. play_music no-ops on the same track, so re-fires are audio-safe.
func _on_player_respawned() -> void:
	set_deferred("monitoring", true)
