extends "res://tests/framework/test_case.gd"

# Batch H (UI) U3/U4: the shop has a way back (BACK TO TITLE + ui_cancel), repeatable rows
# show the current total, locked rows name their prerequisite, the focused row description
# is shown, and the booster button explains itself.

const SHOP_SCENE := preload("res://ui/shop/karens_shop.tscn")
const UPGRADES := "res://_core/persistence/shop_upgrades/"

var shop: Control

func before_each() -> void:
	# Q1: the runner hands every test a fresh profile on a temp path (no backup needed).
	var p: PlayerProfile = SaveManager.profile
	p.scrap = 0
	p.cells = 0
	p.cores = 0
	p.unlocked_combos.assign(["AAA", "AAB"])
	p.booster_slots = 1
	p.equipped_run_boosters.clear()
	p.double_jump_unlocked = false
	p.max_hp_upgrades = 0
	p.shield_upgrades = 0
	p.max_lives_upgrades = 0
	shop = null

func after_each() -> void:
	if is_instance_valid(shop):
		shop.queue_free()
	GameManager.start_new_run() # no upgrade maxima leak into later tests
	super.after_each()

func _open_shop() -> Control:
	shop = SHOP_SCENE.instantiate()
	add_child(shop)
	return shop

func test_shop_has_back_to_title_after_start_run() -> void:
	_open_shop()
	var back: Button = shop.get_node_or_null("Background/Margin/VBox/BackButton")
	assert_not_null(back, "BackButton exists")
	if back == null:
		return
	assert_eq(back.text, "BACK TO TITLE")
	assert_gt(back.get_index(), shop.start_button.get_index(), "BACK TO TITLE comes after START RUN")
	assert_true(back.custom_minimum_size.y >= 44.0, "44 px focus target")
	assert_gt(back.pressed.get_connections().size(), 0, "BACK TO TITLE is wired")
	assert_eq(shop.start_button.focus_neighbor_bottom, shop.start_button.get_path_to(back), "Focus chain START RUN -> BACK")

func test_back_button_and_ui_cancel_request_the_title_screen() -> void:
	_open_shop()
	var requested: Array[String] = []
	shop.change_scene = func(path: String) -> void: requested.append(path)
	shop.back_button.pressed.emit()
	assert_eq(requested.size(), 1, "BACK TO TITLE requests a scene change")
	assert_eq(requested.back(), "res://ui/menus/title_screen.tscn", "...to the title screen")
	var cancel := InputEventAction.new()
	cancel.action = &"ui_cancel"
	cancel.pressed = true
	shop._unhandled_input(cancel)
	assert_eq(requested.size(), 2, "ui_cancel is handled the same way")
	assert_eq(requested.back(), "res://ui/menus/title_screen.tscn")

func test_repeatable_rows_show_the_current_total() -> void:
	_open_shop()
	var p: PlayerProfile = SaveManager.profile
	p.max_hp_upgrades = 1
	p.shield_upgrades = 1
	p.max_lives_upgrades = 1
	var hp: ShopUpgrade = load(UPGRADES + "upgrade_max_hp.tres")
	var shield: ShopUpgrade = load(UPGRADES + "upgrade_max_shield.tres")
	var life: ShopUpgrade = load(UPGRADES + "upgrade_extra_life.tres")
	assert_eq(shop._row_text(hp, p), "Max HP +20 — 100 Scrap   [HP 140]")
	assert_true(shop._row_text(shield, p).ends_with("[SHIELD 50]"), shop._row_text(shield, p))
	assert_true(shop._row_text(life, p).ends_with("[LIVES 4]"), shop._row_text(life, p))
	var double_jump: ShopUpgrade = load(UPGRADES + "upgrade_double_jump.tres")
	assert_false(shop._row_text(double_jump, p).contains("["), "One-off unlocks carry no total")

func test_shop_totals_match_the_run_start() -> void:
	var p: PlayerProfile = SaveManager.profile
	p.max_hp_upgrades = 2
	p.shield_upgrades = 3
	p.max_lives_upgrades = 1
	GameManager.start_new_run()
	_open_shop()
	assert_eq(shop._total_tag(load(UPGRADES + "upgrade_max_hp.tres"), p), "[HP %d]" % int(GameManager.max_hp))
	assert_eq(shop._total_tag(load(UPGRADES + "upgrade_max_shield.tres"), p), "[SHIELD %d]" % int(GameManager.max_shield))
	assert_eq(shop._total_tag(load(UPGRADES + "upgrade_extra_life.tres"), p), "[LIVES %d]" % GameManager.max_lives)

func test_locked_row_names_its_prerequisite() -> void:
	_open_shop()
	var p: PlayerProfile = SaveManager.profile
	var battery_ram: ShopUpgrade = load(UPGRADES + "combo_unlock_battery_ram.tres")
	var text: String = shop._row_text(battery_ram, p)
	assert_true(text.contains("needs"), text)
	assert_eq(text, "[LOCKED — needs Sweeper] Unlock: Battery Ram (B-B)")

func test_focused_row_shows_its_description() -> void:
	_open_shop()
	await get_tree().process_frame # rows take focus deferred
	var first_row: Button = shop.cumulative_list.get_child(0)
	first_row.grab_focus()
	var hp: ShopUpgrade = load(UPGRADES + "upgrade_max_hp.tres")
	assert_eq(shop.description_label.text, hp.description, "The focused row description is shown")
	shop.start_button.grab_focus()
	assert_eq(shop.description_label.text, "", "Non-row buttons clear it")

func test_focused_row_name_prefixes_its_description() -> void:
	_open_shop()
	await get_tree().process_frame # rows take focus deferred
	var first_row: Button = shop.cumulative_list.get_child(0)
	first_row.grab_focus()
	var hp: ShopUpgrade = load(UPGRADES + "upgrade_max_hp.tres")
	var expected: String = hp.name.to_upper() + " " + String.chr(0x2014) + " "
	assert_eq(shop.description_name_label.text, expected, "I8: the focused item name prefixes the description")
	assert_eq(shop.description_name_label.get_theme_color("font_color"), Color(0, 0.961, 1, 1), "...in cyan")
	var row: Control = shop.description_label.get_parent()
	assert_eq(row.get_index(), shop.get_node("Background/Margin/VBox/HBox").get_index() + 1, "Right under the two columns")
	assert_lt(row.get_index(), shop.booster_button.get_index(), "...above the booster button")
	shop.start_button.grab_focus()
	assert_eq(shop.description_name_label.text, "", "Non-row buttons clear the name too")

func test_booster_button_explains_itself() -> void:
	_open_shop()
	assert_eq(shop.booster_button.text, "RUN BOOSTER 1/1: NONE  (press to change)")
