extends "res://tests/framework/test_case.gd"

var original_profile_state: Dictionary

func before_each() -> void:
	if SaveManager and SaveManager.profile:
		var p = SaveManager.profile
		original_profile_state = {
			"scrap": p.scrap,
			"cells": p.cells,
			"cores": p.cores,
			"unlocked_combos": p.unlocked_combos.duplicate(),
			"booster_slots": p.booster_slots,
			"equipped_run_boosters": p.equipped_run_boosters.duplicate(),
			"double_jump_unlocked": p.double_jump_unlocked,
			"max_hp_upgrades": p.max_hp_upgrades,
			"shield_upgrades": p.shield_upgrades,
			"max_lives_upgrades": p.max_lives_upgrades,
		}
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

func after_each() -> void:
	if SaveManager and SaveManager.profile and not original_profile_state.is_empty():
		var p = SaveManager.profile
		p.scrap = original_profile_state["scrap"]
		p.cells = original_profile_state["cells"]
		p.cores = original_profile_state["cores"]
		p.unlocked_combos = original_profile_state["unlocked_combos"]
		p.booster_slots = original_profile_state["booster_slots"]
		p.equipped_run_boosters.assign(original_profile_state["equipped_run_boosters"])
		p.double_jump_unlocked = original_profile_state["double_jump_unlocked"]
		p.max_hp_upgrades = original_profile_state["max_hp_upgrades"]
		p.shield_upgrades = original_profile_state["shield_upgrades"]
		p.max_lives_upgrades = original_profile_state["max_lives_upgrades"]
		SaveManager.save_profile()

func test_tri_cut_and_launcher_free_and_available_by_default() -> void:
	var tri_cut: ShopUpgrade = load("res://_core/persistence/shop_upgrades/combo_unlock_tri_cut.tres")
	var launcher: ShopUpgrade = load("res://_core/persistence/shop_upgrades/combo_unlock_launcher.tres")
	assert_eq(tri_cut.cost, 0, "Tri-Cut should be free")
	assert_eq(launcher.cost, 0, "Launcher should be free")
	assert_true(SaveManager.profile.unlocked_combos.has("AAA"), "Tri-Cut should be unlocked by default")
	assert_true(SaveManager.profile.unlocked_combos.has("AAB"), "Launcher should be unlocked by default")

func test_sweeper_and_battery_ram_cost_cells() -> void:
	var sweeper: ShopUpgrade = load("res://_core/persistence/shop_upgrades/combo_unlock_sweeper.tres")
	var battery_ram: ShopUpgrade = load("res://_core/persistence/shop_upgrades/combo_unlock_battery_ram.tres")
	assert_eq(sweeper.currency, ShopUpgrade.Currency.CELLS, "Sweeper should cost cells")
	assert_gt(sweeper.cost, 0, "Sweeper should have a nonzero cost")
	assert_eq(battery_ram.currency, ShopUpgrade.Currency.CELLS, "Battery Ram should cost cells")
	assert_gt(battery_ram.cost, 0, "Battery Ram should have a nonzero cost")

func test_unpurchased_sweeper_falls_back_to_generic_damage() -> void:
	var player = load("res://characters/player/player.tscn").instantiate()
	add_child(player)
	player.ability_meter = 100.0

	var fsm = player.state_machine
	var attack_state = fsm.get_node("StateAttack")

	# Sweeper (A-B-B) not unlocked -> should fall back to generic heavy damage (28.0),
	# not the tuned Sweeper route value (20.0).
	attack_state.enter() # A
	attack_state.buffered_attack = true
	attack_state.buffered_heavy = true
	attack_state.attack_timer = 0.0
	attack_state.physics_update(0.0) # AB
	attack_state.buffered_attack = true
	attack_state.buffered_heavy = true
	attack_state.attack_timer = 0.0
	attack_state.physics_update(0.0) # ABB

	assert_eq("".join(attack_state.current_sequence), "ABB")
	assert_eq(player.bionic_arm_hitbox.damage_info.amount, 28.0, "Locked Sweeper should fall back to generic heavy damage")
	assert_eq(player.bionic_arm_hitbox.scale, Vector3.ONE, "Locked Sweeper should not widen the hitbox")

	player.queue_free()

func test_purchased_sweeper_uses_route_data() -> void:
	SaveManager.profile.unlocked_combos.append("ABB")

	var player = load("res://characters/player/player.tscn").instantiate()
	add_child(player)
	player.ability_meter = 100.0

	var fsm = player.state_machine
	var attack_state = fsm.get_node("StateAttack")

	attack_state.enter()
	attack_state.buffered_attack = true
	attack_state.buffered_heavy = true
	attack_state.attack_timer = 0.0
	attack_state.physics_update(0.0)
	attack_state.buffered_attack = true
	attack_state.buffered_heavy = true
	attack_state.attack_timer = 0.0
	attack_state.physics_update(0.0)

	assert_eq("".join(attack_state.current_sequence), "ABB")
	assert_eq(player.bionic_arm_hitbox.damage_info.amount, 20.0, "Unlocked Sweeper should use its tuned route damage")
	assert_eq(player.bionic_arm_hitbox.scale, Vector3(1.5, 1.0, 1.5), "Unlocked Sweeper should widen the hitbox")

	player.queue_free()

func test_booster_slot_upgrade_costs_one_core_and_grants_slot() -> void:
	var upgrade: ShopUpgrade = load("res://_core/persistence/shop_upgrades/upgrade_booster_slot.tres")
	assert_eq(upgrade.currency, ShopUpgrade.Currency.CORES, "Booster slot upgrade should cost cores")
	assert_eq(upgrade.cost, 1, "Booster slot upgrade should be a one-core unique")
	assert_false(upgrade.is_repeatable, "Booster slot upgrade should not be repeatable")
	assert_eq(SaveManager.profile.booster_slots, 1, "Profile should start with 1 booster slot")

