class_name RunnerEnemy
extends CharacterBody3D

@export var stats: EnemyStats
## H2: scene-placed grunts that must not wake through walls. When set (e.g. "07") the
## distance aggro is skipped and the grunt wakes on SignalBus.zone_entered for the zone
## whose number matches. Wave-spawned grunts leave it empty (distance aggro / spawner).
@export var wake_zone: String = ""

@onready var health_component: HealthComponent = $HealthComponent
@onready var hitbox: Hitbox3D = $Hitbox3D
@onready var mesh_instance: MeshInstance3D = $MeshInstance3D
@onready var character_visual: CharacterVisual = $MeshInstance3D
## R2: clip driver of the rigged body (idle/run, telegraph hold, strike, hit react, death) —
## characters/shared/enemy_animator.gd. Untyped: the global class cache only refreshes on an
## editor scan.
@onready var animator = get_node_or_null("EnemyAnimator")
var combat_comp: Node = null
## U2: the attack footprint on the floor (null until _ready).
const TelegraphZoneScript := preload("res://vfx/telegraph_zone.gd")
var telegraph_zone: Node3D = null

## F2: facing turn rate (per physics tick, same weight as PlayerController.face_direction)
## and the speed below which the grunt faces the player instead of its velocity.
const FACING_TURN_WEIGHT := 0.2
const FACING_MIN_SPEED := 0.1

var player: Node3D
var attack_step: int = 0 # 0 = idle, 1 = telegraph, 2 = active, 3 = recovery
## Dormant until the player enters stats.aggro_range (checked per primary beat) (a
## WaveSpawner only places it; the aggro check wakes it). IntensityController treats
## is_active == false as dormant.
var is_active: bool = false
## H2: origin -> feet distance for the ledge probe.
var _feet_offset: float = 0.0

func _ready() -> void:
	var combat_script = load("res://_core/components/enemy_combat_component.gd")
	if combat_script:
		combat_comp = combat_script.new()
		combat_comp.name = "EnemyCombatComponent"
		add_child(combat_comp)
		combat_comp.connect("stun_started", _on_stun_started)
		if animator:
			combat_comp.connect("stun_started", Callable(animator, "on_stun_started"))

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
	telegraph_zone = TelegraphZoneScript.attach(self, hitbox, TelegraphZoneScript.COLOR_MAGENTA)

	player = get_tree().current_scene.get_node_or_null("Player")
	_feet_offset = EnemyStats.feet_offset_of(self)
	SignalBus.beat.connect(_on_beat)
	if wake_zone != "":
		SignalBus.zone_entered.connect(_on_zone_entered)

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
					# H2: never chase off a ledge. J11: blocked straight ahead -> slide along the
					# edge in depth toward the player's z; hold only when both probes fail.
					var move := EnemyStats.chase_direction(self, dir, _feet_offset, player.global_position.z - global_position.z)
					velocity.x = move.x * stats.speed
					velocity.z = move.z * stats.speed
				else:
					velocity.x = move_toward(velocity.x, 0, 10 * delta)
					velocity.z = move_toward(velocity.z, 0, 10 * delta)
			elif attack_step == 2:
				velocity.x = move_toward(velocity.x, 0, 5 * delta)
				velocity.z = move_toward(velocity.z, 0, 5 * delta)
			else:
				velocity.x = move_toward(velocity.x, 0, 20 * delta)
				velocity.z = move_toward(velocity.z, 0, 20 * delta)

	_update_facing()
	move_and_slide()

func _on_beat(layer: String, beat_index: int) -> void:
	if layer != "primary":
		return
	_update_aggro()
	if not is_active:
		return
	if combat_comp.is_stunned():
		return
	var previous_step := attack_step

	if attack_step == 1:
		attack_step = 2
		hitbox.is_active = true
		_hide_telegraph_zone()
		if player:
			var dir = (player.global_position - global_position).normalized()
			dir.y = 0
			velocity.x = dir.x * stats.speed * 2.5
			velocity.z = dir.z * stats.speed * 2.5
	elif attack_step == 2:
		attack_step = 3
		hitbox.is_active = false
	elif attack_step == 3:
		attack_step = 0
		
	if attack_step == 0 and player:
		var dist = global_position.distance_to(player.global_position)
		if dist <= 2.5:
			attack_step = 1
			# White-hot rim for the telegraph beat; it fades back on its own.
			character_visual.flash_telegraph()
			_show_telegraph_zone()
	if animator and attack_step != previous_step:
		animator.on_attack_step(attack_step)

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
	attack_step = 0
	hitbox.is_active = false
	_hide_telegraph_zone()
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
	_hide_telegraph_zone()
	GameManager.add_scrap(stats.scrap)
	SignalBus.enemy_died.emit(global_position)
	# F3: flash + shrink, then free (scrap/enemy_died above stay immediate). R2: the death
	# clip plays first; CharacterVisual.play_death delays the shrink by its length.
	if animator:
		animator.on_died()
	if combat_comp:
		combat_comp.play_death_and_free(character_visual)
	else:
		queue_free()

## U2: the floor footprint of the attack (vfx/telegraph_zone.gd): shown for the telegraph beat
## (fading in across one beat), hidden when the hitbox arms, on a stun and on death.
func _show_telegraph_zone() -> void:
	if telegraph_zone:
		telegraph_zone.show_telegraph(60.0 / maxf(Conductor.bpm, 1.0))

func _hide_telegraph_zone() -> void:
	if telegraph_zone:
		telegraph_zone.hide_telegraph()
