extends CanvasLayer

## Boot screen. START RUN goes to Karen's Shop (where the booster is chosen and the run
## starts, per VerticalSlice.md). The logo pulses subtly on the Conductor's primary beat.

const SHOP_SCENE := "res://ui/shop/karens_shop.tscn"
const SLICE_SCENE := "res://levels/slice/vertical_slice.tscn"
## D32 export smoke: release templates refuse a scene path on the command line, so the
## exported exe is driven into the slice with a user arg: `SaintManick.exe ... -- --start-run`.
const AUTOSTART_ARG := "--start-run"
const PULSE_SCALE := 1.03
const PULSE_TIME := 0.15

@onready var logo: TextureRect = $Root/Logo
@onready var start_button: Button = $Root/ButtonContainer/StartButton
@onready var quit_button: Button = $Root/ButtonContainer/QuitButton
@onready var options_button: Button = $Root/ButtonContainer/OptionsButton
@onready var button_container: Control = $Root/ButtonContainer
@onready var options_menu: Control = $Root/OptionsMenu

var _pulse_tween: Tween

func _ready() -> void:
	# L8: boot applies the saved options (volumes, fullscreen) once the profile has loaded.
	if SaveManager:
		SaveManager.apply_settings()
	start_button.pressed.connect(_on_start_pressed)
	options_button.pressed.connect(_on_options_pressed)
	options_menu.closed.connect(_on_options_closed)
	quit_button.pressed.connect(_on_quit_pressed)
	SignalBus.beat.connect(_on_beat)
	logo.resized.connect(_update_logo_pivot)
	_update_logo_pivot()
	# Gamepad navigation: focus the first button.
	start_button.grab_focus()
	if wants_autostart(OS.get_cmdline_user_args()):
		_autostart_run.call_deferred()

## True when the user args (after `--`) ask for an immediate run (export smoke / CI).
static func wants_autostart(user_args: PackedStringArray) -> bool:
	return AUTOSTART_ARG in user_args

func _autostart_run() -> void:
	if GameManager:
		GameManager.start_new_run()
	get_tree().change_scene_to_file(SLICE_SCENE)

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

## L8: the options panel stands in for the button column until it closes.
func _on_options_pressed() -> void:
	button_container.hide()
	options_menu.open()

func _on_options_closed() -> void:
	button_container.show()
	options_button.grab_focus()

func _on_quit_pressed() -> void:
	get_tree().quit()
