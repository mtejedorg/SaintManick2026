extends "res://tests/framework/test_case.gd"

# Batch K (owner decisions D3, D22, D6, D14, D7, D8, D13, D17, D28, D21, D20): combat and feel.

const PLAYER_SCENE := "res://characters/player/player.tscn"
const BRUISER_SCENE := "res://characters/enemies/bruiser/bruiser.tscn"
const HEADLINER_SCENE := "res://characters/enemies/headliner/headliner.tscn"
const ENFORCER_SCENE := "res://characters/enemies/enforcer/enforcer.tscn"
const CAMERA_SCENE := "res://characters/player/drone_camera.tscn"
const COMBO_TRI_CUT := "res://characters/player/combos/combo_tri_cut.tres"
const COMBO_LAUNCHER := "res://characters/player/combos/combo_launcher.tres"
const COMBO_SWEEPER := "res://characters/player/combos/combo_sweeper.tres"
const COMBO_BATTERY_RAM := "res://characters/player/combos/combo_battery_ram.tres"
const BRUISER_STATS := "res://characters/enemies/bruiser/bruiser_stats.tres"
const ENEMY_BODY_BIT := 4 # collision layer 3

var _nodes: Array[Node] = []

func after_each() -> void:
	for n in _nodes:
		if is_instance_valid(n):
			n.queue_free()
	_nodes.clear()
	Conductor.layers["primary"].time_accumulator = (60.0 / Conductor.bpm) * 0.5

func _keep(n: Node) -> Node:
	_nodes.append(n)
	return n

## A fresh Nick far from every other test body, off the beat.
func _player(z: float) -> PlayerController:
	var player: PlayerController = load(PLAYER_SCENE).instantiate()
	player.position = Vector3(0.0, 200.0, z)
	add_child(player)
	_keep(player)
	Conductor.layers["primary"].time_accumulator = (60.0 / Conductor.bpm) * 0.5
	return player

func _attack(player: PlayerController, heavy: bool) -> Node:
	player.pending_attack_heavy = heavy
	player.state_machine._on_transition_requested("StateAttack")
	return player.state_machine.get_node("StateAttack")

# --- K1 (D3) -------------------------------------------------------------------------

## Cycle DPS of a chain under the real chain timing: a buffered press fires the next hit
## once the timer drops under COMBO_WINDOW, the capped last hit runs its full window.
func _chain_dps(damages: Array[float], durations: Array[float], combo_window: float) -> float:
	var total := 0.0
	var time := 0.0
	for i in damages.size():
		total += damages[i]
		time += durations[i] if i == damages.size() - 1 else durations[i] - combo_window
	return total / time

func test_k1_heavy_windows_and_finisher_damage_ship_the_decision() -> void:
	var player := _player(12000.0)
	var attack: Node = player.state_machine.get_node("StateAttack")
	assert_eq(attack.heavy_attack_durations, [0.45, 0.45, 0.75] as Array[float], "K1: generic heavy windows 0.45 / 0.45 / 0.75 s")
	assert_eq(attack.attack_durations, [0.3, 0.3, 0.6] as Array[float], "K1: light windows untouched")
	assert_eq((load(COMBO_TRI_CUT) as ComboDef).damage, 32.0, "K1: Tri-Cut 32 (D3 ordering: mash <= Tri-Cut)")
	assert_eq((load(COMBO_LAUNCHER) as ComboDef).damage, 40.0, "K1: Launcher 40")
	assert_eq((load(COMBO_BATTERY_RAM) as ComboDef).damage, 55.0, "K1: Battery Ram 55")
	assert_eq((load(COMBO_SWEEPER) as ComboDef).damage, 20.0, "K1: Sweeper stays 20 (the crowd tool)")
	# A generic heavy really runs the slower window.
	_attack(player, true)
	assert_almost_eq(attack.attack_timer, 0.45, 0.0001, "K1: the first generic heavy runs 0.45 s")

