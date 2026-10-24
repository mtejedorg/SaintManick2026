extends CanvasLayer

@onready var battery_rect: TextureRect = $MarginContainer/VBoxContainer/StatusContainer/BatteryContainer/BatteryRect
## GAP-8 fix (M12): the shield is now an overlaid TextureProgressBar directly on top of
## the battery (GDD §6.1: "regenerating shield shown as an overlaid layer on top"), not a
## separate slot using the stamina textures — the Ability Bar owns that slot now.
@onready var shield_bar: TextureProgressBar = $MarginContainer/VBoxContainer/StatusContainer/BatteryContainer/ShieldBar
@onready var lives_rect: TextureRect = $MarginContainer/VBoxContainer/LowerRow/LivesBox/LivesRect
## Magenta "LAST LIFE" tag under the lives icon, shown when no spare lives remain.
@onready var last_life_label: Label = $MarginContainer/VBoxContainer/LowerRow/LivesBox/LastLifeLabel
@onready var zone_title_card: Control = $ZoneTitleCard
@onready var beat_pulse_node: Control = $BeatPulse
@onready var combo_label: Label = $ComboLabel
@onready var boss_bar_container: PanelContainer = $BossBarContainer
@onready var boss_name_label: Label = $BossBarContainer/BossBarVBox/BossNameLabel
@onready var boss_health_bar: ProgressBar = $BossBarContainer/BossBarVBox/BossHealthBar

@onready var scrap_label: Label = $ScrapLabel
@onready var cells_label: Label = $CellsLabel
@onready var cores_label: Label = $CoresLabel

## Cropped HUD art (res://ui/hud/art/). Loaded through ResourceLoader — FileAccess.file_exists
## on a res:// png is false in exported builds (only the imported .ctex ships).
const ART_DIR := "res://ui/hud/art/"
const COMBO_CYAN := Color(0.0, 0.961, 1.0, 1.0)
## Below this fraction of max HP the battery pulses magenta on every beat.
const LOW_HP_RATIO := 0.25
const LOW_HP_MAGENTA := Color(1.0, 0.0, 0.667, 1.0)
const LOW_HP_PULSE_TIME := 0.15
## How long the "LIFE LOST — N LEFT" banner rests on screen.
const LIFE_LOST_HOLD := 1.2

var beat_tween: Tween
var combo_tween: Tween
var low_hp_tween: Tween
var _low_hp: bool = false

func _ready() -> void:
	# Subscriptions
	SignalBus.player_health_changed.connect(_on_player_health_changed)
	SignalBus.player_shield_changed.connect(_on_player_shield_changed)
	GameManager.lives_changed.connect(_on_lives_changed)
	SignalBus.player_life_lost.connect(_on_player_life_lost)
	SignalBus.beat.connect(_on_beat)
	SignalBus.downbeat.connect(_on_downbeat)
	SignalBus.combo_increased.connect(_on_combo_increased)
	SignalBus.combo_reset.connect(_on_combo_reset)
	SignalBus.combo_capped.connect(_on_combo_capped)
	SignalBus.boss_spawned.connect(_on_boss_spawned)
	SignalBus.boss_health_changed.connect(_on_boss_health_changed)
	SignalBus.boss_died.connect(_on_boss_died)
	SignalBus.boss_reset.connect(_on_boss_reset)
	GameManager.scrap_changed.connect(_on_scrap_changed)
	GameManager.cells_changed.connect(_on_cells_changed)
	GameManager.cores_changed.connect(_on_cores_changed)

	# Initial UI Setup
	_setup_textures()
	_update_battery_ui(GameManager.current_hp, GameManager.max_hp)
	_update_shield_ui(GameManager.current_shield, GameManager.max_shield)
	_update_lives_ui(GameManager.current_lives)
	scrap_label.text = "SCRAP  %d" % GameManager.scrap
	cells_label.text = "CELLS  %d" % GameManager.cells
	cores_label.text = "CORES  %d" % GameManager.cores
	
	# Set pivot offset for beat pulse center pulsing
	beat_pulse_node.pivot_offset = beat_pulse_node.size / 2.0
	beat_pulse_node.modulate = Color(1.0, 1.0, 1.0, 0.5)

