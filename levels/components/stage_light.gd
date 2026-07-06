class_name StageLight
extends OmniLight3D

## Zone 10 beat-animated stage lighting (M13, GDD §2.2 zone lighting identity /
## §1.3 "the beat as the world's heartbeat"). Pulses energy and cycles through a neon
## color palette on every beat, with a stronger flash on downbeats — matches the HUD's
## own beat_pulse visual language (hud.gd _on_beat/_on_downbeat).

@export var base_energy: float = 2.0
@export var beat_energy_boost: float = 1.5
@export var downbeat_energy_boost: float = 3.0
@export var palette: Array[Color] = [
	Color(0.0, 0.949, 1.0),   # cyan
	Color(1.0, 0.0, 0.667),   # magenta
	Color(1.0, 1.0, 1.0),     # white
]

var _palette_index: int = 0

func _ready() -> void:
	light_energy = base_energy
	light_color = palette[0] if not palette.is_empty() else Color.WHITE
	SignalBus.beat.connect(_on_beat)
	SignalBus.downbeat.connect(_on_downbeat)

func _on_beat(layer: String, _beat_index: int) -> void:
	if layer != "primary":
		return
	_pulse(beat_energy_boost, 0.2)

func _on_downbeat(layer: String, _measure_index: int) -> void:
	if layer != "primary":
		return
	if not palette.is_empty():
		_palette_index = (_palette_index + 1) % palette.size()
		light_color = palette[_palette_index]
	_pulse(downbeat_energy_boost, 0.35)

func _pulse(boost: float, duration: float) -> void:
	var tween = create_tween()
	light_energy = base_energy + boost
	tween.tween_property(self, "light_energy", base_energy, duration).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
