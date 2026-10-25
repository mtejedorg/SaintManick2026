class_name PlayerController
extends CharacterBody3D

@export var max_speed: float = 8.0
@export var acceleration: float = 40.0
@export var friction: float = 60.0
@export var jump_force: float = 18.0
@export var gravity_multiplier: float = 3.0
@export var dash_speed: float = 18.0
@export var roll_speed: float = 18.0

## T1: shared dash/roll cooldown, started when a dodge state EXITS. Prevents chaining
## dash->roll->dash into permanent i-frames (the defense economy the GDD's "read the
## heartbeat" pillar depends on). The EMP Dash-Cancel bypasses the can_dodge() check
## (it transitions straight from StateAttack, never through Idle/Run) but still starts
## this cooldown on its own StateDash exit.
@export var dodge_cooldown: float = 0.5
## Reward-only beat alignment window (GDD §3.3): a dash/roll started within this many
## seconds of a primary-layer beat edge refunds its cooldown and grants ability meter.
## Never a gate — the player is never beat-validated, only ever rewarded.
@export var beat_align_window: float = 0.12
@export var beat_aligned_dodge_meter: float = 4.0
var _dodge_cooldown_timer: float = 0.0

## F10 input forgiveness. Coyote time: a ground jump is still allowed this long after
## walking off a ledge. Jump buffer: a jump pressed this long before landing fires on
## landing. Dodge buffer: a dash/roll pressed during attack recovery or the dodge cooldown
## fires as soon as it is allowed, if within this window.
@export var coyote_time: float = 0.10
@export var jump_buffer_time: float = 0.12
@export var dodge_buffer_time: float = 0.15
var _coyote_timer: float = 0.0
var _jump_buffer_timer: float = 0.0
var _dodge_buffer_timer: float = 0.0
## The dodge state the buffered press asks for ("StateDash"/"StateRoll"; "" = none).
var _buffered_dodge_state: String = ""
## H3: attack latching. A light/heavy press is held this long so one pressed during a
## dash/roll, in the air or in the last combo hit recovery fires as soon as it can.
@export var attack_buffer_time: float = 0.15
var _attack_buffer_timer: float = 0.0
var _buffered_attack_heavy: bool = false
## H3: light (false) / heavy (true) for the NEXT StateAttack.enter(). Set by
## take_buffered_attack() right before the transition, read (and reset) by the state.
var pending_attack_heavy: bool = false
## I1: the stunning hit the NEXT StateHurt.enter() applies (knockback + stagger length).
## Set by _enter_hurt() right before the transition, read (and reset) by the state.
var pending_hurt: DamageInfo = null

## The rail Nick is plane-locked to (null = free top-down movement). Switching to a new
## rail eases him onto it over rail_blend_time instead of hard-snapping in one frame (the
## Zone 7 -> 8 hand-off alone is up to 25 m).
@export var current_path: Path3D:
	set(value):
		if value != null and value != current_path:
			_rail_blend = 0.0
		current_path = value
## Seconds to ease onto a newly assigned rail.
@export var rail_blend_time: float = 0.3
## 0 -> 1 progress of the ease onto the current rail; 1 = locked (snap every frame).
var _rail_blend: float = 1.0

## Y below which the player is considered to have fallen out of the world. Below every
## legitimate floor in the slice (lowest arena floor ~ -4.5); the elevator rises well above 0.
const FALL_KILL_Y: float = -15.0
## F14: floors that must never become the fall-return point (the Zone 8 collapsing
## platform drops away — returning Nick over the void would chain fall damage).
const UNSAFE_FLOOR_GROUP := &"unsafe_floor"
## HP cost paid when falling out of the world (shield absorbs first, per the universal rule).
@export var fall_damage: float = 20.0
## J4: the fall cue and the short grace after a survivable fall (the life-loss respawn
## grants its own, longer one).
const FALL_GRACE := 0.5
const FALL_BANNER := "SIGNAL LOST  -%d HP"
const FALL_BANNER_HOLD := 1.0
## J3: a zero-stun hit's flinch -- hit_react (0.77 s) fitted to this, resting states only.
const FLINCH_SECONDS := 0.22

