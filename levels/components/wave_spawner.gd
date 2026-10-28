class_name WaveSpawner
extends Node3D

signal wave_cleared

## Enemies that must die for the wave to clear.
var active_enemies: Array[Node] = []
## Spawned but not required to clear the wave; freed silently when the wave clears.
var _non_blocking: Array[Node] = []

## S2 staged entrances. On: a wave arrives one enemy at a time ON the Conductor's primary
## beat (WaveDef.stagger_beats apart) with its WaveDef.entry presentation, and wave_cleared
## waits for the last pending arrival. Off (the default -- bare spawners in tests/tools) =
## the whole wave in one frame, as before. The slice turns it on per spawner instance.
@export var staged_entries: bool = false

const ENTRY_DROP := "drop"
const ENTRY_BEAM := "beam"
## The landing ring is the top-down ground-ring geometry (player.tscn TorusMesh_ring) at 1.2x.
const RING_INNER := 0.5
const RING_OUTER := 0.6
const RING_SCALE := 1.2
const RING_FLATTEN := 0.3
const RING_LIFT := 0.03
const ENTRY_COLOR := Color(1.0, 0.0, 0.666667)
## sRGB albedo multiplier: the unshaded entry meshes bloom past glow_hdr_threshold 1.0
## (unshaded drops EMISSION -- same trick as vfx/shock_ring.gd).
const ENTRY_HDR := 2.0
const RING_ALPHA := 0.85
const BEAM_ALPHA := 0.6
const BEAM_RADIUS := 0.5
const BEAM_HEIGHT := 4.0
const BEAM_SECONDS := 0.25
const BEAM_SCALE_FROM := 0.6
const BEAM_SCALE_SECONDS := 0.2
const LANDING_SHAKE_STRENGTH := 0.1
const LANDING_SHAKE_DURATION := 0.1
## A dropped enemy that has not touched down after this long stops being tracked.
const LANDING_TIMEOUT := 3.0
## Ground probe under a marker for the ring (ground markers sit ~0.9 m above their floor).
const GROUND_PROBE := 3.0
const GROUND_FALLBACK := 0.95
const WORLD_MASK := 1

## Bumped by every spawn_wave() and reset(): arrivals queued under an older wave are dropped.
var _generation: int = 0
## Pending arrivals of the current staged wave, in arrival order:
## {scene, marker, blocking, arrival (beat number), ring (MeshInstance3D or null)}.
var _queue: Array[Dictionary] = []
## The staged wave in progress (null when none / legacy spawn).
var _queue_def: WaveDef = null
## Primary beats counted since the staged wave started.
var _beats: int = 0
## Dropped enemies still in the air: {enemy, ring, time}.
var _landing: Array[Dictionary] = []
var _ring_pool: Array[MeshInstance3D] = []
var _beam_pool: Array[MeshInstance3D] = []
var _ring_mesh: TorusMesh = null
var _beam_mesh: CylinderMesh = null

func _ready() -> void:
	set_physics_process(false)

func spawn_wave(wave_def: WaveDef) -> void:
	_cancel_pending()
	active_enemies.clear()
	_non_blocking.clear()
	if not wave_def or wave_def.enemies.is_empty():
		wave_cleared.emit()
		return

	var markers := _markers()
	if markers.is_empty():
		push_warning("WaveSpawner: No Marker3D children found. Spawning at spawner position.")
	var plan := _plan(wave_def, markers)

	if staged_entries and is_inside_tree():
		_stage(wave_def, plan)
		return

	for slot in plan:
		_spawn(slot, wave_def, "")
	# A wave made only of non-blocking enemies has nothing to wait for.
	if active_enemies.is_empty():
		_clear_non_blocking()
		wave_cleared.emit()

func _markers() -> Array[Marker3D]:
	var markers: Array[Marker3D] = []
	for child in get_children():
		if child is Marker3D:
			markers.append(child)
	return markers

## One slot per enemy: a named marker (WaveDef.spawn_markers) wins, otherwise unnamed
## enemies take the spawner's markers in order.
func _plan(wave_def: WaveDef, markers: Array[Marker3D]) -> Array[Dictionary]:
	var plan: Array[Dictionary] = []
	var round_robin := 0
	for i in range(wave_def.enemies.size()):
		var enemy_scene: PackedScene = wave_def.enemies[i]
		if not enemy_scene:
			continue
		var marker: Marker3D = null
		if not markers.is_empty():
			marker = _find_named_marker(markers, wave_def, i)
			if marker == null:
				marker = markers[round_robin % markers.size()]
				round_robin += 1
		plan.append({"scene": enemy_scene, "marker": marker, "blocking": wave_def.is_blocking(i)})
	return plan

