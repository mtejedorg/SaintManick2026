extends "res://tests/framework/test_case.gd"

# Batch R (round-4): the rigged body on Runner and Bruiser (R1), the enemy animator (R2) and
# segment playback for Nick's swings (R3). R4 (Enforcer stray bars) is checked in the capture.

const RUNNER := "res://characters/enemies/runner/runner.tscn"
const BRUISER := "res://characters/enemies/bruiser/bruiser.tscn"
const BODY := "res://characters/shared/enemy_body_visual.tscn"
const PLAYER := "res://characters/player/player.tscn"
const LIBRARY := "res://characters/player/nick_animations.tres"
const MAGENTA := Color(1, 0, 0.666667, 1)

var _nodes: Array[Node] = []

func after_each() -> void:
	super.after_each()
	for n in _nodes:
		if is_instance_valid(n):
			n.free()
	_nodes.clear()

func _keep(n: Node) -> Node:
	_nodes.append(n)
	return n

## An enemy parked far from everything with its AI off (the animator keeps running).
func _enemy(path: String, z: float) -> CharacterBody3D:
	var e: CharacterBody3D = _keep(load(path).instantiate())
	e.position = Vector3(0.0, 700.0, z)
	add_child(e)
	e.set_physics_process(false)
	return e

func _animator(e: Node) -> Node:
	return e.get_node("EnemyAnimator")

func _ap(e: Node) -> AnimationPlayer:
	return _animator(e).anim_player

func _stun_hit(seconds: float) -> DamageInfo:
	var info := DamageInfo.new()
	info.amount = 1.0
	info.knockback = 2.0
	info.stun = seconds
	return info

# --- R1 ------------------------------------------------------------------------------

func test_r1_runner_and_bruiser_wear_the_rigged_body_with_a_magenta_dark_base() -> void:
	var z := 21000.0
	for path in [RUNNER, BRUISER]:
		z += 20.0
		var e := _enemy(path, z)
		var visual: CharacterVisual = e.get_node("MeshInstance3D")
		assert_eq(visual.scene_file_path, BODY, "%s instances enemy_body_visual.tscn" % path)
		var sk := visual.find_child("Skeleton3D", true, false) as Skeleton3D
		assert_true(sk != null and sk.get_bone_count() == 33, "%s has the 33-bone Mixamo skeleton" % path)
		assert_false(visual.auto_play_clip, "%s: the visual never auto-plays the library's first clip" % path)
		assert_eq(visual.tint, MAGENTA, "%s tint is magenta" % path)
		assert_true(visual.base_material != null and visual.base_material.albedo_color.v < 0.3, "%s base stays dark" % path)
	var runner := _enemy(RUNNER, 21060.0)
	assert_eq((runner.get_node("MeshInstance3D") as CharacterVisual).get_base_rim_color(), CharacterVisual.ENEMY_RIM_COLOR, "Runner rim magenta")
	assert_almost_eq((runner.get_node("MeshInstance3D") as Node3D).scale.x, 0.95, 0.001, "Runner visual scale 0.95")
	assert_almost_eq((_enemy(BRUISER, 21080.0).get_node("MeshInstance3D") as Node3D).scale.x, 1.3, 0.001, "Bruiser keeps its 1.3 bulk")

func test_r1_the_shared_library_keeps_the_swings_one_shot() -> void:
	_enemy(RUNNER, 21090.0)
	var p: Node = _keep(load(PLAYER).instantiate())
	add_child(p)
	var lib: AnimationLibrary = load(LIBRARY)
	for key in ["attack_combo", "attack_light", "attack_heavy", "hit_react", "death", "land", "run_stop"]:
		assert_eq(lib.get_animation(key).loop_mode, Animation.LOOP_NONE, "%s stays one-shot (no auto-play loop leak)" % key)

# --- R2 ------------------------------------------------------------------------------

