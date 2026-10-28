extends "res://tests/framework/test_case.gd"

## Verifies M13's per-zone lighting first pass without instantiating the full
## vertical_slice.tscn (a heavyweight scene with wave spawners/encounters/bosses whose
## _ready() side effects aren't worth triggering just to check light nodes exist).
## Reads the scene file as text instead — consistent with how C2's scene-corruption fix
## was verified via diff/grep rather than runtime instantiation.

const SCENE_PATH := "res://levels/slice/vertical_slice.tscn"

func _read_scene_text() -> String:
	var file = FileAccess.open(SCENE_PATH, FileAccess.READ)
	assert_not_null(file, "vertical_slice.tscn should be readable")
	var text = file.get_as_text()
	file.close()
	return text

func test_zone_lights_container_and_all_ten_lights_exist() -> void:
	var text = _read_scene_text()
	assert_true(text.contains("[node name=\"ZoneLights\" type=\"Node3D\" parent=\".\"]"), "ZoneLights container should exist")

	var expected_names = ["Z1_Light", "Z2_Light", "Z3_Light", "Z4_Light", "Z5_Light",
		"Z6_Light", "Z7_Light", "Z8_Light", "Z9_Light", "Z10_StageLight"]
	for light_name in expected_names:
		var header = "[node name=\"%s\" type=\"OmniLight3D\" parent=\"ZoneLights\"]" % light_name
		assert_true(text.contains(header), "Scene should declare %s as an OmniLight3D under ZoneLights" % light_name)

func test_zone_10_stage_light_wired_to_stage_light_script() -> void:
	var text = _read_scene_text()
	assert_true(text.contains("res://levels/components/stage_light.gd"), "stage_light.gd should be referenced as an ext_resource")
	# The Z10 light node block should carry the stage_light script assignment.
	var z10_index = text.find("[node name=\"Z10_StageLight\"")
	assert_gt(z10_index, -1, "Z10_StageLight node should exist")
	var next_node_index = text.find("[node name=", z10_index + 1)
	var next_connection_index = text.find("[connection", z10_index + 1)
	var block_end = text.length()
	if next_node_index != -1:
		block_end = next_node_index
	if next_connection_index != -1 and next_connection_index < block_end:
		block_end = next_connection_index
	var z10_block = text.substr(z10_index, block_end - z10_index)
	assert_true(z10_block.contains("script = ExtResource("), "Z10_StageLight should have the stage_light script assigned")

func test_zone_10_stage_light_pulses_on_beat() -> void:
	var stage_light = load("res://levels/components/stage_light.gd").new()
	add_child(stage_light)
	stage_light.base_energy = 2.0
	stage_light.light_energy = 2.0

	if not SignalBus.beat.is_connected(stage_light._on_beat):
		SignalBus.beat.connect(stage_light._on_beat)
	if not SignalBus.downbeat.is_connected(stage_light._on_downbeat):
		SignalBus.downbeat.connect(stage_light._on_downbeat)

	stage_light._on_beat("primary", 2)
	assert_gt(stage_light.light_energy, stage_light.base_energy, "A beat should spike the stage light's energy above baseline")

	stage_light.queue_free()

func test_zone_10_stage_light_cycles_palette_on_downbeat() -> void:
	var stage_light = load("res://levels/components/stage_light.gd").new()
	add_child(stage_light)
	# add_child already ran _ready(): the initial palette[0] colour is in place (V6: no re-ready).

	if not SignalBus.downbeat.is_connected(stage_light._on_downbeat):
		SignalBus.downbeat.connect(stage_light._on_downbeat)

	var first_color = stage_light.light_color
	stage_light._on_downbeat("primary", 1)
	var second_color = stage_light.light_color

	assert_true(first_color != second_color, "Downbeat should cycle the stage light to the next palette color")

	stage_light.queue_free()

# C5: the recoloured / extended light coverage.
func _node_block(text: String, node_name: String) -> String:
	var i := text.find("[node name=\"%s\"" % node_name)
	assert_gt(i, -1, "%s should exist" % node_name)
	var j := text.find("[node name=", i + 1)
	var k := text.find("[connection", i + 1)
	var end := text.length()
	if j != -1:
		end = j
	if k != -1 and k < end:
		end = k
	return text.substr(i, end - i)

func test_zone_light_coverage_additions_exist() -> void:
	var text := _read_scene_text()
	for light_name in ["Z1_AccentLight", "Z2_PitLight1", "Z2_PistonLight6", "Z4_RimLight", "Z5_LightB", "Z5_LightC",
			"Z6_EdgeLightL", "Z6_EdgeLightR", "Z7_FillLight", "Z8_LightB", "Z8_LightC", "Z9_GapLight", "Z9_ElevatorLight"]:
		assert_true(text.contains("[node name=\"%s\" type=\"OmniLight3D\"" % light_name), "%s should be declared" % light_name)

func test_zone_3_and_8_lights_pulse_with_the_beat() -> void:
	var text := _read_scene_text()
	for light_name in ["Z3_Light", "Z8_Light", "Z8_LightB", "Z8_LightC", "Z2_PistonLight1"]:
		assert_true(_node_block(text, light_name).contains("script = ExtResource(\"35_stage_light\")"), "%s should use stage_light.gd" % light_name)

func test_zone_10_has_two_volumetric_spotlights() -> void:
	var text := _read_scene_text()
	for spot_name in ["Z10_SpotL", "Z10_SpotR"]:
		var block := _node_block(text, spot_name)
		assert_true(block.contains("type=\"SpotLight3D\""), "%s is a SpotLight3D" % spot_name)
		assert_true(block.contains("spot_angle = 16.0"), "%s cone angle" % spot_name)
		assert_true(block.contains("light_volumetric_fog_energy = 4.0"), "%s should light the volumetric fog" % spot_name)

func test_zone_atmosphere_node_is_wired_under_world_environment() -> void:
	var text := _read_scene_text()
	assert_true(text.contains("[node name=\"ZoneAtmosphere\" type=\"Node\" parent=\"WorldEnvironment\""), "ZoneAtmosphere should be a child of WorldEnvironment")
	assert_true(text.contains("res://levels/components/zone_atmosphere.gd"), "zone_atmosphere.gd should be referenced")
