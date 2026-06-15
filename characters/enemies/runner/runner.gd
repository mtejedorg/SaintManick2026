class_name RunnerEnemy
extends CharacterBody3D

@onready var health_component: HealthComponent = $HealthComponent

func _ready() -> void:
	health_component.health_changed.connect(_on_health_changed)
	health_component.died.connect(_on_died)

func _physics_process(delta: float) -> void:
	if not is_on_floor():
		velocity += get_gravity() * delta
	move_and_slide()

func _on_health_changed(current: int, _max_health: int) -> void:
	# Prototype hit feedback
	print("Runner hit! HP: ", current)
	velocity.y = 8.0 # Pop up slightly on hit

func _on_died() -> void:
	print("Runner Died!")
	queue_free()
