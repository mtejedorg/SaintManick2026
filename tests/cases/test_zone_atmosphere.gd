extends "res://tests/framework/test_case.gd"

# preload by path: a brand-new class_name is not in the global class cache until the next editor/import pass.
const Atmo = preload("res://levels/components/zone_atmosphere.gd")

# C5: zone_entered drives the ONE Environment's ambient + volumetric fog from a table.

var _holder: WorldEnvironment
var _atmo

func before_each() -> void:
	_holder = WorldEnvironment.new()
	_holder.environment = Environment.new()
	_atmo = Atmo.new()
	_holder.add_child(_atmo)
	add_child(_holder) # _ready runs: duplicates the Environment, connects zone_entered

func after_each() -> void:
	super.after_each()
	if is_instance_valid(_holder):
		_holder.free()

func test_lookup_returns_the_zone_5_palette() -> void:
	var z5 := Atmo.get_atmosphere(5)
	assert_eq(z5["ambient"], Color("#120F24"), "Zone 5 ambient")
	assert_eq(z5["fog_albedo"], Color("#2A1A5A"), "Zone 5 fog albedo")
	assert_almost_eq(z5["density"], 0.048, 0.00001, "Zone 5 fog density")
	var fog: Color = z5["fog_albedo"]
	var emission: Color = z5["fog_emission"]
	assert_almost_eq(emission.r, fog.r * 0.4, 0.00001, "Fog emission is 40% of fog albedo (r)")
	assert_almost_eq(emission.b, fog.b * 0.4, 0.00001, "Fog emission is 40% of fog albedo (b)")

func test_all_ten_zones_are_defined_and_unknown_zones_are_empty() -> void:
	for zone in range(1, 11):
		assert_false(Atmo.get_atmosphere(zone).is_empty(), "Zone %d needs an atmosphere" % zone)
	assert_true(Atmo.get_atmosphere(11).is_empty(), "No zone 11")
	assert_true(Atmo.get_atmosphere(0).is_empty(), "No zone 0")

func test_zone_number_parses_the_first_integer() -> void:
	var dash := "—"
	assert_eq(Atmo.parse_zone_number("SECTOR 05 %s NEON MARKET" % dash), 5)
	assert_eq(Atmo.parse_zone_number("SECTOR 10 %s THE HEADLINER" % dash), 10)
	assert_eq(Atmo.parse_zone_number("SECTOR 08 %s ESCAPE" % dash), 8)
	assert_eq(Atmo.parse_zone_number("no digits here"), -1)

func test_zone_entered_targets_the_entered_zones_values_and_tweens_the_environment() -> void:
	SignalBus.zone_entered.emit("SECTOR 05 — X")
	assert_eq(_atmo.current_zone, 5, "zone_entered should select Zone 5")
	assert_eq(_atmo.target_atmosphere["ambient"], Color("#120F24"), "Tween target is the Zone 5 ambient")
	assert_eq(_atmo.target_atmosphere["fog_albedo"], Color("#2A1A5A"), "Tween target is the Zone 5 fog")
	assert_not_null(_atmo.active_tween, "A tween should be running")
	# Fast-forward the tween instead of waiting 1.5 s.
	_atmo.active_tween.custom_step(Atmo.TWEEN_TIME + 0.1)
	var env := _holder.environment
	assert_eq(env.ambient_light_color, Color("#120F24"), "Environment ambient reaches Zone 5")
	assert_eq(env.volumetric_fog_albedo, Color("#2A1A5A"), "Environment fog albedo reaches Zone 5")
	assert_almost_eq(env.volumetric_fog_density, 0.048, 0.00001, "Environment fog density reaches Zone 5")

func test_private_environment_copy_leaves_the_authored_resource_untouched() -> void:
	var authored := Environment.new()
	authored.volumetric_fog_density = 0.5
	var holder := WorldEnvironment.new()
	holder.environment = authored
	var atmo = Atmo.new()
	holder.add_child(atmo)
	add_child(holder)
	atmo.apply_zone(10, true)
	assert_almost_eq(authored.volumetric_fog_density, 0.5, 0.00001, "The scene's cached Environment must not be mutated")
	assert_true(holder.environment != authored, "The WorldEnvironment drives a private copy")
	holder.free()
