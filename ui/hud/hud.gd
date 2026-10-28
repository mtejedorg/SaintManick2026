extends CanvasLayer

## D11 (batch M): the HUD cluster is drawn from Controls styled by the theme's Hud* type
## variations (ui/theme/neon_theme.tres) — no raster art. The battery is a framed 12-segment
## bar; the low-HP pulse tweens this whole bar's modulate.
@onready var battery_bar: PanelContainer = $SafeArea/MarginContainer/VBoxContainer/StatusContainer/BatteryContainer/BatteryBar
@onready var battery_segments: HBoxContainer = $SafeArea/MarginContainer/VBoxContainer/StatusContainer/BatteryContainer/BatteryBar/Segments
## Numeric "HP 120/120" readout right of the battery.
@onready var hp_label: Label = $SafeArea/MarginContainer/VBoxContainer/StatusContainer/HpLabel
## GAP-8 fix (M12) / D11: the shield is a thin pale-cyan strip directly under the battery
## (GDD §6.1), filling left-to-right, hidden while the shield is down.
@onready var shield_bar: ProgressBar = $SafeArea/MarginContainer/VBoxContainer/StatusContainer/BatteryContainer/ShieldBar
## One cyan diamond per spare life, up to LIVES_GLYPH_MAX.
# ART: optional 24x24 Nick head glyph (cyan line art on transparent, PNG) to sit as the first
# child of LivesRow so the diamonds read as "Nick's lives" at a glance; the row works without it.
@onready var lives_row: HBoxContainer = $SafeArea/MarginContainer/VBoxContainer/LowerRow/LivesBox/LivesRow
## Magenta "LAST LIFE" tag under the lives glyphs, shown when no spare lives remain.
@onready var last_life_label: Label = $SafeArea/MarginContainer/VBoxContainer/LowerRow/LivesBox/LastLifeLabel
## U6: "xN" tag after the glyphs when there are more lives than glyphs.
@onready var lives_count_label: Label = $SafeArea/MarginContainer/VBoxContainer/LowerRow/LivesBox/LivesRow/LivesCountLabel
@onready var zone_title_card: Control = $ZoneTitleCard
@onready var beat_pulse_node: Control = $BeatPulse
@onready var combo_label: Label = $ComboLabel
@onready var boss_bar_container: PanelContainer = $SafeArea/BossBarMargin/BossBarContainer
@onready var boss_name_label: Label = $SafeArea/BossBarMargin/BossBarContainer/BossBarVBox/BossNameLabel
@onready var boss_health_bar: ProgressBar = $SafeArea/BossBarMargin/BossBarContainer/BossBarVBox/BossHealthBar
## U5: thin cyan strip along the boss bar's top edge, same treatment as the player shield.
@onready var boss_shield_strip: TextureProgressBar = $SafeArea/BossBarMargin/BossBarContainer/BossBarVBox/BossHealthBar/BossShieldStrip

@onready var scrap_label: Label = $SafeArea/Currencies/ScrapLabel
@onready var cells_label: Label = $SafeArea/Currencies/CellsLabel
@onready var cores_label: Label = $SafeArea/Currencies/CoresLabel
## Q5: "SECTOR 03 / 10 + boosters" under the currencies, set on zone_entered.
@onready var zone_tag: Label = $SafeArea/Currencies/HudZoneTag
## Q8: every corner element lives in this MarginContainer, clamped to a centred 16:9 rect.
@onready var safe_area: MarginContainer = $SafeArea
## Q6: the action-gated control hints, bottom-left.
@onready var hud_hints: HBoxContainer = $SafeArea/HudHints
## Q8: full-screen magenta edge glow at low HP (ui/hud/low_hp_vignette.gdshader).
@onready var low_hp_vignette: ColorRect = $LowHpVignette

