extends Node
## AudioManager — Autoload
## Centralized audio playback. All paths are virtual (res://audio/...).
## Files don't need to exist yet — every load gracefully no-ops if missing.
##
## Public API:
##   AudioManager.play_sfx("hit_light")
##   AudioManager.play_music("zone_industrial")
##   AudioManager.play_ambience("industrial_hum")
##   AudioManager.stop_music()
##   AudioManager.stop_ambience()
##   AudioManager.set_music_volume(db: float)

const SFX_PATH     := "res://audio/sfx/"
const MUSIC_PATH   := "res://audio/music/"
const AMBIENCE_PATH := "res://audio/ambience/"

# These nodes are added to vertical_slice.tscn.
# AudioManager finds them at runtime via the SceneTree.
var _sfx_player: AudioStreamPlayer = null
var _music_player: AudioStreamPlayer = null
var _ambience_player: AudioStreamPlayer = null

# Polyphonic SFX pool — avoids cutting off overlapping hit sounds.
var _sfx_pool: Array[AudioStreamPlayer] = []
const SFX_POOL_SIZE := 8

# Boss scene players — registered by the boss scene on _ready().
# BossMusicA (phase 1) and BossMusicB (phase 2, starts silent) run in sync
# so the phase crossfade is always beat-accurate.
var _boss_music_a: AudioStreamPlayer = null
var _boss_music_b: AudioStreamPlayer = null
# True only while the Headliner fight's music is running; the Enforcer miniboss
# also emits boss_spawned/boss_died but must not start or stop boss music.
var _boss_music_active: bool = false

# Currently playing music clip — lets zone re-entries within the same tier
# (e.g. Zones 1→2→3→4 all industrial) skip restarting the track from the top.
var _current_music: String = ""

func _ready() -> void:
	_build_sfx_pool()
	_connect_signals()

# ---------------------------------------------------------------------------
# Public API
# ---------------------------------------------------------------------------

func play_sfx(clip_name: String) -> void:
	var stream := _load_stream(SFX_PATH + clip_name + ".ogg")
	if stream == null:
		return
	var player := _get_free_sfx_player()
	if player == null:
		return
	player.stream = stream
	player.play()


func play_music(clip_name: String) -> void:
	if clip_name == _current_music and _music_player and _music_player.playing:
		return
	var stream := _load_stream(MUSIC_PATH + clip_name + ".ogg")
	if stream == null:
		return
	_ensure_players()
	if _music_player == null:
		return
	_music_player.stream = stream
	_music_player.play()
	_current_music = clip_name


func stop_music() -> void:
	if _music_player and _music_player.playing:
		_music_player.stop()
	_current_music = ""


func play_ambience(clip_name: String) -> void:
	var stream := _load_stream(AMBIENCE_PATH + clip_name + ".ogg")
	if stream == null:
		return
	_ensure_players()
	if _ambience_player == null:
		return
	_ambience_player.stream = stream
	_ambience_player.play()


func stop_ambience() -> void:
	if _ambience_player and _ambience_player.playing:
		_ambience_player.stop()


func set_music_volume(db: float) -> void:
	if _music_player:
		_music_player.volume_db = db


func set_ambience_volume(db: float) -> void:
	if _ambience_player:
		_ambience_player.volume_db = db

# ---------------------------------------------------------------------------
# Signal connections — triggered by SignalBus
# ---------------------------------------------------------------------------

func _connect_signals() -> void:
	# Combat feedback
	SignalBus.player_hit_landed.connect(_on_player_hit_landed)
	SignalBus.player_died.connect(_on_player_died)
	SignalBus.player_respawned.connect(_on_player_respawned)
	SignalBus.combo_increased.connect(_on_combo_increased)
	SignalBus.shield_broken.connect(_on_shield_broken)

	# Zone transitions
	SignalBus.zone_entered.connect(_on_zone_entered)

	# Boss events
	SignalBus.boss_spawned.connect(_on_boss_spawned)
	SignalBus.boss_health_changed.connect(_on_boss_health_changed)
	SignalBus.boss_died.connect(_on_boss_died)
	SignalBus.boss_reset.connect(_on_boss_reset)

	# Run lifecycle
	SignalBus.run_started.connect(_on_run_started)