func test_k1_named_routes_out_damage_heavy_mashing() -> void:
	var player := _player(12020.0)
	var attack: Node = player.state_machine.get_node("StateAttack")
	var window: float = attack.COMBO_WINDOW
	# Generic values read from the shipped attack state (a lone A or B never matches a route).
	_attack(player, true)
	var heavy: float = player.bionic_arm_hitbox.damage_info.amount
	player.state_machine._on_transition_requested("StateIdle")
	_attack(player, false)
	var light: float = player.katana_hitbox.damage_info.amount
	var h: Array[float] = attack.heavy_attack_durations
	var l: Array[float] = attack.attack_durations
	var tri: ComboDef = load(COMBO_TRI_CUT)
	var lau: ComboDef = load(COMBO_LAUNCHER)
	var ram: ComboDef = load(COMBO_BATTERY_RAM)
	var mash := _chain_dps([heavy, heavy, heavy] as Array[float], h, window)
	var tri_dps := _chain_dps([light, light, tri.damage] as Array[float], [l[0], l[1], tri.duration] as Array[float], window)
	var lau_dps := _chain_dps([light, light, lau.damage] as Array[float], [l[0], l[1], lau.duration] as Array[float], window)
	var ram_dps := _chain_dps([heavy, ram.damage] as Array[float], [h[0], ram.duration] as Array[float], window)
	print("     K1 DPS  mash %.1f  tri-cut %.1f  launcher %.1f  battery ram %.1f" % [mash, tri_dps, lau_dps, ram_dps])
	assert_lt(tri_dps, lau_dps, "K1: Tri-Cut < Launcher (%.1f vs %.1f)" % [tri_dps, lau_dps])
	assert_lt(lau_dps, ram_dps, "K1: Launcher < Battery Ram (%.1f vs %.1f)" % [lau_dps, ram_dps])
	assert_gt(lau_dps, mash, "K1: Launcher beats heavy mashing (%.1f vs %.1f)" % [lau_dps, mash])
	assert_gt(ram_dps, mash, "K1: Battery Ram beats heavy mashing (%.1f vs %.1f)" % [ram_dps, mash])
	# D3: mash <= Tri-Cut (Tri-Cut raised 30 -> 32 so the ordering holds with the real chain timing).
	assert_true(mash <= tri_dps, "K1: heavy mashing must not out-DPS Tri-Cut (%.1f vs %.1f)" % [mash, tri_dps])

# --- K2 (D22) ------------------------------------------------------------------------

func test_k2_free_dodge_cancel_late_in_recovery_after_a_connected_hit() -> void:
	var player := _player(12040.0)
	var attack: Node = _attack(player, false)
	player.ability_meter = 50.0
	var recovery: float = attack.current_hit_duration * (1.0 - attack.ACTIVE_WINDOW_FRACTION)
	# 30 percent into recovery: no free cancel yet.
	attack.attack_timer = recovery * 0.7
	player.hit_connected = true
	player.buffer_dodge("StateRoll")
	assert_false(attack._try_dodge_cancel(false), "K2: no free cancel at 30 percent of recovery")
	assert_eq(player.state_machine.current_state, attack, "...Nick is still attacking")
	# 70 percent into recovery, hit connected: the buffered roll fires for free.
	attack.attack_timer = recovery * 0.3
	assert_true(attack._try_dodge_cancel(false), "K2: free cancel at 70 percent of recovery after a connected hit")
	assert_eq(player.state_machine.current_state.name, "StateRoll", "...straight into the roll")
	assert_eq(player.ability_meter, 50.0, "...without spending meter")

func test_k2_no_free_cancel_after_a_whiff() -> void:
	var player := _player(12060.0)
	var attack: Node = _attack(player, false)
	var recovery: float = attack.current_hit_duration * (1.0 - attack.ACTIVE_WINDOW_FRACTION)
	attack.attack_timer = recovery * 0.3
	assert_false(player.hit_connected, "A new hit has not connected yet")
	player.buffer_dodge("StateDash")
	assert_false(attack._try_dodge_cancel(true), "K2: a whiffed hit has no free cancel")
	assert_eq(player.state_machine.current_state, attack, "...Nick is still attacking")

func test_k2_a_landed_hit_marks_the_hit_connected_and_a_new_hit_clears_it() -> void:
	var player := _player(12080.0)
	_attack(player, false)
	var info := DamageInfo.new()
	info.amount = 12.0
	info.source = player
	player._on_player_hit_landed(info)
	assert_true(player.hit_connected, "A landed hit connects")
	player.state_machine._on_transition_requested("StateIdle")
	_attack(player, true)
	assert_false(player.hit_connected, "A new hit starts unconnected")
	player._on_hit_blocked(Vector3.ZERO)
	assert_true(player.hit_connected, "A shield-absorbed hit connected too")

