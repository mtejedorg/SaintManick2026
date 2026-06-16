extends "res://tests/framework/test_case.gd"

func test_bruiser_stats() -> void:
	var stats = load("res://characters/enemies/bruiser/bruiser_stats.tres") as EnemyStats
	assert_not_null(stats, "Bruiser stats should be loadable")
	assert_eq(stats.max_health, 90.0, "Bruiser HP should be 90.0")
	assert_eq(stats.damage, 20.0, "Bruiser damage should be 20.0")

func test_runner_stats() -> void:
	var stats = load("res://characters/enemies/runner/runner_stats.tres") as EnemyStats
	assert_not_null(stats, "Runner stats should be loadable")
	assert_eq(stats.max_health, 30.0, "Runner HP should be 30.0")
	assert_eq(stats.damage, 8.0, "Runner damage should be 8.0")

func test_sniper_stats() -> void:
	var stats = load("res://characters/enemies/sniper/sniper_stats.tres") as EnemyStats
	assert_not_null(stats, "Sniper stats should be loadable")
	assert_eq(stats.max_health, 24.0, "Sniper HP should be 24.0")
	assert_eq(stats.damage, 18.0, "Sniper damage should be 18.0")

func test_enforcer_stats() -> void:
	var stats = load("res://characters/enemies/enforcer/enforcer_stats.tres") as EnemyStats
	assert_not_null(stats, "Enforcer stats should be loadable")
	assert_eq(stats.max_health, 600.0, "Enforcer HP should be 600.0")
	assert_eq(stats.damage, 22.0, "Enforcer damage should be 22.0")

func test_headliner_stats() -> void:
	var stats = load("res://characters/enemies/headliner/headliner_stats.tres") as EnemyStats
	assert_not_null(stats, "Headliner stats should be loadable")
	assert_eq(stats.max_health, 1500.0, "Headliner HP should be 1500.0")
	assert_eq(stats.damage, 25.0, "Headliner damage should be 25.0")
