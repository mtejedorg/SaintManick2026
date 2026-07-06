class_name PlayerController
extends CharacterBody3D

@export var max_speed: float = 8.0
@export var acceleration: float = 40.0
@export var friction: float = 60.0
@export var jump_force: float = 18.0
@export var gravity_multiplier: float = 3.0
@export var dash_speed: float = 18.0
@export var roll_speed: float = 18.0

@export var current_path: Path3D

## Y below which the player is considered to have fallen out of the world. Below every
## legitimate floor in the slice (lowest arena floor ~ -4.5); the elevator rises well above 0.
const FALL_KILL_Y: float = -15.0
## HP cost paid when falling out of the world (shield absorbs first, per the universal rule).
@export var fall_damage: float = 20.0

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

@onready var state_machine: Node = $StateMachine
@onready var mesh: MeshInstance3D = $MeshInstance3D
@onready var katana_hitbox: Area3D = $MeshInstance3D/KatanaHitbox
@onready var health_component: HealthComponent = $HealthComponent
@onready var animation_controller: PlayerAnimationController = $PlayerAnimationController
var combo_component: Node = null

func _ready() -> void:
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

func _process(delta: float) -> void:
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
	return true

func _on_downbeat(_layer: String, _measure_index: int) -> void:
	if not bass_drop_armed:
		return
	_detonate_bass_drop()

func _detonate_bass_drop() -> void:
	bass_drop_armed = false
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

func _on_died() -> void:
	if animation_controller:
		animation_controller.play_once("death")

func _on_damaged(_info) -> void:
	if animation_controller:
		animation_controller.play_once("hit_react")

func _physics_process(_delta: float) -> void:
	if current_path and current_path.curve:
		# Snap the player X and Z to the closest point on the path to prevent drifting
		var local_pos = current_path.to_local(global_position)
		var closest_pt = current_path.to_global(current_path.curve.get_closest_point(local_pos))
		global_position.x = closest_pt.x
		global_position.z = closest_pt.z

	# Remember the last solid ground so a fall can return Nick there.
	if is_on_floor():
		last_safe_position = global_position

	# Fell out of the world -> snap back to the last safe ground and pay HP (shield absorbs first;
	# if the bar empties the HealthComponent's universal rule costs a life). No infinite fall, no
	# full level reset.
	if global_position.y < FALL_KILL_Y:
		global_position = last_safe_position
		velocity = Vector3.ZERO
		can_double_jump = double_jump_unlocked
		var fall_hit := DamageInfo.new()
		fall_hit.amount = fall_damage
		fall_hit.source = self
		health_component.take_damage(fall_hit)

func apply_gravity(delta: float) -> void:
	if not is_on_floor():
		velocity += get_gravity() * gravity_multiplier * delta
	else:
		can_double_jump = double_jump_unlocked

func get_movement_input() -> Vector2:
	return Vector2(
		Input.get_axis("ui_left", "ui_right"),
		Input.get_axis("ui_up", "ui_down")
	)

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

func face_direction(direction: float) -> void:
	if direction == 0:
		return
	is_facing_right = direction > 0
	# Smooth rotation for the 3D MeshInstance3D parent to face left/right.
	# This correctly propagates rotation to both the KatanaHitbox and the CharacterVisual.
	var target_rotation = PI / 2.0 if is_facing_right else -PI / 2.0
	mesh.rotation.y = lerp_angle(mesh.rotation.y, target_rotation, 0.2)
