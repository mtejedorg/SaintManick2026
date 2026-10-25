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

const TITLE_SCENE := "res://ui/menus/title_screen.tscn"

## U4: the run-start totals shown on the repeatable rows. Same formula as
## GameManager.start_new_run() (base + step x upgrades, boosters excluded);
## tests/cases/test_shop_feedback.gd pins these to GameManager so the two cannot drift.
const BASE_MAX_HP := 120.0
const MAX_HP_PER_UPGRADE := 20.0
const BASE_MAX_SHIELD := 40.0
const MAX_SHIELD_PER_UPGRADE := 10.0
const BASE_MAX_LIVES := 3

const CURRENCY_LABELS = ["Scrap", "Cells", "Cores"]

## Row state tags. Plain text on purpose: the default font has no checkmark/padlock glyphs,
## so those would risk tofu boxes wherever the system-font fallback lacks them.
const OWNED_PREFIX := "[OWNED] "
const LOCKED_PREFIX := "[LOCKED] "
## U4: a locked row names what it is waiting for, e.g. "[LOCKED — needs Sweeper] ".
const LOCKED_NEEDS_FORMAT := "[LOCKED — needs %s] "
## Cost colour for a row the player cannot afford yet (amber = "not yet" in the neon palette).
const UNAFFORDABLE_COLOR := Color(1.0, 0.72, 0.0, 1.0)
const SHAKE_DISTANCE := 6.0
const SHAKE_STEP_TIME := 0.05

@onready var scrap_label: Label = $Background/Margin/VBox/CurrencyLabel
@onready var cumulative_list: VBoxContainer = $Background/Margin/VBox/HBox/CumulativeColumn/CumulativeList
@onready var combo_list: VBoxContainer = $Background/Margin/VBox/HBox/ComboColumn/ComboList
@onready var booster_button: Button = $Background/Margin/VBox/BoosterButton
@onready var start_button: Button = $Background/Margin/VBox/StartRunButton
@onready var back_button: Button = $Background/Margin/VBox/BackButton
## U4: the focused row's ShopUpgrade.description (one dim line under the columns).
@onready var description_label: Label = $Background/Margin/VBox/DescriptionRow/DescriptionLabel
## I8: the focused row's name in cyan, prefixing the description ("MAX HP +20 — ...").
@onready var description_name_label: Label = $Background/Margin/VBox/DescriptionRow/DescriptionName

## Slot 1 is the scene's BoosterButton; slots 2..N are created in code, in order, right
## after it (see _sync_booster_slot_buttons).
var _extra_booster_buttons: Array[Button] = []

## Scene-change hook (path) -> void. A seam so tests can observe navigation without leaving
## the test scene; defaults to SceneTree.change_scene_to_file.
var change_scene: Callable

func _ready() -> void:
	change_scene = _change_scene_to
	booster_button.pressed.connect(_cycle_booster_slot.bind(0))
	start_button.pressed.connect(_on_start_run)
	back_button.pressed.connect(_on_back_to_title)
	# U3: BACK TO TITLE sits right after START RUN in the focus chain.
	start_button.focus_neighbor_bottom = start_button.get_path_to(back_button)
	start_button.focus_next = start_button.get_path_to(back_button)
	back_button.focus_neighbor_top = back_button.get_path_to(start_button)
	back_button.focus_previous = back_button.get_path_to(start_button)
	for button in [booster_button, start_button, back_button]:
		button.focus_entered.connect(_show_description.bind("", ""))
	_rebuild_ui()

## U3: ui_cancel (Esc / gamepad B) leaves the shop the same way BACK TO TITLE does.
func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed("ui_cancel"):
		get_viewport().set_input_as_handled()
		_on_back_to_title()

func _on_back_to_title() -> void:
	change_scene.call(TITLE_SCENE)

func _change_scene_to(path: String) -> void:
	get_tree().change_scene_to_file(path)

## I8: "<NAME> — " in cyan, then the dim description, right under the two lists.
func _show_description(item_name: String, text: String) -> void:
	description_name_label.text = "%s \u2014 " % item_name.to_upper() if item_name != "" else ""
	description_label.text = text

