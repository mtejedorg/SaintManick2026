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

## Batch Q2: the GDD §5.3 Run Booster catalog -- one RunBooster resource per booster (values
## live in the .tres, not here). Catalog order is the shop's cycle order. Preloaded by path
## (RunBoosterRes) so this autoload parses before the editor has registered the class_name.
const RunBoosterRes = preload("res://_core/persistence/run_booster.gd")
const RUN_BOOSTERS: Array[RunBoosterRes] = [
	preload("res://_core/persistence/run_boosters/tempo_shield.tres"),
	preload("res://_core/persistence/run_boosters/adrenaline.tres"),
	preload("res://_core/persistence/run_boosters/scrap_magnet.tres"),
]
## Q7: every GameManager scene change goes through the fade + threaded-load helper.
const SceneTransition = preload("res://ui/transition/scene_transition.gd")

# Run booster modifiers — reset each run in start_new_run()
var run_speed_multiplier: float = 1.0
var scrap_multiplier: int = 1
var enemies_defeated: int = 0
var zones_cleared: int = 0
## Q3: run stats for the results screen, reset by start_new_run(). run_time counts (scaled)
## seconds while the run is live and the tree is not paused; max_combo is the best
## combo_increased value; lives_lost counts player_life_lost emissions.
var run_time: float = 0.0
var max_combo: int = 0
var lives_lost: int = 0
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
## I2: bumped by every grant so an older grace timer cannot end a newer grace early.
var _grace_token: int = 0

## I6: who landed the lethal hit, for the Game Over "DESTROYED BY" line ("" = unknown).
## Set (record_lethal_hit) on the lethal hit itself, before the death beat and before
## player_life_lost fires, so every life-loss listener can read it.
var last_killer: String = ""

## K11 (D20): the death beat between a lethal hit and the respawn / game over -- real time
## (ignores the hit-stop time scale; pauses with the tree). Nick locks his input and holds
## the death clip meanwhile (PlayerController._on_died / StateDead).
const DEATH_BEAT_SECONDS := 0.9
const DEATH_HIT_STOP_DURATION := 0.5
const DEATH_HIT_STOP_SCALE := 0.2
## P9: the zone card names the killer DURING the death beat (time is slowed, the cause is on
## screen), and the respawn card says where the run resumes. Both are priority cards
## (banner_requested). The respawn card is emitted right after player_life_lost, so it
## replaces the HUD's own life-lost card on the same frame.
const RESPAWN_BANNER_HOLD := 1.2
## Bumped per death beat and per new run: a pending beat from an older death or run
## never resolves into this one.
var _death_beat_token: int = 0
## True from the lethal hit until the death beat resolves (or is cancelled).
var death_beat_pending: bool = false

var is_test: bool = false

## Batch O: the public DEMO is the slice without Karen's Shop. A demo run plays with whatever
## the profile already has (upgrades, lives, Double Jump) but never writes back: nothing is
## banked or saved, its booster comes from demo_boosters (the title's demo loadout) instead
## of the profile, and every post-run screen returns to the title. Set by start_new_run().
var demo_mode: bool = false
## The demo loadout's run boosters ("None" is never stored). Read only when demo_mode is on.
var demo_boosters: Array[String] = []
## Q6: onboarding flags a demo run sets in memory only (a demo never saves). They OR with the
## profile's seen_controls / seen_hints for the rest of the session.
var _session_seen_controls: bool = false
var _session_seen_hints: int = 0

const TITLE_SCENE := "res://ui/menus/title_screen.tscn"
const SHOP_SCENE := "res://ui/shop/karens_shop.tscn"

## Set once the run has terminated (full clear, game over or abandon) so a second
## terminal event in the same run can't bank currencies twice — e.g. a last-life death
## inside the Headliner's victory hold. Cleared by start_new_run().
var run_ended: bool = false

func _ready() -> void:
	if not is_test:
		start_new_run()
	SignalBus.enemy_died.connect(_on_enemy_died)
	SignalBus.zone_entered.connect(_on_zone_entered)
	SignalBus.combo_increased.connect(_on_combo_increased)
	SignalBus.player_life_lost.connect(_on_player_life_lost)

## Q3: the run clock. GameManager pauses with the tree, so a paused game never counts.
func _process(delta: float) -> void:
	if is_run_active() and not get_tree().paused:
		run_time += delta

## A run is live from start_new_run() until it ends (full clear, game over, abandon).
func is_run_active() -> bool:
	return not run_ended

