extends Control

## GDD §6.1: "Ability Bar. Occupies the old stamina slot." A horizontal TextureProgressBar
## (fills left-to-right, 265x64 under the battery) using the cropped HUD art in res://ui/hud/art/. Textures are loaded
## via ResourceLoader (never FileAccess on a res:// png — that fails in exported builds).
## A dark "Track" panel sits behind the meter so the slot stays readable at 0 (the empty art
## is only a small bracket). When the meter is full the fill flickers cyan/white on every beat,
## and holds white while Bass Drop is armed.

const UNDER_PATH := "res://ui/hud/art/ability_empty.png"
const PROGRESS_PATH := "res://ui/hud/art/ability_full.png"

const FILL_CYAN := Color(0.0, 0.961, 1.0, 1.0)
const FILL_WHITE := Color(1.0, 1.0, 1.0, 1.0)
const FULL_PULSE_TIME := 0.15

@onready var meter_bar: TextureProgressBar = $ProgressBar

var _is_full: bool = false
var _bass_drop_armed: bool = false
var _beat_flip: bool = false
var _pulse_tween: Tween

func _ready() -> void:
	_setup_textures()
	if SignalBus:
		SignalBus.ability_meter_changed.connect(_on_ability_meter_changed)
		SignalBus.beat.connect(_on_beat)
		# bass_drop_armed is added to SignalBus by another batch — connect by name so this
		# script stays parse-safe whether or not the signal exists yet.
		if SignalBus.has_signal("bass_drop_armed"):
			SignalBus.connect("bass_drop_armed", _on_bass_drop_armed)
	meter_bar.value = 0.0

func _setup_textures() -> void:
	meter_bar.fill_mode = TextureProgressBar.FILL_LEFT_TO_RIGHT
	if ResourceLoader.exists(UNDER_PATH):
		meter_bar.texture_under = load(UNDER_PATH)
	if ResourceLoader.exists(PROGRESS_PATH):
		meter_bar.texture_progress = load(PROGRESS_PATH)

func _on_ability_meter_changed(current: float, max_meter: float) -> void:
	meter_bar.max_value = max_meter
	_is_full = max_meter > 0.0 and current >= max_meter
	if not _is_full and not _bass_drop_armed:
		_reset_fill_tint()

	# Optional juice: tween the value
	var tween = create_tween()
	tween.tween_property(meter_bar, "value", current, 0.1).set_trans(Tween.TRANS_SINE)

func _on_bass_drop_armed(armed: bool) -> void:
	_bass_drop_armed = armed
	if armed:
		_kill_pulse()
		meter_bar.tint_progress = FILL_WHITE
	elif not _is_full:
		_reset_fill_tint()

func _on_beat(layer: String, _beat_index: int) -> void:
	if layer != "primary" or not _is_full or _bass_drop_armed:
		return
	_kill_pulse()
	_beat_flip = not _beat_flip
	var target: Color = FILL_WHITE if _beat_flip else FILL_CYAN
	_pulse_tween = create_tween()
	_pulse_tween.tween_property(meter_bar, "tint_progress", target, FULL_PULSE_TIME).set_trans(Tween.TRANS_SINE)

func _reset_fill_tint() -> void:
	_kill_pulse()
	meter_bar.tint_progress = FILL_WHITE

func _kill_pulse() -> void:
	if _pulse_tween:
		_pulse_tween.kill()
		_pulse_tween = null