const COMBO_CYAN := Color(0.0, 0.961, 1.0, 1.0)
## Below this fraction of max HP the battery pulses magenta on every beat.
const LOW_HP_RATIO := 0.25
const LOW_HP_MAGENTA := Color(1.0, 0.0, 0.667, 1.0)
const LOW_HP_PULSE_TIME := 0.15
## Q8: the HUD corners sit inside a centred 16:9 rect plus this margin (px, 1080p canvas).
const SAFE_ASPECT := 16.0 / 9.0
const SAFE_MARGIN := 20.0
## Q5: the slice's zone count for the zone tag ("SECTOR 03 / 10").
const ZONE_COUNT := 10
## Q5: the boss entrance card ("LIVE ON AIR" over the boss name), then the bar fades in.
const BOSS_EYEBROW := "LIVE ON AIR"
const BOSS_BAR_FADE_TIME := 0.4
## Q8: low-HP vignette -- fully off above VIGNETTE_START_RATIO of max HP, full at
## VIGNETTE_FULL_RATIO and below; beat pulse decay and the player_damaged flash.
const VIGNETTE_START_RATIO := 0.35
const VIGNETTE_FULL_RATIO := 0.1
const VIGNETTE_PULSE_TIME := 0.3
const VIGNETTE_FLASH_PEAK := 0.5
const VIGNETTE_FLASH_TIME := 0.15
## Battery segment count, and how many of the last cells to drain turn magenta at low HP.
const BATTERY_SEGMENTS := 12
const BATTERY_DANGER_SEGMENTS := 3
## Theme type variations (ui/theme/neon_theme.tres) the battery cells and HP readout switch between.
const SEGMENT_LIT := &"HudSegment"
const SEGMENT_EMPTY := &"HudSegmentEmpty"
const SEGMENT_DANGER := &"HudSegmentDanger"
const NUMERAL := &"HudNumeral"
const NUMERAL_DANGER := &"HudNumeralDanger"
## The lives row tops out at this many glyphs; more lives add an "xN" tag (U6).
const LIVES_GLYPH_MAX := 4
## U7: per-beat "LAST LIFE" pulse, alpha LAST_LIFE_PULSE_LOW <-> 1.0.
const LAST_LIFE_PULSE_LOW := 0.6
const LAST_LIFE_PULSE_TIME := 0.3

var beat_tween: Tween
var combo_tween: Tween
var low_hp_tween: Tween
var last_life_tween: Tween
var _low_hp: bool = false
## Q5: seconds the boss card holds before it slides out (tests shorten it).
var boss_card_hold: float = 1.8
var _boss_bar_tween: Tween
var _vignette_material: ShaderMaterial
var _vignette_intensity: float = 0.0
var _vignette_flash: float = 0.0
var _vignette_pulse_tween: Tween
var _vignette_flash_tween: Tween

func _ready() -> void:
	# Subscriptions
	SignalBus.player_health_changed.connect(_on_player_health_changed)
	SignalBus.player_shield_changed.connect(_on_player_shield_changed)
	GameManager.lives_changed.connect(_on_lives_changed)
	SignalBus.player_damaged.connect(_on_player_damaged)
	SignalBus.zone_entered.connect(_on_zone_entered)
	SignalBus.beat.connect(_on_beat)
	SignalBus.downbeat.connect(_on_downbeat)
	SignalBus.combo_increased.connect(_on_combo_increased)
	SignalBus.combo_reset.connect(_on_combo_reset)
	SignalBus.combo_capped.connect(_on_combo_capped)
	SignalBus.boss_spawned.connect(_on_boss_spawned)
	SignalBus.boss_health_changed.connect(_on_boss_health_changed)
	SignalBus.boss_shield_changed.connect(_on_boss_shield_changed)
	SignalBus.boss_died.connect(_on_boss_died)
	SignalBus.boss_reset.connect(_on_boss_reset)
	GameManager.scrap_changed.connect(_on_scrap_changed)
	GameManager.cells_changed.connect(_on_cells_changed)
	GameManager.cores_changed.connect(_on_cores_changed)

	# Initial UI Setup
	# Each HUD owns its vignette material (the scene's sub-resource is shared between instances).
	_vignette_material = (low_hp_vignette.material as ShaderMaterial).duplicate() as ShaderMaterial
	low_hp_vignette.material = _vignette_material
	get_viewport().size_changed.connect(_update_safe_area)
	if SaveManager and SaveManager.profile and not SaveManager.profile.changed.is_connected(_update_safe_area):
		SaveManager.profile.changed.connect(_update_safe_area) # V11: HUD SIZE picked in the options
	_update_safe_area()
	_setup_boss_shield_strip()
	_update_battery_ui(GameManager.current_hp, GameManager.max_hp)
	_update_vignette(GameManager.current_hp, GameManager.max_hp)
	_update_shield_ui(GameManager.current_shield, GameManager.max_shield)
	_update_lives_ui(GameManager.current_lives)
	scrap_label.text = "SCRAP  %d" % GameManager.scrap
	cells_label.text = "CELLS  %d" % GameManager.cells
	cores_label.text = "CORES  %d" % GameManager.cores
	
	# Set pivot offset for beat pulse center pulsing
	beat_pulse_node.pivot_offset = beat_pulse_node.size / 2.0
	beat_pulse_node.modulate = Color(1.0, 1.0, 1.0, 0.5)

