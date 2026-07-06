extends Control

## Data-driven shop (M8): every purchasable thing is a ShopUpgrade resource. This script
## only knows how to render a generic upgrade row and apply an upgrade's Effect — it does
## not hardcode what "Max HP" or "Sweeper" cost or do.

const CUMULATIVE_UPGRADE_PATHS: Array[String] = [
	"res://_core/persistence/shop_upgrades/upgrade_max_hp.tres",
	"res://_core/persistence/shop_upgrades/upgrade_max_shield.tres",
	"res://_core/persistence/shop_upgrades/upgrade_extra_life.tres",
	"res://_core/persistence/shop_upgrades/upgrade_double_jump.tres",
	"res://_core/persistence/shop_upgrades/upgrade_booster_slot.tres",
]

## Combo Skill Tree — order matters (prerequisite chain: Tri-Cut -> Launcher -> Sweeper ->
## Battery Ram), GDD §5.2 "Nick must unlock basic chains before he can purchase advanced
## juggles or heavy sweeps."
const COMBO_UPGRADE_PATHS: Array[String] = [
	"res://_core/persistence/shop_upgrades/combo_unlock_tri_cut.tres",
	"res://_core/persistence/shop_upgrades/combo_unlock_launcher.tres",
	"res://_core/persistence/shop_upgrades/combo_unlock_sweeper.tres",
	"res://_core/persistence/shop_upgrades/combo_unlock_battery_ram.tres",
]

const BOOSTERS = ["None", "Tempo Shield", "Adrenaline", "Scrap Magnet"]

const CURRENCY_LABELS = ["Scrap", "Cells", "Cores"]

@onready var scrap_label: Label = $Background/Margin/VBox/CurrencyLabel
@onready var cumulative_list: VBoxContainer = $Background/Margin/VBox/HBox/CumulativeColumn/CumulativeList
@onready var combo_list: VBoxContainer = $Background/Margin/VBox/HBox/ComboColumn/ComboList
@onready var booster_button: Button = $Background/Margin/VBox/BoosterButton
@onready var start_button: Button = $Background/Margin/VBox/StartRunButton

func _ready() -> void:
	booster_button.pressed.connect(_on_cycle_booster)
	start_button.pressed.connect(_on_start_run)
	_rebuild_ui()

func _rebuild_ui() -> void:
	_update_currency_label()
	_populate_upgrade_list(cumulative_list, CUMULATIVE_UPGRADE_PATHS)
	_populate_upgrade_list(combo_list, COMBO_UPGRADE_PATHS)
	_update_booster_button()

func _update_currency_label() -> void:
	if not (SaveManager and SaveManager.profile):
		scrap_label.text = "Error Loading Profile"
		return
	var p = SaveManager.profile
	scrap_label.text = "SCRAP %d   CELLS %d   CORES %d" % [p.scrap, p.cells, p.cores]

func _populate_upgrade_list(container: VBoxContainer, paths: Array[String]) -> void:
	for child in container.get_children():
		child.queue_free()

	for path in paths:
		var upgrade: ShopUpgrade = load(path)
		if not upgrade:
			continue
		var button = Button.new()
		button.custom_minimum_size = Vector2(0, 44)
		_style_upgrade_button(button)
		_configure_button_for_upgrade(button, upgrade)
		button.pressed.connect(_on_buy_upgrade.bind(upgrade))
		container.add_child(button)

func _configure_button_for_upgrade(button: Button, upgrade: ShopUpgrade) -> void:
	var p = SaveManager.profile if SaveManager else null
	var is_owned = _is_upgrade_owned(upgrade, p)
	var prereq_met = upgrade.prerequisite_id == "" or (p and _is_prereq_met(upgrade.prerequisite_id, p))
	var currency_label = CURRENCY_LABELS[upgrade.currency]
	var cost_text = "FREE" if upgrade.cost <= 0 else "%d %s" % [upgrade.cost, currency_label]

	if is_owned:
		button.text = "%s (Owned)" % upgrade.name
		button.disabled = true
	elif not prereq_met:
		button.text = "%s [Locked]" % upgrade.name
		button.disabled = true
	else:
		button.text = "%s — %s" % [upgrade.name, cost_text]
		button.disabled = false

func _is_upgrade_owned(upgrade: ShopUpgrade, p: PlayerProfile) -> bool:
	if not p:
		return false
	if upgrade.is_repeatable:
		return false
	match upgrade.effect:
		ShopUpgrade.Effect.DOUBLE_JUMP:
			return p.double_jump_unlocked
		ShopUpgrade.Effect.UNLOCK_COMBO:
			return p.unlocked_combos.has(upgrade.combo_id)
		ShopUpgrade.Effect.BOOSTER_SLOT:
			return p.booster_slots > 1
		_:
			return false

