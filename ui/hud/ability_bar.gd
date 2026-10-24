extends Control

## GDD §6.1: "Ability Bar. Occupies the old stamina slot." A horizontal TextureProgressBar
## (fills left-to-right, 265x64 under the battery) using the cropped HUD art in res://ui/hud/art/. Textures are loaded
## via ResourceLoader (never FileAccess on a res:// png — that fails in exported builds).

const UNDER_PATH := "res://ui/hud/art/ability_empty.png"
const PROGRESS_PATH := "res://ui/hud/art/ability_full.png"

@onready var meter_bar: TextureProgressBar = $ProgressBar

func _ready() -> void:
	_setup_textures()
	if SignalBus:
		SignalBus.ability_meter_changed.connect(_on_ability_meter_changed)
	meter_bar.value = 0.0

func _setup_textures() -> void:
	meter_bar.fill_mode = TextureProgressBar.FILL_LEFT_TO_RIGHT
	if ResourceLoader.exists(UNDER_PATH):
		meter_bar.texture_under = load(UNDER_PATH)
	if ResourceLoader.exists(PROGRESS_PATH):
		meter_bar.texture_progress = load(PROGRESS_PATH)

func _on_ability_meter_changed(current: float, max_meter: float) -> void:
	meter_bar.max_value = max_meter

	# Optional juice: tween the value
	var tween = create_tween()
	tween.tween_property(meter_bar, "value", current, 0.1).set_trans(Tween.TRANS_SINE)
