class_name CeilingPiston
extends Node3D

## Conductor-locked crusher (C13). Everything keys off the Conductor's in-measure beat
## number (1..4) and its downbeat -- never a locally counted beat -- so all pistons share
## the world's heartbeat and cascade by `beat_offset`:
##   * cock-back on the beat BEFORE the slam: rises `cock_distance` and glows hot,
##   * slam on the slam beat (the measure downbeat for beat_offset 0),
##   * accelerating pistons (`accelerate_pattern`) slam on beats first and first+2 instead of
##     once per measure while Nick is near; they only switch mode on a measure boundary.

signal slammed

@export var slam_distance: float = 3.5
@export var slam_duration: float = 0.1
@export var hold_duration: float = 0.2
@export var retract_duration: float = 0.5
## Beats (0..3) after the measure downbeat on which this piston slams -- staggers a row of
## pistons into a cascade instead of a synchronised wall.
@export var beat_offset: int = 0
@export var accelerate_pattern: bool = false
@export var start_accelerating_distance: float = 15.0
@export var cock_distance: float = 0.5
@export var cock_duration: float = 0.12
@export var cock_emission_energy: float = 2.5
@export var damage: float = 15.0

@onready var piston_body: Node3D = $PistonBody
@onready var hitbox: Hitbox3D = $PistonBody/Hitbox3D
@onready var piston_mesh: MeshInstance3D = get_node_or_null("PistonBody/MeshInstance3D")

const BEATS_PER_MEASURE := 4

var initial_y: float
var tween: Tween
var player: Node3D
## True while the accelerated (two slams per measure) pattern is latched.
var is_fast: bool = false
var is_cocked: bool = false
var _material: StandardMaterial3D
var _rest_emission_energy: float = 0.0

func _ready() -> void:
	initial_y = piston_body.position.y
	# Overhead hazard: solid, but Nick walks under it (see test_golden_path_traversal).
	piston_body.add_to_group("hazards")
	hitbox.is_active = false

	hitbox.collision_layer = 8192 # Layer 14
	hitbox.collision_mask = 1024 # Layer 11
	hitbox.damage_info = DamageInfo.new()
	hitbox.damage_info.amount = damage
	hitbox.damage_info.knockback = 5.0
	hitbox.damage_info.source = self

	if piston_mesh and piston_mesh.get_surface_override_material(0) is StandardMaterial3D:
		_material = piston_mesh.get_surface_override_material(0)
		_rest_emission_energy = _material.emission_energy_multiplier

	player = get_tree().current_scene.get_node_or_null("Player")
	SignalBus.beat.connect(_on_beat)
	SignalBus.downbeat.connect(_on_downbeat)

## Beats of the measure (1..4) on which this piston slams in its current mode.
func get_slam_beats() -> Array[int]:
	var first := posmod(beat_offset, BEATS_PER_MEASURE) + 1
	var beats: Array[int] = [first]
	if is_fast:
		beats.append((first + 1) % BEATS_PER_MEASURE + 1)
	return beats

func _on_beat(layer: String, beat_index: int) -> void:
	if layer != "primary":
		return
	# Beat 1 is the measure boundary (the Conductor emits it just before `downbeat`):
	# the only moment the slam pattern may change.
	if beat_index == 1:
		_refresh_pattern()
	var slam_beats := get_slam_beats()
	if (beat_index % BEATS_PER_MEASURE + 1) in slam_beats:
		cock_back()
	# A slam on beat 1 is driven by the downbeat signal itself.
	if beat_index != 1 and beat_index in slam_beats:
		slam()

func _on_downbeat(layer: String, _measure_index: int) -> void:
	if layer != "primary":
		return
	_refresh_pattern()
	if 1 in get_slam_beats():
		slam()
	elif is_cocked:
		_relax()

func _refresh_pattern() -> void:
	if not player:
		player = get_tree().current_scene.get_node_or_null("Player")
	is_fast = false
	if accelerate_pattern and player:
		is_fast = global_position.distance_to(player.global_position) < start_accelerating_distance

## One-beat telegraph: rise a little and glow hot so the slam can be read and dodged.
func cock_back() -> void:
	if is_cocked:
		return
	is_cocked = true
	if tween:
		tween.kill()
	tween = create_tween().set_parallel(true)
	tween.tween_property(piston_body, "position:y", initial_y + cock_distance, cock_duration)\
		.set_trans(Tween.TRANS_QUAD)\
		.set_ease(Tween.EASE_OUT)
	if _material:
		tween.tween_property(_material, "emission_energy_multiplier", cock_emission_energy, cock_duration)

## A cocked piston whose pattern flipped on the measure boundary: ease back to rest.
func _relax() -> void:
	is_cocked = false
	if tween:
		tween.kill()
	tween = create_tween().set_parallel(true)
	tween.tween_property(piston_body, "position:y", initial_y, cock_duration)
	if _material:
		tween.tween_property(_material, "emission_energy_multiplier", _rest_emission_energy, cock_duration)

func slam() -> void:
	if tween:
		tween.kill()
	is_cocked = false
	hitbox.is_active = false
	slammed.emit()

	tween = create_tween()
	# Slam down rapidly
	tween.tween_property(piston_body, "position:y", initial_y - slam_distance, slam_duration)\
		.set_trans(Tween.TRANS_QUAD)\
		.set_ease(Tween.EASE_IN)

	# Activate hitbox on impact
	tween.tween_callback(func():
		hitbox.is_active = true
		SignalBus.camera_shake_requested.emit(0.4, 0.2)
	)

	# Hold
	tween.tween_interval(hold_duration)

	# Deactivate hitbox and retract slowly (cooling back to the resting glow)
	tween.tween_callback(func():
		hitbox.is_active = false
		if _material:
			_material.emission_energy_multiplier = _rest_emission_energy
	)
	tween.tween_property(piston_body, "position:y", initial_y, retract_duration)\
		.set_trans(Tween.TRANS_QUAD)\
		.set_ease(Tween.EASE_OUT)
