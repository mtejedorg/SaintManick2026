class_name PlayerTuning
extends Resource

## Q2: Nick's combat/movement tuning as data (no magic numbers in the controller or its
## states). The shipped values live in player_tuning.tres, assigned by player.tscn; GDD
## rev. 3 mirrors them (where the two disagree, the .tres wins). First-pass numbers come
## from Documents/tools/balance_tool.html.

@export_group("Dodge")
## Dash burst speed (m/s) over StateDash.dash_duration (GDD §3.2: 18 m/s, ~4.5 m).
@export var dash_speed: float = 18.0
## K4 (D14): roll speed (m/s); ~7.2 m over the 0.65 s roll.
@export var roll_speed: float = 11.0
## T1/K3 (D6): the shared dash/roll cooldown (s), started when a dodge state exits.
@export var dodge_cooldown: float = 0.3
## Reward-only beat alignment window (s, either side of a primary beat edge; GDD §3.3).
@export var beat_align_window: float = 0.06
## K3 (D6): share of dodge_cooldown an on-beat dodge refunds (0.5 = half).
@export_range(0.0, 1.0) var beat_aligned_cooldown_refund: float = 0.5

@export_group("Attack")
## Generic (unmatched) light hit windows (s), first / second / third hit.
@export var attack_durations: Array[float] = [0.3, 0.3, 0.6]
## K1 (D3): generic heavy hit windows (s) -- slower, so the named routes out-damage mashing.
@export var heavy_attack_durations: Array[float] = [0.45, 0.45, 0.75]
## K2 (D22): the free dodge cancel opens in the last this-much of a hit's recovery.
@export_range(0.0, 1.0) var free_cancel_recovery_fraction: float = 0.4
## Q4: step-in speed (m/s) toward the facing at the start of hit 1 / 2 / 3 of a chain, so
## the opener's knockback cannot carry the target out of the finisher's reach.
@export var attack_step_in: Array[float] = [3.0, 3.0, 4.0]
## Q4: how long (s) each hit's step-in lasts.
@export var attack_step_in_seconds: float = 0.1

@export_group("Bass Drop")
## K6 (D8): Bass Drop radius (m) and damage.
@export var bass_drop_radius: float = 10.0
@export var bass_drop_damage: float = 90.0

@export_group("Death and falls")
## K11 (D20): the death beat (s) before the respawn / game over. GameManager reads it
## through PlayerController.death_beat_seconds() when it can; its own const is the fallback.
@export var death_beat_seconds: float = 0.9
## J4: HP a fall out of the world costs, and the grace (s) after a survivable one.
@export var fall_damage: float = 20.0
@export var fall_grace: float = 0.5

## push_errors every out-of-range value; true when the resource is sane.
func validate() -> bool:
	var ok := true
	for check in [
		["dash_speed", dash_speed > 0.0],
		["roll_speed", roll_speed > 0.0],
		["dodge_cooldown", dodge_cooldown >= 0.0],
		["beat_align_window", beat_align_window >= 0.0 and beat_align_window < 0.25],
		["beat_aligned_cooldown_refund", beat_aligned_cooldown_refund >= 0.0 and beat_aligned_cooldown_refund <= 1.0],
		["attack_durations", _positive_windows(attack_durations)],
		["heavy_attack_durations", _positive_windows(heavy_attack_durations)],
		["free_cancel_recovery_fraction", free_cancel_recovery_fraction >= 0.0 and free_cancel_recovery_fraction <= 1.0],
		["attack_step_in", attack_step_in.size() == attack_durations.size() and attack_step_in.all(func(v: float): return v >= 0.0)],
		["attack_step_in_seconds", attack_step_in_seconds >= 0.0 and attack_step_in_seconds <= attack_durations.min()],
		["bass_drop_radius", bass_drop_radius > 0.0],
		["bass_drop_damage", bass_drop_damage >= 0.0],
		["death_beat_seconds", death_beat_seconds >= 0.0],
		["fall_damage", fall_damage >= 0.0],
		["fall_grace", fall_grace >= 0.0],
	]:
		if not check[1]:
			push_error("PlayerTuning %s: %s is out of range." % [resource_path, check[0]])
			ok = false
	return ok

## One window per chain hit (three), every one longer than zero.
static func _positive_windows(windows: Array[float]) -> bool:
	return windows.size() == 3 and windows.all(func(v: float): return v > 0.0)
