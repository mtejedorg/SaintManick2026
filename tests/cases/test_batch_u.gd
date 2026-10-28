extends "res://tests/framework/test_case.gd"

# Batch U (the motion layer): katana trail / dash streak / landing dust (U1), telegraph
# footprints (U2), reactive shield bubbles (U3), combo flash hygiene (U4), ambient life and the
# neon flicker (U5).

const PLAYER_SCENE := "res://characters/player/player.tscn"
const RUNNER_SCENE := "res://characters/enemies/runner/runner.tscn"
const BRUISER_SCENE := "res://characters/enemies/bruiser/bruiser.tscn"
const ENFORCER_SCENE := "res://characters/enemies/enforcer/enforcer.tscn"
const HEADLINER_SCENE := "res://characters/enemies/headliner/headliner.tscn"
const MotionFxScript := preload("res://vfx/player_motion_fx.gd")
const NeonFlickerScript := preload("res://vfx/neon_flicker.gd")
const TelegraphZoneScript := preload("res://vfx/telegraph_zone.gd")
const Atmo := preload("res://levels/components/zone_atmosphere.gd")

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

func _spawn(scene_path: String, pos: Vector3) -> Node3D:
	var n: Node3D = _keep((load(scene_path) as PackedScene).instantiate())
	n.position = pos
	add_child(n)
	return n

func _player_with_fx() -> Array:
	var player: PlayerController = _spawn(PLAYER_SCENE, Vector3(0.0, 200.0, 4000.0))
	var fx: Node = _keep(MotionFxScript.new())
	add_child(fx)
	return [player, fx]

# --- U1 ------------------------------------------------------------------------------------

func test_u1_the_trail_attaches_to_a_hand_bone_of_the_players_skeleton() -> void:
	var pair := _player_with_fx()
	var player: PlayerController = pair[0]
	var fx: Node = pair[1]
	assert_not_null(fx.attachment, "The trail has a BoneAttachment3D")
	assert_true(fx.attachment.get_parent() is Skeleton3D, "...on the player's own Skeleton3D")
	assert_true(player.is_ancestor_of(fx.attachment), "...inside the player scene (no scene file edited)")
	assert_true(fx.attachment.get_bone_idx() >= 0, "...bound to a real bone (idx %d)" % fx.attachment.get_bone_idx())
	assert_eq(fx.attachment.bone_name, "mixamorig_RightHand", "The katana hand")
	assert_eq(fx.trail.get_parent(), fx.attachment, "The ribbon rides the attachment")
	var trail := fx.trail as GPUParticles3D
	assert_true(trail.trail_enabled and trail.draw_pass_1 is RibbonTrailMesh, "A ribbon trail")
	assert_eq(trail.amount, 12, "12 particles")
	assert_almost_eq(trail.lifetime, 0.18, 0.0001, "0.18 s")
	assert_false(trail.emitting, "Idle: not emitting")

func test_u1_the_trail_emits_only_during_the_attack_window() -> void:
	var pair := _player_with_fx()
	var player: PlayerController = pair[0]
	var fx: Node = pair[1]
	var trail := fx.trail as GPUParticles3D
	fx.update_attack_window(false, false, 0.016)
	assert_false(trail.emitting, "No hitbox live: no trail")
	fx.update_attack_window(true, false, 0.016)
	assert_true(trail.emitting, "Katana hitbox live: trail on")
	assert_false(trail.heavy, "Light swing: cyan")
	fx.update_attack_window(false, false, 0.02)
	assert_true(trail.emitting, "A short hold bridges the chain's one-frame hitbox re-arm")
	fx.update_attack_window(false, false, 0.1)
	assert_false(trail.emitting, "Window closed: trail off")
	fx.update_attack_window(false, true, 0.016)
	assert_true(trail.emitting and trail.heavy, "Bionic-arm (heavy) swing: trail on, amber")
	assert_true(trail._material.albedo_color.r > trail._material.albedo_color.b, "...amber, not cyan")
	fx.update_attack_window(true, false, 0.016)
	assert_false(trail.heavy, "...and back to cyan on the next light swing")
	# The live path: the real hitbox flag, polled in _process.
	fx.update_attack_window(false, false, 1.0)
	player.katana_hitbox.is_active = true
	fx._process(0.016)
	assert_true(trail.emitting, "_process reads katana_hitbox.is_active")
	player.katana_hitbox.is_active = false
	fx._process(1.0)
	assert_false(trail.emitting, "...and closes with it")

