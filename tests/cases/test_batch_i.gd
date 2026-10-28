extends "res://tests/framework/test_case.gd"

# Batch I: Nick hurt state (I1), respawn grace separate from dodge i-frames (I2), attack
# facing snap (I3), sniper hitbox = beam width (I4), Zone 1 control prompts (I5), Game
# Over cause line (I6), Zone 6-7 trims cyan (I7). I8 (shop) lives in test_shop_feedback.

const PLAYER_SCENE := "res://characters/player/player.tscn"
const SNIPER_SCENE := "res://characters/enemies/sniper/sniper.tscn"
const SNIPER_SCRIPT := "res://characters/enemies/sniper/sniper.gd"
const ONBOARDING_SCRIPT := "res://levels/components/onboarding_prompts.gd"
const GAME_OVER_SCENE := "res://ui/menus/game_over_screen.tscn"
const SLICE_PATH := "res://levels/slice/vertical_slice.tscn"
const TRIM_CYAN := "res://assets/materials/trim_cyan.tres"
const STEP := 1.0 / 60.0

## Real zone names use an em dash ("SECTOR NN -- DESCRIPTION"); kept out of the source bytes.
var zone_1: String = "SECTOR 01 " + String.chr(0x2014) + " STREET ENTRANCE"
var zone_2: String = "SECTOR 02 " + String.chr(0x2014) + " TOXIC ALLEY"

var _floor: StaticBody3D
var _extra: Array[Node] = []

func after_each() -> void:
	super.after_each()
	Input.action_release("move_left")
	Input.action_release("move_right")
	if is_instance_valid(_floor):
		_floor.queue_free()
	for n in _extra:
		if is_instance_valid(n):
			n.queue_free()
	_extra.clear()
	GameManager.respawn_grace_duration = 1.0
	GameManager.last_killer = ""

func _make_floor(top_center: Vector3) -> void:
	_floor = StaticBody3D.new()
	var shape := CollisionShape3D.new()
	var box := BoxShape3D.new()
	box.size = Vector3(20.0, 1.0, 20.0)
	shape.shape = box
	_floor.add_child(shape)
	add_child(_floor)
	_floor.global_position = top_center - Vector3(0.0, 0.5, 0.0)

## Nick standing on a fresh floor, physics frozen (states stepped by hand), off-rail.
func _grounded_player(origin: Vector3) -> PlayerController:
	_make_floor(origin - Vector3(0.0, 1.0, 0.0))
	var player: PlayerController = load(PLAYER_SCENE).instantiate()
	player.position = origin
	add_child(player)
	player.current_path = null
	for i in 3:
		await get_tree().physics_frame
	player.set_physics_process(false)
	player.state_machine.set_physics_process(false)
	return player

func _state(player: PlayerController) -> String:
	return String(player.state_machine.current_state.name)

func _hit_from(source_pos: Vector3, stun: float) -> DamageInfo:
	# Own holder per source: a sibling "Runner2" still queued for deletion from an earlier
	# test would make add_child rename this one.
	var holder := Node3D.new()
	add_child(holder)
	_extra.append(holder)
	var src := Node3D.new()
	src.name = "Runner2"
	holder.add_child(src)
	src.global_position = source_pos
	var info := DamageInfo.new()
	info.amount = 5.0
	info.knockback = 5.0
	info.stun = stun
	info.source = src
	return info

# --- I1 ------------------------------------------------------------------------------

func test_stunning_hit_puts_nick_in_hurt_then_back_to_idle() -> void:
	var player: PlayerController = await _grounded_player(Vector3(0.0, 0.0, 7400.0))
	assert_eq(_state(player), "StateIdle")
	player.health_component.take_damage(_hit_from(player.global_position - Vector3(2.0, 0.0, 0.0), 0.3))
	assert_eq(_state(player), "StateHurt", "A hit with stun 0.3 staggers Nick")
	assert_gt(player.velocity.x, 0.0, "Knocked back away from the source (source on his left)")
	var elapsed := 0.0
	while elapsed < 0.5 and _state(player) == "StateHurt":
		player.state_machine.current_state.physics_update(STEP)
		elapsed += STEP
	assert_eq(_state(player), "StateIdle", "Back in Idle within 0.5 s")
	assert_lt(elapsed, 0.5, "...the stagger lasted the stun, not longer")
	player.queue_free()

func test_zero_stun_hit_does_not_change_state() -> void:
	var player: PlayerController = await _grounded_player(Vector3(0.0, 0.0, 7420.0))
	var hp_before := player.health_component.current_health + player.health_component.current_shield
	player.health_component.take_damage(_hit_from(player.global_position + Vector3(2.0, 0.0, 0.0), 0.0))
	assert_eq(_state(player), "StateIdle", "A zero-stun hit only flinches")
	assert_lt(player.health_component.current_health + player.health_component.current_shield, hp_before, "...but still lands")
	player.queue_free()

