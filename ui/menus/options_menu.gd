extends Control
## L8 (D25): minimal options -- Master / Music / SFX volume (0-100) and Fullscreen, persisted in
## the PlayerProfile through SaveManager (the profile owns the values, SaveManager applies them).
## The title screen and the pause menu each instance this scene, call open() and wait for
## `closed`. BACK, ui_cancel and pause all close it; the profile is saved on close.
## Q4: three accessibility rows in the same button pattern -- SCREEN SHAKE (cycles 100 % /
## OFF / 50 %), VCR EFFECTS and REDUCE FLASHES toggles -- persisted in the PlayerProfile and
## read by gameplay through GameManager.shake_multiplier() / vcr_enabled() / reduce_flashes().

signal closed

## Q4: the screen-shake steps the SCREEN SHAKE row cycles through (accept = next, wraps).
const SHAKE_STEPS: Array[float] = [0.0, 0.5, 1.0]

@onready var master_slider: HSlider = $Panel/VBox/Grid/MasterSlider
@onready var music_slider: HSlider = $Panel/VBox/Grid/MusicSlider
@onready var sfx_slider: HSlider = $Panel/VBox/Grid/SfxSlider
@onready var master_value: Label = $Panel/VBox/Grid/MasterValue
@onready var music_value: Label = $Panel/VBox/Grid/MusicValue
@onready var sfx_value: Label = $Panel/VBox/Grid/SfxValue
@onready var fullscreen_toggle: Button = $Panel/VBox/FullscreenToggle
@onready var shake_button: Button = $Panel/VBox/ShakeButton
@onready var vcr_toggle: Button = $Panel/VBox/VcrToggle
@onready var flash_toggle: Button = $Panel/VBox/FlashToggle
@onready var hud_size_button: Button = $Panel/VBox/HudSizeButton
@onready var back_button: Button = $Panel/VBox/BackButton

func _ready() -> void:
	hide()
	master_slider.value_changed.connect(_on_volume_changed.bind(SaveManager.BUS_MASTER))
	music_slider.value_changed.connect(_on_volume_changed.bind(SaveManager.BUS_MUSIC))
	sfx_slider.value_changed.connect(_on_volume_changed.bind(SaveManager.BUS_SFX))
	for slider in _sliders():
		slider.drag_ended.connect(_on_drag_ended)
	fullscreen_toggle.toggled.connect(_on_fullscreen_toggled)
	shake_button.pressed.connect(cycle_shake.bind(1))
	vcr_toggle.toggled.connect(_on_vcr_toggled)
	flash_toggle.toggled.connect(_on_flash_toggled)
	hud_size_button.pressed.connect(cycle_hud_scale.bind(1))
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
	elif shake_button.has_focus() and event.is_action_pressed("ui_left"):
		cycle_shake(-1)
		get_viewport().set_input_as_handled()
	elif shake_button.has_focus() and event.is_action_pressed("ui_right"):
		cycle_shake(1)
		get_viewport().set_input_as_handled()
	elif hud_size_button.has_focus() and event.is_action_pressed("ui_left"):
		cycle_hud_scale(-1)
		get_viewport().set_input_as_handled()
	elif hud_size_button.has_focus() and event.is_action_pressed("ui_right"):
		cycle_hud_scale(1)
		get_viewport().set_input_as_handled()

func _sliders() -> Array[HSlider]:
	return [master_slider, music_slider, sfx_slider]

## Up/down walk the column and wrap; left/right stay on the sliders' values, and never leave
## the panel from the buttons.
func _wire_focus() -> void:
	var chain: Array[Control] = [master_slider, music_slider, sfx_slider, fullscreen_toggle, shake_button, vcr_toggle, flash_toggle, hud_size_button, back_button]
	for i in chain.size():
		var c := chain[i]
		var prev := chain[(i - 1 + chain.size()) % chain.size()]
		var next := chain[(i + 1) % chain.size()]
		c.focus_neighbor_top = c.get_path_to(prev)
		c.focus_neighbor_bottom = c.get_path_to(next)
		c.focus_previous = c.get_path_to(prev)
		c.focus_next = c.get_path_to(next)
	for b in [fullscreen_toggle, shake_button, vcr_toggle, flash_toggle, hud_size_button, back_button]:
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
	vcr_toggle.set_pressed_no_signal(p.vcr_effects)
	flash_toggle.set_pressed_no_signal(p.reduce_flashes)
	_refresh_labels()

