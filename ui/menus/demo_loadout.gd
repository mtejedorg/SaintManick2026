extends Control
## Batch O: the START DEMO loadout -- the only pre-run choice a demo run gets (no shop). One
## RUN BOOSTER row cycles through the run boosters (accept / left / right), a dim line
## describes the pick, START DEMO starts a demo run (GameManager.demo_mode: nothing banked)
## with it. The title screen instances this like the options menu: open(), wait for `closed`;
## BACK and ui_cancel close it.
## Q1/Q2: the choices come from GameManager.RUN_BOOSTERS minus the scrap multiplier (a demo
## banks nothing, so Scrap Magnet would do nothing); open() focuses START DEMO with the booster
## row one Up away; the pick is remembered for the session (last_pick) so a reopened panel --
## and RETRY / PLAY AGAIN, which reuse GameManager.demo_boosters -- keep it.

signal closed

const SceneTransition = preload("res://ui/transition/scene_transition.gd")
const RunBoosterRes = preload("res://_core/persistence/run_booster.gd")
const SLICE_SCENE := "res://levels/slice/vertical_slice.tscn"
const NONE := "None"
const ROW_FORMAT := "< RUN BOOSTER: %s >"
const NONE_DESCRIPTION := "No modifier"

## Session memory of the last booster started with ("None" or a display name).
static var last_pick: String = NONE

@onready var booster_button: Button = $Panel/VBox/BoosterButton
@onready var hint_label: Label = $Panel/VBox/HintLabel
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
	_select_last_pick()
	_refresh()

## "None" first, then every catalog booster that does something in a demo run.
static func options() -> Array[String]:
	var result: Array[String] = [NONE]
	for booster in GameManager.RUN_BOOSTERS:
		if booster.effect != RunBoosterRes.Effect.SCRAP_MULT:
			result.append(booster.display_name)
	return result

## The booster's own description line (its RunBooster resource).
static func describe(booster_name: String) -> String:
	var booster: RunBoosterRes = GameManager.find_run_booster(booster_name)
	return booster.description if booster else NONE_DESCRIPTION

func selected_booster() -> String:
	return options()[selected_index]

func open() -> void:
	_select_last_pick()
	show()
	_refresh()
	start_button.grab_focus()

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
	if booster != NONE:
		picks.append(booster)
	last_pick = booster
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
	SceneTransition.go(get_tree(), path)

func _select_last_pick() -> void:
	selected_index = maxi(options().find(last_pick), 0)

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
