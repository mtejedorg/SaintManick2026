extends "res://tests/framework/test_case.gd"

## F12: a hit absorbed by a boss state shield is contact, not a whiff — the combo survives
## (without incrementing), a light shake fires, and hit_blocked is emitted for VFX.

func _player_hit(player: PlayerController) -> DamageInfo:
	var dmg := DamageInfo.new()
	dmg.amount = 12.0
	dmg.source = player
	return dmg

func test_shielded_headliner_hit_keeps_the_combo() -> void:
	var player: PlayerController = load("res://characters/player/player.tscn").instantiate()
	add_child(player)
	player.set_physics_process(false)
	var boss: HeadlinerBoss = load("res://characters/enemies/headliner/headliner.tscn").instantiate()
	boss.position = Vector3(0.0, 300.0, 4400.0)
	add_child(boss)
	boss.activate_boss()
	assert_true(boss.is_shield_active, "Precondition: the Headliner shield is up")

	var combo = player.combo_component
	combo.combo_count = 3
	combo.combo_timer = 0.5
	var got := {"blocked": 0, "landed": 0, "shake": Vector2.ZERO}
	var on_blocked := func(_p): got.blocked += 1
	var on_landed := func(_d): got.landed += 1
	var on_shake := func(s, d): got.shake = Vector2(s, d)
	SignalBus.hit_blocked.connect(on_blocked)
	SignalBus.player_hit_landed.connect(on_landed)
	SignalBus.camera_shake_requested.connect(on_shake)

	combo.on_attack_started()
	var meter_before: float = player.ability_meter
	boss.hurtbox.receive_hit(_player_hit(player))
	combo.on_attack_ended()

	SignalBus.hit_blocked.disconnect(on_blocked)
	SignalBus.player_hit_landed.disconnect(on_landed)
	SignalBus.camera_shake_requested.disconnect(on_shake)

	assert_eq(got.blocked, 1, "An absorbed hit emits hit_blocked")
	assert_eq(got.landed, 0, "An absorbed hit is not a landed hit")
	assert_true(got.shake.is_equal_approx(Vector2(0.03, 0.08)), "An absorbed hit gives a light shake (got %s)" % got.shake)
	assert_eq(combo.combo_count, 3, "The combo survives the blocked attack without incrementing")
	assert_almost_eq(combo.combo_timer, combo.combo_timeout, 0.001, "The blocked hit refreshes the combo timer")
	assert_almost_eq(player.ability_meter, meter_before, 0.001, "A blocked hit grants no meter")
	assert_eq(boss.health_component.current_health, boss.health_component.max_health, "A blocked hit deals no damage")
	boss.queue_free()
	player.queue_free()
