class_name BruiserEnemy
extends CharacterBody3D

## Beat-synced attack step, ported from Runner's attack_step pattern (runner.gd _on_beat)
## but gated to downbeats only, per GDD §4.1: "They only attack on the heavy downbeats."
## 0 = idle/chase, 1 = telegraph (one beat before the downbeat, white-hot rim), 2 = active
## (hitbox live on the downbeat), 3 = recovery (hitbox off, cooling down).
enum AttackStep { IDLE, TELEGRAPH, ACTIVE, RECOVERY }

@export var stats: EnemyStats
## H2: scene-placed grunts that must not wake through walls. When set (e.g. "07") the
## distance aggro is skipped and the grunt wakes on SignalBus.zone_entered for the zone
## whose number matches. Wave-spawned grunts leave it empty (distance aggro / spawner).
@export var wake_zone: String = ""

@onready var health_component: HealthComponent = $HealthComponent
@onready var hitbox: Hitbox3D = $Hitbox3D
@onready var mesh_instance: MeshInstance3D = $MeshInstance3D
@onready var character_visual: CharacterVisual = $MeshInstance3D
var combat_comp: Node = null

## F2: facing turn rate (per physics tick, same weight as PlayerController.face_direction)
## and the speed below which the grunt faces the player instead of its velocity.
const FACING_TURN_WEIGHT := 0.2
const FACING_MIN_SPEED := 0.1

var player: Node3D
var attack_step: int = AttackStep.IDLE
## Dormant until the player enters stats.aggro_range (checked per primary beat) (a
## WaveSpawner only places it; the aggro check wakes it). IntensityController treats
## is_active == false as dormant.
var is_active: bool = false
## Authored visual scale (bruiser.tscn sizes the shared visual to its 2.2 m capsule). The
## beat pulse is relative to this, never to Vector3.ONE.
var _base_scale: Vector3 = Vector3.ONE
## H2: origin -> feet distance for the ledge probe.
var _feet_offset: float = 0.0

func _ready() -> void:
	var combat_script = load("res://_core/components/enemy_combat_component.gd")
	if combat_script:
		combat_comp = combat_script.new()
		combat_comp.name = "EnemyCombatComponent"
		add_child(combat_comp)
		combat_comp.connect("stun_started", _on_stun_started)

	if not stats:
		stats = load("res://characters/enemies/bruiser/bruiser_stats.tres")

	health_component.max_health = stats.max_health
	health_component.current_health = stats.max_health
	health_component.max_shield = stats.shield
	health_component.current_shield = stats.shield
	health_component.health_changed.connect(_on_health_changed)
	health_component.died.connect(_on_died)

	hitbox.damage_info = DamageInfo.new()
	hitbox.damage_info.amount = stats.damage
	hitbox.damage_info.knockback = stats.knockback
	hitbox.damage_info.stun = stats.stun
	hitbox.damage_info.source = self
	# Hitbox-clarity fix (M6b): no more permanent contact damage. It switches on only
	# during the active step, gated by the beat.
	hitbox.is_active = false
	_base_scale = mesh_instance.scale

	player = get_tree().current_scene.get_node_or_null("Player")
	_feet_offset = EnemyStats.feet_offset_of(self)
	SignalBus.beat.connect(_on_beat)
	if wake_zone != "":
		SignalBus.zone_entered.connect(_on_zone_entered)
	SignalBus.downbeat.connect(_on_downbeat)

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
			if attack_step == AttackStep.IDLE:
				var dist = global_position.distance_to(player.global_position)
				if dist > stats.melee_range:
					var dir = (player.global_position - global_position).normalized()
					dir.y = 0
					# H2: never chase off a ledge. J11: blocked straight ahead -> slide along the
					# edge in depth toward the player's z; hold only when both probes fail.
					var move := EnemyStats.chase_direction(self, dir, _feet_offset, player.global_position.z - global_position.z)
					velocity.x = move.x * stats.speed
					velocity.z = move.z * stats.speed
				else:
					velocity.x = move_toward(velocity.x, 0, 20 * delta)
					velocity.z = move_toward(velocity.z, 0, 20 * delta)
			else:
				# Planted for the telegraph/active/recovery sequence — a Bruiser doesn't
				# reposition mid-swing.
				velocity.x = move_toward(velocity.x, 0, 20 * delta)
				velocity.z = move_toward(velocity.z, 0, 20 * delta)

	_update_facing()
	move_and_slide()