func _on_player_hit_landed(damage_info: DamageInfo) -> void:
	if damage_info.amount >= DamageInfo.HEAVY_THRESHOLD:
		play_sfx("hit_heavy")
	else:
		play_sfx("hit_light")


## F5: HealthComponent emits player_died on EVERY life lost, before the checkpoint
## respawn — the music only stops when the death is terminal (game over).
func _on_player_died() -> void:
	var gm := get_node_or_null("/root/GameManager")
	if gm == null or should_stop_music_on_death(gm.current_lives):
		stop_music()
	play_sfx("death_nick")

## True when a death with `lives_remaining` lives left ends the run (GameManager: the
## death that finds current_lives == 0 is game over; any other death respawns).
static func should_stop_music_on_death(lives_remaining: int) -> bool:
	return lives_remaining <= 0

## F5: back at the checkpoint — make sure its zone track is playing (play_music skips a
## track that is already running, so a surviving zone track is not restarted).
func _on_player_respawned() -> void:
	var gm := get_node_or_null("/root/GameManager")
	if gm == null:
		return
	var clip := music_for_tier(tier_for_zone(gm.checkpoint_zone))
	if clip != "":
		play_music(clip)


func _on_combo_increased(_current_combo: int) -> void:
	play_sfx("combo_tick")

## P7: any HealthComponent shield knocked to 0 (no-ops if the clip is missing).
func _on_shield_broken(_position: Vector3) -> void:
	play_sfx("shield_break")


## Maps a zone name to its audio tier, following the slice's Factory→Neon arc
## (Documents/VerticalSlice.md):
##   Zones 1–4  → "industrial" (Factory)
##   Zones 5–7  → "neon"       (Neon district streets)
##   Zones 8–9  → "highrise"   (Neon high-rise ascent — Zone 9 elevator climbs the
##                              skyscraper exterior; reuses the zone_corporate clips)
##   Zone 10    → "boss"       (music driven by boss_spawned, no ambience)
## Returns "" when the name carries no zone number. Zone names are
## "SECTOR NN — DESCRIPTION"; the first positive integer token is the zone number.
static func tier_for_zone(zone_name: String) -> String:
	var zone_number := 0
	for part in zone_name.split(" "):
		var n := part.to_int()
		if n > 0:
			zone_number = n
			break

	if zone_number >= 1 and zone_number <= 4:
		return "industrial"
	elif zone_number >= 5 and zone_number <= 7:
		return "neon"
	elif zone_number >= 8 and zone_number <= 9:
		return "highrise"
	elif zone_number == 10:
		return "boss"
	return ""


## Zone music clip per tier ("" for the boss tier — Zone 10 music is triggered by
## boss_spawned). Filenames keep the old "corporate" naming for the Neon high-rise tier.
static func music_for_tier(tier: String) -> String:
	match tier:
		"industrial":
			return "zone_industrial"
		"neon":
			return "zone_neon_market"
		"highrise":
			return "zone_corporate"
	return ""

## Ambience clip per tier ("" for the boss tier — no ambience during the fight).
static func ambience_for_tier(tier: String) -> String:
	match tier:
		"industrial":
			return "industrial_hum"
		"neon":
			return "neon_market_crowd"
		"highrise":
			return "corporate_interior"
	return ""

func _on_zone_entered(zone_name: String) -> void:
	var tier := tier_for_zone(zone_name)
	var music := music_for_tier(tier)
	if music != "":
		play_music(music)
	var ambience := ambience_for_tier(tier)
	if ambience != "":
		play_ambience(ambience)


