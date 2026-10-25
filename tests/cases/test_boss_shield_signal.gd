extends "res://tests/framework/test_case.gd"

# Batch H (UI) U5: the bosses report their on/off shield on SignalBus.boss_shield_changed
# so the HUD can draw a strip on the boss bar, only while the fight is live.

const ENFORCER_SCENE := preload("res://characters/enemies/enforcer/enforcer.tscn")
const HEADLINER_SCENE := preload("res://characters/enemies/headliner/headliner.tscn")
const ZONE_07 := "SECTOR 07 — ENFORCER"

var _emissions: Array = []

func before_each() -> void:
	_emissions.clear()
	SignalBus.boss_shield_changed.connect(_record)

func _record(current: float, max_shield: float) -> void:
	_emissions.append(Vector2(current, max_shield))

func test_enforcer_reports_its_shield_only_once_the_fight_starts() -> void:
	var enforcer: EnforcerEnemy = ENFORCER_SCENE.instantiate()
	enforcer.position = Vector3(0.0, 2.0, 8200.0)
	add_child(enforcer)
	enforcer.set_physics_process(false)
	assert_true(enforcer.is_shield_active, "The Enforcer boots shielded (StateShield)")
	assert_eq(_emissions.size(), 0, "A dormant boss reports nothing")
	SignalBus.zone_entered.emit(ZONE_07)
	assert_eq(_emissions.back(), Vector2(1.0, 1.0), "Fight start reports the raised shield (max, max)")
	enforcer.break_shield()
	assert_false(enforcer.is_shield_active)
	assert_eq(_emissions.back(), Vector2(0.0, 1.0), "Shield break reports (0, max)")
	enforcer.queue_free()

func test_headliner_reports_its_shield_on_activation() -> void:
	var boss: HeadlinerBoss = HEADLINER_SCENE.instantiate()
	boss.position = Vector3(0.0, 2.0, 8220.0)
	add_child(boss)
	boss.set_physics_process(false)
	assert_eq(_emissions.size(), 0, "A dormant Headliner reports nothing")
	boss.activate_boss()
	assert_eq(_emissions.back(), Vector2(1.0, 1.0), "Activation raises and reports the shield")
	boss.break_shield()
	assert_eq(_emissions.back(), Vector2(0.0, 1.0), "Shield break reports (0, max)")
	boss.queue_free()
