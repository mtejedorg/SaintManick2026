class_name ElevatorEncounter
extends Node3D

signal encounter_completed

@export var platform: AnimatableBody3D
@export var target_y: float = 15.0
@export var speed: float = 2.0
@export var waves: Array[WaveDef] = []
@export var spawner: WaveSpawner
@export var wave_cooldown: float = 5.0

@export var entry_trigger: Area3D
@export var target_path: Path3D # Path_Z9
## Rail Nick is handed to when the elevator arrives (Path_Z10). Without it he stays on
## Path_Z9 (max x = platform edge) and cannot walk into the dock.
@export var exit_path: Path3D
## Rare Scrap ("cells" in code, GDD §5.1) awarded for clearing the Zone 9 elevator
## endurance encounter.
@export var cells_reward: int = 10
## S4: the ride stops. Wave i is fought with the platform parked at stop_heights[i] (it climbs
## there, lurches to a halt and waits until the wave is dead); once every wave is beaten the
## last leg runs to target_y. Heights past target_y are clamped to it; no entry = target_y.
@export var stop_heights: Array[float] = [5.0, 10.0, 14.5]
## Flickers for `flicker_beats` beats each time the platform lurches to a stop (optional).
@export var ride_light: OmniLight3D
@export var flicker_beats: int = 3
const LURCH_SHAKE_STRENGTH := 0.2
const LURCH_SHAKE_DURATION := 0.3
const FLICKER_LOW := 0.15

var current_wave_index: int = 0
var is_active: bool = false
## Set once the elevator has arrived and every wave is beaten. A completed elevator never
## resets on respawn (dead enemies stay dead, no scrap re-farming).
var completed: bool = false
var _start_y: float = 0.0
var is_cooldown: bool = false
var cooldown_timer: float = 0.0
## Bumped on every respawn: a deferred start_encounter scheduled under an older generation
## is stale (a respawn reset landed in the same frame) and no-ops.
var _generation: int = 0
## S4: index of the stop the platform last lurched into (-1 = none yet this ride).
var _halted_stop: int = -1
var _flicker_left: int = 0
var _light_energy: float = 0.0
var _flicker_tween: Tween = null

func _ready() -> void:
	if platform:
		_start_y = platform.position.y
	if spawner:
		spawner.wave_cleared.connect(_on_wave_cleared)
	if entry_trigger:
		entry_trigger.body_entered.connect(_on_entry_trigger_entered)
	SignalBus.player_respawned.connect(_on_player_respawned)
	if ride_light:
		_light_energy = ride_light.light_energy

## The player lost a life mid-ride: despawn the wave silently, drop the platform back to
## the bottom and re-arm the entry trigger so he can board and fight it again from wave 1.
## A completed elevator is left alone.
func _on_player_respawned() -> void:
	_generation += 1
	if completed or not is_active:
		return
	if spawner:
		spawner.reset()
	if platform:
		platform.position.y = _start_y
	current_wave_index = 0
	is_cooldown = false
	cooldown_timer = 0.0
	is_active = false
	_halted_stop = -1
	_stop_flicker()
	if entry_trigger:
		entry_trigger.set_deferred("monitoring", true)

func _on_entry_trigger_entered(body: Node3D) -> void:
	if body is PlayerController and not is_active:
		# Disable entry trigger monitoring to avoid multiple triggers
		entry_trigger.set_deferred("monitoring", false)
		
		# H4: rail-lock Nick to the shaft NOW -- the camera tween only assigns it when it lands
		# 1.5 s later, and one step back in that window stranded him under the platform.
		if "current_path" in body and target_path:
			body.current_path = target_path
		# Shift camera from Path_Z8 to Path_Z9
		SignalBus.camera_shift_requested.emit(false, target_path, 1.5)
		
		# Start encounter (deferred: spawning inside the body_entered callback is blocked)
		start_encounter.bind(_generation).call_deferred()

func start_encounter(generation: int = -1) -> void:
	if generation != -1 and generation != _generation:
		# Stale: Nick respawned before the deferred start ran -- stay idle, re-arm boarding.
		if entry_trigger:
			entry_trigger.set_deferred("monitoring", true)
		return
	is_active = true
	completed = false
	is_cooldown = false
	current_wave_index = 0
	_halted_stop = -1
	_spawn_current_wave()

