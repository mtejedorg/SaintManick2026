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

## GDD §5.3 "Overshield": Tempo Shield raises max shield by 50% for the run.
const TEMPO_SHIELD_MULTIPLIER: float = 1.5
## GDD §5.3 Adrenaline: run-wide movement speed multiplier.
const ADRENALINE_SPEED_MULTIPLIER: float = 1.2
## GDD §5.3 Scrap Magnet: scrap pickup multiplier.
const SCRAP_MAGNET_MULTIPLIER: int = 2

# Run booster modifiers — reset each run in start_new_run()
var run_speed_multiplier: float = 1.0
var scrap_multiplier: int = 1
var enemies_defeated: int = 0
var zones_cleared: int = 0
# Zone names already counted this run — a checkpoint respawn re-enters earlier zones
# and must not count them twice.
var _zones_seen: Dictionary = {}

# T3: checkpoint respawn. Losing a life teleports Nick back to the last zone entry
# instead of reloading the whole slice (which respawned every enemy and let re-kills
# re-drop scrap — death was economically rewarded).
var checkpoint_zone: String = ""
var checkpoint_position: Vector3 = Vector3.ZERO
var has_checkpoint: bool = false
## Camera/movement mode at the checkpoint: the rail Nick was locked to (null = free
## top-down movement) and whether the camera was top-down. Restored on respawn so a death
## in a top-down fight doesn't leave a side-scroll checkpoint with the camera top-down.
var checkpoint_path: Path3D = null
var checkpoint_top_down: bool = false
## Seconds of post-respawn invincibility grace so Nick isn't hit on the exact frame
## he reappears.
var respawn_grace_duration: float = 1.0

var is_test: bool = false

## Set once the run has terminated (full clear, game over or abandon) so a second
## terminal event in the same run can't bank currencies twice — e.g. a last-life death
## inside the Headliner's victory hold. Cleared by start_new_run().
var run_ended: bool = false

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

	# Reset booster modifiers, then apply every distinct equipped run booster on top of
	# the profile upgrades (before the volatile pools are filled from the maxima).
	run_speed_multiplier = 1.0
	scrap_multiplier = 1
	if SaveManager and SaveManager.profile:
		for booster in SaveManager.profile.get_active_run_boosters():
			match booster:
				"Tempo Shield":
					max_shield = round(max_shield * TEMPO_SHIELD_MULTIPLIER)
				"Adrenaline":
					run_speed_multiplier = ADRENALINE_SPEED_MULTIPLIER
				"Scrap Magnet":
					scrap_multiplier = SCRAP_MAGNET_MULTIPLIER

	scrap = 0
	cells = 0
	cores = 0
	current_lives = max_lives
	current_hp = max_hp
	current_shield = max_shield

	enemies_defeated = 0
	zones_cleared = 0
	_zones_seen.clear()
	run_ended = false

	# A new run starts from the slice's own first zone — never a previous run's checkpoint.
	has_checkpoint = false
	checkpoint_zone = ""
	checkpoint_position = Vector3.ZERO
	checkpoint_path = null
	checkpoint_top_down = false

	scrap_changed.emit(scrap)
	cells_changed.emit(cells)
	cores_changed.emit(cores)
	lives_changed.emit(current_lives)
	SignalBus.run_started.emit()

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
		# Refill volatile HP/shield for the respawn
		current_hp = max_hp
		current_shield = max_shield
		if current_lives > 0:
			lives_changed.emit(current_lives)
			SignalBus.player_life_lost.emit(current_lives)
			# T3: checkpoint respawn instead of a full scene reload. Cleared encounters
			# stay cleared (dead enemies never respawn — no death-farming); uncleared
			# fights and activated bosses reset via player_respawned listeners.
			_respawn_at_checkpoint()
			SignalBus.player_respawned.emit()
			return

	# No lives left – game over (single emission for the terminal state)
	if run_ended:
		return
	run_ended = true
	current_lives = 0
	lives_changed.emit(current_lives)
	SignalBus.player_life_lost.emit(current_lives)

	# Transfer run currencies to persistent profile
	_bank_run_currencies()

	if not is_test:
		_change_scene("res://ui/menus/game_over_screen.tscn")