func test_k2_emp_cancel_moved_into_the_active_window() -> void:
	var player := _player(12100.0)
	var attack: Node = _attack(player, false)
	player.ability_meter = 30.0
	var recovery: float = attack.current_hit_duration * (1.0 - attack.ACTIVE_WINDOW_FRACTION)
	# Recovery, no connected hit: the paid cancel no longer lives here.
	attack.attack_timer = recovery * 0.5
	assert_false(attack._try_dodge_cancel(true), "K2: no EMP cancel in recovery any more")
	assert_eq(player.ability_meter, 30.0, "...and no meter spent")
	# Active window: a dash press with >= 25 meter cancels and pays.
	attack.attack_timer = attack.current_hit_duration * 0.9
	assert_true(attack.is_in_active_window(), "Precondition: inside the active window")
	assert_true(attack._try_dodge_cancel(true), "K2: EMP cancel during the active window")
	assert_eq(player.state_machine.current_state.name, "StateDash", "...into the dash")
	assert_almost_eq(player.ability_meter, 5.0, 0.0001, "...spending 25 meter")

# --- K3 (D6) -------------------------------------------------------------------------

func test_k3_dodge_tuning_values() -> void:
	var player := _player(12120.0)
	assert_almost_eq(player.beat_align_window, 0.06, 0.0001, "K3: beat_align_window 0.06")
	assert_almost_eq(player.dodge_cooldown, 0.3, 0.0001, "K3: dodge_cooldown 0.3")

func test_k3_a_dodge_008_off_the_beat_is_not_rewarded() -> void:
	var player := _player(12140.0)
	player.ability_meter = 0.0
	Conductor.layers["primary"].time_accumulator = 0.08
	player.state_machine._on_transition_requested("StateDash")
	assert_eq(player.ability_meter, 0.0, "K3: 0.08 s off the beat pays no meter")
	player.state_machine._on_transition_requested("StateIdle")
	assert_almost_eq(player._dodge_cooldown_timer, player.dodge_cooldown, 0.0001, "...and refunds no cooldown")

func test_k3_a_dodge_004_off_the_beat_is_rewarded_with_the_cue() -> void:
	var player := _player(12160.0)
	player.ability_meter = 0.0
	var flags := {"cue": 0}
	var on_cue := func(): flags.cue += 1
	SignalBus.beat_dodge_landed.connect(on_cue)
	Conductor.layers["primary"].time_accumulator = 0.04
	player.state_machine._on_transition_requested("StateRoll")
	SignalBus.beat_dodge_landed.disconnect(on_cue)
	assert_eq(player.ability_meter, player.beat_aligned_dodge_meter, "K3: 0.04 s off the beat pays the meter")
	assert_eq(flags.cue, 1, "K3: beat_dodge_landed fired once")
	assert_true(player.character_visual.get_current_rim_color().is_equal_approx(player.BEAT_DODGE_RIM_COLOR), "K3: the rim flashes cyan")
	player.state_machine._on_transition_requested("StateIdle")
	assert_almost_eq(player._dodge_cooldown_timer, player.dodge_cooldown * 0.5, 0.0001, "K3: half the cooldown is refunded")

func test_k3_the_meter_reward_pays_at_most_once_per_two_beats() -> void:
	var player := _player(12180.0)
	player.ability_meter = 0.0
	var layer: Dictionary = Conductor.layers["primary"]
	var beat_before: int = layer.beat_index
	var dash: Node = player.state_machine.get_node("StateDash")
	var roll: Node = player.state_machine.get_node("StateRoll")
	layer.time_accumulator = 0.0
	dash.enter()
	dash.exit()
	layer.beat_index = beat_before + 1 # the very next beat
	layer.time_accumulator = 0.0
	roll.enter()
	roll.exit()
	assert_eq(player.ability_meter, player.beat_aligned_dodge_meter, "K3: two rewarded dodges within 2 beats give +4 once")
	layer.beat_index = beat_before + 2
	layer.time_accumulator = 0.0
	dash.enter()
	dash.exit()
	assert_eq(player.ability_meter, player.beat_aligned_dodge_meter * 2.0, "K3: two beats later it pays again")
	layer.beat_index = beat_before

# --- K4 (D14) ------------------------------------------------------------------------

func test_k4_roll_speed_covers_about_seven_metres() -> void:
	var player := _player(12200.0)
	var roll: Node = player.state_machine.get_node("StateRoll")
	assert_almost_eq(player.roll_speed, 11.0, 0.0001, "K4: roll_speed 11")
	var distance: float = player.roll_speed * (roll.roll_iframe_duration + roll.roll_recovery_duration)
	assert_almost_eq(distance, 7.2, 0.1, "K4: a roll covers about 7.2 m (got %.2f)" % distance)
	assert_almost_eq(player.dash_speed, 18.0, 0.0001, "K4: dash untouched")

