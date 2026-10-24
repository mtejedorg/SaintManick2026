extends "res://tests/framework/test_case.gd"

# C14j: dying mid-elevator used to leave the platform halfway up, the entry trigger
# disarmed and the wave state dangling -- the ride could never be retried. Mirrors the
# ZoneEncounter pattern in test_checkpoint_respawn.gd.

var elevator: ElevatorEncounter
var platform: AnimatableBody3D
var spawner: WaveSpawner
var trigger: Area3D

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

func after_each() -> void:
	super.after_each()
	for n in [elevator, platform, spawner, trigger]:
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
