extends "res://tests/framework/test_case.gd"

# Batch M (D11 option B): the HUD cluster is rebuilt from Controls styled by the theme's Hud*
# type variations. Battery = 12 themed cells + HP readout, shield = pale strip under it, lives =
# up to 4 diamond glyphs + xN + LAST LIFE, ability meter = 10 themed cells + a BASS DROP caption
# (Q8). No raster art from res://ui/hud/art/ is referenced. The killer is named by GameManager's
# death-beat card (Q4b).

const HUD_SCENE := preload("res://ui/hud/hud.tscn")
const THEME_PATH := "res://ui/theme/neon_theme.tres"
const ART_DIR := "res://ui/hud/art/"
const HUD_SCRIPTS := ["res://ui/hud/hud.gd", "res://ui/hud/ability_bar.gd"]
const HUD_SCENES := ["res://ui/hud/hud.tscn", "res://ui/hud/ability_bar.tscn"]

var hud: CanvasLayer
var _run_ended_before: bool
var _killer_before: String

func before_each() -> void:
	_run_ended_before = GameManager.run_ended
	_killer_before = GameManager.last_killer
	GameManager.run_ended = false
	GameManager.last_killer = ""
	hud = HUD_SCENE.instantiate()
	add_child(hud)

func after_each() -> void:
	GameManager.run_ended = _run_ended_before
	GameManager.last_killer = _killer_before
	if is_instance_valid(hud):
		hud.queue_free()
	super.after_each()

func _cells() -> Array:
	return hud.battery_segments.get_children()

func _visible_glyphs() -> int:
	var count := 0
	for child in hud.lives_row.get_children():
		if child != hud.lives_count_label and (child as CanvasItem).visible:
			count += 1
	return count

func _ability_bar() -> Control:
	return hud.get_node("SafeArea/MarginContainer/VBoxContainer/LowerRow/AbilityBar")

# --- Battery ----------------------------------------------------------------------------

func test_full_hp_lights_all_twelve_segments() -> void:
	SignalBus.player_health_changed.emit(120.0, 120.0)
	assert_eq(_cells().size(), 12, "12 battery cells")
	assert_eq(hud.lit_battery_segments(), 12, "120/120 -> 12 lit")
	for cell in _cells():
		assert_eq(cell.theme_type_variation, &"HudSegment", "Full battery cells are cyan HudSegment")
	assert_eq(hud.hp_label.text, "HP 120/120")
	assert_eq(hud.hp_label.theme_type_variation, &"HudNumeral")

func test_quarter_hp_lights_three_danger_segments() -> void:
	SignalBus.player_health_changed.emit(30.0, 120.0)
	assert_eq(hud.lit_battery_segments(), 3, "30/120 -> 3 lit")
	var cells := _cells()
	for i in 3:
		assert_eq(cells[i].theme_type_variation, &"HudSegmentDanger", "The last 3 cells to drain turn magenta (cell %d)" % i)
	for i in range(3, 12):
		assert_eq(cells[i].theme_type_variation, &"HudSegmentEmpty", "Drained cell %d is dark" % i)
	assert_eq(hud.hp_label.theme_type_variation, &"HudNumeralDanger", "The readout turns magenta too")
	SignalBus.player_health_changed.emit(70.0, 120.0)
	assert_eq(hud.lit_battery_segments(), 7, "70/120 -> 7 lit")
	assert_eq(cells[0].theme_type_variation, &"HudSegment", "Back above a quarter -> cyan again")
	assert_eq(hud.hp_label.text, "HP 70/120")

func test_a_sliver_of_hp_still_lights_one_cell() -> void:
	SignalBus.player_health_changed.emit(2.0, 120.0)
	assert_eq(hud.lit_battery_segments(), 1, "Alive -> never an empty battery")
	SignalBus.player_health_changed.emit(0.0, 120.0)
	assert_eq(hud.lit_battery_segments(), 0, "Dead -> empty")

func test_hp_readout_is_a_20px_numeral_right_of_the_bar() -> void:
	assert_eq(hud.hp_label.get_theme_font_size("font_size"), 26, "Q8: the HP readout reads at 26 px")
	var row: Node = hud.get_node("SafeArea/MarginContainer/VBoxContainer/StatusContainer")
	assert_true(hud.hp_label.get_index() > row.get_node("BatteryContainer").get_index(), "Readout sits right of the battery")

