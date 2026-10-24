class_name ZoneAtmosphere
extends Node

## Per-zone atmosphere (C5). The slice has ONE Environment; on `SignalBus.zone_entered` this
## tweens that single resource's ambient colour and volumetric fog (albedo / emission /
## density) to the entered zone's palette over TWEEN_TIME seconds, so each sector keeps a
## distinct identity without swapping Environment resources mid-fight (a swap would pop).
##
## Factory (1-4) is warm/industrial haze, Neon District (5-10) is saturated magenta/cyan.
## Fog emission is always FOG_EMISSION_RATIO of the fog albedo: a faint self-glow so fog
## never goes fully black between the neon lights.

const TWEEN_TIME := 1.5
const FOG_EMISSION_RATIO := 0.1

## zone number -> { ambient, fog (albedo), density }
const TABLE := {
	1: {"ambient": Color("#120C08"), "fog": Color("#3A2410"), "density": 0.025},
	2: {"ambient": Color("#07120A"), "fog": Color("#0E3A18"), "density": 0.03},
	3: {"ambient": Color("#100808"), "fog": Color("#3A0F0A"), "density": 0.02},
	4: {"ambient": Color("#120A14"), "fog": Color("#5C1F6E"), "density": 0.012},
	5: {"ambient": Color("#0C0A18"), "fog": Color("#2A1A5A"), "density": 0.03},
	6: {"ambient": Color("#0A0C1A"), "fog": Color("#103A5A"), "density": 0.018},
	7: {"ambient": Color("#140814"), "fog": Color("#4A0A3A"), "density": 0.025},
	8: {"ambient": Color("#140610"), "fog": Color("#5A0A28"), "density": 0.02},
	9: {"ambient": Color("#060A14"), "fog": Color("#1A2A5A"), "density": 0.012},
	10: {"ambient": Color("#0A0614"), "fog": Color("#301040"), "density": 0.035},
}

## The WorldEnvironment whose Environment is driven. Defaults to this node's parent.
@export var world_environment: WorldEnvironment

var environment: Environment
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

## Table lookup: { ambient, fog_albedo, fog_emission, density }, or {} for an unknown zone.
static func get_atmosphere(zone: int) -> Dictionary:
	if not TABLE.has(zone):
		return {}
	var row: Dictionary = TABLE[zone]
	var fog: Color = row["fog"]
	return {
		"ambient": row["ambient"],
		"fog_albedo": fog,
		"fog_emission": Color(fog.r * FOG_EMISSION_RATIO, fog.g * FOG_EMISSION_RATIO, fog.b * FOG_EMISSION_RATIO, 1.0),
		"density": row["density"],
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
	if instant:
		environment.ambient_light_color = atmosphere["ambient"]
		environment.volumetric_fog_albedo = atmosphere["fog_albedo"]
		environment.volumetric_fog_emission = atmosphere["fog_emission"]
		environment.volumetric_fog_density = atmosphere["density"]
		return
	active_tween = create_tween().set_parallel(true).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
	active_tween.tween_property(environment, "ambient_light_color", atmosphere["ambient"], TWEEN_TIME)
	active_tween.tween_property(environment, "volumetric_fog_albedo", atmosphere["fog_albedo"], TWEEN_TIME)
	active_tween.tween_property(environment, "volumetric_fog_emission", atmosphere["fog_emission"], TWEEN_TIME)
	active_tween.tween_property(environment, "volumetric_fog_density", atmosphere["density"], TWEEN_TIME)