func start_new_run(demo: bool = false) -> void:
	demo_mode = demo
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
	for booster_name in run_boosters():
		var booster := find_run_booster(booster_name)
		if booster:
			_apply_run_booster(booster)

	scrap = 0
	cells = 0
	cores = 0
	current_lives = max_lives
	current_hp = max_hp
	current_shield = max_shield

	enemies_defeated = 0
	zones_cleared = 0
	run_time = 0.0
	max_combo = 0
	lives_lost = 0
	last_killer = ""
	_zones_seen.clear()
	run_ended = false
	cancel_death_beat() # K11: a death beat pending from the last run never lands here

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

## The boosters this run applies: the demo loadout's in demo mode (distinct, no "None"),
## otherwise the profile's equipped ones.
func run_boosters() -> Array[String]:
	var result: Array[String] = []
	if demo_mode:
		for booster in demo_boosters:
			if booster != "" and booster != "None" and not result.has(booster):
				result.append(booster)
	elif SaveManager and SaveManager.profile:
		result = SaveManager.profile.get_active_run_boosters()
	return result

## Q2: the catalog entry whose display_name (what the profile stores) or id matches; null for
## "None", "" or an unknown name.
static func find_run_booster(booster_name: String) -> RunBoosterRes:
	for booster in RUN_BOOSTERS:
		if booster.display_name == booster_name or booster.id == booster_name:
			return booster
	return null

func _apply_run_booster(booster: RunBoosterRes) -> void:
	match booster.effect:
		RunBoosterRes.Effect.SHIELD_MULT:
			max_shield = round(max_shield * booster.value)
		RunBoosterRes.Effect.SPEED_MULT:
			run_speed_multiplier = booster.value
		RunBoosterRes.Effect.SCRAP_MULT:
			scrap_multiplier = int(booster.value)

## Q1: combo-tree gating. A demo run plays every route (it has no shop); otherwise the
## profile's purchased routes. The attack state should ask this instead of the profile.
func is_combo_unlocked(seq: String) -> bool:
	if demo_mode:
		return true
	return SaveManager != null and SaveManager.profile != null and SaveManager.profile.unlocked_combos.has(seq)

## Q1: the Double Jump -- always available in a demo run, otherwise the profile's unlock.
func double_jump_available() -> bool:
	if demo_mode:
		return true
	return SaveManager != null and SaveManager.profile != null and SaveManager.profile.double_jump_unlocked

## Q4 accessibility options (PlayerProfile, set in the options menu). The camera shake, the VCR
## overlay and the hit flashes read these getters.
func shake_multiplier() -> float:
	return SaveManager.profile.screen_shake if SaveManager and SaveManager.profile else 1.0

func vcr_enabled() -> bool:
	return SaveManager.profile.vcr_effects if SaveManager and SaveManager.profile else true

func reduce_flashes() -> bool:
	return SaveManager.profile.reduce_flashes if SaveManager and SaveManager.profile else false

## Q6: the HUD hint strip has run its course (profile, or this session for a demo).
func controls_seen() -> bool:
	if _session_seen_controls:
		return true
	return SaveManager != null and SaveManager.profile != null and SaveManager.profile.seen_controls

## Q6: marks the controls as seen. A demo run keeps it in memory only -- nothing is saved.
func mark_controls_seen() -> void:
	if controls_seen():
		return
	if demo_mode or SaveManager == null or SaveManager.profile == null:
		_session_seen_controls = true
		return
	SaveManager.profile.seen_controls = true
	SaveManager.save_profile()

## Q6: one-shot gameplay hints (OnboardingPrompts), a bitmask of `bit`s already shown.
func hint_seen(bit: int) -> bool:
	if (_session_seen_hints & bit) != 0:
		return true
	return SaveManager != null and SaveManager.profile != null and (SaveManager.profile.seen_hints & bit) != 0

func mark_hint_seen(bit: int) -> void:
	if hint_seen(bit):
		return
	if demo_mode or SaveManager == null or SaveManager.profile == null:
		_session_seen_hints |= bit
		return
	SaveManager.profile.seen_hints |= bit
	SaveManager.save_profile()

## Batch O: where every post-run screen (results, game over, pause ABANDON RUN) goes --
## the title after a demo run, Karen's Shop after a full run.
func post_run_scene() -> String:
	return TITLE_SCENE if demo_mode else SHOP_SCENE

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

