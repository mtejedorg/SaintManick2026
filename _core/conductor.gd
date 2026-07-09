extends Node

# Active meter layers.
# Each layer stores: beats_per_measure, beat_index (total beats), measure_index (total measures), and time_accumulator.
var layers: Dictionary = {
	"primary": {
		"beats_per_measure": 4,
		"beat_index": 0,
		"measure_index": 0,
		"time_accumulator": 0.0
	}
}

@export var bpm: float = 128.0
var target_bpm: float = 128.0
var bpm_ramp_rate: float = 20.0 # BPM change per second

# IntensityController hook stub
var intensity_controller: Node = null

func _ready() -> void:
	target_bpm = bpm

func _process(delta: float) -> void:
	# Smoothly ramp BPM towards target BPM
	if bpm != target_bpm:
		var step = bpm_ramp_rate * delta
		if abs(bpm - target_bpm) <= step:
			bpm = target_bpm
		else:
			bpm += sign(target_bpm - bpm) * step
		SignalBus.tempo_changed.emit(bpm)

	# Update all running meter layers
	for layer_name in layers.keys():
		var layer = layers[layer_name]
		var beat_duration = 60.0 / bpm
		layer.time_accumulator += delta
		
		while layer.time_accumulator >= beat_duration:
			layer.time_accumulator -= beat_duration
			layer.beat_index += 1
			
			# 1-based index (e.g. 1, 2, 3, 4) for musical meter
			var beat_in_measure = ((layer.beat_index - 1) % layer.beats_per_measure) + 1
			
			SignalBus.beat.emit(layer_name, beat_in_measure)
			
			# If this is the downbeat (first beat of the measure), emit downbeat
			if beat_in_measure == 1:
				layer.measure_index += 1
				SignalBus.downbeat.emit(layer_name, layer.measure_index)

## Register or configure a meter layer
func register_layer(layer_name: String, beats_per_measure: int = 4) -> void:
	layers[layer_name] = {
		"beats_per_measure": beats_per_measure,
		"beat_index": 0,
		"measure_index": 0,
		"time_accumulator": 0.0
	}

## Removes a meter layer (e.g. the Headliner's phase-2 polyrhythm once the fight ends).
## No-op if the layer doesn't exist or is "primary" (never remove the world clock).
func unregister_layer(layer_name: String) -> void:
	if layer_name == "primary":
		return
	layers.erase(layer_name)

## Distance in seconds from the current position in `layer_name`'s beat cycle to the
## nearest beat edge (0 or the next beat). Used for reward-only beat-alignment checks
## (e.g. T1 dodge timing) — never for gating, per the "player is never beat-validated" rule.
func seconds_to_nearest_beat(layer_name: String = "primary") -> float:
	if not layers.has(layer_name):
		return INF
	var layer = layers[layer_name]
	var beat_duration = 60.0 / bpm
	var t = layer.time_accumulator
	return min(t, beat_duration - t)