func _spawn(slot: Dictionary, wave_def: WaveDef, entry: String) -> Node:
	var enemy = (slot["scene"] as PackedScene).instantiate()
	var spawn_pos := global_position
	var spawn_rot := global_rotation
	var marker: Marker3D = slot["marker"]
	if marker and is_instance_valid(marker):
		spawn_pos = marker.global_position
		spawn_rot = marker.global_rotation
	if entry == ENTRY_DROP:
		spawn_pos += Vector3.UP * wave_def.drop_height
	# Add child before setting global_position to ensure it's in the tree
	add_child(enemy)
	enemy.global_position = spawn_pos
	enemy.global_rotation = spawn_rot
	if slot["blocking"]:
		active_enemies.append(enemy)
		enemy.tree_exited.connect(_on_enemy_defeated.bind(enemy))
	else:
		_non_blocking.append(enemy)
	return enemy

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
	if _queue_def != null:
		_check_staged_cleared()
		return
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
## starts clean. S2: also cancels every arrival still pending.
func reset() -> void:
	_cancel_pending()
	var doomed = active_enemies.duplicate()
	active_enemies.clear()
	_clear_non_blocking()
	for enemy in doomed:
		if is_instance_valid(enemy):
			if enemy.tree_exited.is_connected(_on_enemy_defeated.bind(enemy)):
				enemy.tree_exited.disconnect(_on_enemy_defeated.bind(enemy))
			enemy.queue_free()

## Arrivals still to come in the current staged wave.
func pending_count() -> int:
	return _queue.size()

# --- S2 staged arrivals ----------------------------------------------------------------

func _stage(wave_def: WaveDef, plan: Array[Dictionary]) -> void:
	_queue_def = wave_def
	_beats = 0
	var stagger := maxf(wave_def.stagger_beats, 0.0)
	for k in plan.size():
		var slot: Dictionary = plan[k]
		# Enemy k lands on beat 1 + floor(k * stagger): the first one a beat after its ring.
		slot["arrival"] = 1 + floori(k * stagger + 0.0001)
		slot["ring"] = null
		_queue.append(slot)
	# Connected lazily: the test framework strips every SignalBus connection between tests.
	if not SignalBus.beat.is_connected(_on_beat):
		SignalBus.beat.connect(_on_beat)
	_show_due_rings()

func _on_beat(layer: String, _beat_index: int) -> void:
	if layer != "primary" or _queue_def == null or _queue.is_empty():
		return
	_beats += 1
	var generation := _generation
	while not _queue.is_empty() and int(_queue[0]["arrival"]) <= _beats:
		_arrive(_queue.pop_front())
		if generation != _generation:
			return
	_show_due_rings()
	_check_staged_cleared()

func _arrive(slot: Dictionary) -> void:
	var entry := _queue_def.entry
	var enemy: Node = _spawn(slot, _queue_def, entry)
	var ring: MeshInstance3D = slot["ring"]
	if entry == ENTRY_DROP and enemy is Node3D:
		# The ring stays on the landing spot until touchdown.
		_landing.append({"enemy": enemy, "ring": ring, "time": 0.0})
		set_physics_process(true)
		return
	_release_ring(ring)
	if entry == ENTRY_BEAM and enemy is Node3D:
		_beam_in(enemy as Node3D)

## Every pending arrival due within one beat shows its landing ring now.
func _show_due_rings() -> void:
	for slot in _queue:
		if slot["ring"] == null and int(slot["arrival"]) - 1 <= _beats:
			slot["ring"] = _acquire_ring(_ground_under(slot["marker"]))

## A staged wave is over when nothing blocking is alive or still to arrive.
func _check_staged_cleared() -> void:
	if _queue_def == null or not active_enemies.is_empty():
		return
	for slot in _queue:
		if slot["blocking"]:
			return
	_cancel_queue()
	_queue_def = null
	_clear_non_blocking()
	wave_cleared.emit()

func _cancel_queue() -> void:
	for slot in _queue:
		_release_ring(slot["ring"])
	_queue.clear()

func _cancel_pending() -> void:
	_generation += 1
	_cancel_queue()
	_queue_def = null
	_beats = 0
	for entry in _landing:
		_release_ring(entry["ring"])
	_landing.clear()

