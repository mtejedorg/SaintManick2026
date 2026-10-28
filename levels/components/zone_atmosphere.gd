class_name ZoneAtmosphere
extends Node

## Per-zone atmosphere (C5). The slice has ONE Environment; on `SignalBus.zone_entered` this
## tweens that single resource's ambient colour and volumetric fog (albedo / emission /
## density) to the entered zone's palette over TWEEN_TIME seconds, so each sector keeps a
## distinct identity without swapping Environment resources mid-fight (a swap would pop).
##
## Ambient colours were lifted x1.5 in G1 so walkable surfaces stay legible (the sun and
## ambient energy alone were undone by this per-zone tween).
##
## Factory (1-4) is warm/industrial haze, Neon District (5-10) is saturated magenta/cyan.
## Fog emission is always FOG_EMISSION_RATIO of the fog albedo: a self-glow so fog never goes
## black between the neon lights and the haze reads against the void (G2: 0.1 -> 0.4).
##
## P4/P5: the same tween also drives the sky's horizon band (a private copy of the shared
## ProceduralSkyMaterial on the private Environment) and the key/rim DirectionalLights, so
## the Factory reads under a warm sodium key and the Neon District under a magenta one.

const TWEEN_TIME := 1.5
const FOG_EMISSION_RATIO := 0.4
## The ground-side horizon band follows the sky horizon at this fraction (no seam at y 0).
const GROUND_HORIZON_RATIO := 0.5

## Horizon / key / rim palettes per district (P4, P5).
const HORIZON_SODIUM := Color(0.45, 0.18, 0.04)
const HORIZON_MAGENTA := Color(0.35, 0.05, 0.35)
const HORIZON_VIOLET := Color(0.18, 0.05, 0.35)
const SUN_SODIUM := Color(1.0, 0.55, 0.2)
const SUN_MAGENTA := Color(0.9, 0.2, 0.7)
const RIM_CYAN := Color(0.0, 0.960784, 1.0)

## U5: the ambient-life emitter (vfx/ambient_particles.tscn, parented to the drone camera) per
## district: cyan dust (Zones 1-3), falling rain streaks (4-5), magenta motes (6-10). Counts stay
## inside the budget (<= 80 live ambient particles).
const AMBIENT_DUST_CYAN := Color(0.0, 0.85, 1.0)
const AMBIENT_RAIN := Color(0.6, 0.8, 1.0)
const AMBIENT_MOTE_MAGENTA := Color(1.0, 0.0, 0.667)

