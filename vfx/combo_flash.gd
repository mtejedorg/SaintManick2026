## Combo flash — brief white screen overlay triggered by SignalBus.combo_increased.
## Sits on a high-layer CanvasLayer so it renders above all HUD elements.
## P10: the same (single, reused) overlay also plays SignalBus.screen_flash_requested
## flashes (the Bass Drop detonation) at the requested alpha/duration.
extends CanvasLayer

@onready var rect: ColorRect = $ColorRect
var _tween: Tween = null

const FLASH_ALPHA: float = 0.15
const FLASH_DURATION: float = 0.08

func _ready() -> void:
	layer = 10
	rect.color = Color(1.0, 1.0, 1.0, 0.0)
	SignalBus.combo_increased.connect(_on_combo_increased)
	SignalBus.screen_flash_requested.connect(flash)

func _on_combo_increased(_combo: int) -> void:
	flash(FLASH_ALPHA, FLASH_DURATION)

## Snaps the overlay to white at `alpha` and fades it out over `duration` seconds. A weaker
## flash never cuts a stronger one that is still brighter.
func flash(alpha: float, duration: float) -> void:
	if _tween and _tween.is_valid() and rect.color.a > alpha:
		return
	if _tween:
		_tween.kill()
	rect.color = Color(1.0, 1.0, 1.0, alpha)
	_tween = create_tween()
	_tween.tween_property(rect, "color:a", 0.0, duration).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
