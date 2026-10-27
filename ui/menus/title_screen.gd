extends CanvasLayer

## Boot screen. Batch O: START DEMO opens the demo loadout (the public demo is the slice with
## no shop -- GameManager.demo_mode); START RUN stands in for Level One until it exists and
## goes to Karen's Shop (booster pick, then the slice) exactly as before. The logo pulses
## subtly on the Conductor's primary beat.

const SHOP_SCENE := "res://ui/shop/karens_shop.tscn"
const SLICE_SCENE := "res://levels/slice/vertical_slice.tscn"
## D32 export smoke: release templates refuse a scene path on the command line, so the
## exported exe is driven into the slice with a user arg: `SaintManick.exe ... -- --start-run`.
## Batch O: that starts a DEMO run directly (no loadout, no boosters), so the smoke never
## depends on the shop or on the profile's equipped boosters.
const AUTOSTART_ARG := "--start-run"
const PULSE_SCALE := 1.03
const PULSE_TIME := 0.15

@onready var logo: TextureRect = $Root/Logo
@onready var start_demo_button: Button = $Root/ButtonContainer/StartDemoButton
@onready var start_button: Button = $Root/ButtonContainer/StartRunGroup/StartRunButton
@onready var quit_button: Button = $Root/ButtonContainer/QuitButton
@onready var options_button: Button = $Root/ButtonContainer/OptionsButton
@onready var button_container: Control = $Root/ButtonContainer
@onready var options_menu: Control = $Root/OptionsMenu
@onready var demo_loadout: Control = $Root/DemoLoadout

var _pulse_tween: Tween

## Scene-change hook (path) -> void; a seam so tests can observe navigation.
var change_scene: Callable = _change_scene_to

func _ready() -> void:
	# L8: boot applies the saved options (volumes, fullscreen) once the profile has loaded.
	if SaveManager:
		SaveManager.apply_settings()
	start_demo_button.pressed.connect(_on_start_demo_pressed)
	demo_loadout.closed.connect(_on_demo_loadout_closed)
	start_button.pressed.connect(_on_start_pressed)
	options_button.pressed.connect(_on_options_pressed)
	options_menu.closed.connect(_on_options_closed)
	quit_button.pressed.connect(_on_quit_pressed)
	SignalBus.beat.connect(_on_beat)
	logo.resized.connect(_update_logo_pivot)
	_update_logo_pivot()
	_wire_focus()
	# Gamepad navigation: focus the first button.
	start_demo_button.grab_focus()
	if wants_autostart(OS.get_cmdline_user_args()):
		_autostart_run.call_deferred()

## True when the user args (after `--`) ask for an immediate run (export smoke / CI).
static func wants_autostart(user_args: PackedStringArray) -> bool:
	return AUTOSTART_ARG in user_args

func _autostart_run() -> void:
	if GameManager:
		GameManager.demo_boosters.clear()
		GameManager.start_new_run(true)
	change_scene.call(SLICE_SCENE)

func _change_scene_to(path: String) -> void:
	get_tree().change_scene_to_file(path)

## The four buttons in column order (the START RUN sub-label is not focusable).
func menu_buttons() -> Array[Button]:
	return [start_demo_button, start_button, options_button, quit_button]

## Up/down walk the column top -> bottom and wrap.
func _wire_focus() -> void:
	var chain := menu_buttons()
	for i in chain.size():
		var b := chain[i]
		var prev := chain[(i - 1 + chain.size()) % chain.size()]
		var next := chain[(i + 1) % chain.size()]
		b.focus_neighbor_top = b.get_path_to(prev)
		b.focus_neighbor_bottom = b.get_path_to(next)
		b.focus_previous = b.get_path_to(prev)
		b.focus_next = b.get_path_to(next)

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

## START RUN: the Level One stand-in -- Karen's Shop, which starts a full (banking) run.
func _on_start_pressed() -> void:
	change_scene.call(SHOP_SCENE)

## START DEMO: the loadout panel stands in for the button column until it closes.
func _on_start_demo_pressed() -> void:
	button_container.hide()
	demo_loadout.open()

func _on_demo_loadout_closed() -> void:
	button_container.show()
	start_demo_button.grab_focus()

## L8: the options panel stands in for the button column until it closes.
func _on_options_pressed() -> void:
	button_container.hide()
	options_menu.open()

func _on_options_closed() -> void:
	button_container.show()
	options_button.grab_focus()

func _on_quit_pressed() -> void:
	get_tree().quit()
