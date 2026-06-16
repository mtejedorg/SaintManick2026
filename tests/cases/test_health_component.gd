extends "res://tests/framework/test_case.gd"

var health_comp: HealthComponent

func before_each() -> void:
	health_comp = HealthComponent.new()
	health_comp.max_health = 100.0
	health_comp.max_shield = 40.0
	health_comp.shield_regen_rate = 12.0
	health_comp.shield_regen_delay = 3.0
	health_comp.is_player = false
	add_child(health_comp)
	health_comp.current_health = health_comp.max_health
	health_comp.current_shield = health_comp.max_shield

func after_each() -> void:
	if is_instance_valid(health_comp):
		health_comp.queue_free()
	super.after_each() # Call parent to clean up SignalBus

func test_shield_absorbs_damage_first() -> void:
	var damage_info = DamageInfo.new()
	damage_info.amount = 20.0
	damage_info.is_shield_breaker = false
	
	health_comp.take_damage(damage_info)
	assert_eq(health_comp.current_shield, 20.0, "Shield should absorb 20 damage")
	assert_eq(health_comp.current_health, 100.0, "Health should remain unaffected")

func test_non_shield_breaker_spillover() -> void:
	var damage_info = DamageInfo.new()
	damage_info.amount = 60.0
	damage_info.is_shield_breaker = false
	
	health_comp.take_damage(damage_info)
	assert_eq(health_comp.current_shield, 0.0, "Shield should be depleted")
	assert_eq(health_comp.current_health, 80.0, "Health should absorb spillover damage")

func test_shield_breaker_bypasses_shield() -> void:
	var damage_info = DamageInfo.new()
	damage_info.amount = 30.0
	damage_info.is_shield_breaker = true
	
	health_comp.take_damage(damage_info)
	assert_eq(health_comp.current_shield, 0.0, "Shield should be depleted/set to 0 by shield breaker")
	assert_eq(health_comp.current_health, 70.0, "Health should absorb all damage directly")

func test_health_cannot_drop_below_zero_and_died_signal() -> void:
	var flags = {"died": false}
	health_comp.died.connect(func(): flags.died = true)
	
	var damage_info = DamageInfo.new()
	damage_info.amount = 200.0
	
	health_comp.take_damage(damage_info)
	assert_eq(health_comp.current_health, 0.0, "Health should not go below 0")
	assert_true(flags.died, "Died signal should be emitted")

func test_shield_regen_delay_and_processing() -> void:
	var damage_info = DamageInfo.new()
	damage_info.amount = 20.0
	health_comp.take_damage(damage_info)
	assert_eq(health_comp.current_shield, 20.0)
	
	health_comp._process(1.0)
	assert_eq(health_comp.current_shield, 20.0, "Shield should not regenerate during delay")
	
	health_comp._process(2.1) # Total elapsed > 3.0
	assert_eq(health_comp.current_shield, 20.0, "Shield should not regenerate on timer expiration frame")
	
	health_comp._process(1.0)
	assert_eq(health_comp.current_shield, 32.0, "Shield should regenerate at 12/s after delay")
	
	health_comp._process(1.0)
	assert_eq(health_comp.current_shield, 40.0, "Shield should clamp to max_shield")

func test_player_routing_to_signal_bus_and_game_manager() -> void:
	health_comp.is_player = true
	
	var flags = {
		"health": -1.0,
		"shield": -1.0,
		"died": false
	}
	
	var h_conn = func(h, mh): flags.health = h
	var s_conn = func(s, ms): flags.shield = s
	var d_conn = func(): flags.died = true
	
	SignalBus.player_health_changed.connect(h_conn)
	SignalBus.player_shield_changed.connect(s_conn)
	SignalBus.player_died.connect(d_conn)
	
	var damage_info = DamageInfo.new()
	damage_info.amount = 10.0
	health_comp.take_damage(damage_info)
	
	assert_eq(flags.shield, 30.0, "SignalBus shield signal should update")
	assert_eq(flags.health, 100.0, "SignalBus health signal should update")
	
	var gm = get_node_or_null("/root/GameManager")
	if gm:
		assert_eq(gm.current_hp, 100.0, "GameManager HP should update")
		assert_eq(gm.current_shield, 30.0, "GameManager Shield should update")
		
	var fatal_damage = DamageInfo.new()
	fatal_damage.amount = 150.0
	health_comp.take_damage(fatal_damage)
	
	assert_true(flags.died, "SignalBus player_died should be triggered")
	
	# Disconnect to clean up global SignalBus
	SignalBus.player_health_changed.disconnect(h_conn)
	SignalBus.player_shield_changed.disconnect(s_conn)
	SignalBus.player_died.disconnect(d_conn)
