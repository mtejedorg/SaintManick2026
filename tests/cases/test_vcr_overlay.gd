extends "res://tests/framework/test_case.gd"

var overlay: CanvasLayer

func before_each() -> void:
	overlay = load("res://ui/vcr/vcr_overlay.tscn").instantiate()
	add_child(overlay)
	# Test framework's after_each() disconnects ALL SignalBus connections — reconnect
	# what vcr_overlay.gd wires in _ready().
	if not SignalBus.player_damaged.is_connected(overlay._on_player_damaged):
		SignalBus.player_damaged.connect(overlay._on_player_damaged)
	if not SignalBus.camera_shift_requested.is_connected(overlay._on_camera_shift_requested):
		SignalBus.camera_shift_requested.connect(overlay._on_camera_shift_requested)

func after_each() -> void:
	if is_instance_valid(overlay):
		overlay.queue_free()

func test_trigger_burst_sets_aberration_strength() -> void:
	var material: ShaderMaterial = overlay.get_node("OverlayRect").material
	assert_eq(material.get_shader_parameter("aberration_strength"), 0.0, "Should start with no aberration")

	overlay.trigger_burst(0.02, 0.35)

	assert_eq(material.get_shader_parameter("aberration_strength"), 0.02, "Burst should set aberration_strength")

func test_burst_decays_over_time() -> void:
	var material: ShaderMaterial = overlay.get_node("OverlayRect").material
	overlay.trigger_burst(0.02, 0.35)
	assert_eq(material.get_shader_parameter("aberration_strength"), 0.02)

	overlay._process(0.1)
	var decayed = material.get_shader_parameter("aberration_strength")
	assert_lt(decayed, 0.02, "Aberration should decay over time")
	assert_gt(decayed, 0.0, "Burst should still be visible after 0.1s (fades over its duration, not in one frame)")

	overlay._process(1.0)
	assert_eq(material.get_shader_parameter("aberration_strength"), 0.0, "Aberration should not go negative")

func test_player_damaged_triggers_burst() -> void:
	var material: ShaderMaterial = overlay.get_node("OverlayRect").material
	assert_eq(material.get_shader_parameter("aberration_strength"), 0.0)

	var dmg_info = DamageInfo.new()
	dmg_info.amount = 10.0
	SignalBus.player_damaged.emit(dmg_info)

	assert_gt(material.get_shader_parameter("aberration_strength"), 0.0, "player_damaged should trigger a VCR burst")

func test_camera_shift_triggers_burst() -> void:
	var material: ShaderMaterial = overlay.get_node("OverlayRect").material
	assert_eq(material.get_shader_parameter("aberration_strength"), 0.0)

	SignalBus.camera_shift_requested.emit(true, null, 1.5)

	assert_gt(material.get_shader_parameter("aberration_strength"), 0.0, "camera_shift_requested should trigger a VCR burst")
