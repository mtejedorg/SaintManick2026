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

## S2 staged entrances — read only by a WaveSpawner with `staged_entries` on (a bare spawner
## still drops the whole wave in one frame). Beats between one enemy's arrival and the next.
## Arrivals land ON the primary beat (the world's heartbeat), so 0.5 = two per beat, 1 = one.
@export var stagger_beats: float = 0.5
## How each enemy arrives: "drop" (side-scroll: released `drop_height` above its marker,
## a magenta ring marks the landing spot one beat early, a small shake on touchdown) or
## "beam" (top-down rims: a short additive magenta column + a 0.6 -> 1 scale-in on the
## marker). Anything else = appear on the marker.
@export var entry: String = "drop"
## Height above the marker a "drop" enemy is released from (the Zone 9 wave 2 uses 8: it
## falls out of the shaft above the platform).
@export var drop_height: float = 6.0

func is_blocking(index: int) -> bool:
	return index >= blocking.size() or blocking[index]
