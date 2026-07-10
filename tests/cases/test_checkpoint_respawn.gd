extends "res://tests/framework/test_case.gd"

# T3: losing a life with lives remaining respawns Nick at the last zone-entry checkpoint
# instead of reloading the whole slice. Cleared encounters stay cleared (no death-farming),
# activated bosses reset to dormant at full HP.

func before_each() -> void:
	GameManager.is_test = true
	# The framework's after_each() disconnects all SignalBus connections — restore what
	# GameManager wires in _ready() (pattern from test_game_manager.gd).
	if not SignalBus.zone_entered.is_connected(GameManager._on_zone_entered):
		SignalBus.zone_entered.connect(GameManager._on_zone_entered)
	GameManager.has_checkpoint = false
	GameManager.checkpoint_zone = ""
	GameManager.checkpoint_position = Vector3.ZERO

func test_life_loss_does_not_reload_scene_in_test_mode() -> void:
	GameManager.start_new_run()
	var scene_before = get_tree().current_scene
	GameManager.current_hp = 5.0

	GameManager.respawn_or_game_over()

	assert_eq(get_tree().current_scene, scene_before, "Life loss must not swap/reload the current scene")
	assert_eq(GameManager.current_lives, GameManager.max_lives - 1, "Life loss should cost exactly one life")
	assert_eq(GameManager.current_hp, GameManager.max_hp, "Respawn should refill HP")
	assert_eq(GameManager.current_shield, GameManager.max_shield, "Respawn should refill shield")

func test_checkpoint_updates_on_zone_entered() -> void:
	# GameManager finds the player as a "Player"-named child of current_scene — the test
	# runner's dummy current_scene lets us plant one there.
	var player = load("res://characters/player/player.tscn").instantiate()
	player.name = "Player"
	get_tree().current_scene.add_child(player)
	player.global_position = Vector3(42.0, -3.0, 1.5)

	SignalBus.zone_entered.emit("SECTOR 05 — NEON MARKET")

	assert_true(GameManager.has_checkpoint, "zone_entered should store a checkpoint")
	assert_eq(GameManager.checkpoint_zone, "SECTOR 05 — NEON MARKET")
	assert_eq(GameManager.checkpoint_position, Vector3(42.0, -3.0, 1.5), "Checkpoint should capture the player's position at zone entry")

	# free() immediately, not queue_free(): the suite runs without idle frames, and a
	# lingering "Player" child would name-clash with the next test's player (Godot
	# auto-renames the new node, breaking GameManager._find_player).
	player.free()

func test_respawn_teleports_refills_and_emits_player_respawned() -> void:
	var player = load("res://characters/player/player.tscn").instantiate()
	player.name = "Player"
	get_tree().current_scene.add_child(player)
	player.global_position = Vector3(10.0, 0.0, 0.0)

	SignalBus.zone_entered.emit("SECTOR 03 — SECURITY LOCK")

	# Walk on, get hurt, die once.
	player.global_position = Vector3(60.0, 0.0, 0.0)
	player.velocity = Vector3(5.0, 0.0, 0.0)
	player.health_component.current_health = 0.0

	var flags = {"respawned": false}
	var on_respawn = func(): flags.respawned = true
	SignalBus.player_respawned.connect(on_respawn)

	GameManager.start_new_run()
	GameManager.respawn_or_game_over()

	assert_true(flags.respawned, "player_respawned should fire on a survivable life loss")
	assert_eq(player.global_position, Vector3(10.0, 0.0, 0.0), "Respawn should teleport to the checkpoint")
	assert_eq(player.velocity, Vector3.ZERO, "Respawn should zero velocity")
	assert_eq(player.health_component.current_health, GameManager.max_hp, "Respawn should refill the player's HealthComponent HP")
	assert_eq(player.health_component.current_shield, GameManager.max_shield, "Respawn should refill the player's shield")
	assert_true(player.health_component.is_invincible, "Respawn should grant a grace invincibility window")
	assert_eq(player.last_safe_position, player.global_position, "Respawn should reset last_safe_position to the checkpoint")

	SignalBus.player_respawned.disconnect(on_respawn)
	player.free() # immediate — see name-clash note in test_checkpoint_updates_on_zone_entered

func test_cleared_encounter_stays_cleared_after_respawn() -> void:
	var encounter = ZoneEncounter.new()
	var spawner = WaveSpawner.new()
	add_child(spawner)
	encounter.spawner = spawner
	add_child(encounter)

	encounter.active = true
	encounter.completed = true
	encounter.monitoring = false

	SignalBus.player_respawned.emit()

	assert_true(encounter.completed, "A completed encounter must stay completed")
	assert_true(encounter.active, "A completed encounter must not re-arm")
	assert_false(encounter.monitoring, "A completed encounter's trigger must stay disarmed")

	encounter.queue_free()
	spawner.queue_free()

func test_uncleared_encounter_resets_and_rearms_on_respawn() -> void:
	var encounter = ZoneEncounter.new()
	var spawner = WaveSpawner.new()
	add_child(spawner)
	encounter.spawner = spawner
	add_child(encounter)

	# Mid-fight: active, trigger disarmed, one live enemy in the wave.
	encounter.active = true
	encounter.current_wave_index = 1
	encounter.monitoring = false
	var enemy = load("res://characters/enemies/runner/runner.tscn").instantiate()
	spawner.add_child(enemy)
	spawner.active_enemies.append(enemy)
	enemy.tree_exited.connect(spawner._on_enemy_defeated.bind(enemy))

	var scrap_before = GameManager.scrap
	SignalBus.player_respawned.emit()

	assert_false(encounter.active, "An uncleared encounter should reset on respawn")
	assert_eq(encounter.current_wave_index, 0, "Wave progress should reset to wave 1")
	assert_true(spawner.active_enemies.is_empty(), "Spawned enemies should be despawned silently")
	assert_eq(GameManager.scrap, scrap_before, "Silent despawn must not award scrap")

	encounter.queue_free()
	spawner.queue_free()

func test_enforcer_resets_to_dormant_full_hp_on_respawn() -> void:
	var enforcer = load("res://characters/enemies/enforcer/enforcer.tscn").instantiate()
	add_child(enforcer)

	# Activate and wound it.
	SignalBus.zone_entered.emit("SECTOR 07 — ENFORCER")
	assert_true(enforcer.is_active, "Enforcer should activate on SECTOR 07 zone entry")
	enforcer.health_component.current_health = 50.0

	var flags = {"boss_reset": false}
	var on_reset = func(): flags.boss_reset = true
	SignalBus.boss_reset.connect(on_reset)

	SignalBus.player_respawned.emit()

	assert_false(enforcer.is_active, "Enforcer should return to dormant on respawn")
	assert_eq(enforcer.health_component.current_health, enforcer.health_component.max_health, "Enforcer should reset to full HP")
	assert_true(flags.boss_reset, "Enforcer reset should emit boss_reset (hides boss bar)")

	SignalBus.boss_reset.disconnect(on_reset)
	enforcer.queue_free()
