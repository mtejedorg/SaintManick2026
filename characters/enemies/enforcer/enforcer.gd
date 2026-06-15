class_name EnforcerEnemy
extends CharacterBody3D

@export var stats: EnemyStats

@onready var health_component: HealthComponent = $HealthComponent
@onready var hitbox: Hitbox3D = $Hitbox3D
@onready var mesh_instance: MeshInstance3D = $MeshInstance3D

var player: Node3D
var base_material: StandardMaterial3D
var telegraph_material: StandardMaterial3D
var in_attack_sequence: bool = false

func _ready() -> void:
	if not stats:
		stats = load("res://characters/enemies/enforcer/enforcer_stats.tres")
		
	health_component.max_health = stats.max_health
	health_component.current_health = stats.max_health
	health_component.health_changed.connect(_on_health_changed)
	health_component.died.connect(_on_died)
	
	hitbox.damage_info = DamageInfo.new()
	hitbox.damage_info.amount = stats.damage
	hitbox.damage_info.knockback = stats.knockback
	hitbox.damage_info.stun = stats.stun
	hitbox.damage_info.source = self
	hitbox.is_active = false

	# Setup materials
	base_material = mesh_instance.get_surface_override_material(0)
	if not base_material:
		var active_mesh = mesh_instance.mesh
		if active_mesh and active_mesh.material:
			base_material = active_mesh.material
	if base_material:
		base_material = base_material.duplicate()
	else:
		base_material = StandardMaterial3D.new()
	mesh_instance.set_surface_override_material(0, base_material)

	telegraph_material = base_material.duplicate()
	telegraph_material.albedo_color = Color(1.0, 0.3, 0.0, 1.0)
	telegraph_material.emission_enabled = true
	telegraph_material.emission = Color(1.0, 0.3, 0.0, 1.0)

	player = get_tree().current_scene.get_node_or_null("Player")
	SignalBus.beat.connect(_on_beat)

func _physics_process(delta: float) -> void:
	if not is_on_floor():
		velocity += get_gravity() * delta
		
	if player and is_on_floor() and not in_attack_sequence:
		var dist = global_position.distance_to(player.global_position)
		if dist > 3.0:
			var dir = (player.global_position - global_position).normalized()
			dir.y = 0
			velocity.x = dir.x * stats.speed
			velocity.z = dir.z * stats.speed
		else:
			velocity.x = move_toward(velocity.x, 0, 10 * delta)
			velocity.z = move_toward(velocity.z, 0, 10 * delta)
	elif in_attack_sequence:
		velocity.x = move_toward(velocity.x, 0, 5 * delta)
		velocity.z = move_toward(velocity.z, 0, 5 * delta)
		
	move_and_slide()

func _on_beat(layer: String, beat_index: int) -> void:
	if layer != "primary":
		return
		
	# Enforcer cycle:
	# Beat 1: Check distance & telegraph
	# Beat 2: Lunge & swing
	# Beat 3: Reset hitbox and recover albedo
	# Beat 4: End sequence
	match beat_index:
		1:
			if player:
				var dist = global_position.distance_to(player.global_position)
				if dist <= 4.0:
					in_attack_sequence = true
					mesh_instance.set_surface_override_material(0, telegraph_material)
					print("Enforcer charges attack on beat 1")
		2:
			if in_attack_sequence:
				hitbox.is_active = true
				if player:
					var dir = (player.global_position - global_position).normalized()
					dir.y = 0
					velocity.x = dir.x * stats.speed * 1.5
					velocity.z = dir.z * stats.speed * 1.5
				print("Enforcer swings on beat 2")
		3:
			if in_attack_sequence:
				hitbox.is_active = false
				mesh_instance.set_surface_override_material(0, base_material)
				print("Enforcer recovers on beat 3")
		4:
			in_attack_sequence = false
			mesh_instance.set_surface_override_material(0, base_material)

func _on_health_changed(current: float, _max_health: float) -> void:
	print("Enforcer hit! HP: ", current)

func _on_died() -> void:
	print("MINI-BOSS DEFEATED!")
	GameManager.add_scrap(stats.scrap)
	queue_free()
