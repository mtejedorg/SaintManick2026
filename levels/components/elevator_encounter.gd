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

var current_wave_index: int = 0
var is_active: bool = false
## Set once the elevator has arrived and every wave is beaten. A completed elevator never
## resets on respawn (dead enemies stay dead, no scrap re-farming).
var completed: bool = false
var _start_y: float = 0.0
var is_cooldown: bool = false
var cooldown_timer: float = 0.0

func _ready() -> void:
	if platform:
		_start_y = platform.position.y
	if spawner:
		spawner.wave_cleared.connect(_on_wave_cleared)
	if entry_trigger:
		entry_trigger.body_entered.connect(_on_entry_trigger_entered)
	SignalBus.player_respawned.connect(_on_player_respawned)

## The player lost a life mid-ride: despawn the wave silently, drop the platform back to
## the bottom and re-arm the entry trigger so he can board and fight it again from wave 1.
## A completed elevator is left alone.
func _on_player_respawned() -> void:
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
	if entry_trigger:
		entry_trigger.set_deferred("monitoring", true)

func _on_entry_trigger_entered(body: Node3D) -> void:
	if body is PlayerController and not is_active:
		# Disable entry trigger monitoring to avoid multiple triggers
		entry_trigger.set_deferred("monitoring", false)
		
		# Shift camera from Path_Z8 to Path_Z9
		SignalBus.camera_shift_requested.emit(false, target_path, 1.5)
		
		# Start encounter (deferred: spawning inside the body_entered callback is blocked)
		start_encounter.call_deferred()

func start_encounter() -> void:
	is_active = true
	completed = false
	is_cooldown = false
	current_wave_index = 0
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
		if current_y < target_y:
			current_y = min(target_y, current_y + speed * delta)
			platform.position.y = current_y
			
	_check_completion()

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
		if cells_reward > 0:
			GameManager.add_cells(cells_reward)
		if exit_path:
			SignalBus.camera_shift_requested.emit(false, exit_path, 0.5)
		encounter_completed.emit()
		print("Elevator encounter completed!")