func _on_boss_spawned(boss_name: String) -> void:
	play_sfx("boss_bar_appear")
	# Only the Headliner takes over the soundtrack; the Enforcer miniboss
	# keeps its zone music running under the miniboss health bar.
	if boss_name != "Headliner":
		return
	stop_ambience()
	stop_music()
	_boss_music_active = true
	if _boss_music_a and _boss_music_b:
		# Phase-locked pair: both start together, phase 2 sits silent until
		# the 50% HP crossfade in _on_boss_health_changed.
		_boss_music_a.volume_db = 0.0
		_boss_music_b.volume_db = -80.0
		_boss_music_a.play()
		_boss_music_b.play()
	else:
		play_music("boss_headliner")


func _on_boss_health_changed(current: int, maximum: int) -> void:
	if not _boss_music_active:
		return
	if _boss_music_a == null or _boss_music_b == null:
		return
	if current <= maximum / 2.0 and _boss_music_b.volume_db < 0.0:
		var tween := get_tree().create_tween()
		tween.set_parallel(true)
		tween.tween_property(_boss_music_a, "volume_db", -80.0, 0.5)
		tween.tween_property(_boss_music_b, "volume_db", 0.0, 0.5)


func _on_boss_died() -> void:
	# The Enforcer miniboss also emits boss_died — leave its zone music alone.
	if not _boss_music_active:
		return
	_boss_music_active = false
	stop_music()
	if _boss_music_a:
		_boss_music_a.stop()
	if _boss_music_b:
		_boss_music_b.stop()

## A run that ended mid-Headliner (game over/abandon) never emitted boss_died — clear the
## boss-music flag so the next run's Enforcer kill doesn't cut the zone music, and forget
## the last track so the first zone entry starts its music fresh.
func _on_run_started() -> void:
	_boss_music_active = false
	_current_music = ""

## T3: a checkpoint respawn returned the boss to dormant — silence the boss track the
## same way a kill does (guarded, so an Enforcer reset leaves zone music alone).
func _on_boss_reset() -> void:
	_on_boss_died()

# ---------------------------------------------------------------------------
# Internal helpers
# ---------------------------------------------------------------------------

func _load_stream(path: String) -> AudioStream:
	if not ResourceLoader.exists(path):
		# Graceful no-op: file not added yet, silently skip.
		return null
	return load(path) as AudioStream


func _build_sfx_pool() -> void:
	for i in SFX_POOL_SIZE:
		var p := AudioStreamPlayer.new()
		p.bus = "SFX"
		p.name = "SFXPoolPlayer_%d" % i
		add_child(p)
		_sfx_pool.append(p)


func _get_free_sfx_player() -> AudioStreamPlayer:
	for p in _sfx_pool:
		if not p.playing:
			return p
	# All slots busy — steal the oldest (first in array, which finished furthest ago).
	# Simple round-robin would be better with a pointer, but pool is small enough.
	return _sfx_pool[0]


## Locate the AudioStreamPlayer nodes that live in the main scene.
## Called lazily so AudioManager (an autoload) doesn't race the scene tree.
func _ensure_players() -> void:
	if _music_player and _ambience_player:
		return
	var root := get_tree().current_scene
	if root == null:
		return
	if _music_player == null:
		_music_player = root.get_node_or_null("MusicPlayer")
	if _ambience_player == null:
		_ambience_player = root.get_node_or_null("AmbiencePlayer")


## Called by the main scene after it's ready so players are registered immediately.
func register_scene_players(
		music: AudioStreamPlayer,
		ambience: AudioStreamPlayer) -> void:
	_music_player = music
	_ambience_player = ambience


## Called by the boss scene on _ready() to register the two phase players.
## BossMusicA carries the phase-1 track; BossMusicB carries the phase-2 track
## and should start with volume_db = -80 in the scene. Both are played together
## on boss_spawned so they remain phase-locked for the mid-fight crossfade.
func register_boss_music_players(
		phase_a: AudioStreamPlayer,
		phase_b: AudioStreamPlayer) -> void:
	_boss_music_a = phase_a
	_boss_music_b = phase_b