var can_double_jump: bool = true
var double_jump_unlocked: bool = false
var is_facing_right: bool = true
var is_jump_enabled: bool = true
var ability_meter: float = 0.0
const MAX_ABILITY_METER: float = 100.0

## GDD §3.3: the bar charges by landing combo hits (~+4% per light hit, +9% per heavy
## hit) — classified via DamageInfo.HEAVY_THRESHOLD, NOT a raw damage*scale formula, so
## fill rates stay tunable independent of combo damage balancing.
@export var meter_per_light_hit: float = 4.0
@export var meter_per_heavy_hit: float = 9.0
## Seconds of no landed hits before out-of-combat decay kicks in (mirrors the combo
## component's 2s out-of-combat timeout notion).
@export var meter_decay_delay: float = 2.0
## Meter drained per second once decay starts, encouraging aggression.
@export var meter_decay_rate: float = 5.0
var _meter_decay_timer: float = 0.0
## Last grounded position; a fall returns Nick here instead of reloading the level.
var last_safe_position: Vector3 = Vector3.ZERO

## Bass Drop (M5b, GDD §3.3 full-bar ultimate): a screen-clearing AoE that detonates on
## the next downbeat once armed. Meter must be completely full to arm; input action is
## a temporary binding (see signal_bus.gd _register_input) until M9 lands a real input map.
@export var bass_drop_radius: float = 6.0
@export var bass_drop_damage: float = 60.0
@export var bass_drop_knockback: float = 16.0
@export var bass_drop_stun: float = 1.0
var bass_drop_armed: bool = false

## F6: damage feedback — a short hit-stop, a camera shake and a white-hot rim flash on any
## HP or shield loss.
const DAMAGE_HIT_STOP_DURATION := 0.06
const DAMAGE_HIT_STOP_SCALE := 0.05
const DAMAGE_SHAKE_STRENGTH := 0.15
const DAMAGE_SHAKE_DURATION := 0.2
const DAMAGE_FLASH_STRENGTH := 6.0
const DAMAGE_FLASH_SECONDS := 0.15
## F6: rim while invincible (dash/roll i-frames, respawn grace): pale cyan, dimmed.
const INVINCIBLE_RIM_COLOR := Color(0.6, 1.0, 1.0)
const INVINCIBLE_RIM_STRENGTH := 2.0
## F6: below this HP fraction the rim pulses toward magenta on every primary beat.
const LOW_HP_FRACTION := 0.25
const LOW_HP_PULSE_COLOR := Color(1.0, 0.0, 0.666667)
const LOW_HP_PULSE_STRENGTH := 4.0
const LOW_HP_PULSE_SECONDS := 0.25
## F9: Bass Drop cue — rim held white-hot while armed; detonation hit-stop and a magenta
## shock ring that grows from RING_START_SCALE to bass_drop_radius at Nick's feet.
const BASS_DROP_ARMED_RIM_STRENGTH := 5.0
const BASS_DROP_HIT_STOP_DURATION := 0.12
const BASS_DROP_HIT_STOP_SCALE := 0.05
const BASS_DROP_RING_COLOR := Color(1.0, 0.0, 0.666667)
const BASS_DROP_RING_START_SCALE := 0.5
const BASS_DROP_RING_SECONDS := 0.3
## Capsule half-height: Nick's origin is the capsule centre, his feet are this far below.
const FEET_OFFSET := 1.0

@onready var state_machine: Node = $StateMachine
@onready var mesh: MeshInstance3D = $MeshInstance3D
@onready var katana_hitbox: Area3D = $MeshInstance3D/KatanaHitbox
@onready var bionic_arm_hitbox: Area3D = $MeshInstance3D/BionicArmHitbox
@onready var health_component: HealthComponent = $HealthComponent
@onready var animation_controller: PlayerAnimationController = $PlayerAnimationController
@onready var character_visual: CharacterVisual = get_node_or_null("MeshInstance3D/CharacterVisual")
var combo_component: Node = null
## Which resting rim is applied right now ("" = not yet resolved) — see _update_rest_rim().
var _rest_rim_key: String = ""

