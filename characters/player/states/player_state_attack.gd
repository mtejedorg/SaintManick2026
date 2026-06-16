extends PlayerState

var attack_timer: float = 0.0
var combo_step: int = 0
var max_combo_step: int = 2
var attack_durations: Array[float] = [0.3, 0.3, 0.6]

func enter() -> void:
	combo_step = 0
	if player.combo_component:
		player.combo_component.on_attack_started()
	var is_heavy = Input.is_action_just_pressed("attack_heavy")
	_start_attack(is_heavy)

func _start_attack(is_heavy: bool) -> void:
	attack_timer = attack_durations[combo_step]
	player.velocity.x = 0 # Stop movement during attack for heavy feel
	player.velocity.z = 0
	
	if not player.katana_hitbox.damage_info:
		player.katana_hitbox.damage_info = DamageInfo.new()
	player.katana_hitbox.damage_info.amount = 28.0 if is_heavy else 12.0
	player.katana_hitbox.damage_info.is_shield_breaker = is_heavy
	player.katana_hitbox.damage_info.source = player
	player.katana_hitbox.damage_info.knockback = 8.0 if is_heavy else 4.0
	player.katana_hitbox.damage_info.stun = 0.4 if is_heavy else 0.25
	player.katana_hitbox.damage_info.is_launcher = is_heavy or combo_step == 2
	
	player.katana_hitbox.is_active = true

func exit() -> void:
	player.katana_hitbox.is_active = false
	if player.combo_component:
		player.combo_component.on_attack_ended()


func physics_update(delta: float) -> void:
	player.apply_gravity(delta)
	player.move_and_slide()
	
	attack_timer -= delta
	
	if Input.is_action_just_pressed("attack_light") or Input.is_action_just_pressed("attack_heavy"):
		if combo_step < max_combo_step and attack_timer < 0.15: # combo window
			combo_step += 1
			var is_heavy = Input.is_action_just_pressed("attack_heavy")
			_start_attack(is_heavy)
			return
			
	if attack_timer <= 0:
		player.katana_hitbox.is_active = false
		if not player.is_on_floor():
			transition_requested.emit("StateAirborne")
		else:
			transition_requested.emit("StateIdle")
