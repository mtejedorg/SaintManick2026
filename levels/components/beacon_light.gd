extends Node3D

## S1 (Zone 8 escape): a rotating red warning beacon. The "Vane" child (a small emissive
## reflector) turns once every `beats_per_turn` beats at the current tempo, and the "Glow"
## OmniLight flares on every primary beat and decays. Pure dressing: no collision, no
## gameplay -- tempo comes from SignalBus.tempo_changed, never from an audio clock.

@export var beats_per_turn: float = 2.0
@export var flare_boost: float = 1.5
@export var flare_seconds: float = 0.25

var _bpm: float = 128.0
var _base_energy: float = 0.0
var _vane: Node3D = null
var _glow: OmniLight3D = null

func _ready() -> void:
	_vane = get_node_or_null("Vane") as Node3D
	_glow = get_node_or_null("Glow") as OmniLight3D
	if _glow:
		_base_energy = _glow.light_energy
	var tempo: Variant = Conductor.get("bpm") if Conductor else null
	if tempo is float and tempo > 0.0:
		_bpm = tempo
	SignalBus.beat.connect(_on_beat)
	SignalBus.tempo_changed.connect(_on_tempo_changed)

func _process(delta: float) -> void:
	if _vane == null or beats_per_turn <= 0.0:
		return
	_vane.rotate_y(TAU * delta * _bpm / (60.0 * beats_per_turn))

func _on_tempo_changed(new_bpm: float) -> void:
	if new_bpm > 0.0:
		_bpm = new_bpm

func _on_beat(layer: String, _beat_index: int) -> void:
	if layer != "primary" or _glow == null:
		return
	_glow.light_energy = _base_energy + flare_boost
	_glow.create_tween().tween_property(_glow, "light_energy", _base_energy, flare_seconds).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
