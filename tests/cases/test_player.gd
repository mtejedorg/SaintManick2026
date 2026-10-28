extends "res://tests/framework/test_case.gd"

# Regression: falling out of the world must return Nick to his last safe ground and cost HP
# (never an infinite fall, never a full level reload).
func test_fall_returns_to_safe_position_and_costs_hp() -> void:
	GameManager.is_test = true
	GameManager.current_lives = 3

	var player_scene = load("res://characters/player/player.tscn")
	var player = player_scene.instantiate()
	add_child(player)

	# Isolate HP from shield for a clean assertion.
	player.health_component.max_shield = 0.0
	player.health_component.current_shield = 0.0
	player.health_component.max_health = 120.0
	player.health_component.current_health = 120.0

	player.current_path = null
	var safe := Vector3(10.0, 1.0, 0.0)
	player.last_safe_position = safe
	var lives_before := GameManager.current_lives

	# Drop below the kill plane.
	player.global_position = Vector3(0.0, PlayerController.FALL_KILL_Y - 5.0, 0.0)
	player._physics_process(0.016)

	assert_eq(player.global_position, safe, "Fall should return Nick to his last safe position")
	assert_eq(player.health_component.current_health, 100.0, "Fall should cost fall_damage HP")
	assert_eq(GameManager.current_lives, lives_before, "A survivable fall must NOT cost a life or reload")
	assert_eq(player.velocity, Vector3.ZERO, "Velocity should be reset after a fall")

	# Above the kill plane: no fall handling.
	player.global_position = Vector3(0.0, 5.0, 0.0)
	player.health_component.current_health = 100.0
	player._physics_process(0.016)
	assert_eq(player.health_component.current_health, 100.0, "Above the kill plane should not cost HP")

	player.queue_free()

# GDD §3.1: up/down are dead inputs while plane-locked (side-scroll); they only steer in
# free (top-down) movement.
func test_up_down_ignored_while_plane_locked() -> void:
	var player = load("res://characters/player/player.tscn").instantiate()
	add_child(player)
	var path := Path3D.new()
	path.curve = Curve3D.new()
	path.curve.add_point(Vector3.ZERO)
	path.curve.add_point(Vector3(10.0, 0.0, 0.0))
	add_child(path)

	Input.action_press("move_up")
	player.current_path = path
	var locked: Vector2 = player.get_movement_input()
	player.current_path = null
	var free: Vector2 = player.get_movement_input()
	Input.action_release("move_up")

	assert_eq(locked, Vector2.ZERO, "Up should do nothing while plane-locked to a Path3D")
	assert_eq(free, Vector2(0.0, -1.0), "Up should still steer in free (top-down) movement")

	path.queue_free()
	player.queue_free()

func _find_skeleton(node: Node) -> Skeleton3D:
	if node is Skeleton3D:
		return node
	for child in node.get_children():
		var found := _find_skeleton(child)
		if found:
			return found
	return null

# A11: Nick's feet must sit on the bottom of his 2 m capsule (origin is the capsule
# centre, so the ground is origin.y - 1.0) — a floating visual detaches his shadow.
# Measured standing on a floor with the idle clip playing: the bind pose (no clip) and
# the airborne "fall" clip (feet tucked) legitimately put the toes elsewhere.
func test_nick_visual_feet_rest_on_capsule_bottom() -> void:
	var origin := Vector3(0.0, 200.0, -3000.0)
	var floor_body := StaticBody3D.new()
	var floor_shape := CollisionShape3D.new()
	var box := BoxShape3D.new()
	box.size = Vector3(20.0, 1.0, 20.0)
	floor_shape.shape = box
	floor_body.add_child(floor_shape)
	add_child(floor_body)
	floor_body.global_position = origin - Vector3(0.0, 0.5, 0.0) # top face at origin.y

	var player = load("res://characters/player/player.tscn").instantiate()
	add_child(player)
	player.current_path = null
	player.global_position = origin + Vector3(0.0, 1.0, 0.0) # capsule bottom on the floor
	player.animation_controller.play("idle")

	for i in 3:
		await get_tree().process_frame

	var skeleton := _find_skeleton(player)
	assert_not_null(skeleton, "Player visual should contain a Skeleton3D")
	if skeleton:
		var lowest := INF
		for bone in skeleton.get_bone_count():
			var y: float = (skeleton.global_transform * skeleton.get_bone_global_pose(bone)).origin.y
			lowest = min(lowest, y)
		var ground: float = player.global_position.y - 1.0
		assert_true(absf(lowest - ground) <= 0.15, "Lowest bone y %.3f should be within 0.15 of the capsule bottom %.3f" % [lowest, ground])

	player.queue_free()
	floor_body.queue_free()