func _rebuild_ui() -> void:
	var remembered_focus: Vector2i = _focused_row_position()
	_update_currency_label()
	_populate_upgrade_list(cumulative_list, CUMULATIVE_UPGRADE_PATHS)
	_populate_upgrade_list(combo_list, COMBO_UPGRADE_PATHS)
	_sync_booster_slot_buttons()
	_update_booster_buttons()
	_wire_column_focus_neighbors()
	# Deferred: the freshly added rows must be in the tree and laid out before they can
	# take focus. Re-selects the row the player was on (after a purchase) when it exists.
	call_deferred("_focus_upgrade_row", remembered_focus)

func _update_currency_label() -> void:
	if not (SaveManager and SaveManager.profile):
		scrap_label.text = "Error Loading Profile"
		return
	var p = SaveManager.profile
	scrap_label.text = "SCRAP %d   CELLS %d   CORES %d" % [p.scrap, p.cells, p.cores]

func _populate_upgrade_list(container: VBoxContainer, paths: Array[String]) -> void:
	# Detach immediately (not just queue_free) so the stale rows can never be found by the
	# focus/neighbour passes that run in the same frame.
	for child in container.get_children():
		container.remove_child(child)
		child.queue_free()

	for path in paths:
		var upgrade: ShopUpgrade = load(path)
		if not upgrade:
			continue
		var button = Button.new()
		button.custom_minimum_size = Vector2(0, 44)
		# Look comes from the shared neon theme (type variation UpgradeRow), not inline styleboxes.
		button.theme_type_variation = &"UpgradeRow"
		button.alignment = HORIZONTAL_ALIGNMENT_LEFT
		_configure_button_for_upgrade(button, upgrade)
		button.pressed.connect(_on_upgrade_row_pressed.bind(button, upgrade))
		button.focus_entered.connect(_show_description.bind(upgrade.name, upgrade.description))
		button.mouse_entered.connect(_show_description.bind(upgrade.name, upgrade.description))
		container.add_child(button)

func _configure_button_for_upgrade(button: Button, upgrade: ShopUpgrade) -> void:
	var p = SaveManager.profile if SaveManager else null
	button.text = _row_text(upgrade, p)
	button.disabled = _is_upgrade_owned(upgrade, p) or not _is_row_prereq_met(upgrade, p)
	if not button.disabled and not _can_afford(upgrade):
		# Stays enabled (so it is focusable and explains itself) but the cost reads amber.
		for color_name in ["font_color", "font_hover_color", "font_focus_color", "font_pressed_color", "font_hover_pressed_color"]:
			button.add_theme_color_override(color_name, UNAFFORDABLE_COLOR)

func _is_row_prereq_met(upgrade: ShopUpgrade, p: PlayerProfile) -> bool:
	return upgrade.prerequisite_id == "" or (p != null and _is_prereq_met(upgrade.prerequisite_id, p))

## The row label: "[OWNED] name", "[LOCKED — needs X] name", or "name — cost" plus, on the
## repeatable stat rows, the current run-start total ("   [HP 140]").
func _row_text(upgrade: ShopUpgrade, p: PlayerProfile) -> String:
	if _is_upgrade_owned(upgrade, p):
		return "%s%s" % [OWNED_PREFIX, upgrade.name]
	if not _is_row_prereq_met(upgrade, p):
		var needs: String = _prereq_display_name(upgrade.prerequisite_id)
		var prefix: String = LOCKED_NEEDS_FORMAT % needs if needs != "" else LOCKED_PREFIX
		return "%s%s" % [prefix, upgrade.name]
	var currency_label: String = CURRENCY_LABELS[upgrade.currency]
	if upgrade.cost == 1:
		# "1 Core", not "1 Cores".
		currency_label = currency_label.trim_suffix("s")
	var cost_text: String = "FREE" if upgrade.cost <= 0 else "%d %s" % [upgrade.cost, currency_label]
	var text: String = "%s — %s" % [upgrade.name, cost_text]
	var total: String = _total_tag(upgrade, p)
	if total != "":
		text += "   " + total
	return text