func _physics_process(delta: float) -> void:
	if not is_active:
		return
		
	if is_cooldown:
		cooldown_timer -= delta
		if cooldown_timer <= 0.0:
			is_cooldown = false
			_spawn_current_wave()
			
	if platform:
		var current_y = platform.position.y
		var leg_top := current_leg_height()
		if current_y < leg_top:
			current_y = min(leg_top, current_y + speed * delta)
			platform.position.y = current_y
			if current_y >= leg_top and current_wave_index < waves.size() and _halted_stop != current_wave_index:
				_lurch_to_stop(current_wave_index)
			
	_check_completion()

## S4: how high the platform may climb right now -- the current wave's stop while it is
## being fought, target_y once every wave is beaten.
func current_leg_height() -> float:
	if current_wave_index < waves.size() and current_wave_index < stop_heights.size():
		return minf(stop_heights[current_wave_index], target_y)
	return target_y

## S4: the platform has climbed into a stop with its wave still alive -- jolt and flicker.
func _lurch_to_stop(stop_index: int) -> void:
	_halted_stop = stop_index
	SignalBus.camera_shake_requested.emit(LURCH_SHAKE_STRENGTH, LURCH_SHAKE_DURATION)
	if ride_light == null or flicker_beats <= 0:
		return
	_flicker_left = flicker_beats
	if not SignalBus.beat.is_connected(_on_flicker_beat):
		SignalBus.beat.connect(_on_flicker_beat)
	_flicker_once()

func _on_flicker_beat(layer: String, _beat_index: int) -> void:
	if layer != "primary" or _flicker_left <= 0:
		return
	_flicker_left -= 1
	if _flicker_left <= 0:
		_stop_flicker()
		return
	_flicker_once()

## One stutter of the ride light: off, on, half, on within ~0.25 s.
func _flicker_once() -> void:
	if ride_light == null or not ride_light.is_inside_tree():
		return
	if _flicker_tween:
		_flicker_tween.kill()
	ride_light.light_energy = _light_energy * FLICKER_LOW
	_flicker_tween = ride_light.create_tween()
	_flicker_tween.tween_property(ride_light, "light_energy", _light_energy, 0.06)
	_flicker_tween.tween_property(ride_light, "light_energy", _light_energy * 0.4, 0.05)
	_flicker_tween.tween_property(ride_light, "light_energy", _light_energy, 0.12)

func _stop_flicker() -> void:
	_flicker_left = 0
	if _flicker_tween:
		_flicker_tween.kill()
		_flicker_tween = null
	if ride_light and is_instance_valid(ride_light):
		ride_light.light_energy = _light_energy

func _spawn_current_wave() -> void:
	if current_wave_index < waves.size():
		if spawner:
			spawner.spawn_wave(waves[current_wave_index])
		else:
			push_error("ElevatorEncounter: No WaveSpawner assigned!")
			_on_wave_cleared()

func _on_wave_cleared() -> void:
	current_wave_index += 1
	if current_wave_index < waves.size():
		is_cooldown = true
		cooldown_timer = wave_cooldown
	else:
		_check_completion()

func _check_completion() -> void:
	if not is_active:
		return
		
	var platform_y = platform.position.y if platform else target_y
	var reached_top = platform_y >= target_y
	var all_waves_done = current_wave_index >= waves.size()
	
	if reached_top and all_waves_done:
		is_active = false
		completed = true
		# The completed elevator never resets, so the Zone 9 checkpoint (at the base) would
		# respawn Nick below a parked platform: checkpoint him dock-side, on the exit rail.
		var player := get_tree().get_first_node_in_group("player") as Node3D
		if player:
			GameManager.set_checkpoint(player.global_position, exit_path, false)
		if cells_reward > 0:
			GameManager.add_cells(cells_reward)
		if exit_path:
			SignalBus.camera_shift_requested.emit(false, exit_path, 0.5)
		encounter_completed.emit()
		print("Elevator encounter completed!")