## U5: the boss bar's shield strip is a flat white fill tinted cyan by the node's modulate,
## stretched to the (variable) boss bar width.
func _setup_boss_shield_strip() -> void:
	var flat_fill = GradientTexture2D.new()
	var gradient = Gradient.new()
	gradient.set_color(0, Color(1, 1, 1, 1))
	gradient.set_color(1, Color(1, 1, 1, 1))
	flat_fill.gradient = gradient
	flat_fill.width = 265
	flat_fill.height = 6
	boss_shield_strip.fill_mode = TextureProgressBar.FILL_LEFT_TO_RIGHT
	boss_shield_strip.nine_patch_stretch = true
	boss_shield_strip.texture_progress = flat_fill

func _on_player_health_changed(new_health: float, max_health: float) -> void:
	_update_battery_ui(new_health, max_health)
	_update_vignette(new_health, max_health)

func _on_player_shield_changed(new_shield: float, max_shield: float) -> void:
	_update_shield_ui(new_shield, max_shield)

func _on_lives_changed(new_amount: int) -> void:
	_update_lives_ui(new_amount)

## Q4b: the life-lost card ("LIFE LOST — N LEFT — RESUMING SECTOR NN" / "LAST LIFE") and the
## death-beat "DESTROYED BY X" card come from GameManager through banner_requested; the HUD no
## longer builds its own (the two collided on the same frame). The LAST LIFE tag and its beat
## pulse still follow lives_changed (_update_lives_ui).

## Q8: margins that keep the corners inside a centred 16:9 rect (+ SAFE_MARGIN) on any window.
func _update_safe_area() -> void:
	var rect := get_viewport().get_visible_rect().size
	if rect.x <= 0.0 or rect.y <= 0.0:
		return
	var margin_x := SAFE_MARGIN
	var margin_y := SAFE_MARGIN
	var aspect := rect.x / rect.y
	if aspect > SAFE_ASPECT:
		margin_x += (rect.x - rect.y * SAFE_ASPECT) / 2.0
	elif aspect < SAFE_ASPECT:
		margin_y += (rect.y - rect.x / SAFE_ASPECT) / 2.0
	safe_area.add_theme_constant_override("margin_left", roundi(margin_x))
	safe_area.add_theme_constant_override("margin_right", roundi(margin_x))
	safe_area.add_theme_constant_override("margin_top", roundi(margin_y))
	safe_area.add_theme_constant_override("margin_bottom", roundi(margin_y))
	_apply_hud_scale(rect)

## V11: HUD SIZE. SafeArea scales uniformly about its top-left corner while its size shrinks to
## rect / scale, so every corner widget stays pinned to its own corner at any step.
func _apply_hud_scale(rect: Vector2) -> void:
	var s := hud_scale()
	safe_area.set_anchors_preset(Control.PRESET_TOP_LEFT)
	safe_area.pivot_offset = Vector2.ZERO
	safe_area.scale = Vector2(s, s)
	safe_area.position = Vector2.ZERO
	safe_area.size = rect / s

## The scale in force: the profile's HUD SIZE (auto 125 % in a window under 900 px high).
func hud_scale() -> float:
	var profile: PlayerProfile = SaveManager.profile if SaveManager else null
	if profile == null:
		return 1.0
	var window_height := float(get_window().size.y) if get_window() else 1080.0
	return maxf(profile.effective_hud_scale(window_height), 0.5)