## "[HP 140]" / "[SHIELD 50]" / "[LIVES 4]" on the repeatable stat rows, "" otherwise.
func _total_tag(upgrade: ShopUpgrade, p: PlayerProfile) -> String:
	if p == null or not upgrade.is_repeatable:
		return ""
	match upgrade.effect:
		ShopUpgrade.Effect.MAX_HP:
			return "[HP %d]" % int(BASE_MAX_HP + MAX_HP_PER_UPGRADE * p.max_hp_upgrades)
		ShopUpgrade.Effect.MAX_SHIELD:
			return "[SHIELD %d]" % int(BASE_MAX_SHIELD + MAX_SHIELD_PER_UPGRADE * p.shield_upgrades)
		ShopUpgrade.Effect.MAX_LIVES:
			return "[LIVES %d]" % (BASE_MAX_LIVES + p.max_lives_upgrades)
	return ""

## Short name of a prerequisite upgrade: "Unlock: Sweeper (A-B-B)" -> "Sweeper".
func _prereq_display_name(prereq_id: String) -> String:
	var all_paths: Array[String] = []
	all_paths.append_array(COMBO_UPGRADE_PATHS)
	all_paths.append_array(CUMULATIVE_UPGRADE_PATHS)
	for path in all_paths:
		var upgrade: ShopUpgrade = load(path)
		if upgrade and upgrade.id == prereq_id:
			var short_name: String = upgrade.name.trim_prefix("Unlock: ")
			var paren: int = short_name.find(" (")
			return short_name.substr(0, paren) if paren > 0 else short_name
	return ""

func _can_afford(upgrade: ShopUpgrade) -> bool:
	if upgrade.cost <= 0:
		return true
	if not (SaveManager and SaveManager.profile):
		return false
	var p: PlayerProfile = SaveManager.profile
	match upgrade.currency:
		ShopUpgrade.Currency.SCRAP:
			return p.scrap >= upgrade.cost
		ShopUpgrade.Currency.CELLS:
			return p.cells >= upgrade.cost
		ShopUpgrade.Currency.CORES:
			return p.cores >= upgrade.cost
	return false

## Row press: an unaffordable row does nothing but shake; otherwise it buys.
func _on_upgrade_row_pressed(button: Button, upgrade: ShopUpgrade) -> void:
	if not _can_afford(upgrade):
		_shake_row(button)
		return
	_on_buy_upgrade(upgrade)

## 0.2 s "no" shake: position.x +/- SHAKE_DISTANCE, four 0.05 s steps, back to rest.
func _shake_row(button: Button) -> void:
	if button.has_meta("shake_tween"):
		var previous = button.get_meta("shake_tween")
		if previous is Tween and previous.is_valid():
			previous.kill()
	# The rest position is captured once so overlapping presses can't drift the row.
	if not button.has_meta("shake_rest_x"):
		button.set_meta("shake_rest_x", button.position.x)
	var rest_x: float = button.get_meta("shake_rest_x")
	var tween := button.create_tween()
	button.set_meta("shake_tween", tween)
	tween.tween_property(button, "position:x", rest_x + SHAKE_DISTANCE, SHAKE_STEP_TIME)
	tween.tween_property(button, "position:x", rest_x - SHAKE_DISTANCE, SHAKE_STEP_TIME)
	tween.tween_property(button, "position:x", rest_x + SHAKE_DISTANCE, SHAKE_STEP_TIME)
	tween.tween_property(button, "position:x", rest_x, SHAKE_STEP_TIME)

## Wires left/right focus between the two columns, row i <-> row i (clamped to the shorter
## column), so the first rows of each column always connect.
func _wire_column_focus_neighbors() -> void:
	var left_rows: Array = cumulative_list.get_children()
	var right_rows: Array = combo_list.get_children()
	if left_rows.is_empty() or right_rows.is_empty():
		return
	for i in left_rows.size():
		var left_row: Control = left_rows[i]
		var right_row: Control = right_rows[mini(i, right_rows.size() - 1)]
		left_row.focus_neighbor_right = left_row.get_path_to(right_row)
	for i in right_rows.size():
		var right_row: Control = right_rows[i]
		var left_row: Control = left_rows[mini(i, left_rows.size() - 1)]
		right_row.focus_neighbor_left = right_row.get_path_to(left_row)

## (column, row index) of the focused upgrade row, or (-1, -1) when focus is elsewhere.
func _focused_row_position() -> Vector2i:
	var owner_control: Control = get_viewport().gui_get_focus_owner() if get_viewport() else null
	if owner_control == null:
		return Vector2i(-1, -1)
	var columns: Array[VBoxContainer] = [cumulative_list, combo_list]
	for column in columns.size():
		var rows: Array = columns[column].get_children()
		var idx: int = rows.find(owner_control)
		if idx >= 0:
			return Vector2i(column, idx)
	return Vector2i(-1, -1)

