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
"$GODOT" --headless --path "$PROJ" --quit-after 300   > /tmp/smoke_title.log 2>&1                                   # main scene = title screen
"$GODOT" --headless --path "$PROJ" --quit-after 300 res://levels/slice/vertical_slice.tscn > /tmp/smoke.log 2>&1   # the slice
"$GODOT" --headless --path "$PROJ" --script tests/run_tests.gd
```

On success, the suite outputs `Result: SUCCESS` and exits with process code `0`. If any assertions fail, it prints detailed error messages and exits with code `1`.

**Also grep both logs** for errors the test suite is blind to (design-contract violations aside — scene corruption, silent shader failures, missing loaders):

```bash
grep -iE "SCRIPT ERROR|Parse Error|Compile Error|Failed to load|SHADER ERROR|Failed loading resource|No loader found|Blender path|clash|renamed|already in the scene|Load Error" /tmp/imp.log /tmp/smoke_title.log /tmp/smoke.log
```

Pass = exit 0 on all commands, zero grep hits (the two exit-time leak lines are known), test count at or above the last known-good baseline (currently **261**). Visual gate: `tools/capture/capture_scene.tscn` (see `.claude/CLAUDE.md`).

---

## 2. Test Coverage Table

The automated suite consists of **218 test cases** across **38 test suites** (2026-10-24; regenerate this table with the snippet in the commit that produced it — counts `func test_` per file).

| Test Suite File | Test Cases | Covers |
| :--- | :---: | :--- |
| `test_ability_bar_logic.gd` | 6 | ability meter fill; heavy attack free at zero meter; battery ram sets guard breaking at zero meter; meter fill classifies by heavy threshold not damage scale; meter decays out of combat but not immediately; meter decay stops at zero |
| `test_ability_spenders.gd` | 7 | emp dash cancel consumes meter and transitions to dash; emp dash cancel fails without enough meter; hitbox disabled during recovery window; bass drop arms only at full meter; bass drop detonates on downbeat and resets meter; bass drop does not detonate without arming … |
| `test_audio_zones.gd` | 1 | tier for zone follows factory to neon arc |
| `test_boss_shield_absorb.gd` | 2 | headliner shield absorbs without stun or knockback; enforcer shield absorbs without stun or knockback |
| `test_bruiser.gd` | 5 | bruiser shield and guard break; bruiser hitbox inactive by default; bruiser telegraphs one beat before downbeat; bruiser hitbox active only on downbeat then recovers; bruiser does not telegraph out of range |
| `test_camera_fsm.gd` | 3 | initial state is sidescroll; transition to topdown; transition back to sidescroll |
| `test_ceiling_piston.gd` | 6 | downbeat triggers slam; slam beat is not driven by a local counter; cock back happens on beat four before the downbeat; beat offset staggers the slam beat; accelerated piston slams on beats one and three never a three beat cycle; slammed hitbox world aabb overlaps the floor to head height |
| `test_character_visual.gd` | 4 | white tint keeps model materials; non white tint applies one dark base; rim defaults overrides and flash returns; default rim by faction |
| `test_checkpoint_respawn.gd` | 7 | life loss does not reload scene in mode; checkpoint updates on zone entered; respawn teleports refills and emits player respawned; cleared encounter stays cleared after respawn; uncleared encounter resets and rearms on respawn; enforcer resets to dormant full hp on respawn … |
| `test_collision_layers.gd` | 5 | collision layer constants; player collision configuration; enemy collision configuration; hazard collision configuration; body root layers |
| `test_combo_hit_registration.gd` | 3 | single light attack hits runner in front; light chain registers every hit on a target still in the box; battery ram ends the chain without a third hit |
| `test_conductor.gd` | 3 | beat index progression and wrapping; downbeat emissions; tempo transition ramping |
| `test_damage_flow.gd` | 4 | active hitbox inflicts damage; inactive hitbox ignores overlaps; source populated with owner if unset; source remains unchanged if already set |
| `test_dodge_economy.gd` | 4 | cooldown blocks immediate redodge from idle; roll is vulnerable during recovery tail; beat aligned dodge grants meter and skips cooldown; emp dash cancel still works with cooldown active |
| `test_elevator_respawn.gd` | 3 | mid ride respawn resets platform waves and rearms the trigger; completed elevator is untouched by respawn; respawn before boarding does nothing |
| `test_enemy_stats.gd` | 5 | bruiser stats; runner stats; sniper stats; enforcer stats; headliner stats |
| `test_enemy_visual_scale.gd` | 4 | runner visual matches capsule; bruiser visual matches capsule; enforcer visual matches capsule; enforcer keeps its materials and telegraphs with rim and lean |
| `test_escape_kill_wall.gd` | 6 | wall is dormant in the authored scene; wall parks ten metres behind nick when the escape starts; respawn reparks the wall behind the checkpoint and keeps it moving; respawn before the escape leaves the wall alone; wall stops once it passes the end trigger; each damage beat shakes the camera |
| `test_game_manager.gd` | 12 | start new run resets and applies upgrades; scrap modification and spending; respawn or game over flow; enemies and zones tracking; cells and cores accumulate and reset; full clear banks scrap cells and cores … |
| `test_grunt_dormancy.gd` | 3 | runner below kill plane despawns silently; far runner stays dormant and near runner wakes on beat; slice at load rests at base tempo |
| `test_headliner_boss.gd` | 14 | object pool lifecycle; projectile hits and expiry; projectile range is relative to its spawn point; boss activation; boss shield breaker; boss phase transition … |
| `test_health_component.gd` | 6 | shield absorbs damage first; non shield breaker spillover; shield breaker bypasses shield; health cannot drop below zero and died signal; shield regen delay and processing; player routing to signal bus and game manager |
| `test_hud_layout.gd` | 6 | ability bar lives in lower row not floating; shield bar overlays battery not separate slot; ability bar uses ability art textures; hud reflects ability meter changes; hud has no input overlay; battery rect has texture after ready |
| `test_intensity_controller.gd` | 4 | tempo boost calculations; tempo boost clamp limit; boss suspension logic; dormant boss and miniboss hurtboxes excluded from count |
| `test_juice_combat.gd` | 17 | player roll invincibility; player dash invincibility; enemy knockback and stun; enemy air juggle launch; player combo counter; combo resets when player takes damage … |
| `test_level_fixes.gd` | 12 | z7 barrier is taller than a jump; zone4 trigger no longer overlaps the zone3 room; zone4 spawn markers stay over the catwalk; zone10 arena gate and walls span the whole dock; falling hazard reaches the floor and door closes flush; zone2 to zone3 gap is split by platform7 … |
| `test_player.gd` | 9 | fall returns to safe position and costs hp; up down ignored while plane locked; nick visual feet rest on capsule bottom; new rail is eased onto not snapped; stale play once does not override a later clip with idle; play fitted stretches the clip to the state duration … |
| `test_rail_reachability.gd` | 5 | every zone trigger lies inside its rails x range; consecutive rails overlap so nick is never snapped across a gap; elevator hands nick to the dock rail and boss gate closes behind him; player walking the zone8 rail boards the elevator; scene placed enemies stand on solid ground |
| `test_save_manager.gd` | 6 | fallback to default profile when missing; save and load profile; legacy persistent scrap migrates to scrap; multiple run boosters persist through save round trip; legacy single run booster migrates to array; legacy none run booster is not migrated |
| `test_shield_hierarchy.gd` | 5 | generic heavy pressures but does not zero a shield; battery ram zeroes the shield; generic heavy no longer launches; light attack shield damage unchanged; bass drop breaks boss shield state |
| `test_shop_and_combo_gating.gd` | 11 | tri cut and launcher free and available by default; sweeper and battery ram cost cells; unpurchased sweeper falls back to generic damage; purchased sweeper uses route data; booster slot upgrade costs one core and grants slot; shop scene loads and lists upgrades … |
| `test_slice_b_logic.gd` | 6 | flow rewire; escape activation; escape hazards damage non instant; elevator encounter movement and wave cooldown; elevator completion; door flashes one beat before closing |
| `test_sniper.gd` | 3 | beam widens through aim lock fire in range; no cycle when player beyond attack range; drone visual is dark metal orange rim and hovers |
| `test_trigger_physics.gd` | 1 | player body trips zone encounter through physics |
| `test_vcr_overlay.gd` | 4 | trigger burst sets aberration strength; burst decays over time; player damaged triggers burst; camera shift triggers burst |
| `test_wave_encounter.gd` | 3 | wave spawner clears wave on enemy tree exit; wave spawner honours named spawn marker; zone encounter gate locks and wave progression |
| `test_zone_atmosphere.gd` | 5 | lookup returns the zone 5 palette; all ten zones are defined and unknown zones are empty; zone number parses the first integer; zone entered targets the entered zones values and tweens the environment; private environment copy leaves the authored resource untouched |
| `test_zone_lighting.gd` | 8 | zone lights container and all ten lights exist; zone 10 stage light wired to stage light script; zone 10 stage light pulses on beat; zone 10 stage light cycles palette on downbeat; zone light coverage additions exist; zone 3 and 8 lights pulse with the beat … |

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