func _ready() -> void:
	# Lookup handle for systems outside the slice root (e.g. ElevatorEncounter's checkpoint).
	add_to_group("player")
	var sm = get_node_or_null("/root/SaveManager")
	if sm and sm.profile:
		double_jump_unlocked = sm.profile.double_jump_unlocked
	can_double_jump = double_jump_unlocked
	var combo_script = load("res://characters/player/player_combo_component.gd")
	if combo_script:
		combo_component = combo_script.new()
		combo_component.name = "PlayerComboComponent"
		add_child(combo_component)
	health_component.is_player = true
	# Face right from frame 1 (is_facing_right starts true): the visual's authored yaw is 0
	# (+Z, toward the camera), so an attack before the first move used to swing at the lens.
	mesh.rotation.y = PI / 2.0

	var gm = get_node_or_null("/root/GameManager")
	if gm:
		health_component.max_health = gm.max_hp
		health_component.current_health = gm.current_hp
		health_component.max_shield = gm.max_shield
		health_component.current_shield = gm.current_shield
	health_component.died.connect(_on_died)
	health_component.damaged.connect(_on_damaged)
	SignalBus.player_hit_landed.connect(_on_player_hit_landed)
	SignalBus.downbeat.connect(_on_downbeat)
	SignalBus.beat.connect(_on_beat)
	SignalBus.player_respawned.connect(_on_player_respawned)
	last_safe_position = global_position

	# Apply run booster speed multiplier if GameManager set one
	if gm and gm.run_speed_multiplier != 1.0:
		max_speed *= gm.run_speed_multiplier
		
	# Delay emitting the initial ability meter slightly so HUD is ready
	call_deferred("_emit_initial_ability_meter")

func _emit_initial_ability_meter() -> void:
	SignalBus.ability_meter_changed.emit(ability_meter, MAX_ABILITY_METER)

func _on_player_hit_landed(dmg_info: DamageInfo) -> void:
	if dmg_info.source == self and not dmg_info.is_ability_hit:
		var is_heavy_hit = dmg_info.amount >= DamageInfo.HEAVY_THRESHOLD
		add_ability_meter(meter_per_heavy_hit if is_heavy_hit else meter_per_light_hit)
		_meter_decay_timer = meter_decay_delay

func add_ability_meter(amount: float) -> void:
	ability_meter = clamp(ability_meter + amount, 0.0, MAX_ABILITY_METER)
	SignalBus.ability_meter_changed.emit(ability_meter, MAX_ABILITY_METER)

func can_dodge() -> bool:
	return _dodge_cooldown_timer <= 0.0

func start_dodge_cooldown() -> void:
	_dodge_cooldown_timer = dodge_cooldown

## Reward-only: if a dash/roll begins within beat_align_window of a primary-layer beat
## edge, grant ability meter and tell the caller so it can skip starting the cooldown.
## Returns false (no reward, no side effects) if the Conductor isn't available (tests
## that build a bare player without the autoload tree still work).
func try_beat_aligned_dodge_reward() -> bool:
	var conductor = get_node_or_null("/root/Conductor")
	if not conductor:
		return false
	if conductor.seconds_to_nearest_beat("primary") <= beat_align_window:
		add_ability_meter(beat_aligned_dodge_meter)
		return true
	return false

func _process(delta: float) -> void:
	_update_rest_rim()
	if _dodge_cooldown_timer > 0.0:
		_dodge_cooldown_timer -= delta
	if ability_meter <= 0.0:
		return
	if _meter_decay_timer > 0.0:
		_meter_decay_timer -= delta
		if _meter_decay_timer > 0.0:
			return
		# The delay boundary fell inside this frame (large delta / low framerate) — only
		# decay for the leftover time past the boundary, not the whole frame.
		var overshoot = -_meter_decay_timer
		_meter_decay_timer = 0.0
		if overshoot <= 0.0:
			return
		delta = overshoot
	# Out of combat: slowly drain the bar to encourage aggression (GDD §3.3).
	add_ability_meter(-meter_decay_rate * delta)

