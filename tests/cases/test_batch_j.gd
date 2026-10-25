extends "res://tests/framework/test_case.gd"

# Batch J (round-3 no-decision fixes). J9/J10 geometry lives in test_zone_trigger_isolation /
# test_level_fixes; J14 assertions in test_headliner_boss; the rest is here.

const PLAYER_SCENE := "res://characters/player/player.tscn"
const PROJECTILE_SCENE := "res://levels/components/pooled_projectile.tscn"
const SNIPER_SCENE := "res://characters/enemies/sniper/sniper.tscn"
const RUNNER_SCENE := "res://characters/enemies/runner/runner.tscn"
const CAMERA_SCENE := "res://characters/player/drone_camera.tscn"
const ONBOARDING_SCRIPT := "res://levels/components/onboarding_prompts.gd"
const FocusGrace = preload("res://ui/menus/focus_grace.gd")
const STEP := 1.0 / 60.0

## Real zone names use an em dash ("SECTOR NN -- DESCRIPTION"); kept out of the source bytes.
var zone_1: String = "SECTOR 01 " + String.chr(0x2014) + " STREET ENTRANCE"

## Collects every engine error printed while it is registered (OS.add_logger).
class ErrorCatcher extends Logger:
	var lines: Array[String] = []
	var _mutex := Mutex.new()

	func _log_error(function: String, file: String, line: int, code: String, rationale: String, _editor_notify: bool, _error_type: int, _script_backtraces: Array[ScriptBacktrace]) -> void:
		_mutex.lock()
		lines.append("%s (%s:%d) %s %s" % [function, file, line, code, rationale])
		_mutex.unlock()

	func _log_message(message: String, error: bool) -> void:
		if not error:
			return
		_mutex.lock()
		lines.append(message)
		_mutex.unlock()

	func flush_errors() -> Array[String]:
		var out: Array[String] = []
		_mutex.lock()
		for l in lines:
			var low := l.to_lower()
			if low.contains("flushing queries") or low.contains("blocked during in/out"):
				out.append(l)
		_mutex.unlock()
		return out

var _extra: Array[Node] = []

func after_each() -> void:
	super.after_each()
	for n in _extra:
		if is_instance_valid(n):
			n.queue_free()
	_extra.clear()
	Engine.time_scale = 1.0
	get_tree().paused = false
	GameManager.respawn_grace_duration = 1.0

func _keep(node: Node) -> Node:
	_extra.append(node)
	return node

func _make_floor(parent: Node, top_center: Vector3, size: Vector3 = Vector3(20.0, 1.0, 20.0)) -> StaticBody3D:
	var body := StaticBody3D.new()
	var shape := CollisionShape3D.new()
	var box := BoxShape3D.new()
	box.size = size
	shape.shape = box
	body.add_child(shape)
	parent.add_child(body)
	body.global_position = top_center - Vector3(0.0, size.y * 0.5, 0.0)
	return _keep(body) as StaticBody3D

# --- J13 -----------------------------------------------------------------------------

