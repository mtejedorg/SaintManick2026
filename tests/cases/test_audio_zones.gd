extends "res://tests/framework/test_case.gd"

# A6: zone audio tiers follow the slice's Factory (1–4) → Neon (5–7) → Neon high-rise
# (8–9) → boss (10) arc from Documents/VerticalSlice.md.

func test_tier_for_zone_follows_factory_to_neon_arc() -> void:
	assert_eq(AudioManager.tier_for_zone("SECTOR 01 — LOADING DOCK"), "industrial")
	assert_eq(AudioManager.tier_for_zone("SECTOR 04 — FACTORY FLOOR"), "industrial", "Zone 4 is still Factory")
	assert_eq(AudioManager.tier_for_zone("SECTOR 05 — NEON STREETS"), "neon", "Zone 5 starts the Neon district")
	assert_eq(AudioManager.tier_for_zone("SECTOR 07 — ENFORCER"), "neon")
	assert_eq(AudioManager.tier_for_zone("SECTOR 08 — ESCAPE"), "highrise")
	assert_eq(AudioManager.tier_for_zone("SECTOR 09 — ELEVATOR"), "highrise", "Zone 9 elevator is the high-rise ascent")
	assert_eq(AudioManager.tier_for_zone("SECTOR 10 — HEADLINER"), "boss")
	assert_eq(AudioManager.tier_for_zone("NO NUMBER HERE"), "", "Names without a zone number map to no tier")

# F5: player_died fires on every life lost (before the respawn) — only a terminal death
# (no lives left) stops the music; a respawn re-plays the checkpoint zone's track.
func test_music_stops_only_on_a_terminal_death() -> void:
	assert_true(AudioManager.should_stop_music_on_death(0), "The death that finds 0 lives is game over -> stop")
	assert_false(AudioManager.should_stop_music_on_death(1), "A death with a life left respawns -> keep the music")
	assert_false(AudioManager.should_stop_music_on_death(3), "Keep the music on the first life lost")

func test_respawn_track_follows_the_checkpoint_tier() -> void:
	assert_eq(AudioManager.music_for_tier(AudioManager.tier_for_zone("SECTOR 03 — PRESS LINE")), "zone_industrial")
	assert_eq(AudioManager.music_for_tier(AudioManager.tier_for_zone("SECTOR 06 — MARKET")), "zone_neon_market")
	assert_eq(AudioManager.music_for_tier(AudioManager.tier_for_zone("SECTOR 09 — ELEVATOR")), "zone_corporate")
	assert_eq(AudioManager.music_for_tier("boss"), "", "Boss music is driven by boss_spawned, not the zone tier")
