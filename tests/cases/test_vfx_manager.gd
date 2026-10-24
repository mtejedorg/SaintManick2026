extends "res://tests/framework/test_case.gd"

# G8: SignalBus.hit_blocked (a shielded boss absorbing a hit) had no visual. The VFX
# manager now fires a steel-coloured spark from the same pool as the hit sparks.

func _busy_count(vfx: Node) -> int:
	var n := 0
	for b in vfx._spark_busy:
		if b:
			n += 1
	return n

func test_blocked_and_landed_hits_each_fire_one_pooled_spark() -> void:
	var vfx: Node = load("res://vfx/vfx_manager.gd").new()
	add_child(vfx)

	SignalBus.hit_blocked.emit(Vector3.ZERO)
	assert_eq(_busy_count(vfx), 1, "A blocked hit should fire exactly one spark from the pool")

	SignalBus.hit_landed.emit(Vector3.ZERO, "light")
	assert_eq(_busy_count(vfx), 2, "A landed hit should take a second spark slot")

	vfx.free()