func try_consume_ability_meter(amount: float) -> bool:
	if ability_meter >= amount:
		ability_meter -= amount
		SignalBus.ability_meter_changed.emit(ability_meter, MAX_ABILITY_METER)
		return true
	return false

func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed("ability_ultimate"):
		try_arm_bass_drop()

## Arms Bass Drop if the meter is completely full. Does not consume the meter yet —
## it detonates (and only then zeroes the meter) on the next downbeat.
func try_arm_bass_drop() -> bool:
	if bass_drop_armed:
		return false
	if ability_meter < MAX_ABILITY_METER:
		return false
	bass_drop_armed = true
	SignalBus.bass_drop_armed.emit(true)
	_update_rest_rim()
	return true

func _on_downbeat(_layer: String, _measure_index: int) -> void:
	if not bass_drop_armed:
		return
	_detonate_bass_drop()

func _detonate_bass_drop() -> void:
	bass_drop_armed = false
	SignalBus.bass_drop_armed.emit(false)
	_update_rest_rim()
	ability_meter = 0.0
	SignalBus.ability_meter_changed.emit(ability_meter, MAX_ABILITY_METER)

	var dmg_info := DamageInfo.new()
	dmg_info.amount = bass_drop_damage
	dmg_info.knockback = bass_drop_knockback
	dmg_info.stun = bass_drop_stun
	dmg_info.is_shield_breaker = true
	dmg_info.is_guard_breaking = true
	dmg_info.is_ability_hit = true
	dmg_info.source = self

	for hurtbox in get_tree().get_nodes_in_group("enemy_hurtbox"):
		if not is_instance_valid(hurtbox):
			continue
		if global_position.distance_to(hurtbox.global_position) <= bass_drop_radius:
			hurtbox.receive_hit(dmg_info)

	SignalBus.camera_shake_requested.emit(0.3, 0.4)
	SignalBus.hit_stop_requested.emit(BASS_DROP_HIT_STOP_DURATION, BASS_DROP_HIT_STOP_SCALE)
	_spawn_bass_drop_ring()

## F9: one-shot shock ring at Nick's feet (Bass Drop fires at most once per full meter, so
## it is created and freed rather than pooled). Parented to Nick's parent so it stays where
## the drop landed while he moves.
func _spawn_bass_drop_ring() -> MeshInstance3D:
	var host := get_parent()
	if host == null or not is_inside_tree():
		return null
	var torus := TorusMesh.new()
	torus.inner_radius = 0.9
	torus.outer_radius = 1.0
	var mat := StandardMaterial3D.new()
	mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	mat.albedo_color = BASS_DROP_RING_COLOR
	torus.material = mat
	var ring := MeshInstance3D.new()
	ring.name = "BassDropRing"
	ring.mesh = torus
	ring.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	host.add_child(ring)
	ring.global_position = global_position - Vector3(0.0, FEET_OFFSET, 0.0)
	ring.scale = Vector3(BASS_DROP_RING_START_SCALE, 1.0, BASS_DROP_RING_START_SCALE)
	var tween := ring.create_tween()
	tween.tween_property(ring, "scale", Vector3(bass_drop_radius, 1.0, bass_drop_radius), BASS_DROP_RING_SECONDS).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	tween.tween_callback(ring.queue_free)
	return ring

## H3: a checkpoint respawn hands Nick back in a clean state -- Idle, idle clip, no stale
## buffers, no armed Bass Drop, no dodge cooldown, at rest. GameManager has already
## teleported him and granted the grace (HealthComponent.grace_invincible -- I2: a dodge
## state exit() only clears its own i-frames, so it cannot cancel the grace).
func _on_player_respawned() -> void:
	# State first: a dodge state exit() starts the cooldown.
	if state_machine and state_machine.has_method("_on_transition_requested"):
		state_machine._on_transition_requested("StateIdle")
	pending_hurt = null
	velocity = Vector3.ZERO
	consume_jump_buffer()
	clear_coyote_time()
	clear_dodge_buffer()
	clear_attack_buffer()
	pending_attack_heavy = false
	_dodge_cooldown_timer = 0.0
	bass_drop_armed = false
	SignalBus.bass_drop_armed.emit(false)
	if animation_controller:
		animation_controller.play("idle")
	_update_rest_rim()

