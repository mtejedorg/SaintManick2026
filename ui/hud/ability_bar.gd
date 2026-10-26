extends Control

## GDD §6.1: "Ability Bar. Occupies the old stamina slot." D11 (batch M): a 265x14 strip in a
## HudPanel frame, cut into SEGMENTS cells by HudSegmentGap separators, with HudTick marks every
## 2 cells and a dim 0..100 HudScale under it (ability_bar.tscn). The fill is a TextureProgressBar
## over flat generated textures (no raster art): the empty track is tinted FILL_EMPTY, the fill
## is white tinted FILL_CYAN at rest. When the meter is full the fill flickers cyan/white on
## every beat, and holds white while Bass Drop is armed.

const SEGMENTS := 10
const FILL_CYAN := Color(0.0, 0.961, 1.0, 1.0)
const FILL_WHITE := Color(1.0, 1.0, 1.0, 1.0)
## Unlit cells: the same faint cyan as the theme's HudSegmentEmpty.
const FILL_EMPTY := Color(0.0, 0.961, 1.0, 0.13)
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
	_reset_fill_tint()

func _setup_textures() -> void:
	meter_bar.fill_mode = TextureProgressBar.FILL_LEFT_TO_RIGHT
	meter_bar.nine_patch_stretch = true
	meter_bar.texture_under = _flat_texture()
	meter_bar.texture_progress = _flat_texture()
	meter_bar.tint_under = FILL_EMPTY

## A flat white texture, stretched to the bar and coloured by the tint_* properties.
func _flat_texture() -> GradientTexture2D:
	var gradient := Gradient.new()
	gradient.set_color(0, Color.WHITE)
	gradient.set_color(1, Color.WHITE)
	var tex := GradientTexture2D.new()
	tex.gradient = gradient
	tex.width = 8
	tex.height = 8
	return tex

## Whole cells covered by the current fill (the value tweens over 0.1 s).
func lit_segments() -> int:
	if meter_bar.max_value <= 0.0:
		return 0
	return clampi(floori(meter_bar.value / meter_bar.max_value * SEGMENTS + 0.0001), 0, SEGMENTS)

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

## The resting fill is cyan; white is reserved for the full-meter flicker and the armed hold.
func _reset_fill_tint() -> void:
	_kill_pulse()
	meter_bar.tint_progress = FILL_CYAN

func _kill_pulse() -> void:
	if _pulse_tween:
		_pulse_tween.kill()
		_pulse_tween = null
