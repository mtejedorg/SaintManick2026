# Saint Manick Test Plan

This document outlines the testing architecture, runner instructions, and manual playtest regression procedures for **Saint Manick**.

---

## 1. Automated Headless Test Suite

Saint Manick features a self-contained, custom GDScript test framework designed to run headless and validate core gameplay and persistence logic.

### 1.1 Running Instructions

To execute the test suite from the command line, run the following commands (adjusting the path to your Godot binary as necessary). Always run all three — the import pass and smoke pass catch scene/shader corruption that the test suite itself cannot see:

```bash
GODOT="/c/Users/MARCO/Tools/Godot/Godot_v4.6.3-stable_win64_console.exe"
PROJ="/c/Users/MARCO/Documents/GitHub/SAINT MANICK"   # space in path — always quote

"$GODOT" --headless --path "$PROJ" --import           > /tmp/imp.log   2>&1
"$GODOT" --headless --path "$PROJ" --quit-after 300   > /tmp/smoke.log 2>&1
"$GODOT" --headless --path "$PROJ" --script tests/run_tests.gd
```

On success, the suite outputs `Result: SUCCESS` and exits with process code `0`. If any assertions fail, it prints detailed error messages and exits with code `1`.

**Also grep both logs** for errors the test suite is blind to (design-contract violations aside — scene corruption, silent shader failures, missing loaders):

```bash
grep -iE "SCRIPT ERROR|Parse Error|Compile Error|Failed to load|SHADER ERROR|Failed loading resource|No loader found|Blender path|clash|renamed|already in the scene|Load Error" /tmp/imp.log /tmp/smoke.log
```

Pass = exit 0 on all three commands, zero grep hits, test count at or above the last known-good baseline (currently **100**).

---

## 2. Test Coverage Table

The automated suite consists of **100 test cases** across **20 test suites**.

| Test Suite File | Test Cases | Objective / Verification |
| :--- | :---: | :--- |
| `test_health_component.gd` | 6 | Shield-first damage absorption, spillover to health, `is_shield_breaker` bypass, health clamping + `died` signal, shield regen delay, player signal routing. |
| `test_damage_flow.gd` | 4 | Active `Hitbox3D`/`Hurtbox3D` overlap damage, inactive hitbox no-op, `damage_info.source` auto-population and preservation. |
| `test_conductor.gd` | 3 | `beat_index` progression/downbeat wrapping, `measure_index` incrementing, BPM ramp toward target. |
| `test_game_manager.gd` | 7 | Run reset + upgrade scaling, scrap add/spend, respawn/game-over life decrement flow, enemy/zone tracking, **cells/cores accumulate + reset**, **full-clear and game-over currency banking (scrap + cells + core)**. |
| `test_save_manager.gd` | 3 | Profile serialization round-trip (now including default-unlocked starter combos), missing-file fallback, **one-time `persistent_scrap` → `scrap` migration from a legacy fixture save**. |
| `test_enemy_stats.gd` | 5 | `.tres` stat assertions for Bruiser/Runner/Sniper/Enforcer/Headliner. |
| `test_wave_encounter.gd` | 2 | `wave_cleared` emission, ZoneEncounter gate lock/unlock progression. |
| `test_collision_layers.gd` | 4 | 3D physics collision layer constants and per-scene layer/mask assignments. |
| `test_camera_fsm.gd` | 3 | Sidescroll → Transitioning → TopDown transitions, target tracking, jump-suppression/`current_path` updates. |
| `test_juice_combat.gd` | 12 | Roll/dash invincibility, enemy knockback + stun decay, launcher Y-pop, combo counter timeout/whiff-drop, combo route damage (Tri-Cut/Sweeper/Battery Ram), **resource-driven combo route data (C4)**, **Bruiser shield sourced from EnemyStats (C4)**, **combo reset on player damage (M11)**, **combo cap at 50 with `combo_capped` firing exactly once (M11)**, hit-stop time-scale recovery. |
| `test_slice_b_logic.gd` | 5 | Enforcer death rewiring, escape sequence camera/wall/end-zone, escape hazard periodic damage, elevator translation/waves/cooldown, elevator completion conditions. |
| `test_headliner_boss.gd` | 7 | Object pool lifecycle, pooled projectile hit/expiry, boss dormant→Shield activation, shield mitigation/break, Phase 2 top-down transition, Bullet Hell state + enrage transition, Death state + run completion. |
| `test_player.gd` | 1 | Fall-out-of-world returns to last safe position and costs HP (no infinite fall, no full reload). |
| `test_ability_bar_logic.gd` | 6 | Meter fill/cap, **heavy attack stays heavy at 0 meter (C1)**, **Battery Ram sets `is_guard_breaking` at 0 meter (C1)**, **fill classified via `DamageInfo.HEAVY_THRESHOLD` not damage scale (C5)**, **out-of-combat decay respecting the delay window (C5)**, decay never goes negative. |
| `test_ability_spenders.gd` | 7 | **EMP Dash-Cancel spends 25 meter and transitions to StateDash (M5b)**, fails gracefully without enough meter, hitbox on/off across the active/recovery boundary, **Bass Drop arms only at full meter, detonates on downbeat + resets meter, no-op without arming, AoE radius targeting (M5b)**. |
| `test_bruiser.gd` | 5 | Shield/guard-break absorption, **hitbox inactive by default (M6b)**, **telegraph arms one beat before the downbeat within range (M6b)**, **hitbox active only during the beat-gated active step then recovers (M6b)**, **no telegraph out of melee range (M6b)**. |
| `test_shop_and_combo_gating.gd` | 8 | **Tri-Cut/Launcher free + unlocked by default (M8)**, **Sweeper/Battery Ram cost cells (M8)**, locked route falls back to generic damage, unlocked route uses tuned route data, **booster-slot upgrade costs 1 core and grants +1 slot (M8)**, shop scene renders both upgrade lists, buying a combo spends currency + unlocks it, buying with an unmet prerequisite is rejected. |
| `test_vcr_overlay.gd` | 4 | **Burst sets/decays `aberration_strength` (M10)**, **`player_damaged` and `camera_shift_requested` each trigger a burst (M10)**. |
| `test_hud_layout.gd` | 4 | **Ability Bar lives in StatusContainer, not floating at HUD root (GAP-8/M12)**, **shield overlays the battery instead of a separate stamina slot (GAP-8/M12)**, ability bar's estamina textures are assigned, HUD reacts to `ability_meter_changed` post-move. |
| `test_zone_lighting.gd` | 4 | **All 10 zone-tinted `OmniLight3D`s exist under `ZoneLights` (M13)**, **Zone 10 carries the `stage_light.gd` script**, stage light pulses on beat and cycles its palette on downbeat. |

