class_name EnforcerEnemy
extends CharacterBody3D

@export var stats: EnemyStats

@onready var health_component: HealthComponent = $HealthComponent
@onready var hitbox: Hitbox3D = $Hitbox3D
@onready var mesh_instance: MeshInstance3D = $MeshInstance3D
@onready var character_visual: CharacterVisual = $MeshInstance3D
@onready var shield_bubble: MeshInstance3D = $ShieldBubble
@onready var state_machine: EnforcerStateMachine = $StateMachine
var combat_comp: Node = null

var player: Node3D
var is_shield_active: bool = false
var is_vulnerable: bool = false
## Scene-placed miniboss: stays dormant (no chase, no boss bar) until the player
## enters its zone. Activated by SignalBus.zone_entered for SECTOR 07.
var is_active: bool = false

func _ready() -> void:
	var combat_script = load("res://_core/components/enemy_combat_component.gd")
	if combat_script:
		combat_comp = combat_script.new()
		combat_comp.name = "EnemyCombatComponent"
		add_child(combat_comp)

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

	player = get_tree().current_scene.get_node_or_null("Player")

	# Initialize state machine
	state_machine.init(self)

	SignalBus.beat.connect(_on_beat)
	SignalBus.zone_entered.connect(_on_zone_entered)
	SignalBus.player_respawned.connect(_on_player_respawned)

## T3: the player lost a life mid-fight — return to dormant at full HP. The SECTOR 07
## ZoneTrigger re-arms itself on the same signal, so re-entering the zone re-activates
## the fight naturally via _on_zone_entered.
func _on_player_respawned() -> void:
	if not is_active:
		return
	if health_component.current_health <= 0.0:
		return # Defeated bosses stay defeated.
	is_active = false
	health_component.current_health = health_component.max_health
	health_component.health_changed.emit(health_component.current_health, health_component.max_health)
	velocity = Vector3.ZERO
	is_vulnerable = false
	if combat_comp:
		combat_comp.stun_timer = 0.0
	# Back to the fresh-boot state (initial_state = StateShield, which re-raises the
	# shield exactly like a new fight).
	if state_machine and state_machine.initial_state:
		state_machine.transition_to(state_machine.initial_state.name)
	SignalBus.boss_reset.emit()

func _on_zone_entered(zone_name: String) -> void:
	if is_active:
		return
	if "07" in zone_name or "ENFORCER" in zone_name.to_upper():
		is_active = true
		# Announce miniboss presence to HUD only once the fight begins
		SignalBus.boss_spawned.emit("Enforcer")
		SignalBus.boss_health_changed.emit(int(health_component.current_health), int(health_component.max_health))

func _physics_process(delta: float) -> void:
	if not is_active:
		# Dormant: settle on the floor but don't chase or attack.
		apply_gravity(delta)
		move_and_slide()
		return
	if combat_comp.is_stunned():
		apply_gravity(delta)
		move_and_slide()
	else:
		state_machine.physics_process(delta)

func apply_gravity(delta: float) -> void:
	if not is_on_floor():
		velocity += get_gravity() * delta

func _on_beat(layer: String, beat_index: int) -> void:
	if not is_active:
		return
	if combat_comp.is_stunned():
		return
	state_machine.handle_beat(layer, beat_index)


func break_shield() -> void:
	if state_machine.current_state and state_machine.current_state.has_method("on_shield_broken"):
		state_machine.current_state.on_shield_broken()

func _on_health_changed(current: float, max_health: float) -> void:
	SignalBus.boss_health_changed.emit(int(current), int(max_health))

func _on_died() -> void:
	GameManager.add_scrap(stats.scrap)
	if stats.cells > 0:
		GameManager.add_cells(stats.cells)
	SignalBus.enemy_died.emit(global_position)
	SignalBus.miniboss_defeated.emit()
	SignalBus.boss_died.emit()
	queue_free()
