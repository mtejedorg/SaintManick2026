extends Node

@export var friction: float = 15.0 # Floor horizontal decay friction
@export var normal_hit_y_pop: float = 3.0
@export var launcher_hit_y_pop: float = 8.0

var stun_timer: float = 0.0

func _ready() -> void:
	var enemy = get_parent()
	if enemy:
		var hurtbox = enemy.get_node_or_null("Hurtbox3D")
		if not hurtbox:
			for child in enemy.get_children():
				if child is Hurtbox3D:
					hurtbox = child
					break
		if hurtbox:
			hurtbox.hit_received.connect(_on_hit_received)

func _physics_process(delta: float) -> void:
	var enemy = get_parent() as CharacterBody3D
	if not enemy:
		return
		
	if stun_timer > 0.0:
		stun_timer -= delta
		if stun_timer < 0.0:
			stun_timer = 0.0
			
		if enemy.is_on_floor():
			enemy.velocity.x = move_toward(enemy.velocity.x, 0.0, friction * delta)
			enemy.velocity.z = move_toward(enemy.velocity.z, 0.0, friction * delta)

func _on_hit_received(damage_info: DamageInfo) -> void:
	var enemy = get_parent() as CharacterBody3D
	if not enemy:
		return
		
	if enemy.health_component and enemy.health_component.is_invincible:
		return
		
	var has_shield = enemy.get("health_component") and enemy.health_component.current_shield > 0.0
	if has_shield and not damage_info.is_guard_breaking:
		return
		
	# Calculate knockback direction
	var knockback_dir = Vector3.ZERO
	if damage_info.source:
		knockback_dir = (enemy.global_position - damage_info.source.global_position).normalized()
		knockback_dir.y = 0
		if knockback_dir == Vector3.ZERO:
			knockback_dir = Vector3.RIGHT if randf() > 0.5 else Vector3.LEFT
		else:
			knockback_dir = knockback_dir.normalized()
	else:
		knockback_dir = Vector3.RIGHT
		
	# Apply knockback velocities
	var force = damage_info.knockback
	enemy.velocity.x = knockback_dir.x * force
	enemy.velocity.z = knockback_dir.z * force
	
	# Apply vertical pop
	if damage_info.is_launcher:
		enemy.velocity.y = launcher_hit_y_pop
	else:
		enemy.velocity.y = normal_hit_y_pop
		
	stun_timer = damage_info.stun

func is_stunned() -> bool:
	return stun_timer > 0.0
