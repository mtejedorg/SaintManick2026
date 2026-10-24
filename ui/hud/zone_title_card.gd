extends Control
## ZoneTitleCard — cinematic zone name banner.
## Slides in from left (fading in as it moves), holds, slides out to right (fading out).
## Connected to SignalBus.zone_entered. Other systems (e.g. the HUD's life-lost banner)
## reuse the card through show_text().

const SLIDE_IN_TIME  := 0.4
const HOLD_TIME      := 2.0
const SLIDE_OUT_TIME := 0.4

@onready var label: Label = $Label

var _tween: Tween

func _ready() -> void:
	modulate.a = 0.0
	visible = false
	SignalBus.zone_entered.connect(_on_zone_entered)

func _on_zone_entered(zone_name: String) -> void:
	show_text(zone_name)

## Plays the banner with arbitrary text. `hold` is the seconds the card rests on screen
## between the slide-in and the slide-out.
func show_text(text: String, hold: float = HOLD_TIME) -> void:
	label.text = text
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
	_tween.tween_callback(func() -> void:
		visible = false
		position.x = 0.0
	)
