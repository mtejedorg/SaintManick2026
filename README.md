# Saint Manick

**Saint Manick** is a 2.5D Action-Roguelite Beat'em up set in a decadent, neon-drenched dystopian future. Players control **Nick**, a rogue corporate enforcer with a bionic arm and a katana, fighting through the radial districts of the city. Guided by **Karen** via a surveillance drone, Nick must fight his way to the great central tower. 

The game features classic heavy beat'em up combat blended with ambient rhythm mechanics, punishing roguelite meta-progression, and dynamic *Nier Automata* style camera shifts where the perspective smoothly transitions from 2.5D side-scrolling to Top-Down 3D bullet hells.

---

## Project Status: Vertical Slice Playable (Zones 1–10 complete)

Running on **Godot 4.6.3**. The full designed vertical slice is implemented end-to-end and has been dressed and audited through four rounds (round 4: 28 Oct 2026) — all 10 zones from the Factory floor to the Headliner rooftop, both bosses, the roguelite meta-loop, a title screen with a demo flow, a data-driven shop + combo skill tree, a game-feel layer, per-zone lighting, placeholder art and audio, and a self-verifying automated test suite (**610 tests, all green on 2026-10-28**).

**Functional Systems:**
- **Combat Contract:** `DamageInfo` resource flows `Hitbox3D → Hurtbox3D → HealthComponent`. `HealthComponent` owns the universal death rule (shield → HP → lose a life → permadeath only at 0 HP + 0 lives, shield regen 12/s after 3s) and roll/dash **i-frames**. A named collision-layer scheme prevents self-hits/friendly-fire.
- **The Ability Bar (reward, never a gate):** fills on landed hits (+4 light / +9 heavy, classified via `DamageInfo.HEAVY_THRESHOLD`, not a damage-scaled formula) and decays slowly out of combat. No basic input (move/jump/dash/roll/light/heavy) is ever gated by it — heavy is always heavy, even at 0 meter. Two real spenders: **EMP Dash-Cancel** (25 meter, cancels attack recovery straight into a dash) and **Bass Drop** (full meter, arms on input, detonates in an AoE on the next downbeat).
- **Combos & the Combo Skill Tree:** Tri-Cut (AAA) and Launcher (AAB) are unlocked on every profile from the start; Sweeper (ABB) and Battery Ram (BB) are purchased with Cells in Karen's Shop. Route data (damage/duration/knockback/flags) lives in `ComboDef` `.tres` resources, not hardcoded literals. The combo counter caps at ×50 with a neon glitch/explode celebration, and resets immediately if Nick takes damage.
- **The Conductor (tempo engine):** Autoload metronome emitting `SignalBus.beat / downbeat / tempo_changed`; **variable BPM** (the Headliner jumps 128→160 in phase 2) with meter-layer support. Every hazard/enemy/boss telegraph is beat-driven, including the Bruiser (telegraph one beat before, hitbox active only on the downbeat); the player is never required to act on the beat.
- **Camera HSM:** `Sidescroll / Transitioning / TopDown` state machine driven by `SignalBus.camera_shift_requested`; owns the 2.5D plane-lock and jump suppression and shifts both ways (used for the security room, the plaza ambush, and the Headliner's bullet-hell phase). Perspective shifts (and player damage) trigger a VCR chromatic-aberration burst on the drone-feed overlay.
- **Persistence:** `SaveManager` + `PlayerProfile` persist Scrap, Cells, Cores, unlocked combos, and permanent upgrades to `user://` (including a one-time migration for pre-rename saves); **Karen's Shop** is fully data-driven around `ShopUpgrade` resources and equips a Run Booster. Volatile run state is never persisted, and a demo run banks nothing.
- **Currencies:** Scrap (grunts), Cells/Rare Scrap (Enforcer kill, Zone 8 escape completion, Zone 9 elevator clear), Cores/Data Cores (district boss kill) — all tracked as GameManager run-totals, banked to the profile on game-over or full clear, shown on the HUD and run-results screen.
- **Enemy roster (data-driven `EnemyStats` `.tres`):** Runner, Bruiser (beat-gated telegraphed attacks, hyper-armor shield from `EnemyStats.shield`), Sniper (beat-locked laser), the **Rhythm Enforcer** mini-boss (beat-locked 3-hit bursts, shield-break) and the **Headliner** (multi-phase HSM with a pooled top-down bullet-hell). Knockback/stun and air-juggle launches are data-driven via `DamageInfo`.
- **Encounter & hazard systems:** reusable `ZoneEncounter` + `WaveSpawner` (camera-locked waves), and beat-driven hazards — ceiling pistons, bomb grid, sniper lasers, toxic pit, the Zone 8 escape gauntlet, and the Zone 9 ascending elevator.
- **Game feel:** hit-stop, screen-shake, roll/dash invincibility, combo counter, air juggles, and a VCR scanline/vignette/chromatic-aberration overlay.
- **Per-zone lighting:** zone-tinted `OmniLight3D`s (warm sodium/cyan for 1-3, magenta/cyan for 4-6, cold white/blue for 7-9) plus beat-animated stage lighting for Zone 10.
- **Object pool (`_core/pool`):** projectiles are pre-instantiated and reused, never freed mid-combat (bullet-hell performance).
- **Input:** a real `[input]` section in `project.godot` with keyboard + gamepad bindings for every action (jump/dash/roll/attack_light/attack_heavy/ability_ultimate).
- **Master sequence:** `vertical_slice.tscn` holds Zones 1–10 in one scene. The Enforcer's death arms the Zone 8 escape, then the Zone 9 elevator, the Headliner and the results screen. In a full run, Game Over leads to Karen's Shop; a demo offers RETRY or PLAY AGAIN, or the title, and banks nothing.
- **Front end:** a title screen with START DEMO (loadout pick, nothing banked), START RUN (the Level One stand-in: Karen's Shop, then the slice), OPTIONS and QUIT, plus an options menu, pause menu and results screens.

### Running & testing

The project requires **Godot 4.6**. Open `project.godot` in the editor and press Play, or from the CLI:

```
# Launch the game (opens the title screen)
godot --path .

# Launch the slice directly
godot --path . res://levels/slice/vertical_slice.tscn

# Compile-check all scripts (CI-style)
godot --headless --path . --import

# Smoke-run for 300 frames headless (catches scene/shader corruption tests can't see)
godot --headless --path . --quit-after 300                                          # title screen
godot --headless --path . --quit-after 300 res://levels/slice/vertical_slice.tscn   # the slice

# Run the automated test suite (exits non-zero on any failure)
godot --headless --path . --script tests/run_tests.gd
```

The runner prints `Total Tests Run: 610` and `Result: SUCCESS` on a green run.

Grep the import/smoke logs for `SCRIPT ERROR|Parse Error|Compile Error|Failed to load|SHADER ERROR|Failed loading resource|No loader found|Blender path|clash|renamed|already in the scene|Load Error` — the test suite validates logic but is blind to scene-property misplacement and silent shader compile failures.

See **`TESTPLAN.md`** for the automated-coverage table and the manual playtest/regression checklist.

---

## Next Steps / Remaining Polish

The designed slice's machine-track systems (combat, economy, shop, input, UI theming, per-zone lighting) are feature-complete; what remains is content that needs a human in the loop:

1. **Art & Animation:** the `NickProto.fbx` placeholder ships only a bind-pose clip — Mixamo clip rename + `animation_map` fill is still pending (expect `AnimationPlayer not found` warnings in the smoke log until then), then Nick model sign-off and the katana `BoneAttachment3D`. Swap the `CSGBox3D` block-outs for real Factory/Neon environment art.
2. **3D asset generation:** enemy models beyond the current placeholders (bruiser/runner/sniper/enforcer/headliner all use recolored placeholder meshes via `CharacterVisual`).
3. **Audio:** integrate real audio (SFX + the industrial-techno music stems, including `boss_headliner_phase2.ogg`) — `AudioManager` no-ops on missing files by design, so wiring is in place but silent until assets land.
4. **Visual grading pass:** re-check bloom/tone-mapping/per-zone lighting now that the DirectionalLight3D's transform/shadows are restored (C2) and now that all 10 zone lights are in.
5. **Playtest gauntlet:** full run-through checking heavy attacks work at 0 meter, Bass Drop lands cleanly on a downbeat, an old save keeps its banked scrap, and the combo skill tree gating feels right pacing-wise.
6. **Run Boosters & balance:** implement actual Run-Booster effects (selection already persists) and tune numbers in `tools/balance_tool.html` toward the 2–3 / 4–5 runs-to-clear targets.
7. **Front-end:** a main-menu/start screen and the diegetic heartbeat tempo readout.

---

## Directory Structure

- **`/_core`** - Autoloads (GameManager, Conductor, SignalBus, SaveManager, HitStop), modular Components (Health, Hit/Hurtbox, DamageInfo, combat/combo), the HSM base, `persistence/` (PlayerProfile, ShopUpgrade + `shop_upgrades/` resources), and the object `pool`.
- **`/characters`** - Player (controller, HSM states, camera-state machine, combo, `combos/` ComboDef resources) and Enemies (data-driven stats + HSM bosses, beat-gated Bruiser telegraph); `shared/` holds the reusable recolorable character visual.
- **`/levels`** - `slice/vertical_slice.tscn` (Zones 1–10, per-zone lighting, VCR overlay) and reusable `components/` (encounters, wave spawner, hazards, escape, elevator, stage lighting).
- **`/ui`** - The diegetic HUD (battery/shield overlay/ability bar/lives/beat pulse/currencies), the data-driven Karen's Shop (`ShopUpgrade`-based, combo skill tree), themed menus (pause/game-over/run-results), and `vcr/` (drone-feed overlay).
- **`/assets/shaders`** - Neon rim (spatial) and VCR overlay (canvas_item, screen-space) shaders.
- **`/tests`** - Self-contained GDScript test framework + cases (run headless; see TESTPLAN.md).
- **`/Documents`** - The definitive source of truth (GDD, VerticalSlice.md, CodeArchitecture.md, Roadmap.md).
- **`/UnityProject`** - The legacy Unity 5 prototype codebase (Deprecated).
- **`/2D_Assets`** & **`/3D_Assets`** - Art resources, textures, and the placeholder NickProto model.
