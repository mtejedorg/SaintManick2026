extends Node

var combo_count: int = 0
var combo_timeout: float = 2.0
var combo_timer: float = 0.0
var has_hit_this_attack: bool = false

func _ready() -> void:
	SignalBus.player_hit_landed.connect(_on_player_hit_landed)

func _process(delta: float) -> void:
	if combo_count > 0:
		combo_timer -= delta
		if combo_timer <= 0.0:
			_drop_combo()

func _on_player_hit_landed(_damage_info: DamageInfo) -> void:
	combo_count += 1
	combo_timer = combo_timeout
	has_hit_this_attack = true
	SignalBus.combo_increased.emit(combo_count)

func on_attack_started() -> void:
	has_hit_this_attack = false

func on_attack_ended() -> void:
	if not has_hit_this_attack and combo_count > 0:
		_drop_combo()

func _drop_combo() -> void:
	combo_count = 0
	combo_timer = 0.0
	SignalBus.combo_dropped.emit()