func complete_run() -> void:
	if run_ended:
		return
	run_ended = true
	_bank_run_currencies()

	if not is_test:
		_change_scene("res://ui/menus/run_results_screen.tscn")

## Every GameManager scene change unpauses first: a pause opened during a hold (e.g. the
## boss victory timer) must not leak `paused = true` into the next screen.
func _change_scene(path: String) -> void:
	get_tree().paused = false
	get_tree().change_scene_to_file(path)

## Pause menu "ABANDON RUN": banks the run's scrap/cells/cores exactly like a game
## over, then clears the volatile run currencies. Does NOT change scene — the caller does.
func abandon_run() -> void:
	if run_ended:
		return
	run_ended = true
	_bank_run_currencies()
	scrap = 0
	cells = 0
	cores = 0
	scrap_changed.emit(scrap)
	cells_changed.emit(cells)
	cores_changed.emit(cores)

## Transfers the run's currencies into the persistent profile and saves. Shared by
## game over, full clear and abandon.
func _bank_run_currencies() -> void:
	if SaveManager and SaveManager.profile:
		SaveManager.profile.scrap += scrap
		SaveManager.profile.cells += cells
		SaveManager.profile.cores += cores
		SaveManager.save_profile()

## Null-safe player lookup — tests run with a dummy current_scene that has no Player,
## so every caller must tolerate null.
func _find_player() -> Node:
	if not get_tree() or not get_tree().current_scene:
		return null
	return get_tree().current_scene.get_node_or_null("Player")

## T3: applies the refilled HP/shield to the live player, teleports him to the last
## checkpoint, and grants a short invincibility grace. No-ops cleanly when no player
## node exists (headless tests).
func _respawn_at_checkpoint() -> void:
	var player = _find_player()
	if not player:
		return
	var hc: HealthComponent = player.get_node_or_null("HealthComponent")
	if hc:
		hc.current_health = current_hp
		hc.current_shield = current_shield
		hc.health_changed.emit(hc.current_health, hc.max_health)
		hc.shield_changed.emit(hc.current_shield, hc.max_shield)
		SignalBus.player_health_changed.emit(hc.current_health, hc.max_health)
		SignalBus.player_shield_changed.emit(hc.current_shield, hc.max_shield)
		# Grace window: timer-based, then off.
		hc.is_invincible = true
		get_tree().create_timer(respawn_grace_duration).timeout.connect(func():
			if is_instance_valid(hc):
				hc.is_invincible = false
		)
	if has_checkpoint:
		player.global_position = checkpoint_position
		_restore_checkpoint_mode(player)
	if "velocity" in player:
		player.velocity = Vector3.ZERO
	if "last_safe_position" in player:
		player.last_safe_position = player.global_position

## Puts the camera FSM and Nick's movement constraint back to what they were at the
## checkpoint — instantly, no tween (the camera snap also kills any in-flight shift so its
## tween can't land later and overwrite the restored rail).
func _restore_checkpoint_mode(player: Node) -> void:
	var cam := _find_drone_camera()
	if cam:
		cam.snap_to_mode(checkpoint_top_down)
	if "current_path" in player:
		player.current_path = checkpoint_path
	if "is_jump_enabled" in player:
		player.is_jump_enabled = not checkpoint_top_down

func _find_drone_camera() -> DroneCamera:
	if not get_tree() or not get_tree().current_scene:
		return null
	var scene := get_tree().current_scene
	var direct := scene.get_node_or_null("DroneCamera") as DroneCamera
	if direct:
		return direct
	for cam in scene.find_children("*", "Camera3D", true, false):
		if cam is DroneCamera:
			return cam
	return null

func _on_enemy_died(_position: Vector3) -> void:
	enemies_defeated += 1

func _on_zone_entered(zone_name: String) -> void:
	# T3: every zone entry is a checkpoint — store where Nick was when he crossed in.
	var player = _find_player()
	if player:
		checkpoint_zone = zone_name
		checkpoint_position = player.global_position
		if "current_path" in player:
			checkpoint_path = player.current_path
			checkpoint_top_down = player.current_path == null
		has_checkpoint = true
	if _zones_seen.has(zone_name):
		return
	_zones_seen[zone_name] = true
	zones_cleared += 1