## Looks up a combo-tree prerequisite by ShopUpgrade.id across the combo upgrade list.
func _is_prereq_met(prereq_id: String, p: PlayerProfile) -> bool:
	for path in COMBO_UPGRADE_PATHS:
		var upgrade: ShopUpgrade = load(path)
		if upgrade and upgrade.id == prereq_id:
			return _is_upgrade_owned(upgrade, p) or (upgrade.effect == ShopUpgrade.Effect.UNLOCK_COMBO and p.unlocked_combos.has(upgrade.combo_id))
	return false

func _on_buy_upgrade(upgrade: ShopUpgrade) -> void:
	if not (SaveManager and SaveManager.profile):
		return
	var p = SaveManager.profile

	if _is_upgrade_owned(upgrade, p):
		return
	if upgrade.prerequisite_id != "" and not _is_prereq_met(upgrade.prerequisite_id, p):
		return
	if not _spend_currency(p, upgrade.currency, upgrade.cost):
		return

	_apply_effect(upgrade, p)
	SaveManager.save_profile()
	_rebuild_ui()

func _spend_currency(p: PlayerProfile, currency: ShopUpgrade.Currency, cost: int) -> bool:
	if cost <= 0:
		return true
	match currency:
		ShopUpgrade.Currency.SCRAP:
			if p.scrap < cost:
				return false
			p.scrap -= cost
		ShopUpgrade.Currency.CELLS:
			if p.cells < cost:
				return false
			p.cells -= cost
		ShopUpgrade.Currency.CORES:
			if p.cores < cost:
				return false
			p.cores -= cost
	return true

func _apply_effect(upgrade: ShopUpgrade, p: PlayerProfile) -> void:
	match upgrade.effect:
		ShopUpgrade.Effect.MAX_HP:
			p.max_hp_upgrades += 1
		ShopUpgrade.Effect.MAX_SHIELD:
			p.shield_upgrades += 1
		ShopUpgrade.Effect.MAX_LIVES:
			p.max_lives_upgrades += 1
		ShopUpgrade.Effect.DOUBLE_JUMP:
			p.double_jump_unlocked = true
		ShopUpgrade.Effect.UNLOCK_COMBO:
			if not p.unlocked_combos.has(upgrade.combo_id):
				p.unlocked_combos.append(upgrade.combo_id)
		ShopUpgrade.Effect.BOOSTER_SLOT:
			p.booster_slots += 1

func _style_upgrade_button(button: Button) -> void:
	var normal = StyleBoxFlat.new()
	normal.bg_color = Color(0, 0.2, 0.24, 1)
	normal.corner_radius_top_left = 6
	normal.corner_radius_top_right = 6
	normal.corner_radius_bottom_right = 6
	normal.corner_radius_bottom_left = 6
	button.add_theme_stylebox_override("normal", normal)

	var hover = normal.duplicate()
	hover.bg_color = Color(0, 0.35, 0.4, 1)
	button.add_theme_stylebox_override("hover", hover)

	var disabled = normal.duplicate()
	disabled.bg_color = Color(0.08, 0.08, 0.1, 1)
	button.add_theme_stylebox_override("disabled", disabled)

	button.add_theme_color_override("font_color", Color(0, 0.949, 1, 1))
	button.add_theme_color_override("font_disabled_color", Color(0.4, 0.4, 0.45, 1))

func _update_booster_button() -> void:
	if not (SaveManager and SaveManager.profile):
		return
	var p = SaveManager.profile
	booster_button.text = "Equipped Booster: %s  (Slots: %d)" % [
		(p.equipped_run_booster if p.equipped_run_booster != "" else "None"),
		p.booster_slots
	]

func _on_cycle_booster() -> void:
	if SaveManager and SaveManager.profile:
		var p = SaveManager.profile
		var current = p.equipped_run_booster
		var idx = BOOSTERS.find(current)
		if idx == -1:
			idx = 0
		var next_idx = (idx + 1) % BOOSTERS.size()
		p.equipped_run_booster = BOOSTERS[next_idx]
		SaveManager.save_profile()
		_update_booster_button()

func _on_start_run() -> void:
	if GameManager:
		GameManager.start_new_run()
	get_tree().change_scene_to_file("res://levels/slice/vertical_slice.tscn")
