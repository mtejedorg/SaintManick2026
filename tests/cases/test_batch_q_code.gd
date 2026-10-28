extends "res://tests/framework/test_case.gd"

## Batch Q-code: Q3 combo routes + Double Jump through GameManager (demo mode), Q5 QA fixes
## (environmental DamageInfo, StateMachine.transition_to, settings applied at SaveManager
## boot, accessibility consumers in the drone camera and the VCR overlay).

const PLAYER_SCENE := "res://characters/player/player.tscn"
const RUNNER_SCENE := "res://characters/enemies/runner/runner.tscn"
const CAMERA_SCENE := "res://characters/player/drone_camera.tscn"
const VCR_SCENE := "res://ui/vcr/vcr_overlay.tscn"
const SAVE_MANAGER_SCRIPT := "res://_core/persistence/save_manager.gd"
const TOXIC_PIT_SCRIPT := "res://levels/components/toxic_pit.gd"
const COMBO_BATTERY_RAM := "res://characters/player/combos/combo_battery_ram.tres"
const BOOT_SAVE := "user://test_q_boot_settings.tres"

var _nodes: Array[Node] = []

func after_each() -> void:
	super.after_each()
	for n in _nodes:
		if is_instance_valid(n):
			n.free()
	_nodes.clear()
	GameManager.demo_mode = false
	GameManager.start_new_run() # no demo state leaks
	if FileAccess.file_exists(BOOT_SAVE):
		DirAccess.remove_absolute(ProjectSettings.globalize_path(BOOT_SAVE))

func _keep(n: Node) -> Node:
	_nodes.append(n)
	return n

func _player(z: float) -> PlayerController:
	var player: PlayerController = _keep(load(PLAYER_SCENE).instantiate())
	player.position = Vector3(0.0, 400.0, z)
	add_child(player)
	return player

## A profile with only the free routes and no Double Jump.
func _locked_profile() -> PlayerProfile:
	var p: PlayerProfile = SaveManager.profile
	p.unlocked_combos.assign(["AAA", "AAB"])
	p.double_jump_unlocked = false
	return p

## Airborne with the double jump unspent: does a jump press fire it?
func _double_jumps(player: PlayerController) -> bool:
	player.state_machine.transition_to("StateAirborne")
	var airborne: Node = player.state_machine.current_state
	player.can_double_jump = true
	player.clear_coyote_time()
	player.velocity.y = -2.0
	player.buffer_jump()
	airborne.physics_update(1.0 / 60.0)
	return is_equal_approx(player.velocity.y, player.jump_force)

# --- Q3 ------------------------------------------------------------------------------

func test_q3_a_demo_run_unlocks_every_route_and_the_double_jump_without_the_profile() -> void:
	assert_true(GameManager.has_method("is_combo_unlocked") and GameManager.has_method("double_jump_available"), "Precondition: GameManager offers the demo-aware gates")
	var p := _locked_profile()
	var before_combos: Array[String] = p.unlocked_combos.duplicate()
	var before_jump: bool = p.double_jump_unlocked
	GameManager.demo_mode = true
	var player := _player(15000.0)
	var attack: Node = player.state_machine.get_node("StateAttack")
	for seq in ["AAA", "AAB", "ABB", "BB"]:
		assert_true(attack._is_combo_unlocked(seq), "Demo: route %s is unlocked" % seq)
	# The real chain: B-B lands as Battery Ram, not a generic heavy.
	player.pending_attack_heavy = true
	player.state_machine.transition_to("StateAttack")
	attack.combo_step = 1
	attack._start_attack(true)
	assert_eq(player.bionic_arm_hitbox.damage_info.amount, (load(COMBO_BATTERY_RAM) as ComboDef).damage, "Demo: B-B hits as Battery Ram")
	player.state_machine.transition_to("StateIdle")
	assert_true(player.is_double_jump_available(), "Demo: the Double Jump is available")
	assert_true(_double_jumps(player), "Demo: the airborne state fires the double jump")
	assert_eq(p.unlocked_combos, before_combos, "The profile combos are untouched")
	assert_eq(p.double_jump_unlocked, before_jump, "The profile Double Jump flag is untouched")

func test_q3_outside_the_demo_the_profile_still_gates() -> void:
	_locked_profile()
	GameManager.demo_mode = false
	var player := _player(15020.0)
	var attack: Node = player.state_machine.get_node("StateAttack")
	assert_true(attack._is_combo_unlocked("AAB"), "A run: the free Launcher is unlocked")
	assert_false(attack._is_combo_unlocked("BB"), "A run: an unbought Battery Ram stays locked")
	assert_false(player.is_double_jump_available(), "A run: no Double Jump without the profile unlock")
	assert_false(_double_jumps(player), "...and the airborne state does not fire it")

# --- Q5: environmental DamageInfo ------------------------------------------------------

