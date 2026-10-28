extends HBoxContainer
## Batch Q6: the action-gated hint strip (bottom-left, replaces the three Zone 1 control cards).
## One chip per core action; a chip fades out (FADE_TIME) the first time its action fires
## (Input.is_action_just_pressed, polled in _process). Chip text follows the last input device
## (keyboard vs gamepad). Once every chip has fired the controls count as seen
## (GameManager.mark_controls_seen: PlayerProfile.seen_controls, in memory only during a demo)
## and the strip never shows again; with them already seen it skips itself at _ready().

const FADE_TIME := 0.4
## [action, keyboard text, gamepad text] per chip, left to right.
const CHIPS := [
	["attack_light", "J ATTACK", "X ATTACK"],
	["attack_heavy", "K HEAVY", "Y HEAVY"],
	["jump", "SPACE JUMP", "A JUMP"],
	["dash", "SHIFT/Q DASH", "RB DASH"],
	["roll", "CTRL/E ROLL", "B ROLL"],
]
const CHIP_FONT_SIZE := 18
## Inner padding of a chip (px) on top of the HudPanel frame.
const CHIP_PAD_X := 10.0
const CHIP_PAD_Y := 3.0
## Stick deflection that counts as "the player is on a gamepad".
const JOY_AXIS_THRESHOLD := 0.5

## action -> PanelContainer chip, in CHIPS order.
var _chips: Dictionary = {}
## action -> true once its action fired.
var _fired: Dictionary = {}
var _gamepad: bool = false
## Hidden by the HUD while a boss bar shares the bottom edge.
var _suppressed: bool = false

func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_theme_constant_override("separation", 8)
	for spec in CHIPS:
		var chip := PanelContainer.new()
		chip.theme_type_variation = &"HudPanel"
		chip.mouse_filter = Control.MOUSE_FILTER_IGNORE
		var label := Label.new()
		label.name = "Label"
		label.theme_type_variation = &"DimLabel"
		label.add_theme_font_size_override("font_size", CHIP_FONT_SIZE)
		label.add_theme_color_override("font_color", Color(0.91, 0.965, 1, 1))
		chip.add_child(label)
		chip.name = String(spec[0]).to_pascal_case() + "Chip"
		add_child(chip)
		var frame := chip.get_theme_stylebox(&"panel").duplicate() as StyleBox
		frame.content_margin_left = CHIP_PAD_X
		frame.content_margin_right = CHIP_PAD_X
		frame.content_margin_top = CHIP_PAD_Y
		frame.content_margin_bottom = CHIP_PAD_Y
		chip.add_theme_stylebox_override(&"panel", frame)
		_chips[spec[0]] = chip
	_refresh_labels()
	if GameManager.controls_seen():
		visible = false
		set_process(false)
		set_process_input(false)

func _process(_delta: float) -> void:
	for spec in CHIPS:
		var action: String = spec[0]
		if not _fired.has(action) and Input.is_action_just_pressed(action):
			fire(action)

func _input(event: InputEvent) -> void:
	var pad := _gamepad
	if event is InputEventJoypadButton:
		pad = true
	elif event is InputEventJoypadMotion:
		if absf((event as InputEventJoypadMotion).axis_value) >= JOY_AXIS_THRESHOLD:
			pad = true
	elif event is InputEventKey or event is InputEventMouseButton:
		pad = false
	if pad != _gamepad:
		_gamepad = pad
		_refresh_labels()

## The chip for `action` has done its job: fade it out. The last one marks the controls seen.
func fire(action: String) -> void:
	if _fired.has(action) or not _chips.has(action):
		return
	_fired[action] = true
	var chip: Control = _chips[action]
	var tween := chip.create_tween()
	tween.tween_property(chip, "modulate:a", 0.0, FADE_TIME)
	tween.tween_callback(func() -> void: chip.visible = false)
	if all_fired():
		GameManager.mark_controls_seen()
		set_process(false)

func all_fired() -> bool:
	return _fired.size() >= CHIPS.size()

func is_fired(action: String) -> bool:
	return _fired.has(action)

func chip(action: String) -> PanelContainer:
	return _chips.get(action)

func chip_text(action: String) -> String:
	var c: PanelContainer = _chips.get(action)
	return (c.get_node("Label") as Label).text if c else ""

func set_suppressed(on: bool) -> void:
	_suppressed = on
	visible = not on and not all_fired() and not GameManager.controls_seen()

func uses_gamepad_labels() -> bool:
	return _gamepad

func _refresh_labels() -> void:
	for spec in CHIPS:
		var c: PanelContainer = _chips.get(spec[0])
		if c:
			(c.get_node("Label") as Label).text = spec[2] if _gamepad else spec[1]
