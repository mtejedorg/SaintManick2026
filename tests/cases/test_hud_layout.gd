extends "res://tests/framework/test_case.gd"

var hud: CanvasLayer

func before_each() -> void:
	hud = load("res://ui/hud/hud.tscn").instantiate()
	add_child(hud)

func after_each() -> void:
	if is_instance_valid(hud):
		hud.queue_free()

func test_ability_bar_lives_in_lower_row_not_floating() -> void:
	# GAP-8 fix (M12): the ability bar used to be a generic floating ProgressBar at
	# top-left. It must be embedded in the top-right HUD cluster (the GDD-designated
	# "old stamina slot", now a horizontal strip in LowerRow under the battery), not a
	# standalone root child.
	var lower_row = hud.get_node("SafeArea/MarginContainer/VBoxContainer/LowerRow")
	var ability_bar = lower_row.get_node_or_null("AbilityBar")
	assert_not_null(ability_bar, "AbilityBar should be a child of LowerRow")

	# Must NOT be a direct child of the HUD root anymore (that was the old floating placement).
	assert_null(hud.get_node_or_null("AbilityBar"), "AbilityBar should no longer float at the HUD root")

func test_shield_bar_overlays_battery_not_separate_slot() -> void:
	# GAP-8 fix (M12) / D11: the shield is a thin 6 px strip directly under the segmented
	# battery bar, inside the same BatteryContainer (GDD §6.1).
	var battery_container = hud.get_node("SafeArea/MarginContainer/VBoxContainer/StatusContainer/BatteryContainer")
	assert_not_null(battery_container, "Battery should be wrapped in a container so the shield can overlay it")

	var battery_rect = battery_container.get_node_or_null("BatteryBar")
	var shield_bar = battery_container.get_node_or_null("ShieldBar")
	assert_not_null(battery_rect, "BatteryBar should exist under BatteryContainer")
	assert_not_null(shield_bar, "ShieldBar should exist under BatteryContainer, overlaying the battery")

func test_ability_bar_uses_ability_art_textures() -> void:
	# Q8: the Ability Bar is 10 themed cells (the battery's pattern) -- no textures at all.
	var ability_bar = hud.get_node("SafeArea/MarginContainer/VBoxContainer/LowerRow/AbilityBar")
	assert_null(ability_bar.get_node_or_null("ProgressBar"), "No TextureProgressBar any more")
	assert_eq(ability_bar.get_node("Frame/Segments").get_child_count(), 10, "10 cells")

func test_ability_bar_has_empty_track() -> void:
	# The empty art is only a small bracket, so a dark Track panel sits behind the meter to
	# keep the slot readable at 0.
	var ability_bar = hud.get_node("SafeArea/MarginContainer/VBoxContainer/LowerRow/AbilityBar")
	var frame = ability_bar.get_node_or_null("Frame")
	assert_not_null(frame, "AbilityBar should have a Frame panel holding the cells")
	if frame == null:
		return
	assert_true(frame is PanelContainer, "Frame should be a PanelContainer")
	assert_eq(frame.theme_type_variation, &"HudPanel", "...drawn as the dark HudPanel even at 0")
	assert_eq(ability_bar.get_node("Frame/Segments").get_child(0).theme_type_variation, &"HudSegmentEmpty", "An empty meter shows dark cells")

func test_hud_reflects_ability_meter_changes() -> void:
	var ability_bar = hud.get_node("SafeArea/MarginContainer/VBoxContainer/LowerRow/AbilityBar")
	if not SignalBus.ability_meter_changed.is_connected(ability_bar._on_ability_meter_changed):
		SignalBus.ability_meter_changed.connect(ability_bar._on_ability_meter_changed)

	SignalBus.ability_meter_changed.emit(75.0, 100.0)
	assert_eq(ability_bar.meter_max, 100.0, "Ability bar meter_max should track the emitted max_meter")
	assert_eq(ability_bar.lit_segments(), 7, "75/100 -> 7 cells")

func test_hud_has_no_input_overlay() -> void:
	# The keyboard-hint debug overlay is a dev tool only — it must not ship in the HUD.
	assert_null(hud.get_node_or_null("InputOverlay"), "HUD must not instance InputOverlay")

func test_battery_bar_has_segments_after_ready() -> void:
	# D11: the battery is drawn from 12 themed Panel cells instead of res://ui/hud/art/ PNGs.
	var segments: Node = hud.get_node("SafeArea/MarginContainer/VBoxContainer/StatusContainer/BatteryContainer/BatteryBar/Segments")
	assert_eq(segments.get_child_count(), 12, "BatteryBar should hold 12 segment cells after _ready()")
