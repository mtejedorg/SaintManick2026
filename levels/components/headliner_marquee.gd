extends Label3D

## S3 (Zone 10 stage): "THE HEADLINER" over the stage -- amber while the show runs, magenta
## once the boss reaches phase 2. The boss script is read, never changed: every
## boss_health_changed re-reads its `phase_2_triggered` flag, boss_reset puts the amber back.

@export var headliner: Node
@export var calm_color: Color = Color(1.0, 0.55, 0.1)
@export var phase_2_color: Color = Color(1.0, 0.0, 0.666667)
## HDR multiplier so the unshaded label blooms past glow_hdr_threshold.
@export var glow_boost: float = 1.8

var is_phase_2: bool = false

func _ready() -> void:
	_apply(false)
	SignalBus.boss_health_changed.connect(_on_boss_health_changed)
	SignalBus.boss_reset.connect(_on_boss_reset)

func _on_boss_health_changed(_current: int, _maximum: int) -> void:
	if headliner and is_instance_valid(headliner) and headliner.get("phase_2_triggered") == true:
		_apply(true)

func _on_boss_reset() -> void:
	_apply(false)

func _apply(phase_2: bool) -> void:
	is_phase_2 = phase_2
	var c := phase_2_color if phase_2 else calm_color
	modulate = Color(c.r * glow_boost, c.g * glow_boost, c.b * glow_boost, 1.0)
	outline_modulate = Color(c.r * 0.35, c.g * 0.35, c.b * 0.35, 1.0)