---

## 3. Manual Playtest Regression Checklist

For features and visual/game-feel parameters that cannot be fully validated programmatically, use the following checklist during manual playtests.

### 3.1 Movement & Physics
- [ ] **Basic Movement**: Check that the player moves left/right smoothly on the current Path3D.
- [ ] **Double Jump**: Verify double jump works in sidescroll mode (unlocked via the shop).
- [ ] **Dash & Roll**: Verify Dash and Roll trigger the correct states and move the player correctly, using the real `dash`/`roll` input actions (M9 — keyboard *and* gamepad).
- [ ] **Jump Constraints**: Check that jumping is fully disabled in Top-Down mode (e.g., during top-down encounters).
- [ ] **Gamepad Parity**: Verify jump/dash/roll/attack_light/attack_heavy/ability_ultimate all respond correctly on a connected gamepad, not just keyboard.

### 3.2 Visual & Camera
- [ ] **Camera Shifts**: Request top-down transitions (e.g., entering an encounter) and check that the camera smoothly shifts to the top-down perspective within `1.5` seconds, and triggers a VCR aberration burst (M10).
- [ ] **Camera Tracking**: Ensure the camera tracks the player smoothly without jittering.
- [ ] **Transition Boundaries**: Check that the screen borders block player movement or keep them in frame during combat encounters.
- [ ] **Per-Zone Lighting**: Walk Zones 1→10 and confirm the lighting identity shifts as designed — warm sodium/cyan (1-3), magenta/cyan (4-6), cold white/blue (7-9), beat-animated stage lighting (10).
- [ ] **VCR Overlay**: Confirm the constant scanline/vignette overlay is present and subtle, and that taking damage produces a brief chromatic-aberration burst.

