class_name ZoneEncounter
extends Area3D

signal encounter_completed

@export var zone_name: String = ""
@export var waves: Array[WaveDef] = []
@export var spawner: WaveSpawner
@export var is_top_down: bool = false
@export var target_camera_path: Path3D
@export var gates: Array[Node3D] = []

var current_wave_index: int = 0
var active: bool = false
## T3: set once all waves are beaten. A completed encounter NEVER resets on respawn —
## dead enemies stay dead (kills the death-farming loop where reloads re-dropped scrap).
var completed: bool = false

func _ready() -> void:
	body_entered.connect(_on_body_entered)
	set_gate_locked(false)
	if spawner:
		spawner.wave_cleared.connect(_on_wave_cleared)
	SignalBus.player_respawned.connect(_on_player_respawned)

func _on_body_entered(body: Node3D) -> void:
	if active:
		return
	if body is PlayerController:
		active = true
		# Disable detection so it doesn't trigger again
		set_deferred("monitoring", false)

		# Announce zone entry
		if zone_name != "":
			SignalBus.zone_entered.emit(zone_name)

		# Lock gates
		set_gate_locked(true)
		
		# Handle camera shift
		if is_top_down:
			SignalBus.camera_shift_requested.emit(true, null, 1.5)
			
		# Start spawning waves. Deferred: this runs inside the Area3D body_entered
		# callback, where add_child()/monitorable changes are blocked by the physics server.
		current_wave_index = 0
		_spawn_current_wave.call_deferred()

func _spawn_current_wave() -> void:
	if current_wave_index < waves.size():
		if spawner:
			spawner.spawn_wave(waves[current_wave_index])
		else:
			push_error("ZoneEncounter: No WaveSpawner assigned!")
			_on_wave_cleared()
	else:
		# All waves completed
		_complete_encounter()

func _on_wave_cleared() -> void:
	current_wave_index += 1
	# Deferred: wave_cleared fires from the last enemy's tree_exited, i.e. while the
	# spawner is mid remove_child() — add_child() of the next wave would fail ("busy").
	_spawn_current_wave.call_deferred()

func _complete_encounter() -> void:
	completed = true
	set_gate_locked(false)
	if is_top_down:
		SignalBus.camera_shift_requested.emit(false, target_camera_path, 1.5)
	encounter_completed.emit()

## T3: the player lost a life mid-fight — despawn the remaining wave silently (no
## enemy_died, no scrap) and re-arm the trigger so he refights it from wave 1.
## Completed encounters are untouched.
func _on_player_respawned() -> void:
	if completed or not active:
		return
	if spawner:
		spawner.reset()
	active = false
	current_wave_index = 0
	set_gate_locked(false)
	set_deferred("monitoring", true)

func set_gate_locked(locked: bool) -> void:
	for gate in gates:
		if not gate:
			continue
		gate.visible = locked
		if gate is CSGPrimitive3D:
			gate.use_collision = locked
		elif gate is CollisionObject3D:
			for child in gate.get_children():
				if child is CollisionShape3D:
					child.set_deferred("disabled", not locked)
		elif gate is CollisionShape3D:
			gate.set_deferred("disabled", not locked)