func test_new_rail_is_eased_onto_not_snapped() -> void:
	# D9: assigning a rail 10 m away must not teleport Nick in one frame.
	var rail := Path3D.new()
	rail.curve = Curve3D.new()
	rail.curve.add_point(Vector3(-50.0, 0.0, -10.0))
	rail.curve.add_point(Vector3(50.0, 0.0, -10.0))
	rail.position = Vector3(0.0, 0.0, 4000.0)
	add_child(rail)

	var player: PlayerController = load("res://characters/player/player.tscn").instantiate()
	player.position = Vector3(0.0, 0.0, 4000.0)
	add_child(player)
	player.current_path = null
	player.set_physics_process(false) # drive the ticks by hand
	var start := player.global_position

	player.current_path = rail
	player._physics_process(0.1)
	var moved := start.distance_to(player.global_position)
	assert_gt(moved, 0.0, "Nick should start moving toward the new rail")
	assert_lt(moved, 5.0, "One 0.1 s tick must move Nick less than 5 m toward a rail 10 m away (moved %.2f)" % moved)

	for i in 3:
		player._physics_process(0.1)
	assert_almost_eq(player.global_position.z, 4000.0 - 10.0, 0.01, "After rail_blend_time Nick should be locked onto the rail")

	player.queue_free()
	rail.queue_free()

func test_stale_play_once_does_not_override_a_later_clip_with_idle() -> void:
	# D11: a play_once whose clip was superseded by play("run") must not fall back to idle
	# when some later non-looping clip finishes.
	var player: PlayerController = load("res://characters/player/player.tscn").instantiate()
	add_child(player)
	var ctrl := player.animation_controller
	assert_not_null(ctrl.anim_player, "Nick's AnimationPlayer should be found")
	assert_eq(ctrl.anim_player.playback_default_blend_time, ctrl.blend_time, "Default blend time should be applied")

	ctrl.play_once("hit_react")
	ctrl.play("run")
	ctrl.anim_player.animation_finished.emit(&"hit_react")
	assert_eq(String(ctrl.anim_player.current_animation), "run", "A stale play_once must not switch to idle")

	# A play_once that is still current DOES fall back to idle.
	ctrl.play_once("hit_react")
	ctrl.anim_player.animation_finished.emit(&"hit_react")
	assert_eq(String(ctrl.anim_player.current_animation), "idle", "A current play_once should fall back to idle")
	player.queue_free()

func test_play_fitted_stretches_the_clip_to_the_state_duration() -> void:
	var player: PlayerController = load("res://characters/player/player.tscn").instantiate()
	add_child(player)
	var ctrl := player.animation_controller
	var length: float = ctrl.anim_player.get_animation("dash").length
	ctrl.play_fitted("dash", 0.25)
	assert_eq(String(ctrl.anim_player.current_animation), "dash")
	assert_almost_eq(ctrl.anim_player.get_playing_speed(), length / 0.25, 0.01, "Clip speed should fit the 0.25 s dash")
	player.queue_free()