# --- K5 (D7) -------------------------------------------------------------------------

func test_k5_bruiser_shield_80_against_generic_heavies_and_battery_ram() -> void:
	assert_eq((load(BRUISER_STATS) as EnemyStats).shield, 80.0, "K5: Bruiser shield 80")
	var player := _player(12220.0)
	_attack(player, true)
	var heavy: DamageInfo = player.bionic_arm_hitbox.damage_info.duplicate()
	var bruiser: Node3D = _keep(load(BRUISER_SCENE).instantiate())
	bruiser.position = Vector3(0.0, 200.0, 12240.0)
	add_child(bruiser)
	var health: HealthComponent = bruiser.get_node("HealthComponent")
	assert_eq(health.current_shield, 80.0, "K5: the Bruiser spawns with 80 shield")
	# A generic heavy pressures shields at its 2x multiplier: 28 -> 56 shield damage.
	health.take_damage(heavy)
	assert_gt(health.current_shield, 0.0, "K5: one generic heavy (56 shield damage) no longer breaks it")
	health.take_damage(heavy)
	assert_eq(health.current_shield, 0.0, "K5: the second generic heavy (112) breaks it")
	# Battery Ram (55, shield breaker) zeroes a full shield on its own.
	var fresh: Node3D = _keep(load(BRUISER_SCENE).instantiate())
	fresh.position = Vector3(0.0, 200.0, 12260.0)
	add_child(fresh)
	var ram_def: ComboDef = load(COMBO_BATTERY_RAM)
	var ram := DamageInfo.new()
	ram.amount = ram_def.damage
	ram.is_shield_breaker = ram_def.is_shield_breaker
	var fresh_health: HealthComponent = fresh.get_node("HealthComponent")
	fresh_health.take_damage(ram)
	assert_eq(fresh_health.current_shield, 0.0, "K5: Battery Ram breaks the 80 shield")

# --- K6 (D8) -------------------------------------------------------------------------

func test_k6_bass_drop_reaches_ten_metres_for_ninety() -> void:
	var player := _player(12280.0)
	assert_almost_eq(player.bass_drop_radius, 10.0, 0.0001, "K6: radius 10")
	assert_almost_eq(player.bass_drop_damage, 90.0, 0.0001, "K6: damage 90")
	var near: Node3D = _keep(load(BRUISER_SCENE).instantiate())
	add_child(near)
	near.global_position = player.global_position + Vector3(9.0, 0.0, 0.0)
	var far: Node3D = _keep(load(BRUISER_SCENE).instantiate())
	add_child(far)
	far.global_position = player.global_position + Vector3(11.0, 0.0, 0.0)
	var near_hc: HealthComponent = near.get_node("HealthComponent")
	var far_hc: HealthComponent = far.get_node("HealthComponent")
	var near_before: float = near_hc.current_health
	player.ability_meter = player.MAX_ABILITY_METER
	assert_true(player.try_arm_bass_drop(), "Precondition: armed")
	var ring: MeshInstance3D = null
	player._detonate_bass_drop()
	for c in get_children():
		if c.name.begins_with("BassDropRing"):
			ring = c
			_keep(c)
	assert_eq(near_hc.current_shield, 0.0, "K6: a Bruiser 9 m away loses its shield")
	assert_lt(near_hc.current_health, near_before, "K6: ...and takes the HP damage")
	assert_eq(far_hc.current_shield, far_hc.max_shield, "K6: one 11 m away is untouched")
	assert_not_null(ring, "K6: the shock ring still spawns")

# --- K7 (D13) ------------------------------------------------------------------------

func test_k7_headliner_phase_two_reads_half_of_the_new_max_health() -> void:
	var boss: HeadlinerBoss = _keep(load(HEADLINER_SCENE).instantiate())
	boss.position = Vector3(0.0, 300.0, 12300.0)
	add_child(boss)
	boss.activate_boss()
	assert_eq(boss.health_component.max_health, 2400.0, "K7: the Headliner fights at 2400 HP")
	boss._on_health_changed(1250.0, 2400.0)
	assert_false(boss.phase_2_triggered, "K7: 1250 of 2400 HP stays in phase 1")
	boss._on_health_changed(1200.0, 2400.0)
	assert_true(boss.phase_2_triggered, "K7: 1200 HP (half of 2400) triggers phase 2")
	Conductor.target_bpm = Conductor.get_resting_bpm()
	Conductor.bpm = Conductor.get_resting_bpm()

