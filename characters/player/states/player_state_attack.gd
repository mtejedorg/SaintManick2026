extends PlayerState

## Route data lives in ComboDef resources (characters/player/combos/*.tres) — no magic
## numbers here. Keyed by their input_chain joined into a string ("AAA", "AAB", "ABB", "BB")
## so a full-chain match can look itself up directly.
const COMBO_RESOURCE_PATHS: Array[String] = [
	"res://characters/player/combos/combo_tri_cut.tres",
	"res://characters/player/combos/combo_launcher.tres",
	"res://characters/player/combos/combo_sweeper.tres",
	"res://characters/player/combos/combo_battery_ram.tres",
]

static var _combo_defs_by_chain: Dictionary = {}

## EMP Dash-Cancel (M5b): a partial spender. During the recovery portion of an attack
## (the tail end of attack_timer, after the hitbox's active window), a dash input consumes
## 25 meter and cancels straight into StateDash, skipping the remaining recovery frames.
const EMP_DASH_CANCEL_COST: float = 25.0
## Fraction of the current hit's total duration considered "active" (hitbox live). The
## remainder is recovery, during which the EMP Dash-Cancel window is open.
const ACTIVE_WINDOW_FRACTION: float = 0.6

var attack_timer: float = 0.0
var current_hit_duration: float = 0.0
var combo_step: int = 0
var max_combo_step: int = 2
var attack_durations: Array[float] = [0.3, 0.3, 0.6]
const COMBO_WINDOW: float = 0.15

# Presses landed before the combo window opens are buffered and consumed when
# it does — mashing chains combos instead of whiffing between windows.
var buffered_attack: bool = false
var buffered_heavy: bool = false
var current_sequence: Array[String] = []

func _ensure_combo_defs_loaded() -> void:
	if not _combo_defs_by_chain.is_empty():
		return
	for path in COMBO_RESOURCE_PATHS:
		var def: ComboDef = load(path)
		if def:
			_combo_defs_by_chain["".join(def.input_chain)] = def

func enter() -> void:
	_ensure_combo_defs_loaded()
	combo_step = 0
	current_sequence.clear()
	buffered_attack = false
	buffered_heavy = false
	if player.combo_component:
		player.combo_component.on_attack_started()
	var is_heavy = Input.is_action_just_pressed("attack_heavy")
	_start_attack(is_heavy)

func _start_attack(is_heavy: bool) -> void:
	# Heavy is a free basic input (GDD §3.2/§3.3) — the Ability Bar is a reward meter,
	# never a cost gate on basic attacks. try_consume_ability_meter() stays available
	# for the real spenders (EMP Dash-Cancel, Bass Drop).
	current_sequence.append("B" if is_heavy else "A")

	var seq = "".join(current_sequence)
	var combo_def: ComboDef = _combo_defs_by_chain.get(seq)

	attack_timer = combo_def.duration if combo_def else attack_durations[combo_step]
	current_hit_duration = attack_timer

	# Widen hitbox per-route (Sweeper's ComboDef carries a wider hitbox_scale).
	player.katana_hitbox.scale = combo_def.hitbox_scale if combo_def else Vector3.ONE

	player.velocity.x = 0
	player.velocity.z = 0

	if player.animation_controller:
		var anim = "attack_light"
		if is_heavy:
			anim = "attack_heavy"
		elif combo_step > 0:
			anim = "attack_combo"
		player.animation_controller.play_once(anim)

	if not player.katana_hitbox.damage_info:
		player.katana_hitbox.damage_info = DamageInfo.new()

	if combo_def:
		# Full route matched (Tri-Cut/Launcher/Sweeper/Battery Ram) — route data wins.
		player.katana_hitbox.damage_info.amount = combo_def.damage
		player.katana_hitbox.damage_info.knockback = combo_def.knockback
		player.katana_hitbox.damage_info.stun = combo_def.stun_time
		player.katana_hitbox.damage_info.is_launcher = combo_def.is_launcher
		player.katana_hitbox.damage_info.is_guard_breaking = combo_def.is_guard_breaking
		player.katana_hitbox.damage_info.is_shield_breaker = is_heavy
	else:
		# Unmatched/generic hit (mashing) — plain light/heavy basic-input values.
		player.katana_hitbox.damage_info.amount = 28.0 if is_heavy else 12.0
		player.katana_hitbox.damage_info.is_shield_breaker = is_heavy
		player.katana_hitbox.damage_info.knockback = 8.0 if is_heavy else 4.0
		player.katana_hitbox.damage_info.stun = 0.4 if is_heavy else 0.25
		player.katana_hitbox.damage_info.is_launcher = is_heavy
		player.katana_hitbox.damage_info.is_guard_breaking = false

	player.katana_hitbox.damage_info.source = player
	player.katana_hitbox.is_active = true

func exit() -> void:
	player.katana_hitbox.is_active = false
	if player.combo_component:
		player.combo_component.on_attack_ended()

## Consumes the EMP Dash-Cancel cost and transitions straight to StateDash, cancelling
## the remaining recovery frames. Returns false (no-op) if the player doesn't have
## enough meter. Exposed as its own method so it can be exercised directly in tests
## without depending on Input singleton event timing.
func _try_emp_dash_cancel() -> bool:
	if not player.try_consume_ability_meter(EMP_DASH_CANCEL_COST):
		return false
	transition_requested.emit("StateDash")
	return true


func physics_update(delta: float) -> void:
	player.apply_gravity(delta)
	player.move_and_slide()

	attack_timer -= delta

	# Recovery: the tail end of the hit, after its active window closes. The hitbox
	# switches off and the EMP Dash-Cancel window opens.
	var active_window_end = current_hit_duration * (1.0 - ACTIVE_WINDOW_FRACTION)
	var in_recovery = attack_timer <= active_window_end
	if in_recovery and player.katana_hitbox.is_active:
		player.katana_hitbox.is_active = false

	if in_recovery and Input.is_action_just_pressed("dash"):
		if _try_emp_dash_cancel():
			return

	# Buffer any press during the attack; consume it once the window opens.
	if Input.is_action_just_pressed("attack_light") or Input.is_action_just_pressed("attack_heavy"):
		buffered_attack = true
		buffered_heavy = Input.is_action_just_pressed("attack_heavy")

	if buffered_attack and combo_step < max_combo_step and attack_timer < COMBO_WINDOW:
		combo_step += 1
		var is_heavy = buffered_heavy
		buffered_attack = false
		buffered_heavy = false
		_start_attack(is_heavy)
		return

	if attack_timer <= 0:
		player.katana_hitbox.is_active = false
		if not player.is_on_floor():
			transition_requested.emit("StateAirborne")
		else:
			transition_requested.emit("StateIdle")