## zone number -> { ambient, fog (albedo), density, sky_horizon, sun_color, sun_energy,
## rim_color, rim_energy, ambient_color, ambient_amount, ambient_style ("dust"/"rain"/"mote") }
const TABLE := {
	1: {"ambient": Color("#1B120C"), "fog": Color("#3A2410"), "density": 0.04, "sky_horizon": HORIZON_SODIUM, "sun_color": SUN_SODIUM, "sun_energy": 0.9, "rim_color": RIM_CYAN, "rim_energy": 0.15, "ambient_color": AMBIENT_DUST_CYAN, "ambient_amount": 40, "ambient_style": "dust"},
	2: {"ambient": Color("#0A1B0F"), "fog": Color("#0E3A18"), "density": 0.048, "sky_horizon": HORIZON_SODIUM, "sun_color": SUN_SODIUM, "sun_energy": 0.9, "rim_color": RIM_CYAN, "rim_energy": 0.15, "ambient_color": AMBIENT_DUST_CYAN, "ambient_amount": 40, "ambient_style": "dust"},
	3: {"ambient": Color("#180C0C"), "fog": Color("#3A0F0A"), "density": 0.032, "sky_horizon": HORIZON_SODIUM, "sun_color": SUN_SODIUM, "sun_energy": 0.9, "rim_color": RIM_CYAN, "rim_energy": 0.15, "ambient_color": AMBIENT_DUST_CYAN, "ambient_amount": 40, "ambient_style": "dust"},
	4: {"ambient": Color("#1B0F1E"), "fog": Color("#5C1F6E"), "density": 0.019, "sky_horizon": HORIZON_SODIUM, "sun_color": SUN_SODIUM, "sun_energy": 0.9, "rim_color": RIM_CYAN, "rim_energy": 0.15, "ambient_color": AMBIENT_RAIN, "ambient_amount": 60, "ambient_style": "rain"},
	5: {"ambient": Color("#120F24"), "fog": Color("#2A1A5A"), "density": 0.048, "sky_horizon": HORIZON_MAGENTA, "sun_color": SUN_MAGENTA, "sun_energy": 0.7, "rim_color": RIM_CYAN, "rim_energy": 0.25, "ambient_color": AMBIENT_RAIN, "ambient_amount": 60, "ambient_style": "rain"},
	6: {"ambient": Color("#0F1227"), "fog": Color("#103A5A"), "density": 0.029, "sky_horizon": HORIZON_MAGENTA, "sun_color": SUN_MAGENTA, "sun_energy": 0.7, "rim_color": RIM_CYAN, "rim_energy": 0.25, "ambient_color": AMBIENT_MOTE_MAGENTA, "ambient_amount": 40, "ambient_style": "mote"},
	7: {"ambient": Color("#1E0C1E"), "fog": Color("#4A0A3A"), "density": 0.04, "sky_horizon": HORIZON_MAGENTA, "sun_color": SUN_MAGENTA, "sun_energy": 0.7, "rim_color": RIM_CYAN, "rim_energy": 0.25, "ambient_color": AMBIENT_MOTE_MAGENTA, "ambient_amount": 40, "ambient_style": "mote"},
	8: {"ambient": Color("#1E0918"), "fog": Color("#5A0A28"), "density": 0.032, "sky_horizon": HORIZON_MAGENTA, "sun_color": SUN_MAGENTA, "sun_energy": 0.7, "rim_color": RIM_CYAN, "rim_energy": 0.25, "ambient_color": AMBIENT_MOTE_MAGENTA, "ambient_amount": 40, "ambient_style": "mote"},
	9: {"ambient": Color("#090F1E"), "fog": Color("#1A2A5A"), "density": 0.019, "sky_horizon": HORIZON_VIOLET, "sun_color": SUN_MAGENTA, "sun_energy": 0.7, "rim_color": RIM_CYAN, "rim_energy": 0.25, "ambient_color": AMBIENT_MOTE_MAGENTA, "ambient_amount": 40, "ambient_style": "mote"},
	10: {"ambient": Color("#0F091E"), "fog": Color("#301040"), "density": 0.056, "sky_horizon": HORIZON_VIOLET, "sun_color": SUN_MAGENTA, "sun_energy": 0.7, "rim_color": RIM_CYAN, "rim_energy": 0.25, "ambient_color": AMBIENT_MOTE_MAGENTA, "ambient_amount": 40, "ambient_style": "mote"},
}

## The WorldEnvironment whose Environment is driven. Defaults to this node's parent.
@export var world_environment: WorldEnvironment
## P5: the key light (tinted per district) and the cyan rim fill. Optional.
@export var sun_light: DirectionalLight3D
@export var rim_light: DirectionalLight3D

var environment: Environment
## P4: the private copy of the sky material on the private Environment (null without a
## ProceduralSkyMaterial).
var sky_material: ProceduralSkyMaterial
var current_zone: int = 0
## The values the running (or last) tween is heading for: ambient, fog_albedo, fog_emission, density.
var target_atmosphere: Dictionary = {}
var active_tween: Tween

func _ready() -> void:
	if world_environment == null:
		world_environment = get_parent() as WorldEnvironment
	if world_environment == null or world_environment.environment == null:
		push_warning("ZoneAtmosphere: no WorldEnvironment/Environment to drive.")
		return
	# The Environment is a sub-resource of the cached scene: work on a private copy so a
	# reloaded run starts from the authored values, not from wherever the last run ended.
	environment = world_environment.environment.duplicate() as Environment
	# The sky is a shared sub-resource too: give the private Environment its own Sky and sky
	# material so the horizon tween never writes into the cached scene resource.
	if environment.sky:
		var sky := environment.sky.duplicate() as Sky
		if sky.sky_material is ProceduralSkyMaterial:
			sky.sky_material = sky.sky_material.duplicate()
			sky_material = sky.sky_material as ProceduralSkyMaterial
		environment.sky = sky
	world_environment.environment = environment
	SignalBus.zone_entered.connect(_on_zone_entered)
	apply_zone(1, true)