## Q5: the first integer of a zone name ("SECTOR 03 — ..." -> 3), the audio parser's rule;
## 0 when there is none.
static func zone_number(zone_name: String) -> int:
	for part in zone_name.split(" "):
		var n := part.to_int()
		if n > 0:
			return n
	return 0

## Q5: "SECTOR 03 / 10", plus " · ADRENALINE" for each run booster.
static func zone_tag_text(zone_name: String, boosters: Array[String]) -> String:
	var n := zone_number(zone_name)
	if n <= 0:
		return ""
	var text := "SECTOR %02d / %d" % [n, ZONE_COUNT]
	for booster in boosters:
		text += " \u00b7 %s" % booster.to_upper()
	return text

func _on_zone_entered(zone_name: String) -> void:
	var text := zone_tag_text(zone_name, GameManager.run_boosters())
	if text == "":
		return
	zone_tag.text = text
	zone_tag.visible = true

## Q8: the vignette's base alpha for an HP ratio (0 above 35 %, 1 at 10 % and below).
static func vignette_alpha_for(ratio: float) -> float:
	return 1.0 - smoothstep(VIGNETTE_FULL_RATIO, VIGNETTE_START_RATIO, ratio)

## The vignette's current base alpha (0 = off).
func vignette_alpha() -> float:
	return _vignette_intensity

func _update_vignette(current: float, max_val: float) -> void:
	var ratio: float = current / max_val if max_val > 0.0 else 1.0
	_vignette_intensity = 0.0 if GameManager.reduce_flashes() else vignette_alpha_for(ratio)
	_vignette_material.set_shader_parameter("intensity", _vignette_intensity)
	_sync_vignette_visible()

func _sync_vignette_visible() -> void:
	low_hp_vignette.visible = _vignette_intensity > 0.0 or _vignette_flash > 0.0

func _set_vignette_pulse(value: float) -> void:
	_vignette_material.set_shader_parameter("pulse", value)

func _set_vignette_flash(value: float) -> void:
	_vignette_flash = value
	_vignette_material.set_shader_parameter("flash", value)
	_sync_vignette_visible()

func _pulse_vignette() -> void:
	if _vignette_intensity <= 0.0:
		return
	if _vignette_pulse_tween:
		_vignette_pulse_tween.kill()
	_vignette_pulse_tween = create_tween()
	_vignette_pulse_tween.tween_method(_set_vignette_pulse, 1.0, 0.0, VIGNETTE_PULSE_TIME)

func _on_player_damaged(_damage_info: DamageInfo) -> void:
	if GameManager.reduce_flashes():
		return
	if _vignette_flash_tween:
		_vignette_flash_tween.kill()
	_vignette_flash_tween = create_tween()
	_vignette_flash_tween.tween_method(_set_vignette_flash, VIGNETTE_FLASH_PEAK, 0.0, VIGNETTE_FLASH_TIME)

## Lights round(ratio * 12) cells (never 0 while Nick is alive). At <= 25 % HP the lit cells,
## the last three to drain, switch to the magenta danger style and the readout turns magenta.
func _update_battery_ui(current: float, max_val: float) -> void:
	var ratio: float = current / max_val if max_val > 0.0 else 0.0
	_set_low_hp(ratio > 0.0 and ratio < LOW_HP_RATIO)
	var lit: int = clampi(roundi(ratio * BATTERY_SEGMENTS), 0, BATTERY_SEGMENTS)
	if current > 0.0:
		lit = maxi(lit, 1)
	var danger: bool = ratio > 0.0 and ratio <= LOW_HP_RATIO
	var cells := battery_segments.get_children()
	for i in cells.size():
		var cell := cells[i] as Control
		if i >= lit:
			cell.theme_type_variation = SEGMENT_EMPTY
		elif danger and i < BATTERY_DANGER_SEGMENTS:
			cell.theme_type_variation = SEGMENT_DANGER
		else:
			cell.theme_type_variation = SEGMENT_LIT
	hp_label.text = "HP %d/%d" % [ceili(maxf(current, 0.0)), ceili(max_val)]
	hp_label.theme_type_variation = NUMERAL_DANGER if danger else NUMERAL

