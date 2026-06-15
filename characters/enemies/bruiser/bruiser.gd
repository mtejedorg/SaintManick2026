class_name BruiserEnemy
extends CharacterBody3D

@export var stats: EnemyStats

@onready var health_component: HealthComponent = $HealthComponent
@onready var hitbox: Hitbox3D = $Hitbox3D
@onready var mesh_instance: MeshInstance3D = $MeshInstance3D

var player: Node3D
var base_material: StandardMaterial3D

func _ready() -> void:
	if not stats:
		stats = load("res://characters/enemies/bruiser/bruiser_stats.tres")
		
	health_component.max_health = stats.max_health
	health_component.current_health = stats.max_health
	health_component.health_changed.connect(_on_health_changed)
	health_component.died.connect(_on_died)
	
	hitbox.damage_info = DamageInfo.new()
	hitbox.damage_info.amount = stats.damage
	hitbox.damage_info.knockback = stats.knockback
	hitbox.damage_info.stun = stats.stun
	hitbox.damage_info.source = self
	hitbox.is_active = true

	# Setup base material
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

	player = get_tree().current_scene.get_node_or_null("Player")
	SignalBus.beat.connect(_on_beat)

func _physics_process(delta: float) -> void:
	if not is_on_floor():
		velocity += get_gravity() * delta
	move_and_slide()

func _on_beat(layer: String, beat_index: int) -> void:
	if layer != "primary":
		return
	# Visual scale pulse on the beat
	var tween = create_tween()
	tween.tween_property(mesh_instance, "scale", Vector3(1.1, 1.1, 1.1), 0.1).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	tween.tween_property(mesh_instance, "scale", Vector3(1.0, 1.0, 1.0), 0.2).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN)

func _on_health_changed(current: float, _max_health: float) -> void:
	print("Bruiser hit! HP: ", current)
	velocity.y = 2.0

func _on_died() -> void:
	print("Bruiser Died!")
	GameManager.add_scrap(stats.scrap)
	queue_free()