func test_r2_idle_at_rest_run_when_moving_with_change_edge_playback() -> void:
	var e := _enemy(RUNNER, 21100.0)
	var anim := _animator(e)
	var ap := _ap(e)
	assert_eq(String(ap.current_animation), "idle", "A grunt stands posed in idle from spawn")
	var before: int = anim.play_count
	e.velocity = Vector3(3.0, 0.0, 0.0)
	anim._physics_process(0.016)
	anim._physics_process(0.016)
	anim._physics_process(0.016)
	assert_eq(String(ap.current_animation), "run", "Moving -> run")
	assert_almost_eq(ap.get_playing_speed(), 1.15, 0.001, "Runner run at 1.15")
	assert_eq(anim.play_count, before + 1, "run started once over three frames (change-edge, no restarts)")
	e.velocity = Vector3(0.1, 0.0, 0.0)
	anim._physics_process(0.016)
	anim._physics_process(0.016)
	assert_eq(String(ap.current_animation), "idle", "Below 0.3 m/s -> idle")
	assert_eq(anim.play_count, before + 2, "idle started once")

func test_r2_bruiser_moves_heavily() -> void:
	var e := _enemy(BRUISER, 21120.0)
	var anim := _animator(e)
	assert_almost_eq(_ap(e).get_playing_speed(), 0.7, 0.001, "Bruiser idles at 0.7")
	e.velocity = Vector3(0.0, 0.0, 2.0)
	anim._physics_process(0.016)
	assert_eq(String(_ap(e).current_animation), "run")
	assert_almost_eq(_ap(e).get_playing_speed(), 0.7, 0.001, "Bruiser runs at 0.7")
	assert_eq(anim.attack_key, "attack_heavy", "Bruiser swings attack_heavy")

func test_r2_telegraph_holds_the_wind_up_then_the_strike_fits_one_beat() -> void:
	var e := _enemy(RUNNER, 21140.0)
	var anim := _animator(e)
	var ap := _ap(e)
	var window: Vector2 = anim.window_of("attack_light")
	anim.on_attack_step(1)
	assert_eq(String(ap.current_animation), "attack_light", "Telegraph plays the swing clip")
	assert_almost_eq(ap.get_playing_speed(), 0.0, 0.0001, "...frozen")
	e.velocity = Vector3(4.0, 0.0, 0.0)
	for i in 5:
		await get_tree().process_frame
	anim._physics_process(0.016)
	assert_eq(String(ap.current_animation), "attack_light", "Locomotion never overrides the held tell")
	assert_almost_eq(ap.current_animation_position, window.x, 0.001, "...held at the wind-up")
	anim.on_attack_step(2)
	var expected: float = (window.y - window.x) / (60.0 / maxf(Conductor.bpm, 1.0))
	assert_almost_eq(ap.get_playing_speed(), expected, 0.01, "The strike resumes fitted to one beat")
	assert_true(ap.get_playing_speed() <= 2.0, "...at <= 2x")

func test_r2_a_stun_plays_hit_react_fitted_to_the_stun() -> void:
	var e := _enemy(RUNNER, 21160.0)
	var ap := _ap(e)
	(e.get_node("Hurtbox3D") as Hurtbox3D).receive_hit(_stun_hit(0.4))
	assert_eq(String(ap.current_animation), "hit_react", "A stunning hit plays hit_react")
	var window: Vector2 = _animator(e).window_of("hit_react")
	assert_almost_eq(ap.get_playing_speed(), (window.y - window.x) / 0.4, 0.01, "...fitted to the 0.4 s stun")

func test_r2_death_plays_the_clip_before_the_shrink() -> void:
	var e := _enemy(RUNNER, 21180.0)
	var ap := _ap(e)
	var anim := _animator(e)
	var kill := DamageInfo.new()
	kill.amount = 9999.0
	(e.get_node("Hurtbox3D") as Hurtbox3D).receive_hit(kill)
	assert_eq(String(ap.current_animation), "death", "died -> the death clip")
	anim._physics_process(0.016)
	assert_eq(String(ap.current_animation), "death", "...and locomotion never takes over")
	var visual: Node3D = e.get_node("MeshInstance3D")
	var start_scale := visual.scale.length()
	await get_tree().create_timer(anim.death_anim_seconds * 0.8).timeout
	assert_true(is_instance_valid(e), "The body stays for the clip")
	assert_almost_eq(visual.scale.length(), start_scale, 0.001, "No shrink while the death clip plays")
	await get_tree().create_timer(0.25 + 0.3).timeout
	assert_false(is_instance_valid(e), "Freed after clip + shrink (~0.6 s)")

func test_r2_flash_telegraph_announces_the_tell() -> void:
	var e := _enemy(RUNNER, 21200.0)
	var got: Array = []
	SignalBus.enemy_telegraphed.connect(func(who: Node3D): got.append(who))
	(e.get_node("MeshInstance3D") as CharacterVisual).flash_telegraph()
	assert_eq(got.size(), 1, "enemy_telegraphed fires once")
	assert_true(got.size() == 1 and got[0] == e, "...with the enemy body")

