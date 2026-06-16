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
	if enemy in active_enemies:
		active_enemies.erase(enemy)
	if active_enemies.is_empty():
		wave_cleared.emit()
