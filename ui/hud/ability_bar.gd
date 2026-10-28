extends VBoxContainer

## GDD §6.1: "Ability Bar. Occupies the old stamina slot." Q8: the meter is a HudPanel frame
## holding an HBoxContainer of SEGMENTS themed cells (the battery's pattern, so it scales with
## the cluster's width) and one 18 px "BASS DROP" caption that lights while Bass Drop is armed.
## Lit cells are cyan HudSegment; when the meter is full they flicker HudSegment / white
## HudSegmentHot on every primary beat, and hold HudSegmentHot while Bass Drop is armed.

const SEGMENTS := 10
const SEGMENT_LIT := &"HudSegment"
const SEGMENT_EMPTY := &"HudSegmentEmpty"
const SEGMENT_HOT := &"HudSegmentHot"
const CAPTION_DIM := Color(0.55, 0.78, 0.82, 0.55)
const CAPTION_LIT := Color(1.0, 1.0, 1.0, 1.0)

@onready var segments: HBoxContainer = $Frame/Segments
@onready var caption: Label = $Caption

var meter_value: float = 0.0
var meter_max: float = 100.0
var _is_full: bool = false
var _bass_drop_armed: bool = false
var _beat_flip: bool = false

func _ready() -> void:
	if SignalBus:
		SignalBus.ability_meter_changed.connect(_on_ability_meter_changed)
		SignalBus.beat.connect(_on_beat)
		SignalBus.bass_drop_armed.connect(_on_bass_drop_armed)
	_refresh()

## Whole cells covered by the current meter value.
func lit_segments() -> int:
	if meter_max <= 0.0:
		return 0
	return clampi(floori(meter_value / meter_max * SEGMENTS + 0.0001), 0, SEGMENTS)

## True while the BASS DROP caption is lit (Bass Drop armed).
func caption_lit() -> bool:
	return _bass_drop_armed

func _on_ability_meter_changed(current: float, max_meter: float) -> void:
	meter_max = max_meter
	meter_value = current
	_is_full = max_meter > 0.0 and current >= max_meter
	if not _is_full:
		_beat_flip = false
	_refresh()

func _on_bass_drop_armed(armed: bool) -> void:
	_bass_drop_armed = armed
	_beat_flip = false
	_refresh()

func _on_beat(layer: String, _beat_index: int) -> void:
	if layer != "primary" or not _is_full or _bass_drop_armed:
		return
	_beat_flip = not _beat_flip
	_refresh()

func _refresh() -> void:
	var lit := lit_segments()
	var hot := _bass_drop_armed or (_is_full and _beat_flip)
	var cells := segments.get_children()
	for i in cells.size():
		var cell := cells[i] as Control
		if i >= lit:
			cell.theme_type_variation = SEGMENT_EMPTY
		else:
			cell.theme_type_variation = SEGMENT_HOT if hot else SEGMENT_LIT
	caption.add_theme_color_override("font_color", CAPTION_LIT if _bass_drop_armed else CAPTION_DIM)
