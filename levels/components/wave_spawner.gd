class_name WaveSpawner
extends Node3D

signal wave_cleared

## Enemies that must die for the wave to clear.
var active_enemies: Array[Node] = []
## Spawned but not required to clear the wave; freed silently when the wave clears.
var _non_blocking: Array[Node] = []

func spawn_wave(wave_def: WaveDef) -> void:
	active_enemies.clear()
	_non_blocking.clear()
	if not wave_def or wave_def.enemies.is_empty():
		wave_cleared.emit()
		return

	# Gather all Marker3D nodes under this spawner
	var markers: Array[Marker3D] = []
	for child in get_children():
		if child is Marker3D:
			markers.append(child)

	if markers.is_empty():
		push_warning("WaveSpawner: No Marker3D children found. Spawning at spawner position.")

	var round_robin := 0
	for i in range(wave_def.enemies.size()):
		var enemy_scene = wave_def.enemies[i]
		if not enemy_scene:
			continue
			
		var enemy = enemy_scene.instantiate()
		
		# Determine spawn position: a named marker (WaveDef.spawn_markers) wins, otherwise
		# unnamed enemies take the spawner's markers in order.
		var spawn_pos = global_position
		var spawn_rot = global_rotation
		if not markers.is_empty():
			var marker: Marker3D = _find_named_marker(markers, wave_def, i)
			if marker == null:
				marker = markers[round_robin % markers.size()]
				round_robin += 1
			spawn_pos = marker.global_position
			spawn_rot = marker.global_rotation
			
		# Add child before setting global_position to ensure it's in the tree
		add_child(enemy)
		enemy.global_position = spawn_pos
		enemy.global_rotation = spawn_rot
		
		if wave_def.is_blocking(i):
			active_enemies.append(enemy)
			enemy.tree_exited.connect(_on_enemy_defeated.bind(enemy))
		else:
			_non_blocking.append(enemy)

	# A wave made only of non-blocking enemies has nothing to wait for.
	if active_enemies.is_empty():
		_clear_non_blocking()
		wave_cleared.emit()

## Marker named by wave_def.spawn_markers[index], or null when the slot is unnamed/unknown.
func _find_named_marker(markers: Array[Marker3D], wave_def: WaveDef, index: int) -> Marker3D:
	if index >= wave_def.spawn_markers.size():
		return null
	var wanted: String = wave_def.spawn_markers[index]
	if wanted == "":
		return null
	for marker in markers:
		if String(marker.name) == wanted:
			return marker
	push_warning("WaveSpawner: named spawn marker '%s' not found; using round-robin." % wanted)
	return null

func _on_enemy_defeated(enemy: Node) -> void:
	if not is_inside_tree():
		return
	# Only tracked enemies count toward wave completion — reset() silently frees its
	# enemies AFTER clearing this list, and those frees must not emit wave_cleared
	# (which would advance the encounter mid-reset).
	if enemy not in active_enemies:
		return
	active_enemies.erase(enemy)
	if active_enemies.is_empty():
		_clear_non_blocking()
		wave_cleared.emit()

## Silently free the non-blocking leftovers (no enemy_died, no scrap).
func _clear_non_blocking() -> void:
	var leftovers := _non_blocking.duplicate()
	_non_blocking.clear()
	for enemy in leftovers:
		if is_instance_valid(enemy):
			enemy.queue_free()

## T3: silently despawn every still-alive spawned enemy — no enemy_died, no scrap,
## no wave_cleared. Used when the player loses a life mid-encounter so the refight
## starts clean.
func reset() -> void:
	var doomed = active_enemies.duplicate()
	active_enemies.clear()
	_clear_non_blocking()
	for enemy in doomed:
		if is_instance_valid(enemy):
			if enemy.tree_exited.is_connected(_on_enemy_defeated.bind(enemy)):
				enemy.tree_exited.disconnect(_on_enemy_defeated.bind(enemy))
			enemy.queue_free()
