class_name WaveSpawner
extends Node3D

signal wave_cleared

var active_enemies: Array[Node] = []

func spawn_wave(wave_def: WaveDef) -> void:
	active_enemies.clear()
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

	for i in range(wave_def.enemies.size()):
		var enemy_scene = wave_def.enemies[i]
		if not enemy_scene:
			continue
			
		var enemy = enemy_scene.instantiate()
		
		# Determine spawn position
		var spawn_pos = global_position
		var spawn_rot = global_rotation
		if not markers.is_empty():
			var marker = markers[i % markers.size()]
			spawn_pos = marker.global_position
			spawn_rot = marker.global_rotation
			
		# Add child before setting global_position to ensure it's in the tree
		add_child(enemy)
		enemy.global_position = spawn_pos
		enemy.global_rotation = spawn_rot
		
		active_enemies.append(enemy)
		enemy.tree_exited.connect(_on_enemy_defeated.bind(enemy))

func _on_enemy_defeated(enemy: Node) -> void:
	# Only tracked enemies count toward wave completion — reset() silently frees its
	# enemies AFTER clearing this list, and those frees must not emit wave_cleared
	# (which would advance the encounter mid-reset).
	if enemy not in active_enemies:
		return
	active_enemies.erase(enemy)
	if active_enemies.is_empty():
		wave_cleared.emit()

## T3: silently despawn every still-alive spawned enemy — no enemy_died, no scrap,
## no wave_cleared. Used when the player loses a life mid-encounter so the refight
## starts clean.
func reset() -> void:
	var doomed = active_enemies.duplicate()
	active_enemies.clear()
	for enemy in doomed:
		if is_instance_valid(enemy):
			if enemy.tree_exited.is_connected(_on_enemy_defeated.bind(enemy)):
				enemy.tree_exited.disconnect(_on_enemy_defeated.bind(enemy))
			enemy.queue_free()
