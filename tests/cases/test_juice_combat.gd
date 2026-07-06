extends "res://tests/framework/test_case.gd"

func before_each() -> void:
	# Reconnect HitStop to SignalBus as the test runner clears all global connections between tests
	var hit_stop = get_node_or_null("/root/HitStop")
	if hit_stop:
		if not SignalBus.player_hit_landed.is_connected(hit_stop._on_player_hit_landed):
			SignalBus.player_hit_landed.connect(hit_stop._on_player_hit_landed)
		if not SignalBus.hit_stop_requested.is_connected(hit_stop.start_hit_stop):
			SignalBus.hit_stop_requested.connect(hit_stop.start_hit_stop)

func after_each() -> void:
	Engine.time_scale = 1.0
	var hit_stop = get_node_or_null("/root/HitStop")
	if hit_stop:
		hit_stop.hit_stop_timer = 0.0
	super.after_each()

func test_player_roll_invincibility() -> void:
	var player = load("res://characters/player/player.tscn").instantiate()
	add_child(player)
	
	var health_comp = player.health_component
	assert_not_null(health_comp, "Player should have HealthComponent")
	assert_false(health_comp.is_invincible, "Should not be invincible initially")
	
	var fsm = player.state_machine
	var roll_state = fsm.get_node("StateRoll")
	assert_not_null(roll_state, "Player should have StateRoll node")
	
	# Simulate entering roll state
	roll_state.enter()
	assert_true(health_comp.is_invincible, "Should be invincible in roll state")
	
	# Try applying damage
	var initial_hp = health_comp.current_health
	var damage_info = DamageInfo.new()
	damage_info.amount = 10.0
	damage_info.is_shield_breaker = true
	health_comp.take_damage(damage_info)
	assert_eq(health_comp.current_health, initial_hp, "Invincible player should take no damage")
	
	# Exit roll state
	roll_state.exit()
	assert_false(health_comp.is_invincible, "Should not be invincible after exiting roll state")
	
	# Damage should now apply
	health_comp.take_damage(damage_info)
	assert_lt(health_comp.current_health, initial_hp, "Player should take damage after roll state exits")
	
	player.queue_free()

func test_player_dash_invincibility() -> void:
	var player = load("res://characters/player/player.tscn").instantiate()
	add_child(player)
	
	var health_comp = player.health_component
	assert_not_null(health_comp, "Player should have HealthComponent")
	assert_false(health_comp.is_invincible, "Should not be invincible initially")
	
	var fsm = player.state_machine
	var dash_state = fsm.get_node("StateDash")
	assert_not_null(dash_state, "Player should have StateDash node")
	
	# Simulate entering dash state
	dash_state.enter()
	assert_true(health_comp.is_invincible, "Should be invincible in dash state")
	
	# Try applying damage
	var initial_hp = health_comp.current_health
	var damage_info = DamageInfo.new()
	damage_info.amount = 10.0
	damage_info.is_shield_breaker = true
	health_comp.take_damage(damage_info)
	assert_eq(health_comp.current_health, initial_hp, "Invincible player should take no damage")
	
	# Exit dash state
	dash_state.exit()
	assert_false(health_comp.is_invincible, "Should not be invincible after exiting dash state")
	
	# Damage should now apply
	health_comp.take_damage(damage_info)
	assert_lt(health_comp.current_health, initial_hp, "Player should take damage after dash state exits")
	
	player.queue_free()
func test_enemy_knockback_and_stun() -> void:
	var enemy = load("res://characters/enemies/runner/runner.tscn").instantiate()
	add_child(enemy)
	
	var combat_comp = enemy.combat_comp
	assert_not_null(combat_comp, "Runner should have EnemyCombatComponent")
	assert_false(combat_comp.is_stunned(), "Enemy should not be stunned initially")
	
	var attacker = Node3D.new()
	add_child(attacker)
	attacker.global_position = Vector3(0, 0, 0)
	enemy.global_position = Vector3(2, 0, 0)
	
	var damage_info = DamageInfo.new()
	damage_info.amount = 10.0
	damage_info.knockback = 5.0
	damage_info.stun = 0.5
	damage_info.source = attacker
	
	var hurtbox = enemy.get_node("Hurtbox3D")
	assert_not_null(hurtbox, "Enemy should have Hurtbox3D")
	hurtbox.receive_hit(damage_info)
	
	# Knockback should be horizontal away from attacker
	assert_gt(enemy.velocity.x, 0.0, "Velocity.x should be positive (away from attacker)")
	assert_eq(enemy.velocity.x, 5.0, "Velocity.x should match knockback strength")
	assert_true(combat_comp.is_stunned(), "Enemy should be stunned after hit")
	assert_almost_eq(combat_comp.stun_timer, 0.5, 0.01)
	
	# Simulate physics process tick to verify decay/countdown
	combat_comp._physics_process(0.1)
	assert_almost_eq(combat_comp.stun_timer, 0.4, 0.01)
	assert_true(combat_comp.is_stunned())
	
	# Clear stun
	combat_comp._physics_process(0.4)
	assert_eq(combat_comp.stun_timer, 0.0)
	assert_false(combat_comp.is_stunned())
	
	attacker.queue_free()
	enemy.queue_free()