func _on_died() -> void:
	if animation_controller:
		animation_controller.play_once("death")

func _on_damaged(info: DamageInfo) -> void:
	# I1: a stunning hit staggers Nick (StateHurt plays hit_react fitted to the stagger);
	# a zero-stun hit only flinches, with no state change (J3: see _play_flinch).
	var staggers := is_staggered_by(info)
	if not staggers:
		_play_flinch()
	SignalBus.player_damaged.emit(info)
	# F6: make every hit taken read — HP and shield losses alike.
	SignalBus.hit_stop_requested.emit(DAMAGE_HIT_STOP_DURATION, DAMAGE_HIT_STOP_SCALE)
	SignalBus.camera_shake_requested.emit(DAMAGE_SHAKE_STRENGTH, DAMAGE_SHAKE_DURATION)
	if character_visual:
		character_visual.flash_rim(Color.WHITE, DAMAGE_FLASH_STRENGTH, DAMAGE_FLASH_SECONDS)
	if staggers:
		_enter_hurt(info)

## I1: a hit that got through (i-frames and the respawn grace never reach here) staggers
## Nick when it carries stun, he survives it, and it is not his own fall damage.
func is_staggered_by(info: DamageInfo) -> bool:
	if info == null or info.stun <= 0.0 or info.source == self:
		return false
	return health_component != null and health_component.current_health > 0.0

## J3: the zero-stun flinch plays only in a resting state (a PlayerState with an anim_key:
## Idle/Run/Airborne) -- never over a live swing or a dodge clip -- fitted to FLINCH_SECONDS,
## then back to the state's own clip.
func _play_flinch() -> void:
	if animation_controller == null or state_machine == null:
		return
	var state: Variant = state_machine.get("current_state")
	if not (state is PlayerState) or (state as PlayerState).anim_key == "":
		return
	animation_controller.play_once_fitted("hit_react", FLINCH_SECONDS)

## I1: hands the hit to StateHurt. A second stagger while already hurt restarts it.
func _enter_hurt(info: DamageInfo) -> void:
	if state_machine == null:
		return
	var hurt: Node = state_machine.get_node_or_null("StateHurt")
	if hurt == null:
		return
	pending_hurt = info
	if state_machine.current_state == hurt:
		hurt.enter()
	else:
		state_machine._on_transition_requested("StateHurt")

## F6: below LOW_HP_FRACTION the rim pulses toward magenta on every primary beat.
func _on_beat(layer: String, _beat_index: int) -> void:
	if layer != "primary" or character_visual == null:
		return
	if is_low_health():
		character_visual.flash_rim(LOW_HP_PULSE_COLOR, LOW_HP_PULSE_STRENGTH, LOW_HP_PULSE_SECONDS)

func is_low_health() -> bool:
	var hc := health_component
	return hc.max_health > 0.0 and hc.current_health > 0.0 and hc.current_health / hc.max_health < LOW_HP_FRACTION

## The rim Nick rests at: white-hot while Bass Drop is armed (F9), pale cyan while
## invincible, otherwise his authored cyan. Flashes (damage, low-HP pulse) play on top and
## return to it.
func _update_rest_rim() -> void:
	if character_visual == null:
		return
	var key := "default"
	if bass_drop_armed:
		key = "bass_drop_armed"
	elif health_component.is_invincible:
		key = "invincible"
	if key == _rest_rim_key:
		return
	_rest_rim_key = key
	match key:
		"bass_drop_armed":
			character_visual.update_rim_color(Color.WHITE)
			character_visual.update_rim_strength(BASS_DROP_ARMED_RIM_STRENGTH)
		"invincible":
			character_visual.update_rim_color(INVINCIBLE_RIM_COLOR)
			character_visual.update_rim_strength(INVINCIBLE_RIM_STRENGTH)
		_:
			character_visual.update_rim_color(character_visual.get_default_rim_color())
			character_visual.update_rim_strength(character_visual.rim_strength)

