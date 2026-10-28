class_name EnforcerEnemy
extends CharacterBody3D

@export var stats: EnemyStats
## H1: the Zone 7 entry seal (a StaticBody3D in the "gates" group with a CollisionShape3D
## and a Visual child, same shape as the Zone 10 LeftGate). Closed while the fight is live,
## opened on defeat and on the respawn reset. Optional: no gate, no seal.
@export var entry_gate: Node3D

@onready var health_component: HealthComponent = $HealthComponent
@onready var hitbox: Hitbox3D = $Hitbox3D
@onready var mesh_instance: MeshInstance3D = $MeshInstance3D
@onready var character_visual: CharacterVisual = $MeshInstance3D
@onready var shield_bubble: MeshInstance3D = $ShieldBubble
@onready var state_machine: EnforcerStateMachine = $StateMachine
var combat_comp: Node = null
## U2: the strike footprint on the floor; U3: the reactive shield bubble (per-instance materials).
const TelegraphZoneScript := preload("res://vfx/telegraph_zone.gd")
const ShieldBubbleFxScript := preload("res://vfx/shield_bubble_fx.gd")
var telegraph_zone: Node3D = null
var _shield_fx = null

## Unrigged mesh (Enforcer_Hammer.glb): procedural life instead of clips.
const BEAT_SQUASH := 0.03            # +3 % height on every primary beat
const BEAT_SQUASH_SECONDS := 0.1
const TELEGRAPH_LEAN_DEGREES := 8.0  # tips toward the model's front for the telegraph beat
## F8: yaw rate (rad/s, lerp_angle weight per second) while turning to face Nick.
const TURN_RATE := 10.0

var player: Node3D
## U5: the shield is on/off; the HUD strip reads it as full (SHIELD_STRIP_MAX) or empty.
const SHIELD_STRIP_MAX := 1.0
## Set by the states. Only a live fight reports it (the dormant boss boots in StateShield).
var is_shield_active: bool = false:
	set(value):
		if value == is_shield_active:
			return
		is_shield_active = value
		if is_active:
			_emit_shield_state()
var is_vulnerable: bool = false
## Scene-placed miniboss: stays dormant (no chase, no boss bar) until the player
## enters its zone. Activated by SignalBus.zone_entered for SECTOR 07.
var is_active: bool = false
## H1: where the scene placed the boss. A boss is never freed by the kill plane — it is
## put back here instead (and on the respawn reset).
var _spawn_transform: Transform3D

func _ready() -> void:
	_spawn_transform = global_transform
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
	telegraph_zone = TelegraphZoneScript.attach(self, hitbox, TelegraphZoneScript.COLOR_MAGENTA)
	if shield_bubble:
		_shield_fx = ShieldBubbleFxScript.new(shield_bubble)

	player = get_tree().current_scene.get_node_or_null("Player")

	# Initialize state machine
	state_machine.init(self)

	SignalBus.beat.connect(_on_beat)
	SignalBus.zone_entered.connect(_on_zone_entered)
	SignalBus.player_respawned.connect(_on_player_respawned)
	SignalBus.hit_blocked.connect(_on_hit_blocked)

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
	global_transform = _spawn_transform
	velocity = Vector3.ZERO
	is_vulnerable = false
	_set_entry_gate_closed(false)
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
		_set_entry_gate_closed(true)
		# Announce miniboss presence to HUD only once the fight begins
		SignalBus.boss_spawned.emit("Enforcer")
		SignalBus.boss_health_changed.emit(int(health_component.current_health), int(health_component.max_health))
		_emit_shield_state()

func _emit_shield_state() -> void:
	SignalBus.boss_shield_changed.emit(SHIELD_STRIP_MAX if is_shield_active else 0.0, SHIELD_STRIP_MAX)

func _physics_process(delta: float) -> void:
	if _check_kill_plane():
		return
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

## H1: out of the world -> back to the spawn point (never free a boss). True if it reset.
func _check_kill_plane() -> bool:
	if global_position.y < EnemyStats.KILL_PLANE_Y:
		global_transform = _spawn_transform
		velocity = Vector3.ZERO
		return true
	return false

## H1: seal (true) / open (false) the arena entry. The collision flip is deferred: this can
## run from a zone trigger's body_entered callback.
func _set_entry_gate_closed(closed: bool) -> void:
	if not entry_gate or not is_instance_valid(entry_gate):
		return
	var col := entry_gate.get_node_or_null("CollisionShape3D") as CollisionShape3D
	if col:
		col.set_deferred("disabled", not closed)
	var visual := entry_gate.get_node_or_null("Visual") as Node3D
	if visual:
		visual.visible = closed

func apply_gravity(delta: float) -> void:
	if not is_on_floor():
		velocity += get_gravity() * delta

func _on_beat(layer: String, beat_index: int) -> void:
	if layer == "primary" and character_visual:
		character_visual.beat_pulse(BEAT_SQUASH, BEAT_SQUASH_SECONDS)
	if not is_active:
		return
	if combat_comp.is_stunned():
		return
	state_machine.handle_beat(layer, beat_index)


func break_shield() -> void:
	# U3: flash first - the state change below hides the bubble in the same call.
	if _shield_fx and is_shield_active:
		_shield_fx.break_flash()
	if state_machine.current_state and state_machine.current_state.has_method("on_shield_broken"):
		state_machine.current_state.on_shield_broken()

func _on_health_changed(current: float, max_health: float) -> void:
	SignalBus.boss_health_changed.emit(int(current), int(max_health))

func _on_died() -> void:
	hide_telegraph_zone()
	GameManager.add_scrap(stats.scrap)
	if stats.cells > 0:
		GameManager.add_cells(stats.cells)
	SignalBus.enemy_died.emit(global_position if is_inside_tree() else Vector3.ZERO)
	SignalBus.miniboss_defeated.emit()
	SignalBus.boss_died.emit()
	_set_entry_gate_closed(false)
	# F3: flash + shrink, then free (rewards and signals above stay immediate).
	if shield_bubble:
		shield_bubble.visible = false
	if combat_comp:
		combat_comp.play_death_and_free(character_visual)
	else:
		queue_free()

## U3: a blocked hit (hit_blocked carries the hurtbox position) while this shield is up sends a
## ripple across the bubble toward where it landed.
func _on_hit_blocked(position: Vector3) -> void:
	if _shield_fx == null or not is_shield_active or not shield_bubble or not shield_bubble.visible:
		return
	if not _shield_fx.is_hit_in_range(position):
		return
	_shield_fx.ripple(position, player.global_position if player else Vector3.ZERO)

## U2: the floor footprint of the strike (vfx/telegraph_zone.gd), shown for the telegraph and
## hidden when the hitbox arms.
func show_telegraph_zone() -> void:
	if telegraph_zone:
		telegraph_zone.show_telegraph(60.0 / maxf(Conductor.bpm, 1.0))

func hide_telegraph_zone() -> void:
	if telegraph_zone:
		telegraph_zone.hide_telegraph()
