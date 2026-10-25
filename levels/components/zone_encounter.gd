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
## Bumped on every activation and every respawn reset: a deferred wave spawn scheduled
## under an older generation is stale (a respawn reset landed in the same frame) and no-ops.
var _generation: int = 0
## H1: a completed top-down encounter keeps its gates shut until the camera shift back to
## side-scroll has landed (the rail/jump come back only then) -- leaving the room in the
## 1.5 s tween window would walk Nick off the floor axis.
var _awaiting_shift_unlock: bool = false
## J6: a top-down encounter holds its first wave until the camera shift INTO top-down has
## landed (free movement + jump off only then). The generation the pending start belongs to;
## -1 = no start pending.
var _pending_start_generation: int = -1

func _ready() -> void:
	body_entered.connect(_on_body_entered)
	# Gates are the only legal solid obstacles on the golden path (test_golden_path_traversal).
	for gate in gates:
		if gate:
			gate.add_to_group("gates")
	set_gate_locked(false)
	if spawner:
		spawner.wave_cleared.connect(_on_wave_cleared)
	SignalBus.player_respawned.connect(_on_player_respawned)

func _on_body_entered(body: Node3D) -> void:
	if active:
		return
	if body is PlayerController:
		active = true
		_generation += 1
		# Disable detection so it doesn't trigger again
		set_deferred("monitoring", false)

		# Announce zone entry
		if zone_name != "":
			SignalBus.zone_entered.emit(zone_name)

		# Lock gates
		set_gate_locked(true)
		
		current_wave_index = 0
		# Handle camera shift. J6: a top-down fight starts when the shift has landed.
		if is_top_down:
			_await_top_down_start()
			SignalBus.camera_shift_requested.emit(true, null, 1.5)
			return

		# Start spawning waves. Deferred: this runs inside the Area3D body_entered
		# callback, where add_child()/monitorable changes are blocked by the physics server.
		_spawn_current_wave.bind(_generation).call_deferred()

## J6: one-shot wait for camera_shift_finished(true) under the current generation.
func _await_top_down_start() -> void:
	_pending_start_generation = _generation
	if not SignalBus.camera_shift_finished.is_connected(_on_top_down_shift_landed):
		SignalBus.camera_shift_finished.connect(_on_top_down_shift_landed)

func _on_top_down_shift_landed(top_down: bool) -> void:
	if not top_down:
		return # a stale shift back out; keep waiting for the one in
	var generation := _pending_start_generation
	_cancel_top_down_start()
	if generation == -1 or generation != _generation:
		return
	_spawn_current_wave.bind(generation).call_deferred()

func _cancel_top_down_start() -> void:
	_pending_start_generation = -1
	if SignalBus.camera_shift_finished.is_connected(_on_top_down_shift_landed):
		SignalBus.camera_shift_finished.disconnect(_on_top_down_shift_landed)

## J6: true while a top-down start waits for its camera shift.
func is_waiting_for_top_down_shift() -> bool:
	return _pending_start_generation != -1

func _spawn_current_wave(generation: int = -1) -> void:
	if (generation != -1 and generation != _generation) or not active or completed:
		return
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
	_spawn_current_wave.bind(_generation).call_deferred()

func _complete_encounter() -> void:
	completed = true
	_cancel_top_down_start()
	if is_top_down:
		_awaiting_shift_unlock = true
		if not SignalBus.camera_shift_finished.is_connected(_on_camera_shift_finished):
			SignalBus.camera_shift_finished.connect(_on_camera_shift_finished)
		SignalBus.camera_shift_requested.emit(false, target_camera_path, 1.5)
	else:
		set_gate_locked(false)
	encounter_completed.emit()

## H1: the shift back to side-scroll landed -> open the room (one-shot).
func _on_camera_shift_finished(top_down: bool) -> void:
	if top_down:
		return # a stale shift INTO top-down; wait for the one back out
	_release_shift_unlock()

func _release_shift_unlock() -> void:
	if not _awaiting_shift_unlock:
		return
	_awaiting_shift_unlock = false
	if SignalBus.camera_shift_finished.is_connected(_on_camera_shift_finished):
		SignalBus.camera_shift_finished.disconnect(_on_camera_shift_finished)
	set_gate_locked(false)

## T3: the player lost a life mid-fight — despawn the remaining wave silently (no
## enemy_died, no scrap) and re-arm the trigger so he refights it from wave 1.
## Completed encounters are untouched.
func _on_player_respawned() -> void:
	_generation += 1
	_cancel_top_down_start()
	# H1: a respawn snaps the camera/rail back instantly -- never leave a cleared room shut.
	_release_shift_unlock()
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
			# J13: deferred -- this runs from body_entered and from player_respawned, both of
			# which can arrive inside the physics flush.
			gate.set_deferred("use_collision", locked)
		elif gate is CollisionObject3D:
			for child in gate.get_children():
				if child is CollisionShape3D:
					child.set_deferred("disabled", not locked)
		elif gate is CollisionShape3D:
			gate.set_deferred("disabled", not locked)