func test_enemy_air_juggle_launch() -> void:
	var enemy = load("res://characters/enemies/runner/runner.tscn").instantiate()
	add_child(enemy)
	
	var damage_info = DamageInfo.new()
	damage_info.amount = 10.0
	damage_info.knockback = 5.0
	damage_info.stun = 0.5
	damage_info.is_launcher = true
	
	var hurtbox = enemy.get_node("Hurtbox3D")
	hurtbox.receive_hit(damage_info)
	
	assert_eq(enemy.velocity.y, 8.0, "Launcher hit should apply Y launch pop of 8.0")
	
	var damage_info_normal = DamageInfo.new()
	damage_info_normal.amount = 10.0
	damage_info_normal.knockback = 5.0
	damage_info_normal.stun = 0.5
	damage_info_normal.is_launcher = false
	hurtbox.receive_hit(damage_info_normal)
	assert_eq(enemy.velocity.y, 3.0, "Normal hit should apply normal Y pop of 3.0")
	
	enemy.queue_free()

func test_player_combo_counter() -> void:
	var player = load("res://characters/player/player.tscn").instantiate()
	add_child(player)
	
	var combo_comp = player.combo_component
	assert_not_null(combo_comp, "Player should have PlayerComboComponent")
	assert_eq(combo_comp.combo_count, 0, "Combo should start at 0")
	
	var damage_info = DamageInfo.new()
	damage_info.source = player
	SignalBus.player_hit_landed.emit(damage_info)
	
	assert_eq(combo_comp.combo_count, 1, "Combo should increase on player hit landed")
	assert_almost_eq(combo_comp.combo_timer, 2.0, 0.01)
	
	combo_comp._process(1.0)
	assert_eq(combo_comp.combo_count, 1, "Combo should remain active before timeout")
	assert_almost_eq(combo_comp.combo_timer, 1.0, 0.01)
	
	combo_comp._process(1.1)
	assert_eq(combo_comp.combo_count, 0, "Combo should drop on timeout")
	
	# Test whiff detection
	combo_comp.on_attack_started()
	SignalBus.player_hit_landed.emit(damage_info)
	assert_eq(combo_comp.combo_count, 1)
	combo_comp.on_attack_ended()
	assert_eq(combo_comp.combo_count, 1, "Combo should not drop if attack connected")
	
	combo_comp.on_attack_started()
	combo_comp.on_attack_ended()
	assert_eq(combo_comp.combo_count, 0, "Combo should drop on attack whiff")
	
	player.queue_free()

func test_player_combo_routes() -> void:
	var player = load("res://characters/player/player.tscn").instantiate()
	add_child(player)
	
	var fsm = player.state_machine
	var attack_state = fsm.get_node("StateAttack")
	assert_not_null(attack_state, "Should have attack state")
	
	player.ability_meter = 100.0 # Ensure enough meter for heavy attacks
	
	# Test Tri-Cut (A-A-A)
	attack_state.enter()
	assert_eq("".join(attack_state.current_sequence), "A")
	attack_state.buffered_attack = true
	attack_state.buffered_heavy = false
	attack_state.attack_timer = 0.0 # Force sequence advance
	attack_state.physics_update(0.0)
	assert_eq("".join(attack_state.current_sequence), "AA")
	attack_state.buffered_attack = true
	attack_state.buffered_heavy = false
	attack_state.attack_timer = 0.0
	attack_state.physics_update(0.0)
	assert_eq("".join(attack_state.current_sequence), "AAA")
	assert_eq(player.katana_hitbox.damage_info.amount, 20.0, "Tri-cut should set amount to 20")
	
	# Test Sweeper (A-B-B)
	attack_state.enter()
	attack_state.buffered_attack = true
	attack_state.buffered_heavy = true
	attack_state.attack_timer = 0.0
	attack_state.physics_update(0.0)
	attack_state.buffered_attack = true
	attack_state.buffered_heavy = true
	attack_state.attack_timer = 0.0
	attack_state.physics_update(0.0)
	assert_eq("".join(attack_state.current_sequence), "ABB")
	assert_eq(player.katana_hitbox.damage_info.amount, 20.0, "Sweeper should set amount to 20")
	assert_eq(player.katana_hitbox.scale, Vector3(1.5, 1.0, 1.5), "Sweeper should widen hitbox")
	
	# Test Battery Ram (B-B)
	attack_state.enter()
	attack_state.current_sequence.clear()
	attack_state._start_attack(true) # First heavy
	attack_state.buffered_attack = true
	attack_state.buffered_heavy = true
	attack_state.attack_timer = 0.0
	attack_state.physics_update(0.0)
	assert_eq("".join(attack_state.current_sequence), "BB")
	assert_true(player.katana_hitbox.damage_info.is_guard_breaking, "Battery Ram should be guard breaking")
	assert_eq(player.katana_hitbox.damage_info.amount, 40.0)

	player.queue_free()

