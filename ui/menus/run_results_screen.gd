extends CanvasLayer
## Run Results (full clear). Q3: the stats are a two-column grid (dim label left, value right in
## Share Tech Mono) fed by GameManager's run stats, plus a rank letter. A demo run gets PLAY
## AGAIN (same loadout) as the focused primary and RETURN TO TITLE second, the NOTHING BANKED
## line and a thank-you line (DEMO_CTA appended once the owner supplies the link).

const FocusGrace = preload("res://ui/menus/focus_grace.gd")
const SceneTransition = preload("res://ui/transition/scene_transition.gd")
const SLICE_SCENE := "res://levels/slice/vertical_slice.tscn"

## Batch O: a demo run returns to the title and banks nothing.
const DEMO_RETURN_TEXT := "RETURN TO TITLE"
const DEMO_THANKS_TEXT := "THANKS FOR PLAYING THE DEMO"
## Owner-supplied call to action (wishlist link etc.), appended to the thanks line when set.
const DEMO_CTA := ""
## The slice's zone count (the "N / 10" in ZONES CLEARED).
const ZONE_COUNT := 10
const ROW_FONT_SIZE := 26
const CYAN := Color(0, 0.949, 1, 1)
const MAGENTA := Color(1, 0, 0.667, 1)
const WHITE := Color(1, 1, 1, 1)
## Rank from the run time: under 6 min S, under 9 A, under 12 B, else C; a run without a lost
## life climbs one tier (capped at S).
const RANKS := ["S", "A", "B", "C"]
const RANK_TIME_LIMITS := [360.0, 540.0, 720.0]

@onready var continue_button: Button = $CenterBox/ContinueButton
@onready var play_again_button: Button = $CenterBox/PlayAgainButton
@onready var demo_label: Label = $CenterBox/DemoLabel
@onready var demo_thanks_label: Label = $CenterBox/DemoThanksLabel
@onready var stats_grid: GridContainer = $CenterBox/StatsGrid
@onready var rank_label: Label = $CenterBox/RankLabel

## Scene-change hook (path) -> void; a seam so tests can observe navigation.
var change_scene: Callable = _change_scene_to

func _ready() -> void:
	continue_button.pressed.connect(FocusGrace.guard(continue_button, _on_continue))
	play_again_button.pressed.connect(FocusGrace.guard(play_again_button, _on_play_again))
	_populate_stats()
	var demo: bool = GameManager.demo_mode
	demo_label.visible = demo
	demo_thanks_label.visible = demo
	demo_thanks_label.text = thanks_text()
	play_again_button.visible = demo
	if demo:
		continue_button.text = DEMO_RETURN_TEXT
		play_again_button.focus_neighbor_bottom = play_again_button.get_path_to(continue_button)
		continue_button.focus_neighbor_top = continue_button.get_path_to(play_again_button)
	# Gamepad navigation: the primary button takes focus once the input grace is over (U2).
	FocusGrace.arm(primary_button(), FocusGrace.END_SCREEN_GRACE)
	if demo:
		FocusGrace.arm(continue_button, FocusGrace.END_SCREEN_GRACE, false)

## PLAY AGAIN in a demo run, otherwise CONTINUE TO SHOP.
func primary_button() -> Button:
	return play_again_button if GameManager.demo_mode else continue_button

static func thanks_text() -> String:
	return DEMO_THANKS_TEXT + ("\n" + DEMO_CTA if DEMO_CTA != "" else "")

## "m:ss" (run_time is seconds).
static func format_time(seconds: float) -> String:
	var total: int = maxi(int(seconds), 0)
	return "%d:%02d" % [int(total / 60.0), total % 60]

## S / A / B / C from the run time, one tier up for a run that lost no life.
static func rank_for(run_time: float, lives_lost: int) -> String:
	var tier: int = RANK_TIME_LIMITS.size()
	for i in RANK_TIME_LIMITS.size():
		if run_time < RANK_TIME_LIMITS[i]:
			tier = i
			break
	if lives_lost == 0:
		tier = maxi(tier - 1, 0)
	return RANKS[tier]

## [label, value, value colour] for every grid row, in order.
func stat_rows() -> Array:
	var gm := GameManager
	return [
		["ZONES CLEARED", "%d / %d" % [gm.zones_cleared, ZONE_COUNT], CYAN],
		["TIME", format_time(gm.run_time), CYAN],
		["MAX COMBO", "x%d" % gm.max_combo, CYAN],
		["LIVES LOST", str(gm.lives_lost), CYAN],
		["SCRAP", str(gm.scrap), CYAN],
		["CELLS", str(gm.cells), MAGENTA],
		["CORES", str(gm.cores), WHITE],
	]

func _populate_stats() -> void:
	for child in stats_grid.get_children():
		stats_grid.remove_child(child)
		child.queue_free()
	for row in stat_rows():
		var key := Label.new()
		key.theme_type_variation = &"DimLabel"
		key.add_theme_font_size_override("font_size", ROW_FONT_SIZE)
		key.text = row[0]
		key.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		stats_grid.add_child(key)
		var value := Label.new()
		value.add_theme_font_size_override("font_size", ROW_FONT_SIZE)
		value.add_theme_color_override("font_color", row[2])
		value.text = row[1]
		value.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
		value.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		stats_grid.add_child(value)
	rank_label.text = "RANK  %s" % rank_for(GameManager.run_time, GameManager.lives_lost)

func _on_continue() -> void:
	change_scene.call(GameManager.post_run_scene())

## Q3: a fresh demo run with the same loadout (GameManager.demo_boosters).
func _on_play_again() -> void:
	GameManager.start_new_run(true)
	change_scene.call(SLICE_SCENE)

func _change_scene_to(path: String) -> void:
	SceneTransition.go(get_tree(), path)
