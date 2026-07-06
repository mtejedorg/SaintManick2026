extends "res://tests/framework/test_case.gd"

var hud: CanvasLayer

func before_each() -> void:
	hud = load("res://ui/hud/hud.tscn").instantiate()
	add_child(hud)

func after_each() -> void:
	if is_instance_valid(hud):
		hud.queue_free()

func test_ability_bar_lives_in_status_container_not_floating() -> void:
	# GAP-8 fix (M12): the ability bar used to be a generic floating ProgressBar at
	# top-left (offsets 20/80 in ability_bar.tscn). It must now be embedded in the HUD's
	# StatusContainer (the GDD-designated "old stamina slot"), not a standalone root child.
	var status_container = hud.get_node("MarginContainer/VBoxContainer/StatusContainer")
	var ability_bar = status_container.get_node_or_null("AbilityBar")
	assert_not_null(ability_bar, "AbilityBar should be a child of StatusContainer")

	# Must NOT be a direct child of the HUD root anymore (that was the old floating placement).
	assert_null(hud.get_node_or_null("AbilityBar"), "AbilityBar should no longer float at the HUD root")

func test_shield_bar_overlays_battery_not_separate_slot() -> void:
	# GAP-8 fix (M12): the shield used to sit in its own StatusContainer slot using the
	# stamina textures (the Ability Bar's actual slot). It must now be an overlay directly
	# on top of BatteryRect (GDD §6.1: "shield shown as an overlaid layer on top").
	var battery_container = hud.get_node("MarginContainer/VBoxContainer/StatusContainer/BatteryContainer")
	assert_not_null(battery_container, "Battery should be wrapped in a container so the shield can overlay it")

	var battery_rect = battery_container.get_node_or_null("BatteryRect")
	var shield_bar = battery_container.get_node_or_null("ShieldBar")
	assert_not_null(battery_rect, "BatteryRect should exist under BatteryContainer")
	assert_not_null(shield_bar, "ShieldBar should exist under BatteryContainer, overlaying the battery")

func test_ability_bar_uses_estamina_textures() -> void:
	# The Ability Bar now owns the stamina-slot textures previously (incorrectly)
	# assigned to the shield bar.
	var ability_bar = hud.get_node("MarginContainer/VBoxContainer/StatusContainer/AbilityBar")
	var progress_bar: TextureProgressBar = ability_bar.get_node("ProgressBar")
	assert_not_null(progress_bar.texture_under, "Ability bar should have an estamina background texture assigned")
	assert_not_null(progress_bar.texture_progress, "Ability bar should have an estamina fill texture assigned")

func test_hud_reflects_ability_meter_changes() -> void:
	var ability_bar = hud.get_node("MarginContainer/VBoxContainer/StatusContainer/AbilityBar")
	var progress_bar: TextureProgressBar = ability_bar.get_node("ProgressBar")

	if not SignalBus.ability_meter_changed.is_connected(ability_bar._on_ability_meter_changed):
		SignalBus.ability_meter_changed.connect(ability_bar._on_ability_meter_changed)

	SignalBus.ability_meter_changed.emit(75.0, 100.0)
	assert_eq(progress_bar.max_value, 100.0, "Ability bar max_value should track the emitted max_meter")
