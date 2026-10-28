extends Node

## F4: emitted whenever a hit sets a stun (> 0). Grunts cancel their attack sequence on it
## (disarm the hitbox, drop the telegraph) so they never lunge without a fresh tell.
signal stun_started()

@export var friction: float = 15.0 # Floor horizontal decay friction
@export var normal_hit_y_pop: float = 3.0
@export var launcher_hit_y_pop: float = 8.0
## Q4: knockback share of a chain opener (DamageInfo.is_chain_opener) -- a flinch, so the
## finisher of the chain still reaches the target.
@export var opener_knockback_scale: float = 0.4
## Q4: horizontal decay (m/s^2) while a hit has the enemy airborne -- the Launcher pops a
## grunt high but carries it ~4 m, not across the arena.
@export var air_friction: float = 18.0

## Hit reaction (F3): a short white-hot rim flash plus a squash on every non-absorbed hit.
const HIT_FLASH_STRENGTH := 5.0
const HIT_FLASH_SECONDS := 0.08
const HIT_PULSE_AMOUNT := 0.06
const HIT_PULSE_SECONDS := 0.06
## Seconds the death tween (CharacterVisual.play_death) plays before the enemy frees.
const DEATH_SECONDS := 0.25

var stun_timer: float = 0.0
## Q4: a hit popped the enemy into the air; cleared when it lands (air_friction applies).
var _in_hit_flight: bool = false
## True once play_death_and_free() ran: the enemy no longer reacts to hits.
var is_dying: bool = false

func _ready() -> void:
	var enemy = get_parent()
	if enemy:
		var hurtbox = enemy.get_node_or_null("Hurtbox3D")
		if not hurtbox:
			for child in enemy.get_children():
				if child is Hurtbox3D:
					hurtbox = child
					break
		if hurtbox:
			hurtbox.hit_received.connect(_on_hit_received)

func _physics_process(delta: float) -> void:
	var enemy = get_parent() as CharacterBody3D
	if not enemy:
		return
		
	if stun_timer > 0.0:
		stun_timer -= delta
		if stun_timer < 0.0:
			stun_timer = 0.0
			
		if enemy.is_on_floor():
			enemy.velocity.x = move_toward(enemy.velocity.x, 0.0, friction * delta)
			enemy.velocity.z = move_toward(enemy.velocity.z, 0.0, friction * delta)

	# Q4: cap the airborne drift of a hit (stunned, or still in the flight a hit started).
	if enemy.is_on_floor():
		_in_hit_flight = false
	elif _in_hit_flight or stun_timer > 0.0:
		var horizontal := Vector2(enemy.velocity.x, enemy.velocity.z)
		horizontal = horizontal.move_toward(Vector2.ZERO, air_friction * delta)
		enemy.velocity.x = horizontal.x
		enemy.velocity.z = horizontal.y

func _on_hit_received(damage_info: DamageInfo) -> void:
	var enemy = get_parent() as CharacterBody3D
	if not enemy or is_dying:
		return

	if enemy.health_component and enemy.health_component.is_invincible:
		return

	# Boss-style state shields (Enforcer/Headliner `is_shield_active`) absorb the hit
	# entirely — no knockback, no stun — unless it breaks the guard/shield. Otherwise
	# mashing the shield would stun-lock the boss state machine (_on_beat skips while stunned).
	if enemy.get("is_shield_active") == true and not (damage_info.is_guard_breaking or damage_info.is_shield_breaker):
		return
		
	var has_shield = enemy.get("health_component") and enemy.health_component.current_shield > 0.0
	if has_shield and not damage_info.is_guard_breaking:
		_flash_hit(enemy)
		return

	# J8/Q5: an environmental tick (toxic pit, kill wall) only flashes -- it must not cancel a
	# running stun or zero the knockback slide. A player hit with no knockback/stun still pops.
	if damage_info.is_environmental:
		_flash_hit(enemy)
		return

	# Calculate knockback direction
	var knockback_dir = Vector3.ZERO
	if damage_info.source:
		knockback_dir = (enemy.global_position - damage_info.source.global_position).normalized()
		knockback_dir.y = 0
		if knockback_dir == Vector3.ZERO:
			knockback_dir = Vector3.RIGHT if randf() > 0.5 else Vector3.LEFT
		else:
			knockback_dir = knockback_dir.normalized()
	else:
		knockback_dir = Vector3.RIGHT
		
	# Apply knockback velocities
	var force: float = damage_info.knockback
	if damage_info.is_chain_opener:
		force *= opener_knockback_scale
	enemy.velocity.x = knockback_dir.x * force
	enemy.velocity.z = knockback_dir.z * force
	
	# Apply vertical pop
	if damage_info.is_launcher:
		enemy.velocity.y = launcher_hit_y_pop
	else:
		enemy.velocity.y = normal_hit_y_pop
	_in_hit_flight = true
		
	# J8: a weaker stun never shortens the running one.
	stun_timer = maxf(stun_timer, damage_info.stun)
	if damage_info.stun > 0.0:
		stun_started.emit()
	# After stun_started: a grunt's handler restores its resting rim, the flash goes on top.
	_flash_hit(enemy)

func is_stunned() -> bool:
	return stun_timer > 0.0

func _flash_hit(enemy: Node) -> void:
	var visual = enemy.get("character_visual")
	if visual == null or not is_instance_valid(visual):
		return
	if visual.has_method("flash_rim"):
		visual.flash_rim(Color.WHITE, HIT_FLASH_STRENGTH, HIT_FLASH_SECONDS)
	if visual.has_method("beat_pulse"):
		visual.beat_pulse(HIT_PULSE_AMOUNT, HIT_PULSE_SECONDS)

## F3: shared enemy death. Disarms every Area3D on the enemy (hitboxes off, hurtboxes no
## longer targetable, AoE group left), stops its AI (physics + Conductor beat handlers),
## plays the visual's death tween and frees the enemy when it ends. Scrap/enemy_died are
## the caller's job and stay immediate; only the queue_free is delayed (the WaveSpawner
## counts tree_exited).
func play_death_and_free(visual: CharacterVisual) -> void:
	var enemy := get_parent() as CharacterBody3D
	if not enemy or is_dying:
		return
	is_dying = true
	stun_timer = 0.0
	enemy.velocity = Vector3.ZERO
	enemy.set_physics_process(false)
	enemy.set_deferred("collision_layer", 0)
	enemy.set_deferred("collision_mask", 0)
	for child in enemy.get_children():
		if child is Area3D:
			if child is Hitbox3D:
				child.is_active = false
			child.set_deferred("monitoring", false)
			child.set_deferred("monitorable", false)
			if child.is_in_group("enemy_hurtbox"):
				child.remove_from_group("enemy_hurtbox")
			for shape in child.get_children():
				if shape is CollisionShape3D:
					shape.set_deferred("disabled", true)
	_disconnect_beats(enemy)
	var tween: Tween = visual.play_death(DEATH_SECONDS) if visual and is_instance_valid(visual) else null
	if tween:
		tween.finished.connect(enemy.queue_free)
	else:
		enemy.queue_free()

## Drops every Conductor beat/downbeat handler owned by the enemy or one of its children, so
## a dying enemy never telegraphs or re-arms a hitbox during its death tween.
func _disconnect_beats(enemy: Node) -> void:
	for sig in ["beat", "downbeat"]:
		for conn in SignalBus.get_signal_connection_list(sig):
			var callable: Callable = conn["callable"]
			var target := callable.get_object() as Node
			if target and (target == enemy or enemy.is_ancestor_of(target)):
				SignalBus.disconnect(sig, callable)