func test_stagger_is_capped_and_iframes_ignore_the_hit() -> void:
	var player: PlayerController = await _grounded_player(Vector3(0.0, 0.0, 7440.0))
	player.health_component.take_damage(_hit_from(player.global_position + Vector3(2.0, 0.0, 0.0), 1.5))
	var hurt = player.state_machine.current_state
	assert_eq(String(hurt.name), "StateHurt")
	assert_almost_eq(hurt.hurt_timer, 0.4, 0.0001, "A 1.5 s stun locks Nick for 0.4 s at most")
	assert_lt(player.velocity.x, 0.0, "Source on his right -> pushed left")
	player.state_machine._on_transition_requested("StateIdle")
	player.state_machine._on_transition_requested("StateDash")
	player.health_component.take_damage(_hit_from(player.global_position + Vector3(2.0, 0.0, 0.0), 0.3))
	assert_eq(_state(player), "StateDash", "Dash i-frames ignore the hit entirely")
	player.queue_free()

# --- I2 ------------------------------------------------------------------------------

func test_dash_exit_does_not_end_the_respawn_grace() -> void:
	var player: PlayerController = await _grounded_player(Vector3(0.0, 0.0, 7460.0))
	var hc := player.health_component
	GameManager.respawn_grace_duration = 0.3
	GameManager.grant_respawn_grace(hc)
	player.state_machine._on_transition_requested("StateDash")
	player.state_machine._on_transition_requested("StateIdle") # dash exit clears its i-frames
	assert_true(hc.is_invincible, "Still invincible after the dash exit -- the grace runs on")
	var hp := hc.current_health
	var shield := hc.current_shield
	hc.take_damage(_hit_from(player.global_position + Vector3(2.0, 0.0, 0.0), 0.3))
	assert_eq(hc.current_health, hp, "The grace blocks the hit")
	assert_eq(hc.current_shield, shield, "...shield untouched too")
	assert_eq(_state(player), "StateIdle", "...and no stagger")
	await get_tree().create_timer(0.4).timeout
	assert_false(hc.is_invincible, "The grace ends on its own timer")
	player.queue_free()

func test_new_grace_is_not_cut_by_an_older_timer() -> void:
	var hc := HealthComponent.new()
	add_child(hc)
	_extra.append(hc)
	GameManager.respawn_grace_duration = 0.2
	GameManager.grant_respawn_grace(hc)
	await get_tree().create_timer(0.1).timeout
	GameManager.grant_respawn_grace(hc)
	await get_tree().create_timer(0.15).timeout
	assert_true(hc.grace_invincible, "The first timer must not end the second grace")
	hc.is_invincible = false # a dodge exit
	assert_true(hc.is_invincible, "Clearing i-frames leaves the grace")
	await get_tree().create_timer(0.1).timeout
	assert_false(hc.is_invincible, "Second grace over")

# --- I3 ------------------------------------------------------------------------------

func test_attack_snaps_facing_to_the_held_direction() -> void:
	var player: PlayerController = await _grounded_player(Vector3(0.0, 0.0, 7480.0))
	assert_true(player.is_facing_right, "Starts facing right")
	Input.action_press("move_left")
	player.pending_attack_heavy = false
	player.state_machine._on_transition_requested("StateAttack")
	assert_false(player.is_facing_right, "Holding left at the attack -> faces left")
	assert_almost_eq(player.mesh.rotation.y, -PI / 2.0, 0.0001, "...snapped, not eased (the hitboxes ride the mesh)")
	Input.action_release("move_left")
	player.queue_free()

# --- I4 ------------------------------------------------------------------------------

func test_sniper_hitbox_matches_the_live_beam_width() -> void:
	var sniper: Node = (load(SNIPER_SCENE) as PackedScene).instantiate()
	var shape := (sniper.get_node("LaserHitbox/CollisionShape3D") as CollisionShape3D).shape as BoxShape3D
	var beam_mesh := (sniper.get_node("LaserBeam") as MeshInstance3D).mesh as BoxMesh
	var fire_scale: Vector3 = load(SNIPER_SCRIPT).FIRE_BEAM_SCALE
	assert_almost_eq(shape.size.x, beam_mesh.size.x * fire_scale.x, 0.0001, "Hitbox width = live beam width")
	assert_almost_eq(shape.size.y, beam_mesh.size.y * fire_scale.y, 0.0001, "Hitbox height = live beam height")
	assert_almost_eq(shape.size.x, 0.6, 0.0001, "0.6 m")
	sniper.free()

# --- I5 ------------------------------------------------------------------------------

