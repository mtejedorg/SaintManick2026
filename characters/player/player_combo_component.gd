extends Node

## GDD §6.1: "Epic Combo Multiplier... When maxed out, the multiplier visually glitches
## and explodes with intense neon colors to reward the player." M11 caps the counter here
## and fires a dedicated celebration signal once, on the frame it hits the cap.
const MAX_COMBO: int = 50

var combo_count: int = 0
var combo_timeout: float = 2.0
var combo_timer: float = 0.0
var has_hit_this_attack: bool = false

func _ready() -> void:
	SignalBus.player_hit_landed.connect(_on_player_hit_landed)
	SignalBus.player_damaged.connect(_on_player_damaged)
	SignalBus.hit_blocked.connect(_on_hit_blocked)

func _process(delta: float) -> void:
	if combo_count > 0:
		combo_timer -= delta
		if combo_timer <= 0.0:
			_drop_combo()

func _on_player_hit_landed(_damage_info: DamageInfo) -> void:
	if combo_count >= MAX_COMBO:
		# Already capped — keep the timer alive but don't re-fire the celebration signal
		# on every subsequent hit. Still a landed hit: without this, the next
		# on_attack_ended() reads the capped attack as a whiff and drops the combo to 0.
		combo_timer = combo_timeout
		has_hit_this_attack = true
		return
	combo_count += 1
	combo_timer = combo_timeout
	has_hit_this_attack = true
	SignalBus.combo_increased.emit(combo_count)
	if combo_count >= MAX_COMBO:
		SignalBus.combo_capped.emit()

## F12: a hit absorbed by a boss shield connected — not a whiff. Keeps the chain alive
## (no increment, no celebration, no meter).
func _on_hit_blocked(_position: Vector3) -> void:
	has_hit_this_attack = true
	if combo_count > 0:
		combo_timer = combo_timeout

## GDD §6.1's "combo counter that grows... without taking damage" — a hit taken drops
## the combo immediately, same as a whiffed attack (_drop_combo below), regardless of
## how the mid-attack whiff detection would otherwise resolve.
func _on_player_damaged(_damage_info: DamageInfo) -> void:
	if combo_count > 0:
		_drop_combo()

func on_attack_started() -> void:
	has_hit_this_attack = false

func on_attack_ended() -> void:
	if not has_hit_this_attack and combo_count > 0:
		_drop_combo()

func _drop_combo() -> void:
	combo_count = 0
	combo_timer = 0.0
	SignalBus.combo_dropped.emit()
	SignalBus.combo_reset.emit()
