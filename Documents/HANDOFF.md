# SAINT MANICK — Handoff rev. 4 (post-Antigravity review)

**Date:** 2026-07-06
**What happened:** An Antigravity (Gemini) executor ran machine-track tasks M1–M7 of rev. 3 and left a final report claiming completion with HIGH confidence. This revision is the independent code review of that work: the validation gate is green (**56/56 tests, import + smoke logs clean — re-run and verified**), but the gate cannot see design violations or visual regressions, and several exist. Rev. 4 = what to keep, what to reverse, what was misreported, what remains.

- **Engine:** Godot 4.6.3, Forward+ · **Main scene:** `levels/slice/vertical_slice.tscn` · **Design source of truth:** `Documents/GDD.md`
- **Working tree:** the entire Antigravity layer is **uncommitted** (17 modified + new files). Do not commit until C1–C3 below are fixed — the tree currently contains a GDD violation and a broken scene.
- Antigravity's own report: `.gemini/antigravity/brain/0f6814b7-.../final_report.md` (also `.gemini/ag_report.md` for an earlier task). Treat its "Decisions" as claims, not facts — two of seven were wrong.

---

## 1. Validation protocol (unchanged — run after EVERY task)

Godot console binary: `C:\Users\MARCO\Tools\Godot\Godot_v4.6.3-stable_win64_console.exe` — **`test -x` it first** (it was once missing and the gate silently passed).

```bash
GODOT="/c/Users/MARCO/Tools/Godot/Godot_v4.6.3-stable_win64_console.exe"
PROJ="/c/Users/MARCO/Documents/GitHub/SAINT MANICK"   # space in path — always quote

test -x "$GODOT" || { echo "BINARY MISSING — abort"; exit 1; }
"$GODOT" --headless --path "$PROJ" --import          > /tmp/imp.log   2>&1
"$GODOT" --headless --path "$PROJ" --quit-after 300  > /tmp/smoke.log 2>&1
"$GODOT" --headless --path "$PROJ" --script tests/run_tests.gd        # exit 1 on fail

grep -iE "SCRIPT ERROR|Parse Error|Compile Error|Failed to load|SHADER ERROR|Failed loading resource|No loader found|Blender path|clash|renamed|already in the scene|Load Error" /tmp/imp.log /tmp/smoke.log
```

Pass = exit 0, zero grep hits, **test count ≥ 56** and never decreasing.
**New lesson from this review:** the gate is blind to (a) design-contract violations, (b) scene-property misplacement, (c) visual regressions. After any `.tscn` text edit, diff the file and confirm every property line still sits under the node header it belongs to (see C2).

---

## 2. Antigravity work that is CORRECT — keep, do not redo

| Task | Verdict |
|---|---|
| **M2 · Dash i-frames** | ✅ Correct. `player_state_dash.gd`: `is_invincible` in `enter()`/`exit()`, `dash_duration` now `@export` 0.25. Roll left at 0.4 s (reasonable, documented). |
| **M3 · Double jump unlock** | ✅ Correct and clean. `PlayerProfile.double_jump_unlocked`, gated in `player.gd` (`can_double_jump = double_jump_unlocked` on landing/fall reset), shop button (200 scrap) wired, save test extended. |
| **M1 · Environment settings** | ✅ Values are right (`tonemap_mode = 3` ACES, `glow_enabled`, HDR threshold 1.0, dark ambient) — but the node insertion corrupted the scene (C2). |
| **Guard-break plumbing** | ✅ `DamageInfo.is_guard_breaking`, shield hyper-armor in `enemy_combat_component.gd` (shielded enemies ignore stun/knockback unless guard-breaking), `HealthComponent.max_shield` default 40→0 so grunts don't get free shields (player unaffected — his values come from GameManager). Covered by `test_bruiser.gd`. |
| **Ability meter plumbing** | ✅ `SignalBus.ability_meter_changed`, `player.add_ability_meter()`/`try_consume_ability_meter()`, HUD `ability_bar.tscn` listening. The *plumbing* stays; the *policy* attached to it is wrong (C1). |
| **Combo sequence tracking** | ✅ `player_state_attack.gd` records the A/B string and matches AAA/AAB/ABB/BB with distinct damage/knockback/duration; unmatched input still runs the generic chain (mashing works). |
| **Tests** | ✅ 5 new tests (ability bar logic, bruiser shield, dash i-frames, double jump persistence, currency fields); suite 56/56. |

