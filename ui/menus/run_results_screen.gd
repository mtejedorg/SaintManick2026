extends CanvasLayer

const FocusGrace = preload("res://ui/menus/focus_grace.gd")

## Batch O: a demo run returns to the title and banks nothing.
const DEMO_RETURN_TEXT := "RETURN TO TITLE"

@onready var continue_button: Button = $CenterBox/ContinueButton
@onready var demo_label: Label = $CenterBox/DemoLabel

## Scene-change hook (path) -> void; a seam so tests can observe navigation.
var change_scene: Callable = _change_scene_to

func _ready() -> void:
	continue_button.pressed.connect(_on_continue)
	_populate_stats()
	var demo: bool = GameManager.demo_mode
	demo_label.visible = demo
	if demo:
		continue_button.text = DEMO_RETURN_TEXT
	# Gamepad navigation: the only button takes focus once the input grace is over (U2).
	FocusGrace.arm($CenterBox/ContinueButton, FocusGrace.END_SCREEN_GRACE)

func _populate_stats() -> void:
	var gm = get_node_or_null("/root/GameManager")
	if not gm:
		return
	$CenterBox/StatsContainer/ScrapLabel.text = "SCRAP COLLECTED    %d" % gm.scrap
	$CenterBox/StatsContainer/CellsLabel.text = "CELLS COLLECTED    %d" % gm.cells
	$CenterBox/StatsContainer/CoresLabel.text = "CORES COLLECTED    %d" % gm.cores
	$CenterBox/StatsContainer/EnemiesLabel.text = "ENEMIES DEFEATED   %d" % gm.enemies_defeated
	$CenterBox/StatsContainer/ZonesLabel.text = "ZONES CLEARED      %d / 10" % gm.zones_cleared

func _on_continue() -> void:
	change_scene.call(GameManager.post_run_scene())

func _change_scene_to(path: String) -> void:
	get_tree().change_scene_to_file(path)
