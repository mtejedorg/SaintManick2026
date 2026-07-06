extends CanvasLayer

const GAME_OVER_PATH := "res://2D_Assets/UI_and_Menus/game voer/GAME-OVER.png"
const DEGRADADO_PATH := "res://2D_Assets/UI_and_Menus/game voer/DEGRADADO.png"
const CAPA1_PATH     := "res://2D_Assets/UI_and_Menus/game voer/Capa-1.png"

@onready var degradado:      TextureRect = $Root/Degradado
@onready var capa1:          TextureRect = $Root/Capa1
@onready var game_over_text: TextureRect = $Root/GameOverText
@onready var return_button:  Button      = $Root/ReturnButton

func _ready() -> void:
	_try_load_texture(degradado, DEGRADADO_PATH)
	_try_load_texture(capa1, CAPA1_PATH)
	_try_load_texture(game_over_text, GAME_OVER_PATH)
	return_button.pressed.connect(_on_return_pressed)

func _try_load_texture(rect: TextureRect, path: String) -> void:
	if FileAccess.file_exists(path):
		rect.texture = load(path)

func _on_return_pressed() -> void:
	get_tree().change_scene_to_file("res://ui/shop/karens_shop.tscn")
