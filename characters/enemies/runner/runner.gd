class_name RunnerEnemy
extends CharacterBody3D

@export var stats: EnemyStats

@onready var health_component: HealthComponent = $HealthComponent
@onready var hitbox: Hitbox3D = $Hitbox3D
@onready var mesh_instance: MeshInstance3D = $MeshInstance3D
var combat_comp: Node = null

var player: Node3D
var base_material: StandardMaterial3D
var telegraph_material: StandardMaterial3D
var attack_step: int = 0 # 0 = idle, 1 = telegraph, 2 = active, 3 = recovery
## Dormant until the player enters stats.aggro_range (checked per primary beat) or a
## WaveSpawner activates it. IntensityController treats is_active == false as dormant.
var is_active: bool = false

func _ready() -> void:
	var combat_script = load("res://_core/components/enemy_combat_component.gd")
	if combat_script:
		combat_comp = combat_script.new()
		combat_comp.name = "EnemyCombatComponent"
		add_child(combat_comp)

	if not stats:
		stats = load("res://characters/enemies/runner/runner_stats.tres")
		
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
	telegraph_material.albedo_color = Color(1.0, 0.0, 0.0, 1.0)
	telegraph_material.emission_enabled = true
	telegraph_material.emission = Color(1.0, 0.0, 0.0, 1.0)

	player = get_tree().current_scene.get_node_or_null("Player")
	SignalBus.beat.connect(_on_beat)

func _physics_process(delta: float) -> void:
	if _check_kill_plane():
		return
	if not is_on_floor():
		velocity += get_gravity() * delta
		
	if not combat_comp.is_stunned():
		if not is_active:
			# Dormant: stand still, no chase.
			velocity.x = move_toward(velocity.x, 0, 20 * delta)
			velocity.z = move_toward(velocity.z, 0, 20 * delta)
		elif player and is_on_floor():
			if attack_step == 0:
				var dist = global_position.distance_to(player.global_position)
				if dist > 1.5:
					var dir = (player.global_position - global_position).normalized()
					dir.y = 0
					velocity.x = dir.x * stats.speed
					velocity.z = dir.z * stats.speed
				else:
					velocity.x = move_toward(velocity.x, 0, 10 * delta)
					velocity.z = move_toward(velocity.z, 0, 10 * delta)
			elif attack_step == 2:
				velocity.x = move_toward(velocity.x, 0, 5 * delta)
				velocity.z = move_toward(velocity.z, 0, 5 * delta)
			else:
				velocity.x = move_toward(velocity.x, 0, 20 * delta)
				velocity.z = move_toward(velocity.z, 0, 20 * delta)
		
	move_and_slide()

func _on_beat(layer: String, beat_index: int) -> void:
	if layer != "primary":
		return
	_update_aggro()
	if not is_active:
		return
	if combat_comp.is_stunned():
		return
		
	if attack_step == 1:
		attack_step = 2
		hitbox.is_active = true
		if player:
			var dir = (player.global_position - global_position).normalized()
			dir.y = 0
			velocity.x = dir.x * stats.speed * 2.5
			velocity.z = dir.z * stats.speed * 2.5
	elif attack_step == 2:
		attack_step = 3
		hitbox.is_active = false
		mesh_instance.set_surface_override_material(0, base_material)
	elif attack_step == 3:
		attack_step = 0
		
	if attack_step == 0 and player:
		var dist = global_position.distance_to(player.global_position)
		if dist <= 2.5:
			attack_step = 1
			mesh_instance.set_surface_override_material(0, telegraph_material)

## Cheap per-beat aggro check: once the player is within aggro_range the grunt wakes up
## for good.
func _update_aggro() -> void:
	if is_active or not player or not is_instance_valid(player):
		return
	if global_position.distance_to(player.global_position) <= stats.aggro_range:
		is_active = true

## Out of the world -> despawn silently (no scrap, no enemy_died). Returns true if freed.
func _check_kill_plane() -> bool:
	if global_position.y < EnemyStats.KILL_PLANE_Y:
		queue_free()
		return true
	return false

func _on_health_changed(_current: float, _max_health: float) -> void:
	pass

func _on_died() -> void:
	GameManager.add_scrap(stats.scrap)
	SignalBus.enemy_died.emit(global_position)
	queue_free()

