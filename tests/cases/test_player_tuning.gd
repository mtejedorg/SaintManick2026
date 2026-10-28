extends "res://tests/framework/test_case.gd"

## Q2: Nick's tuning lives in characters/player/player_tuning.tres (PlayerTuning). Every
## other test asserts invariants against it; this file pins it to GDD rev. 3 once.

const TUNING := "res://characters/player/player_tuning.tres"
const PLAYER_SCENE := "res://characters/player/player.tscn"

var _nodes: Array[Node] = []

func after_each() -> void:
	super.after_each()
	for n in _nodes:
		if is_instance_valid(n):
			n.queue_free()
	_nodes.clear()

## GDD rev. 3 (Documents/GDD.md 3.1-3.3, 5): dash 18 m/s, roll 11 m/s, 0.3 s dodge cooldown,
## +-0.06 s beat window refunding half, light 0.3/0.3/0.6 s and heavy 0.45/0.45/0.75 s
## windows, free cancel in the last 40 % of recovery, Bass Drop 90 / 10 m, 0.9 s death beat,
## falls cost 20 HP with a 0.5 s grace.
func test_the_shipped_tuning_matches_gdd_rev_3() -> void:
	var t: PlayerTuning = load(TUNING)
	assert_not_null(t, "player_tuning.tres loads as a PlayerTuning")
	if t == null:
		return
	var expected := {
		"dash_speed": 18.0, "roll_speed": 11.0, "dodge_cooldown": 0.3,
		"beat_align_window": 0.06, "beat_aligned_cooldown_refund": 0.5,
		"free_cancel_recovery_fraction": 0.4, "bass_drop_radius": 10.0, "bass_drop_damage": 90.0,
		"death_beat_seconds": 0.9, "fall_damage": 20.0, "fall_grace": 0.5,
	}
	for key in expected:
		assert_almost_eq(float(t.get(key)), expected[key], 0.0001, "GDD rev. 3: %s = %s (got %s)" % [key, expected[key], t.get(key)])
	assert_eq(t.attack_durations, [0.3, 0.3, 0.6] as Array[float], "GDD rev. 3: light windows 0.3 / 0.3 / 0.6 s")
	assert_eq(t.heavy_attack_durations, [0.45, 0.45, 0.75] as Array[float], "GDD rev. 3 (D3): heavy windows 0.45 / 0.45 / 0.75 s")
	# V13: the fallback const is no longer pinned to the resource -- the resource drives the beat
	# (test_the_death_beat_follows_the_tuning_resource).

func test_the_shipped_tuning_validates() -> void:
	var t: PlayerTuning = load(TUNING)
	assert_true(t.validate(), "The shipped values are all in range")

func test_validate_flags_an_out_of_range_value() -> void:
	var t: PlayerTuning = (load(TUNING) as PlayerTuning).duplicate()
	t.free_cancel_recovery_fraction = 1.5
	assert_false(t.validate(), "A free-cancel share above 1 is rejected (push_error)")

func test_nick_and_his_states_read_the_resource() -> void:
	var player: PlayerController = load(PLAYER_SCENE).instantiate()
	player.position = Vector3(0.0, 400.0, 14000.0)
	add_child(player)
	_nodes.append(player)
	assert_eq(player.tuning, load(TUNING), "Nick ships with player_tuning.tres")
	assert_almost_eq(player.death_beat_seconds(), player.tuning.death_beat_seconds, 0.0001, "death_beat_seconds() reads the resource")
	# A swapped resource changes the behaviour: the states read player.tuning, not a copy.
	var custom: PlayerTuning = player.tuning.duplicate()
	custom.dash_speed = 5.0
	custom.dodge_cooldown = 0.7
	player.tuning = custom
	player.is_facing_right = true
	Conductor.layers["primary"].time_accumulator = (60.0 / Conductor.bpm) * 0.5 # off the beat
	player.state_machine.transition_to("StateDash")
	player.state_machine.current_state.physics_update(1.0 / 60.0)
	assert_almost_eq(player.velocity.x, 5.0, 0.0001, "StateDash moves at tuning.dash_speed")
	player.state_machine.transition_to("StateIdle")
	assert_almost_eq(player._dodge_cooldown_timer, 0.7, 0.0001, "The dodge cooldown comes from the resource")
	var attack: Node = player.state_machine.get_node("StateAttack")
	custom.attack_durations = [0.2, 0.3, 0.6] as Array[float]
	player.pending_attack_heavy = false
	player.state_machine.transition_to("StateAttack")
	assert_almost_eq(attack.attack_timer, 0.2, 0.0001, "StateAttack times generic hits from the resource")
