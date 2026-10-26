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
	var lower_row = hud.get_node("MarginContainer/VBoxContainer/LowerRow")
	var ability_bar = lower_row.get_node_or_null("AbilityBar")
	assert_not_null(ability_bar, "AbilityBar should be a child of LowerRow")

	# Must NOT be a direct child of the HUD root anymore (that was the old floating placement).
	assert_null(hud.get_node_or_null("AbilityBar"), "AbilityBar should no longer float at the HUD root")

func test_shield_bar_overlays_battery_not_separate_slot() -> void:
	# GAP-8 fix (M12) / D11: the shield is a thin 6 px strip directly under the segmented
	# battery bar, inside the same BatteryContainer (GDD §6.1).
	var battery_container = hud.get_node("MarginContainer/VBoxContainer/StatusContainer/BatteryContainer")
	assert_not_null(battery_container, "Battery should be wrapped in a container so the shield can overlay it")

	var battery_rect = battery_container.get_node_or_null("BatteryBar")
	var shield_bar = battery_container.get_node_or_null("ShieldBar")
	assert_not_null(battery_rect, "BatteryBar should exist under BatteryContainer")
	assert_not_null(shield_bar, "ShieldBar should exist under BatteryContainer, overlaying the battery")

func test_ability_bar_uses_ability_art_textures() -> void:
	# D11: the Ability Bar's under/fill textures are flat generated textures (no raster art).
	var ability_bar = hud.get_node("MarginContainer/VBoxContainer/LowerRow/AbilityBar")
	var progress_bar: TextureProgressBar = ability_bar.get_node("ProgressBar")
	assert_not_null(progress_bar.texture_under, "Ability bar should have a background texture assigned")
	assert_not_null(progress_bar.texture_progress, "Ability bar should have a fill texture assigned")

func test_ability_bar_has_empty_track() -> void:
	# The empty art is only a small bracket, so a dark Track panel sits behind the meter to
	# keep the slot readable at 0.
	var ability_bar = hud.get_node("MarginContainer/VBoxContainer/LowerRow/AbilityBar")
	var track = ability_bar.get_node_or_null("Track")
	assert_not_null(track, "AbilityBar should have a Track child behind the progress bar")
	if track == null:
		return
	assert_true(track is Panel, "Track should be a Panel")
	assert_true(track.get_index() < ability_bar.get_node("ProgressBar").get_index(), "Track must be drawn behind the ProgressBar")

func test_hud_reflects_ability_meter_changes() -> void:
	var ability_bar = hud.get_node("MarginContainer/VBoxContainer/LowerRow/AbilityBar")
	var progress_bar: TextureProgressBar = ability_bar.get_node("ProgressBar")

	if not SignalBus.ability_meter_changed.is_connected(ability_bar._on_ability_meter_changed):
		SignalBus.ability_meter_changed.connect(ability_bar._on_ability_meter_changed)

	SignalBus.ability_meter_changed.emit(75.0, 100.0)
	assert_eq(progress_bar.max_value, 100.0, "Ability bar max_value should track the emitted max_meter")

func test_hud_has_no_input_overlay() -> void:
	# The keyboard-hint debug overlay is a dev tool only — it must not ship in the HUD.
	assert_null(hud.get_node_or_null("InputOverlay"), "HUD must not instance InputOverlay")

func test_battery_bar_has_segments_after_ready() -> void:
	# D11: the battery is drawn from 12 themed Panel cells instead of res://ui/hud/art/ PNGs.
	var segments: Node = hud.get_node("MarginContainer/VBoxContainer/StatusContainer/BatteryContainer/BatteryBar/Segments")
	assert_eq(segments.get_child_count(), 12, "BatteryBar should hold 12 segment cells after _ready()")