func test_u1_the_dash_streak_fires_once_per_dash_or_roll() -> void:
	var pair := _player_with_fx()
	var fx: Node = pair[1]
	fx.update_state("StateRun")
	assert_eq(fx.dash_bursts, 0, "Running is not a dash")
	fx.update_state("StateDash")
	assert_eq(fx.dash_bursts, 1, "Entering StateDash: one streak")
	assert_true((fx.streak as GPUParticles3D).emitting, "...emitting")
	fx.update_state("StateDash")
	assert_eq(fx.dash_bursts, 1, "Staying in the state is not a new event")
	fx.update_state("StateIdle")
	fx.update_state("StateRoll")
	assert_eq(fx.dash_bursts, 2, "A roll fires its own streak")
	var streak := fx.streak as GPUParticles3D
	assert_eq(streak.amount, 10, "10 particles")
	assert_almost_eq(streak.lifetime, 0.2, 0.0001, "0.2 s")
	assert_eq((streak.draw_pass_1 as QuadMesh).size, Vector2(0.04, 0.8), "0.04 x 0.8 quads")

func test_u1_landing_dust_fires_once_per_hard_landing() -> void:
	var pair := _player_with_fx()
	var fx: Node = pair[1]
	fx.update_landing(true, 0.0)
	assert_eq(fx.land_bursts, 0, "Standing on the floor: nothing")
	fx.update_landing(false, -3.0)
	fx.update_landing(true, 0.0)
	assert_eq(fx.land_bursts, 0, "A soft landing (3 m/s) raises no dust")
	fx.update_landing(false, -9.0)
	fx.update_landing(false, -12.0)
	fx.update_landing(true, 0.0)
	assert_eq(fx.land_bursts, 1, "A 12 m/s landing: one puff")
	fx.update_landing(true, 0.0)
	assert_eq(fx.land_bursts, 1, "Still grounded: no repeat")
	var dust := fx.dust as GPUParticles3D
	assert_eq(dust.amount, 6, "6 particles")
	assert_almost_eq(dust.lifetime, 0.3, 0.0001, "0.3 s")
	assert_eq((dust.draw_pass_1 as QuadMesh).size, Vector2(0.3, 0.3), "0.3 m quads")

func test_u1_the_vfx_manager_owns_the_motion_layer_once() -> void:
	var vfx: Node = _keep(load("res://vfx/vfx_manager.gd").new())
	add_child(vfx)
	assert_not_null(vfx.motion_fx, "VFXManager builds the motion layer")
	assert_not_null(vfx.neon_flicker, "...and the neon flicker")
	assert_eq(vfx.motion_fx.get_children().size(), 2, "One pooled streak and one pooled puff (no trail without a player)")

# --- U2 ------------------------------------------------------------------------------------

func _near_player(host: Node3D, offset: Vector3) -> Node3D:
	var p: Node3D = _keep(Node3D.new())
	add_child(p)
	p.global_position = host.global_position + offset
	return p

func test_u2_the_runner_shows_its_footprint_on_telegraph_and_hides_it_when_the_hitbox_arms() -> void:
	var runner: RunnerEnemy = _spawn(RUNNER_SCENE, Vector3(0.0, 200.0, 4100.0))
	var zone := runner.telegraph_zone as MeshInstance3D
	assert_not_null(zone, "The Runner builds a telegraph zone")
	assert_false(zone.visible, "Hidden at rest")
	assert_eq((zone.mesh as QuadMesh).size, Vector2(1.0, 1.0), "Sized to the hitbox capsule (radius 0.5 -> 1 m)")
	assert_almost_eq(zone.position.y, -0.9 + 0.02, 0.0001, "Lying 0.02 m above the floor")
	assert_true(zone._color.is_equal_approx(TelegraphZoneScript.COLOR_MAGENTA), "Magenta")
	runner.is_active = true
	runner.player = _near_player(runner, Vector3(1.0, 0.0, 0.0))
	runner._on_beat("primary", 1)
	assert_eq(runner.attack_step, 1, "Precondition: telegraphing")
	assert_true(zone.visible, "Telegraph: footprint on")
	assert_almost_eq(zone.current_alpha(), 0.15, 0.0001, "...starting at alpha 0.15")
	runner._on_beat("primary", 2)
	assert_eq(runner.attack_step, 2, "Precondition: the hitbox is armed")
	assert_false(zone.visible, "The hitbox arms: footprint off")