func _refresh_labels() -> void:
	master_value.text = "%d%%" % roundi(master_slider.value)
	music_value.text = "%d%%" % roundi(music_slider.value)
	sfx_value.text = "%d%%" % roundi(sfx_slider.value)
	fullscreen_toggle.text = "FULLSCREEN: %s" % ("ON" if fullscreen_toggle.button_pressed else "OFF")
	shake_button.text = "SCREEN SHAKE: %s" % shake_text(_shake_value())
	vcr_toggle.text = "VCR EFFECTS: %s" % ("ON" if vcr_toggle.button_pressed else "OFF")
	flash_toggle.text = "REDUCE FLASHES: %s" % ("ON" if flash_toggle.button_pressed else "OFF")
	hud_size_button.text = "HUD SIZE: %s" % hud_scale_text(_hud_scale_value())

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

## "OFF" / "50%" / "100%".
static func shake_text(value: float) -> String:
	return "OFF" if value <= 0.0 else "%d%%" % roundi(value * 100.0)

func _shake_value() -> float:
	var p: PlayerProfile = SaveManager.profile if SaveManager else null
	return p.screen_shake if p else 1.0

## Steps SCREEN SHAKE through SHAKE_STEPS by `step`, wrapping; an off-grid stored value snaps
## to the nearest step first.
func cycle_shake(step: int) -> void:
	var p: PlayerProfile = SaveManager.profile if SaveManager else null
	if p == null:
		return
	var idx := 0
	for i in SHAKE_STEPS.size():
		if absf(SHAKE_STEPS[i] - p.screen_shake) < absf(SHAKE_STEPS[idx] - p.screen_shake):
			idx = i
	var count := SHAKE_STEPS.size()
	p.screen_shake = SHAKE_STEPS[((idx + step) % count + count) % count]
	SaveManager.save_profile()
	_refresh_labels()

## V11: "100 %" / "125 %" / "150 %".
static func hud_scale_text(value: float) -> String:
	return "%d %%" % roundi(value * 100.0)

## The HUD scale in force (the auto 125 % of a small window included).
func _hud_scale_value() -> float:
	var p: PlayerProfile = SaveManager.profile if SaveManager else null
	if p == null:
		return 1.0
	return p.effective_hud_scale(float(get_window().size.y))

## V11: steps HUD SIZE through PlayerProfile.HUD_SCALE_STEPS by `step`, wrapping, from the value
## in force; the pick is saved and the HUD (listening to the profile's `changed`) re-scales.
func cycle_hud_scale(step: int) -> void:
	var p: PlayerProfile = SaveManager.profile if SaveManager else null
	if p == null:
		return
	var steps := PlayerProfile.HUD_SCALE_STEPS
	var current := _hud_scale_value()
	var idx := 0
	for i in steps.size():
		if absf(steps[i] - current) < absf(steps[idx] - current):
			idx = i
	var count := steps.size()
	p.hud_scale = steps[((idx + step) % count + count) % count]
	p.hud_scale_chosen = true
	SaveManager.save_profile()
	p.emit_changed()
	_refresh_labels()

func _on_vcr_toggled(on: bool) -> void:
	if SaveManager and SaveManager.profile:
		SaveManager.profile.vcr_effects = on
		SaveManager.save_profile()
	_refresh_labels()

func _on_flash_toggled(on: bool) -> void:
	if SaveManager and SaveManager.profile:
		SaveManager.profile.reduce_flashes = on
		SaveManager.save_profile()
	_refresh_labels()