## F10: ticks the forgiveness windows and records this frame's jump/dodge presses. Runs
## from _physics_process, before the StateMachine child's physics step (parent first), so
## states always see the press of the current frame through the buffers.
func _tick_input_buffers(delta: float) -> void:
	_coyote_timer = maxf(0.0, _coyote_timer - delta)
	_jump_buffer_timer = maxf(0.0, _jump_buffer_timer - delta)
	_dodge_buffer_timer = maxf(0.0, _dodge_buffer_timer - delta)
	if _dodge_buffer_timer <= 0.0:
		_buffered_dodge_state = ""
	_attack_buffer_timer = maxf(0.0, _attack_buffer_timer - delta)
	if Input.is_action_just_pressed("jump"):
		buffer_jump()
	if Input.is_action_just_pressed("dash"):
		buffer_dodge("StateDash")
	elif Input.is_action_just_pressed("roll"):
		buffer_dodge("StateRoll")
	if Input.is_action_just_pressed("attack_heavy"):
		buffer_attack(true)
	elif Input.is_action_just_pressed("attack_light"):
		buffer_attack(false)

## H3: latch an attack press (heavy wins over light in the same frame).
func buffer_attack(heavy: bool) -> void:
	_buffered_attack_heavy = heavy
	_attack_buffer_timer = attack_buffer_time

func has_buffered_attack() -> bool:
	return _attack_buffer_timer > 0.0

## Uses up the buffered attack: true if there was one, and pending_attack_heavy now says
## which (StateAttack.enter() reads it).
func take_buffered_attack() -> bool:
	if not has_buffered_attack():
		return false
	pending_attack_heavy = _buffered_attack_heavy
	clear_attack_buffer()
	return true

func clear_attack_buffer() -> void:
	_attack_buffer_timer = 0.0
	_buffered_attack_heavy = false

func buffer_jump() -> void:
	_jump_buffer_timer = jump_buffer_time

func has_buffered_jump() -> bool:
	return _jump_buffer_timer > 0.0

## Uses up the buffered jump; returns whether there was one.
func consume_jump_buffer() -> bool:
	var had := has_buffered_jump()
	_jump_buffer_timer = 0.0
	return had

func start_coyote_time() -> void:
	_coyote_timer = coyote_time

func has_coyote_time() -> bool:
	return _coyote_timer > 0.0

func clear_coyote_time() -> void:
	_coyote_timer = 0.0

func buffer_dodge(state_name: String) -> void:
	_buffered_dodge_state = state_name
	_dodge_buffer_timer = dodge_buffer_time

## The buffered dodge state to enter now ("" if none is buffered or the cooldown still
## runs). Consumes the buffer when it returns a state.
func take_buffered_dodge() -> String:
	if _dodge_buffer_timer <= 0.0 or _buffered_dodge_state == "" or not can_dodge():
		return ""
	var state_name := _buffered_dodge_state
	clear_dodge_buffer()
	return state_name

func clear_dodge_buffer() -> void:
	_dodge_buffer_timer = 0.0
	_buffered_dodge_state = ""

func _physics_process(delta: float) -> void:
	_tick_input_buffers(delta)
	if current_path and current_path.curve:
		# Snap the player X and Z to the closest point on the path to prevent drifting —
		# eased over rail_blend_time right after a rail switch.
		var local_pos = current_path.to_local(global_position)
		var closest_pt = current_path.to_global(current_path.curve.get_closest_point(local_pos))
		if _rail_blend < 1.0:
			_rail_blend = minf(1.0, _rail_blend + delta / maxf(rail_blend_time, 0.001))
			global_position.x = lerpf(global_position.x, closest_pt.x, _rail_blend)
			global_position.z = lerpf(global_position.z, closest_pt.z, _rail_blend)
		else:
			global_position.x = closest_pt.x
			global_position.z = closest_pt.z

	# Remember the last solid ground so a fall can return Nick there — never a floor that
	# can vanish under him (F14).
	if is_on_floor() and _is_standing_on_safe_floor():
		last_safe_position = global_position

	# Fell out of the world -> snap back to the last safe ground and pay HP (shield absorbs first;
	# if the bar empties the HealthComponent's universal rule costs a life). No infinite fall, no
	# full level reset.
	if global_position.y < FALL_KILL_Y:
		fall_back_to_safe_ground()