func test_low_hp_pulse_still_tweens_the_whole_bar() -> void:
	SignalBus.player_health_changed.emit(20.0, 120.0)
	SignalBus.beat.emit("primary", 0)
	await get_tree().create_timer(0.1).timeout
	assert_true(hud.battery_bar.modulate != Color.WHITE, "Low HP pulses the bar's modulate on the beat")
	SignalBus.player_health_changed.emit(120.0, 120.0)
	assert_eq(hud.battery_bar.modulate, Color.WHITE, "Leaving low HP resets the bar")

# --- Shield -----------------------------------------------------------------------------

func test_half_shield_shows_the_strip_at_fifty_percent() -> void:
	SignalBus.player_shield_changed.emit(20.0, 40.0)
	assert_true(hud.shield_bar.visible, "Shield up -> strip visible")
	assert_almost_eq(hud.shield_bar.value / hud.shield_bar.max_value, 0.5, 0.001, "20/40 -> half")
	assert_eq(hud.shield_bar.theme_type_variation, &"HudStrip")
	assert_true(hud.shield_bar.offset_top >= hud.battery_bar.offset_bottom, "Strip sits directly under the battery")
	assert_almost_eq(hud.shield_bar.offset_bottom - hud.shield_bar.offset_top, 6.0, 0.01, "6 px strip")

func test_zero_shield_hides_the_strip() -> void:
	SignalBus.player_shield_changed.emit(0.0, 40.0)
	assert_false(hud.shield_bar.visible, "Shield down -> strip hidden")
	SignalBus.player_shield_changed.emit(5.0, 40.0)
	assert_true(hud.shield_bar.visible, "Regenerating -> back")

# --- Lives ------------------------------------------------------------------------------

func test_three_lives_show_three_glyphs() -> void:
	hud._on_lives_changed(3)
	assert_eq(_visible_glyphs(), 3, "3 lives -> 3 diamonds")
	assert_false(hud.lives_count_label.visible, "No xN tag at 3")
	assert_false(hud.last_life_label.visible, "No LAST LIFE tag at 3")
	for child in hud.lives_row.get_children():
		if child != hud.lives_count_label:
			assert_true(child.get_child(0) is Polygon2D, "Each glyph is a drawn diamond, not a texture")

func test_six_lives_show_four_glyphs_and_a_count() -> void:
	hud._on_lives_changed(6)
	assert_eq(_visible_glyphs(), 4, "Glyphs cap at 4")
	assert_true(hud.lives_count_label.visible, "6 lives -> xN tag")
	assert_eq(hud.lives_count_label.text, "x6")

func test_zero_spare_lives_shows_only_last_life() -> void:
	hud._on_lives_changed(0)
	assert_eq(_visible_glyphs(), 0, "No spare lives -> no glyphs")
	assert_true(hud.last_life_label.visible, "LAST LIFE tag takes over")

# --- Ability meter ----------------------------------------------------------------------

func test_half_meter_lights_five_segments() -> void:
	var bar := _ability_bar()
	SignalBus.ability_meter_changed.emit(50.0, 100.0)
	assert_eq(bar.lit_segments(), 5, "50/100 -> 5 of 10 cells")
	var lit := 0
	for cell in bar.segments.get_children():
		if cell.theme_type_variation == &"HudSegment":
			lit += 1
	assert_eq(lit, 5, "...five cells drawn lit")

func test_meter_strip_has_ten_cells_ticks_and_scale() -> void:
	var bar := _ability_bar()
	assert_true(bar.get_node("Frame/Segments") is HBoxContainer, "Q8: the meter is an HBoxContainer of cells")
	assert_eq(bar.get_node("Frame/Segments").get_child_count(), 10, "10 cells")
	for cell in bar.get_node("Frame/Segments").get_children():
		assert_true(String(cell.theme_type_variation).begins_with("HudSegment"), "%s is a HudSegment cell" % cell.name)
	assert_null(bar.get_node_or_null("Scale"), "The 0..100 digit row is gone")
	var caption: Label = bar.get_node("Caption")
	assert_eq(caption.text, "BASS DROP", "...replaced by one caption")
	assert_eq(caption.get_theme_font_size("font_size"), 18, "...at 18 px")
	assert_eq(bar.get_node("Frame").theme_type_variation, &"HudPanel")

