extends "res://tests/framework/test_case.gd"

const ObjectPool = preload("res://_core/pool/object_pool.gd")
const PooledProjectile = preload("res://levels/components/pooled_projectile.gd")

func test_object_pool_lifecycle() -> void:
	var pool = ObjectPool.new()
	pool.template = load("res://levels/components/pooled_projectile.tscn")
	pool.initial_pool_size = 5
	pool.allow_growth = true
	add_child(pool)
	
	# Verify pre-instantiation
	assert_eq(pool.inactive_pool.size(), 5, "Pool should pre-instantiate initial size")
	
	# Test acquisition of active nodes
	var node1 = pool.acquire()
	assert_not_null(node1, "Acquired node should not be null")
	assert_true(node1.visible, "Acquired node should be visible")
	assert_true(node1.is_physics_processing(), "Acquired node should have physics process enabled")
	if node1 is Area3D:
		assert_true(node1.monitoring, "Acquired Area3D should be monitoring")
		assert_true(node1.monitorable, "Acquired Area3D should be monitorable")
		
	# Verify count reduced in inactive pool
	assert_eq(pool.inactive_pool.size(), 4, "Inactive pool size should decrease")
	
	# Test release disabling state/visibility
	pool.release(node1)
	assert_false(node1.visible, "Released node should be invisible")
	assert_false(node1.is_physics_processing(), "Released node should have physics process disabled")
	if node1 is Area3D:
		assert_false(node1.monitoring, "Released Area3D should not be monitoring")
		assert_false(node1.monitorable, "Released Area3D should not be monitorable")
	assert_eq(node1.global_position, Vector3(9999, 9999, 9999), "Released node should be moved to safe coordinates")
	assert_eq(pool.inactive_pool.size(), 5, "Inactive pool size should restore")
	
	# Test growth
	var acquired_nodes: Array[Node] = []
	for i in range(6):
		acquired_nodes.append(pool.acquire())
	assert_eq(acquired_nodes.size(), 6)
	assert_eq(pool.inactive_pool.size(), 0)
	
	# Clean up
	for n in acquired_nodes:
		if is_instance_valid(n):
			n.queue_free()
	pool.queue_free()

func test_projectile_hits_and_expiry() -> void:
	var pool = ObjectPool.new()
	pool.template = load("res://levels/components/pooled_projectile.tscn")
	pool.initial_pool_size = 2
	add_child(pool)
	
	var proj = pool.acquire()
	assert_not_null(proj)
	assert_true(proj is PooledProjectile)
	
	# Setup damage info and player hurtbox
	var player_hurtbox = Hurtbox3D.new()
	var player_health = HealthComponent.new()
	player_health.max_health = 100.0
	player_health.current_health = 100.0
	player_hurtbox.health_component = player_health
	add_child(player_health)
	add_child(player_hurtbox)
	player_health.current_shield = 0.0

	
	# Mock collision
	proj.hitbox.is_active = true
	proj.hitbox.damage_info.amount = 15.0
	proj.hitbox.damage_info.source = proj
	
	# Trigger the collision through the real signal so both handlers run: the hitbox
	# deals damage and the projectile schedules its own return to the pool. (Calling
	# hitbox._on_area_entered directly skipped the release — the assertion below only
	# passed because the old hard-coded arena centre culled the projectile.)
	proj.hitbox.area_entered.emit(player_hurtbox)
	
	assert_eq(player_health.current_health, 85.0, "Player should take damage from projectile hit")
	
	# Wait for deferred release
	await get_tree().process_frame
	assert_false(proj.visible, "Projectile should return to pool (becoming invisible) after hit")
	
	# Test lifetime timeout expiry
	var proj2 = pool.acquire()
	assert_not_null(proj2)
	proj2.lifetime = 0.1
	proj2.current_lifetime = 0.1
	proj2._physics_process(0.2) # Tick physics past lifetime
	
	assert_false(proj2.visible, "Projectile should return to pool on lifetime expiry")
	
	# Clean up
	player_hurtbox.queue_free()
	player_health.queue_free()
	pool.queue_free()

func test_projectile_range_is_relative_to_its_spawn_point() -> void:
	var pool = ObjectPool.new()
	pool.template = load("res://levels/components/pooled_projectile.tscn")
	pool.initial_pool_size = 1
	add_child(pool)

	# Fired far from the Zone 10 arena: must not be culled for being "out of the arena".
	var proj = pool.acquire()
	proj.global_position = Vector3(-500.0, 0.0, 40.0) # emitter positions after acquire
	proj.direction = Vector3.RIGHT
	proj._physics_process(0.016)
	assert_true(proj.visible, "Projectile should survive when fired away from the old hard-coded arena centre")

	# Travelling past max_range from its own spawn point returns it to the pool.
	proj.global_position = Vector3(-500.0 + proj.max_range + 1.0, 0.0, 40.0)
	proj._physics_process(0.016)
	assert_false(proj.visible, "Projectile should return to pool beyond max_range from its spawn point")

	# Re-acquired projectiles re-capture a fresh origin.
	var again = pool.acquire()
	again.global_position = Vector3(800.0, 0.0, 0.0)
	again._physics_process(0.016)
	assert_true(again.visible, "Re-acquired projectile should measure range from its new spawn point")

	pool.queue_free()