func test_lethal_hitbox_overlap_respawns_outside_the_physics_flush() -> void:
	GameManager.start_new_run()
	var lives_before: int = GameManager.current_lives
	var scene: Node = get_tree().current_scene
	var origin := Vector3(0.0, 0.0, 9600.0)
	_make_floor(scene, origin - Vector3(0.0, 1.0, 0.0), Vector3(60.0, 1.0, 20.0))
	var player: PlayerController = load(PLAYER_SCENE).instantiate()
	player.name = "Player" # GameManager._find_player() looks it up under current_scene
	player.position = origin
	scene.add_child(player)
	_keep(player)
	player.current_path = null

	var gate := CSGBox3D.new()
	gate.size = Vector3(0.5, 3.0, 4.0)
	scene.add_child(gate)
	_keep(gate)
	gate.global_position = origin + Vector3(6.0, 0.5, 0.0)
	var enc := ZoneEncounter.new()
	var gates: Array[Node3D] = [gate]
	enc.gates = gates
	scene.add_child(enc)
	_keep(enc)
	enc.global_position = origin + Vector3(40.0, 0.0, 0.0)
	enc.active = true
	enc.set_gate_locked(true)

	var pool := ObjectPool.new()
	pool.template = load(PROJECTILE_SCENE)
	pool.initial_pool_size = 4
	scene.add_child(pool)
	_keep(pool)
	for i in 3:
		var bullet: Node3D = pool.acquire()
		bullet.global_position = origin + Vector3(-20.0 - i, 0.0, 0.0)
	SignalBus.player_respawned.connect(pool.release_all) # what the Headliner does
	for i in 4:
		await get_tree().physics_frame
	await get_tree().process_frame
	assert_true(gate.use_collision, "Precondition: the gate is shut")

	var catcher := ErrorCatcher.new()
	OS.add_logger(catcher)
	var killer := Node3D.new()
	killer.name = "Runner"
	scene.add_child(killer)
	_keep(killer)
	var hitbox := Hitbox3D.new()
	hitbox.collision_layer = 8192
	hitbox.collision_mask = 1024
	var info := DamageInfo.new()
	info.amount = 9999.0
	info.source = killer
	hitbox.damage_info = info
	var hit_shape := CollisionShape3D.new()
	var sphere := SphereShape3D.new()
	sphere.radius = 1.0
	hit_shape.shape = sphere
	hitbox.add_child(hit_shape)
	hitbox.is_active = true
	scene.add_child(hitbox)
	_keep(hitbox)
	hitbox.global_position = player.global_position

	var frames := 0
	while GameManager.current_lives == lives_before and frames < 40:
		await get_tree().physics_frame
		frames += 1
	await get_tree().process_frame
	await get_tree().physics_frame
	OS.remove_logger(catcher)

	assert_eq(GameManager.current_lives, lives_before - 1, "The real overlap killed Nick and spent a life")
	assert_almost_eq(player.health_component.current_health, player.health_component.max_health, 0.001, "...and the respawn refilled him")
	assert_true(player.health_component.grace_invincible, "...with the respawn grace")
	assert_eq(pool.inactive_pool.size(), pool.get_child_count(), "Every in-flight bullet went back to the pool")
	assert_false(gate.use_collision, "The encounter's CSG gate opened on the respawn")
	var errors := catcher.flush_errors()
	assert_eq(errors.size(), 0, "No physics-flush errors: %s" % str(errors))
	hitbox.is_active = false
	GameManager.start_new_run()

# --- shared helpers ------------------------------------------------------------------

## Nick standing on a fresh floor, physics frozen (states stepped by hand), off-rail.
func _grounded_player(origin: Vector3) -> PlayerController:
	_make_floor(self, origin - Vector3(0.0, 1.0, 0.0))
	var player: PlayerController = load(PLAYER_SCENE).instantiate()
	player.position = origin
	add_child(player)
	_keep(player)
	player.current_path = null
	for i in 3:
		await get_tree().physics_frame
	player.set_physics_process(false)
	player.state_machine.set_physics_process(false)
	player.health_component.current_shield = 0.0
	player.health_component.current_health = 100.0
	return player

func _zero_stun_hit(at: Vector3) -> DamageInfo:
	var src := Node3D.new()
	add_child(src)
	_keep(src)
	src.global_position = at
	var info := DamageInfo.new()
	info.amount = 5.0
	info.knockback = 0.0
	info.stun = 0.0
	info.source = src
	return info

func _collect_banners() -> Array[String]:
	var got: Array[String] = []
	SignalBus.banner_requested.connect(func(text: String, _hold: float): got.append(text))
	return got

func _wait_real(seconds: float) -> void:
	var start := Time.get_ticks_msec()
	while (Time.get_ticks_msec() - start) / 1000.0 < seconds:
		await get_tree().process_frame

# --- J1 ------------------------------------------------------------------------------

