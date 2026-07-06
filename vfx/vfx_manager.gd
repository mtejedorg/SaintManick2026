## VFX Manager — lives as a Node in vertical_slice.tscn.
## Maintains pools of hit spark and enemy death particle bursts and dispatches
## them on SignalBus events so individual scenes never instantiate/free VFX nodes.
extends Node

const POOL_SIZE_SPARK: int = 8
const POOL_SIZE_DEATH: int = 8

const HIT_SPARK_SCENE := preload("res://vfx/hit_spark.tscn")
const ENEMY_DEATH_SCENE := preload("res://vfx/enemy_death.tscn")

## Neon palette
const COLOR_CYAN    := Color(0.0,   0.961, 1.0,   1.0)  # #00F5FF  light attack
const COLOR_MAGENTA := Color(1.0,   0.0,   0.667, 1.0)  # #FF00AA  heavy attack
const COLOR_WHITE   := Color(1.0,   1.0,   1.0,   1.0)

var _spark_pool: Array[GPUParticles3D] = []
var _death_pool: Array[GPUParticles3D] = []
var _spark_busy: Array[bool] = []
var _death_busy: Array[bool] = []

func _ready() -> void:
	_build_pool(HIT_SPARK_SCENE, _spark_pool, _spark_busy, POOL_SIZE_SPARK)
	_build_pool(ENEMY_DEATH_SCENE, _death_pool, _death_busy, POOL_SIZE_DEATH)

	SignalBus.hit_landed.connect(_on_hit_landed)
	SignalBus.enemy_died.connect(_on_enemy_died)

func _build_pool(scene: PackedScene, pool: Array[GPUParticles3D], busy: Array[bool], count: int) -> void:
	for i in count:
		var inst := scene.instantiate() as GPUParticles3D
		add_child(inst)
		pool.append(inst)
		busy.append(false)
		# Use .bind(i) so the captured index is the value at loop time, not a reference.
		inst.burst_finished.connect(_on_burst_finished.bind(busy, i))

## hit_type: "light" → cyan sparks, "heavy" → magenta sparks
func _on_hit_landed(position: Vector3, hit_type: String) -> void:
	var idx := _first_free(_spark_busy)
	if idx == -1:
		return  # All slots busy; skip this frame's spark rather than stutter
	_spark_busy[idx] = true
	var spark := _spark_pool[idx]
	var primary := COLOR_CYAN if hit_type == "light" else COLOR_MAGENTA
	var secondary := COLOR_WHITE if hit_type == "light" else COLOR_CYAN
	spark.set_color(primary, secondary)
	spark.burst(position)

func _on_enemy_died(position: Vector3) -> void:
	var idx := _first_free(_death_busy)
	if idx == -1:
		return
	_death_busy[idx] = true
	_death_pool[idx].burst(position)

func _on_burst_finished(busy: Array[bool], idx: int) -> void:
	busy[idx] = false

func _first_free(busy: Array[bool]) -> int:
	for i in busy.size():
		if not busy[i]:
			return i
	return -1