func test_boss_activation() -> void:
	var boss_scene = load("res://characters/enemies/headliner/headliner.tscn")
	var boss = boss_scene.instantiate()
	add_child(boss)
	
	assert_false(boss.is_active_boss, "Boss should start dormant")
	assert_eq(boss.state_machine.current_state.name, "StateDormant", "State should be StateDormant initially")
	
	# Activate boss
	boss.activate_boss()
	
	assert_true(boss.is_active_boss, "Boss should be active after activation")
	assert_eq(boss.state_machine.current_state.name, "StateShield", "Boss should transition to StateShield on activation")
	
	boss.queue_free()

func test_boss_shield_breaker() -> void:
	var boss_scene = load("res://characters/enemies/headliner/headliner.tscn")
	var boss = boss_scene.instantiate()
	add_child(boss)
	boss.activate_boss()
	
	# Normal hit on shield should be mitigated
	var normal_dmg = DamageInfo.new()
	normal_dmg.amount = 50.0
	normal_dmg.is_shield_breaker = false
	
	var initial_hp = boss.health_component.current_health
	boss.hurtbox.receive_hit(normal_dmg)
	
	assert_eq(boss.health_component.current_health, initial_hp, "Normal hit should deal no damage while shield is active")
	assert_eq(boss.state_machine.current_state.name, "StateShield", "Boss should remain in StateShield")
	
	# Shield breaker hit should break shield and trigger StateRecovery
	var breaker_dmg = DamageInfo.new()
	breaker_dmg.amount = 50.0
	breaker_dmg.is_shield_breaker = true
	
	boss.hurtbox.receive_hit(breaker_dmg)
	
	assert_eq(boss.state_machine.current_state.name, "StateRecovery", "Shield break should transition boss to StateRecovery")
	assert_true(boss.is_vulnerable, "Boss should be vulnerable in StateRecovery")
	
	# Clean up
	boss.queue_free()

func test_boss_phase_transition() -> void:
	var boss_scene = load("res://characters/enemies/headliner/headliner.tscn")
	var boss = boss_scene.instantiate()
	add_child(boss)
	boss.activate_boss()
	# Give the boss a real arena rail so the test proves phase 2 does NOT pass it on.
	var rail := Path3D.new()
	rail.curve = Curve3D.new()
	add_child(rail)
	boss.path_z10 = rail
	
	var flags = {"camera_shifted": false, "top_down": false, "path": rail}
	var camera_connection = func(top_down, path, transition_time):
		flags.camera_shifted = true
		flags.top_down = top_down
		flags.path = path
	SignalBus.camera_shift_requested.connect(camera_connection)
	
	# Deal damage to drop health to 50% or below (750 HP or below)
	var dmg = DamageInfo.new()
	dmg.amount = 800.0
	dmg.is_shield_breaker = true # break shield and deal damage
	
	boss.hurtbox.receive_hit(dmg)
	
	assert_true(boss.phase_2_triggered, "Phase 2 should trigger when HP <= 50%")
	assert_eq(boss.state_machine.current_state.name, "StateTransition", "Boss should transition to StateTransition")
	assert_true(flags.camera_shifted, "Camera shift should be requested")
	assert_true(flags.top_down, "Camera shift should request top-down")
	assert_null(flags.path, "Phase 2 top-down shift must not rail-lock Nick (path should be null)")
	
	# Disconnect and clean up
	SignalBus.camera_shift_requested.disconnect(camera_connection)
	boss.queue_free()
	rail.queue_free()

func test_boss_bullet_hell_shield_break() -> void:
	var boss_scene = load("res://characters/enemies/headliner/headliner.tscn")
	var boss = boss_scene.instantiate()
	add_child(boss)
	boss.activate_boss()
	
	# Manually force transition to StateBulletHell to test shield break transition
	boss.phase_2_triggered = true
	boss.state_machine.transition_to("StateBulletHell")
	
	assert_eq(boss.state_machine.current_state.name, "StateBulletHell")
	assert_true(boss.is_shield_active, "Shield should be active in Bullet Hell")
	
	var flags = {"camera_shifted": false, "top_down": true}
	var camera_connection = func(top_down, path, transition_time):
		flags.camera_shifted = true
		flags.top_down = top_down
	SignalBus.camera_shift_requested.connect(camera_connection)
	
	# Break shield with shield breaker
	var breaker_dmg = DamageInfo.new()
	breaker_dmg.amount = 10.0
	breaker_dmg.is_shield_breaker = true
	boss.hurtbox.receive_hit(breaker_dmg)
	
	assert_eq(boss.state_machine.current_state.name, "StateEnraged", "Shield break in bullet hell should transition to StateEnraged")
	assert_true(flags.camera_shifted, "Camera shift back should be requested")
	assert_false(flags.top_down, "Camera shift should request sidescroll (top_down = false)")
	assert_eq(boss.speed_multiplier, 1.2, "Speed multiplier should be 1.2 in enraged state")
	
	# Disconnect and clean up
	SignalBus.camera_shift_requested.disconnect(camera_connection)
	boss.queue_free()