## Gives keyboard/gamepad focus to the remembered upgrade row if it is still enabled,
## otherwise the first enabled row (UPGRADES column first, then COMBO SKILL TREE), otherwise
## START RUN so the screen is never focus-less.
func _focus_upgrade_row(remembered: Vector2i = Vector2i(-1, -1)) -> void:
	if not is_inside_tree():
		return
	var columns: Array[VBoxContainer] = [cumulative_list, combo_list]
	if remembered.x >= 0 and remembered.x < columns.size():
		var rows: Array = columns[remembered.x].get_children()
		if remembered.y >= 0 and remembered.y < rows.size():
			var remembered_row := rows[remembered.y] as Button
			if remembered_row and not remembered_row.disabled:
				remembered_row.grab_focus()
				return
	for column in columns:
		for row in column.get_children():
			var button := row as Button
			if button and not button.disabled and not button.is_queued_for_deletion():
				button.grab_focus()
				return
	start_button.grab_focus()

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

## Mirrors slot 1 (BoosterButton) so extra slots match however the scene styles it. The
## look itself comes from the neon theme set on the KarensShop root.
func _style_booster_slot_button(button: Button) -> void:
	button.custom_minimum_size = booster_button.custom_minimum_size
	button.size_flags_horizontal = booster_button.size_flags_horizontal

## Keeps one extra slot button per booster slot beyond the first.
func _sync_booster_slot_buttons() -> void:
	var slots: int = SaveManager.profile.booster_slots if SaveManager and SaveManager.profile else 1
	var wanted: int = maxi(slots - 1, 0)
	while _extra_booster_buttons.size() > wanted:
		var stale: Button = _extra_booster_buttons.pop_back()
		stale.queue_free()
	while _extra_booster_buttons.size() < wanted:
		var button := Button.new()
		_style_booster_slot_button(button)
		button.pressed.connect(_cycle_booster_slot.bind(_extra_booster_buttons.size() + 1))
		var anchor: Button = _extra_booster_buttons.back() if not _extra_booster_buttons.is_empty() else booster_button
		anchor.add_sibling(button)
		_extra_booster_buttons.append(button)

func _booster_slot_buttons() -> Array[Button]:
	var buttons: Array[Button] = [booster_button]
	buttons.append_array(_extra_booster_buttons)
	return buttons

func _update_booster_buttons() -> void:
	if not (SaveManager and SaveManager.profile):
		return
	var p: PlayerProfile = SaveManager.profile
	var equipped: Array[String] = p.get_active_run_boosters()
	var buttons := _booster_slot_buttons()
	for slot in buttons.size():
		var booster: String = equipped[slot] if slot < equipped.size() else "None"
		buttons[slot].text = "RUN BOOSTER %d/%d: %s  (press to change)" % [slot + 1, p.booster_slots, booster.to_upper()]

## Cycles one slot through None/Tempo Shield/Adrenaline/Scrap Magnet, skipping boosters
## already equipped in another slot. "None" stores nothing (the array stays compact), and
## the stored array is always trimmed to booster_slots.
func _cycle_booster_slot(slot: int) -> void:
	if not (SaveManager and SaveManager.profile):
		return
	var p: PlayerProfile = SaveManager.profile
	if slot >= p.booster_slots:
		return
	var equipped: Array[String] = p.get_active_run_boosters()
	var current: String = equipped[slot] if slot < equipped.size() else "None"
	var idx: int = maxi(BOOSTERS.find(current), 0)
	var next: String = "None"
	for step in range(1, BOOSTERS.size() + 1):
		var candidate: String = BOOSTERS[(idx + step) % BOOSTERS.size()]
		if candidate == "None" or not equipped.has(candidate):
			next = candidate
			break
	if slot < equipped.size():
		if next == "None":
			equipped.remove_at(slot)
		else:
			equipped[slot] = next
	elif next != "None":
		equipped.append(next)
	p.equipped_run_boosters = equipped
	SaveManager.save_profile()
	_update_booster_buttons()

func _on_start_run() -> void:
	if GameManager:
		GameManager.start_new_run()
	get_tree().change_scene_to_file("res://levels/slice/vertical_slice.tscn")
