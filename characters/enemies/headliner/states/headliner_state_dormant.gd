extends HeadlinerState

func enter() -> void:
	boss.is_active_boss = false
	boss.is_shield_active = false
	if boss.shield_bubble:
		boss.shield_bubble.visible = false

func exit() -> void:
	pass
