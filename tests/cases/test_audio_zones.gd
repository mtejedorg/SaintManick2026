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