# Q6: the three Zone 1 control cards moved to the HUD's action-gated hint strip; the
# onboarding node keeps only its once-per-run and one-shot cards.
func test_zone_one_prompts_once_per_run() -> void:
	var prompts: Node = load(ONBOARDING_SCRIPT).new()
	add_child(prompts)
	_extra.append(prompts)
	var got: Array[String] = []
	var on_banner := func(text: String, _hold: float): got.append(text)
	SignalBus.banner_requested.connect(on_banner)
	SignalBus.zone_entered.emit(zone_1)
	SignalBus.zone_entered.emit(zone_2)
	await get_tree().create_timer(0.2).timeout
	assert_eq(got.size(), 0, "No zone entry plays a control card any more (%s)" % str(got))
	assert_false("PROMPTS" in (load(ONBOARDING_SCRIPT) as Script).get_script_constant_map(), "The PROMPTS card list is gone")
	assert_false(SaveManager.profile.seen_controls, "...and a Zone 2 entry no longer marks the controls seen")
	SignalBus.banner_requested.disconnect(on_banner)

func test_zone_one_prompts_drop_pending_cards_on_life_lost() -> void:
	var prompts: Node = load(ONBOARDING_SCRIPT).new()
	prompts.top_down_delay = 0.05
	add_child(prompts)
	_extra.append(prompts)
	var got: Array[String] = []
	var on_banner := func(text: String, _hold: float): got.append(text)
	SignalBus.banner_requested.connect(on_banner)
	SignalBus.camera_shift_finished.emit(true)
	SignalBus.player_life_lost.emit(2)
	await get_tree().create_timer(0.25).timeout
	assert_eq(got.size(), 0, "A LIFE LOST card is never cut by a pending prompt")
	SignalBus.banner_requested.disconnect(on_banner)

func test_slice_has_the_onboarding_node() -> void:
	var state := (load(SLICE_PATH) as PackedScene).get_state()
	var found := false
	for i in state.get_node_count():
		if String(state.get_node_name(i)) == "OnboardingPrompts":
			for p in state.get_node_property_count(i):
				if state.get_node_property_name(i, p) == &"script":
					found = (state.get_node_property_value(i, p) as Script).resource_path == ONBOARDING_SCRIPT
	assert_true(found, "vertical_slice.tscn has an OnboardingPrompts node with the script")

# --- I6 ------------------------------------------------------------------------------

func test_lethal_hit_records_the_killer() -> void:
	GameManager.start_new_run()
	var hc := HealthComponent.new()
	hc.is_player = true
	add_child(hc)
	_extra.append(hc)
	hc.current_shield = 0.0
	hc.current_health = 1.0
	var info := _hit_from(Vector3.ZERO, 0.0)
	info.amount = 50.0
	hc.take_damage(info)
	assert_eq(GameManager.last_killer, "RUNNER", "Lethal hit from %s -> RUNNER (got %s)" % [info.source.name if is_instance_valid(info.source) else "freed", GameManager.last_killer])
	await get_tree().process_frame # J13: the deferred respawn_or_game_over lands here
	GameManager.start_new_run()
	assert_eq(GameManager.last_killer, "", "A new run clears it")

func test_killer_names_for_known_sources() -> void:
	assert_eq(GameManager.bare_node_name("RhythmEnforcer_3"), "RHYTHM ENFORCER")
	var player: PlayerController = load(PLAYER_SCENE).instantiate()
	assert_eq(GameManager.killer_name(player), "THE DROP", "Nick is his own source only for a fall")
	player.free()
	var pit := ToxicPit.new()
	assert_eq(GameManager.killer_name(pit), "TOXIC PIT")
	pit.free()
	var wall := EscapeKillWall.new()
	assert_eq(GameManager.killer_name(wall), "KILL WALL")
	wall.free()

func test_game_over_screen_names_the_killer() -> void:
	GameManager.last_killer = "RUNNER"
	var screen = load(GAME_OVER_SCENE).instantiate()
	add_child(screen)
	assert_true(screen.summary_label.text.contains("DESTROYED BY RUNNER"), "Game Over shows the cause line")
	assert_true(screen.summary_label.visible, "...and the summary is visible")
	screen.queue_free()

# --- I7 ------------------------------------------------------------------------------

func test_zone_six_and_seven_trims_are_cyan() -> void:
	var state := (load(SLICE_PATH) as PackedScene).get_state()
	var checked := 0
	for i in state.get_node_count():
		var path := String(state.get_node_path(i))
		if path != "./Trims/Z6_Trim" and path != "./Trims/Z7_Trim":
			continue
		for p in state.get_node_property_count(i):
			if state.get_node_property_name(i, p) == &"material":
				var mat := state.get_node_property_value(i, p) as Material
				assert_eq(mat.resource_path, TRIM_CYAN, path + " uses the cyan trim")
				checked += 1
	assert_eq(checked, 2, "Both arena trims found")
