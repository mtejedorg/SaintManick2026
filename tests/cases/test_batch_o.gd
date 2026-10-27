extends "res://tests/framework/test_case.gd"

# Batch O (owner direction 27 Oct): the demo flow. O1 GameManager demo mode (nothing banked,
# demo loadout boosters, post_run_scene), O2 title START DEMO / START RUN, O3 demo loadout,
# O4 post-run screens in demo mode.

const TITLE_SCENE := "res://ui/menus/title_screen.tscn"
const SHOP_SCENE := "res://ui/shop/karens_shop.tscn"
const SLICE_SCENE := "res://levels/slice/vertical_slice.tscn"
const LOADOUT_SCENE := "res://ui/menus/demo_loadout.tscn"
const RESULTS_SCENE := "res://ui/menus/run_results_screen.tscn"
const GAME_OVER_SCENE := "res://ui/menus/game_over_screen.tscn"
const PAUSE_SCENE := "res://ui/menus/pause_menu.tscn"
const DemoLoadout = preload("res://ui/menus/demo_loadout.gd")
const KarensShop = preload("res://ui/shop/karens_shop.gd")

var _backup: Dictionary = {}
var _nodes: Array[Node] = []
var _requested: Array[String] = []

func before_each() -> void:
	GameManager.is_test = true
	var p: PlayerProfile = SaveManager.profile
	_backup = {
		"scrap": p.scrap, "cells": p.cells, "cores": p.cores,
		"max_hp_upgrades": p.max_hp_upgrades,
		"equipped_run_boosters": p.equipped_run_boosters.duplicate(),
		"booster_slots": p.booster_slots,
	}
	p.equipped_run_boosters.clear()
	_requested.clear()

func after_each() -> void:
	super.after_each()
	get_tree().paused = false
	for n in _nodes:
		if is_instance_valid(n):
			n.free()
	_nodes.clear()
	var p: PlayerProfile = SaveManager.profile
	for key in _backup.keys():
		p.set(key, _backup[key])
	SaveManager.save_profile()
	GameManager.demo_boosters.clear()
	GameManager.start_new_run() # back to a normal run; no demo/booster state leaks

func _add(scene_path: String) -> Node:
	var n: Node = (load(scene_path) as PackedScene).instantiate()
	add_child(n)
	_nodes.append(n)
	return n

func _record(path: String) -> void:
	_requested.append(path)

func _cancel_event() -> InputEventAction:
	var ev := InputEventAction.new()
	ev.action = &"ui_cancel"
	ev.pressed = true
	return ev

# --- O1 ------------------------------------------------------------------------------

func test_o1_demo_run_banks_nothing_and_returns_to_title() -> void:
	var p: PlayerProfile = SaveManager.profile
	p.scrap = 100
	p.cells = 3
	GameManager.start_new_run(true)
	assert_true(GameManager.demo_mode, "start_new_run(true) is a demo run")
	GameManager.add_scrap(500)
	GameManager.add_cells(2)
	GameManager.complete_run()
	assert_eq(p.scrap, 100, "A demo run leaves the banked scrap unchanged")
	assert_eq(p.cells, 3, "...and the banked cells")
	assert_eq(GameManager.scrap, 500, "The run's scrap still counts up for the results screen")
	assert_eq(GameManager.post_run_scene(), TITLE_SCENE, "A demo run returns to the title")

func test_o1_demo_game_over_and_abandon_bank_nothing() -> void:
	var p: PlayerProfile = SaveManager.profile
	p.scrap = 40
	GameManager.start_new_run(true)
	GameManager.add_scrap(25)
	GameManager.current_lives = 0
	GameManager.respawn_or_game_over()
	assert_true(GameManager.run_ended, "Game over ended the demo run")
	assert_eq(p.scrap, 40, "A demo game over banks nothing")
	GameManager.start_new_run(true)
	GameManager.add_scrap(25)
	GameManager.abandon_run()
	assert_eq(p.scrap, 40, "A demo abandon banks nothing")

func test_o1_normal_run_banks_and_returns_to_the_shop() -> void:
	var p: PlayerProfile = SaveManager.profile
	p.scrap = 100
	GameManager.start_new_run()
	assert_false(GameManager.demo_mode, "The no-arg call is a normal run")
	GameManager.add_scrap(500)
	GameManager.complete_run()
	assert_eq(p.scrap, 600, "A normal run banks its scrap")
	assert_eq(GameManager.post_run_scene(), SHOP_SCENE, "A normal run returns to Karen's Shop")

