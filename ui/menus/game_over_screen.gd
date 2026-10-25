extends CanvasLayer

const FocusGrace = preload("res://ui/menus/focus_grace.gd")

@onready var return_button: Button = $Root/CenterBox/ReturnButton
@onready var summary_label: Label = $Root/CenterBox/RunSummaryLabel

func _ready() -> void:
	return_button.pressed.connect(_on_return_pressed)
	summary_label.text = _build_summary()
	summary_label.visible = summary_label.text != ""
	# Gamepad navigation: the only button takes focus once the input grace is over (U2).
	FocusGrace.arm(return_button, FocusGrace.END_SCREEN_GRACE)

func _on_return_pressed() -> void:
	get_tree().change_scene_to_file("res://ui/shop/karens_shop.tscn")

## "SCRAP BANKED +N · ZONE REACHED <zone>". Either half is omitted when its data is missing.
func _build_summary() -> String:
	var parts: Array[String] = []
	var banked: int = _banked_scrap()
	if banked > 0:
		parts.append("SCRAP BANKED +%d" % banked)
	var zone: String = GameManager.checkpoint_zone
	if zone != "":
		parts.append("ZONE REACHED %s" % zone)
	return " · ".join(parts)

## The run's scrap as it was banked. GameManager.respawn_or_game_over() banks it into the
## profile but leaves the volatile GameManager.scrap untouched on the game-over path (only
## abandon_run() zeroes it), so it still holds the banked amount here. A dedicated
## `last_run_scrap` var, if GameManager ever gains one, wins.
func _banked_scrap() -> int:
	if "last_run_scrap" in GameManager:
		return int(GameManager.get("last_run_scrap"))
	return GameManager.scrap