func test_idle_plays_on_spawn() -> void:
	# D12: StateIdle.enter() runs from the StateMachine's _ready, before
	# player.animation_controller is assigned — it must still start the idle clip.
	var floor_body := StaticBody3D.new()
	var floor_shape := CollisionShape3D.new()
	var box := BoxShape3D.new()
	box.size = Vector3(20.0, 1.0, 20.0)
	floor_shape.shape = box
	floor_body.add_child(floor_shape)
	floor_body.position = Vector3(0.0, -1.5, 5000.0) # top at y=-1 = capsule bottom
	add_child(floor_body)

	var player: PlayerController = load("res://characters/player/player.tscn").instantiate()
	player.position = Vector3(0.0, 0.0, 5000.0)
	add_child(player)
	await get_tree().process_frame
	await get_tree().process_frame
	var anim_player: AnimationPlayer = player.animation_controller.anim_player
	assert_not_null(anim_player, "Nick's AnimationPlayer should be found")
	assert_eq(player.state_machine.current_state.name, "StateIdle", "Precondition: Nick is standing idle")
	assert_eq(String(anim_player.current_animation), "idle", "Nick should play idle on spawn, not sit in the bind pose")
	player.queue_free()
	floor_body.queue_free()

func test_nick_faces_right_before_first_move() -> void:
	# E0: is_facing_right starts true, so the visual must already face +X on spawn —
	# an attack before the first move must not swing toward the camera (+Z).
	var player: PlayerController = load("res://characters/player/player.tscn").instantiate()
	add_child(player)
	assert_almost_eq(player.mesh.rotation.y, PI / 2.0, 0.001, "Nick's visual should face right (+X) from spawn")
	player.queue_free()

func test_nick_rim_is_cyan_at_strength_3_5() -> void:
	# E6: the cyan edge must read over the magenta panels of Nick's texture.
	var player: PlayerController = load("res://characters/player/player.tscn").instantiate()
	add_child(player)
	var visual: CharacterVisual = player.get_node("MeshInstance3D/CharacterVisual")
	assert_eq(visual.get_base_rim_color(), CharacterVisual.PLAYER_RIM_COLOR, "Nick's rim is cyan #00F5FF")
	assert_almost_eq(visual.get_base_rim_strength(), 3.5, 0.001, "Nick's rim strength is 3.5")
	for sm in visual.skinned_meshes:
		assert_null(sm.material_override, "Nick keeps his textured materials (WHITE tint)")
	player.queue_free()

func test_move_left_action_drives_movement_x() -> void:
	# F1: horizontal movement reads move_left/move_right (A/D, arrows, D-pad, stick).
	var player: PlayerController = load("res://characters/player/player.tscn").instantiate()
	add_child(player)
	player.current_path = null
	Input.action_press("move_left")
	var dir: Vector2 = player.get_movement_input()
	Input.action_release("move_left")
	assert_almost_eq(dir.x, -1.0, 0.001, "move_left should drive x = -1")
	player.queue_free()

func _hit(amount: float) -> DamageInfo:
	var info := DamageInfo.new()
	info.amount = amount
	return info

func test_damage_requests_hit_stop_shake_and_white_flash() -> void:
	# F6: any HP/shield loss on Nick reads — hit-stop, shake and a white-hot rim flash.
	var player: PlayerController = load("res://characters/player/player.tscn").instantiate()
	add_child(player)
	player.health_component.max_health = 100.0
	player.health_component.current_health = 100.0
	var got = {"stop": Vector2.ZERO, "shake": Vector2.ZERO}
	var on_stop = func(d, s): got.stop = Vector2(d, s)
	var on_shake = func(st, d): got.shake = Vector2(st, d)
	SignalBus.hit_stop_requested.connect(on_stop)
	SignalBus.camera_shake_requested.connect(on_shake)
	player.health_component.take_damage(_hit(10.0))
	SignalBus.hit_stop_requested.disconnect(on_stop)
	SignalBus.camera_shake_requested.disconnect(on_shake)
	Engine.time_scale = 1.0
	var hs = get_node_or_null("/root/HitStop")
	if hs:
		hs.hit_stop_timer = 0.0
	assert_true(got.stop.is_equal_approx(Vector2(0.06, 0.05)), "Taking damage requests a 0.06 s hit-stop (got %s)" % got.stop)
	assert_true(got.shake.is_equal_approx(Vector2(0.15, 0.2)), "Taking damage requests a 0.15 / 0.2 s shake (got %s)" % got.shake)
	assert_eq(player.character_visual.get_current_rim_color(), Color.WHITE, "Nick's rim flashes white on damage")
	player.queue_free()

