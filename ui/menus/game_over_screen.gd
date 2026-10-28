extends CanvasLayer

const FocusGrace = preload("res://ui/menus/focus_grace.gd")
const SceneTransition = preload("res://ui/transition/scene_transition.gd")
const SLICE_SCENE := "res://levels/slice/vertical_slice.tscn"

## Batch O: a demo run returns to the title and banked nothing.
const DEMO_RETURN_TEXT := "RETURN TO TITLE"
const DEMO_SUB_TEXT := "Karen is recalling the drone.\nDemo run — nothing banked."

@onready var retry_button: Button = $Root/CenterBox/RetryButton
@onready var return_button: Button = $Root/CenterBox/ReturnButton
@onready var summary_label: Label = $Root/CenterBox/RunSummaryLabel
@onready var sub_label: Label = $Root/CenterBox/SubLabel

## Scene-change hook (path) -> void; a seam so tests can observe navigation.
var change_scene: Callable = _change_scene_to

func _ready() -> void:
	retry_button.pressed.connect(FocusGrace.guard(retry_button, _on_retry_pressed))
	return_button.pressed.connect(FocusGrace.guard(return_button, _on_return_pressed))
	var demo: bool = GameManager.demo_mode
	# Q3: a demo game over offers RETRY first (same loadout), then the title.
	retry_button.visible = demo
	if demo:
		return_button.text = DEMO_RETURN_TEXT
		sub_label.text = DEMO_SUB_TEXT
		retry_button.focus_neighbor_bottom = retry_button.get_path_to(return_button)
		retry_button.focus_neighbor_top = retry_button.get_path_to(return_button)
		return_button.focus_neighbor_top = return_button.get_path_to(retry_button)
		return_button.focus_neighbor_bottom = return_button.get_path_to(retry_button)
	summary_label.text = _build_summary()
	summary_label.visible = summary_label.text != ""
	# Gamepad navigation: the primary button takes focus once the input grace is over (U2).
	FocusGrace.arm(primary_button(), FocusGrace.END_SCREEN_GRACE)
	if demo:
		FocusGrace.arm(return_button, FocusGrace.END_SCREEN_GRACE, false)

## RETRY in a demo run, otherwise the only button.
func primary_button() -> Button:
	return retry_button if GameManager.demo_mode else return_button

## Q3: a fresh demo run with the same loadout (GameManager.demo_boosters), straight back in.
func _on_retry_pressed() -> void:
	GameManager.start_new_run(true)
	change_scene.call(SLICE_SCENE)

func _on_return_pressed() -> void:
	change_scene.call(GameManager.post_run_scene())

func _change_scene_to(path: String) -> void:
	SceneTransition.go(get_tree(), path)

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
