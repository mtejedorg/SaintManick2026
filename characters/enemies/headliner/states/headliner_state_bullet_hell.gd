extends HeadlinerState

## Phase-2 bullet-hell timeout. When the shield has not been broken after this
## many primary beats (~9 s at the 160 BPM boss tempo) it "overheats" and drops,
## so a player without a shield-breaker (Battery Ram / Bass Drop) is never
## softlocked in the phase.
@export var max_beats: int = 24

var beat_counter: int = 0

## H4: phase cues for the zone-card banner (SignalBus.banner_requested).
const STORM_BANNER := "PROJECTION STORM — SURVIVE"
const STORM_BANNER_HOLD := 2.0
const OVERHEAT_BANNER := "SHIELD DOWN"
const OVERHEAT_BANNER_HOLD := 1.0
## H4: the bubble tints toward this as the overheat timer runs out (beat_counter/max_beats).
const OVERHEAT_TINT := Color(1.0, 1.0, 1.0)

## Per-fight copy of the bubble material (the scene sub-resource stays untouched) and its
## authored colours.
var _bubble_material: StandardMaterial3D = null
var _bubble_albedo: Color
var _bubble_emission: Color

func enter() -> void:
	boss.is_shield_active = true
	if boss.shield_bubble:
		boss.shield_bubble.visible = true
		_prepare_bubble_material()
	boss.velocity = Vector3.ZERO
	beat_counter = 0
	_update_bubble_tint()
	SignalBus.banner_requested.emit(STORM_BANNER, STORM_BANNER_HOLD)

func exit() -> void:
	# J14: the storm ends with the phase (shield broken or overheated) -- no bullet outlives it.
	if boss.pool:
		boss.pool.release_all()
	boss.is_shield_active = false
	if boss.shield_bubble:
		boss.shield_bubble.visible = false
	beat_counter = 0
	_update_bubble_tint() # back to the authored look for the next phase-2 attempt

func _prepare_bubble_material() -> void:
	if _bubble_material:
		return
	var source := boss.shield_bubble.get_active_material(0) as StandardMaterial3D
	if source == null:
		return
	_bubble_material = source.duplicate() as StandardMaterial3D
	_bubble_albedo = source.albedo_color
	_bubble_emission = source.emission
	boss.shield_bubble.set_surface_override_material(0, _bubble_material)

## Fraction of the overheat timer used up (0 on enter, 1 when the shield drops).
func get_overheat_fraction() -> float:
	return clampf(float(beat_counter) / float(maxi(max_beats, 1)), 0.0, 1.0)

func _update_bubble_tint() -> void:
	if _bubble_material == null:
		return
	var t := get_overheat_fraction()
	var albedo := _bubble_albedo.lerp(OVERHEAT_TINT, t)
	albedo.a = _bubble_albedo.a
	_bubble_material.albedo_color = albedo
	_bubble_material.emission = _bubble_emission.lerp(OVERHEAT_TINT, t)

func physics_update(delta: float) -> void:
	boss.apply_gravity(delta)
	boss.velocity.x = 0
	boss.velocity.z = 0
	boss.move_and_slide()

func on_beat(layer: String, beat_index: int) -> void:
	if layer != "primary":
		return
		
	beat_counter += 1
	if beat_counter >= max_beats:
		_overheat_shield()
		return
	_update_bubble_tint()
	
	# Fire beat-driven patterns
	match beat_index:
		1:
			# Radial pattern
			if boss.emitter:
				boss.emitter.fire_radial(12, 6.0, 10.0)
		2:
			# Aimed pattern at player
			if boss.emitter and boss.player:
				boss.emitter.fire_aimed(8.0, 10.0, boss.player.global_position)
		3:
			# Spiral pattern (increment angle offset based on beat_counter)
			if boss.emitter:
				boss.emitter.fire_spiral(8, 6.0, 10.0, float(beat_counter) * 0.2, 0.4)
		4:
			# Aimed pattern
			if boss.emitter and boss.player:
				boss.emitter.fire_aimed(8.0, 10.0, boss.player.global_position)

func on_shield_broken() -> void:
	state_machine.transition_to("StateEnraged")

# Same exit as a shield break — StateEnraged shifts the camera back to side-scroll.
func _overheat_shield() -> void:
	boss.is_shield_active = false
	SignalBus.banner_requested.emit(OVERHEAT_BANNER, OVERHEAT_BANNER_HOLD)
	state_machine.transition_to("StateEnraged")
