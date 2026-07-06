extends Node3D

@onready var music_player: AudioStreamPlayer = $MusicPlayer
@onready var ambience_player: AudioStreamPlayer = $AmbiencePlayer

func _ready() -> void:
	# Register scene-level audio players with the AudioManager autoload.
	AudioManager.register_scene_players(music_player, ambience_player)
