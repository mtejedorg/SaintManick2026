extends Node

signal scrap_changed(new_amount: int)
signal lives_changed(new_amount: int)

# Permanent stats cache (loaded from profile upgrades)
var max_hp: float = 120.0
var max_shield: float = 40.0
var max_lives: int = 3

# Volatile run state
var scrap: int = 0
var current_lives: int = 3
var current_hp: float = 120.0
var current_shield: float = 40.0

var is_test: bool = false

func _ready() -> void:
	if not is_test:
		start_new_run()

func start_new_run() -> void:
	if SaveManager and SaveManager.profile:
		max_hp = 120.0 + 20.0 * SaveManager.profile.max_hp_upgrades
		max_lives = 3 + SaveManager.profile.max_lives_upgrades
		max_shield = 40.0 + 10.0 * SaveManager.profile.shield_upgrades
	else:
		max_hp = 120.0
		max_lives = 3
		max_shield = 40.0

	scrap = 0
	current_lives = max_lives
	current_hp = max_hp
	current_shield = max_shield

	scrap_changed.emit(scrap)
	lives_changed.emit(current_lives)

func add_scrap(amount: int) -> void:
	scrap += amount
	scrap_changed.emit(scrap)

func spend_scrap(amount: int) -> bool:
	if SaveManager and SaveManager.profile:
		if SaveManager.profile.persistent_scrap >= amount:
			SaveManager.profile.persistent_scrap -= amount
			SaveManager.save_profile()
			return true
	return false

func respawn_or_game_over() -> void:
	if current_lives > 0:
		current_lives -= 1
		# Reset volatile HP/shield for the reload
		current_hp = max_hp
		current_shield = max_shield
		lives_changed.emit(current_lives)
		SignalBus.player_life_lost.emit(current_lives)
		if current_lives > 0:
			if not is_test:
				get_tree().reload_current_scene()
			return

	# No lives left – game over
	current_lives = 0
	lives_changed.emit(current_lives)
	SignalBus.player_life_lost.emit(current_lives)

	# Transfer run scrap to persistent profile
	if SaveManager and SaveManager.profile:
		SaveManager.profile.persistent_scrap += scrap
		SaveManager.save_profile()

	if not is_test:
		get_tree().change_scene_to_file("res://ui/shop/karens_shop.tscn")

func complete_run() -> void:
	if SaveManager and SaveManager.profile:
		SaveManager.profile.persistent_scrap += scrap
		SaveManager.save_profile()
	
	if not is_test:
		get_tree().change_scene_to_file("res://ui/shop/karens_shop.tscn")