func test_shop_scene_loads_and_lists_upgrades() -> void:
	var shop_scene = load("res://ui/shop/karens_shop.tscn")
	assert_not_null(shop_scene, "Shop scene should load")
	var shop = shop_scene.instantiate()
	add_child(shop)

	assert_eq(shop.cumulative_list.get_child_count(), 5, "Cumulative column should list 5 upgrades")
	assert_eq(shop.combo_list.get_child_count(), 4, "Combo column should list 4 combo-tree entries")

	shop.queue_free()

func test_buying_combo_upgrade_spends_cells_and_unlocks_combo() -> void:
	SaveManager.profile.cells = 50
	SaveManager.profile.unlocked_combos = ["AAA", "AAB"] # Sweeper prereq (Launcher) met

	var shop_scene = load("res://ui/shop/karens_shop.tscn")
	var shop = shop_scene.instantiate()
	add_child(shop)

	var sweeper: ShopUpgrade = load("res://_core/persistence/shop_upgrades/combo_unlock_sweeper.tres")
	shop._on_buy_upgrade(sweeper)

	assert_eq(SaveManager.profile.cells, 50 - sweeper.cost, "Buying Sweeper should spend its cell cost")
	assert_true(SaveManager.profile.unlocked_combos.has("ABB"), "Buying Sweeper should unlock ABB")

	shop.queue_free()

func test_cannot_buy_locked_prerequisite_combo() -> void:
	SaveManager.profile.cells = 100
	SaveManager.profile.unlocked_combos = ["AAA"] # Launcher NOT unlocked -> Sweeper prereq unmet

	var shop_scene = load("res://ui/shop/karens_shop.tscn")
	var shop = shop_scene.instantiate()
	add_child(shop)

	var sweeper: ShopUpgrade = load("res://_core/persistence/shop_upgrades/combo_unlock_sweeper.tres")
	shop._on_buy_upgrade(sweeper)

	assert_eq(SaveManager.profile.cells, 100, "Should not spend cells when prerequisite is unmet")
	assert_false(SaveManager.profile.unlocked_combos.has("ABB"), "Should not unlock Sweeper without its prerequisite")

	shop.queue_free()

func _booster_shop() -> Node:
	var shop = load("res://ui/shop/karens_shop.tscn").instantiate()
	add_child(shop)
	return shop

func test_single_slot_shop_has_one_booster_button() -> void:
	var shop = _booster_shop()
	assert_eq(shop._booster_slot_buttons().size(), 1, "One slot -> only the scene BoosterButton")
	shop._cycle_booster_slot(0)
	assert_eq(SaveManager.profile.equipped_run_boosters.size(), 1, "Cycling slot 1 should equip a booster")
	assert_eq(SaveManager.profile.equipped_run_boosters[0], "Tempo Shield", "First cycle from None should be Tempo Shield")
	shop._cycle_booster_slot(1) # no second slot -> ignored
	assert_eq(SaveManager.profile.equipped_run_boosters.size(), 1, "A slot beyond booster_slots should be ignored")
	shop.queue_free()

func test_two_booster_slots_equip_two_distinct_boosters() -> void:
	SaveManager.profile.booster_slots = 2
	var shop = _booster_shop()

	var buttons: Array = shop._booster_slot_buttons()
	assert_eq(buttons.size(), 2, "Two slots -> BoosterButton + one code-created slot button")
	assert_eq(buttons[1].get_index(), shop.booster_button.get_index() + 1, "Extra slot button should sit right after BoosterButton")

	shop._cycle_booster_slot(0) # slot 1 -> Tempo Shield
	shop._cycle_booster_slot(1) # slot 2 -> skips Tempo Shield (taken) -> Adrenaline

	var equipped: Array[String] = SaveManager.profile.equipped_run_boosters
	assert_eq(equipped.size(), 2, "Both slots should be filled")
	assert_eq(equipped[0], "Tempo Shield", "Slot 1 should hold Tempo Shield")
	assert_eq(equipped[1], "Adrenaline", "Slot 2 should skip the duplicate and hold Adrenaline")
	shop.queue_free()

func test_booster_cycle_rejects_duplicates_and_none_stores_nothing() -> void:
	SaveManager.profile.booster_slots = 2
	SaveManager.profile.equipped_run_boosters = ["Adrenaline", "Scrap Magnet"]
	var shop = _booster_shop()

	# Slot 1: Adrenaline -> (Scrap Magnet taken in slot 2) -> None, which stores nothing.
	shop._cycle_booster_slot(0)
	var equipped: Array[String] = SaveManager.profile.equipped_run_boosters
	assert_eq(equipped.size(), 1, "Cycling to None should remove the entry")
	assert_eq(equipped[0], "Scrap Magnet", "Remaining booster should be kept")
	assert_false(equipped.has("None"), "None must never be stored")

	# A stored array with duplicates/overflow is trimmed to distinct boosters <= slots.
	SaveManager.profile.equipped_run_boosters = ["Tempo Shield", "Tempo Shield", "Adrenaline", "Scrap Magnet"]
	var active: Array[String] = SaveManager.profile.get_active_run_boosters()
	assert_eq(active.size(), 2, "Active boosters should be trimmed to booster_slots")
	assert_eq(active[0], "Tempo Shield")
	assert_eq(active[1], "Adrenaline", "Duplicate Tempo Shield should be skipped")
	shop.queue_free()
