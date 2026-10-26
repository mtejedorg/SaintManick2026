extends Control
## L8 (D25): minimal options -- Master / Music / SFX volume (0-100) and Fullscreen, persisted in
## the PlayerProfile through SaveManager (the profile owns the values, SaveManager applies them).
## The title screen and the pause menu each instance this scene, call open() and wait for
## `closed`. BACK, ui_cancel and pause all close it; the profile is saved on close.

signal closed

@onready var master_slider: HSlider = $Panel/VBox/Grid/MasterSlider
@onready var music_slider: HSlider = $Panel/VBox/Grid/MusicSlider
@onready var sfx_slider: HSlider = $Panel/VBox/Grid/SfxSlider
@onready var master_value: Label = $Panel/VBox/Grid/MasterValue
@onready var music_value: Label = $Panel/VBox/Grid/MusicValue
@onready var sfx_value: Label = $Panel/VBox/Grid/SfxValue
@onready var fullscreen_toggle: Button = $Panel/VBox/FullscreenToggle
@onready var back_button: Button = $Panel/VBox/BackButton

func _ready() -> void:
	hide()
	master_slider.value_changed.connect(_on_volume_changed.bind(SaveManager.BUS_MASTER))
	music_slider.value_changed.connect(_on_volume_changed.bind(SaveManager.BUS_MUSIC))
	sfx_slider.value_changed.connect(_on_volume_changed.bind(SaveManager.BUS_SFX))
	for slider in _sliders():
		slider.drag_ended.connect(_on_drag_ended)
	fullscreen_toggle.toggled.connect(_on_fullscreen_toggled)
	back_button.pressed.connect(close)
	_wire_focus()
	_sync_from_profile()

func open() -> void:
	_sync_from_profile()
	show()
	master_slider.grab_focus()

func close() -> void:
	if not visible:
		return
	hide()
	if SaveManager and SaveManager.profile:
		SaveManager.save_profile()
	closed.emit()

func _input(event: InputEvent) -> void:
	if not visible:
		return
	if event.is_action_pressed("ui_cancel") or event.is_action_pressed("pause"):
		close()
		get_viewport().set_input_as_handled()

func _sliders() -> Array[HSlider]:
	return [master_slider, music_slider, sfx_slider]

## Up/down walk the column and wrap; left/right stay on the sliders' values, and never leave
## the panel from the buttons.
func _wire_focus() -> void:
	var chain: Array[Control] = [master_slider, music_slider, sfx_slider, fullscreen_toggle, back_button]
	for i in chain.size():
		var c := chain[i]
		var prev := chain[(i - 1 + chain.size()) % chain.size()]
		var next := chain[(i + 1) % chain.size()]
		c.focus_neighbor_top = c.get_path_to(prev)
		c.focus_neighbor_bottom = c.get_path_to(next)
		c.focus_previous = c.get_path_to(prev)
		c.focus_next = c.get_path_to(next)
	for b in [fullscreen_toggle, back_button]:
		b.focus_neighbor_left = b.get_path_to(b)
		b.focus_neighbor_right = b.get_path_to(b)

func _sync_from_profile() -> void:
	var p: PlayerProfile = SaveManager.profile if SaveManager else null
	if p == null:
		return
	master_slider.set_value_no_signal(p.master_volume * 100.0)
	music_slider.set_value_no_signal(p.music_volume * 100.0)
	sfx_slider.set_value_no_signal(p.sfx_volume * 100.0)
	fullscreen_toggle.set_pressed_no_signal(p.fullscreen)
	_refresh_labels()

func _refresh_labels() -> void:
	master_value.text = "%d%%" % roundi(master_slider.value)
	music_value.text = "%d%%" % roundi(music_slider.value)
	sfx_value.text = "%d%%" % roundi(sfx_slider.value)
	fullscreen_toggle.text = "FULLSCREEN: %s" % ("ON" if fullscreen_toggle.button_pressed else "OFF")

func _on_volume_changed(value: float, bus: StringName) -> void:
	var linear := clampf(value / 100.0, 0.0, 1.0)
	var p: PlayerProfile = SaveManager.profile if SaveManager else null
	if p:
		if bus == SaveManager.BUS_MASTER:
			p.master_volume = linear
		elif bus == SaveManager.BUS_MUSIC:
			p.music_volume = linear
		elif bus == SaveManager.BUS_SFX:
			p.sfx_volume = linear
	SaveManager.set_bus_volume_linear(bus, linear)
	_refresh_labels()

func _on_drag_ended(value_changed: bool) -> void:
	if value_changed and SaveManager and SaveManager.profile:
		SaveManager.save_profile()

func _on_fullscreen_toggled(on: bool) -> void:
	if SaveManager and SaveManager.profile:
		SaveManager.profile.fullscreen = on
		SaveManager.save_profile()
	SaveManager.apply_fullscreen(on)
	_refresh_labels()
