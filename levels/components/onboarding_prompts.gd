class_name OnboardingPrompts
extends Node

## Gameplay hint cards through SignalBus.banner_requested (the zone title card channel).
## Q6: the three Zone 1 control cards are gone -- the HUD's action-gated hint strip
## (ui/hud/hud_hints.gd) teaches the controls and owns PlayerProfile.seen_controls. What stays:
## - two once-per-run cards (J5): TOP-DOWN `top_down_delay` s after the first camera shift into
##   top-down has landed, and BASS DROP READY the first time the meter is full;
## - one-shot hints, shown once ever (PlayerProfile.seen_hints bitmask via GameManager; a demo
##   run keeps them in memory only and never saves): the first blocked hit (SHIELDED), the first
##   combo reaching CHAIN_HINT_COMBO (TRI-CUT), and -- only if SignalBus has it -- the first
##   enemy_telegraphed (WHITE RIM).

## Seconds after the first top-down camera_shift_finished(true) before the top-down card.
@export var top_down_delay: float = 1.5
## Hold of each card (slide-in 0.4 + hold + slide-out 0.4).
@export var hold: float = 1.6

const TOP_DOWN_PROMPT := "TOP-DOWN  W/A/S/D MOVE IN DEPTH · JUMP OFFLINE"
const BASS_DROP_PROMPT := "BASS DROP READY  L / LB"
const SHIELD_HINT := "SHIELDED — HEAVY HEAVY (K K) BREAKS THE GUARD"
const CHAIN_HINT := "CHAIN J J J = TRI-CUT"
const TELEGRAPH_HINT := "WHITE RIM = HIT INCOMING — DODGE"
## PlayerProfile.seen_hints bits.
const HINT_SHIELD := 1
const HINT_CHAIN := 2
const HINT_TELEGRAPH := 4
## The combo count whose first arrival shows the TRI-CUT hint.
const CHAIN_HINT_COMBO := 3
## The telegraph signal another batch adds to SignalBus; connected only if it exists.
const TELEGRAPH_SIGNAL := &"enemy_telegraphed"

## Bumped on reset / life lost: a pending card only fires if its token is still current.
var _token: int = 0
## One-shot extra cards: 0 = not yet, 1 = pending (top-down only), 2 = shown.
var _top_down_card: int = 0
var _bass_drop_shown: bool = false

func _ready() -> void:
	SignalBus.run_started.connect(_on_run_started)
	SignalBus.player_life_lost.connect(_on_player_life_lost)
	SignalBus.camera_shift_finished.connect(_on_camera_shift_finished)
	SignalBus.ability_meter_changed.connect(_on_ability_meter_changed)
	SignalBus.hit_blocked.connect(_on_hit_blocked)
	SignalBus.combo_increased.connect(_on_combo_increased)
	if SignalBus.has_signal(TELEGRAPH_SIGNAL):
		SignalBus.connect(TELEGRAPH_SIGNAL, _on_enemy_telegraphed)

func _on_run_started() -> void:
	_token += 1
	_top_down_card = 0
	_bass_drop_shown = false

func _on_player_life_lost(_lives: int) -> void:
	_token += 1
	if _top_down_card == 1:
		_top_down_card = 0 # dropped before it showed: the next landed shift plays it

func _on_camera_shift_finished(top_down: bool) -> void:
	if not top_down or _top_down_card != 0:
		return
	_top_down_card = 1
	var token := _token
	if top_down_delay <= 0.0:
		_show_top_down(token)
		return
	get_tree().create_timer(top_down_delay, false).timeout.connect(_show_top_down.bind(token))

func _show_top_down(token: int) -> void:
	if token != _token or _top_down_card != 1 or not is_inside_tree():
		return
	_top_down_card = 2
	SignalBus.banner_requested.emit(TOP_DOWN_PROMPT, hold)

func _on_ability_meter_changed(current: float, max_meter: float) -> void:
	if _bass_drop_shown or max_meter <= 0.0 or current < max_meter:
		return
	_bass_drop_shown = true
	SignalBus.banner_requested.emit(BASS_DROP_PROMPT, hold)

func _on_hit_blocked(_position: Vector3) -> void:
	_show_hint(HINT_SHIELD, SHIELD_HINT)

func _on_combo_increased(current_combo: int) -> void:
	if current_combo >= CHAIN_HINT_COMBO:
		_show_hint(HINT_CHAIN, CHAIN_HINT)

## Signature-agnostic: whatever enemy_telegraphed carries, the first one shows the hint.
func _on_enemy_telegraphed(_a = null, _b = null, _c = null) -> void:
	_show_hint(HINT_TELEGRAPH, TELEGRAPH_HINT)

## Shows a one-shot hint unless its bit is already seen (profile or this demo session).
func _show_hint(bit: int, text: String) -> void:
	if GameManager.hint_seen(bit):
		return
	GameManager.mark_hint_seen(bit)
	SignalBus.banner_requested.emit(text, hold)
