extends "res://tests/framework/test_case.gd"

# C14j: dying mid-elevator used to leave the platform halfway up, the entry trigger
# disarmed and the wave state dangling -- the ride could never be retried. Mirrors the
# ZoneEncounter pattern in test_checkpoint_respawn.gd.

var elevator: ElevatorEncounter
var platform: AnimatableBody3D
var spawner: WaveSpawner
var trigger: Area3D
var exit_path: Path3D
var player_stub: Node3D

func before_each() -> void:
	platform = AnimatableBody3D.new()
	platform.sync_to_physics = false
	platform.position.y = -4.5
	spawner = WaveSpawner.new()
	trigger = Area3D.new()
	elevator = ElevatorEncounter.new()
	elevator.platform = platform
	elevator.spawner = spawner
	elevator.entry_trigger = trigger
	elevator.target_y = 14.5
	exit_path = Path3D.new()
	elevator.exit_path = exit_path
	player_stub = Node3D.new()
	player_stub.name = "PlayerStub"
	player_stub.add_to_group("player")
	var wave := WaveDef.new()
	var node := Node3D.new()
	var scene := PackedScene.new()
	scene.pack(node)
	node.free()
	var list: Array[PackedScene] = [scene]
	wave.enemies = list
	var waves_list: Array[WaveDef] = [wave, wave]
	elevator.waves = waves_list
	add_child(platform)
	add_child(spawner)
	add_child(trigger)
	add_child(elevator)
	add_child(exit_path)
	add_child(player_stub)
	GameManager.has_checkpoint = false
	GameManager.checkpoint_path = null
	GameManager.checkpoint_top_down = true

func after_each() -> void:
	super.after_each()
	for n in [elevator, platform, spawner, trigger, exit_path, player_stub]:
		if is_instance_valid(n):
			n.free()

func test_mid_ride_respawn_resets_platform_waves_and_rearms_the_trigger() -> void:
	elevator.start_encounter()
	elevator._physics_process(1.0)
	assert_gt(platform.position.y, -4.5, "Platform should have risen")
	elevator.current_wave_index = 1
	trigger.monitoring = false
	assert_eq(spawner.active_enemies.size(), 1, "A wave is live")

	SignalBus.player_respawned.emit()

	assert_false(elevator.is_active, "Elevator goes idle")
	assert_eq(elevator.current_wave_index, 0, "Wave progress restarts")
	assert_eq(platform.position.y, -4.5, "Platform returns to its starting height")
	assert_true(spawner.active_enemies.is_empty(), "Live wave despawned silently")
	await get_tree().process_frame
	assert_true(trigger.monitoring, "Entry trigger is re-armed (deferred)")

func test_completed_elevator_is_untouched_by_respawn() -> void:
	elevator.start_encounter()
	platform.position.y = 14.5
	elevator.current_wave_index = elevator.waves.size()
	elevator._check_completion()
	assert_true(elevator.completed, "Arrival with every wave beaten completes the elevator")

	SignalBus.player_respawned.emit()

	assert_eq(platform.position.y, 14.5, "A completed elevator stays at the top")
	assert_true(elevator.completed)

func test_respawn_before_boarding_does_nothing() -> void:
	platform.position.y = -4.5
	SignalBus.player_respawned.emit()
	assert_false(elevator.is_active)
	assert_eq(platform.position.y, -4.5)

# G3: dying between the elevator's arrival and the Zone 10 trigger used to respawn Nick at
# the Zone 9 checkpoint at the base, under a platform that is parked at the top for good.
func test_completed_elevator_checkpoints_nick_dock_side_on_the_exit_rail() -> void:
	elevator.start_encounter()
	platform.position.y = elevator.target_y
	elevator.current_wave_index = elevator.waves.size()
	player_stub.global_position = Vector3(350.0, 15.0, 0.0)
	elevator._physics_process(0.016)
	assert_true(elevator.completed, "Precondition: arrival with every wave beaten completes the elevator")
	assert_true(GameManager.has_checkpoint, "Elevator completion should store a checkpoint")
	assert_eq(GameManager.checkpoint_path, elevator.exit_path, "The checkpoint rail should be the elevator's exit rail")
	assert_false(GameManager.checkpoint_top_down, "The dock checkpoint is side-scroll")
	assert_eq(GameManager.checkpoint_position, Vector3(350.0, 15.0, 0.0), "The checkpoint is where Nick stands on the arrived platform")
