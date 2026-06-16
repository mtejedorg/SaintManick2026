extends "res://tests/framework/test_case.gd"

var parent_node: Node3D
var hitbox: Hitbox3D
var hurtbox: Hurtbox3D
var health_comp: HealthComponent

func before_each() -> void:
	parent_node = Node3D.new()
	add_child(parent_node)
	
	hitbox = Hitbox3D.new()
	parent_node.add_child(hitbox)
	hitbox.owner = parent_node # Set owner so hitbox can resolve damage_info.source = owner
	
	health_comp = HealthComponent.new()
	health_comp.max_health = 100.0
	health_comp.max_shield = 0.0 # No shield to make health math easy
	health_comp.is_player = false
	parent_node.add_child(health_comp)
	health_comp.current_health = health_comp.max_health
	health_comp.current_shield = health_comp.max_shield
	
	hurtbox = Hurtbox3D.new()
	hurtbox.health_component = health_comp
	parent_node.add_child(hurtbox)

func after_each() -> void:
	if is_instance_valid(parent_node):
		parent_node.queue_free()

func test_active_hitbox_inflicts_damage() -> void:
	hitbox.damage_info = DamageInfo.new()
	hitbox.damage_info.amount = 15.0
	hitbox.is_active = true
	
	var flags = {"hit_received": false}
	hurtbox.hit_received.connect(func(info): flags.hit_received = true)
	
	# Manually simulate area overlap
	hitbox._on_area_entered(hurtbox)
	
	assert_true(flags.hit_received, "Hurtbox should emit hit_received signal")
	assert_eq(health_comp.current_health, 85.0, "HealthComponent should receive 15.0 damage")

func test_inactive_hitbox_ignores_overlaps() -> void:
	hitbox.damage_info = DamageInfo.new()
	hitbox.damage_info.amount = 15.0
	hitbox.is_active = false
	
	var flags = {"hit_received": false}
	hurtbox.hit_received.connect(func(info): flags.hit_received = true)
	
	# Manually simulate area overlap
	hitbox._on_area_entered(hurtbox)
	
	assert_false(flags.hit_received, "Hurtbox should not emit hit_received signal when hitbox is inactive")
	assert_eq(health_comp.current_health, 100.0, "HealthComponent should not receive damage when hitbox is inactive")

func test_source_populated_with_owner_if_unset() -> void:
	hitbox.damage_info = DamageInfo.new()
	hitbox.damage_info.amount = 10.0
	hitbox.damage_info.source = null
	hitbox.is_active = true
	
	hitbox._on_area_entered(hurtbox)
	
	assert_not_null(hitbox.damage_info.source, "Damage source should be populated")
	assert_eq(hitbox.damage_info.source, parent_node, "Damage source should be set to the hitbox owner")

func test_source_remains_unchanged_if_already_set() -> void:
	var custom_source = Node3D.new()
	add_child(custom_source)
	
	hitbox.damage_info = DamageInfo.new()
	hitbox.damage_info.amount = 10.0
	hitbox.damage_info.source = custom_source
	hitbox.is_active = true
	
	hitbox._on_area_entered(hurtbox)
	
	assert_eq(hitbox.damage_info.source, custom_source, "Damage source should not be overwritten if already set")
	
	custom_source.queue_free()
