extends CanvasLayer

## Drone-feed VCR overlay (M10, GDD §6.2): constant faint scanlines + a vignette, and
## chromatic-aberration/glitch bursts on player damage or a Nier-style camera perspective
## shift. Screen-space canvas_item shader (assets/shaders/vcr_overlay.gdshader) — no
## spatial depth buffer involved.

@export var burst_strength: float = 0.035
@export var burst_duration: float = 0.45
## V6: heavy hits / finishers (damage amount >= KILL_BURST_AMOUNT) and boss kills give a small
## 0.4x aberration burst over 0.12 s.
const KILL_BURST_AMOUNT: float = 32.0
const KILL_BURST_FACTOR: float = 0.4
const KILL_BURST_SECONDS: float = 0.12

@onready var overlay_rect: ColorRect = $OverlayRect

var _material: ShaderMaterial
var _burst_timer: float = 0.0
## Strength passed to the last trigger_burst(); the decay rate (units/sec) is derived
## from it so every burst fades linearly to 0 over its own duration.
var _burst_peak: float = 0.0
var _burst_total: float = 0.0
## Q5: burst_strength as authored, restored when the VCR option is switched back on.
var _authored_burst_strength: float = 0.0

func _ready() -> void:
	# load() caches and shares .tres resources across every instance — duplicate so each
	# VcrOverlay owns its own aberration_strength state instead of fighting other
	# instances (and test runs) over the same shared ShaderMaterial.
	var shared_material = overlay_rect.material as ShaderMaterial
	_material = shared_material.duplicate() as ShaderMaterial
	overlay_rect.material = _material
	SignalBus.player_damaged.connect(_on_player_damaged)
	SignalBus.camera_shift_requested.connect(_on_camera_shift_requested)
	SignalBus.player_hit_landed.connect(_on_player_hit_landed)
	SignalBus.boss_died.connect(_on_boss_died)
	_authored_burst_strength = burst_strength
	apply_accessibility()

## Q5 (accessibility): with GameManager.vcr_enabled() false the feed is clean -- no burst
## strength and the overlay hidden. Re-run it when the option changes.
func apply_accessibility() -> void:
	var gm := get_node_or_null("/root/GameManager")
	var enabled: bool = true
	if gm and gm.has_method("vcr_enabled"):
		enabled = bool(gm.vcr_enabled())
	if not enabled:
		burst_strength = 0.0
		if _material:
			_material.set_shader_parameter("aberration_strength", 0.0)
		_burst_timer = 0.0
	else:
		burst_strength = _authored_burst_strength
	visible = enabled
	if overlay_rect:
		overlay_rect.visible = enabled

func _process(delta: float) -> void:
	if not _material:
		return
	if _burst_timer > 0.0:
		_burst_timer -= delta
		var current: float = _material.get_shader_parameter("aberration_strength")
		var decay_rate: float = _burst_peak / maxf(_burst_total, 0.001)
		var decayed: float = maxf(0.0, current - decay_rate * delta)
		if _burst_timer <= 0.0:
			decayed = 0.0
		_material.set_shader_parameter("aberration_strength", decayed)

func _on_player_damaged(_damage_info: DamageInfo) -> void:
	apply_accessibility() # Q5: an option changed mid-run applies from the next burst on
	trigger_burst(burst_strength, burst_duration)

func _on_player_hit_landed(damage_info: DamageInfo) -> void:
	if damage_info != null and damage_info.amount >= KILL_BURST_AMOUNT:
		_impact_burst()

func _on_boss_died() -> void:
	_impact_burst()

## V6: a small burst that never cuts a stronger one still decaying (a damage burst).
func _impact_burst() -> void:
	apply_accessibility()
	var strength := burst_strength * KILL_BURST_FACTOR
	if strength <= 0.0 or not _material:
		return
	if _burst_timer > 0.0 and float(_material.get_shader_parameter("aberration_strength")) >= strength:
		return
	trigger_burst(strength, KILL_BURST_SECONDS)

func _on_camera_shift_requested(_top_down: bool, _target_path: Path3D, _transition_time: float) -> void:
	apply_accessibility()
	trigger_burst(burst_strength, burst_duration)

## Spikes chromatic aberration to `strength`, then lets _process() decay it back to 0
## over roughly `duration` seconds. Exposed as its own method so tests and other systems
## can trigger a burst directly.
func trigger_burst(strength: float, duration: float) -> void:
	if not _material:
		return
	_material.set_shader_parameter("aberration_strength", strength)
	_burst_peak = strength
	_burst_total = duration
	_burst_timer = duration
