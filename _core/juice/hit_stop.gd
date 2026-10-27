extends Node

## P6: graded hit-stop. Nick's landed hits freeze by weight (DamageInfo.amount): light
## (< DamageInfo.HEAVY_THRESHOLD), heavy, and finisher (>= FINISHER_THRESHOLD: Tri-Cut 32,
## Launcher 40, Battery Ram 55). A kill (SignalBus.enemy_died) adds its own beat on top
## through the same merge rule. Blocked / shield-absorbed hits never stop (they emit
## hit_blocked, or carry Hurtbox3D.SHIELD_ABSORBED_META on player_hit_landed).
const LIGHT_STOP_DURATION := 0.04
const LIGHT_STOP_SCALE := 0.10
const HEAVY_STOP_DURATION := 0.07
const HEAVY_STOP_SCALE := 0.08
const FINISHER_STOP_DURATION := 0.11
const FINISHER_STOP_SCALE := 0.05
const KILL_STOP_DURATION := 0.12
const KILL_STOP_SCALE := 0.05
const FINISHER_THRESHOLD := 32.0
const KILL_SHAKE_STRENGTH := 0.12
const KILL_SHAKE_DURATION := 0.2

var hit_stop_timer: float = 0.0

func _ready() -> void:
	# J12: keep ticking while the tree is paused -- a pause opened inside a stop would
	# otherwise hold Engine.time_scale at the stop's scale for the whole pause (and stretch
	# every scaled timer, e.g. the Resume grace). _process already works in real time.
	process_mode = Node.PROCESS_MODE_ALWAYS
	SignalBus.player_hit_landed.connect(_on_player_hit_landed)
	SignalBus.hit_stop_requested.connect(start_hit_stop)
	SignalBus.enemy_died.connect(_on_enemy_died)

func _process(delta: float) -> void:
	if hit_stop_timer > 0.0:
		var current_scale = Engine.time_scale
		if current_scale > 0.0:
			var real_delta = delta / current_scale
			hit_stop_timer -= real_delta
			if hit_stop_timer <= 0.0:
				Engine.time_scale = 1.0
				hit_stop_timer = 0.0
		else:
			# Safety fallback if time_scale is somehow 0
			hit_stop_timer = 0.0
			Engine.time_scale = 1.0

func _on_player_hit_landed(damage_info: DamageInfo) -> void:
	if damage_info == null or damage_info.get_meta(Hurtbox3D.SHIELD_ABSORBED_META, false):
		return
	var stop := stop_for_amount(damage_info.amount)
	start_hit_stop(stop.x, stop.y)

## (duration, time_scale) of the stop a landed hit of `amount` damage earns.
static func stop_for_amount(amount: float) -> Vector2:
	if amount >= FINISHER_THRESHOLD:
		return Vector2(FINISHER_STOP_DURATION, FINISHER_STOP_SCALE)
	if amount >= DamageInfo.HEAVY_THRESHOLD:
		return Vector2(HEAVY_STOP_DURATION, HEAVY_STOP_SCALE)
	return Vector2(LIGHT_STOP_DURATION, LIGHT_STOP_SCALE)

## The kill beat: an extra stop merged over the killing hit's own, plus a short shake.
func _on_enemy_died(_position: Vector3) -> void:
	start_hit_stop(KILL_STOP_DURATION, KILL_STOP_SCALE)
	SignalBus.camera_shake_requested.emit(KILL_SHAKE_STRENGTH, KILL_SHAKE_DURATION)

## Overlapping requests (Nick hit while landing a hit) never shorten or weaken a stop that
## is already running: the longer remaining time and the deeper slow-down win. `replace`
## (K11 death beat) overrides a running stop with exactly this one instead.
func start_hit_stop(duration: float, time_scale: float, replace: bool = false) -> void:
	if hit_stop_timer > 0.0 and not replace:
		Engine.time_scale = minf(Engine.time_scale, time_scale)
		hit_stop_timer = maxf(hit_stop_timer, duration)
		return
	Engine.time_scale = time_scale
	hit_stop_timer = duration