func test_combo_routes_are_resource_driven() -> void:
	# C4: route data (damage/duration/knockback/flags) must come from the ComboDef .tres
	# resources, not literals baked into player_state_attack.gd. Prove it by loading the
	# Launcher resource directly and confirming the attack state's output matches it exactly.
	var launcher_def: ComboDef = load("res://characters/player/combos/combo_launcher.tres")
	assert_not_null(launcher_def, "Launcher ComboDef resource should exist")
	assert_eq("".join(launcher_def.input_chain), "AAB")

	var player = load("res://characters/player/player.tscn").instantiate()
	add_child(player)
	var fsm = player.state_machine
	var attack_state = fsm.get_node("StateAttack")

	attack_state.enter() # A
	attack_state.buffered_attack = true
	attack_state.buffered_heavy = false
	attack_state.attack_timer = 0.0
	attack_state.physics_update(0.0) # AA
	attack_state.buffered_attack = true
	attack_state.buffered_heavy = true
	attack_state.attack_timer = 0.0
	attack_state.physics_update(0.0) # AAB (Launcher)

	assert_eq("".join(attack_state.current_sequence), "AAB")
	assert_eq(player.katana_hitbox.damage_info.amount, launcher_def.damage, "Launcher damage should match the ComboDef resource")
	assert_eq(player.katana_hitbox.damage_info.knockback, launcher_def.knockback, "Launcher knockback should match the ComboDef resource")
	assert_eq(player.katana_hitbox.damage_info.stun, launcher_def.stun_time, "Launcher stun should match the ComboDef resource")
	assert_true(player.katana_hitbox.damage_info.is_launcher, "Launcher route should set is_launcher")
	assert_almost_eq(attack_state.attack_timer, launcher_def.duration, 0.001, "Attack timer should match the ComboDef duration")

	player.queue_free()

func test_bruiser_shield_driven_by_enemy_stats() -> void:
	# C4: Bruiser's shield must come from EnemyStats.shield (bruiser_stats.tres), not a
	# hardcoded 50.0 in bruiser.gd.
	var stats: EnemyStats = load("res://characters/enemies/bruiser/bruiser_stats.tres")
	assert_not_null(stats, "Bruiser stats resource should exist")
	assert_eq(stats.shield, 50.0, "bruiser_stats.tres should define shield = 50")

	var bruiser = load("res://characters/enemies/bruiser/bruiser.tscn").instantiate()
	add_child(bruiser)
	var health = bruiser.get_node("HealthComponent")
	assert_eq(health.max_shield, stats.shield, "Bruiser's max_shield should be sourced from EnemyStats.shield")
	assert_eq(health.current_shield, stats.shield, "Bruiser's current_shield should be sourced from EnemyStats.shield")

	bruiser.queue_free()

func test_hit_stop_time_scale_recovery() -> void:
	var hit_stop = get_node("/root/HitStop")
	assert_not_null(hit_stop, "HitStop autoload should exist")
	
	Engine.time_scale = 1.0
	hit_stop.hit_stop_timer = 0.0
	
	SignalBus.hit_stop_requested.emit(0.1, 0.05)
	assert_eq(Engine.time_scale, 0.05, "Time scale should be set to target scale")
	assert_almost_eq(hit_stop.hit_stop_timer, 0.1, 0.01)
	
	hit_stop._process(0.0025) # real_delta = 0.0025 / 0.05 = 0.05
	assert_eq(Engine.time_scale, 0.05, "Time scale should remain low before duration expires")
	assert_almost_eq(hit_stop.hit_stop_timer, 0.05, 0.01)
	
	hit_stop._process(0.003) # real_delta = 0.003 / 0.05 = 0.06
	assert_eq(Engine.time_scale, 1.0, "Time scale should recover to 1.0")
	assert_eq(hit_stop.hit_stop_timer, 0.0)
