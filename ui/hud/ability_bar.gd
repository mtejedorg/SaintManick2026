extends Control

## GDD §6.1: "Ability Bar. Occupies the old stamina slot." — GAP-8 fix (M12): this now
## uses the estamina-* textures (2D_Assets/UI_and_Menus/) that used to render on the
## shield bar, and is embedded in the HUD's StatusContainer instead of floating as a
## generic top-left ProgressBar.

@onready var meter_bar: TextureProgressBar = $ProgressBar

func _ready() -> void:
	_setup_textures()
	if SignalBus:
		SignalBus.ability_meter_changed.connect(_on_ability_meter_changed)
	meter_bar.value = 0.0

func _setup_textures() -> void:
	var under_path = _get_estamina_empty_path()
	var progress_path = _get_estamina_full_path()

	if under_path != "" and FileAccess.file_exists(under_path):
		meter_bar.texture_under = load(under_path)
	if progress_path != "" and FileAccess.file_exists(progress_path):
		meter_bar.texture_progress = load(progress_path)

func _on_ability_meter_changed(current: float, max_meter: float) -> void:
	meter_bar.max_value = max_meter

	# Optional juice: tween the value
	var tween = create_tween()
	tween.tween_property(meter_bar, "value", current, 0.1).set_trans(Tween.TRANS_SINE)

# Path helpers for accented filenames (mirrors hud.gd's _get_estamina_* helpers).
func _get_estamina_empty_path() -> String:
	var p1 = "res://2D_Assets/UI_and_Menus/estamina-vacía.png"
	if FileAccess.file_exists(p1):
		return p1
	var p2 = "res://2D_Assets/UI_and_Menus/estamina-vacÃa.png"
	if FileAccess.file_exists(p2):
		return p2
	return ""

func _get_estamina_full_path() -> String:
	var p = "res://2D_Assets/UI_and_Menus/estamian-llena.png"
	if FileAccess.file_exists(p):
		return p
	return ""
