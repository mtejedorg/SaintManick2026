class_name ProjectileEmitter
extends Node3D

@export var pool: ObjectPool

func fire_radial(count: int, speed: float, damage: float, offset: float = 0.0) -> void:
	if not pool:
		return
	for i in range(count):
		# Half-step offset so no bullet sits exactly on the boss->player axis at offset 0.
		var angle = offset + PI / count + (i * 2.0 * PI / count)
		var dir = Vector3(cos(angle), 0, sin(angle)).normalized()
		_spawn_projectile(dir, speed, damage)

func fire_aimed(speed: float, damage: float, target: Vector3) -> void:
	if not pool:
		return
	var dir = (target - global_position).normalized()
	dir.y = 0
	dir = dir.normalized()
	_spawn_projectile(dir, speed, damage)

func fire_spiral(count: int, speed: float, damage: float, start_angle: float, step: float) -> void:
	if not pool:
		return
	for i in range(count):
		var angle = start_angle + (i * step)
		var dir = Vector3(cos(angle), 0, sin(angle)).normalized()
		_spawn_projectile(dir, speed, damage)

func _spawn_projectile(dir: Vector3, speed: float, damage: float) -> void:
	var proj = pool.acquire()
	if proj:
		proj.global_position = global_position
		if proj is PooledProjectile:
			proj.configure(dir, speed, damage) # J7: after acquire, so this shot carries `damage`
			# Make sure it knows its source is the boss/emitter owner
			if proj.hitbox and proj.hitbox.damage_info:
				proj.hitbox.damage_info.source = owner if owner else self