func _on_beat(layer: String, beat_index: int) -> void:
	if layer != "primary":
		return
	if combat_comp.is_stunned():
		return

	# Visual scale pulse on every beat.
	var tween = create_tween()
	tween.tween_property(mesh_instance, "scale", _base_scale * 1.1, 0.1).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	tween.tween_property(mesh_instance, "scale", _base_scale, 0.2).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN)

	# Dormant grunts keep the heartbeat pulse but never telegraph.
	_update_aggro()
	if not is_active:
		return

	var layer_data = Conductor.layers.get(layer)
	var bpm_count = layer_data.beats_per_measure if layer_data else 4

	# One beat before the downbeat -> arm the telegraph (skip if already mid-sequence).
	if attack_step == AttackStep.IDLE and beat_index == bpm_count:
		var dist = global_position.distance_to(player.global_position) if player else INF
		if dist <= stats.melee_range * 1.5:
			attack_step = AttackStep.TELEGRAPH
			character_visual.flash_telegraph()
	elif attack_step == AttackStep.ACTIVE:
		# T4: the swing lands ON the downbeat and lasts exactly ONE beat — the very next
		# primary beat (beat 2) switches the hitbox off. This transition used to live in
		# _on_downbeat, which left the hitbox live for a full measure (~1.9s @128), i.e.
		# contact damage with extra steps. (Conductor emits beat before downbeat, so on
		# the downbeat itself this runs while still TELEGRAPH — no same-beat cancel.)
		attack_step = AttackStep.RECOVERY
		hitbox.is_active = false
	elif attack_step == AttackStep.RECOVERY:
		attack_step = AttackStep.IDLE

func _on_downbeat(layer: String, _measure_index: int) -> void:
	if layer != "primary":
		return
	if not is_active:
		return
	if combat_comp.is_stunned():
		return

	if attack_step == AttackStep.TELEGRAPH:
		attack_step = AttackStep.ACTIVE
		hitbox.is_active = true

## F2: the NickProto body faces +Z, so yaw the visual root toward the move direction (or
## toward the player while planted), like PlayerController.face_direction. Dormant and
## stunned grunts keep their current yaw (knockback must not spin them away).
func _update_facing() -> void:
	if not is_active or combat_comp.is_stunned():
		return
	var side := 0.0
	if absf(velocity.x) > FACING_MIN_SPEED:
		side = signf(velocity.x)
	elif player and is_instance_valid(player):
		side = signf(player.global_position.x - global_position.x)
	if side == 0.0:
		return
	mesh_instance.rotation.y = lerp_angle(mesh_instance.rotation.y, side * PI / 2.0, FACING_TURN_WEIGHT)

## F4: a stunning hit cancels the attack sequence — hitbox off, telegraph rim dropped — so
## the grunt needs a fresh tell before it can swing again.
func _on_stun_started() -> void:
	attack_step = AttackStep.IDLE
	hitbox.is_active = false
	character_visual.update_rim_color(character_visual.get_default_rim_color())

## Cheap per-beat aggro check: once the player is within aggro_range the grunt wakes up
## for good.
func _update_aggro() -> void:
	if is_active or wake_zone != "" or not player or not is_instance_valid(player):
		return
	if global_position.distance_to(player.global_position) <= stats.aggro_range:
		is_active = true

## H2: zone-gated wake-up (wake_zone set): only the zone with the matching number wakes it.
func _on_zone_entered(zone_name: String) -> void:
	if is_active or wake_zone == "":
		return
	if EnemyStats.zone_number(zone_name) == wake_zone.to_int():
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
	# F3: flash + shrink, then free (scrap/enemy_died above stay immediate).
	if combat_comp:
		combat_comp.play_death_and_free(character_visual)
	else:
		queue_free()
