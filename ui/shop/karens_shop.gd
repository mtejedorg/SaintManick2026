extends Control

@onready var scrap_label: Label = $VBox/ScrapLabel
@onready var hp_button: Button = $VBox/BuyHPButton
@onready var life_button: Button = $VBox/BuyLifeButton
@onready var shield_button: Button = $VBox/BuyShieldButton
@onready var double_jump_button: Button = $VBox/BuyDoubleJumpButton
@onready var booster_button: Button = $VBox/BoosterButton
@onready var start_button: Button = $VBox/StartRunButton

const BOOSTERS = ["None", "Tempo Shield", "Adrenaline", "Scrap Magnet"]

func _ready() -> void:
	hp_button.pressed.connect(_on_buy_hp)
	life_button.pressed.connect(_on_buy_life)
	shield_button.pressed.connect(_on_buy_shield)
	double_jump_button.pressed.connect(_on_buy_double_jump)
	booster_button.pressed.connect(_on_cycle_booster)
	start_button.pressed.connect(_on_start_run)
	_update_ui()

func _update_ui() -> void:
	if SaveManager and SaveManager.profile:
		var p = SaveManager.profile
		scrap_label.text = "Scrap: " + str(p.scrap) + " | Cells: " + str(p.cells) + " | Cores: " + str(p.cores) + \
			"\nHP Level: " + str(p.max_hp_upgrades) + " (Max HP: " + str(120 + 20 * p.max_hp_upgrades) + ")" + \
			"\nShield Level: " + str(p.shield_upgrades) + " (Max Shield: " + str(40 + 10 * p.shield_upgrades) + ")" + \
			"\nLives Level: " + str(p.max_lives_upgrades) + " (Max Lives: " + str(3 + p.max_lives_upgrades) + ")"
		
		booster_button.text = "Equipped Booster: " + (p.equipped_run_booster if p.equipped_run_booster != "" else "None")
		double_jump_button.disabled = p.double_jump_unlocked
		if p.double_jump_unlocked:
			double_jump_button.text = "Double Jump (Unlocked)"
	else:
		scrap_label.text = "Error Loading Profile"

func _on_buy_hp() -> void:
	if SaveManager and SaveManager.profile:
		var p = SaveManager.profile
		if p.scrap >= 100:
			p.scrap -= 100
			p.max_hp_upgrades += 1
			SaveManager.save_profile()
			_update_ui()

func _on_buy_life() -> void:
	if SaveManager and SaveManager.profile:
		var p = SaveManager.profile
		if p.scrap >= 300:
			p.scrap -= 300
			p.max_lives_upgrades += 1
			SaveManager.save_profile()
			_update_ui()

func _on_buy_shield() -> void:
	if SaveManager and SaveManager.profile:
		var p = SaveManager.profile
		if p.scrap >= 150:
			p.scrap -= 150
			p.shield_upgrades += 1
			SaveManager.save_profile()
			_update_ui()

func _on_buy_double_jump() -> void:
	if SaveManager and SaveManager.profile:
		var p = SaveManager.profile
		if not p.double_jump_unlocked and p.scrap >= 200:
			p.scrap -= 200
			p.double_jump_unlocked = true
			SaveManager.save_profile()
			_update_ui()

func _on_cycle_booster() -> void:
	if SaveManager and SaveManager.profile:
		var p = SaveManager.profile
		var current = p.equipped_run_booster
		var idx = BOOSTERS.find(current)
		if idx == -1:
			idx = 0
		var next_idx = (idx + 1) % BOOSTERS.size()
		p.equipped_run_booster = BOOSTERS[next_idx]
		SaveManager.save_profile()
		_update_ui()

func _on_start_run() -> void:
	if GameManager:
		GameManager.start_new_run()
	get_tree().change_scene_to_file("res://levels/slice/vertical_slice.tscn")
