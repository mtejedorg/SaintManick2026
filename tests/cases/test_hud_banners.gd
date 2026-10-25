extends "res://tests/framework/test_case.gd"

# Batch H (UI) U1/U5/U6/U7: the life-lost banner survives the respawn zone card and shows
# on the last spare life, banner_requested reaches the card, the boss bar shows a shield
# strip, lives above the art cap get an "xN" tag, and the LAST LIFE tag pulses on the beat.

const HUD_SCENE := preload("res://ui/hud/hud.tscn")
const ZONE_07 := "SECTOR 07 — ENFORCER"

var hud: CanvasLayer
var _run_ended_before: bool

func before_each() -> void:
	_run_ended_before = GameManager.run_ended
	GameManager.run_ended = false
	hud = HUD_SCENE.instantiate()
	add_child(hud)

func after_each() -> void:
	GameManager.run_ended = _run_ended_before
	if is_instance_valid(hud):
		hud.queue_free()
	super.after_each()

func _card_text() -> String:
	return hud.zone_title_card.label.text

func test_life_lost_banner_survives_the_respawn_zone_card() -> void:
	SignalBus.player_life_lost.emit(1)
	await get_tree().process_frame
	SignalBus.zone_entered.emit(ZONE_07)
	assert_eq(_card_text(), "LIFE LOST — 1 LEFT", "The respawn zone_entered must not replace the life-lost banner")
	assert_eq(hud.zone_title_card._queued_zone, ZONE_07, "A new zone during a priority card is queued, not lost")

func test_already_announced_zone_is_dropped_during_a_priority_card() -> void:
	SignalBus.zone_entered.emit(ZONE_07)
	assert_eq(_card_text(), ZONE_07, "A plain zone_entered still shows the zone card")
	SignalBus.player_life_lost.emit(2)
	SignalBus.zone_entered.emit(ZONE_07)
	assert_eq(_card_text(), "LIFE LOST — 2 LEFT", "Banner stays up")
	assert_eq(hud.zone_title_card._queued_zone, "", "A zone already announced is dropped, not replayed")

func test_queued_zone_plays_after_the_priority_card() -> void:
	SignalBus.player_life_lost.emit(1)
	SignalBus.zone_entered.emit(ZONE_07)
	hud.zone_title_card._on_card_finished() # the priority card slide-out ended
	assert_eq(_card_text(), ZONE_07, "The queued zone plays once the priority card is done")
	assert_false(hud.zone_title_card._priority_active, "A zone card is not a priority card")

func test_spending_the_last_spare_life_shows_last_life() -> void:
	GameManager.run_ended = false
	SignalBus.player_life_lost.emit(0)
	assert_eq(_card_text(), "LAST LIFE", "0 spare lives with the run still live -> LAST LIFE banner")
	assert_true(hud.zone_title_card.visible, "The banner is on screen")

func test_game_over_emission_stays_quiet() -> void:
	GameManager.run_ended = true
	SignalBus.player_life_lost.emit(0)
	assert_false(hud.zone_title_card.visible, "The terminal emission (run_ended) shows no banner")

func test_banner_requested_reaches_the_zone_card() -> void:
	SignalBus.banner_requested.emit("PROJECTION STORM — SURVIVE", 2.0)
	assert_eq(_card_text(), "PROJECTION STORM — SURVIVE", "banner_requested shows its text on the card")
	assert_true(hud.zone_title_card._priority_active, "Boss cues are priority cards")

func test_boss_shield_strip_follows_boss_shield_changed() -> void:
	SignalBus.boss_spawned.emit("Enforcer")
	assert_false(hud.boss_shield_strip.visible, "No shield reported yet -> strip hidden")
	SignalBus.boss_shield_changed.emit(50.0, 50.0)
	assert_true(hud.boss_shield_strip.visible, "Shield up -> strip visible")
	assert_eq(hud.boss_shield_strip.value, 50.0)
	SignalBus.boss_shield_changed.emit(0.0, 50.0)
	assert_false(hud.boss_shield_strip.visible, "Shield down -> strip hidden")

func test_boss_shield_strip_hides_on_reset() -> void:
	SignalBus.boss_spawned.emit("Headliner")
	SignalBus.boss_shield_changed.emit(1.0, 1.0)
	SignalBus.boss_reset.emit()
	assert_false(hud.boss_shield_strip.visible, "A respawn reset clears the strip")

func test_lives_above_the_art_cap_show_a_count_tag() -> void:
	hud._update_lives_ui(6)
	assert_true(hud.lives_count_label.visible, "6 lives -> xN tag visible")
	assert_eq(hud.lives_count_label.text, "x6")
	hud._update_lives_ui(4)
	assert_false(hud.lives_count_label.visible, "4 lives fit the art -> no tag")

func test_last_life_tag_size_and_beat_pulse() -> void:
	assert_eq(hud.last_life_label.get_theme_font_size("font_size"), 22, "LAST LIFE reads at 22 px")
	hud._update_lives_ui(0)
	assert_true(hud.last_life_label.visible)
	SignalBus.beat.emit("primary", 0)
	assert_almost_eq(hud.last_life_label.modulate.a, 1.0, 0.01, "Bright on the beat")
	await get_tree().create_timer(0.4).timeout
	assert_almost_eq(hud.last_life_label.modulate.a, hud.LAST_LIFE_PULSE_LOW, 0.05, "Settles to the low alpha between beats")
	hud._update_lives_ui(2)
	assert_almost_eq(hud.last_life_label.modulate.a, 1.0, 0.01, "Hidden tag resets its alpha")
