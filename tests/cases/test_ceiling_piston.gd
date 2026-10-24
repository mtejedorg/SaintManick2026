extends "res://tests/framework/test_case.gd"

# C13: pistons are Conductor-locked (in-measure beat number + downbeat, no local counter),
# stagger by beat_offset, cock back one beat early, and the slammed hitbox really reaches
# the floor/Nick (it used to stop 0.25 m under the platform top).

const PISTON_SCENE := "res://levels/components/ceiling_piston.tscn"

var _piston: CeilingPiston

func before_each() -> void:
	_piston = (load(PISTON_SCENE) as PackedScene).instantiate()
	add_child(_piston)
	_piston.position = Vector3(0.0, 3.5, 0.0)
	# The live Conductor keeps ticking while tests await: cut the piston off from it so only
	# the beats this test injects reach it.
	if SignalBus.beat.is_connected(_piston._on_beat):
		SignalBus.beat.disconnect(_piston._on_beat)
	if SignalBus.downbeat.is_connected(_piston._on_downbeat):
		SignalBus.downbeat.disconnect(_piston._on_downbeat)

func after_each() -> void:
	super.after_each()
	if is_instance_valid(_piston):
		_piston.free()

func test_downbeat_triggers_slam() -> void:
	assert_null(_piston.tween, "Piston idle before the downbeat")
	_piston._on_downbeat("primary", 1)
	assert_not_null(_piston.tween, "A downbeat must trigger slam()")
	assert_true(_piston.tween.is_running(), "The slam tween should be running")

func test_slam_beat_is_not_driven_by_a_local_counter() -> void:
	var flags := {"slams": 0}
	_piston.slammed.connect(func(): flags.slams += 1)
	# Many non-downbeat beats (2, 3, 4) must never slam a beat_offset-0 piston.
	for i in 12:
		_piston._on_beat("primary", 2 + (i % 3))
	assert_eq(flags.slams, 0, "Mid-measure beats never slam an offset-0 piston")
	assert_eq(_piston.get_slam_beats(), [1] as Array[int], "A beat_offset-0 piston slams on the downbeat only")
	_piston._on_downbeat("primary", 1)
	assert_eq(flags.slams, 1, "The downbeat slams it exactly once")

func test_cock_back_happens_on_beat_four_before_the_downbeat() -> void:
	var rest_y := _piston.piston_body.position.y
	_piston._on_beat("primary", 4)
	assert_true(_piston.is_cocked, "Beat 4 is the cock-back beat for a downbeat slam")
	await get_tree().create_timer(_piston.cock_duration + 0.1).timeout
	assert_almost_eq(_piston.piston_body.position.y, rest_y + _piston.cock_distance, 0.02, "Cock-back lifts the body 0.5 m")
	assert_almost_eq(_piston._material.emission_energy_multiplier, _piston.cock_emission_energy, 0.05, "Cock-back drives the emission to x2.5")

func test_beat_offset_staggers_the_slam_beat() -> void:
	_piston.beat_offset = 2
	assert_eq(_piston.get_slam_beats(), [3] as Array[int], "Offset 2 slams on beat 3")
	_piston._on_downbeat("primary", 1)
	assert_null(_piston.tween, "An offset piston ignores the downbeat")
	_piston._on_beat("primary", 2)
	assert_true(_piston.is_cocked, "It cocks on the beat before its slam beat")
	_piston._on_beat("primary", 3)
	assert_false(_piston.is_cocked, "...and slams on its beat (cock released)")
	assert_true(_piston.tween.is_running())

func test_accelerated_piston_slams_on_beats_one_and_three_never_a_three_beat_cycle() -> void:
	_piston.accelerate_pattern = true
	var near := Node3D.new()
	add_child(near)
	near.global_position = _piston.global_position + Vector3(2.0, 0.0, 0.0)
	_piston.player = near
	assert_eq(_piston.get_slam_beats(), [1] as Array[int], "Slow until a measure boundary")
	_piston._on_beat("primary", 2)
	assert_eq(_piston.get_slam_beats(), [1] as Array[int], "Mid-measure the pattern must not change")
	_piston._on_beat("primary", 1) # measure boundary
	assert_eq(_piston.get_slam_beats(), [1, 3] as Array[int], "Near Nick: beats 1 and 3")
	near.global_position = _piston.global_position + Vector3(100.0, 0.0, 0.0)
	_piston._on_beat("primary", 3)
	assert_eq(_piston.get_slam_beats(), [1, 3] as Array[int], "Moving away mid-measure keeps the latched pattern")
	_piston._on_beat("primary", 1)
	assert_eq(_piston.get_slam_beats(), [1] as Array[int], "Back to once per measure at the next boundary")
	near.free()

func test_slammed_hitbox_world_aabb_overlaps_the_floor_to_head_height() -> void:
	_piston._on_downbeat("primary", 1)
	await get_tree().create_timer(_piston.slam_duration + 0.08).timeout
	assert_true(_piston.hitbox.is_active, "Hitbox is live after the impact")
	var shape_node: CollisionShape3D = _piston.hitbox.get_node("CollisionShape3D")
	var half_y := (shape_node.shape as BoxShape3D).size.y * 0.5
	var lo := shape_node.global_position.y - half_y
	var hi := shape_node.global_position.y + half_y
	assert_true(lo <= 1.0 and hi >= 0.0, "Hitbox world y %.2f..%.2f must overlap Nick's hurtbox band 0..1" % [lo, hi])
	assert_almost_eq(lo, 0.0, 0.05, "Body bottom is flush with the floor top (y=0)")