func _physics_process(delta: float) -> void:
	if _landing.is_empty():
		set_physics_process(false)
		return
	for i in range(_landing.size() - 1, -1, -1):
		var entry: Dictionary = _landing[i]
		entry["time"] = float(entry["time"]) + delta
		var enemy = entry["enemy"]
		var alive: bool = is_instance_valid(enemy) and (enemy as Node).is_inside_tree()
		var landed: bool = alive and enemy is CharacterBody3D and (enemy as CharacterBody3D).is_on_floor()
		if landed:
			SignalBus.camera_shake_requested.emit(LANDING_SHAKE_STRENGTH, LANDING_SHAKE_DURATION)
		if landed or not alive or not (enemy is CharacterBody3D) or float(entry["time"]) >= LANDING_TIMEOUT:
			_release_ring(entry["ring"])
			_landing.remove_at(i)

## Floor point under a marker (under the spawner itself without one).
func _ground_under(marker: Marker3D) -> Vector3:
	var p := global_position
	if marker and is_instance_valid(marker):
		p = marker.global_position
	var world := get_world_3d()
	if world:
		var query := PhysicsRayQueryParameters3D.create(p + Vector3.UP * 0.2, p + Vector3.DOWN * GROUND_PROBE, WORLD_MASK)
		var hit := world.direct_space_state.intersect_ray(query)
		if not hit.is_empty():
			return (hit["position"] as Vector3) + Vector3.UP * RING_LIFT
	return p + Vector3.DOWN * GROUND_FALLBACK

func _entry_material(alpha: float, additive: bool) -> StandardMaterial3D:
	var mat := StandardMaterial3D.new()
	mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	if additive:
		mat.blend_mode = BaseMaterial3D.BLEND_MODE_ADD
	mat.cull_mode = BaseMaterial3D.CULL_DISABLED
	mat.albedo_color = Color(ENTRY_COLOR.r * ENTRY_HDR, ENTRY_COLOR.g * ENTRY_HDR, ENTRY_COLOR.b * ENTRY_HDR, alpha)
	return mat

func _acquire_ring(at: Vector3) -> MeshInstance3D:
	var ring: MeshInstance3D = null
	while ring == null and not _ring_pool.is_empty():
		var pooled: MeshInstance3D = _ring_pool.pop_back()
		if is_instance_valid(pooled):
			ring = pooled
	if ring == null:
		if _ring_mesh == null:
			_ring_mesh = TorusMesh.new()
			_ring_mesh.inner_radius = RING_INNER
			_ring_mesh.outer_radius = RING_OUTER
			_ring_mesh.material = _entry_material(RING_ALPHA, false)
		ring = MeshInstance3D.new()
		ring.name = "EntryRing"
		ring.mesh = _ring_mesh
		ring.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		add_child(ring)
	ring.global_position = at
	ring.global_rotation = Vector3.ZERO
	ring.scale = Vector3(RING_SCALE, RING_FLATTEN, RING_SCALE)
	ring.visible = true
	return ring

func _release_ring(ring: Variant) -> void:
	if ring == null or not is_instance_valid(ring):
		return
	(ring as MeshInstance3D).visible = false
	if ring not in _ring_pool:
		_ring_pool.append(ring)

## Top-down rims: a short additive column on the marker while the enemy scales in.
func _beam_in(enemy: Node3D) -> void:
	var beam: MeshInstance3D = null
	while beam == null and not _beam_pool.is_empty():
		var pooled: MeshInstance3D = _beam_pool.pop_back()
		if is_instance_valid(pooled):
			beam = pooled
	if beam == null:
		if _beam_mesh == null:
			_beam_mesh = CylinderMesh.new()
			_beam_mesh.top_radius = BEAM_RADIUS
			_beam_mesh.bottom_radius = BEAM_RADIUS
			_beam_mesh.height = BEAM_HEIGHT
			_beam_mesh.material = _entry_material(BEAM_ALPHA, true)
		beam = MeshInstance3D.new()
		beam.name = "EntryBeam"
		beam.mesh = _beam_mesh
		beam.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		add_child(beam)
	var floor_point := enemy.global_position + Vector3.DOWN * GROUND_FALLBACK
	beam.global_position = floor_point + Vector3.UP * (BEAM_HEIGHT * 0.5)
	beam.scale = Vector3.ONE
	beam.visible = true
	var beam_tween := beam.create_tween()
	beam_tween.tween_property(beam, "scale", Vector3(0.05, 1.0, 0.05), BEAM_SECONDS).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN)
	beam_tween.tween_callback(_release_beam.bind(beam))
	var visual := enemy.get_node_or_null("MeshInstance3D") as Node3D
	if visual:
		var rest := visual.scale
		visual.scale = rest * BEAM_SCALE_FROM
		enemy.create_tween().tween_property(visual, "scale", rest, BEAM_SCALE_SECONDS).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)

func _release_beam(beam: MeshInstance3D) -> void:
	if not is_instance_valid(beam):
		return
	beam.visible = false
	if beam not in _beam_pool:
		_beam_pool.append(beam)
