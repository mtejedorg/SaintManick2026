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
	
	# Trigger the collision
	proj.hitbox._on_area_entered(player_hurtbox)
	
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
	
	var flags = {"camera_shifted": false, "top_down": false}
	var camera_connection = func(top_down, path, transition_time):
		flags.camera_shifted = true
		flags.top_down = top_down
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
	
	# Disconnect and clean up
	SignalBus.camera_shift_requested.disconnect(camera_connection)
	boss.queue_free()

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
