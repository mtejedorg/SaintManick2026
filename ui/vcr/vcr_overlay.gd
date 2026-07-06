extends CanvasLayer

## Drone-feed VCR overlay (M10, GDD §6.2): constant faint scanlines + a vignette, and
## chromatic-aberration/glitch bursts on player damage or a Nier-style camera perspective
## shift. Screen-space canvas_item shader (assets/shaders/vcr_overlay.gdshader) — no
## spatial depth buffer involved.

@export var burst_strength: float = 0.02
@export var burst_duration: float = 0.35
## How fast the aberration decays back to 0 once a burst fires, in units/sec.
@export var burst_decay_rate: float = 0.08

@onready var overlay_rect: ColorRect = $OverlayRect

var _material: ShaderMaterial
var _burst_timer: float = 0.0

func _ready() -> void:
	# load() caches and shares .tres resources across every instance — duplicate so each
	# VcrOverlay owns its own aberration_strength state instead of fighting other
	# instances (and test runs) over the same shared ShaderMaterial.
	var shared_material = overlay_rect.material as ShaderMaterial
	_material = shared_material.duplicate() as ShaderMaterial
	overlay_rect.material = _material
	SignalBus.player_damaged.connect(_on_player_damaged)
	SignalBus.camera_shift_requested.connect(_on_camera_shift_requested)

func _process(delta: float) -> void:
	if not _material:
		return
	if _burst_timer > 0.0:
		_burst_timer -= delta
		var current = _material.get_shader_parameter("aberration_strength")
		var decayed = max(0.0, current - burst_decay_rate)
		_material.set_shader_parameter("aberration_strength", decayed)

func _on_player_damaged(_damage_info: DamageInfo) -> void:
	trigger_burst(burst_strength, burst_duration)

func _on_camera_shift_requested(_top_down: bool, _target_path: Path3D, _transition_time: float) -> void:
	trigger_burst(burst_strength, burst_duration)

## Spikes chromatic aberration to `strength`, then lets _process() decay it back to 0
## over roughly `duration` seconds. Exposed as its own method so tests and other systems
## can trigger a burst directly.
func trigger_burst(strength: float, duration: float) -> void:
	if not _material:
		return
	_material.set_shader_parameter("aberration_strength", strength)
	_burst_timer = duration
