extends CanvasLayer

const DEGRADADO_PATH  := "res://2D_Assets/UI_and_Menus/OPCIÓN PAUSE/DEGRADADO.png"
const CAPA5_PATH      := "res://2D_Assets/UI_and_Menus/OPCIÓN PAUSE/Capa-5.png"
const SEMICIRCULO_PATH := "res://2D_Assets/UI_and_Menus/OPCIÓN PAUSE/SEMICÍCULO.png"
const PAUSE_TITLE_PATH := "res://2D_Assets/UI_and_Menus/OPCIÓN PAUSE/PAUSE.png"

@onready var degradado:    TextureRect = $Root/Degradado
@onready var capa5:        TextureRect = $Root/Capa5
@onready var semicirculo:  TextureRect = $Root/Semicirculo
@onready var pause_title:  TextureRect = $Root/PauseTitle
@onready var resume_button: Button     = $Root/ButtonContainer/ResumeButton
@onready var quit_button:   Button     = $Root/ButtonContainer/QuitButton

func _ready() -> void:
	_try_load_texture(degradado, DEGRADADO_PATH)
	_try_load_texture(capa5, CAPA5_PATH)
	_try_load_texture(semicirculo, SEMICIRCULO_PATH)
	_try_load_texture(pause_title, PAUSE_TITLE_PATH)

	resume_button.pressed.connect(_on_resume_pressed)
	quit_button.pressed.connect(_on_quit_pressed)

	# Visible state driven by toggle; start hidden
	hide()

func _input(event: InputEvent) -> void:
	# This node is PROCESS_MODE_ALWAYS so the toggle works while the tree is paused.
	if event.is_action_pressed("ui_cancel"):
		toggle()
		get_viewport().set_input_as_handled()

func _try_load_texture(rect: TextureRect, path: String) -> void:
	if FileAccess.file_exists(path):
		rect.texture = load(path)

func toggle() -> void:
	if visible:
		_resume()
	else:
		show()
		get_tree().paused = true

func _resume() -> void:
	hide()
	get_tree().paused = false

func _on_resume_pressed() -> void:
	_resume()

func _on_quit_pressed() -> void:
	get_tree().paused = false
	get_tree().change_scene_to_file("res://ui/shop/karens_shop.tscn")