## J4: the fall contract -- back to the last safe ground for fall_damage. The cost ignores
## dash/roll i-frames (DamageInfo.ignores_iframes: a dash off the edge still pays) but not
## the respawn grace, so a respawn-fall loop cannot double-charge. A survivable fall shows
## the SIGNAL LOST cue and grants a short grace; a fall that costs a life leaves the grace to
## the life-loss respawn.
func fall_back_to_safe_ground() -> void:
	global_position = last_safe_position
	velocity = Vector3.ZERO
	can_double_jump = double_jump_unlocked
	if health_component.grace_invincible:
		return # still inside a grace: no charge, and the running grace is not shortened
	var fall_hit := DamageInfo.new()
	fall_hit.amount = fall_damage
	fall_hit.source = self
	fall_hit.ignores_iframes = true
	health_component.take_damage(fall_hit)
	SignalBus.banner_requested.emit(FALL_BANNER % int(fall_damage), FALL_BANNER_HOLD)
	if health_component.current_health > 0.0:
		var gm = get_node_or_null("/root/GameManager")
		if gm:
			gm.grant_respawn_grace(health_component, FALL_GRACE)

## F14: false when any floor contact of the last move_and_slide is an unsafe floor.
func _is_standing_on_safe_floor() -> bool:
	for i in get_slide_collision_count():
		var col := get_slide_collision(i)
		if col.get_angle(0, up_direction) > floor_max_angle + 0.01:
			continue # a wall/ceiling contact, not the floor
		if is_unsafe_floor(col.get_collider() as Node):
			return false
	return true

## A floor body Nick must not respawn on after a fall: in the unsafe_floor group, or (until
## the level tags it) the PlatformBody of an EscapeCollapsingHazard.
static func is_unsafe_floor(body: Node) -> bool:
	if body == null:
		return false
	if body.is_in_group(UNSAFE_FLOOR_GROUP):
		return true
	return body is StaticBody3D and body.get_parent() is EscapeCollapsingHazard

func apply_gravity(delta: float) -> void:
	if not is_on_floor():
		velocity += get_gravity() * gravity_multiplier * delta
	else:
		can_double_jump = double_jump_unlocked

func get_movement_input() -> Vector2:
	# The real gameplay actions (A/D, arrows, D-pad, left stick) — not the ui_* menu ones.
	var x := Input.get_axis("move_left", "move_right")
	# GDD §3.1: while plane-locked to a Path3D (side-scroll), up/down do nothing — they
	# must not flip facing or enter StateRun while Nick stands still.
	if current_path != null:
		return Vector2(x, 0.0)
	return Vector2(x, Input.get_axis("move_up", "move_down"))

func get_path_direction(input_dir: Vector2) -> Vector3:
	if not current_path or not current_path.curve:
		return Vector3(input_dir.x, 0, input_dir.y).normalized() * input_dir.length()
		
	var local_pos = current_path.to_local(global_position)
	var offset = current_path.curve.get_closest_offset(local_pos)
	
	# Sample a point slightly ahead to get the tangent direction
	var current_pt = current_path.to_global(current_path.curve.sample_baked(offset))
	var next_pt = current_path.to_global(current_path.curve.sample_baked(offset + 0.1))
	
	var dir = (next_pt - current_pt).normalized()
	dir.y = 0
	# For Path3D, only the X input moves us along the path
	return dir * input_dir.x

## `snap` turns at once instead of easing (I3: an attack must swing where the stick points,
## and the hitboxes ride on the mesh).
func face_direction(direction: float, snap: bool = false) -> void:
	if direction == 0:
		return
	is_facing_right = direction > 0
	# Smooth rotation for the 3D MeshInstance3D parent to face left/right.
	# This correctly propagates rotation to both the KatanaHitbox and the CharacterVisual.
	var target_rotation = PI / 2.0 if is_facing_right else -PI / 2.0
	mesh.rotation.y = target_rotation if snap else lerp_angle(mesh.rotation.y, target_rotation, 0.2)