func test_q5_a_zero_knockback_zero_stun_player_hit_still_pops() -> void:
	var runner: CharacterBody3D = _keep(load(RUNNER_SCENE).instantiate())
	runner.position = Vector3(0.0, 400.0, 15040.0)
	add_child(runner)
	runner.set_physics_process(false)
	var combat: Node = runner.combat_comp
	var source: Node3D = _keep(Node3D.new())
	add_child(source)
	source.global_position = runner.global_position - Vector3(1.0, 0.0, 0.0)
	var hit := DamageInfo.new()
	hit.amount = 1.0
	hit.source = source
	assert_false(hit.is_environmental, "DamageInfo defaults to an attack")
	combat._on_hit_received(hit)
	assert_almost_eq(runner.velocity.y, combat.normal_hit_y_pop, 0.0001, "Q5: a 0/0 player hit still pops the grunt")
	var stun_hit := DamageInfo.new()
	stun_hit.amount = 1.0
	stun_hit.stun = 0.3
	stun_hit.source = source
	combat._on_hit_received(stun_hit)
	assert_true(combat.is_stunned(), "...and a 0-knockback hit with stun stuns it")

func test_q5_an_environmental_tick_only_flashes() -> void:
	var runner: CharacterBody3D = _keep(load(RUNNER_SCENE).instantiate())
	runner.position = Vector3(0.0, 400.0, 15060.0)
	add_child(runner)
	runner.set_physics_process(false)
	var combat: Node = runner.combat_comp
	combat.stun_timer = 0.5
	runner.velocity = Vector3(4.0, 0.0, 0.0)
	var pit: Node = _keep(load(TOXIC_PIT_SCRIPT).new())
	var tick: DamageInfo = pit._make_damage()
	assert_true(tick.is_environmental, "Q5: the toxic pit tick is environmental")
	combat._on_hit_received(tick)
	assert_almost_eq(runner.velocity.x, 4.0, 0.0001, "...it keeps the knockback slide")
	assert_almost_eq(runner.velocity.y, 0.0, 0.0001, "...no pop")
	assert_almost_eq(combat.stun_timer, 0.5, 0.0001, "...and the running stun")

# --- Q5: StateMachine.transition_to ----------------------------------------------------

func test_q5_transition_to_is_the_public_entry_point() -> void:
	var player := _player(15080.0)
	var sm: StateMachine = player.state_machine
	sm.transition_to("StateRoll")
	assert_eq(sm.current_state.name, "StateRoll", "transition_to enters the named state")
	sm.transition_to("stateidle")
	assert_eq(sm.current_state.name, "StateIdle", "...case-insensitively")
	sm.transition_to("StateDoesNotExist") # push_error, no transition
	assert_eq(sm.current_state.name, "StateIdle", "An unknown state leaves the machine where it was")
	player.health_component.current_health = 0.0
	player._on_died()
	assert_eq(sm.current_state.name, "StateIdle", "The death transition is deferred")
	await get_tree().process_frame
	assert_eq(sm.current_state.name, "StateDead", "...transition_to.call_deferred lands it")
	player.input_locked = false

# --- Q5: settings at SaveManager boot --------------------------------------------------

func test_q5_saved_volumes_apply_when_save_manager_boots() -> void:
	var stored := PlayerProfile.new()
	stored.music_volume = 0.5
	assert_eq(ResourceSaver.save(stored, BOOT_SAVE), OK, "Precondition: a profile with music at 50 percent")
	var music := AudioServer.get_bus_index(SaveManager.BUS_MUSIC)
	assert_true(music >= 0, "Precondition: a Music bus")
	var base: float = AudioServer.get_bus_volume_db(music)
	var sm: Node = load(SAVE_MANAGER_SCRIPT).new()
	sm.save_path = BOOT_SAVE
	add_child(sm) # _ready runs load_profile() then apply_settings() -- no title screen involved
	_keep(sm)
	assert_almost_eq(AudioServer.get_bus_volume_db(music), base + linear_to_db(0.5), 0.01, "Q5: the Music bus is at base + linear_to_db(0.5) right after _ready")
	SaveManager.apply_settings() # back to the test profile mix

# --- Q5: accessibility consumers -------------------------------------------------------

func test_q5_camera_shake_follows_the_screen_shake_option() -> void:
	var cam: Camera3D = _keep(load(CAMERA_SCENE).instantiate())
	add_child(cam)
	SaveManager.profile.set("screen_shake", 0.5)
	cam._on_camera_shake_requested(0.4, 0.3)
	assert_almost_eq(cam.shake_strength, 0.2, 0.0001, "Q5: half shake halves the request")
	cam.shake_timer = 0.0
	cam.shake_strength = 0.0
	SaveManager.profile.set("screen_shake", 0.0)
	cam._on_camera_shake_requested(0.4, 0.3)
	assert_almost_eq(cam.shake_timer, 0.0, 0.0001, "Q5: shake off -- no shake starts")

func test_q5_vcr_overlay_off_means_a_clean_feed() -> void:
	SaveManager.profile.set("vcr_effects", false)
	var overlay: CanvasLayer = _keep(load(VCR_SCENE).instantiate())
	add_child(overlay)
	assert_almost_eq(overlay.burst_strength, 0.0, 0.0001, "Q5: VCR off -- no burst strength")
	assert_false(overlay.visible, "...and the overlay is hidden")
	overlay._on_player_damaged(DamageInfo.new())
	var material: ShaderMaterial = overlay.get_node("OverlayRect").material
	assert_almost_eq(float(material.get_shader_parameter("aberration_strength")), 0.0, 0.0001, "...a hit shows no aberration")
	SaveManager.profile.set("vcr_effects", true)
	overlay.apply_accessibility()
	assert_gt(overlay.burst_strength, 0.0, "Switched back on, the authored burst returns")
	assert_true(overlay.visible, "...and the overlay shows again")
