extends Control
## ZoneTitleCard — cinematic zone name banner.
## Slides in from left (fading in as it moves), holds, slides out to right (fading out).
## Connected to SignalBus.zone_entered and SignalBus.banner_requested. Other systems (e.g.
## the HUD's life-lost banner) reuse the card through show_text().
##
## U1: a PRIORITY card (life lost, boss phase cue) is not cut short by a zone_entered that
## arrives while it is on screen — a respawn teleports Nick into the re-armed checkpoint
## trigger 1-2 frames after the life-lost banner. A zone already announced is dropped; a new
## zone is queued and plays as soon as the priority card has finished.

const SLIDE_IN_TIME  := 0.4
const HOLD_TIME      := 2.0
const SLIDE_OUT_TIME := 0.4

@onready var label: Label = $Label

var _tween: Tween
## True while a priority card is on screen (cleared when its slide-out finishes). Tied to
## the card's own tween rather than a wall-clock timestamp so it pauses with the HUD.
var _priority_active: bool = false
## Zone names already shown by zone_entered (a respawn re-enters them).
var _announced_zones: Dictionary = {}
## A new zone that arrived during a priority card; played right after it.
var _queued_zone: String = ""

func _ready() -> void:
	modulate.a = 0.0
	visible = false
	SignalBus.zone_entered.connect(_on_zone_entered)
	SignalBus.banner_requested.connect(_on_banner_requested)

func _on_zone_entered(zone_name: String) -> void:
	if _priority_active:
		if not _announced_zones.has(zone_name):
			_queued_zone = zone_name
		return
	_announce_zone(zone_name)

func _announce_zone(zone_name: String) -> void:
	_announced_zones[zone_name] = true
	show_text(zone_name)

func _on_banner_requested(text: String, hold: float) -> void:
	show_text(text, hold, true)

## Plays the banner with arbitrary text. `hold` is the seconds the card rests on screen
## between the slide-in and the slide-out. A `priority` card holds off zone_entered cards
## until it has finished (see the header).
func show_text(text: String, hold: float = HOLD_TIME, priority: bool = false) -> void:
	label.text = text
	_priority_active = priority
	_play_card(hold)

func _play_card(hold: float) -> void:
	if _tween:
		_tween.kill()

	visible = true

	# Start offscreen to the left
	var viewport_w: float = get_viewport_rect().size.x
	position.x = -viewport_w
	modulate.a = 0.0

	_tween = create_tween().set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)

	# Slide in — the fade runs in parallel so the card is visible while it moves
	_tween.tween_property(self, "position:x", 0.0, SLIDE_IN_TIME)
	_tween.parallel().tween_property(self, "modulate:a", 1.0, SLIDE_IN_TIME)
	# Hold
	_tween.tween_interval(hold)
	# Slide out — ease in for the exit, fading out while it moves
	_tween.set_ease(Tween.EASE_IN)
	_tween.tween_property(self, "position:x", viewport_w, SLIDE_OUT_TIME)
	_tween.parallel().tween_property(self, "modulate:a", 0.0, SLIDE_OUT_TIME)
	# Hide after animation
	_tween.tween_callback(_on_card_finished)

func _on_card_finished() -> void:
	visible = false
	position.x = 0.0
	_priority_active = false
	if _queued_zone != "":
		var zone_name := _queued_zone
		_queued_zone = ""
		_announce_zone(zone_name)
