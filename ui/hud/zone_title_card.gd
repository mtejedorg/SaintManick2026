extends Control
## ZoneTitleCard — cinematic zone name banner.
## Slides in from left, holds, slides out to right.
## Connected to SignalBus.zone_entered.

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
	label.text = zone_name
	_play_card()

func _play_card() -> void:
	if _tween:
		_tween.kill()

	visible = true

	# Start offscreen to the left
	var viewport_w: float = get_viewport_rect().size.x
	position.x = -viewport_w

	_tween = create_tween().set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)

	# Slide in
	_tween.tween_property(self, "position:x", 0.0, SLIDE_IN_TIME)
	_tween.tween_property(self, "modulate:a", 1.0, SLIDE_IN_TIME).from(0.0)
	# Hold
	_tween.tween_interval(HOLD_TIME)
	# Slide out — ease in for the exit
	_tween.set_ease(Tween.EASE_IN)
	_tween.tween_property(self, "position:x", viewport_w, SLIDE_OUT_TIME)
	_tween.tween_property(self, "modulate:a", 0.0, SLIDE_OUT_TIME)
	# Hide after animation
	_tween.tween_callback(func() -> void:
		visible = false
		position.x = 0.0
	)
