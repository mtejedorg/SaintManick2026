extends "res://tests/framework/test_case.gd"

# C10: the Zone 8 kill wall was authored ahead of the Enforcer arena and bit Nick before the
# escape even began, never followed him after a respawn, and had no visible body.

const SLICE_PATH := "res://levels/slice/vertical_slice.tscn"

var _player: Node3D
var _seq: EscapeSequence
var _wall: EscapeKillWall
var _end: Area3D

func before_each() -> void:
	GameManager.is_test = true
	_player = load("res://characters/player/player.tscn").instantiate()
	_player.name = "Player"
	get_tree().current_scene.add_child(_player)
	_player.global_position = Vector3(262.0, -3.0, 0.0)

	_wall = EscapeKillWall.new()
	_wall.monitoring = false # as authored in the slice
	_end = Area3D.new()
	_seq = EscapeSequence.new()
	_seq.kill_wall = _wall
	_seq.end_trigger = _end
	add_child(_seq)
	add_child(_wall)
	add_child(_end)
	_wall.global_position = Vector3(275.0, -4.0, 0.0)
	_end.global_position = Vector3(398.0, -4.0, 0.0) # L4: the ~120 m course

func after_each() -> void:
	super.after_each()
	# free() immediately: a lingering "Player" child would name-clash with the next test's.
	if is_instance_valid(_player):
		_player.free()
	for n in [_seq, _wall, _end]:
		if is_instance_valid(n):
			n.free()

func test_wall_is_dormant_in_the_authored_scene() -> void:
	var slice: Node3D = (load(SLICE_PATH) as PackedScene).instantiate()
	add_child(slice)
	var wall: Area3D = slice.get_node("EscapeSequence/EscapeKillWall")
	assert_false(wall.monitoring, "The kill wall must not hurt anyone before the escape starts")
	slice.free()

func test_wall_parks_ten_metres_behind_nick_when_the_escape_starts() -> void:
	SignalBus.miniboss_defeated.emit()
	assert_true(_seq.is_active, "Escape should be active")
	assert_true(_wall.is_moving, "Wall should be moving")
	assert_almost_eq(_wall.global_position.x, 252.0, 0.001, "Wall starts 10 m behind Nick (x=262), not at its authored x=275")

func test_respawn_reparks_the_wall_behind_the_checkpoint_and_keeps_it_moving() -> void:
	SignalBus.miniboss_defeated.emit()
	_wall.global_position.x = 300.0
	GameManager.checkpoint_position = Vector3(281.0, -3.0, 0.0)
	SignalBus.player_respawned.emit()
	assert_almost_eq(_wall.global_position.x, 271.0, 0.001, "Wall resets to checkpoint x - 10")
	assert_true(_wall.is_moving, "Wall keeps chasing after a respawn")

func test_respawn_before_the_escape_leaves_the_wall_alone() -> void:
	GameManager.checkpoint_position = Vector3(50.0, 0.0, 0.0)
	SignalBus.player_respawned.emit()
	assert_eq(_wall.global_position.x, 275.0, "No escape yet: respawning must not move the wall")

func test_wall_stops_once_it_passes_the_end_trigger() -> void:
	SignalBus.miniboss_defeated.emit()
	_wall.global_position.x = 399.0
	_seq._physics_process(0.016)
	assert_false(_wall.is_moving, "Wall stops after sweeping past the exit")

func test_each_damage_beat_shakes_the_camera() -> void:
	var flags := {"shakes": 0}
	# Count only the wall's own (0.1, 0.2) shake: Nick's damage reaction adds its own.
	var on_shake := func(strength, duration): if is_equal_approx(strength, 0.1) and is_equal_approx(duration, 0.2): flags.shakes += 1
	SignalBus.camera_shake_requested.connect(on_shake)
	_wall._on_body_entered(_player)
	_wall._on_beat("primary", 1)
	# >= 2: Nick's own damage feedback (F6) adds a shake per hit taken on top of the wall's.
	assert_true(flags.shakes >= 2, "Entering and each damage beat should both shake the camera")
	SignalBus.camera_shake_requested.disconnect(on_shake)

func test_respawn_mid_escape_puts_nick_and_his_checkpoint_on_path_z8() -> void:
	var path_z7 := Path3D.new()
	var path_z8 := Path3D.new()
	add_child(path_z7)
	add_child(path_z8)
	_seq.path_z8 = path_z8
	_player.current_path = path_z7
	GameManager.checkpoint_path = path_z7
	GameManager.checkpoint_top_down = true
	SignalBus.miniboss_defeated.emit()
	GameManager.checkpoint_position = Vector3(270.0, -3.0, 0.0)
	SignalBus.player_respawned.emit()
	assert_eq(_player.current_path, path_z8, "Escape active + respawn: Nick walks Path_Z8")
	assert_eq(GameManager.checkpoint_path, path_z8, "...and so does his checkpoint")
	assert_false(GameManager.checkpoint_top_down, "...in side-scroll")
	path_z7.free()
	path_z8.free()

func test_wall_glow_is_hidden_until_the_chase_starts_and_after_it_ends() -> void:
	var body := MeshInstance3D.new()
	body.name = "WallMesh"
	var core := MeshInstance3D.new()
	core.name = "HotCore"
	_wall.add_child(body)
	_wall.add_child(core)
	_wall._set_body_visible(false)
	assert_false(body.visible or core.visible, "Dormant wall must not glow")
	_wall.start_moving()
	assert_true(body.visible and core.visible, "Chase start shows the wall")
	_wall.stop_moving()
	assert_false(body.visible or core.visible, "Parked wall is hidden again")
