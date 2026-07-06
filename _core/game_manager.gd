extends Node

signal scrap_changed(new_amount: int)
signal cells_changed(new_amount: int)
signal cores_changed(new_amount: int)
signal lives_changed(new_amount: int)

# Permanent stats cache (loaded from profile upgrades)
var max_hp: float = 120.0
var max_shield: float = 40.0
var max_lives: int = 3

# Volatile run state
var scrap: int = 0
## Rare Scrap (GDD §5.1 "cells" in code) — Enforcer kill, Zone 8 escape completion,
## Zone 9 elevator clear.
var cells: int = 0
## Data Cores (GDD §5.1 "cores" in code) — district boss kill (Headliner in the slice).
var cores: int = 0
var current_lives: int = 3
var current_hp: float = 120.0
var current_shield: float = 40.0

# Run booster modifiers — reset each run in start_new_run()
var run_speed_multiplier: float = 1.0
var scrap_multiplier: int = 1
var enemies_defeated: int = 0
var zones_cleared: int = 0
# Zone names already counted this run — a death reload re-enters earlier zones
# and must not count them twice.
var _zones_seen: Dictionary = {}

var is_test: bool = false

func _ready() -> void:
	if not is_test:
		start_new_run()
	SignalBus.enemy_died.connect(_on_enemy_died)
	SignalBus.zone_entered.connect(_on_zone_entered)

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
	cells = 0
	cores = 0
	current_lives = max_lives
	current_hp = max_hp
	current_shield = max_shield

	# Reset booster modifiers before applying new ones
	run_speed_multiplier = 1.0
	scrap_multiplier = 1
	enemies_defeated = 0
	zones_cleared = 0
	_zones_seen.clear()

	# Apply equipped run booster
	if SaveManager and SaveManager.profile:
		match SaveManager.profile.equipped_run_booster:
			"Tempo Shield":
				# Shield starts full — already set above; signal the player after scene is ready
				call_deferred("_apply_tempo_shield")
			"Adrenaline":
				run_speed_multiplier = 1.2
			"Scrap Magnet":
				scrap_multiplier = 2

	scrap_changed.emit(scrap)
	cells_changed.emit(cells)
	cores_changed.emit(cores)
	lives_changed.emit(current_lives)

func _apply_tempo_shield() -> void:
	# Restore full shield on the player's HealthComponent if one exists in the tree.
	var player = get_tree().current_scene.get_node_or_null("Player") if get_tree().current_scene else null
	if player and player.has_node("HealthComponent"):
		var hc: HealthComponent = player.get_node("HealthComponent")
		hc.current_shield = hc.max_shield
		hc.shield_changed.emit(hc.current_shield, hc.max_shield)
		if hc.is_player:
			SignalBus.player_shield_changed.emit(hc.current_shield, hc.max_shield)

func add_scrap(amount: int) -> void:
	scrap += amount * scrap_multiplier
	scrap_changed.emit(scrap)

func add_cells(amount: int) -> void:
	cells += amount
	cells_changed.emit(cells)

func add_cores(amount: int) -> void:
	cores += amount
	cores_changed.emit(cores)

func spend_scrap(amount: int) -> bool:
	if SaveManager and SaveManager.profile:
		if SaveManager.profile.scrap >= amount:
			SaveManager.profile.scrap -= amount
			SaveManager.save_profile()
			return true
	return false

func respawn_or_game_over() -> void:
	if current_lives > 0:
		current_lives -= 1
		# Reset volatile HP/shield for the reload
		current_hp = max_hp
		current_shield = max_shield
		if current_lives > 0:
			lives_changed.emit(current_lives)
			SignalBus.player_life_lost.emit(current_lives)
			if not is_test:
				get_tree().reload_current_scene()
			return

	# No lives left – game over (single emission for the terminal state)
	current_lives = 0
	lives_changed.emit(current_lives)
	SignalBus.player_life_lost.emit(current_lives)

	# Transfer run currencies to persistent profile
	if SaveManager and SaveManager.profile:
		SaveManager.profile.scrap += scrap
		SaveManager.profile.cells += cells
		SaveManager.profile.cores += cores
		SaveManager.save_profile()

	if not is_test:
		get_tree().change_scene_to_file("res://ui/menus/game_over_screen.tscn")

func complete_run() -> void:
	if SaveManager and SaveManager.profile:
		SaveManager.profile.scrap += scrap
		SaveManager.profile.cells += cells
		SaveManager.profile.cores += cores
		SaveManager.save_profile()

	if not is_test:
		get_tree().change_scene_to_file("res://ui/menus/run_results_screen.tscn")

func _on_enemy_died(_position: Vector3) -> void:
	enemies_defeated += 1

func _on_zone_entered(zone_name: String) -> void:
	if _zones_seen.has(zone_name):
		return
	_zones_seen[zone_name] = true
	zones_cleared += 1