func test_u2_the_footprint_fades_from_015_toward_06_across_one_beat() -> void:
	var runner: RunnerEnemy = _spawn(RUNNER_SCENE, Vector3(0.0, 200.0, 4150.0))
	var zone := runner.telegraph_zone as MeshInstance3D
	zone.show_telegraph(0.4)
	assert_almost_eq(zone.current_alpha(), 0.15, 0.0001, "Starts at 0.15")
	await get_tree().create_timer(0.2).timeout
	var mid: float = zone.current_alpha()
	assert_true(mid > 0.2 and mid < 0.6, "...mid-fade (%f)" % mid)
	await get_tree().create_timer(0.4).timeout
	assert_almost_eq(zone.current_alpha(), 0.6, 0.0001, "...ends at 0.6")
	zone.hide_telegraph()
	assert_false(zone.visible, "hide_telegraph hides it")

func test_u2_the_bruiser_footprint_follows_its_downbeat_telegraph() -> void:
	var b: BruiserEnemy = _spawn(BRUISER_SCENE, Vector3(0.0, 200.0, 4200.0))
	var zone := b.telegraph_zone as MeshInstance3D
	assert_not_null(zone, "The Bruiser builds a telegraph zone")
	b.is_active = true
	b.player = _near_player(b, Vector3(1.0, 0.0, 0.0))
	var beats: int = Conductor.layers["primary"].beats_per_measure
	b._on_beat("primary", beats)
	assert_eq(b.attack_step, BruiserEnemy.AttackStep.TELEGRAPH, "Precondition: telegraphing")
	assert_true(zone.visible, "Telegraph: footprint on")
	b._on_downbeat("primary", 1)
	assert_eq(b.attack_step, BruiserEnemy.AttackStep.ACTIVE, "Precondition: the downbeat swing is live")
	assert_false(zone.visible, "Hitbox armed: footprint off")

func test_u2_a_stun_cancels_the_footprint() -> void:
	var runner: RunnerEnemy = _spawn(RUNNER_SCENE, Vector3(0.0, 200.0, 4300.0))
	runner.telegraph_zone.show_telegraph(0.5)
	runner._on_stun_started()
	assert_false(runner.telegraph_zone.visible, "A stun drops the tell")

func test_u2_the_enforcer_footprint_shows_in_the_telegraph_state_only() -> void:
	var boss: EnforcerEnemy = _spawn(ENFORCER_SCENE, Vector3(0.0, 300.0, 15400.0))
	var zone := boss.telegraph_zone as MeshInstance3D
	assert_not_null(zone, "The Enforcer builds a telegraph zone")
	assert_eq((zone.mesh as QuadMesh).size, Vector2(2.4, 2.4), "Sized to its hitbox capsule (radius 1.2)")
	assert_true(zone._color.is_equal_approx(TelegraphZoneScript.COLOR_MAGENTA), "Magenta")
	boss.state_machine.transition_to("StateTelegraph")
	assert_true(zone.visible, "StateTelegraph.enter: footprint on")
	boss.state_machine.transition_to("State3HitBurst")
	assert_false(zone.visible, "The burst arms the hitbox: footprint off")

func test_u2_the_headliner_footprint_is_amber() -> void:
	var boss: HeadlinerBoss = _spawn(HEADLINER_SCENE, Vector3(0.0, 300.0, 15500.0))
	var zone := boss.telegraph_zone as MeshInstance3D
	assert_not_null(zone, "The Headliner builds a telegraph zone")
	assert_eq((zone.mesh as QuadMesh).size, Vector2(4.0, 4.0), "Sized to its hitbox capsule (radius 2.0)")
	assert_true(zone._color.is_equal_approx(TelegraphZoneScript.COLOR_AMBER), "Amber")
	boss.state_machine.transition_to("StateTelegraph")
	assert_true(zone.visible, "StateTelegraph.enter: footprint on")
	boss.state_machine.transition_to("StateMelee")
	assert_false(zone.visible, "StateMelee arms the hitbox: footprint off")

# --- U3 ------------------------------------------------------------------------------------

