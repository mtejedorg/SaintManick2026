class_name HeadlinerBoss
extends CharacterBody3D

@export var stats: EnemyStats

@onready var health_component: HealthComponent = $HealthComponent
@onready var mesh_instance: MeshInstance3D = $MeshInstance3D

var base_material: StandardMaterial3D
var phase_2_material: StandardMaterial3D
var phase_2_triggered: bool = false

func _ready() -> void:
	if not stats:
		stats = load("res://characters/enemies/headliner/headliner_stats.tres")
		
	health_component.max_health = stats.max_health
	health_component.current_health = stats.max_health
	health_component.health_changed.connect(_on_health_changed)
	health_component.died.connect(_on_died)
	
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

	phase_2_material = base_material.duplicate()
	phase_2_material.albedo_color = Color(1.0, 0.0, 1.0, 1.0)
	phase_2_material.emission_enabled = true
	phase_2_material.emission = Color(0.8, 0.0, 0.8, 1.0)

	SignalBus.beat.connect(_on_beat)

func _physics_process(delta: float) -> void:
	if not is_on_floor():
		velocity += get_gravity() * delta
	move_and_slide()

func _on_beat(layer: String, beat_index: int) -> void:
	if layer != "primary":
		return
		
	if phase_2_triggered:
		print("Headliner fires bullet hell wave on beat ", beat_index)
		# Pulse albedo on beat
		var tween = create_tween()
		tween.tween_property(mesh_instance, "scale", Vector3(1.1, 1.1, 1.1), 0.1).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
		tween.tween_property(mesh_instance, "scale", Vector3(1.0, 1.0, 1.0), 0.2).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN)

func _on_health_changed(current: float, _max_health: float) -> void:
	print("Headliner hit! HP: ", current)
	if current < stats.max_health * 0.5 and not phase_2_triggered:
		phase_2_triggered = true
		print("PHASE 2 INITIATED")
		mesh_instance.set_surface_override_material(0, phase_2_material)
		if Conductor:
			Conductor.target_bpm = 160.0

func _on_died() -> void:
	print("VERTICAL SLICE COMPLETE!")
	if Conductor:
		Conductor.target_bpm = 128.0
	GameManager.add_scrap(stats.scrap)
	queue_free()
