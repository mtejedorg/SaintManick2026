class_name SniperEnemy
extends CharacterBody3D

@export var stats: EnemyStats

@onready var health_component: HealthComponent = $HealthComponent
@onready var laser_beam: MeshInstance3D = $LaserBeam
@onready var laser_hitbox: Hitbox3D = $LaserHitbox
var combat_comp: Node = null

var player: Node3D
var laser_material: StandardMaterial3D
var is_aim_locked: bool = false

func _ready() -> void:
	var combat_script = load("res://_core/components/enemy_combat_component.gd")
	if combat_script:
		combat_comp = combat_script.new()
		combat_comp.name = "EnemyCombatComponent"
		add_child(combat_comp)

	if not stats:
		stats = load("res://characters/enemies/sniper/sniper_stats.tres")
		
	health_component.max_health = stats.max_health
	health_component.current_health = stats.max_health
	health_component.health_changed.connect(_on_health_changed)
	health_component.died.connect(_on_died)
	
	laser_hitbox.damage_info = DamageInfo.new()
	laser_hitbox.damage_info.amount = stats.damage
	laser_hitbox.damage_info.knockback = stats.knockback
	laser_hitbox.damage_info.stun = stats.stun
	laser_hitbox.damage_info.source = self
	laser_hitbox.is_active = false
	
	laser_hitbox.collision_layer = 8192 # Layer 14
	laser_hitbox.collision_mask = 1024 # Layer 11
	
	laser_beam.visible = false
	
	# Setup laser material
	laser_material = StandardMaterial3D.new()
	laser_material.albedo_color = Color(1.0, 0.0, 0.0, 0.5)
	laser_material.transparency = StandardMaterial3D.TRANSPARENCY_ALPHA
	laser_material.emission_enabled = true
	laser_material.emission = Color(1.0, 0.0, 0.0, 1.0)
	laser_beam.set_surface_override_material(0, laser_material)

	player = get_tree().current_scene.get_node_or_null("Player")
	SignalBus.beat.connect(_on_beat)

func _physics_process(delta: float) -> void:
	if not is_on_floor():
		velocity += get_gravity() * delta
	if not combat_comp.is_stunned():
		if player and not is_aim_locked:
			var target_pos = player.global_position
			target_pos.y = global_position.y
			if global_position.distance_to(target_pos) > 0.1:
				look_at(target_pos, Vector3.UP)
	move_and_slide()

func _on_beat(layer: String, beat_index: int) -> void:
	if layer != "primary":
		return
	if combat_comp.is_stunned():
		laser_beam.visible = false
		laser_hitbox.is_active = false
		return
		
	match beat_index:
		3:
			is_aim_locked = false
			laser_beam.visible = true
			laser_beam.scale = Vector3(0.05, 0.05, 1.0)
			laser_material.albedo_color.a = 0.3
		4:
			is_aim_locked = true
			laser_beam.scale = Vector3(0.15, 0.15, 1.0)
			laser_material.albedo_color.a = 0.6
		1:
			laser_beam.visible = true
			laser_beam.scale = Vector3(1.0, 1.0, 1.0)
			laser_material.albedo_color.a = 1.0
			laser_hitbox.is_active = true
		2:
			laser_beam.visible = false
			laser_hitbox.is_active = false
			is_aim_locked = false

func _on_health_changed(_current: float, _max_health: float) -> void:
	pass

func _on_died() -> void:
	GameManager.add_scrap(stats.scrap)
	SignalBus.enemy_died.emit(global_position)
	queue_free()