### 3.3 Combat Flow & UI
- [ ] **Attack Input**: Verify light attack and heavy attack trigger animations and damage enemies. **Heavy must work even at 0 ability meter (C1) — this is a hard regression check.**
- [ ] **Health & Shield UI**: Verify that taking damage updates the health/shield UI immediately, and that the shield renders as an overlay directly on the battery segments (not a separate bar).
- [ ] **Ability Bar**: Confirm the Ability Bar occupies the old stamina slot, fills on landed hits (+4 light / +9 heavy), decays slowly out of combat, and is never a gate on any basic input.
- [ ] **Combo Counter**: Check that the combo counter increases on consecutive hits, drops after a 2.0s delay of no combat, drops immediately on a whiffed attack string, **and drops immediately when Nick takes damage (M11)**. Confirm the ×50 cap triggers the neon glitch/explode celebration exactly once.
- [ ] **Currency Display**: Confirm Cells and Cores tick up on the HUD (Enforcer kill, Zone 8/9 completion, Headliner kill) and appear on the run-results screen.
- [ ] **Shop Transition**: Confirm that losing all lives triggers a screen fade and transitions the player to Karen's Shop, themed to the dark/cyan/magenta standard.
- [ ] **Combo Skill Tree**: Confirm Tri-Cut/Launcher are unlocked from a fresh save, and Sweeper/Battery Ram require spending Cells in the shop before their tuned route (wider hitbox, higher damage, guard-break) becomes available in combat.

### 3.4 Combat Juice & Game-Feel
- [ ] **Hit-Stop (Freeze-Frame)**: Verify that landing a hit on an enemy causes a brief, satisfying time-freeze before returning to normal speed.
- [ ] **Camera Screen-Shake**: Check that landing player hits, ceiling piston slams, combo-cap celebrations, and other heavy impacts request and execute a dynamic camera screen-shake.
- [ ] **Roll/Dash Invincibility**: Verify that rolling/dashing provides full invincibility frames.
- [ ] **Enemy Knockback & Stun**: Ensure enemies are pushed back away from the player when hit and pause their AI behavior, movement, and beat actions for the duration of the stun.
- [ ] **Air-Juggle Launch**: Verify that launcher hits launch enemies vertically for air-juggles.
- [ ] **EMP Dash-Cancel**: During attack recovery, confirm a dash input (with ≥25 meter) cancels straight into a dash, skipping the remaining recovery frames.
- [ ] **Bass Drop**: At full meter, confirm the ability_ultimate input arms Bass Drop, it visibly waits, and detonates in an AoE burst exactly on the next downbeat, zeroing the meter.

### 3.5 Bruiser Telegraph (M6b)
- [ ] **No Untelegraphed Damage**: Confirm the Bruiser's hitbox is inactive while chasing/idle — no more contact damage from simply walking into it.
- [ ] **Telegraph**: Confirm the Bruiser flashes red one beat before its attack.
- [ ] **Active Window**: Confirm the hitbox is only live during the downbeat swing, then the Bruiser recovers before it can attack again.

### 3.6 Slice B: Escape & Elevator Flow
- [ ] **Miniboss Rewire**: Verify defeating the Rhythm Enforcer emits `miniboss_defeated`, awards scrap **and cells (M7b)**, without completing the run, transitioning camera smoothly to Path_Z8.
- [ ] **Escape Sequence**: Verify the kill wall starts moving behind the player, closing doors open/close on the beat, falling hazards telegraph for 2 beats before dropping, and the collapsing platform shakes on step. Completing it awards cells (M7b).
- [ ] **Non-instant Damage**: Verify that escape hazards only deal damage (not instant game-over).
- [ ] **Elevator Entry/Waves/Completion**: Verify camera shift to Path_Z9, sequential wave spawning with cooldowns, and completion at target Y with all waves cleared — awards cells (M7b).

### 3.7 Zone 10: "The Headliner" Boss Fight
- [ ] **Boss Activation**: Verify the boss stays dormant until the player enters `Zone10_Trigger` or the elevator encounter completes.
- [ ] **Arena Seal**: Verify the `LeftGate` collision seals the arena once activated.
- [ ] **Shield Phase (P1)**: Verify `StateShield` mitigates all non-shield-breaker damage.
- [ ] **Melee Loop**: Verify the beat-gated telegraph → lunge → melee hitbox sequence.
- [ ] **Shield Break & Recovery**: Verify a shield-breaker hit transitions to `StateRecovery` (vulnerable, 1.5x damage) for 2 beats.
- [ ] **Phase 2 Transition**: Verify the 50% HP threshold triggers `StateTransition`, top-down camera shift, and BPM ramp to 160.
- [ ] **Bullet Hell + Enrage**: Verify beat-driven projectile waves, and that breaking the shield in this phase triggers `StateEnraged` + camera shift back to sidescroll.
- [ ] **Death & Run Completion**: Verify `StateDead` disables collisions, awards scrap **and 1 core (M7b)**, and triggers `complete_run()`.