func test_catwalk_sniper_beam_reaches_nick_below() -> void:
	var origin := Vector3(0.0, 0.0, 9700.0)
	var stand_in := Node3D.new() # Nick: origin = hurtbox centre (capsule r 0.5, h 2)
	add_child(stand_in)
	_keep(stand_in)
	stand_in.global_position = origin + Vector3(8.0, 0.0, 0.0)
	var health := HealthComponent.new()
	stand_in.add_child(health)
	var hurtbox := Hurtbox3D.new()
	hurtbox.name = "Hurtbox3D"
	hurtbox.collision_layer = 1024
	hurtbox.collision_mask = 0
	hurtbox.health_component = health
	var capsule_shape := CollisionShape3D.new()
	var capsule := CapsuleShape3D.new()
	capsule.radius = 0.5
	capsule.height = 2.0
	capsule_shape.shape = capsule
	hurtbox.add_child(capsule_shape)
	stand_in.add_child(hurtbox)

	var sniper: SniperEnemy = load(SNIPER_SCENE).instantiate()
	sniper.position = origin + Vector3(0.0, 4.5, 0.0) # a Zone 4 catwalk sniper
	add_child(sniper)
	_keep(sniper)
	sniper.set_physics_process(false) # no gravity: it stays on its (absent) catwalk
	if SignalBus.beat.is_connected(sniper._on_beat):
		SignalBus.beat.disconnect(sniper._on_beat)
	sniper.player = stand_in
	sniper.is_active = true
	sniper.update_aim()
	sniper._on_beat("primary", 3)
	sniper._on_beat("primary", 4)
	sniper._on_beat("primary", 1)
	assert_true(sniper.laser_hitbox.is_active, "Fire beat: the beam is live")
	for i in 4:
		await get_tree().physics_frame
	assert_true(sniper.laser_hitbox.overlaps_area(hurtbox), "The live beam overlaps the hurtbox 4.5 m below (pitch %.1f deg)" % rad_to_deg(sniper.aim_pitch))
	assert_lt(health.current_health, health.max_health, "...and the shot lands")
	assert_lt(sniper.aim_pitch, -0.3, "The beam pitches down")
	assert_almost_eq(sniper.rotation.x, 0.0, 0.0001, "The body itself only yaws")
	assert_almost_eq(sniper.laser_beam.scale.x, SniperEnemy.FIRE_BEAM_SCALE.x, 0.0001, "Pitching keeps the live beam width")

# --- J2 ------------------------------------------------------------------------------

func test_light_shake_does_not_cancel_a_piston_shake() -> void:
	var camera: DroneCamera = load(CAMERA_SCENE).instantiate()
	add_child(camera)
	_keep(camera)
	camera.set_physics_process(false)
	camera._on_camera_shake_requested(0.4, 0.2) # piston
	camera._physics_process(STEP)
	camera._on_camera_shake_requested(0.05, 0.12) # a light hit one frame later
	assert_gt(camera.current_shake_strength(), 0.3, "The piston shake keeps going (%.3f)" % camera.current_shake_strength())
	assert_almost_eq(camera.shake_timer, 0.2 - STEP, 0.0001, "...with its own longer remaining time")
	camera._on_camera_shake_requested(0.5, 0.1)
	assert_almost_eq(camera.current_shake_strength(), 0.5, 0.0001, "A stronger request still takes over")

func test_weaker_but_longer_shake_stretches_without_jumping() -> void:
	var camera: DroneCamera = load(CAMERA_SCENE).instantiate()
	add_child(camera)
	_keep(camera)
	camera.set_physics_process(false)
	camera._on_camera_shake_requested(0.3, 0.1)
	camera._physics_process(0.05) # decayed to 0.15
	var before := camera.current_shake_strength()
	camera._on_camera_shake_requested(0.1, 0.4)
	assert_almost_eq(camera.current_shake_strength(), before, 0.0001, "No amplitude jump")
	assert_almost_eq(camera.shake_timer, 0.4, 0.0001, "...stretched to the longer request")

# --- J3 ------------------------------------------------------------------------------

func test_zero_stun_hit_keeps_the_attack_clip() -> void:
	var player: PlayerController = await _grounded_player(Vector3(0.0, 0.0, 9720.0))
	player.pending_attack_heavy = false
	player.state_machine._on_transition_requested("StateAttack")
	var anim: AnimationPlayer = player.animation_controller.anim_player
	var clip := String(anim.current_animation)
	player.health_component.take_damage(_zero_stun_hit(player.global_position + Vector3(2.0, 0.0, 0.0)))
	assert_eq(String(player.state_machine.current_state.name), "StateAttack", "No state change")
	assert_eq(String(anim.current_animation), clip, "The swing clip keeps playing")
	assert_false(clip == "hit_react", "...and it is not the flinch")

