extends "res://tests/framework/test_case.gd"

## Q6: the balance tool SLICE preset (Documents/tools/balance_tool.html, ARCH_DEF) mirrors the
## shipped enemy stats. The tool is the first-pass source; the .tres files are the truth.

const TOOL_PATH := "res://Documents/tools/balance_tool.html"
const ARCH_KEYS: Array[String] = ["runner", "bruiser", "sniper", "enforcer", "headliner"]
const QUOTE := "\u0022"

func _tool_text() -> String:
	var f := FileAccess.open(TOOL_PATH, FileAccess.READ)
	return f.get_as_text() if f else ""

func test_arch_def_matches_the_enemy_stats() -> void:
	var text := _tool_text()
	assert_true(text != "", "The balance tool is readable at %s" % TOOL_PATH)
	var block_re := RegEx.new()
	block_re.compile("const ARCH_DEF=[{]([\\s\\S]*?)\\n[}];")
	var block := block_re.search(text)
	assert_not_null(block, "ARCH_DEF is found in the SLICE preset")
	if block == null:
		return
	var row_re := RegEx.new()
	row_re.compile("(\\w+):\\s*[{]name:" + QUOTE + "[^" + QUOTE + "]*" + QUOTE + ",\\s*hp:([\\d.]+),\\s*shield:([\\d.]+),\\s*dmg:([\\d.]+)")
	var rows := {}
	for m in row_re.search_all(block.get_string(1)):
		rows[m.get_string(1)] = [m.get_string(2).to_float(), m.get_string(3).to_float(), m.get_string(4).to_float()]
	for key in ARCH_KEYS:
		assert_true(rows.has(key), "ARCH_DEF has a %s row" % key)
		if not rows.has(key):
			continue
		var stats: EnemyStats = load("res://characters/enemies/%s/%s_stats.tres" % [key, key])
		assert_not_null(stats, "%s_stats.tres loads" % key)
		if stats == null:
			continue
		assert_almost_eq(rows[key][0], stats.max_health, 0.001, "Tool %s hp %s == max_health %s" % [key, rows[key][0], stats.max_health])
		assert_almost_eq(rows[key][1], stats.shield, 0.001, "Tool %s shield %s == shield %s" % [key, rows[key][1], stats.shield])
		assert_almost_eq(rows[key][2], stats.damage, 0.001, "Tool %s dmg %s == damage %s" % [key, rows[key][2], stats.damage])

## W2: the SHOP_DEF rows mirror _core/persistence/shop_upgrades/*.tres (id, cost, currency,
## repeatable flag, prerequisite). The tool's `key` is its own handle; `id` is the .tres id.
const SHOP_DIR := "res://_core/persistence/shop_upgrades/"
const CURRENCY_NAMES: Array[String] = ["scrap", "cells", "cores"]

func _shop_upgrades_by_id() -> Dictionary:
	var out := {}
	for file in DirAccess.get_files_at(SHOP_DIR):
		if not file.ends_with(".tres"):
			continue
		var up := load(SHOP_DIR + file) as ShopUpgrade
		if up != null:
			out[up.id] = up
	return out

func test_shop_def_matches_the_shop_upgrades() -> void:
	var text := _tool_text()
	var block_re := RegEx.new()
	block_re.compile("const SHOP_DEF=\\[([\\s\\S]*?)\\n\\];")
	var block := block_re.search(text)
	assert_not_null(block, "SHOP_DEF is found in the tool")
	if block == null:
		return
	var row_re := RegEx.new()
	row_re.compile("[{]key:" + QUOTE + "(\\w+)" + QUOTE + ",\\s*id:" + QUOTE + "(\\w+)" + QUOTE
		+ ",[^\\n]*?cur:" + QUOTE + "(\\w+)" + QUOTE + ",\\s*cost:(\\d+),\\s*rep:(true|false),\\s*pre:" + QUOTE + "(\\w*)" + QUOTE)
	var ups := _shop_upgrades_by_id()
	assert_true(ups.size() >= 9, "At least 9 shop upgrades load (%d)" % ups.size())
	var key_to_id := {}
	var rows: Array = row_re.search_all(block.get_string(1))
	for m in rows:
		key_to_id[m.get_string(1)] = m.get_string(2)
	assert_eq(rows.size(), ups.size(), "SHOP_DEF row count %d == shop_upgrades/*.tres count %d" % [rows.size(), ups.size()])
	for m in rows:
		var id: String = m.get_string(2)
		assert_true(ups.has(id), "SHOP_DEF id %s has a .tres" % id)
		if not ups.has(id):
			continue
		var up: ShopUpgrade = ups[id]
		assert_eq(m.get_string(4).to_int(), up.cost, "Tool %s cost == .tres cost %d" % [id, up.cost])
		assert_eq(m.get_string(3), CURRENCY_NAMES[up.currency], "Tool %s currency == .tres currency" % id)
		assert_eq(m.get_string(5) == "true", up.is_repeatable, "Tool %s repeatable == .tres" % id)
		var pre_key: String = m.get_string(6)
		var pre_id: String = key_to_id.get(pre_key, "") if pre_key != "" else ""
		assert_eq(pre_id, up.prerequisite_id, "Tool %s prerequisite == .tres prerequisite_id" % id)

