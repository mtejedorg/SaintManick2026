extends "res://tests/framework/test_case.gd"

func test_collision_layer_constants() -> void:
	assert_eq(512, 1 << 9, "player_hitbox (layer 10) bit value should be 512")
	assert_eq(1024, 1 << 10, "player_hurtbox (layer 11) bit value should be 1024")
	assert_eq(2048, 1 << 11, "enemy_hitbox (layer 12) bit value should be 2048")
	assert_eq(4096, 1 << 12, "enemy_hurtbox (layer 13) bit value should be 4096")
	assert_eq(8192, 1 << 13, "hazard_hitbox (layer 14) bit value should be 8192")

func test_player_collision_configuration() -> void:
	var player_scene = load("res://characters/player/player.tscn")
	assert_not_null(player_scene, "Player scene should load")
	
	var player = player_scene.instantiate()
	add_child(player)
	
	var hitbox: Hitbox3D = player.get_node("MeshInstance3D/KatanaHitbox")
	var hurtbox: Hurtbox3D = player.get_node("Hurtbox3D")
	
	assert_not_null(hitbox, "KatanaHitbox should exist on player")
	assert_not_null(hurtbox, "Hurtbox3D should exist on player")
	
	assert_eq(hitbox.collision_layer, 512, "Player hitbox should be on layer 10 (512)")
	assert_eq(hitbox.collision_mask, 4096, "Player hitbox mask should look for layer 13 (4096, enemy_hurtbox)")
	
	assert_eq(hurtbox.collision_layer, 1024, "Player hurtbox should be on layer 11 (1024)")
	assert_eq(hurtbox.collision_mask, 0, "Player hurtbox mask should be 0")
	
	player.queue_free()

func test_enemy_collision_configuration() -> void:
	var enemy_scene = load("res://characters/enemies/bruiser/bruiser.tscn")
	assert_not_null(enemy_scene, "Bruiser enemy scene should load")
	
	var enemy = enemy_scene.instantiate()
	add_child(enemy)
	
	var hitbox: Hitbox3D = _find_hitbox(enemy)
	var hurtbox: Hurtbox3D = _find_hurtbox(enemy)
		
	assert_not_null(hitbox, "Enemy hitbox should exist")
	assert_not_null(hurtbox, "Enemy hurtbox should exist")
	
	assert_eq(hitbox.collision_layer, 2048, "Enemy hitbox should be on layer 12 (2048)")
	assert_eq(hitbox.collision_mask, 1024, "Enemy hitbox mask should look for layer 11 (1024, player_hurtbox)")
	
	assert_eq(hurtbox.collision_layer, 4096, "Enemy hurtbox should be on layer 13 (4096)")
	assert_eq(hurtbox.collision_mask, 0, "Enemy hurtbox mask should be 0")
	
	enemy.queue_free()

func test_hazard_collision_configuration() -> void:
	var hazard_scene = load("res://levels/components/ceiling_piston.tscn")
	assert_not_null(hazard_scene, "Ceiling piston hazard scene should load")
	
	var hazard = hazard_scene.instantiate()
	add_child(hazard)
	
	var hitbox: Hitbox3D = hazard.get_node("PistonBody/Hitbox3D")
	assert_not_null(hitbox, "Ceiling piston hitbox should exist")
	
	assert_eq(hitbox.collision_layer, 8192, "Hazard hitbox should be on layer 14 (8192)")
	assert_eq(hitbox.collision_mask, 1024, "Hazard hitbox mask should look for layer 11 (1024, player_hurtbox)")
	
	hazard.queue_free()

# A9: physics BODY layers (separate from hitbox/hurtbox layers). Player = layer 2
# ("player"), colliding with world (1) + enemies (3). Enemies = layer 3 ("enemies",
# bit 4), colliding with world (1) + player (2). Triggers mask layer 2.
func test_body_root_layers() -> void:
	var player = load("res://characters/player/player.tscn").instantiate()
	assert_eq(player.collision_layer, 2, "Player body should be on the player layer (2)")
	assert_eq(player.collision_mask, 5, "Player body should collide with world (1) + enemies (4)")
	player.free()

	for path in [
		"res://characters/enemies/runner/runner.tscn",
		"res://characters/enemies/bruiser/bruiser.tscn",
		"res://characters/enemies/sniper/sniper.tscn",
		"res://characters/enemies/enforcer/enforcer.tscn",
		"res://characters/enemies/headliner/headliner.tscn",
	]:
		var enemy = load(path).instantiate()
		assert_eq(enemy.collision_layer, 4, "%s body should be on the enemies layer (4)" % path)
		assert_eq(enemy.collision_mask, 3, "%s body should collide with world (1) + player (2)" % path)
		enemy.free()

	var encounter = load("res://levels/components/zone_encounter.tscn").instantiate()
	assert_eq(encounter.collision_mask, 2, "ZoneEncounter should detect the player body layer")
	encounter.free()
	var pit = load("res://levels/components/toxic_pit.tscn").instantiate()
	assert_eq(pit.collision_mask, 2, "ToxicPit should detect the player body layer")
	pit.free()

func _find_hitbox(node: Node) -> Hitbox3D:
	if node is Hitbox3D:
		return node
	for child in node.get_children():
		var res = _find_hitbox(child)
		if res:
			return res
	return null

func _find_hurtbox(node: Node) -> Hurtbox3D:
	if node is Hurtbox3D:
		return node
	for child in node.get_children():
		var res = _find_hurtbox(child)
		if res:
			return res
	return null
