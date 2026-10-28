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