## W2: the ZONES wave groups (enemy counts per WaveDef) mirror the Resource_z*_w* sub-resources of
## levels/slice/vertical_slice.tscn. Zones whose enemies are scene-placed (2, 7, 8, 10) have no
## WaveDef and are not checked here.
const SLICE_SCENE := "res://levels/slice/vertical_slice.tscn"

func _scene_wave_groups() -> Dictionary:
	var f := FileAccess.open(SLICE_SCENE, FileAccess.READ)
	if f == null:
		return {}
	var text := f.get_as_text()
	var ext_re := RegEx.new()
	ext_re.compile("\\[ext_resource[^\\]]*path=" + QUOTE + "res://characters/enemies/(\\w+)/\\w+\\.tscn" + QUOTE + "[^\\]]*id=" + QUOTE + "([^" + QUOTE + "]+)" + QUOTE)
	var id_to_type := {}
	for m in ext_re.search_all(text):
		id_to_type[m.get_string(2)] = m.get_string(1)
	var wave_re := RegEx.new()
	wave_re.compile("\\[sub_resource type=" + QUOTE + "Resource" + QUOTE + " id=" + QUOTE + "Resource_z(\\d+)_w(\\d+)" + QUOTE + "\\]\\s*\\nscript = [^\\n]*\\nenemies = ([^\\n]*)")
	var id_re := RegEx.new()
	id_re.compile("ExtResource[(]" + QUOTE + "([^" + QUOTE + "]+)" + QUOTE + "[)]")
	var out := {}  # zone -> { wave index -> { type -> count } }
	for m in wave_re.search_all(text):
		var zone := m.get_string(1).to_int()
		var wave := m.get_string(2).to_int()
		var counts := {}
		for e in id_re.search_all(m.get_string(3)):
			var t: String = id_to_type.get(e.get_string(1), e.get_string(1))
			counts[t] = int(counts.get(t, 0)) + 1
		if not out.has(zone):
			out[zone] = {}
		out[zone][wave] = counts
	return out

func _tool_zone_groups() -> Dictionary:
	var text := _tool_text()
	var block_re := RegEx.new()
	block_re.compile("const ZONES=\\[([\\s\\S]*?)\\n\\];")
	var block := block_re.search(text)
	var out := {}  # zone -> Array of { type -> count }
	if block == null:
		return out
	var row_re := RegEx.new()
	row_re.compile("[{]n:(\\d+),[^\\n]*?g:\\[(.*)\\],\\s*bC:")
	var grp_re := RegEx.new()
	grp_re.compile("[{]([^{}]*)[}]")
	var kv_re := RegEx.new()
	kv_re.compile("(\\w+):(\\d+)")
	for m in row_re.search_all(block.get_string(1)):
		var groups: Array = []
		for g in grp_re.search_all(m.get_string(2)):
			var counts := {}
			for kv in kv_re.search_all(g.get_string(1)):
				counts[kv.get_string(1)] = kv.get_string(2).to_int()
			groups.append(counts)
		out[m.get_string(1).to_int()] = groups
	return out

func test_zones_enemy_counts_match_the_slice_wave_defs() -> void:
	var scene := _scene_wave_groups()
	var tool_zones := _tool_zone_groups()
	assert_true(scene.size() >= 6, "The slice scene has WaveDefs for at least 6 zones (%d)" % scene.size())
	assert_eq(tool_zones.size(), 10, "The tool ZONES lists 10 zones")
	for zone in scene.keys():
		assert_true(tool_zones.has(zone), "Tool ZONES has zone %d" % zone)
		if not tool_zones.has(zone):
			continue
		var waves: Dictionary = scene[zone]
		var tool_groups: Array = tool_zones[zone]
		assert_eq(tool_groups.size(), waves.size(), "Zone %d: tool wave groups %d == scene WaveDefs %d" % [zone, tool_groups.size(), waves.size()])
		var wave_keys: Array = waves.keys()
		wave_keys.sort()
		for i in mini(tool_groups.size(), wave_keys.size()):
			var want: Dictionary = waves[wave_keys[i]]
			var got: Dictionary = tool_groups[i]
			assert_eq(got.size(), want.size(), "Zone %d wave %d: same enemy types (tool %s, scene %s)" % [zone, i + 1, str(got), str(want)])
			for t in want.keys():
				assert_eq(int(got.get(t, 0)), int(want[t]), "Zone %d wave %d: %s count tool %d == scene %d" % [zone, i + 1, t, int(got.get(t, 0)), int(want[t])])
