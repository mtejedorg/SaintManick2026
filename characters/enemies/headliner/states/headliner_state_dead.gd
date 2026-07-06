extends HeadlinerState

func enter() -> void:
	# Disable collisions on the boss
	var collision_shape = boss.get_node_or_null("CollisionShape3D")
	if collision_shape:
		collision_shape.set_deferred("disabled", true)
		
	if boss.hurtbox:
		boss.hurtbox.set_deferred("monitoring", false)
		boss.hurtbox.set_deferred("monitorable", false)
		
	if boss.hitbox:
		boss.hitbox.set_deferred("monitoring", false)
		boss.hitbox.set_deferred("monitorable", false)

	# Play a simple premium-feeling death tween (pulsing/shrinking)
	if boss.mesh_instance:
		var tween = boss.create_tween()
		tween.tween_property(boss.mesh_instance, "scale", Vector3(1.5, 0.1, 1.5), 0.5)
		tween.tween_property(boss.mesh_instance, "scale", Vector3.ZERO, 0.5)

	# Scrap is awarded once by headliner._on_died() — do not award again here.

	# Let the death visuals play, then queue_free
	get_tree().create_timer(1.0).timeout.connect(func():
		if is_instance_valid(boss):
			boss.queue_free()
	)

	# Hold on the victory moment before switching to the results screen.
	get_tree().create_timer(2.5).timeout.connect(func():
		GameManager.complete_run()
	)

func exit() -> void:
	pass
