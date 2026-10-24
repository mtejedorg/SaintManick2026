class_name HeadlinerBoss
extends CharacterBody3D

@export var stats: EnemyStats
@export var path_z10: Path3D

@onready var health_component: HealthComponent = $HealthComponent
@onready var hitbox: Hitbox3D = $Hitbox3D
@onready var hurtbox: Hurtbox3D = $Hurtbox3D
@onready var mesh_instance: MeshInstance3D = $MeshInstance3D
@onready var character_visual: CharacterVisual = $MeshInstance3D
@onready var shield_bubble: MeshInstance3D = $ShieldBubble
@onready var state_machine: HeadlinerStateMachine = $StateMachine
@onready var emitter: ProjectileEmitter = $ProjectileEmitter
@onready var pool: ObjectPool = $ObjectPool
@onready var boss_music_a: AudioStreamPlayer = $BossMusicA
@onready var boss_music_b: AudioStreamPlayer = $BossMusicB

var combat_comp: Node = null
var player: Node3D

var is_active_boss: bool = false
var is_shield_active: bool = false
var is_vulnerable: bool = false
var speed_multiplier: float = 1.0
var phase_2_triggered: bool = false
## Phase 2 swaps the resting rim to magenta (phase 1 rests at the authored amber).
const PHASE_2_RIM_COLOR := CharacterVisual.ENEMY_RIM_COLOR
## Authored scale of the visual (headliner.tscn sets MeshInstance3D to scale 3). The beat
## pulse and the respawn reset are relative to this, never to Vector3.ONE.
var _base_scale: Vector3 = Vector3.ONE

func _ready() -> void:
	var combat_script = load("res://_core/components/enemy_combat_component.gd")
	if combat_script:
		combat_comp = combat_script.new()
		combat_comp.name = "EnemyCombatComponent"
		add_child(combat_comp)

	if not stats:
		stats = load("res://characters/enemies/headliner/headliner_stats.tres")
		
	health_component.max_health = stats.max_health
	health_component.current_health = stats.max_health
	health_component.health_changed.connect(_on_health_changed)
	health_component.died.connect(_on_died)
	
	if hitbox:
		hitbox.damage_info = DamageInfo.new()
		hitbox.damage_info.amount = stats.damage
		hitbox.damage_info.knockback = stats.knockback
		hitbox.damage_info.stun = stats.stun
		hitbox.damage_info.source = self
		hitbox.is_active = false

	if mesh_instance:
		_base_scale = mesh_instance.scale

	player = get_tree().current_scene.get_node_or_null("Player")
	if not player:
		player = get_tree().root.find_child("Player", true, false)

	# Initialize state machine
	if state_machine:
		state_machine.init(self)

	SignalBus.beat.connect(_on_beat)
	SignalBus.player_respawned.connect(_on_player_respawned)

	AudioManager.register_boss_music_players(boss_music_a, boss_music_b)

## T3: the player lost a life mid-fight — full reset back to the dormant pre-fight
## state. The Zone10_Trigger (a ZoneTrigger) re-arms itself on the same signal, so
## walking back into the arena restarts the fight via activate_boss.
func _on_player_respawned() -> void:
	# In-flight bullets would otherwise keep flying through the respawn grace window.
	if pool:
		pool.release_all()
	if not is_active_boss:
		return
	if health_component.current_health <= 0.0:
		return # A defeated Headliner stays defeated.
	health_component.current_health = health_component.max_health
	health_component.health_changed.emit(health_component.current_health, health_component.max_health)
	velocity = Vector3.ZERO
	is_vulnerable = false
	phase_2_triggered = false
	speed_multiplier = 1.0
	if combat_comp:
		combat_comp.stun_timer = 0.0
	# Restore the pre-phase-2 look (phase 2 swapped the resting rim).
	if character_visual:
		character_visual.update_rim_color(character_visual.get_default_rim_color())
	if mesh_instance:
		mesh_instance.scale = _base_scale
	if Conductor:
		Conductor.target_bpm = 128.0
	# Re-open the LeftGate so the player can walk back in.
	var gate = get_parent().get_node_or_null("LeftGate")
	if gate:
		var col = gate.get_node_or_null("CollisionShape3D")
		if col:
			col.set_deferred("disabled", true)
	# StateDormant.enter() clears is_active_boss/is_shield_active and hides the bubble.
	if state_machine:
		state_machine.transition_to("StateDormant")
	is_active_boss = false
	SignalBus.boss_reset.emit()

## The rim the boss rests at in its current phase (vulnerable windows return here).
func get_resting_rim_color() -> Color:
	if phase_2_triggered:
		return PHASE_2_RIM_COLOR
	return character_visual.get_default_rim_color() if character_visual else CharacterVisual.ENEMY_RIM_COLOR

func _announce_boss() -> void:
	SignalBus.boss_spawned.emit("Headliner")
	SignalBus.boss_health_changed.emit(int(health_component.current_health), int(health_component.max_health))

func _physics_process(delta: float) -> void:
	if not is_active_boss:
		return
	if combat_comp and combat_comp.is_stunned():
		apply_gravity(delta)
		move_and_slide()
	elif state_machine:
		state_machine.physics_process(delta)

func apply_gravity(delta: float) -> void:
	if not is_on_floor():
		velocity += get_gravity() * delta

func activate_boss(body: Node3D = null) -> void:
	if body and not body is PlayerController:
		return
	if is_active_boss:
		return
	is_active_boss = true

	# Boss bar + boss music only start when the fight actually begins.
	_announce_boss()

	# Enable LeftGate collision to seal player in arena
	var gate = get_parent().get_node_or_null("LeftGate")
	if gate:
		var col = gate.get_node_or_null("CollisionShape3D")
		if col:
			col.set_deferred("disabled", false)

	if state_machine:
		state_machine.transition_to("StateShield")


func break_shield() -> void:
	if state_machine and state_machine.current_state and state_machine.current_state.has_method("on_shield_broken"):
		state_machine.current_state.on_shield_broken()

func _on_beat(layer: String, beat_index: int) -> void:
	if not is_active_boss:
		return
	if layer != "primary":
		return
	if combat_comp and combat_comp.is_stunned():
		return
		
	if phase_2_triggered and mesh_instance:
		# Pulse albedo/scale on beat
		var tween = create_tween()
		tween.tween_property(mesh_instance, "scale", _base_scale * 1.05, 0.1).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
		tween.tween_property(mesh_instance, "scale", _base_scale, 0.2).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN)

	if state_machine:
		state_machine.handle_beat(layer, beat_index)

func _on_health_changed(current: float, max_health: float) -> void:
	SignalBus.boss_health_changed.emit(int(current), int(max_health))
	if current <= stats.max_health * 0.5 and not phase_2_triggered:
		phase_2_triggered = true
		if character_visual:
			character_visual.update_rim_color(PHASE_2_RIM_COLOR)
		if Conductor:
			Conductor.target_bpm = 160.0
		if state_machine:
			state_machine.transition_to("StateTransition")

func _on_died() -> void:
	SignalBus.boss_died.emit()
	SignalBus.enemy_died.emit(global_position)
	if stats:
		GameManager.add_scrap(stats.scrap)
	# Data Cores (GDD §5.1/§4.2): "Defeating one drops a Data Core" — district bosses only.
	GameManager.add_cores(1)
	if Conductor:
		Conductor.target_bpm = 128.0
	if state_machine:
		state_machine.transition_to("StateDead")