func test_u3_a_blocked_hit_sets_the_ripple_uniform_and_starts_the_tween() -> void:
	var boss: EnforcerEnemy = _spawn(ENFORCER_SCENE, Vector3(0.0, 300.0, 15600.0))
	assert_true(boss.is_shield_active and boss.shield_bubble.visible, "Precondition: shield up")
	var fx = boss._shield_fx
	assert_almost_eq(float(fx.rim_material.get_shader_parameter("hit_time")), 1.0, 0.0001, "Resting: no ripple")
	var hit := boss.global_position + Vector3(2.0, 0.0, 0.0)
	SignalBus.hit_blocked.emit(hit)
	var hit_pos: Vector3 = fx.rim_material.get_shader_parameter("hit_pos")
	assert_true(hit_pos.is_equal_approx(boss.global_position + Vector3(2.3, 0.0, 0.0)), "hit_pos = where the hit meets the bubble surface (%s)" % str(hit_pos))
	assert_true(fx.ripple_tween != null and fx.ripple_tween.is_valid() and fx.ripple_tween.is_running(), "The hit_time tween runs")
	assert_true(float(fx.rim_material.get_shader_parameter("hit_time")) < 0.5, "...from 0")
	await get_tree().create_timer(0.5).timeout
	assert_almost_eq(float(fx.rim_material.get_shader_parameter("hit_time")), 1.0, 0.0001, "...to 1 over 0.35 s")

func test_u3_hits_on_a_dropped_shield_or_another_target_do_not_ripple() -> void:
	var boss: EnforcerEnemy = _spawn(ENFORCER_SCENE, Vector3(0.0, 300.0, 15700.0))
	SignalBus.hit_blocked.emit(boss.global_position + Vector3(80.0, 0.0, 0.0))
	assert_eq(boss._shield_fx.ripples, 0, "A blocked hit far away is someone else's")
	boss.is_shield_active = false
	SignalBus.hit_blocked.emit(boss.global_position)
	assert_eq(boss._shield_fx.ripples, 0, "No shield, no ripple")

func test_u3_the_bosses_do_not_share_bubble_materials() -> void:
	var e1: EnforcerEnemy = _spawn(ENFORCER_SCENE, Vector3(0.0, 300.0, 15800.0))
	var e2: EnforcerEnemy = _spawn(ENFORCER_SCENE, Vector3(0.0, 300.0, 15900.0))
	var h: HeadlinerBoss = _spawn(HEADLINER_SCENE, Vector3(0.0, 300.0, 16000.0))
	var all := [e1._shield_fx, e2._shield_fx, h._shield_fx]
	for i in all.size():
		for j in range(i + 1, all.size()):
			assert_true(all[i].rim_material != all[j].rim_material, "Rim materials %d/%d are distinct instances" % [i, j])
			assert_true(all[i].base_material != all[j].base_material, "Base materials %d/%d are distinct instances" % [i, j])
	assert_true(e1.shield_bubble.get_surface_override_material(0) == e1._shield_fx.base_material, "The boss draws its own copy")
	assert_true((e1.shield_bubble.get_surface_override_material(0) as StandardMaterial3D).next_pass == e1._shield_fx.rim_material, "...whose next_pass is its own rim copy")
	e1.shield_bubble.visible = true
	SignalBus.hit_blocked.emit(e1.global_position)
	assert_almost_eq(float(e2._shield_fx.rim_material.get_shader_parameter("hit_time")), 1.0, 0.0001, "A ripple on one boss leaves the other untouched")

func test_u3_the_shield_break_flashes_white_and_swells_before_it_hides() -> void:
	var boss: EnforcerEnemy = _spawn(ENFORCER_SCENE, Vector3(0.0, 300.0, 16100.0))
	var fx = boss._shield_fx
	boss.break_shield()
	assert_false(boss.shield_bubble.visible, "The shield state hid the bubble")
	assert_eq(fx.breaks, 1, "One break flash")
	var ghost: MeshInstance3D = fx._ghost
	assert_not_null(ghost, "The flash rides a ghost copy of the bubble")
	assert_true(ghost.visible, "...still showing after the hide")
	assert_true(ghost.material_override.albedo_color.r > 1.0, "...white and over-bright")
	await get_tree().create_timer(0.25).timeout
	assert_false(ghost.visible, "...gone after 0.1 s")
	assert_almost_eq(ghost.scale.x, boss.shield_bubble.scale.x * 1.1, 0.001, "...having swelled 1.0 -> 1.1")

