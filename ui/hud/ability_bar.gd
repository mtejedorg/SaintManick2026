extends Control

@onready var meter_bar: ProgressBar = $ProgressBar

func _ready() -> void:
	if SignalBus:
		SignalBus.ability_meter_changed.connect(_on_ability_meter_changed)
	meter_bar.value = 0.0

func _on_ability_meter_changed(current: float, max_meter: float) -> void:
	meter_bar.max_value = max_meter
	
	# Optional juice: tween the value
	var tween = create_tween()
	tween.tween_property(meter_bar, "value", current, 0.1).set_trans(Tween.TRANS_SINE)