func test_invincible_rim_is_pale_cyan_and_restores() -> void:
	# F6: i-frames read as a pale cyan, dimmed rim.
	var player: PlayerController = load("res://characters/player/player.tscn").instantiate()
	add_child(player)
	player.health_component.is_invincible = true
	player._process(0.0)
	assert_eq(player.character_visual.get_base_rim_color(), PlayerController.INVINCIBLE_RIM_COLOR, "Invincible rim is pale cyan")
	assert_almost_eq(player.character_visual.get_base_rim_strength(), 2.0, 0.001, "Invincible rim strength is 2")
	player.health_component.is_invincible = false
	player._process(0.0)
	assert_eq(player.character_visual.get_base_rim_color(), CharacterVisual.PLAYER_RIM_COLOR, "The cyan rim returns after the i-frames")
	assert_almost_eq(player.character_visual.get_base_rim_strength(), 3.5, 0.001, "Strength 3.5 returns too")
	player.queue_free()

func test_low_health_pulses_magenta_on_the_beat() -> void:
	var player: PlayerController = load("res://characters/player/player.tscn").instantiate()
	add_child(player)
	player.health_component.max_health = 100.0
	player.health_component.current_health = 50.0
	player._on_beat("primary", 1)
	assert_eq(player.character_visual.get_current_rim_color(), player.character_visual.get_base_rim_color(), "Healthy Nick does not pulse")
	player.health_component.current_health = 20.0
	player._on_beat("primary", 1)
	assert_eq(player.character_visual.get_current_rim_color(), PlayerController.LOW_HP_PULSE_COLOR, "Below 25 % HP the beat pulses the rim magenta")
	player.queue_free()

func _floor_under(origin: Vector3) -> StaticBody3D:
	var floor_body := StaticBody3D.new()
	var shape := CollisionShape3D.new()
	var box := BoxShape3D.new()
	box.size = Vector3(20.0, 1.0, 20.0)
	shape.shape = box
	floor_body.add_child(shape)
	add_child(floor_body)
	floor_body.global_position = origin - Vector3(0.0, 1.5, 0.0) # top at the capsule bottom
	return floor_body

func test_unsafe_floor_does_not_become_the_fall_return_point() -> void:
	# F14: standing on a floor in the unsafe_floor group (Zone 8 collapsing platform) must not
	# overwrite last_safe_position — after it collapses every fall would return over the void.
	var origin := Vector3(0.0, 0.0, 7000.0)
	var floor_body := _floor_under(origin)
	floor_body.add_to_group("unsafe_floor")
	var player: PlayerController = load("res://characters/player/player.tscn").instantiate()
	player.position = origin
	add_child(player)
	player.current_path = null
	var marker := Vector3(1.0, 2.0, 3.0)
	player.last_safe_position = marker
	for i in 4:
		await get_tree().physics_frame
	assert_true(player.is_on_floor(), "Precondition: Nick stands on the unsafe floor")
	assert_eq(player.last_safe_position, marker, "An unsafe floor never becomes the fall-return point")

	floor_body.remove_from_group("unsafe_floor")
	await get_tree().physics_frame
	await get_tree().physics_frame
	assert_true(player.last_safe_position.distance_to(player.global_position) < 0.01, "A normal floor still records the safe position")
	player.queue_free()
	floor_body.queue_free()

func test_collapsing_hazard_platform_counts_as_unsafe() -> void:
	var hazard := EscapeCollapsingHazard.new()
	var body := StaticBody3D.new()
	hazard.add_child(body)
	assert_true(PlayerController.is_unsafe_floor(body), "A StaticBody3D under an EscapeCollapsingHazard is unsafe")
	var plain := StaticBody3D.new()
	assert_false(PlayerController.is_unsafe_floor(plain), "A plain floor is safe")
	plain.free()
	hazard.free()