## K11 (D20): called (deferred) by the player HealthComponent on the lethal hit. A 0.5 s
## slow-motion hit-stop (replacing the hit's own short stop), then death_beat_length() of
## real time later the existing respawn_or_game_over -- the respawn and the final death
## alike (the run_ended guard stays inside respawn_or_game_over). The lethal hit has
## already burst the VCR overlay (player_damaged).
func begin_death_beat() -> void:
	_death_beat_token += 1
	var token := _death_beat_token
	death_beat_pending = true
	var beat_seconds := death_beat_length()
	var hit_stop := get_node_or_null("/root/HitStop")
	if hit_stop:
		hit_stop.start_hit_stop(DEATH_HIT_STOP_DURATION, DEATH_HIT_STOP_SCALE, true)
	SignalBus.banner_requested.emit(death_banner_text(last_killer), beat_seconds)
	get_tree().create_timer(beat_seconds, false, false, true).timeout.connect(func():
		if token == _death_beat_token:
			death_beat_pending = false
			respawn_or_game_over()
	)

## V13: the death beat length -- Nick's PlayerTuning.death_beat_seconds (read through the
## player in the "player" group), DEATH_BEAT_SECONDS when there is no player to ask.
func death_beat_length() -> float:
	var tree := get_tree()
	if tree:
		var player := tree.get_first_node_in_group("player")
		if player and player.has_method("death_beat_seconds"):
			return maxf(float(player.death_beat_seconds()), 0.0)
	return DEATH_BEAT_SECONDS

## P9: the death-beat card ("DESTROYED BY RUNNER"; plain "DESTROYED" for an unknown cause).
static func death_banner_text(killer: String) -> String:
	return "DESTROYED BY %s" % killer if killer != "" else "DESTROYED"

## P9: the respawn card. `lives_left` is the count after the life was spent: > 0 ->
## "LIFE LOST — N LEFT", 0 -> "LAST LIFE"; then " — RESUMING SECTOR NN" for the checkpoint
## zone (omitted when the zone name carries no number).
static func respawn_banner_text(lives_left: int, zone_name: String) -> String:
	var text := "LIFE LOST — %d LEFT" % lives_left if lives_left > 0 else "LAST LIFE"
	for part in zone_name.split(" "):
		var zone := part.to_int()
		if zone > 0:
			text += " — RESUMING SECTOR %02d" % zone
			break
	return text

## Ends a pending death beat now: the respawn or game over lands at once.
func finish_death_beat_now() -> void:
	if not death_beat_pending:
		return
	cancel_death_beat()
	respawn_or_game_over()

## Drops a pending death beat (a new run; tests that kill Nick and move on), ending its
## slow-motion if it is still running.
func cancel_death_beat() -> void:
	_death_beat_token += 1
	if death_beat_pending:
		var hit_stop := get_node_or_null("/root/HitStop")
		if hit_stop:
			hit_stop.start_hit_stop(0.0, 1.0, true) # back to normal speed now
	death_beat_pending = false

## GDD §5: "HP reaching 0 costs a life; permadeath only when HP hits 0 with 0 lives
## remaining." N lives = N respawns — the death that finds current_lives == 0 is game over.
func respawn_or_game_over() -> void:
	if current_lives > 0:
		current_lives -= 1
		# Refill volatile HP/shield for the respawn
		current_hp = max_hp
		current_shield = max_shield
		lives_changed.emit(current_lives)
		SignalBus.player_life_lost.emit(current_lives)
		SignalBus.banner_requested.emit(respawn_banner_text(current_lives, checkpoint_zone), RESPAWN_BANNER_HOLD)
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
	SceneTransition.go(get_tree(), path)

## Pause menu "ABANDON RUN": banks the run's scrap/cells/cores exactly like a game
## over, then clears the volatile run currencies. Does NOT change scene — the caller does.
func abandon_run() -> void:
	if run_ended:
		return
	run_ended = true
	cancel_death_beat() # K11: abandoned mid death beat -- no respawn lands on the title
	_bank_run_currencies()
	scrap = 0
	cells = 0
	cores = 0
	scrap_changed.emit(scrap)
	cells_changed.emit(cells)
	cores_changed.emit(cores)

## Transfers the run's currencies into the persistent profile and saves. Shared by
## game over, full clear and abandon. A demo run banks and saves nothing (batch O); its
## volatile scrap/cells/cores still show on the results screen.
func _bank_run_currencies() -> void:
	if demo_mode:
		return
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
		grant_respawn_grace(hc)
	if has_checkpoint:
		player.global_position = checkpoint_position
		_restore_checkpoint_mode(player)
	if "velocity" in player:
		player.velocity = Vector3.ZERO
	if "last_safe_position" in player:
		player.last_safe_position = player.global_position