## Number of lit battery cells (any lit style), for tests and probes.
func lit_battery_segments() -> int:
	var count := 0
	for cell in battery_segments.get_children():
		if (cell as Control).theme_type_variation != SEGMENT_EMPTY:
			count += 1
	return count

func _update_shield_ui(current: float, max_val: float) -> void:
	shield_bar.max_value = max_val
	shield_bar.value = current
	shield_bar.visible = current > 0.0 and max_val > 0.0

## One glyph per spare life up to LIVES_GLYPH_MAX, then an "xN" tag. At 0 spare lives the
## glyphs are gone and the magenta "LAST LIFE" tag (the most important state) takes over.
func _update_lives_ui(lives: int) -> void:
	var glyph_index := 0
	for child in lives_row.get_children():
		if child == lives_count_label:
			continue
		(child as CanvasItem).visible = glyph_index < mini(lives, LIVES_GLYPH_MAX)
		glyph_index += 1
	lives_count_label.visible = lives > LIVES_GLYPH_MAX
	if lives_count_label.visible:
		lives_count_label.text = "x%d" % lives
	last_life_label.visible = lives <= 0
	if not last_life_label.visible:
		if last_life_tween:
			last_life_tween.kill()
		last_life_label.modulate.a = 1.0

## U7: the LAST LIFE tag breathes on the primary beat while it is shown.
func _pulse_last_life() -> void:
	if not last_life_label.visible:
		return
	if last_life_tween:
		last_life_tween.kill()
	last_life_label.modulate.a = 1.0
	last_life_tween = create_tween()
	last_life_tween.tween_property(last_life_label, "modulate:a", LAST_LIFE_PULSE_LOW, LAST_LIFE_PULSE_TIME).set_trans(Tween.TRANS_SINE)

func _set_low_hp(low: bool) -> void:
	if low == _low_hp:
		return
	_low_hp = low
	if not low:
		if low_hp_tween:
			low_hp_tween.kill()
		battery_bar.modulate = Color.WHITE

## Subtle per-beat battery pulse white -> magenta -> white while HP is under 25 %.
func _pulse_low_hp() -> void:
	if not _low_hp:
		return
	if low_hp_tween:
		low_hp_tween.kill()
	low_hp_tween = create_tween()
	low_hp_tween.tween_property(battery_bar, "modulate", LOW_HP_MAGENTA, LOW_HP_PULSE_TIME).set_trans(Tween.TRANS_SINE)
	low_hp_tween.tween_property(battery_bar, "modulate", Color.WHITE, LOW_HP_PULSE_TIME).set_trans(Tween.TRANS_SINE)

func _on_beat(layer: String, _beat_index: int) -> void:
	if layer != "primary":
		return

	_pulse_low_hp()
	_pulse_last_life()
	_pulse_vignette()

	if beat_tween:
		beat_tween.kill()
		
	beat_tween = create_tween().set_parallel(true)
	
	# Standard beat pulse: Cyan-green highlight, slight scale up
	beat_pulse_node.scale = Vector2(1.25, 1.25)
	beat_pulse_node.modulate = Color(0.0, 1.0, 0.8, 1.0)
	
	beat_tween.tween_property(beat_pulse_node, "scale", Vector2(1.0, 1.0), 0.25).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	beat_tween.tween_property(beat_pulse_node, "modulate", Color(1.0, 1.0, 1.0, 0.5), 0.25).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)

func _on_downbeat(layer: String, _measure_index: int) -> void:
	if layer != "primary":
		return
		
	if beat_tween:
		beat_tween.kill()
		
	beat_tween = create_tween().set_parallel(true)
	
	# Strong downbeat pulse: Pink-magenta highlight, larger scale up
	beat_pulse_node.scale = Vector2(1.6, 1.6)
	beat_pulse_node.modulate = Color(1.0, 0.0, 0.5, 1.0)
	
	beat_tween.tween_property(beat_pulse_node, "scale", Vector2(1.0, 1.0), 0.35).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	beat_tween.tween_property(beat_pulse_node, "modulate", Color(1.0, 1.0, 1.0, 0.5), 0.35).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)

