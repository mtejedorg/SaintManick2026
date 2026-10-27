extends CanvasLayer

const FocusGrace = preload("res://ui/menus/focus_grace.gd")

## Batch O: a demo run returns to the title and banked nothing.
const DEMO_RETURN_TEXT := "RETURN TO TITLE"
const DEMO_SUB_TEXT := "Karen is recalling the drone.\nDemo run \u2014 nothing banked."

@onready var return_button: Button = $Root/CenterBox/ReturnButton
@onready var summary_label: Label = $Root/CenterBox/RunSummaryLabel
@onready var sub_label: Label = $Root/CenterBox/SubLabel

## Scene-change hook (path) -> void; a seam so tests can observe navigation.
var change_scene: Callable = _change_scene_to

func _ready() -> void:
	return_button.pressed.connect(_on_return_pressed)
	if GameManager.demo_mode:
		return_button.text = DEMO_RETURN_TEXT
		sub_label.text = DEMO_SUB_TEXT
	summary_label.text = _build_summary()
	summary_label.visible = summary_label.text != ""
	# Gamepad navigation: the only button takes focus once the input grace is over (U2).
	FocusGrace.arm(return_button, FocusGrace.END_SCREEN_GRACE)

func _on_return_pressed() -> void:
	change_scene.call(GameManager.post_run_scene())

func _change_scene_to(path: String) -> void:
	get_tree().change_scene_to_file(path)

## "SCRAP BANKED +N · ZONE REACHED <zone>", then (I6) a "DESTROYED BY <killer>" line.
## Each part is omitted when its data is missing.
func _build_summary() -> String:
	var parts: Array[String] = []
	var banked: int = 0 if GameManager.demo_mode else _banked_scrap()
	if banked > 0:
		parts.append("SCRAP BANKED +%d" % banked)
	var zone: String = GameManager.checkpoint_zone
	if zone != "":
		parts.append("ZONE REACHED %s" % zone)
	var lines: Array[String] = []
	if not parts.is_empty():
		lines.append(" · ".join(parts))
	var killer: String = GameManager.last_killer
	if killer != "":
		lines.append("DESTROYED BY %s" % killer)
	return "\n".join(lines)

## The run's scrap as it was banked. GameManager.respawn_or_game_over() banks it into the
## profile but leaves the volatile GameManager.scrap untouched on the game-over path (only
## abandon_run() zeroes it), so it still holds the banked amount here. A dedicated
## `last_run_scrap` var, if GameManager ever gains one, wins.
func _banked_scrap() -> int:
	if "last_run_scrap" in GameManager:
		return int(GameManager.get("last_run_scrap"))
	return GameManager.scrap