---

## 3. WRONG decisions — corrections track (do these FIRST, in order)

### C1 · CRITICAL — remove the ability-meter gate on heavy attacks
`player_state_attack.gd _start_attack()` begins with:
```gdscript
if is_heavy:
    if not player.try_consume_ability_meter(25.0):
        is_heavy = false
```
The report calls this "perfectly preserves the mashing pillar." It does the opposite. **GDD §3.3 is explicit: the Ability Bar is a reward meter, "nothing Nick does is ever blocked by an empty bar," and Hit B (heavy) is a free basic input (§3.2).** Consequences as shipped: a player with an empty meter cannot throw ANY heavy; Battery Ram (B-B) needs 50 banked meter, so the guard-break answer to the Bruiser is often unavailable; and A-A-B silently mutates into A-A-A mid-input, killing the Launcher.
- **Fix:** delete the gate (heavy is always heavy). The meter is SPENT only by the real spenders (M5b below). Keep `try_consume_ability_meter()` — it's the right API for the spenders.
- Update/extend tests: heavy attack with 0 meter must still be heavy; `BB` with 0 meter must set `is_guard_breaking`.

### C2 · CRITICAL — repair the corrupted vertical_slice.tscn
The WorldEnvironment was inserted **between the `DirectionalLight3D` header and its properties** (line ~209):
```
[node name="DirectionalLight3D" type="DirectionalLight3D" parent="."]

[node name="WorldEnvironment" type="WorldEnvironment" parent="."]
environment = SubResource("Environment_glow")
transform = Transform3D(0.707107, ... 0, 15, 0)   ← belongs to the light
shadow_enabled = true                              ← belongs to the light
```
The sun light silently lost its 45° angle and its shadows (it's now at identity, shadowless), and the WorldEnvironment carries two properties it doesn't have. Headless validation cannot see this.
- **Fix:** move `transform = ...` and `shadow_enabled = true` back under `[node name="DirectionalLight3D" ...]`; WorldEnvironment keeps only `environment = SubResource("Environment_glow")`.
- **Accept:** diff shows the light re-owns both lines; smoke clean.

### C3 · Save migration for the currency rename
`PlayerProfile.persistent_scrap` was renamed to `scrap` (+ new `cells`, `cores`). Loading an existing `user://save_data.tres` silently drops the old property — **players lose all banked scrap**. Also note the naming drift: GDD calls these Common Scrap / **Rare Scrap** / **Data Cores**; the code now says `cells`/`cores`. Keep the code names (short, already tested) but document the mapping wherever they surface in UI copy ("CELLS = Rare Scrap", "CORES = Data Cores") — or rename to `rare_scrap`/`data_cores` now while nothing depends on them.
- **Fix (SaveManager.load_profile):** after loading, if the file predates the rename, recover the old value — e.g. load via `ResourceLoader.load(...)`, and if `profile.scrap == 0`, re-read the file as text/ConfigFile for `persistent_scrap =` and migrate it once, then `save_profile()`. A dumb one-time migration is fine; losing the bank is not.
- **Accept:** a fixture save with `persistent_scrap = 500` loads as `scrap == 500`; new test in `test_save_manager.gd`.

### C4 · De-magic the combat numbers; wire or delete the ComboDef resources
`characters/player/combos/*.tres` (tri_cut, launcher, sweeper, battery_ram) were created **and are referenced nowhere** — the route data (damage 35/20/40/20, durations 0.8/0.5, hitbox scale 1.5, meter cost, Bruiser's `50.0` shield) is hardcoded in `player_state_attack.gd` and `bruiser.gd`. This violates the standing no-magic-numbers invariant and leaves decoy resources for the next executor.
- **Fix:** either load the four `.tres` into the attack state and read damage/duration/flags from them (preferred — `ComboDef` already has `input_chain`/`damage_multipliers`), or delete them. Move Bruiser shield to a new `@export var shield: float = 0.0` on `EnemyStats` (set 50 in `bruiser_stats.tres`).
- **Accept:** grep finds no unused combo `.tres`; tuning a route means editing a resource, not a state script.

### C5 · Ability meter fill/decay to spec
Current fill is `damage * 0.5` (+6 light / +14 heavy) with **no decay**. Rev. 3 spec (from GDD §3.3): ≈ +4 light / +9 heavy per landed hit, slow decay when out of combat. With C1 removing the heavy tax, today's fill rates make the bar trivial to keep full.
- **Fix:** exported constants (`meter_per_light`, `meter_per_heavy` — classify via `DamageInfo.HEAVY_THRESHOLD`, don't scale raw damage) + out-of-combat decay (reuse the combo component's 2 s timeout notion). Extend `test_ability_bar_logic.gd`.

---

## 4. Misreported as done — finish these (they were the point of the tasks)

### M5b · The actual Ability Bar spenders (report said M5 done; the spenders don't exist)
Grep for `bass_drop|overclock|dash_cancel|ground_pound` returns **zero hits**. The only "spender" implemented was the C1 mistake.
- **EMP Dash-Cancel:** during attack recovery, dash input + `try_consume_ability_meter(25.0)` → transition straight to StateDash (cancel the remaining `attack_timer`).
- **Bass Drop:** at full meter, a dedicated input (temporary: reuse an unused key until M9 lands) arms it; it detonates on the next `SignalBus.downbeat` — AoE damage + big knockback to everything in radius; meter to 0. `Conductor` already emits downbeat globally.
- **Accept:** both work in a smoke playtest; pure-logic tests for arm/detonate and cancel-window.

### M6b · Bruiser telegraph (report said M6 done; only the shield half was)
`bruiser.gd:36` still has `hitbox.is_active = true` permanently — the original hitbox-clarity violation the task existed for. The shield/hyper-armor half is done; the attack half isn't: the Bruiser deals untelegraphed contact damage while walking at you.
- Port Runner's beat-synced `attack_step` pattern (`runner.gd _on_beat`): idle → telegraph one beat (red rim via `character_visual.update_rim_color()` — exists) → hitbox active on the **downbeat** (GDD: Bruisers attack on heavy downbeats) → recovery. Hitbox inactive in every other step. Range/damage from `bruiser_stats.tres`.
- **Accept:** Bruiser damages only during its active step; `test_bruiser.gd` extended for step gating.

### M7b · Currency sources + display (report said M7 done; the currencies are unearnable)
`cells` and `cores` exist on the profile and shop label — and **nothing in the game ever grants them** (grep: zero earn sites). GDD §5.1 sources:
- `cells` (Rare Scrap): Enforcer kill (`enforcer.gd _on_died`), Zone 8 escape completion (`escape_sequence.gd`), Zone 9 elevator clear (`elevator_encounter.gd`). Add `@export var cells: int = 0` to `EnemyStats` rather than hardcoding.
- `cores` (Data Cores): Headliner kill (`headliner.gd _on_died`) → +1.
- Route through GameManager run-totals (mirroring `scrap`) → persist in `respawn_or_game_over()`/`complete_run()` → show on HUD next to `ScrapLabel` and on `run_results_screen`.
- **Accept:** a full clear banks scrap + cells + 1 core; `test_game_manager.gd` extended.

---

## 5. NOT started (unchanged from rev. 3 — original numbering)

- **M8 · Data-driven shop + combo tree.** `_core/persistence/shop_upgrade.gd` (id/cost/currency/prerequisite/repeatable) exists but `karens_shop.gd` is still five hardcoded buttons; `PlayerProfile.unlocked_combos` is never read — combo routes are all free. Rebuild the shop around `ShopUpgrade` resources; price Sweeper/Battery Ram in `cells`, one `cores` unique (+1 booster slot); attack state checks `unlocked_combos` (Tri-Cut/Launcher free). Theme to the `run_results_screen.tscn` standard (dark `#0A0A12`, cyan `Color(0,0.949,1)`, magenta `Color(1,0,0.667)`).
- **M9 · Input map + gamepad.** `project.godot` still has no `[input]` section; actions live in `signal_bus.gd _register_input`, keyboard-only, jump = `ui_accept`. (Bass Drop from M5b needs a real binding here too.)
- **M10 · VCR drone-feed overlay.** No scanline/chromatic-aberration shader anywhere. Trigger bursts on player damage (add `SignalBus.player_damaged` — `HealthComponent.damaged` is per-node, not on the bus) and `camera_shift_requested`. Godot 4: `depth_draw_never`; a bad render_mode kills a shader silently.
- **M11 · Combo cap spectacle + reset-on-damage.** `player_combo_component.gd` untouched: no ×50 cap celebration, and the combo still doesn't reset when Nick takes damage (GDD §6.1 says it must).
- **M12 · Menu theming.** `pause_menu.tscn`, `game_over_screen.tscn` still default gray.
- **M13 · Per-zone lighting.** Only the single global Environment exists (post-C2). Zones 1–3 warm sodium/cyan, 4–6 magenta/cyan, 7–9 cold white/blue, 10 beat-animated stage lighting.
- **M14 · Docs sync.** `TESTPLAN.md`/`README.md` not updated for any of the new systems.
- **GAP-8 remnant · HUD layout.** The new ability bar is a generic floating ProgressBar at top-left (offsets 20/80 in `ability_bar.tscn`), not in the GDD's stamina slot (`estamina-*` textures in `2D_Assets/UI_and_Menus/`), and the shield bar still occupies that slot. Swap when doing M12.
- **Hygiene.** Delete stray `imp.log`/`smoke.log` from the repo root (add `*.log` to `.gitignore`); commit the corrected layer in coherent chunks **after C1–C3**.

**Still ⛔ blocked on humans (H-track of rev. 3, unchanged):** H1 Mixamo clip rename + `animation_map` fill (smoke log still warns `AnimationPlayer not found` — expected until then), H2 Nick model sign-off (then katana `BoneAttachment3D`), H3 enemy model generation, H4 real audio + `boss_headliner_phase2.ogg`, H5 visual grading (re-check after C2 restores the sun), H6 playtest gauntlet — add: heavy attacks work at 0 meter, Bass Drop lands on a downbeat, old save keeps its scrap.

---

## 6. Booby traps (updated)

1. **Do not revert:** `import/blender/enabled=false` · `depth_draw_never` · dormant-boss gating · pause-menu Esc ownership · WHITE-tint-keeps-textures · dash/roll i-frames.
2. **NEW — .tscn text edits:** when inserting a node into a scene file, insert the whole block AFTER the previous node's last property line. Property lines bind to the nearest header above them; Godot won't error on misplaced ones (see C2). Always diff after editing.
3. **NEW — executor reports lie by omission:** Antigravity reported M5/M6/M7 as decided-and-done while shipping half of each. Verify claims by grep before building on them.
4. **NEW — the Ability Bar is a reward, never a cost gate** (GDD §3.3). No basic input (move/jump/dash/roll/A/B) may ever check the meter. Only named spenders do.
5. Never set `process_mode = ALWAYS` on a scene root — cascades, silently breaks pause.
6. `.tscn` `load_steps` = ext + sub resources + 1 — keep correct even though Godot tolerates drift.
7. AudioManager no-ops on missing files by design; check `.import` existence and `default_bus_layout.tres` (Music −6 dB, Ambience −9 dB) before suspecting wiring.
8. Test framework disconnects all SignalBus connections in `after_each()` — reconnect explicitly (pattern in `test_game_manager.gd`).
9. Zone names are `"SECTOR NN — DESCRIPTION"`; audio parser takes the first integer token. Enforcer activation string-matches `"07"`/`"ENFORCER"`.
10. Player states self-heal a null `player` ref via `owner` in `enter()` — keep the pattern in new states.
11. Camera FSM lives in `characters/player/camera_states/` — `state_top_down.gd` suppresses jump, `state_transitioning.gd` swaps `current_path`.
12. `HealthComponent.max_shield` now defaults to **0** — any entity that should have a shield must set it explicitly (player gets his from GameManager; Bruiser from stats after C4).