func test_u3_the_shader_declares_the_ripple_and_keeps_the_batch_p_blend() -> void:
	var code := (load("res://assets/shaders/shield_bubble.gdshader") as Shader).code
	assert_true(code.contains("uniform vec3 hit_pos") and code.contains("uniform float hit_time = 1.0"), "hit_pos / hit_time uniforms")
	assert_true(code.contains("blend_add") and code.contains("depth_draw_never") and code.contains("unshaded"), "Batch P render modes kept")

# --- U4 ------------------------------------------------------------------------------------

func test_u4_the_combo_flash_fires_only_on_every_tenth_combo_and_on_the_cap() -> void:
	var flash: CanvasLayer = _keep(load("res://vfx/combo_flash.tscn").instantiate())
	add_child(flash)
	for i in range(1, 10):
		SignalBus.combo_increased.emit(i)
	assert_eq(flash.milestone_flashes, 0, "Combos 1-9: no flash")
	assert_almost_eq(flash.rect.color.a, 0.0, 0.0001, "...the overlay stays clear")
	SignalBus.combo_increased.emit(10)
	assert_eq(flash.milestone_flashes, 1, "The 10th combo: one flash")
	assert_almost_eq(flash.rect.color.a, 0.12, 0.0001, "...at alpha 0.12")
	SignalBus.combo_increased.emit(11)
	assert_eq(flash.milestone_flashes, 1, "The 11th: none")
	SignalBus.combo_capped.emit()
	assert_eq(flash.milestone_flashes, 2, "combo_capped flashes")
	assert_eq(flash.FLASH_DURATION, 0.05, "0.05 s")

func test_u4_the_bass_drop_flash_path_is_untouched() -> void:
	var flash: CanvasLayer = _keep(load("res://vfx/combo_flash.tscn").instantiate())
	add_child(flash)
	SignalBus.screen_flash_requested.emit(0.35, 0.05)
	assert_almost_eq(flash.rect.color.a, 0.35, 0.0001, "screen_flash_requested still snaps the overlay")
	assert_eq(flash.milestone_flashes, 0, "...and is not a combo milestone")

# --- U5 ------------------------------------------------------------------------------------

func test_u5_the_ambient_emitter_rides_the_camera() -> void:
	var cam: DroneCamera = _keep((load("res://characters/player/drone_camera.tscn") as PackedScene).instantiate())
	cam.position = Vector3(0.0, 3.0, 4500.0)
	add_child(cam)
	var amb := cam.get_node_or_null("AmbientParticles") as GPUParticles3D
	assert_not_null(amb, "drone_camera adds the ambient emitter")
	assert_eq(amb.get_parent(), cam, "...as its child")
	assert_eq(amb.amount, 40, "40 particles")
	assert_almost_eq(amb.lifetime, 6.0, 0.0001, "6 s")
	cam.global_position = Vector3(30.0, 3.0, 4600.0)
	amb._process(0.0)
	var expected := cam.global_position - cam.global_basis.z * 10.0
	assert_true(amb.global_position.is_equal_approx(expected), "The box follows the camera (%s vs %s)" % [str(amb.global_position), str(expected)])
	assert_eq(amb.jump_restarts, 1, "A 100 m camera jump re-fills the box (restart + preprocess)")
	cam.global_position += Vector3(0.3, 0.0, 0.0)
	amb._process(0.0)
	assert_eq(amb.jump_restarts, 1, "...a normal frame of travel does not")

func test_u5_the_zone_colour_applies_on_zone_entered() -> void:
	var cam: DroneCamera = _keep((load("res://characters/player/drone_camera.tscn") as PackedScene).instantiate())
	cam.position = Vector3(0.0, 3.0, 4700.0)
	add_child(cam)
	var amb = cam.get_node("AmbientParticles")
	assert_true(amb.current_color.is_equal_approx(Atmo.AMBIENT_DUST_CYAN), "Zone 1: cyan dust")
	SignalBus.zone_entered.emit("SECTOR 07 - ENFORCER")
	assert_eq(amb.current_zone, 7, "Zone 7 applied")
	assert_true(amb.current_color.is_equal_approx(Atmo.AMBIENT_MOTE_MAGENTA), "Zones 6-10: magenta motes")
	assert_eq(amb.current_style, "mote", "...motes")
	assert_true(amb._material.albedo_color.r > 1.0, "...over-bright")
	SignalBus.zone_entered.emit("SECTOR 05 - MARKET")
	assert_eq(amb.current_style, "rain", "Zones 4-5: rain")
	assert_eq(amb.amount, Atmo.TABLE[5]["ambient_amount"], "...with the table's count")
	assert_almost_eq(amb.lifetime, 0.9, 0.0001, "...short-lived streaks")
	assert_true((amb._quad as QuadMesh).size.y > 0.3, "...stretched quads")
	assert_true(amb._process_mat.direction.y < 0.0 and amb._process_mat.initial_velocity_min > 5.0, "...falling")
	SignalBus.zone_entered.emit("SECTOR 02 - SEWERS")
	assert_eq(amb.current_style, "dust", "Zones 1-3: dust again")