func test_zero_stun_hit_while_running_flinches_fast_then_runs() -> void:
	var player: PlayerController = await _grounded_player(Vector3(0.0, 0.0, 9740.0))
	player.state_machine._on_transition_requested("StateRun")
	var anim: AnimationPlayer = player.animation_controller.anim_player
	player.health_component.take_damage(_zero_stun_hit(player.global_position + Vector3(2.0, 0.0, 0.0)))
	assert_eq(String(anim.current_animation), "hit_react", "Run: the flinch plays")
	var length: float = anim.get_animation("hit_react").length
	assert_almost_eq(anim.get_playing_speed(), length / PlayerController.FLINCH_SECONDS, 0.01, "...fitted to 0.22 s")
	anim.animation_finished.emit(&"hit_react")
	assert_eq(String(anim.current_animation), "run", "...then back to the run clip")

# --- J4 ------------------------------------------------------------------------------

func test_fall_during_a_dash_still_costs_the_fall_damage() -> void:
	var player: PlayerController = await _grounded_player(Vector3(0.0, 0.0, 9760.0))
	var hc := player.health_component
	var safe := player.global_position
	player.last_safe_position = safe
	var banners := _collect_banners()
	player.state_machine._on_transition_requested("StateDash")
	assert_true(hc.is_invincible, "Precondition: dash i-frames are on")
	player.fall_back_to_safe_ground() # what _physics_process runs below FALL_KILL_Y
	assert_lt(player.global_position.distance_to(safe), 0.01, "Back on the last safe ground")
	assert_almost_eq(100.0 - hc.current_health, player.fall_damage, 0.001, "The dash does not skip the 20 HP")
	assert_true(banners.has("SIGNAL LOST  -20 HP"), "The fall cue plays (%s)" % str(banners))

func test_survivable_fall_grants_a_short_grace_and_never_double_charges() -> void:
	var player: PlayerController = await _grounded_player(Vector3(0.0, 0.0, 9780.0))
	var hc := player.health_component
	player.last_safe_position = player.global_position
	player.fall_back_to_safe_ground()
	assert_almost_eq(hc.current_health, 80.0, 0.001, "One fall, 20 HP")
	assert_true(hc.grace_invincible, "A survivable fall grants a grace")
	player.fall_back_to_safe_ground() # an immediate second fall (respawn-fall loop)
	assert_almost_eq(hc.current_health, 80.0, 0.001, "...which blocks a second charge")
	await get_tree().create_timer(0.35).timeout
	assert_true(hc.grace_invincible, "Still graced at 0.35 s")
	await get_tree().create_timer(0.25).timeout
	assert_false(hc.grace_invincible, "The fall grace ends after 0.5 s")

func test_lethal_fall_leaves_the_grace_to_the_life_loss_respawn() -> void:
	GameManager.start_new_run()
	var player: PlayerController = await _grounded_player(Vector3(0.0, 0.0, 9800.0))
	var hc := player.health_component
	hc.current_health = 10.0
	player.fall_back_to_safe_ground()
	assert_almost_eq(hc.current_health, 0.0, 0.001, "The fall was lethal")
	assert_false(hc.grace_invincible, "No fall grace when the fall cost a life")
	await get_tree().process_frame # the deferred respawn_or_game_over runs
	GameManager.start_new_run()

# --- J5 ------------------------------------------------------------------------------

func _prompts(first: float, replay: float, gap: float) -> Node:
	var prompts: Node = load(ONBOARDING_SCRIPT).new()
	prompts.first_delay = first
	prompts.replay_delay = replay
	prompts.spacing = gap
	prompts.top_down_delay = 0.05
	add_child(prompts)
	_keep(prompts)
	return prompts

func test_onboarding_attack_card_comes_first() -> void:
	var defaults: Node = load(ONBOARDING_SCRIPT).new()
	assert_almost_eq(defaults.first_delay, 1.5, 0.0001, "ATTACK lands 1.5 s after the zone entry")
	defaults.free()
	_prompts(0.0, 0.0, 0.05)
	var got := _collect_banners()
	SignalBus.zone_entered.emit(zone_1)
	assert_eq(got.size(), 1, "First card on entry")
	if got.size() > 0:
		assert_true(got[0].begins_with("ATTACK"), "...ATTACK first (%s)" % got[0])
	await get_tree().create_timer(0.2).timeout
	assert_eq(got.size(), 3, "All three cards")
	if got.size() == 3:
		assert_true(got[1].begins_with("JUMP") and got[1].contains("DODGE"), "Then JUMP / DODGE")
		assert_true(got[2].begins_with("MOVE") and got[2].contains("A/D"), "Then MOVE")

