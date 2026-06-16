extends "res://tests/framework/test_case.gd"

var conductor: Node

func before_each() -> void:
	var cond_script = load("res://_core/conductor.gd")
	conductor = cond_script.new()
	# Disable processing in tree if we add it, but we won't add it. We will manually drive it.
	# We just need to initialize variables
	conductor.bpm = 120.0
	conductor.target_bpm = 120.0
	conductor.bpm_ramp_rate = 20.0
	# Initialize primary layer
	conductor.register_layer("primary", 4)

func after_each() -> void:
	if is_instance_valid(conductor):
		conductor.free()

func test_beat_index_progression_and_wrapping() -> void:
	var beats: Array[int] = []
	var on_beat = func(layer, beat_idx):
		if layer == "primary":
			beats.append(beat_idx)
	
	SignalBus.beat.connect(on_beat)
	
	# At 120 BPM, a beat is 60.0 / 120.0 = 0.5 seconds.
	# Drive 0.25 seconds: accumulator is 0.25, no beat yet.
	conductor._process(0.25)
	assert_eq(beats.size(), 0, "No beat should emit at 0.25s")
	
	# Drive another 0.25 seconds: accumulator is 0.5, triggers beat 1.
	conductor._process(0.25)
	assert_eq(beats.size(), 1, "One beat should emit at 0.5s")
	assert_eq(beats[0], 1, "First beat should be index 1")
	
	# Drive 1.5 seconds: triggers 3 more beats (at 1.0s, 1.5s, 2.0s)
	# total beat_index should go 2, 3, 4. Since beats_per_measure is 4:
	# beat 2 (1.0s), beat 3 (1.5s), beat 4 (2.0s)
	conductor._process(1.5)
	assert_eq(beats.size(), 4, "Total 4 beats should have emitted")
	assert_eq(beats[1], 2)
	assert_eq(beats[2], 3)
	assert_eq(beats[3], 4)
	
	# Drive 0.5 seconds: beat 5 (at 2.5s) wraps to beat 1 in measure 2
	conductor._process(0.5)
	assert_eq(beats.size(), 5)
	assert_eq(beats[4], 1, "Beat index should wrap back to 1 after 4")
	
	SignalBus.beat.disconnect(on_beat)

func test_downbeat_emissions() -> void:
	var downbeats: Array[int] = []
	var on_downbeat = func(layer, measure_idx):
		if layer == "primary":
			downbeats.append(measure_idx)
			
	SignalBus.downbeat.connect(on_downbeat)
	
	# Beat duration is 0.5s.
	# First beat is at 0.5s, which is beat 1 of measure 1 -> downbeat!
	conductor._process(0.5)
	assert_eq(downbeats.size(), 1)
	assert_eq(downbeats[0], 1, "First downbeat should be measure index 1")
	
	# Beats 2, 3, 4 are at 1.0s, 1.5s, 2.0s. No downbeats.
	conductor._process(1.5)
	assert_eq(downbeats.size(), 1, "No new downbeats during measure 1")
	
	# Beat 5 is at 2.5s, which is beat 1 of measure 2 -> downbeat!
	conductor._process(0.5)
	assert_eq(downbeats.size(), 2)
	assert_eq(downbeats[1], 2, "Second downbeat should be measure index 2")
	
	SignalBus.downbeat.disconnect(on_downbeat)

func test_tempo_transition_ramping() -> void:
	# Set target BPM to 140.0. Rate of change is 20.0 BPM per second.
	conductor.target_bpm = 140.0
	
	# Process 0.5 seconds. BPM should change by 20.0 * 0.5 = 10.0, so 130.0.
	conductor._process(0.5)
	assert_almost_eq(conductor.bpm, 130.0, 0.001, "BPM should ramp to 130.0")
	
	# Process another 0.5 seconds. BPM should reach 140.0.
	conductor._process(0.5)
	assert_almost_eq(conductor.bpm, 140.0, 0.001, "BPM should reach target 140.0")
	
	# Process another 0.5 seconds. BPM should remain at 140.0.
	conductor._process(0.5)
	assert_almost_eq(conductor.bpm, 140.0, 0.001, "BPM should remain at target 140.0")
