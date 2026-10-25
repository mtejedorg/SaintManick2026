class_name OnboardingPrompts
extends Node

## I5: first-zone control prompts. On the first zone_entered for SECTOR 01 in a run, plays
## three short cards through SignalBus.banner_requested (the zone title card), spaced
## `spacing` seconds apart and starting after the zone's own card has slid out. Once per
## run (run_started resets it); leaving the zone or losing a life drops the cards still
## pending so they never cut a zone or LIFE LOST card. Wording copies the pause menu
## CONTROLS block (bindings in project.godot).

## The zone whose entry plays the prompts (zone names are "SECTOR NN -- DESCRIPTION").
@export var zone_prefix: String = "SECTOR 01"
## Seconds after zone entry before the first card: the zone card runs 0.4 + 2.0 + 0.4 s.
@export var first_delay: float = 3.0
## Seconds between the starts of consecutive cards.
@export var spacing: float = 2.5
## Hold of each card; slide-in + hold + slide-out (0.4 + 1.6 + 0.4) stays under `spacing`.
@export var hold: float = 1.6

const PROMPTS: Array[String] = [
	"MOVE  A/D \u00b7 ARROWS \u00b7 STICK",
	"JUMP  SPACE/A      DODGE  SHIFT/RB \u00b7 CTRL/B",
	"ATTACK  J/X LIGHT \u00b7 K/Y HEAVY",
]

var _shown: bool = false
var _zone: String = ""
## Bumped on cancel/reset: a pending card only fires if its token is still current.
var _token: int = 0

func _ready() -> void:
	SignalBus.zone_entered.connect(_on_zone_entered)
	SignalBus.run_started.connect(_on_run_started)
	SignalBus.player_life_lost.connect(_on_player_life_lost)

func _on_run_started() -> void:
	_shown = false
	_zone = ""
	_token += 1

func _on_player_life_lost(_lives: int) -> void:
	_token += 1

func _on_zone_entered(zone_name: String) -> void:
	if not zone_name.begins_with(zone_prefix):
		if _zone != "" and zone_name != _zone:
			_token += 1 # moved on: drop the cards still pending
		return
	if _shown:
		return
	_shown = true
	_zone = zone_name
	_token += 1
	for i in PROMPTS.size():
		_schedule(i, first_delay + spacing * i, _token)

func _schedule(index: int, delay: float, token: int) -> void:
	if delay <= 0.0:
		_show(index, token)
		return
	get_tree().create_timer(delay, false).timeout.connect(_show.bind(index, token))

func _show(index: int, token: int) -> void:
	if token != _token or not is_inside_tree():
		return
	SignalBus.banner_requested.emit(PROMPTS[index], hold)