# --- R3 ------------------------------------------------------------------------------

func _player() -> PlayerController:
	var p: PlayerController = _keep(load(PLAYER).instantiate())
	p.position = Vector3(0.0, 700.0, 21300.0)
	add_child(p)
	p.set_physics_process(false)
	p.state_machine.set_physics_process(false)
	return p

func test_r3_every_attack_segment_plays_at_2x_or_slower() -> void:
	var ctrl := _player().animation_controller
	# Shortest gameplay duration each key is fitted to (attack_durations / heavy / ComboDefs).
	var shortest := {"attack_light": 0.3, "attack_combo": 0.3, "attack_heavy": 0.45}
	for key in shortest:
		ctrl.play_fitted(key, shortest[key])
		var window: Array = PlayerAnimationController.SEGMENTS[key]
		var speed := ctrl.anim_player.get_playing_speed()
		assert_eq(String(ctrl.anim_player.current_animation), key)
		assert_true(speed <= 2.0, "%s plays at <= 2x (%.2f)" % [key, speed])
		assert_almost_eq(speed, (window[1] - window[0]) / shortest[key], 0.01, "%s speed = window / duration" % key)
		assert_almost_eq(ctrl.anim_player.current_animation_position, window[0], 0.001, "%s starts at t_in" % key)

func test_r3_a_repeated_combo_swing_restarts_its_window() -> void:
	var ctrl := _player().animation_controller
	ctrl.play_fitted("attack_combo", 0.3)
	ctrl.anim_player.seek(1.3, true)
	ctrl.play_fitted("attack_combo", 0.6)
	assert_almost_eq(ctrl.anim_player.current_animation_position, PlayerAnimationController.SEGMENTS["attack_combo"][0], 0.001, "Combo 2 -> 3 restarts at t_in")

func test_r3_segment_end_returns_to_the_resting_clip() -> void:
	var p := _player()
	p.state_machine._on_transition_requested("StateRun")
	var ctrl := p.animation_controller
	ctrl.play_fitted("hit_react", 0.2)
	ctrl.anim_player.animation_finished.emit(&"hit_react")
	assert_eq(String(ctrl.anim_player.current_animation), "run", "The window hands back to the state's resting clip")

func test_r3_land_and_run_stop_are_in_the_library_and_the_map() -> void:
	var ctrl := _player().animation_controller
	for key in ["land", "run_stop"]:
		assert_true(ctrl.animation_map.has(key), "%s is mapped" % key)
		assert_true(ctrl.anim_player.has_animation(key), "%s clip is in nick_animations.tres" % key)
		assert_true(PlayerAnimationController.SEGMENTS.has(key), "%s has a strike window" % key)
	ctrl.play_fitted("land", 0.2)
	assert_eq(String(ctrl.anim_player.current_animation), "land")
	assert_true(ctrl.anim_player.get_playing_speed() <= 2.0001, "land at 0.2 s plays <= 2x")
	ctrl.play_fitted("run_stop", 0.15)
	assert_eq(String(ctrl.anim_player.current_animation), "run_stop")
	assert_true(ctrl.anim_player.get_playing_speed() <= 2.0001, "run_stop at 0.15 s plays <= 2x")

# --- R4 ------------------------------------------------------------------------------

func test_r4_the_enforcer_wire_surface_is_gone_not_just_hidden() -> void:
	var e: Node3D = _keep(load("res://characters/enemies/enforcer/enforcer.tscn").instantiate())
	e.position = Vector3(0.0, 700.0, 21400.0)
	add_child(e)
	var visual: CharacterVisual = e.get_node("MeshInstance3D")
	assert_eq(visual.skinned_meshes.size(), 1, "One hammer mesh")
	var sm := visual.skinned_meshes[0]
	assert_eq(sm.mesh.get_surface_count(), 1, "The 280-tri Wire surface is stripped (the rim overlay drew it)")
	var body := sm.get_surface_override_material(0) as StandardMaterial3D
	assert_true(body != null and body.resource_name == "enforcer_body_dark_metal", "The body keeps its dark-metal override")
	assert_true(sm.material_overlay != null, "...and the rim overlay")