func _setup_textures() -> void:
	# The shield is a thin 6 px strip along the TOP edge of the battery (same 265 px width),
	# so it never hides the battery art. Flat white fill, tinted cyan by the node's modulate.
	var flat_fill = GradientTexture2D.new()
	var gradient = Gradient.new()
	gradient.set_color(0, Color(1, 1, 1, 1))
	gradient.set_color(1, Color(1, 1, 1, 1))
	flat_fill.gradient = gradient
	flat_fill.width = 265
	flat_fill.height = 6
	shield_bar.fill_mode = TextureProgressBar.FILL_LEFT_TO_RIGHT
	shield_bar.texture_progress = flat_fill

func _on_player_health_changed(new_health: float, max_health: float) -> void:
	_update_battery_ui(new_health, max_health)

func _on_player_shield_changed(new_shield: float, max_shield: float) -> void:
	_update_shield_ui(new_shield, max_shield)

func _on_lives_changed(new_amount: int) -> void:
	_update_lives_ui(new_amount)

## A life was spent. With lives left, reuse the zone card as a short banner; the terminal
## (0 lives) emission is the game-over path and is handled by the game-over screen.
func _on_player_life_lost(current_lives: int) -> void:
	if current_lives > 0:
		zone_title_card.call("show_text", "LIFE LOST — %d LEFT" % current_lives, LIFE_LOST_HOLD)

func _update_battery_ui(current: float, max_val: float) -> void:
	var ratio = current / max_val if max_val > 0.0 else 0.0
	_set_low_hp(ratio > 0.0 and ratio < LOW_HP_RATIO)
	var segments = clamp(round(ratio * 12.0), 0, 12)
	
	var path := ""
	if segments == 0:
		path = _get_battery_empty_path()
	elif segments == 12:
		path = _get_battery_full_path()
	else:
		path = _get_battery_texture_path(int(segments))

	if ResourceLoader.exists(path):
		battery_rect.texture = load(path)

func _update_shield_ui(current: float, max_val: float) -> void:
	shield_bar.max_value = max_val
	shield_bar.value = current

## The icon stays visible at 0 spare lives (the last-life state is the most important one to
## see); a magenta "LAST LIFE" tag appears under it.
func _update_lives_ui(lives: int) -> void:
	lives_rect.visible = true
	var path: String = _get_lives_path(clampi(lives, 1, 4))
	if ResourceLoader.exists(path):
		lives_rect.texture = load(path)
	last_life_label.visible = lives <= 0

func _set_low_hp(low: bool) -> void:
	if low == _low_hp:
		return
	_low_hp = low
	if not low:
		if low_hp_tween:
			low_hp_tween.kill()
		battery_rect.modulate = Color.WHITE

## Subtle per-beat battery pulse white -> magenta -> white while HP is under 25 %.
func _pulse_low_hp() -> void:
	if not _low_hp:
		return
	if low_hp_tween:
		low_hp_tween.kill()
	low_hp_tween = create_tween()
	low_hp_tween.tween_property(battery_rect, "modulate", LOW_HP_MAGENTA, LOW_HP_PULSE_TIME).set_trans(Tween.TRANS_SINE)
	low_hp_tween.tween_property(battery_rect, "modulate", Color.WHITE, LOW_HP_PULSE_TIME).set_trans(Tween.TRANS_SINE)

func _on_beat(layer: String, _beat_index: int) -> void:
	if layer != "primary":
		return

	_pulse_low_hp()

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

func _on_boss_spawned(boss_name: String) -> void:
	boss_name_label.text = boss_name.to_upper()
	boss_bar_container.visible = true

func _on_boss_health_changed(current: int, maximum: int) -> void:
	boss_health_bar.max_value = maximum
	boss_health_bar.value = current

func _on_boss_died() -> void:
	boss_bar_container.visible = false

## T3: a checkpoint respawn returned the boss to dormant — clear the bar without any
## victory side effects.
func _on_boss_reset() -> void:
	boss_bar_container.visible = false

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

# Art path helpers (ASCII-named, cropped copies in res://ui/hud/art/)
func _get_battery_texture_path(index: int) -> String:
	return ART_DIR + "battery_%02d.png" % index

func _get_battery_full_path() -> String:
	return ART_DIR + "battery_full.png"

func _get_battery_empty_path() -> String:
	return ART_DIR + "battery_empty.png"

func _get_lives_path(count: int) -> String:
	return ART_DIR + "lives_%d.png" % count
