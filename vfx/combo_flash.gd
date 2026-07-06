## Combo flash — brief white screen overlay triggered by SignalBus.combo_increased.
## Sits on a high-layer CanvasLayer so it renders above all HUD elements.
extends CanvasLayer

@onready var rect: ColorRect = $ColorRect
var _tween: Tween = null

const FLASH_ALPHA: float = 0.15
const FLASH_DURATION: float = 0.08

func _ready() -> void:
	layer = 10
	rect.color = Color(1.0, 1.0, 1.0, 0.0)
	SignalBus.combo_increased.connect(_on_combo_increased)

func _on_combo_increased(_combo: int) -> void:
	if _tween:
		_tween.kill()
	rect.color = Color(1.0, 1.0, 1.0, FLASH_ALPHA)
	_tween = create_tween()
	_tween.tween_property(rect, "color:a", 0.0, FLASH_DURATION).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