func _on_combo_increased(current_combo: int) -> void:
	combo_label.text = "x%d" % current_combo
	combo_label.visible = true
	# The cap "glitch" tween leaves modulate white — restore the base cyan on every increase.
	combo_label.modulate = COMBO_CYAN
	combo_label.pivot_offset = combo_label.size / 2.0
	if combo_tween:
		combo_tween.kill()
	combo_tween = create_tween()
	combo_label.scale = Vector2(1.4, 1.4)
	combo_tween.tween_property(combo_label, "scale", Vector2(1.0, 1.0), 0.2).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)

## GDD §6.1: "When maxed out, the multiplier visually glitches and explodes with intense
## neon colors to reward the player." A short cyan/magenta flicker plus an oversized pop,
## settling back into the normal combo-increased look.
func _on_combo_capped() -> void:
	if combo_tween:
		combo_tween.kill()
	combo_tween = create_tween()
	var neon_colors = [Color(0, 0.949, 1, 1), Color(1, 0, 0.667, 1), Color(1, 1, 1, 1)]
	combo_label.scale = Vector2(2.2, 2.2)
	for c in neon_colors:
		combo_tween.tween_property(combo_label, "modulate", c, 0.06)
	combo_tween.tween_property(combo_label, "scale", Vector2(1.4, 1.4), 0.25).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	combo_tween.parallel().tween_property(combo_label, "modulate", Color(1, 1, 1, 1), 0.25)
	SignalBus.camera_shake_requested.emit(0.15, 0.3)

## Q5: the boss moment -- a priority card ("LIVE ON AIR" over the boss name) on the zone
## card, then the boss bar fades in as the card slides out. The hint strip makes room for it.
func _on_boss_spawned(boss_name: String) -> void:
	boss_name_label.text = boss_name.to_upper()
	# The boss reports its shield right after spawning; never inherit the previous fight's.
	boss_shield_strip.visible = false
	zone_title_card.call("show_text", boss_name.to_upper(), boss_card_hold, true, BOSS_EYEBROW)
	hud_hints.set_suppressed(true)
	_kill_boss_bar_tween()
	boss_bar_container.visible = true
	boss_bar_container.modulate.a = 0.0
	_boss_bar_tween = create_tween()
	_boss_bar_tween.tween_interval(float(zone_title_card.call("time_until_slide_out", boss_card_hold)))
	_boss_bar_tween.tween_property(boss_bar_container, "modulate:a", 1.0, BOSS_BAR_FADE_TIME)

func _kill_boss_bar_tween() -> void:
	if _boss_bar_tween:
		_boss_bar_tween.kill()
		_boss_bar_tween = null

func _hide_boss_bar() -> void:
	_kill_boss_bar_tween()
	boss_bar_container.visible = false
	boss_bar_container.modulate.a = 1.0
	boss_shield_strip.visible = false
	hud_hints.set_suppressed(false)

func _on_boss_health_changed(current: int, maximum: int) -> void:
	boss_health_bar.max_value = maximum
	boss_health_bar.value = current

## U5: shield absorbs now read on the boss bar; hidden while the shield is down.
func _on_boss_shield_changed(current: float, max_shield: float) -> void:
	boss_shield_strip.max_value = max_shield
	boss_shield_strip.value = current
	boss_shield_strip.visible = current > 0.0

func _on_boss_died() -> void:
	_hide_boss_bar()

## T3: a checkpoint respawn returned the boss to dormant — clear the bar without any
## victory side effects.
func _on_boss_reset() -> void:
	_hide_boss_bar()

func _on_scrap_changed(new_amount: int) -> void:
	scrap_label.text = "SCRAP  %d" % new_amount

func _on_cells_changed(new_amount: int) -> void:
	cells_label.text = "CELLS  %d" % new_amount

func _on_cores_changed(new_amount: int) -> void:
	cores_label.text = "CORES  %d" % new_amount

func _on_combo_reset() -> void:
	if combo_tween:
		combo_tween.kill()
	combo_tween = create_tween()
	combo_tween.tween_property(combo_label, "modulate:a", 0.0, 0.35).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN)
	combo_tween.tween_callback(func():
		combo_label.visible = false
		combo_label.modulate.a = 1.0
	)
