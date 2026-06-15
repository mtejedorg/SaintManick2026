extends PlayerState

var attack_timer: float = 0.0
var combo_step: int = 0
var max_combo_step: int = 2
var attack_durations: Array[float] = [0.3, 0.3, 0.6]

func enter() -> void:
	combo_step = 0
	_start_attack()

func _start_attack() -> void:
	attack_timer = attack_durations[combo_step]
	player.velocity.x = 0 # Stop movement during attack for heavy feel
	player.velocity.z = 0
	player.katana_hitbox.is_active = true

func exit() -> void:
	player.katana_hitbox.is_active = false

func physics_update(delta: float) -> void:
	player.apply_gravity(delta)
	player.move_and_slide()
	
	attack_timer -= delta
	
	if Input.is_action_just_pressed("attack_light") or Input.is_action_just_pressed("attack_heavy"):
		if combo_step < max_combo_step and attack_timer < 0.15: # combo window
			combo_step += 1
			_start_attack()
			return
			
	if attack_timer <= 0:
		player.katana_hitbox.is_active = false
		if not player.is_on_floor():
			transition_requested.emit("StateAirborne")
		else:
			transition_requested.emit("StateIdle")
