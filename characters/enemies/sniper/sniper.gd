class_name SniperEnemy
extends CharacterBody3D

@export var stats: EnemyStats

@onready var health_component: HealthComponent = $HealthComponent
@onready var laser_beam: MeshInstance3D = $LaserBeam
@onready var laser_hitbox: Hitbox3D = $LaserHitbox
@onready var character_visual: CharacterVisual = $MeshInstance3D
var combat_comp: Node = null

## Beam widths in metres per phase (BoxMesh_laser is 1 x 1 x 30, so scale.xy == width).
const AIM_BEAM_SCALE := Vector3(0.15, 0.15, 1.0)    # beat 3: aiming, still tracking
const LOCK_BEAM_SCALE := Vector3(0.3, 0.3, 1.0)     # beat 4: locked + white-hot telegraph
const FIRE_BEAM_SCALE := Vector3(0.6, 0.6, 1.0)     # beat 1: live
## I4: the LaserHitbox BoxShape3D_laser in sniper.tscn is FIRE_BEAM_SCALE wide (0.6 m) --
## what Nick sees on the live beat is exactly what hits him (test_batch_i).
const BEAM_COLOR := Color(1.0, 0.0, 0.0)
const BEAM_ENERGY := 3.0
## J1: the beam pivots about this local muzzle point; LaserBeam/LaserHitbox sit
## BEAM_HALF_LENGTH ahead of it (sniper.tscn: both at (0, 0.5, -15), BoxMesh 30 m long).
const MUZZLE := Vector3(0.0, 0.5, 0.0)
const BEAM_HALF_LENGTH := 15.0

var player: Node3D
var laser_material: StandardMaterial3D
var is_aim_locked: bool = false
## True between the aim beat and the end of the shot. A cycle only arms while the player
## is within stats.attack_range, so an out-of-range sniper never paints or fires.
var is_cycle_armed: bool = false
## Dormant until the player enters stats.aggro_range (checked per primary beat) or a
## WaveSpawner activates it. IntensityController treats is_active == false as dormant.
var is_active: bool = false
## J1: beam pitch in radians (negative = aiming down). The body only ever yaws; the beam and
## its hitbox pitch toward Nick's hurtbox centre so catwalk snipers (Zone 4, ~4.5 m up) no
## longer fire a horizontal beam over his head.
var aim_pitch: float = 0.0

func _ready() -> void:
	var combat_script = load("res://_core/components/enemy_combat_component.gd")
	if combat_script:
		combat_comp = combat_script.new()
		combat_comp.name = "EnemyCombatComponent"
		add_child(combat_comp)

	if not stats:
		stats = load("res://characters/enemies/sniper/sniper_stats.tres")
		
	health_component.max_health = stats.max_health
	health_component.current_health = stats.max_health
	health_component.health_changed.connect(_on_health_changed)
	health_component.died.connect(_on_died)
	
	laser_hitbox.damage_info = DamageInfo.new()
	laser_hitbox.damage_info.amount = stats.damage
	laser_hitbox.damage_info.knockback = stats.knockback
	laser_hitbox.damage_info.stun = stats.stun
	laser_hitbox.damage_info.source = self
	laser_hitbox.is_active = false
	
	laser_hitbox.collision_layer = 8192 # Layer 14
	laser_hitbox.collision_mask = 1024 # Layer 11
	
	laser_beam.visible = false
	
	# Laser: unshaded red. Unshaded drops EMISSION in Godot 4, so the energy is carried by
	# an HDR albedo (x BEAM_ENERGY) — that is what the bloom picks up.
	laser_material = StandardMaterial3D.new()
	laser_material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	laser_material.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	laser_material.albedo_color = _beam_color(0.5)
	laser_beam.set_surface_override_material(0, laser_material)

	player = get_tree().current_scene.get_node_or_null("Player")
	SignalBus.beat.connect(_on_beat)

func _physics_process(delta: float) -> void:
	if _check_kill_plane():
		return
	if not is_on_floor():
		velocity += get_gravity() * delta
	if not combat_comp.is_stunned() and is_active:
		if player and not is_aim_locked:
			update_aim()
	move_and_slide()

## J1: yaw the body toward Nick (flattened, as before) and pitch the beam + hitbox at his
## hurtbox centre. Floor-level snipers (Zone 6) get ~0 pitch -- unchanged behaviour.
func update_aim() -> void:
	if not player or not is_instance_valid(player):
		return
	var target := _aim_point()
	var flat := Vector3(target.x, global_position.y, target.z)
	if global_position.distance_to(flat) > 0.1:
		look_at(flat, Vector3.UP)
	var to_target := target - global_transform * MUZZLE
	var horizontal := Vector2(to_target.x, to_target.z).length()
	if horizontal > 0.1:
		aim_pitch = atan2(to_target.y, horizontal)
	_apply_beam_pitch()

## Nick's hurtbox centre (his origin is the capsule centre; the Hurtbox3D child wins if present).
func _aim_point() -> Vector3:
	var hurtbox := player.get_node_or_null("Hurtbox3D") as Node3D
	return hurtbox.global_position if hurtbox else player.global_position

## Rotation/position only: the per-beat beam scale (AIM/LOCK/FIRE) is left untouched.
func _apply_beam_pitch() -> void:
	var pitch_basis := Basis(Vector3.RIGHT, aim_pitch)
	var beam_pos := MUZZLE + pitch_basis * Vector3(0.0, 0.0, -BEAM_HALF_LENGTH)
	for node: Node3D in [laser_beam, laser_hitbox]:
		node.rotation = Vector3(aim_pitch, 0.0, 0.0)
		node.position = beam_pos

func _on_beat(layer: String, beat_index: int) -> void:
	if layer != "primary":
		return
	_update_aggro()
	if not is_active:
		return
	if combat_comp.is_stunned():
		_end_cycle()
		return

	match beat_index:
		3:
			if not _player_in_attack_range():
				_end_cycle()
				return
			is_cycle_armed = true
			is_aim_locked = false
			laser_beam.visible = true
			laser_beam.scale = AIM_BEAM_SCALE
			laser_material.albedo_color = _beam_color(0.3)
		4:
			if not is_cycle_armed:
				return
			is_aim_locked = true
			# Lock = one beat before the shot: the shared white-hot telegraph.
			character_visual.flash_telegraph()
			laser_beam.scale = LOCK_BEAM_SCALE
			laser_material.albedo_color = _beam_color(0.6)
		1:
			if not is_cycle_armed:
				return
			laser_beam.visible = true
			laser_beam.scale = FIRE_BEAM_SCALE
			laser_material.albedo_color = _beam_color(1.0)
			laser_hitbox.is_active = true
		2:
			_end_cycle()

func _end_cycle() -> void:
	is_cycle_armed = false
	is_aim_locked = false
	laser_beam.visible = false
	laser_hitbox.is_active = false

func _player_in_attack_range() -> bool:
	if not player or not is_instance_valid(player):
		return false
	if stats.attack_range <= 0.0:
		return true
	return global_position.distance_to(player.global_position) <= stats.attack_range

func _beam_color(alpha: float) -> Color:
	var c := BEAM_COLOR * BEAM_ENERGY
	c.a = alpha
	return c

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
	_end_cycle()
	SignalBus.enemy_died.emit(global_position)
	# F3: flash + shrink, then free (scrap/enemy_died above stay immediate).
	if combat_comp:
		combat_comp.play_death_and_free(character_visual)
	else:
		queue_free()
