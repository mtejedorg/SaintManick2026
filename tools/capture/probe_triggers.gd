## Headless physics probe: does the real Player body trip the slice's Area3D triggers?
## Run: Godot_console.exe --headless --path "<proj>" res://tools/capture/probe_triggers.tscn
extends Node

var _fired: Array[String] = []
var _frame := 0
var _slice: Node3D
var _player: CharacterBody3D

func _ready() -> void:
	_slice = (load("res://levels/slice/vertical_slice.tscn") as PackedScene).instantiate()
	add_child(_slice)
	_player = _slice.get_node("Player")
	SignalBus.zone_entered.connect(func(n: String): _fired.append("zone_entered:" + n))
	SignalBus.boss_spawned.connect(func(n: String): _fired.append("boss_spawned:" + n))
	print("PROBE player layer=%d mask=%d" % [_player.collision_layer, _player.collision_mask])
	for a in _slice.find_children("*", "Area3D", true, false):
		if a.owner == _slice or a.get_parent() == _slice:
			print("PROBE area %s layer=%d mask=%d" % [a.name, a.collision_layer, a.collision_mask])

func _physics_process(_d: float) -> void:
	_frame += 1
	# Walk the player through the Zone 1 encounter trigger (x 0..10), then Zone 2 trigger (x 26..36).
	if _frame == 5:
		if OS.get_cmdline_user_args().has("--fix"):
			_player.collision_layer = 2
			for a in _slice.find_children("*", "Area3D", true, false):
				if a.get_parent() == _slice and a.collision_mask == 1024 and not (a is Hitbox3D):
					a.collision_mask = 2
			print("PROBE applied fix: player layer=2, zone triggers mask=2")
		_player.global_position = Vector3(5, 1, 0)
	if _frame == 25:
		var skel: Skeleton3D = _player.find_child("Skeleton3D", true, false)
		if skel:
			var lowest := INF
			var lowest_name := ""
			for i in skel.get_bone_count():
				var y: float = (skel.global_transform * skel.get_bone_global_pose(i)).origin.y
				if y < lowest:
					lowest = y
					lowest_name = skel.get_bone_name(i)
			print("PROBE player origin y=%.3f lowest bone %s y=%.3f (capsule bottom y=%.3f)" % [_player.global_position.y, lowest_name, lowest, _player.global_position.y - 1.0])
	if _frame == 30:
		_player.global_position = Vector3(31, 1, 0)
	if _frame == 60:
		print("PROBE fired=", _fired)
		var z1: Node = _slice.get_node("Z1_Encounter")
		print("PROBE z1_active=", z1.active, " spawned=", z1.spawner.active_enemies.size())
		get_tree().quit(0)
