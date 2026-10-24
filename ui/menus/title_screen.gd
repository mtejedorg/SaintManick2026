extends CanvasLayer

## Boot screen. START RUN goes to Karen's Shop (where the booster is chosen and the run
## starts, per VerticalSlice.md). The logo pulses subtly on the Conductor's primary beat.

const SHOP_SCENE := "res://ui/shop/karens_shop.tscn"
const PULSE_SCALE := 1.03
const PULSE_TIME := 0.15

@onready var logo: TextureRect = $Root/Logo
@onready var start_button: Button = $Root/ButtonContainer/StartButton
@onready var quit_button: Button = $Root/ButtonContainer/QuitButton

var _pulse_tween: Tween

func _ready() -> void:
	start_button.pressed.connect(_on_start_pressed)
	quit_button.pressed.connect(_on_quit_pressed)
	SignalBus.beat.connect(_on_beat)
	logo.resized.connect(_update_logo_pivot)
	_update_logo_pivot()
	# Gamepad navigation: focus the first button.
	start_button.grab_focus()

func _update_logo_pivot() -> void:
	logo.pivot_offset = logo.size / 2.0

func _on_beat(layer: String, _beat_index: int) -> void:
	if layer != "primary":
		return
	if _pulse_tween:
		_pulse_tween.kill()
	logo.scale = Vector2(PULSE_SCALE, PULSE_SCALE)
	_pulse_tween = create_tween()
	_pulse_tween.tween_property(logo, "scale", Vector2.ONE, PULSE_TIME).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)

func _on_start_pressed() -> void:
	get_tree().change_scene_to_file(SHOP_SCENE)

func _on_quit_pressed() -> void:
	get_tree().quit()
