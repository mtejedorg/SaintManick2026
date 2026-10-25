class_name ObjectPool
extends Node

@export var template: PackedScene
@export var initial_pool_size: int = 32
@export var allow_growth: bool = true

var inactive_pool: Array[Node] = []

func _ready() -> void:
	if template:
		for i in range(initial_pool_size):
			var obj = template.instantiate()
			add_child(obj)
			release(obj)

func acquire() -> Node:
	var obj: Node = null
	if not inactive_pool.is_empty():
		obj = inactive_pool.pop_back()
	elif allow_growth and template:
		obj = template.instantiate()
		add_child(obj)
	
	if obj:
		# Call on_acquire if the method exists
		if obj.has_method("on_acquire"):
			obj.on_acquire()
		
		# Enable visibility
		if obj is Node3D:
			obj.visible = true
		
		# Enable physics/idle processing
		obj.set_process(true)
		obj.set_physics_process(true)
		
		# Enable monitoring/monitorable for Area3Ds. J13: deferred, like release() -- the two
		# must stay in call order (a release + re-acquire in one frame ends up enabled).
		if obj is Area3D:
			obj.set_deferred("monitoring", true)
			obj.set_deferred("monitorable", true)
			
	return obj

## Returns every live (acquired) object to the pool at once — e.g. clearing in-flight
## bullets when the player respawns so none hit him during the respawn grace.
func release_all() -> void:
	for child in get_children():
		if child.is_queued_for_deletion() or inactive_pool.has(child):
			continue
		release(child)

func release(obj: Node) -> void:
	if not obj:
		return
		
	# Call on_release if the method exists
	if obj.has_method("on_release"):
		obj.on_release()
		
	# Set visibility to false and move to a distant safe coordinate
	if obj is Node3D:
		obj.visible = false
		obj.global_position = Vector3(9999, 9999, 9999)
		
	# Disable processing
	obj.set_process(false)
	obj.set_physics_process(false)
	
	# Disable monitoring/monitorable for Area3Ds. J13: deferred -- release_all() runs from
	# player_respawned, which a lethal Hitbox overlap can raise inside the physics flush.
	if obj is Area3D:
		obj.set_deferred("monitoring", false)
		obj.set_deferred("monitorable", false)
		
	if not inactive_pool.has(obj):
		inactive_pool.append(obj)