func test_o1_demo_boosters_replace_the_profile_but_upgrades_apply() -> void:
	var p: PlayerProfile = SaveManager.profile
	p.max_hp_upgrades = 2
	p.booster_slots = 1
	var equipped: Array[String] = ["Tempo Shield"]
	p.equipped_run_boosters = equipped
	var demo: Array[String] = ["Scrap Magnet"]
	GameManager.demo_boosters = demo
	GameManager.start_new_run(true)
	assert_eq(GameManager.scrap_multiplier, GameManager.SCRAP_MAGNET_MULTIPLIER, "The demo loadout's booster applies")
	assert_eq(GameManager.max_shield, 40.0 + 10.0 * p.shield_upgrades, "The profile's equipped Tempo Shield does not")
	assert_eq(GameManager.max_hp, 160.0, "Profile upgrades (max HP) still apply in a demo run")
	GameManager.start_new_run()
	assert_eq(GameManager.scrap_multiplier, 1, "A normal run ignores demo_boosters")
	assert_eq(GameManager.max_shield, round((40.0 + 10.0 * p.shield_upgrades) * GameManager.TEMPO_SHIELD_MULTIPLIER), "...and uses the profile's booster")

# --- O2 ------------------------------------------------------------------------------

func test_o2_title_has_four_buttons_in_order_and_start_demo_focused() -> void:
	var title: CanvasLayer = _add(TITLE_SCENE)
	await get_tree().process_frame
	var container: Control = title.get_node("Root/ButtonContainer")
	var texts: Array[String] = []
	for b in container.find_children("*", "Button", true, false):
		texts.append((b as Button).text)
	assert_eq(texts, ["START DEMO", "START RUN", "OPTIONS", "QUIT"] as Array[String], "Four buttons, in order")
	assert_true(title.start_demo_button.has_focus(), "START DEMO has focus at boot")
	var buttons: Array[Button] = title.menu_buttons()
	for i in buttons.size():
		var next: Button = buttons[(i + 1) % buttons.size()]
		assert_eq(buttons[i].get_node(buttons[i].focus_neighbor_bottom), next, "Focus chain runs top -> bottom (%d)" % i)
	var sub: Label = title.get_node("Root/ButtonContainer/StartRunGroup/StartRunSubLabel")
	assert_eq(String(sub.theme_type_variation), "DimLabel", "The START RUN sub-label is a DimLabel")
	assert_true(sub.text.begins_with("LEVEL ONE"), "...naming Level One")
	assert_true(sub.text.contains("Shop"), "...and the shop stand-in")
	assert_eq(sub.autowrap_mode, TextServer.AUTOWRAP_OFF, "...on one line")

func test_o2_start_run_still_opens_the_shop() -> void:
	var title: CanvasLayer = _add(TITLE_SCENE)
	title.change_scene = _record
	title.start_button.pressed.emit()
	assert_eq(_requested, [SHOP_SCENE] as Array[String], "START RUN is the Level One stand-in: the shop")

func test_o2_autostart_starts_a_demo_run_without_boosters() -> void:
	var title: CanvasLayer = _add(TITLE_SCENE)
	title.change_scene = _record
	var stale: Array[String] = ["Scrap Magnet"]
	GameManager.demo_boosters = stale
	var equipped: Array[String] = ["Scrap Magnet"]
	SaveManager.profile.equipped_run_boosters = equipped
	title._autostart_run()
	assert_true(GameManager.demo_mode, "--start-run starts a demo run")
	assert_eq(GameManager.scrap_multiplier, 1, "...with no booster from either source")
	assert_eq(_requested, [SLICE_SCENE] as Array[String], "...straight into the slice")

# --- O3 ------------------------------------------------------------------------------

func test_o3_loadout_cycles_the_shop_boosters_and_wraps() -> void:
	var loadout: Control = _add(LOADOUT_SCENE)
	assert_eq(DemoLoadout.options(), KarensShop.BOOSTERS, "The loadout reads the shop booster list")
	var count: int = DemoLoadout.options().size()
	assert_eq(loadout.selected_booster(), "None", "Starts on None")
	var seen: Array = []
	for i in count:
		seen.append(loadout.selected_booster())
		assert_true(loadout.booster_button.text.ends_with(loadout.selected_booster().to_upper()), "Row shows the pick")
		assert_eq(loadout.description_label.text, DemoLoadout.describe(loadout.selected_booster()), "Description follows the pick")
		loadout.booster_button.pressed.emit()
	assert_eq(seen, KarensShop.BOOSTERS, "Accept cycles through every booster in order")
	assert_eq(loadout.selected_booster(), "None", "...and wraps back to None")
	loadout.cycle(-1)
	assert_eq(loadout.selected_booster(), KarensShop.BOOSTERS.back(), "Left wraps backwards")
	assert_eq(DemoLoadout.describe("Tempo Shield"), "+50 % shield")
	assert_eq(DemoLoadout.describe("Scrap Magnet"), "x2 Scrap pickups")
	assert_eq(DemoLoadout.describe("None"), "No modifier")