func test_k7_enforcer_fights_at_900() -> void:
	var enforcer: Node3D = _keep(load(ENFORCER_SCENE).instantiate())
	enforcer.position = Vector3(0.0, 300.0, 12320.0)
	add_child(enforcer)
	assert_eq(enforcer.get_node("HealthComponent").max_health, 900.0, "K7: the Enforcer fights at 900 HP")

# --- K8 (D17) ------------------------------------------------------------------------

func test_k8_the_roll_passes_through_enemies_only_during_its_iframes() -> void:
	var player := _player(12340.0)
	assert_true((player.collision_mask & ENEMY_BODY_BIT) != 0, "Precondition: Nick collides with enemy bodies")
	player.state_machine._on_transition_requested("StateRoll")
	var roll: Node = player.state_machine.get_node("StateRoll")
	assert_eq(player.collision_mask & ENEMY_BODY_BIT, 0, "K8: during the roll i-frames the mask excludes layer 3")
	roll.physics_update(roll.roll_iframe_duration + 0.01)
	assert_true((player.collision_mask & ENEMY_BODY_BIT) != 0, "K8: the vulnerable roll tail collides again")
	player.state_machine._on_transition_requested("StateIdle")
	assert_eq(player.collision_mask, 5, "K8: after the roll the mask is world + enemies again")

func test_k8_the_dash_restores_the_mask_on_exit() -> void:
	var player := _player(12360.0)
	player.state_machine._on_transition_requested("StateDash")
	assert_eq(player.collision_mask & ENEMY_BODY_BIT, 0, "K8: the dash passes through enemies")
	player.state_machine._on_transition_requested("StateIdle")
	assert_true((player.collision_mask & ENEMY_BODY_BIT) != 0, "K8: ...until it ends")

func test_k8_a_respawn_mid_roll_restores_the_mask() -> void:
	var player := _player(12380.0)
	player.state_machine._on_transition_requested("StateRoll")
	assert_eq(player.collision_mask & ENEMY_BODY_BIT, 0, "Precondition: mid-roll")
	player._on_player_respawned()
	assert_true((player.collision_mask & ENEMY_BODY_BIT) != 0, "K8: after a respawn mid-roll the mask includes layer 3")
	assert_false(player.health_component._iframes, "K8: the roll i-frames ended too")

# --- K9 (D28) ------------------------------------------------------------------------

func test_k9_a_lost_life_empties_the_ability_meter() -> void:
	var player := _player(12400.0)
	var was_ended: bool = GameManager.run_ended
	GameManager.run_ended = false
	player.ability_meter = 80.0
	var flags := {"value": -1.0}
	var on_meter := func(current: float, _max_meter: float): flags.value = current
	SignalBus.ability_meter_changed.connect(on_meter)
	SignalBus.player_life_lost.emit(2)
	SignalBus.ability_meter_changed.disconnect(on_meter)
	GameManager.run_ended = was_ended
	assert_eq(player.ability_meter, 0.0, "K9: the meter resets on a lost life")
	assert_eq(flags.value, 0.0, "K9: ...and ability_meter_changed fired with 0")

# --- K10 (D21) -----------------------------------------------------------------------

func test_k10_camera_closer_and_the_ring_follows_the_top_down_shift() -> void:
	assert_eq(DroneCamera.TOP_DOWN_OFFSET, Vector3(0, 12, 4.5), "K10: top-down offset (0, 12, 4.5)")
	assert_almost_eq(DroneCamera.TOP_DOWN_ROTATION.x, -PI / 3.0, 0.0001, "K10: the pitch stays -60 deg")
	var player := _player(12420.0)
	var rail := Path3D.new()
	rail.curve = Curve3D.new()
	rail.curve.add_point(Vector3(-5.0, 200.0, 12420.0))
	rail.curve.add_point(Vector3(5.0, 200.0, 12420.0))
	add_child(rail)
	_keep(rail)
	player.current_path = rail
	var ring: Node3D = player.get_node("TopDownRing")
	assert_false(ring.visible, "K10: no ring on a rail")
	var camera: DroneCamera = _keep(load(CAMERA_SCENE).instantiate())
	add_child(camera)
	camera.target = player
	var transitioning: Node = camera.state_machine.states["transitioning"]
	SignalBus.camera_shift_requested.emit(true, rail, 0.05)
	await transitioning.current_tween.finished
	assert_true(ring.visible, "K10: the ring shows after the shift to top-down")
	assert_eq(camera.offset, DroneCamera.TOP_DOWN_OFFSET, "K10: the camera sits at the closer offset")
	SignalBus.camera_shift_requested.emit(false, rail, 0.05)
	await transitioning.current_tween.finished
	assert_false(ring.visible, "K10: the ring hides after the shift back")

