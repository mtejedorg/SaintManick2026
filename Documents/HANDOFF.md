# SAINT MANICK — Unified Handoff (Machine Track + Human Track)

**Date:** 2026-07-06 (rev. 3 — merges rev. 1 review handoff + rev. 2 GDD parity audit; every rev. 2 claim re-verified against code and GDD before inclusion; tests re-run fresh: **51/51 pass**)

- **Engine:** Godot 4.6.3, Forward+ · **Main scene:** `levels/slice/vertical_slice.tscn` · **Player:** Nick
- **Design source of truth:** `Documents/GDD.md`. (`Documents/Roadmap.md` is the dead Unity-era plan — do not execute it.)
- **Desired state:** a GDD-faithful, visually stunning slice — neon-noir look, readable combat, real animation/audio, GDD core systems present.

**How to use this document:** §4 is the **machine track** — every task is executable by a model/agent through file edits + the §1 headless validation loop, no editor GUI needed. §5 is the **human track** — tasks that need the Godot editor, eyes, ears, or authoring judgment. Dependencies between tracks are marked `⛔ blocked by`. Everything else is context so an executor never has to guess.

---

## 1. Validation protocol (machine gate — run after EVERY task)

Godot console binary: `C:\Users\MARCO\Tools\Godot\Godot_v4.6.3-stable_win64_console.exe`

**Always `test -x` the binary first.** On 2026-07-04 it was missing and the shell error slipped past the log grep — two validation runs reported "clean" without Godot ever executing.

```bash
GODOT="/c/Users/MARCO/Tools/Godot/Godot_v4.6.3-stable_win64_console.exe"
PROJ="/c/Users/MARCO/Documents/GitHub/SAINT MANICK"   # path has a space — always quote

test -x "$GODOT" || { echo "BINARY MISSING — abort"; exit 1; }

"$GODOT" --headless --path "$PROJ" --import      > /tmp/imp.log   2>&1   # after ANY asset add
"$GODOT" --headless --path "$PROJ" --quit-after 300 > /tmp/smoke.log 2>&1   # main scene ~300 frames
"$GODOT" --headless --path "$PROJ" --script tests/run_tests.gd              # 51+ tests, exit 1 on fail

# WIDE grep — the narrow pattern historically missed shader + resource-load errors:
grep -iE "SCRIPT ERROR|Parse Error|Compile Error|Failed to load|SHADER ERROR|Failed loading resource|No loader found|Blender path|clash|renamed|already in the scene|Load Error" /tmp/imp.log /tmp/smoke.log
```

Pass = exit 0 everywhere, zero grep hits, test count never decreases.

---

## 2. Already FIXED in the working tree (do not redo, do not revert)

### 2.1 Silent asset-import failure (the biggest find)
A stray `3D_Assets/neon_enforcers.blend` made the Blender importer fail headless, which **aborted the whole import queue with exit code 0** — every asset added since mid-June had no `.import` file: Nick's model never loaded, all 19 audio files silently no-opped. **Fix:** `project.godot` `[filesystem] import/blender/enabled=false`. Never re-enable while `.blend` sources live in `res://`. If an asset "doesn't exist" at runtime, check for a missing `.import` first.

### 2.2 Rim shader never compiled
`assets/shaders/neon_rim.gdshader` used Godot-3 `depth_draw_disabled` → whole shader silently dead, no faction rim glow. **Fixed to `depth_draw_never`.**

### 2.3 Logic bugs fixed (verify in playtests, don't reintroduce)
| Bug | Fix location |
|---|---|
| Pause didn't pause (scene root `PROCESS_MODE_ALWAYS` cascaded to all children) | `levels/slice/vertical_slice.gd` cleaned; Esc toggle lives ONLY in `ui/menus/pause_menu.gd _input()` |
| Boss bar + boss music at t=0 in Zone 1 | `headliner.gd` — announce moved into `activate_boss()` |
| Enforcer chased player from scene load | `enforcer.gd` — dormant until `zone_entered` matches SECTOR 07 (`is_active`) |
| BossMusicA/B never played; crossfade tweened silent players | `audio_manager.gd _on_boss_spawned()` starts both phase-locked (B at −80 dB) |
| Enforcer hijacked/killed the soundtrack | AudioManager gates boss music to `boss_name == "Headliner"` + `_boss_music_active` |
| Headliner double scrap (2000) | Awarded only in `headliner.gd _on_died()` |
| Results screen same frame as boss death | `headliner_state_dead.gd` delays `complete_run()` 2.5 s |
| `zones_cleared` could exceed 10 after death reloads | `game_manager.gd` `_zones_seen` dedup |
| Combo mashing whiffed (0.15 s window only) | `player_state_attack.gd` input buffering |
| Nick's GLB textures wiped by flat-white override | `character_visual.gd` — WHITE tint = keep imported materials |
| Bosses visually tiny in 6 m / 3 m capsules | Visual ×3 in `headliner.tscn`, ×1.5 in `enforcer.tscn` |

