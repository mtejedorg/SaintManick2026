class_name WaveDef
extends Resource

@export var enemies: Array[PackedScene] = []
## Optional named Marker3D per enemy (parallel to `enemies`). An empty string — or an index
## past the end of this array — means "round-robin over the spawner's markers".
@export var spawn_markers: Array[String] = []
