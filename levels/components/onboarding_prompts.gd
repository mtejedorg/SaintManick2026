class_name OnboardingPrompts
extends Node

## I5: first-zone control prompts. On the first zone_entered for SECTOR 01 in a run, plays
## three short cards through SignalBus.banner_requested (the zone title card), spaced
## `spacing` seconds apart. Once per run (run_started resets it); leaving the zone drops the
## cards still pending so they never cut a zone card. Wording copies the pause menu CONTROLS
## block (bindings in project.godot).
## J5: ATTACK comes first (the first runner reaches Nick ~2-3 s in) at `first_delay`. A life
## lost before the last card played re-arms the cards still unplayed: they replay on the
## respawn's zone re-entry after `replay_delay` (clear of the 2.0 s LIFE LOST card). Two more
## one-shot cards per run: the top-down controls `top_down_delay` s after the first camera
## shift into top-down has landed, and BASS DROP READY the first time the meter is full.
## L6 (D34): the Zone 1 cards only play until the player first reaches Zone 2 -- ever. That
## entry sets PlayerProfile.seen_controls (saved); with it set the Zone 1 cards are skipped.
## The TOP-DOWN and BASS DROP cards keep their once-per-run logic, unaffected by the flag.

## The zone whose entry plays the prompts (zone names are "SECTOR NN -- DESCRIPTION").
@export var zone_prefix: String = "SECTOR 01"
## L6: the zone whose first entry marks the controls as seen for good.
@export var seen_zone_prefix: String = "SECTOR 02"
## Seconds after zone entry before the first (ATTACK) card.
@export var first_delay: float = 1.5
## Seconds after a respawn re-entry before the replayed cards (LIFE LOST runs 0.4+1.2+0.4 s).
@export var replay_delay: float = 2.2
## Seconds between the starts of consecutive cards.
@export var spacing: float = 2.5
## Hold of each card; slide-in + hold + slide-out (0.4 + 1.6 + 0.4) stays under `spacing`.
@export var hold: float = 1.6
## Seconds after the first top-down camera_shift_finished(true) before the top-down card.
@export var top_down_delay: float = 1.5

const PROMPTS: Array[String] = [
	"ATTACK  J/X LIGHT \u00b7 K/Y HEAVY",
	"JUMP  SPACE/A      DODGE  SHIFT/RB \u00b7 CTRL/B",
	"MOVE  A/D \u00b7 ARROWS \u00b7 STICK",
]
const TOP_DOWN_PROMPT := "TOP-DOWN  W/A/S/D MOVE IN DEPTH \u00b7 JUMP OFFLINE"
const BASS_DROP_PROMPT := "BASS DROP READY  L / LB"

var _shown: bool = false
var _zone: String = ""
## Index of the next zone card to play (PROMPTS.size() = all played).
var _next_index: int = 0
## True when a life lost re-armed the remaining cards (they replay after replay_delay).
var _replaying: bool = false
## Bumped on cancel/reset: a pending card only fires if its token is still current.
var _token: int = 0
## One-shot extra cards: 0 = not yet, 1 = pending (top-down only), 2 = shown.
var _top_down_card: int = 0
var _bass_drop_shown: bool = false

func _ready() -> void:
	SignalBus.zone_entered.connect(_on_zone_entered)
	SignalBus.run_started.connect(_on_run_started)
	SignalBus.player_life_lost.connect(_on_player_life_lost)
	SignalBus.camera_shift_finished.connect(_on_camera_shift_finished)
	SignalBus.ability_meter_changed.connect(_on_ability_meter_changed)

func _on_run_started() -> void:
	_shown = false
	_zone = ""
	_next_index = 0
	_replaying = false
	_token += 1
	_top_down_card = 0
	_bass_drop_shown = false

func _on_player_life_lost(_lives: int) -> void:
	_token += 1
	# J5: cards not yet played replay on the respawn's zone re-entry.
	if _shown and _next_index < PROMPTS.size():
		_shown = false
		_replaying = true
	if _top_down_card == 1:
		_top_down_card = 0 # dropped before it showed: the next landed shift plays it

func _on_zone_entered(zone_name: String) -> void:
	if seen_zone_prefix != "" and zone_name.begins_with(seen_zone_prefix):
		_mark_controls_seen()
	if not zone_name.begins_with(zone_prefix):
		if _zone != "" and zone_name != _zone:
			_token += 1 # moved on: drop the cards still pending
		return
	if _shown or _controls_seen():
		return
	_shown = true
	_zone = zone_name
	_token += 1
	var start := replay_delay if _replaying else first_delay
	_replaying = false
	var first := _next_index # _show() advances _next_index (a 0 s delay shows at once)
	for i in range(first, PROMPTS.size()):
		_schedule(i, start + spacing * (i - first), _token)

## L6: true once the profile says the player has already reached Zone 2 in some run.
func _controls_seen() -> bool:
	return SaveManager != null and SaveManager.profile != null and SaveManager.profile.seen_controls

func _mark_controls_seen() -> void:
	if SaveManager == null or SaveManager.profile == null or SaveManager.profile.seen_controls:
		return
	SaveManager.profile.seen_controls = true
	SaveManager.save_profile()

func _schedule(index: int, delay: float, token: int) -> void:
	if delay <= 0.0:
		_show(index, token)
		return
	get_tree().create_timer(delay, false).timeout.connect(_show.bind(index, token))

func _show(index: int, token: int) -> void:
	if token != _token or not is_inside_tree():
		return
	_next_index = maxi(_next_index, index + 1)
	SignalBus.banner_requested.emit(PROMPTS[index], hold)

func _on_camera_shift_finished(top_down: bool) -> void:
	if not top_down or _top_down_card != 0:
		return
	_top_down_card = 1
	var token := _token
	if top_down_delay <= 0.0:
		_show_top_down(token)
		return
	get_tree().create_timer(top_down_delay, false).timeout.connect(_show_top_down.bind(token))

func _show_top_down(token: int) -> void:
	if token != _token or _top_down_card != 1 or not is_inside_tree():
		return
	_top_down_card = 2
	SignalBus.banner_requested.emit(TOP_DOWN_PROMPT, hold)

func _on_ability_meter_changed(current: float, max_meter: float) -> void:
	if _bass_drop_shown or max_meter <= 0.0 or current < max_meter:
		return
	_bass_drop_shown = true
	SignalBus.banner_requested.emit(BASS_DROP_PROMPT, hold)
