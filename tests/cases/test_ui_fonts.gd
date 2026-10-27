extends "res://tests/framework/test_case.gd"

# Batch N (D26 option A): the UI typefaces are wired once, in ui/theme/neon_theme.tres.
# Orbitron (variable, wght 400-900) is the display face: buttons, titles, headings, eyebrows,
# the zone card, the combo pop. Share Tech Mono is the default font: HUD numerals, meter scale,
# currency counters, dim labels, shop rows, footer. No scene under ui/ carries a SystemFont or an
# inline font override.

const THEME_PATH := "res://ui/theme/neon_theme.tres"
const ORBITRON := "res://assets/fonts/Orbitron-Variable.ttf"
const MONO := "res://assets/fonts/ShareTechMono-Regular.ttf"
const UI_DIR := "res://ui/"
## OpenType tag "wght" as the int key FontVariation.variation_opentype stores.
const WGHT_TAG := 0x77676874

const ORBITRON_TYPES := [&"Button", &"TitleLabel", &"HeadingLabel", &"EyebrowLabel", &"DimHeading", &"ZoneCardLabel", &"HudCombo"]
const MONO_TYPES := [&"Label", &"HudNumeral", &"HudNumeralDanger", &"HudScale", &"DimLabel", &"UpgradeRow"]

var theme: Theme

func before_each() -> void:
	theme = load(THEME_PATH)

## The FontFile at the bottom of a FontVariation chain.
func _base(font: Font) -> Font:
	while font is FontVariation and (font as FontVariation).base_font != null:
		font = (font as FontVariation).base_font
	return font

## Font a theme type resolves to, walking base_type like Control does.
func _type_font(type_name: StringName) -> Font:
	var t := type_name
	while t != &"":
		if theme.has_font(&"font", t):
			return theme.get_font(&"font", t)
		t = theme.get_type_variation_base(t)
	return theme.default_font

func _ui_files(dir_path: String, out: Array[String]) -> void:
	var dir := DirAccess.open(dir_path)
	if dir == null:
		return
	for sub in dir.get_directories():
		_ui_files(dir_path.path_join(sub), out)
	for f in dir.get_files():
		if f.ends_with(".tscn") or f.ends_with(".tres"):
			out.append(dir_path.path_join(f))

func test_both_font_files_exist_and_load_as_font() -> void:
	for path in [ORBITRON, MONO]:
		assert_true(ResourceLoader.exists(path), "%s is imported" % path)
		assert_true(load(path) is Font, "%s loads as a Font" % path)

func test_default_font_is_share_tech_mono() -> void:
	assert_not_null(theme.default_font, "The theme has a default font")
	assert_true(_base(theme.default_font).resource_path.ends_with("ShareTechMono-Regular.ttf"), "Default font is Share Tech Mono")

func test_display_types_use_orbitron() -> void:
	for t in ORBITRON_TYPES:
		var font := _type_font(t)
		assert_not_null(font, "%s resolves a font" % t)
		if font != null:
			assert_eq(_base(font).resource_path, ORBITRON, "%s is Orbitron" % t)

func test_buttons_and_titles_are_orbitron_bold() -> void:
	for t in [&"Button", &"TitleLabel", &"HeadingLabel", &"ZoneCardLabel"]:
		var font := _type_font(t)
		assert_true(font is FontVariation, "%s uses a weighted FontVariation" % t)
		if font is FontVariation:
			assert_eq(int((font as FontVariation).variation_opentype.get(WGHT_TAG, 0)), 700, "%s at wght 700" % t)

func test_orbitron_falls_back_to_mono_for_missing_glyphs() -> void:
	# Orbitron has no U+00B7 middle dot, which the life-lost banner uses.
	var font := _type_font(&"ZoneCardLabel")
	var fallback_paths: Array[String] = []
	for fb in font.fallbacks:
		fallback_paths.append(_base(fb).resource_path)
	assert_true(MONO in fallback_paths, "Orbitron variations fall back to Share Tech Mono")

func test_hud_and_body_types_use_share_tech_mono() -> void:
	for t in MONO_TYPES:
		var font := _type_font(t)
		assert_not_null(font, "%s resolves a font" % t)
		if font != null:
			assert_eq(_base(font).resource_path, MONO, "%s is Share Tech Mono" % t)

func test_no_system_font_or_inline_font_override_under_ui() -> void:
	var files: Array[String] = []
	_ui_files(UI_DIR, files)
	assert_gt(files.size(), 5, "Found the ui/ scenes")
	for path in files:
		var text := FileAccess.get_file_as_string(path)
		assert_false(text.contains("SystemFont"), "%s references no SystemFont" % path)
		if path.ends_with(".tscn"):
			assert_false(text.contains("theme_override_fonts/"), "%s overrides no font inline" % path)

func test_zone_card_and_combo_render_in_orbitron() -> void:
	var hud: CanvasLayer = preload("res://ui/hud/hud.tscn").instantiate()
	add_child(hud)
	var combo: Label = hud.get_node("ComboLabel")
	assert_eq(_base(combo.get_theme_font(&"font")).resource_path, ORBITRON, "Combo pop is Orbitron")
	assert_eq((combo.get_theme_font(&"font") as FontVariation).spacing_glyph, 3, "Combo keeps its 3 px glyph spacing")
	assert_eq(_base(hud.zone_title_card.label.get_theme_font(&"font")).resource_path, ORBITRON, "Zone card is Orbitron")
	assert_eq(_base(hud.hp_label.get_theme_font(&"font")).resource_path, MONO, "HP readout is Share Tech Mono")
	assert_eq(_base(hud.scrap_label.get_theme_font(&"font")).resource_path, MONO, "Currency counter is Share Tech Mono")
	hud.queue_free()