### 2.4 Standing invariants
Signals over direct calls · StateMachine pattern (add states, not if/elif) · projectile pooling (extend, don't bypass) · **no built-in spawn markers in `wave_spawner.tscn`** · fall = last safe ground + HP cost, never reload · no Node `@export` on Resources · no magic numbers (see `DamageInfo.HEAVY_THRESHOLD`).

---

## 3. GDD feature-parity audit (every claim below re-verified 2026-07-06)

### 3.1 At parity — leave alone
| GDD | Evidence (verified paths) |
|---|---|
| Beat-driven telegraphs, never player-gated (§1.3, §4.1) | Runner/Sniper/Enforcer/Headliner act on `SignalBus.beat`; Conductor ramps `target_bpm` |
| Depth locked 2.5D / unlocked top-down; jump suppressed top-down (§3.1, §3.5) | `player.gd` Path3D snapping; **`characters/player/camera_states/`**`state_transitioning.gd` swaps `current_path` (line ~45), `state_top_down.gd` sets `is_jump_enabled = false` (line 7–8); covered by `test_camera_fsm.gd` |
| Universal death rule; QTE/hazard/fall cost HP (§3.4, §5) | `HealthComponent.take_damage`, `respawn_or_game_over`, fall damage at last safe ground |
| No stamina; mash-friendly (§1.3, §3.2) | No stamina resource; input buffering |
| Run-or-die traversal (§3.4) | Zone 8 `escape_sequence.gd` + hazard set |
| Roguelite loop: persistent scrap, shop, boosters, results (§5) | `PlayerProfile`, `karens_shop.gd`, results/game-over screens |
| Boss phase shift + top-down bullet hell (§4.4) | Headliner FSM, `StateBulletHell`, pooled projectiles |
| Hit feedback + 12-segment battery HUD + beat pulse (§6.1) | `hit_stop.gd`, shake, `vfx/`, `hud.gd` |

### 3.2 Parity GAPS (roadmap drivers; all verified by grep 2026-07-06)
- **GAP-1 · Ability Bar absent** (§3.3, §6.1): no meter, no +4%/+9% fill, no decay, no spenders (EMP Dash-Cancel, Ground-Pound), no ultimates (Overclock, Bass Drop). Zero code hits. HUD's stamina-slot bar is currently occupied by the shield (GAP-8).
- **GAP-2 · Dash has no i-frames** (§3.2): `player_state_dash.gd` never sets `is_invincible` (verified); duration 0.15 s vs GDD ≈0.25 s. (Roll: current 0.4 s vs GDD ≈0.45 s — optional tune.)
- **GAP-3 · Named combo routes missing** (§3.2): generic 3-step chain only. Tri-Cut (A-A-A) / Launcher (A-A-B) / Sweeper (A-B-B) / Battery Ram (B-B) unimplemented. **`_core/components/combo_def.gd` (`input_chain`, `damage_multipliers`) and `PlayerProfile.unlocked_combos` exist as dead scaffolding** — `test_save_manager.gd` already covers `unlocked_combos` serialization.
- **GAP-4 · Single currency** (§5.1): no Rare Scrap, no Data Cores (zero code hits).
- **GAP-5 · Combo skill tree missing** (§5.2): shop = 3 linear stat buys + booster cycle. Depends on GAP-3.
- **GAP-6 · VCR drone-feed effects absent** (§6.2): no scanlines/chromatic aberration/glitch anywhere (zero hits). Half the visual identity.
- **GAP-7 · Double jump free** (§3.1): `can_double_jump` defaults true, never profile-gated; GDD says shop unlock.
- **GAP-8 · Shield occupies the ability bar's HUD slot** (§6.1): GDD wants shield as battery overlay; `estamina-*` textures belong to the Ability Bar.
- **GAP-9 · Bruiser isn't the GDD Bruiser** (§4.1): GDD = shielded, downbeat-only attacker, broken by B-B. Code = permanent contact hitbox from `_ready()` (verified `bruiser.gd`) — last hitbox-clarity violation.
- **GAP-10 · No combo max-out payoff** (§6.1): unbounded counter, no cap celebration; combo also never resets on damage taken (GDD says it should).

### 3.3 GDD-sanctioned OUT of slice scope — do not build
Parry · other district bosses · Karen final boss / camera-as-weapon / checkpoint choice · full 5-district world.

---

## 4. MACHINE TRACK — executable by any model/agent, no editor GUI

Rules: execute in order; run §1 after every task; test count only goes up; commit per task (conventional messages). Agent routing hints per `.claude/CLAUDE.md` are optional — inline execution is fine.

**M0 · Commit the review layer (30 min, do FIRST).**
33 modified + many untracked load-bearing files (`_core/audio_manager.gd`, `vertical_slice.gd`, `nick_visual.tscn`, `ui/menus/`, `vfx/`, `audio/`, `assets/`, `default_bus_layout.tres`…) are one careless `git clean` from oblivion. Commit in chunks: (1) assets+imports, (2) core fixes, (3) boss/audio logic, (4) UI, (5) docs. Delete or archive `Documents/Roadmap.md`.
✅ `git status` clean; 51/51.

**M1 · WorldEnvironment + glow.**
`vertical_slice.tscn` has no WorldEnvironment (verified). Add one via scene-text edit: `Environment` sub_resource with `glow_enabled = true`, glow HDR threshold ≈ 1.0, `tonemap_mode = 3` (ACES), `ambient_light_color` in the `#0A0A12` family. The rim shader's `rim_strength = 2.5` is designed for HDR bloom.
✅ Smoke clean. (Visual sign-off → H5.)

**M2 · Dash i-frames (GAP-2, trivial).**
`player_state_dash.gd`: `is_invincible = true` in `enter()` / `false` in `exit()` (mirror `player_state_roll.gd`); `dash_duration` 0.15 → 0.25 as `@export`. Optionally roll 0.4 → 0.45.
✅ New i-frame test (pattern: existing roll coverage); 52+/52+.

**M3 · Double jump behind shop unlock (GAP-7).**
`PlayerProfile`: `@export var double_jump_unlocked := false`. Gate in `player.gd _ready()`. Add "Double Jump — 200 scrap" purchase to `karens_shop.gd`.
✅ `test_save_manager.gd` extended; fresh profile can't double-jump.

**M4 · Named combo routes (GAP-3).**
Wire the dead scaffolding. Four `ComboDef` `.tres` files (Tri-Cut A-A-A, Launcher A-A-B, Sweeper A-B-B, Battery Ram B-B). In `player_state_attack.gd`, record the pressed light/heavy sequence (buffering already distinguishes them) and match per chain step: Launcher final = `is_launcher` + stronger up-knockback · Sweeper final = brief AoE (widened katana hitbox for that swing) · Battery Ram = 2-step, slow, new `DamageInfo` flag `is_guard_breaking = true`, long recovery. **Unmatched sequences still run the generic chain** (GDD pillar: mashing always works).
✅ Pure-logic tests for sequence→route resolution.

**M5 · Ability Bar (GAP-1 + GAP-8).**
New `_core/components/ability_bar.gd` on the player (mirror `player_combo_component.gd`): +4% light / +9% heavy on `player_hit_landed` (classify via `DamageInfo.HEAVY_THRESHOLD`); slow out-of-combat decay; constants exported. SignalBus: `ability_bar_changed(value)`, `ability_ready()`. Minimum spenders: **EMP Dash-Cancel** (≥25% bar: dash input during attack recovery cancels into StateDash) and **Bass Drop** (full bar: AoE burst that detonates on the next `SignalBus.downbeat`). HUD: shield moves to a battery overlay; the freed `estamina-*` bar becomes the ability meter; flash at 100%.
✅ Fill/decay/spend covered by pure tests; smoke clean.

**M6 · Bruiser rework (GAP-9).**
Port Runner's beat-synced `attack_step` telegraph (`runner.gd _on_beat`): idle → telegraph (one beat, `character_visual.update_rim_color()` exists for this) → active → recovery; attack on downbeats. Recommended (needs M4): guard state broken only by `is_guard_breaking` — reuse the shield-gate pattern from `enforcer_hurtbox.gd`. Tune via `bruiser_stats.tres`.
✅ Damage only during active step; tests green.

**M7 · Three currencies (GAP-4).**
`rare_scrap` + `data_cores` on GameManager (run) and PlayerProfile (persistent). Sources: Enforcer kill, Zone 8 escape completion, elevator clear → rare scrap; Headliner → 1 data core. `EnemyStats` gets `rare_scrap: int = 0`. Persist beside `persistent_scrap`; show on HUD next to `ScrapLabel` and on the results screen.
✅ `test_game_manager.gd` / `test_save_manager.gd` extended.

**M8 · Data-driven shop + combo tree (GAP-5).**
Rebuild `karens_shop.gd` around upgrade `Resource`s (id, name, cost, currency, prerequisite). Stat items = scrap; Sweeper/Battery Ram unlocks = rare scrap, gated on basics (routes check `PlayerProfile.unlocked_combos`; Tri-Cut/Launcher free); one data-core unique (e.g. +1 booster slot). Theme it to the `run_results_screen.tscn` standard while rebuilding (dark `#0A0A12`, cyan `Color(0,0.949,1)`, magenta `Color(1,0,0.667)`).
✅ Locked combos never trigger; prerequisites enforced.

**M9 · Input map + gamepad.**
`project.godot` has no `[input]` section (verified); actions are runtime-registered in `signal_bus.gd`, keyboard-only, jump = `ui_accept`. Define all actions in `[input]` with keyboard + gamepad (attack X/Y, jump A, dash RT/RB, roll B), add a real `jump` action, update the player states using `ui_accept`, delete `_register_input`.
✅ Smoke + tests clean. (Feel pass on hardware → H6.)

**M10 · VCR drone-feed overlay (GAP-6).**
Full-screen CanvasLayer + screen-space `.gdshader`: faint constant scanlines/grain; chromatic-aberration/glitch bursts on player damage and `camera_shift_requested`. Note: `HealthComponent.damaged` is a **per-node** signal, not on SignalBus — either connect via the player node, or (preferred, per the signals-over-direct-calls invariant) add `SignalBus.player_damaged(damage_info)` emitted from `hurtbox_3d.gd`/`health_component.gd` when `is_player`. Exported intensity params, subtle defaults, one master toggle. **Godot 4:** `depth_draw_never`, and remember a bad render_mode kills a shader silently — grep smoke log for `SHADER ERROR`.
✅ Shader compiles (no SHADER ERROR); toggle works.

**M11 · Combo cap spectacle + damage reset (GAP-10).**
Cap ×50 in `player_combo_component.gd`; at cap fire a neon glitch celebration (HUD tween + M10 burst). Add combo reset on player damage (`damaged` signal) per GDD.
✅ Tests for cap + damage-reset.

**M12 · Remaining menu theming.**
`pause_menu.tscn`, `game_over_screen.tscn` → results-screen standard (shop already themed in M8).
✅ Smoke clean.

**M13 · Per-zone lighting first pass.**
Zone-tinted light/fog variation via scene edits: 1–3 warm sodium + cyan, 4–6 saturated magenta/cyan, 7–9 cold white/blue, 10 stage lighting animated on `SignalBus.beat`. Sane defaults; final grading → H5.

**M14 · Docs sync (after the track lands).**
Update `TESTPLAN.md` with the new test cases/scenarios (dash i-frames, combo routes, ability bar, currencies, combo cap) and `README.md`'s feature list + run instructions to match the shipped state.
✅ Docs describe the actual build; no stale claims.

**Machine tasks blocked on human input:** animation_map fill (⛔ H1), BossMusicB repoint to `boss_headliner_phase2.ogg` (⛔ H4), katana `BoneAttachment3D` (⛔ H1 — needs the imported skeleton's hand-bone name).

---

## 5. HUMAN TRACK — needs the editor, eyes, ears, or authoring

**H1 · Mixamo clips: import + rename (Godot editor).**
FBXes under `Animations/` (incl. `Mirrored/`, `Pro Sword and Shield Pack/`) import every clip as `mixamo.com`.
1. Open the project in the editor (first open re-imports; FBX "Image_0" texture warnings are benign).
2. For each FBX: select it in FileSystem → **Import dock → Advanced…** → rename the clip to its semantic name → set **Loop** for idle/run/fall → Reimport.
3. Needed clip names (exactly these keys are requested by code): `idle, run, jump, fall, dash, roll, attack_light, attack_heavy, attack_combo, hit_react, death`.
4. Fill `animation_map` in `player.tscn`'s **PlayerAnimationController** inspector (key → clip name), or hand the mapping to a machine executor.
Done when: smoke log shows no "no clip mapped" warnings and Nick animates in-game.

**H2 · Nick model sign-off (editor viewport).**
Run the scene; check Nick against his 2 m capsule (`nick_visual.tscn` children at y = −1.0), feet on ground, katana (`NickKatana` in `player.tscn`) plausibly in hand. Adjust transforms in those two files. After H1, tell the machine track the skeleton's hand-bone name so it can do the `BoneAttachment3D` swap.

**H3 · Enemy model generation + approval.**
Run `/modelgen` per enemy (runner, bruiser, sniper, enforcer, headliner) — Stage 3B must use `--style neon --accent` (cyan `0.0 0.85 1.0` default, magenta brutes, orange explosives). Approve/reject aesthetics; a machine executor then builds `<name>_visual.tscn` mirroring `nick_visual.tscn` and swaps instances (capsules: grunts ≈2 m, enforcer 3 m, headliner 6 m — visuals must fill them).
Done when: each archetype is silhouette-distinguishable at gameplay camera distance.

**H4 · Real audio (authoring/sourcing — DAW or licensed packs).**
All 19 files in `audio/sfx|music|ambience/` are synthetic test tones. Replace **keeping the same filenames**, OGG **Vorbis** only (Godot won't load Opus-in-Ogg). Music on the Conductor grid: zones 128 BPM, boss 160 BPM. Additionally author `audio/music/boss_headliner_phase2.ogg` (160 BPM, same length/bar grid as phase A so the phase-locked crossfade stays aligned) — a machine executor then repoints BossMusicB in `headliner.tscn` and runs `--import`.
Done when: a full run has no test tones and the 50%-HP crossfade is audible.

**H5 · Visual grading sign-off (after M1/M13).**
Judge in the running game: rim glow reads (cyan Nick / magenta enemies), bloom not blown out, zones feel distinct, boss arena reacts to the beat. Direct a machine executor with concrete parameter changes, or tweak the Environment in-editor.

**H6 · Playtest gauntlet (hands + ears; after machine track lands).**
1. Fresh boot: NO boss bar/music in Zone 1; industrial track + ambience on entering Sector 01.
2. Esc mid-combat: world truly freezes; resume + Esc-again work.
3. Zones 1→3: music does not restart per zone.
4. Sector 07: Enforcer dormant until entry; bar appears; zone music continues; on kill, bar hides, music continues.
5. Die once mid-run, finish: results ≤ 10 zones, scrap sane (headliner 1000 once), rare scrap + data core present (post-M7).
6. Boss: phase 2 at 50% (magenta, 160 BPM, audible crossfade), death → 2.5 s hold → results.
7. Mash chains reliably; named routes trigger on exact strings; dash tanks a sniper laser (post-M2/M4).
8. Ability bar fills / dash-cancels / Bass Drop lands on a downbeat (post-M5).
9. Fall off a platform: last-ground respawn, −20 HP, no reload.
10. Full run on gamepad only (post-M9).
File findings as bugs; a machine executor fixes and re-runs §1.

---

## 6. Booby traps for every executor

1. **Do not revert:** `import/blender/enabled=false` · `depth_draw_never` · dormant-boss gating · pause-menu input ownership · WHITE-tint-keeps-textures.
2. **Never set `process_mode = ALWAYS` on a scene root** — cascades to children, silently breaks pause.
3. `.tscn` `load_steps` = ext + sub resources + 1; mismatches are tolerated silently — keep them correct.
4. AudioManager **no-ops on missing files by design** — silence ≠ wiring bug; check `.import` existence and `default_bus_layout.tres` (Music −6 dB, Ambience −9 dB).
5. Test framework disconnects all SignalBus connections in `after_each()` — reconnect explicitly (see `test_game_manager.gd test_enemies_and_zones_tracking`).
6. Zone names are `"SECTOR NN — DESCRIPTION"`; the audio parser takes the first positive-integer token. Keep the pattern.
7. Enforcer activation string-matches `"07"`/`"ENFORCER"` (`enforcer.gd _on_zone_entered`) — renaming Sector 07 requires updating it.
8. Player states self-heal a null `player` ref via `owner` in `enter()` — StateMachine `_ready()`-order workaround; keep it in new states.
9. `ComboDef` + `PlayerProfile.unlocked_combos` are dead scaffolding **wired by M4/M8** — don't delete as "unused"; `test_save_manager.gd` already asserts their serialization.
10. Camera FSM states live in `characters/player/camera_states/` (not the player StateMachine) — `state_top_down.gd` suppresses jump, `state_transitioning.gd` swaps `current_path`.
