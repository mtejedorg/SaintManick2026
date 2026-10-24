class_name WaveDef
extends Resource

@export var enemies: Array[PackedScene] = []
## Optional named Marker3D per enemy (parallel to `enemies`). An empty string — or an index
## past the end of this array — means "round-robin over the spawner's markers".
@export var spawn_markers: Array[String] = []
## Whether each enemy must die for the wave to clear (parallel to `enemies`). An empty array,
## or an index past the end, means "blocking". Non-blocking enemies (e.g. catwalk snipers the
## z-locked rail cannot reach) are despawned silently once the blocking ones are dead.
@export var blocking: Array[bool] = []

func is_blocking(index: int) -> bool:
	return index >= blocking.size() or blocking[index]