func test_onboarding_replays_unplayed_cards_after_a_life_lost() -> void:
	_prompts(0.0, 0.0, 0.1)
	var got := _collect_banners()
	SignalBus.zone_entered.emit(zone_1)
	assert_eq(got.size(), 1, "ATTACK played")
	SignalBus.player_life_lost.emit(2) # before JUMP/DODGE and MOVE
	await get_tree().create_timer(0.25).timeout
	assert_eq(got.size(), 1, "The pending cards were dropped")
	SignalBus.zone_entered.emit(zone_1) # the respawn re-entry
	await get_tree().create_timer(0.25).timeout
	assert_eq(got.size(), 3, "The two unplayed cards replay (%s)" % str(got))
	if got.size() == 3:
		assert_true(got[1].begins_with("JUMP"), "...from where it stopped")
		assert_true(got[2].begins_with("MOVE"), "...to the end")
	SignalBus.player_life_lost.emit(1)
	SignalBus.zone_entered.emit(zone_1)
	await get_tree().create_timer(0.25).timeout
	assert_eq(got.size(), 3, "Nothing replays once every card has played")

func test_top_down_card_fires_once_after_the_shift_lands() -> void:
	_prompts(0.0, 0.0, 0.05)
	var got := _collect_banners()
	SignalBus.camera_shift_finished.emit(false)
	await get_tree().create_timer(0.1).timeout
	assert_eq(got.size(), 0, "A shift back to side-scroll shows nothing")
	SignalBus.camera_shift_finished.emit(true)
	assert_eq(got.size(), 0, "...the card waits its delay")
	await get_tree().create_timer(0.1).timeout
	assert_eq(got.size(), 1, "The top-down card fires after the landed shift")
	if got.size() > 0:
		assert_true(got[0].begins_with("TOP-DOWN") and got[0].contains("JUMP OFFLINE"), got[0])
	SignalBus.camera_shift_finished.emit(true)
	await get_tree().create_timer(0.1).timeout
	assert_eq(got.size(), 1, "Once per run")
	SignalBus.run_started.emit()
	SignalBus.camera_shift_finished.emit(true)
	await get_tree().create_timer(0.1).timeout
	assert_eq(got.size(), 2, "run_started re-arms it")

func test_bass_drop_card_fires_once_on_a_full_meter() -> void:
	_prompts(0.0, 0.0, 0.05)
	var got := _collect_banners()
	SignalBus.ability_meter_changed.emit(60.0, 100.0)
	assert_eq(got.size(), 0, "Not full yet")
	SignalBus.ability_meter_changed.emit(100.0, 100.0)
	assert_eq(got.size(), 1, "Full meter -> BASS DROP READY")
	if got.size() > 0:
		assert_eq(got[0], "BASS DROP READY  L / LB")
	SignalBus.ability_meter_changed.emit(40.0, 100.0)
	SignalBus.ability_meter_changed.emit(100.0, 100.0)
	assert_eq(got.size(), 1, "Once per run")
	SignalBus.run_started.emit()
	SignalBus.ability_meter_changed.emit(100.0, 100.0)
	assert_eq(got.size(), 2, "run_started re-arms it")

# --- J6 ------------------------------------------------------------------------------

func _top_down_encounter() -> Dictionary:
	var dummy := Node3D.new()
	var scene := PackedScene.new()
	scene.pack(dummy)
	dummy.free()
	var wave := WaveDef.new()
	var enemies: Array[PackedScene] = [scene]
	wave.enemies = enemies
	var spawner := WaveSpawner.new()
	spawner.add_child(Marker3D.new())
	add_child(spawner)
	_keep(spawner)
	var gate := CSGBox3D.new()
	add_child(gate)
	_keep(gate)
	var encounter := ZoneEncounter.new()
	encounter.spawner = spawner
	var waves: Array[WaveDef] = [wave]
	encounter.waves = waves
	var gates: Array[Node3D] = [gate]
	encounter.gates = gates
	encounter.is_top_down = true
	add_child(encounter)
	_keep(encounter)
	var mock_player := PlayerController.new()
	_keep(mock_player)
	return {"encounter": encounter, "spawner": spawner, "gate": gate, "player": mock_player}

