extends Control
## Batch O: the START DEMO loadout -- the only pre-run choice a demo run gets (no shop). One
## RUN BOOSTER row cycles through the shop's booster list (accept / left / right), a dim line
## describes the pick, START DEMO starts a demo run (GameManager.demo_mode: nothing banked)
## with it. The title screen instances this like the options menu: open(), wait for `closed`;
## BACK and ui_cancel close it.

signal closed

const KarensShop = preload("res://ui/shop/karens_shop.gd")
const SLICE_SCENE := "res://levels/slice/vertical_slice.tscn"
const ROW_FORMAT := "RUN BOOSTER: %s"

@onready var booster_button: Button = $Panel/VBox/BoosterButton
@onready var description_label: Label = $Panel/VBox/DescriptionLabel
@onready var start_button: Button = $Panel/VBox/StartDemoButton
@onready var back_button: Button = $Panel/VBox/BackButton

## Index into options() of the selected booster.
var selected_index: int = 0

## Scene-change hook (path) -> void; a seam so tests can observe the jump into the slice.
var change_scene: Callable = _change_scene_to

func _ready() -> void:
	hide()
	booster_button.pressed.connect(cycle.bind(1))
	start_button.pressed.connect(start_demo)
	back_button.pressed.connect(close)
	_wire_focus()
	_refresh()

## The booster choices, straight from the shop's list ("None" first).
static func options() -> Array:
	return KarensShop.BOOSTERS

## One dim line per booster, built from GameManager's own multipliers.
static func describe(booster: String) -> String:
	match booster:
		"Tempo Shield":
			return "+%d %% shield" % roundi((GameManager.TEMPO_SHIELD_MULTIPLIER - 1.0) * 100.0)
		"Adrenaline":
			return "+%d %% move speed" % roundi((GameManager.ADRENALINE_SPEED_MULTIPLIER - 1.0) * 100.0)
		"Scrap Magnet":
			return "x%d Scrap pickups" % GameManager.SCRAP_MAGNET_MULTIPLIER
	return "No modifier"

func selected_booster() -> String:
	return options()[selected_index]

func open() -> void:
	show()
	_refresh()
	booster_button.grab_focus()

func close() -> void:
	if not visible:
		return
	hide()
	closed.emit()

## Steps the booster row by `step` (+1 / -1), wrapping.
func cycle(step: int) -> void:
	var count: int = options().size()
	selected_index = ((selected_index + step) % count + count) % count
	_refresh()

func start_demo() -> void:
	var picks: Array[String] = []
	var booster := selected_booster()
	if booster != "None":
		picks.append(booster)
	GameManager.demo_boosters = picks
	GameManager.start_new_run(true)
	change_scene.call(SLICE_SCENE)

func _input(event: InputEvent) -> void:
	if not visible:
		return
	if event.is_action_pressed("ui_cancel"):
		close()
		get_viewport().set_input_as_handled()
	elif booster_button.has_focus() and event.is_action_pressed("ui_left"):
		cycle(-1)
		get_viewport().set_input_as_handled()
	elif booster_button.has_focus() and event.is_action_pressed("ui_right"):
		cycle(1)
		get_viewport().set_input_as_handled()

func _change_scene_to(path: String) -> void:
	get_tree().change_scene_to_file(path)

func _refresh() -> void:
	var booster := selected_booster()
	booster_button.text = ROW_FORMAT % booster.to_upper()
	description_label.text = describe(booster)

## Up/down walk the column and wrap; left/right belong to the booster row's cycling.
func _wire_focus() -> void:
	var chain: Array[Control] = [booster_button, start_button, back_button]
	for i in chain.size():
		var c := chain[i]
		var prev := chain[(i - 1 + chain.size()) % chain.size()]
		var next := chain[(i + 1) % chain.size()]
		c.focus_neighbor_top = c.get_path_to(prev)
		c.focus_neighbor_bottom = c.get_path_to(next)
		c.focus_previous = c.get_path_to(prev)
		c.focus_next = c.get_path_to(next)
		c.focus_neighbor_left = c.get_path_to(c)
		c.focus_neighbor_right = c.get_path_to(c)