func test_meter_fill_rests_cyan_and_holds_white_when_armed() -> void:
	var bar := _ability_bar()
	SignalBus.ability_meter_changed.emit(100.0, 100.0)
	assert_eq(bar.segments.get_child(0).theme_type_variation, &"HudSegment", "Resting fill is cyan")
	assert_false(bar.caption_lit(), "BASS DROP caption dim until armed")
	SignalBus.bass_drop_armed.emit(true)
	for cell in bar.segments.get_children():
		assert_eq(cell.theme_type_variation, &"HudSegmentHot", "Armed -> white hold (%s)" % cell.name)
	assert_true(bar.caption_lit(), "...and the caption lights")
	SignalBus.bass_drop_armed.emit(false)
	SignalBus.ability_meter_changed.emit(0.0, 100.0)
	assert_eq(bar.segments.get_child(0).theme_type_variation, &"HudSegmentEmpty", "Spent -> empty")
	SignalBus.ability_meter_changed.emit(30.0, 100.0)
	assert_eq(bar.segments.get_child(0).theme_type_variation, &"HudSegment", "...then cyan again")
	assert_false(bar.caption_lit(), "...caption dim")

# --- Theme + no raster art --------------------------------------------------------------

func test_theme_defines_the_hud_variations() -> void:
	var theme: Theme = load(THEME_PATH)
	for type_name in [&"HudPanel", &"HudSegment", &"HudSegmentEmpty", &"HudSegmentDanger"]:
		assert_true(theme.has_stylebox(&"panel", type_name), "%s has a panel style" % type_name)
	assert_true(theme.has_stylebox(&"fill", &"HudStrip") and theme.has_stylebox(&"background", &"HudStrip"), "HudStrip styles a ProgressBar")
	var danger := theme.get_stylebox(&"panel", &"HudSegmentDanger") as StyleBoxFlat
	assert_eq(danger.bg_color, Color(1, 0, 0.667, 1), "Danger cells are magenta")
	var frame := theme.get_stylebox(&"panel", &"HudPanel") as StyleBoxFlat
	assert_eq(frame.border_width_top, 1, "1 px frame")
	assert_almost_eq(frame.bg_color.a, 0.6, 0.01, "Near-black panel at 0.6 alpha")

func test_hud_scene_references_no_hud_art_png() -> void:
	var offenders: Array = []
	_collect_art_refs(HUD_SCENE, offenders)
	assert_eq(offenders, [], "No node in hud.tscn (or its instanced scenes) references ui/hud/art/*.png")
	for path in HUD_SCENES + HUD_SCRIPTS:
		var text := FileAccess.get_file_as_string(path)
		assert_false(text.contains(ART_DIR), "%s has no ui/hud/art/ path" % path)

func _collect_art_refs(scene: PackedScene, offenders: Array) -> void:
	var state := scene.get_state()
	for i in state.get_node_count():
		var inst := state.get_node_instance(i)
		if inst:
			_collect_art_refs(inst, offenders)
		for p in state.get_node_property_count(i):
			var value = state.get_node_property_value(i, p)
			if value is Resource:
				var res_path: String = (value as Resource).resource_path
				if res_path.begins_with(ART_DIR) and res_path.ends_with(".png"):
					offenders.append("%s.%s" % [state.get_node_path(i), state.get_node_property_name(i, p)])

# --- Banner -----------------------------------------------------------------------------

## Q4b: the killer is named by GameManager's death-beat card, the respawn card follows; the
## HUD adds nothing of its own.
func test_life_lost_banner_names_the_killer() -> void:
	SignalBus.banner_requested.emit(GameManager.death_banner_text("RUNNER"), GameManager.DEATH_BEAT_SECONDS)
	assert_eq(hud.zone_title_card.label.text, "DESTROYED BY RUNNER", "The death beat names the killer")
	SignalBus.player_life_lost.emit(2)
	assert_eq(hud.zone_title_card.label.text, "DESTROYED BY RUNNER", "player_life_lost alone changes nothing on the HUD")
	SignalBus.banner_requested.emit(GameManager.respawn_banner_text(2, "SECTOR 05 — NEON MARKET"), GameManager.RESPAWN_BANNER_HOLD)
	assert_eq(hud.zone_title_card.label.text, "LIFE LOST — 2 LEFT — RESUMING SECTOR 05", "...the respawn card is GameManager's")
	assert_false(hud.zone_title_card.eyebrow_label.visible, "No eyebrow on a banner")