func test_o3_start_with_scrap_magnet_starts_a_demo_run() -> void:
	var loadout: Control = _add(LOADOUT_SCENE)
	loadout.change_scene = _record
	loadout.selected_index = KarensShop.BOOSTERS.find("Scrap Magnet")
	loadout.start_button.pressed.emit()
	assert_true(GameManager.demo_mode, "START DEMO starts a demo run")
	assert_eq(GameManager.demo_boosters, ["Scrap Magnet"] as Array[String], "...with the picked booster")
	assert_eq(GameManager.scrap_multiplier, GameManager.SCRAP_MAGNET_MULTIPLIER, "...whose scrap multiplier is the magnet")
	assert_eq(_requested, [SLICE_SCENE] as Array[String], "...and goes into the slice")

func test_o3_loadout_opens_from_start_demo_and_closes_on_ui_cancel() -> void:
	var title: CanvasLayer = _add(TITLE_SCENE)
	await get_tree().process_frame
	var loadout: Control = title.get_node("Root/DemoLoadout")
	assert_false(loadout.visible, "The loadout starts hidden")
	title.start_demo_button.pressed.emit()
	assert_true(loadout.visible, "START DEMO opens the loadout")
	assert_false(title.button_container.visible, "...in place of the title buttons")
	assert_true(loadout.booster_button.has_focus(), "...focused on the booster row")
	loadout._input(_cancel_event())
	assert_false(loadout.visible, "ui_cancel closes it")
	assert_true(title.button_container.visible, "...and brings the buttons back")
	assert_true(title.start_demo_button.has_focus(), "...with START DEMO focused")

# --- O4 ------------------------------------------------------------------------------

func test_o4_results_screen_in_demo_mode() -> void:
	GameManager.start_new_run(true)
	var screen: CanvasLayer = _add(RESULTS_SCENE)
	assert_eq(screen.continue_button.text, "RETURN TO TITLE", "Demo results: RETURN TO TITLE")
	assert_true(screen.demo_label.visible, "...and the NOTHING BANKED line")
	assert_true(screen.demo_label.text.contains("NOTHING BANKED"))
	screen.change_scene = _record
	screen._on_continue()
	assert_eq(_requested, [TITLE_SCENE] as Array[String], "...going to the title")

func test_o4_results_screen_in_a_normal_run() -> void:
	GameManager.start_new_run()
	var screen: CanvasLayer = _add(RESULTS_SCENE)
	assert_eq(screen.continue_button.text, "CONTINUE TO SHOP", "Normal results keep their text")
	assert_false(screen.demo_label.visible, "...and no demo line")
	screen.change_scene = _record
	screen._on_continue()
	assert_eq(_requested, [SHOP_SCENE] as Array[String], "...going to the shop")

func test_o4_game_over_in_demo_and_normal_runs() -> void:
	GameManager.start_new_run(true)
	GameManager.add_scrap(30)
	var demo_screen: CanvasLayer = _add(GAME_OVER_SCENE)
	assert_eq(demo_screen.return_button.text, "RETURN TO TITLE", "Demo game over: RETURN TO TITLE")
	assert_false(demo_screen.summary_label.text.contains("SCRAP BANKED"), "...never claims scrap was banked")
	assert_false(demo_screen.sub_label.text.contains("Scrap banked"), "...in either line")
	demo_screen.change_scene = _record
	demo_screen._on_return_pressed()
	GameManager.start_new_run()
	var screen: CanvasLayer = _add(GAME_OVER_SCENE)
	assert_eq(screen.return_button.text, "RETURN TO SHOP", "Normal game over keeps its text")
	screen.change_scene = _record
	screen._on_return_pressed()
	assert_eq(_requested, [TITLE_SCENE, SHOP_SCENE] as Array[String], "Demo -> title, normal -> shop")

func test_o4_pause_abandon_goes_to_the_title_in_demo_mode() -> void:
	var p: PlayerProfile = SaveManager.profile
	p.scrap = 10
	GameManager.start_new_run(true)
	GameManager.add_scrap(50)
	var menu: CanvasLayer = _add(PAUSE_SCENE)
	menu.change_scene = _record
	assert_eq(menu.quit_button.text, "ABANDON RUN", "The label is unchanged")
	menu._on_quit_pressed()
	assert_eq(p.scrap, 10, "Abandoning a demo run banks nothing")
	assert_false(get_tree().paused, "...unpauses")
	GameManager.start_new_run()
	menu._on_quit_pressed()
	assert_eq(_requested, [TITLE_SCENE, SHOP_SCENE] as Array[String], "Demo abandon -> title, normal -> shop")
