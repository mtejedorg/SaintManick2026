class_name EnforcerEnemy
extends CharacterBody3D

@export var stats: EnemyStats

@onready var health_component: HealthComponent = $HealthComponent
@onready var hitbox: Hitbox3D = $Hitbox3D
@onready var mesh_instance: MeshInstance3D = $MeshInstance3D
@onready var shield_bubble: MeshInstance3D = $ShieldBubble
@onready var state_machine: EnforcerStateMachine = $StateMachine

var player: Node3D
var base_material: StandardMaterial3D
var telegraph_material: StandardMaterial3D
var vulnerable_material: StandardMaterial3D

var is_shield_active: bool = false
var is_vulnerable: bool = false

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

	vulnerable_material = base_material.duplicate()
	vulnerable_material.albedo_color = Color(0.2, 0.6, 1.0, 1.0)
	vulnerable_material.emission_enabled = true
	vulnerable_material.emission = Color(0.1, 0.3, 0.8, 1.0)

	player = get_tree().current_scene.get_node_or_null("Player")
	
	# Initialize state machine
	state_machine.init(self)
	
	SignalBus.beat.connect(_on_beat)

func _physics_process(delta: float) -> void:
	state_machine.physics_process(delta)

func apply_gravity(delta: float) -> void:
	if not is_on_floor():
		velocity += get_gravity() * delta

func _on_beat(layer: String, beat_index: int) -> void:
	state_machine.handle_beat(layer, beat_index)

func break_shield() -> void:
	print("Enforcer shield broken!")
	if state_machine.current_state and state_machine.current_state.has_method("on_shield_broken"):
		state_machine.current_state.on_shield_broken()

func _on_health_changed(current: float, _max_health: float) -> void:
	print("Enforcer hit! HP: ", current)

func _on_died() -> void:
	print("MINI-BOSS DEFEATED!")
	GameManager.add_scrap(stats.scrap)
	GameManager.complete_run()
	queue_free()
