extends Control

@onready var scrap_label: Label = $VBox/ScrapLabel
@onready var hp_button: Button = $VBox/BuyHPButton
@onready var life_button: Button = $VBox/BuyLifeButton
@onready var shield_button: Button = $VBox/BuyShieldButton
@onready var booster_button: Button = $VBox/BoosterButton
@onready var start_button: Button = $VBox/StartRunButton

const BOOSTERS = ["None", "Tempo Shield", "Adrenaline", "Scrap Magnet"]

func _ready() -> void:
	hp_button.pressed.connect(_on_buy_hp)
	life_button.pressed.connect(_on_buy_life)
	shield_button.pressed.connect(_on_buy_shield)
	booster_button.pressed.connect(_on_cycle_booster)
	start_button.pressed.connect(_on_start_run)
	_update_ui()

func _update_ui() -> void:
	if SaveManager and SaveManager.profile:
		var p = SaveManager.profile
		scrap_label.text = "Persistent Scrap: " + str(p.persistent_scrap) + \
			"\nHP Level: " + str(p.max_hp_upgrades) + " (Max HP: " + str(120 + 20 * p.max_hp_upgrades) + ")" + \
			"\nShield Level: " + str(p.shield_upgrades) + " (Max Shield: " + str(40 + 10 * p.shield_upgrades) + ")" + \
			"\nLives Level: " + str(p.max_lives_upgrades) + " (Max Lives: " + str(3 + p.max_lives_upgrades) + ")"
		
		booster_button.text = "Equipped Booster: " + (p.equipped_run_booster if p.equipped_run_booster != "" else "None")
	else:
		scrap_label.text = "Error Loading Profile"

func _on_buy_hp() -> void:
	if SaveManager and SaveManager.profile:
		var p = SaveManager.profile
		if p.persistent_scrap >= 100:
			p.persistent_scrap -= 100
			p.max_hp_upgrades += 1
			SaveManager.save_profile()
			_update_ui()

func _on_buy_life() -> void:
	if SaveManager and SaveManager.profile:
		var p = SaveManager.profile
		if p.persistent_scrap >= 300:
			p.persistent_scrap -= 300
			p.max_lives_upgrades += 1
			SaveManager.save_profile()
			_update_ui()

func _on_buy_shield() -> void:
	if SaveManager and SaveManager.profile:
		var p = SaveManager.profile
		if p.persistent_scrap >= 150:
			p.persistent_scrap -= 150
			p.shield_upgrades += 1
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