func test_top_down_encounter_spawns_only_when_the_shift_lands() -> void:
	var t := _top_down_encounter()
	var encounter: ZoneEncounter = t.encounter
	var spawner: WaveSpawner = t.spawner
	var gate: CSGBox3D = t.gate
	var shifts: Array[bool] = []
	SignalBus.camera_shift_requested.connect(func(top_down: bool, _path: Path3D, _time: float): shifts.append(top_down))
	encounter._on_body_entered(t.player)
	await get_tree().process_frame
	assert_eq(shifts, [true] as Array[bool], "The shift into top-down is requested at once")
	assert_true(gate.visible and gate.use_collision, "Gates lock immediately")
	assert_true(spawner.active_enemies.is_empty(), "No wave while the camera is still shifting")
	assert_true(encounter.is_waiting_for_top_down_shift(), "...the start is pending")
	SignalBus.camera_shift_finished.emit(false)
	await get_tree().process_frame
	assert_true(spawner.active_enemies.is_empty(), "A shift back out does not start it")
	SignalBus.camera_shift_finished.emit(true)
	await get_tree().process_frame
	assert_eq(spawner.active_enemies.size(), 1, "Wave 1 spawns once the shift has landed")
	assert_false(encounter.is_waiting_for_top_down_shift(), "One-shot")

func test_respawn_cancels_a_pending_top_down_start() -> void:
	var t := _top_down_encounter()
	var encounter: ZoneEncounter = t.encounter
	var spawner: WaveSpawner = t.spawner
	encounter._on_body_entered(t.player)
	SignalBus.player_respawned.emit()
	SignalBus.camera_shift_finished.emit(true)
	await get_tree().process_frame
	assert_true(spawner.active_enemies.is_empty(), "A respawn in between cancels the pending spawn")
	assert_false(encounter.active, "...and re-arms the encounter")
	assert_false(encounter.is_waiting_for_top_down_shift(), "...with nothing pending")

# --- J7 ------------------------------------------------------------------------------

func test_emitter_shot_carries_its_own_damage_on_a_fresh_pool() -> void:
	var pool := ObjectPool.new()
	pool.template = load(PROJECTILE_SCENE)
	pool.initial_pool_size = 2
	add_child(pool)
	_keep(pool)
	var emitter := ProjectileEmitter.new()
	emitter.pool = pool
	add_child(emitter)
	_keep(emitter)
	emitter.global_position = Vector3(0.0, 0.0, 9820.0)
	emitter.fire_aimed(8.0, 25.0, emitter.global_position + Vector3.RIGHT)
	var fired: PooledProjectile = null
	for child in pool.get_children():
		if not pool.inactive_pool.has(child):
			fired = child
	assert_not_null(fired, "One bullet in flight")
	if fired:
		assert_almost_eq(fired.hitbox.damage_info.amount, 25.0, 0.0001, "The first shot carries 25, not the previous value")
		assert_almost_eq(fired.speed, 8.0, 0.0001, "...and its speed")
		assert_true(fired.direction.is_equal_approx(Vector3.RIGHT), "...and its direction")
	for child in pool.get_children():
		pool.release(child)

# --- J8 ------------------------------------------------------------------------------

func test_pit_tick_keeps_a_grunt_stunned_and_sliding() -> void:
	var runner: RunnerEnemy = load(RUNNER_SCENE).instantiate()
	runner.position = Vector3(0.0, 50.0, 9840.0)
	add_child(runner)
	_keep(runner)
	runner.set_physics_process(false)
	var combat: Node = runner.combat_comp
	combat.set_physics_process(false)
	combat.stun_timer = 0.8
	runner.velocity = Vector3(4.0, 0.0, 0.0)
	var pit := ToxicPit.new()
	var tick: DamageInfo = pit._make_damage()
	var hp := runner.health_component.current_health
	(runner.get_node("Hurtbox3D") as Hurtbox3D).receive_hit(tick)
	pit.free()
	assert_lt(runner.health_component.current_health, hp, "The tick still burns")
	assert_gt(combat.stun_timer, 0.7, "...but does not cancel the stun")
	assert_almost_eq(runner.velocity.x, 4.0, 0.0001, "...nor the knockback slide")
	var weak := DamageInfo.new()
	weak.amount = 1.0
	weak.knockback = 1.0
	weak.stun = 0.2
	(runner.get_node("Hurtbox3D") as Hurtbox3D).receive_hit(weak)
	assert_gt(combat.stun_timer, 0.7, "A weaker stun never shortens the running one")