## First integer in a zone name ("SECTOR 05 - MARKET" -> 5); -1 if there is none.
static func parse_zone_number(zone_name: String) -> int:
	var digits := ""
	for ch in zone_name:
		if ch >= "0" and ch <= "9":
			digits += ch
		elif digits != "":
			break
	return int(digits) if digits != "" else -1

## Table lookup: { ambient, fog_albedo, fog_emission, density, sky_horizon, ground_horizon,
## sun_color, sun_energy, rim_color, rim_energy, ambient_color, ambient_amount, ambient_style },
## or {} for an unknown zone.
static func get_atmosphere(zone: int) -> Dictionary:
	if not TABLE.has(zone):
		return {}
	var row: Dictionary = TABLE[zone]
	var fog: Color = row["fog"]
	var horizon: Color = row["sky_horizon"]
	return {
		"ambient": row["ambient"],
		"fog_albedo": fog,
		"fog_emission": Color(fog.r * FOG_EMISSION_RATIO, fog.g * FOG_EMISSION_RATIO, fog.b * FOG_EMISSION_RATIO, 1.0),
		"density": row["density"],
		"sky_horizon": horizon,
		"ground_horizon": Color(horizon.r * GROUND_HORIZON_RATIO, horizon.g * GROUND_HORIZON_RATIO, horizon.b * GROUND_HORIZON_RATIO, 1.0),
		"sun_color": row["sun_color"],
		"sun_energy": row["sun_energy"],
		"rim_color": row["rim_color"],
		"rim_energy": row["rim_energy"],
		"ambient_color": row["ambient_color"],
		"ambient_amount": row["ambient_amount"],
		"ambient_style": row["ambient_style"],
	}

func _on_zone_entered(zone_name: String) -> void:
	apply_zone(parse_zone_number(zone_name))

## Tween (or, with `instant`, snap) the Environment to a zone's atmosphere.
func apply_zone(zone: int, instant: bool = false) -> void:
	var atmosphere := get_atmosphere(zone)
	if atmosphere.is_empty() or environment == null:
		return
	current_zone = zone
	target_atmosphere = atmosphere
	if active_tween:
		active_tween.kill()
		active_tween = null
	var targets := _targets(atmosphere)
	if instant:
		for target in targets:
			(target[0] as Object).set(target[1], target[2])
		return
	active_tween = create_tween().set_parallel(true).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
	for target in targets:
		active_tween.tween_property(target[0], target[1], target[2], TWEEN_TIME)

## [object, property, value] for everything a zone's atmosphere drives (the sky and the
## lights only when they exist).
func _targets(atmosphere: Dictionary) -> Array:
	var targets: Array = [
		[environment, "ambient_light_color", atmosphere["ambient"]],
		[environment, "volumetric_fog_albedo", atmosphere["fog_albedo"]],
		[environment, "volumetric_fog_emission", atmosphere["fog_emission"]],
		[environment, "volumetric_fog_density", atmosphere["density"]],
	]
	if sky_material:
		targets.append([sky_material, "sky_horizon_color", atmosphere["sky_horizon"]])
		targets.append([sky_material, "ground_horizon_color", atmosphere["ground_horizon"]])
	if sun_light:
		targets.append([sun_light, "light_color", atmosphere["sun_color"]])
		targets.append([sun_light, "light_energy", atmosphere["sun_energy"]])
	if rim_light:
		targets.append([rim_light, "light_color", atmosphere["rim_color"]])
		targets.append([rim_light, "light_energy", atmosphere["rim_energy"]])
	return targets