## I2: the post-respawn grace window -- its own HealthComponent flag (grace_invincible), so
## a dash/roll exit clearing its i-frames cannot end it early. Timer-based, pauses with the tree.
## J4: `duration` < 0 = respawn_grace_duration (a survivable fall passes its shorter grace).
func grant_respawn_grace(hc: HealthComponent, duration: float = -1.0) -> void:
	hc.grace_invincible = true
	_grace_token += 1
	var token := _grace_token
	var seconds: float = duration if duration >= 0.0 else respawn_grace_duration
	# A weakref, not the node: a lambda capturing a freed HealthComponent errors when called.
	var target: WeakRef = weakref(hc)
	get_tree().create_timer(seconds, false).timeout.connect(func():
		var held := target.get_ref() as HealthComponent
		if token == _grace_token and held:
			held.grace_invincible = false
	)

## I6: stores the display name of the lethal hit's source (see killer_name).
func record_lethal_hit(damage_info: DamageInfo) -> void:
	if damage_info == null or not is_instance_valid(damage_info.source):
		last_killer = ""
		return
	last_killer = killer_name(damage_info.source)

## I6: what the Game Over screen calls whatever killed Nick. A stats resource with a
## display_name wins; then the known enemy/hazard types; then the node name without its
## numbers ("Runner2" -> "RUNNER"). A fall (Nick is his own source) is "THE DROP".
static func killer_name(source: Object) -> String:
	if source == null or not is_instance_valid(source):
		return ""
	if source is PlayerController:
		return "THE DROP"
	var stats: Variant = source.get("stats")
	if stats is Object and "display_name" in stats and str(stats.get("display_name")) != "":
		return str(stats.get("display_name")).to_upper()
	if source is RunnerEnemy:
		return "RUNNER"
	if source is BruiserEnemy:
		return "BRUISER"
	if source is SniperEnemy:
		return "SNIPER"
	if source is EnforcerEnemy:
		return "RHYTHM ENFORCER"
	if source is HeadlinerBoss:
		return "THE HEADLINER"
	if source is ToxicPit:
		return "TOXIC PIT"
	if source is CeilingPiston:
		return "PISTON"
	if source is BombGrid:
		return "BOMB GRID"
	if source is EscapeKillWall:
		return "KILL WALL"
	if source is EscapeDoorHazard:
		return "BLAST DOOR"
	if source is EscapeFallingHazard:
		return "FALLING SIGN"
	if source is Node:
		return bare_node_name(String((source as Node).name))
	return ""

## "Runner2" -> "RUNNER", "RhythmEnforcer_3" -> "RHYTHM ENFORCER".
static func bare_node_name(node_name: String) -> String:
	var digits := RegEx.new()
	digits.compile("[0-9]+")
	var s: String = digits.sub(node_name, "", true)
	var camel := RegEx.new()
	camel.compile("([a-z])([A-Z])")
	s = camel.sub(s, "$1 $2", true)
	return s.replace("_", " ").strip_edges().to_upper()

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

## Stores a checkpoint that is not a zone entry (e.g. the Zone 9 elevator arriving at the
## dock). Leaves checkpoint_zone, _zones_seen and zones_cleared untouched.
func set_checkpoint(position: Vector3, path: Path3D, top_down: bool) -> void:
	checkpoint_position = position
	checkpoint_path = path
	checkpoint_top_down = top_down
	has_checkpoint = true

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

func _on_combo_increased(current_combo: int) -> void:
	max_combo = maxi(max_combo, current_combo)

func _on_player_life_lost(_current_lives: int) -> void:
	lives_lost += 1

func _on_zone_entered(zone_name: String) -> void:
	# T3: every zone entry is a checkpoint — store where Nick was when he crossed in.
	var player = _find_player()
	if player:
		checkpoint_zone = zone_name
		checkpoint_position = player.global_position
		if "current_path" in player:
			# Mid camera shift the rail is only assigned when the tween lands, so the
			# player's current_path is still the OLD mode -- record where the shift is heading.
			var cam := _find_drone_camera()
			if cam and cam.is_shifting():
				var dest: Dictionary = cam.shift_destination()
				checkpoint_top_down = dest.top_down
				checkpoint_path = dest.path
			else:
				checkpoint_path = player.current_path
				checkpoint_top_down = player.current_path == null
		has_checkpoint = true
	if _zones_seen.has(zone_name):
		return
	_zones_seen[zone_name] = true
	zones_cleared += 1

