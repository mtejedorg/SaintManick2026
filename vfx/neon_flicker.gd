extends Node

## U5: the neon breathes. Once per primary beat every trim_* material's emission_energy_multiplier
## jumps +30 % and tweens back over 0.1 s, and now and then (~1 per 8 s per material) a trim
## drops out for 0.1 s like a failing tube. It works on the SHARED material resources the slice
## already references (assets/materials/trim_*.tres), so no scene is touched; the base energies
## are read once, the first time a material is seen, and restored when this node leaves the tree
## (a static registry, so a second flicker node never mistakes a boosted value for the base).

const TRIM_PATHS: Array[String] = [
	"res://assets/materials/trim_cyan.tres",
	"res://assets/materials/trim_magenta.tres",
	"res://assets/materials/trim_sodium.tres",
	"res://assets/materials/trim_red.tres",
]
const PULSE_BOOST := 0.3        # +30 % on every primary beat
## V12 (Reduce Flashes): the beat pulse shrinks to +10 % and the random dropouts stop.
const REDUCED_PULSE_BOOST := 0.1
const PULSE_SECONDS := 0.1
const DROPOUT_SECONDS := 0.1
const DROPOUT_LEVEL := 0.1      # fraction of the base energy during a dropout
const DROPOUT_MEAN_SECONDS := 8.0  # mean gap between dropouts, per material

## material resource_path -> its authored emission_energy_multiplier (first read wins).
static var _bases: Dictionary = {}

var materials: Array[StandardMaterial3D] = []
## Seeded by tests for deterministic dropouts.
var rng := RandomNumberGenerator.new()
## Tests switch the random dropouts off to stay deterministic.
var dropouts_enabled: bool = true
var pulses: int = 0
var dropouts: int = 0
## V12: mirrors GameManager.reduce_flashes(); re-read on every beat and via apply_accessibility()
## (the options menu closing is felt from the next beat on).
var reduced: bool = false

var _tweens: Dictionary = {}     # material -> Tween
var _dropout_left: Dictionary = {}  # material -> seconds left

func _ready() -> void:
	rng.randomize()
	for path in TRIM_PATHS:
		var mat := load(path) as StandardMaterial3D
		if mat == null:
			continue
		if not _bases.has(path):
			_bases[path] = mat.emission_energy_multiplier
		else:
			# A previous flicker node was freed mid-pulse: start from the authored value.
			mat.emission_energy_multiplier = _bases[path]
		materials.append(mat)
	SignalBus.beat.connect(_on_beat)
	apply_accessibility()

func _exit_tree() -> void:
	for mat in materials:
		_kill_tween(mat)
		mat.emission_energy_multiplier = base_of(mat)
	_dropout_left.clear()

## The authored energy of a trim material.
func base_of(mat: StandardMaterial3D) -> float:
	return float(_bases.get(mat.resource_path, mat.emission_energy_multiplier))

## V12: re-reads the Reduce Flashes option (a dropout in flight is allowed to finish).
func apply_accessibility() -> void:
	reduced = GameManager.reduce_flashes()

## The beat boost for the current accessibility setting.
func pulse_boost() -> float:
	return REDUCED_PULSE_BOOST if reduced else PULSE_BOOST

func _on_beat(layer: String, _beat_index: int) -> void:
	if layer == "primary":
		apply_accessibility()
		pulse()

## +30 % (+10 % with Reduce Flashes) on every trim, tweening back to the base over PULSE_SECONDS (a trim in a dropout skips it).
func pulse() -> void:
	pulses += 1
	for mat in materials:
		if _dropout_left.has(mat):
			continue
		var base := base_of(mat)
		_kill_tween(mat)
		mat.emission_energy_multiplier = base * (1.0 + pulse_boost())
		var tween := create_tween()
		tween.tween_property(mat, "emission_energy_multiplier", base, PULSE_SECONDS).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
		_tweens[mat] = tween

## Cuts one trim to DROPOUT_LEVEL for DROPOUT_SECONDS.
func drop_out(mat: StandardMaterial3D) -> void:
	if reduced:
		return # V12: no failing-tube strobing with Reduce Flashes
	dropouts += 1
	_kill_tween(mat)
	_dropout_left[mat] = DROPOUT_SECONDS
	mat.emission_energy_multiplier = base_of(mat) * DROPOUT_LEVEL

func _process(delta: float) -> void:
	for mat in materials:
		if _dropout_left.has(mat):
			_dropout_left[mat] -= delta
			if _dropout_left[mat] <= 0.0:
				_dropout_left.erase(mat)
				mat.emission_energy_multiplier = base_of(mat)
		elif dropouts_enabled and not reduced and rng.randf() < delta / DROPOUT_MEAN_SECONDS:
			drop_out(mat)

func _kill_tween(mat: StandardMaterial3D) -> void:
	var tween = _tweens.get(mat)
	if tween and (tween as Tween).is_valid():
		(tween as Tween).kill()
	_tweens.erase(mat)
