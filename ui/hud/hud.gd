extends CanvasLayer

@onready var battery_rect: TextureRect = $MarginContainer/VBoxContainer/StatusContainer/BatteryRect
@onready var shield_bar: TextureProgressBar = $MarginContainer/VBoxContainer/StatusContainer/ShieldBar
@onready var lives_rect: TextureRect = $MarginContainer/VBoxContainer/LivesRect
@onready var beat_pulse_node: Control = $BeatPulse

var beat_tween: Tween

func _ready() -> void:
	# Subscriptions
	SignalBus.player_health_changed.connect(_on_player_health_changed)
	SignalBus.player_shield_changed.connect(_on_player_shield_changed)
	GameManager.lives_changed.connect(_on_lives_changed)
	SignalBus.beat.connect(_on_beat)
	SignalBus.downbeat.connect(_on_downbeat)
	
	# Initial UI Setup
	_setup_textures()
	_update_battery_ui(GameManager.current_hp, GameManager.max_hp)
	_update_shield_ui(GameManager.current_shield, GameManager.max_shield)
	_update_lives_ui(GameManager.current_lives)
	
	# Set pivot offset for beat pulse center pulsing
	beat_pulse_node.pivot_offset = beat_pulse_node.size / 2.0
	beat_pulse_node.modulate = Color(1.0, 1.0, 1.0, 0.5)

func _setup_textures() -> void:
	# Dynamically set shield progress textures to avoid path mismatches in scene file
	var under_path = _get_estamina_empty_path()
	var progress_path = _get_estamina_full_path()
	
	if under_path != "" and FileAccess.file_exists(under_path):
		shield_bar.texture_under = load(under_path)
	if progress_path != "" and FileAccess.file_exists(progress_path):
		shield_bar.texture_progress = load(progress_path)

func _on_player_health_changed(new_health: float, max_health: float) -> void:
	_update_battery_ui(new_health, max_health)

func _on_player_shield_changed(new_shield: float, max_shield: float) -> void:
	_update_shield_ui(new_shield, max_shield)

func _on_lives_changed(new_amount: int) -> void:
	_update_lives_ui(new_amount)

func _update_battery_ui(current: float, max_val: float) -> void:
	var ratio = current / max_val if max_val > 0.0 else 0.0
	var segments = clamp(round(ratio * 12.0), 0, 12)
	
	var path = ""
	if segments == 0:
		path = _get_battery_empty_path()
	elif segments == 12:
		path = _get_battery_full_path()
		if path == "" or not FileAccess.file_exists(path):
			path = _get_battery_texture_path(12)
	else:
		path = _get_battery_texture_path(segments)
		
	if path != "" and FileAccess.file_exists(path):
		battery_rect.texture = load(path)

func _update_shield_ui(current: float, max_val: float) -> void:
	shield_bar.max_value = max_val
	shield_bar.value = current

func _update_lives_ui(lives: int) -> void:
	if lives <= 0:
		lives_rect.visible = false
	else:
		lives_rect.visible = true
		var count = clamp(lives, 1, 4)
		var path = ""
		if count == 1:
			path = "res://2D_Assets/UI_and_Menus/1-vida-extra.png"
		elif count == 2:
			path = "res://2D_Assets/UI_and_Menus/2-vidas-extra.png"
		elif count == 3:
			path = "res://2D_Assets/UI_and_Menus/3-vidas-extra.png"
		else:
			path = "res://2D_Assets/UI_and_Menus/4-vidas-extra.png"
			
		if FileAccess.file_exists(path):
			lives_rect.texture = load(path)

func _on_beat(layer: String, _beat_index: int) -> void:
	if layer != "primary":
		return
		
	if beat_tween:
		beat_tween.kill()
		
	beat_tween = create_tween().set_parallel(true)
	
	# Standard beat pulse: Cyan-green highlight, slight scale up
	beat_pulse_node.scale = Vector2(1.25, 1.25)
	beat_pulse_node.modulate = Color(0.0, 1.0, 0.8, 1.0)
	
	beat_tween.tween_property(beat_pulse_node, "scale", Vector2(1.0, 1.0), 0.25).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	beat_tween.tween_property(beat_pulse_node, "modulate", Color(1.0, 1.0, 1.0, 0.5), 0.25).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)

func _on_downbeat(layer: String, _measure_index: int) -> void:
	if layer != "primary":
		return
		
	if beat_tween:
		beat_tween.kill()
		
	beat_tween = create_tween().set_parallel(true)
	
	# Strong downbeat pulse: Pink-magenta highlight, larger scale up
	beat_pulse_node.scale = Vector2(1.6, 1.6)
	beat_pulse_node.modulate = Color(1.0, 0.0, 0.5, 1.0)
	
	beat_tween.tween_property(beat_pulse_node, "scale", Vector2(1.0, 1.0), 0.35).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	beat_tween.tween_property(beat_pulse_node, "modulate", Color(1.0, 1.0, 1.0, 0.5), 0.35).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)

# Path Helpers for accented files
func _get_battery_texture_path(index: int) -> String:
	var p1 = "res://2D_Assets/UI_and_Menus/batería-%d.png" % index
	if FileAccess.file_exists(p1):
		return p1
	var p2 = "res://2D_Assets/UI_and_Menus/baterÃa-%d.png" % index
	if FileAccess.file_exists(p2):
		return p2
	return ""

func _get_battery_full_path() -> String:
	var p1 = "res://2D_Assets/UI_and_Menus/batería-llena.png"
	if FileAccess.file_exists(p1):
		return p1
	var p2 = "res://2D_Assets/UI_and_Menus/baterÃa-llena.png"
	if FileAccess.file_exists(p2):
		return p2
	return ""

func _get_battery_empty_path() -> String:
	var p1 = "res://2D_Assets/UI_and_Menus/batería-vacía.png"
	if FileAccess.file_exists(p1):
		return p1
	var p2 = "res://2D_Assets/UI_and_Menus/baterÃa-vacÃa.png"
	if FileAccess.file_exists(p2):
		return p2
	return ""

func _get_estamina_empty_path() -> String:
	var p1 = "res://2D_Assets/UI_and_Menus/estamina-vacía.png"
	if FileAccess.file_exists(p1):
		return p1
	var p2 = "res://2D_Assets/UI_and_Menus/estamina-vacÃa.png"
	if FileAccess.file_exists(p2):
		return p2
	return ""

func _get_estamina_full_path() -> String:
	var p = "res://2D_Assets/UI_and_Menus/estamian-llena.png"
	if FileAccess.file_exists(p):
		return p
	return ""