func test_u5_the_ambient_table_stays_inside_the_particle_budget() -> void:
	for zone in range(1, 11):
		var row := Atmo.get_atmosphere(zone)
		assert_true(row.has("ambient_color") and row.has("ambient_amount") and row.has("ambient_style"), "Zone %d has the ambient columns" % zone)
		assert_true(int(row["ambient_amount"]) <= 80, "Zone %d: <= 80 live ambient particles" % zone)

func test_u5_a_pulse_lifts_the_trim_and_it_returns_to_base() -> void:
	var fx: Node = _keep(NeonFlickerScript.new())
	fx.dropouts_enabled = false
	add_child(fx)
	SignalBus.beat.disconnect(fx._on_beat)  # the real Conductor must not pulse mid-test
	assert_eq(fx.materials.size(), 4, "cyan, magenta, sodium, red")
	var cyan: StandardMaterial3D = load("res://assets/materials/trim_cyan.tres")
	var base: float = fx.base_of(cyan)
	assert_almost_eq(base, 3.0, 0.0001, "Authored cyan energy 3.0")
	fx.pulse()
	assert_almost_eq(cyan.emission_energy_multiplier, base * 1.3, 0.0001, "+30 % on the beat")
	await get_tree().create_timer(0.3).timeout
	assert_almost_eq(cyan.emission_energy_multiplier, base, 0.0001, "...back to base after 0.1 s")
	for mat in fx.materials:
		assert_almost_eq(mat.emission_energy_multiplier, fx.base_of(mat), 0.0001, "Every trim rests at its base")

func test_u5_the_flicker_listens_to_the_bus_beat() -> void:
	var fx: Node = _keep(NeonFlickerScript.new())
	fx.dropouts_enabled = false
	add_child(fx)
	assert_true(SignalBus.beat.is_connected(fx._on_beat), "NeonFlicker subscribes to SignalBus.beat")
	SignalBus.beat.disconnect(fx._on_beat)

func test_u5_the_primary_beat_drives_the_pulse_and_a_dropout_recovers() -> void:
	var fx: Node = _keep(NeonFlickerScript.new())
	fx.dropouts_enabled = false
	add_child(fx)
	SignalBus.beat.disconnect(fx._on_beat)  # the real Conductor must not pulse mid-test
	fx._on_beat("secondary", 1)
	assert_eq(fx.pulses, 0, "Only the primary layer pulses")
	fx._on_beat("primary", 1)
	assert_eq(fx.pulses, 1, "A primary beat pulses")
	var magenta: StandardMaterial3D = load("res://assets/materials/trim_magenta.tres")
	var base: float = fx.base_of(magenta)
	fx.drop_out(magenta)
	assert_true(magenta.emission_energy_multiplier < base * 0.5, "A dropout cuts the tube")
	await get_tree().create_timer(0.3).timeout
	assert_almost_eq(magenta.emission_energy_multiplier, base, 0.0001, "...and it relights after 0.1 s")

func test_u5_leaving_the_tree_mid_pulse_restores_the_authored_energy() -> void:
	var fx: Node = NeonFlickerScript.new()
	fx.dropouts_enabled = false
	add_child(fx)
	SignalBus.beat.disconnect(fx._on_beat)  # the real Conductor must not pulse mid-test
	var sodium: StandardMaterial3D = load("res://assets/materials/trim_sodium.tres")
	var base: float = fx.base_of(sodium)
	fx.pulse()
	fx.free()
	assert_almost_eq(sodium.emission_energy_multiplier, base, 0.0001, "Freed mid-pulse: back to base")
	var fx2: Node = _keep(NeonFlickerScript.new())
	fx2.dropouts_enabled = false
	add_child(fx2)
	assert_almost_eq(fx2.base_of(sodium), 2.5, 0.0001, "A later flicker node still reads the authored 2.5")
