extends HeadlinerState

## Phase-2 bullet-hell timeout. When the shield has not been broken after this
## many primary beats (~9 s at the 160 BPM boss tempo) it "overheats" and drops,
## so a player without a shield-breaker (Battery Ram / Bass Drop) is never
## softlocked in the phase.
@export var max_beats: int = 24

var beat_counter: int = 0

func enter() -> void:
	boss.is_shield_active = true
	if boss.shield_bubble:
		boss.shield_bubble.visible = true
	boss.velocity = Vector3.ZERO
	beat_counter = 0

func exit() -> void:
	boss.is_shield_active = false
	if boss.shield_bubble:
		boss.shield_bubble.visible = false

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
	state_machine.transition_to("StateEnraged")
