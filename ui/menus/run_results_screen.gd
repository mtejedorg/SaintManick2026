extends CanvasLayer

func _ready() -> void:
	$CenterBox/ContinueButton.pressed.connect(_on_continue)
	_populate_stats()

func _populate_stats() -> void:
	var gm = get_node_or_null("/root/GameManager")
	if not gm:
		return
	$CenterBox/StatsContainer/ScrapLabel.text = "SCRAP COLLECTED    %d" % gm.scrap
	$CenterBox/StatsContainer/EnemiesLabel.text = "ENEMIES DEFEATED   %d" % gm.enemies_defeated
	$CenterBox/StatsContainer/ZonesLabel.text = "ZONES CLEARED      %d / 10" % gm.zones_cleared

func _on_continue() -> void:
	get_tree().change_scene_to_file("res://ui/shop/karens_shop.tscn")
