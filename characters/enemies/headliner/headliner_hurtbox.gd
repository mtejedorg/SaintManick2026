class_name HeadlinerHurtbox
extends Hurtbox3D

func receive_hit(damage_info: DamageInfo) -> void:
	if not owner:
		super.receive_hit(damage_info)
		return
		
	# Check if boss has shield active
	if owner.is_shield_active:
		if damage_info.is_shield_breaker:
			# Shield breaks!
			owner.break_shield()
		else:
			hit_received.emit(damage_info)
			return
	else:
		# If the boss is vulnerable, increase damage by 1.5x
		if owner.is_vulnerable:
			var dup_damage = damage_info.duplicate()
			dup_damage.amount *= 1.5
			super.receive_hit(dup_damage)
			return
			
	super.receive_hit(damage_info)