func test_boss_bullet_hell_overheats_after_max_beats() -> void:
	var boss_scene = load("res://characters/enemies/headliner/headliner.tscn")
	var boss = boss_scene.instantiate()
	add_child(boss)
	boss.activate_boss()

	boss.phase_2_triggered = true
	boss.state_machine.transition_to("StateBulletHell")
	var bullet_hell = boss.state_machine.current_state
	assert_eq(bullet_hell.name, "StateBulletHell")

	var flags = {"camera_shifted": false, "top_down": true}
	var camera_connection = func(top_down, path, transition_time):
		flags.camera_shifted = true
		flags.top_down = top_down
	SignalBus.camera_shift_requested.connect(camera_connection)

	# No shield-breaker hit at all — the phase must still end on its own.
	for i in range(bullet_hell.max_beats - 1):
		bullet_hell.on_beat("primary", (i % 4) + 1)
	assert_eq(boss.state_machine.current_state.name, "StateBulletHell", "Bullet hell should persist until max_beats")
	bullet_hell.on_beat("primary", ((bullet_hell.max_beats - 1) % 4) + 1)

	assert_eq(boss.state_machine.current_state.name, "StateEnraged", "Bullet hell should overheat into StateEnraged after max_beats")
	assert_false(boss.is_shield_active, "Overheated shield should be down")
	assert_true(flags.camera_shifted, "Camera shift back should be requested on overheat")
	assert_false(flags.top_down, "Overheat camera shift should request sidescroll (top_down = false)")

	SignalBus.camera_shift_requested.disconnect(camera_connection)
	boss.queue_free()

func test_phase_2_beat_pulse_returns_to_authored_scale() -> void:
	var boss = load("res://characters/enemies/headliner/headliner.tscn").instantiate()
	# headliner_visual.tscn sizes the model on its Pivot (root scale ONE); author a non-unit
	# root scale here so the test still proves the pulse is relative, not Vector3.ONE.
	boss.get_node("MeshInstance3D").scale = Vector3(1.5, 1.5, 1.5)
	add_child(boss)
	var authored: Vector3 = boss.mesh_instance.scale
	assert_true(boss._base_scale.is_equal_approx(authored), "_base_scale captures the authored root scale")

	boss.activate_boss()
	boss.phase_2_triggered = true
	# Only the manual beat below may pulse: a live Conductor beat landing inside the 0.45 s
	# window would restart the tween and make this test depend on the global beat phase.
	if SignalBus.beat.is_connected(boss._on_beat):
		SignalBus.beat.disconnect(boss._on_beat)
	boss._on_beat("primary", 1)

	await get_tree().create_timer(0.05).timeout
	assert_gt(boss.mesh_instance.scale.x, authored.x * 0.99, "Beat pulse should never shrink the visual below its authored scale")
	await get_tree().create_timer(0.4).timeout
	assert_true(boss.mesh_instance.scale.is_equal_approx(authored), "Beat pulse should settle back to the authored scale, got %s" % boss.mesh_instance.scale)

	# Respawn reset restores the authored scale, not Vector3.ONE.
	boss.mesh_instance.scale = authored * 2.0
	boss._on_player_respawned()
	assert_true(boss.mesh_instance.scale.is_equal_approx(authored), "Respawn reset should restore the authored scale")

	boss.queue_free()

func test_boss_death_complete_run() -> void:
	var boss_scene = load("res://characters/enemies/headliner/headliner.tscn")
	var boss = boss_scene.instantiate()
	add_child(boss)
	boss.activate_boss()
	
	var gm = get_node("/root/GameManager")
	var initial_is_test = gm.is_test
	gm.is_test = true
	
	var dmg = DamageInfo.new()
	dmg.amount = 2000.0 # Exceeds max health
	dmg.is_shield_breaker = true # bypass shield
	
	boss.hurtbox.receive_hit(dmg)
	
	assert_eq(boss.state_machine.current_state.name, "StateDead", "Boss should transition to StateDead on death")
	
	# Clean up
	gm.is_test = initial_is_test
	boss.queue_free()