# --- K11 (D20) -----------------------------------------------------------------------

func _lethal(player: PlayerController) -> void:
	var killer := Node3D.new()
	killer.name = "Runner"
	add_child(killer)
	_keep(killer)
	var info := DamageInfo.new()
	info.amount = 9999.0
	info.source = killer
	player.health_component.take_damage(info)

func _real_seconds(seconds: float) -> void:
	await get_tree().create_timer(seconds, true, false, true).timeout

func test_k11_a_lethal_hit_holds_a_death_beat_before_the_respawn() -> void:
	GameManager.start_new_run()
	var lives_before: int = GameManager.current_lives
	var player := _player(12440.0)
	var flags := {"respawned": false, "killer_at_life_lost": "<unset>"}
	var on_respawn := func(): flags.respawned = true
	var on_life_lost := func(_lives: int): flags.killer_at_life_lost = GameManager.last_killer
	SignalBus.player_respawned.connect(on_respawn)
	SignalBus.player_life_lost.connect(on_life_lost)
	_lethal(player)
	assert_true(player.input_locked, "K11: input locks on the lethal hit")
	await get_tree().process_frame
	assert_eq(player.state_machine.current_state.name, "StateDead", "K11: Nick holds the death clip (StateDead)")
	await _real_seconds(0.5)
	assert_false(flags.respawned, "K11: no respawn at 0.5 s")
	assert_eq(GameManager.current_lives, lives_before, "K11: ...no life spent yet")
	assert_true(player.input_locked, "K11: input is still locked during the beat")
	await _real_seconds(0.5)
	assert_true(flags.respawned, "K11: the respawn has happened at 1.0 s")
	assert_eq(GameManager.current_lives, lives_before - 1, "K11: ...one life spent")
	assert_eq(flags.killer_at_life_lost, "RUNNER", "K11: last_killer is set before player_life_lost fires")
	assert_false(player.input_locked, "K11: the respawn unlocks input")
	assert_true(player.state_machine.current_state.name != "StateDead", "K11: ...out of StateDead (Idle hands off to Airborne here, no floor)")
	assert_almost_eq(Engine.time_scale, 1.0, 0.0001, "K11: the death slow-motion is over")
	SignalBus.player_respawned.disconnect(on_respawn)
	SignalBus.player_life_lost.disconnect(on_life_lost)
	GameManager.start_new_run()

func test_k11_input_is_locked_during_the_beat() -> void:
	GameManager.start_new_run()
	var player := _player(12460.0)
	# Control: an unlocked press is buffered.
	Input.action_press("attack_light")
	player._tick_input_buffers(0.0)
	assert_true(player.has_buffered_attack(), "Control: a live press is buffered")
	Input.action_release("attack_light")
	player.clear_attack_buffer()
	_lethal(player)
	Input.action_press("attack_light")
	Input.action_press("move_right")
	player._tick_input_buffers(0.0)
	var move: Vector2 = player.get_movement_input()
	Input.action_release("attack_light")
	Input.action_release("move_right")
	assert_false(player.has_buffered_attack(), "K11: a press during the death beat is not recorded")
	assert_eq(move, Vector2.ZERO, "K11: movement reads zero during the death beat")
	GameManager.start_new_run()

func test_k11_the_final_death_also_waits_the_beat_before_the_game_over() -> void:
	GameManager.start_new_run()
	var was_test: bool = GameManager.is_test
	GameManager.is_test = true # no scene change
	GameManager.current_lives = 0
	var player := _player(12480.0)
	_lethal(player)
	await _real_seconds(0.5)
	assert_false(GameManager.run_ended, "K11: the game over waits the beat (0.5 s)")
	await _real_seconds(0.55)
	assert_true(GameManager.run_ended, "K11: ...and lands after it (1.05 s)")
	GameManager.is_test = was_test
	GameManager.start_new_run()