# --- J11 -----------------------------------------------------------------------------

func test_runner_slides_along_the_deck_edge_to_the_plank() -> void:
	# Zone 4 catwalk shape: SegA 5 m deep, a 0.6 m plank over a 3 m gap, SegB 3 m deep.
	var origin := Vector3(0.0, 0.0, 9860.0)
	_make_floor(self, origin + Vector3(-4.0, 0.0, 0.0), Vector3(8.0, 1.0, 5.0))
	_make_floor(self, origin + Vector3(1.5, 0.0, 0.0), Vector3(3.0, 0.5, 0.6))
	_make_floor(self, origin + Vector3(7.5, 0.0, 0.0), Vector3(9.0, 1.0, 3.0))
	await get_tree().physics_frame
	var runner: RunnerEnemy = load(RUNNER_SCENE).instantiate()
	runner.position = origin + Vector3(-0.4, 0.95, -2.0) # SegA edge, 2 m off the plank line
	add_child(runner)
	_keep(runner)
	var nick := Node3D.new()
	add_child(nick)
	_keep(nick)
	nick.global_position = origin + Vector3(7.0, 0.9, 0.0) # on SegB
	runner.player = nick
	runner.is_active = true
	for i in 60:
		await get_tree().physics_frame
	assert_gt(runner.global_position.z - origin.z, -1.5, "Within 1 s it moved toward the plank line (z %.2f)" % (runner.global_position.z - origin.z))
	for i in 240:
		await get_tree().physics_frame
		if runner.global_position.x - origin.x > 3.2:
			break
	assert_gt(runner.global_position.x - origin.x, 3.0, "...and crossed onto SegB (x %.2f)" % (runner.global_position.x - origin.x))
	assert_gt(runner.global_position.y - origin.y, 0.0, "...without falling into the gap")

func test_runner_still_holds_when_neither_probe_finds_floor() -> void:
	var origin := Vector3(0.0, 0.0, 9880.0)
	_make_floor(self, origin, Vector3(2.0, 1.0, 2.0))
	var runner: RunnerEnemy = load(RUNNER_SCENE).instantiate()
	runner.position = origin + Vector3(0.7, 0.95, 0.7)
	add_child(runner)
	_keep(runner)
	runner.set_physics_process(false)
	await get_tree().physics_frame
	var dir := Vector3(1.0, 0.0, 1.0).normalized()
	var move := EnemyStats.chase_direction(runner, dir, EnemyStats.feet_offset_of(runner), 5.0)
	assert_eq(move, Vector3.ZERO, "Corner of a pad, Nick beyond both edges -> hold")

# --- J12 -----------------------------------------------------------------------------

func test_hit_stop_recovers_while_the_tree_is_paused() -> void:
	assert_eq(HitStop.process_mode, Node.PROCESS_MODE_ALWAYS, "HitStop ticks through a pause")
	HitStop.start_hit_stop(0.1, 0.05)
	get_tree().paused = true
	var start := Time.get_ticks_msec()
	while Engine.time_scale < 1.0 and Time.get_ticks_msec() - start < 1000:
		await get_tree().process_frame
	var elapsed := (Time.get_ticks_msec() - start) / 1000.0
	get_tree().paused = false
	assert_eq(Engine.time_scale, 1.0, "time_scale is back to 1.0 during the pause")
	assert_lt(elapsed, 0.3, "...within the stop's real duration (%.3f s)" % elapsed)

func test_focus_grace_counts_real_seconds() -> void:
	var button := Button.new()
	add_child(button)
	_keep(button)
	Engine.time_scale = 0.05
	FocusGrace.arm(button, 0.1)
	assert_true(button.disabled, "Armed")
	await _wait_real(0.25)
	Engine.time_scale = 1.0
	assert_false(button.disabled, "A 0.05 time_scale does not stretch the 0.1 s grace")
