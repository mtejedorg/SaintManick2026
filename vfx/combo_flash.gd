## Combo flash — brief white screen overlay for combo milestones.
## U4 (owner decision D36, option A, REVERSIBLE: set FLASH_EVERY to 1 and flash on every
## combo_increased again to get the old strobe back): the flash used to fire on EVERY
## combo_increased, a strobe in a long chain. It now fires only on SignalBus.combo_capped and on
## every FLASH_EVERY-th combo, at the dimmer FLASH_ALPHA / shorter FLASH_DURATION below.
## Sits on a high-layer CanvasLayer so it renders above all HUD elements.
## P10: the same (single, reused) overlay also plays SignalBus.screen_flash_requested
## flashes (the Bass Drop detonation) at the requested alpha/duration.
extends CanvasLayer

@onready var rect: ColorRect = $ColorRect
var _tween: Tween = null

const FLASH_ALPHA: float = 0.12
const FLASH_DURATION: float = 0.05
## U4: a combo_increased flashes only when the count is a multiple of this.
const FLASH_EVERY: int = 10
## V6: Reduce Flashes multiplies the flash alpha by this.
const REDUCED_ALPHA_FACTOR: float = 0.5

## How many milestone flashes fired (tests; Bass Drop's screen_flash_requested does not count).
var milestone_flashes: int = 0

func _ready() -> void:
	layer = 10
	rect.color = Color(1.0, 1.0, 1.0, 0.0)
	SignalBus.combo_increased.connect(_on_combo_increased)
	SignalBus.combo_capped.connect(_on_combo_capped)
	SignalBus.screen_flash_requested.connect(flash)

func _on_combo_increased(combo: int) -> void:
	if combo > 0 and combo % FLASH_EVERY == 0:
		_milestone_flash()

func _on_combo_capped() -> void:
	_milestone_flash()

func _milestone_flash() -> void:
	milestone_flashes += 1
	flash(FLASH_ALPHA, FLASH_DURATION)

## Snaps the overlay to white at `alpha` and fades it out over `duration` seconds. A weaker
## flash never cuts a stronger one that is still brighter.
func flash(alpha: float, duration: float) -> void:
	# V6 (accessibility): Reduce Flashes halves every flash, milestone or requested.
	if GameManager.reduce_flashes():
		alpha *= REDUCED_ALPHA_FACTOR
	if _tween and _tween.is_valid() and rect.color.a > alpha:
		return
	if _tween:
		_tween.kill()
	rect.color = Color(1.0, 1.0, 1.0, alpha)
	_tween = create_tween()
	_tween.tween_property(rect, "color:a", 0.0, duration).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