func test_player_respawn_releases_every_in_flight_bullet() -> void:
	# D10: a respawn mid-bullet-hell must clear the Headliner's live projectiles.
	var boss = load("res://characters/enemies/headliner/headliner.tscn").instantiate()
	add_child(boss)
	boss.activate_boss()
	var pool: ObjectPool = boss.pool
	var total: int = pool.get_child_count()
	var live: Array[Node] = []
	for i in 5:
		live.append(pool.acquire())
	assert_eq(pool.inactive_pool.size(), total - 5, "Precondition: five bullets in flight")

	boss._on_player_respawned()

	assert_eq(pool.inactive_pool.size(), total, "Respawn should release every in-flight bullet")
	for b in live:
		assert_false(b.visible, "Released bullets should be hidden")
		assert_false(b.is_physics_processing(), "Released bullets should stop moving")

	# release_all is idempotent — nothing is double-listed.
	pool.release_all()
	assert_eq(pool.inactive_pool.size(), total, "release_all must not duplicate pool entries")
	boss.queue_free()

func test_headliner_rim_follows_phase_and_resets_on_respawn() -> void:
	var boss: HeadlinerBoss = load("res://characters/enemies/headliner/headliner.tscn").instantiate()
	add_child(boss)
	var visual: CharacterVisual = boss.character_visual
	var amber := Color(1.0, 0.54902, 0.101961, 1.0)
	assert_true(visual.get_base_rim_color().is_equal_approx(amber), "Phase 1 rests at the amber rim")
	assert_almost_eq(visual.get_base_rim_strength(), 4.0, 0.001, "Headliner rim strength 4")
	for sm in visual.skinned_meshes:
		assert_null(sm.material_override, "The textured Headliner mesh keeps its own material")
		assert_true((sm.mesh.surface_get_format(0) & Mesh.ARRAY_FORMAT_NORMAL) != 0, "Normals are generated for the normal-less GLB (else the rim floods the whole body)")

	boss.activate_boss()
	boss.health_component.current_health = boss.stats.max_health * 0.4
	boss._on_health_changed(boss.health_component.current_health, boss.stats.max_health)
	assert_true(boss.phase_2_triggered, "Precondition: phase 2 triggered")
	assert_eq(visual.get_base_rim_color(), CharacterVisual.ENEMY_RIM_COLOR, "Phase 2 rests at the magenta rim")
	boss.state_machine.transition_to("StateEnraged")
	assert_almost_eq(visual.get_base_rim_strength(), HeadlinerBoss.ENRAGED_RIM_STRENGTH, 0.001, "Enraged drives the rim to strength 5")

	boss._on_player_respawned()
	assert_true(visual.get_base_rim_color().is_equal_approx(amber), "Respawn restores the amber rim")
	assert_almost_eq(visual.get_base_rim_strength(), 4.0, 0.001, "Respawn restores the rim strength")
	boss.queue_free()

func test_headliner_visual_stands_six_metres_on_its_capsule() -> void:
	var boss: HeadlinerBoss = load("res://characters/enemies/headliner/headliner.tscn").instantiate()
	boss.position = Vector3(0.0, 300.0, 4200.0)
	add_child(boss)
	var merged := AABB()
	var first := true
	for mi in boss.mesh_instance.find_children("*", "MeshInstance3D", true, false):
		var m := mi as MeshInstance3D
		if m.mesh == null:
			continue
		var box: AABB = m.global_transform * m.get_aabb()
		merged = box if first else merged.merge(box)
		first = false
	assert_almost_eq(merged.position.y - boss.global_position.y, -3.0, 0.15, "Headliner feet sit on the 6 m capsule bottom")
	assert_almost_eq(merged.size.y, 6.0, 0.4, "Headliner stands ~6 m tall (upright, not lying down)")
	boss.queue_free()

func test_left_gate_visual_shows_only_while_sealed() -> void:
	# E8: the slice hides LeftGate/Visual while the gate is open; the fight shows it when the
	# gate seals and the respawn reset hides it again with the collision.
	var arena := Node3D.new()
	add_child(arena)
	var gate := Node3D.new()
	gate.name = "LeftGate"
	arena.add_child(gate)
	var gate_visual := MeshInstance3D.new()
	gate_visual.name = "Visual"
	gate_visual.visible = false
	gate.add_child(gate_visual)
	var boss: HeadlinerBoss = load("res://characters/enemies/headliner/headliner.tscn").instantiate()
	arena.add_child(boss)

	boss.activate_boss()
	assert_true(gate_visual.visible, "LeftGate/Visual appears when the boss seals the arena")
	boss._on_player_respawned()
	assert_false(gate_visual.visible, "LeftGate/Visual hides again when the respawn reset re-opens the gate")
	arena.queue_free()
