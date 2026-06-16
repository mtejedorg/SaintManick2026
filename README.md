# Saint Manick

**Saint Manick** is a 2.5D Action-Roguelite Beat'em up set in a decadent, neon-drenched dystopian future. Players control **Nick**, an android combat unit fighting through the radial districts of the city. Guided by **Karen** via a surveillance drone, Nick must fight his way to the great central tower. 

The game features classic heavy beat'em up combat blended with ambient rhythm mechanics, punishing roguelite meta-progression, and dynamic *Nier Automata* style camera shifts where the perspective seamlessly transitions from 2.5D side-scrolling to Top-Down 3D bullet hells.

---

## Project Status: Vertical Slice Playable (Zones 1–10 complete)

Running on **Godot 4.6**. The full designed vertical slice is implemented end-to-end — all 10 zones from the Factory floor to the Headliner rooftop, both bosses, the roguelite meta-loop, a game-feel layer, placeholder art, and a self-verifying automated test suite (**49 tests, all green**).

**Functional Systems:**
- **Combat Contract:** `DamageInfo` resource flows `Hitbox3D → Hurtbox3D → HealthComponent`. `HealthComponent` owns the universal death rule (shield → HP → lose a life → permadeath only at 0 HP + 0 lives, shield regen 12/s after 3s) and roll **i-frames**. A named collision-layer scheme prevents self-hits/friendly-fire.
- **The Conductor (tempo engine):** Autoload metronome emitting `SignalBus.beat / downbeat / tempo_changed`; **variable BPM** (the Headliner ramps 128→160 in phase 2) with meter-layer support. Every hazard/enemy/boss telegraph is beat-driven; the player is never required to act on the beat.
- **Camera HSM:** `Sidescroll / Transitioning / TopDown` state machine driven by `SignalBus.camera_shift_requested`; owns the 2.5D plane-lock and jump suppression and shifts both ways (used for the security room, the plaza ambush, and the Headliner's bullet-hell phase).
- **Persistence:** `SaveManager` + `PlayerProfile` persist Scrap and permanent upgrades to `user://`; **Karen's Shop** spends them and equips a Run Booster. Volatile run state is never persisted.
- **Enemy roster (data-driven `EnemyStats` `.tres`):** Runner, Bruiser, Sniper (beat-locked laser), the **Rhythm Enforcer** mini-boss (beat-locked 3-hit bursts, shield-break) and the **Headliner** (multi-phase HSM with a pooled top-down bullet-hell). Knockback/stun and air-juggle launches are data-driven via `DamageInfo`.
- **Encounter & hazard systems:** reusable `ZoneEncounter` + `WaveSpawner` (camera-locked waves), and beat-driven hazards — ceiling pistons, bomb grid, sniper lasers, toxic pit, the Zone 8 escape gauntlet, and the Zone 9 ascending elevator.
- **Game feel:** hit-stop, screen-shake, roll invincibility, combo counter, and air juggles.
- **Object pool (`_core/pool`):** projectiles are pre-instantiated and reused, never freed mid-combat (bullet-hell performance).
- **Master sequence:** `vertical_slice.tscn` chains Zones 1–7 (Slice A, → Enforcer → shop) into Zones 8–10 (Slice B: escape → elevator → Headliner → results), full meta-loop included.

### Running & testing

The project requires **Godot 4.6**. Open `project.godot` in the editor and press Play, or from the CLI:

```
# Launch the slice
godot --path . 

# Compile-check all scripts (CI-style)
godot --headless --path . --import

# Run the automated test suite (exits non-zero on any failure)
godot --headless --path . -s res://tests/run_tests.gd
```

See **`TESTPLAN.md`** for the automated-coverage table and the manual playtest/regression checklist.

---

## Next Steps / Remaining Polish

The designed slice is feature-complete; what remains is fidelity and tuning:

1. **Art & Animation:** the `NickProto.fbx` placeholder ships only a bind-pose clip — author run/dash/roll/attack animations and swap the `CSGBox3D` block-outs for real Factory/Neon environment art. Add the post-processing stack (bloom, chromatic aberration, retro grading).
2. **Audio:** integrate the industrial-techno stems, slaved to the Conductor (currently metronome-only by design).
3. **Run Boosters & balance:** implement actual Run-Booster effects (selection already persists) and tune numbers in `tools/balance_tool.html` toward the 2–3 / 4–5 runs-to-clear targets.
4. **Front-end:** a main-menu/start screen and the diegetic heartbeat tempo readout.

---

## Directory Structure

- **`/_core`** - Autoloads (GameManager, Conductor, SignalBus, SaveManager, HitStop), modular Components (Health, Hit/Hurtbox, DamageInfo, combat/combo), the HSM base, persistence, and the object `pool`.
- **`/characters`** - Player (controller, HSM states, camera-state machine, combo) and Enemies (data-driven stats + HSM bosses); `shared/` holds the reusable recolorable character visual.
- **`/levels`** - `slice/vertical_slice.tscn` (Zones 1–10) and reusable `components/` (encounters, wave spawner, hazards, escape, elevator).
- **`/ui`** - The diegetic HUD (battery/shield/lives/beat pulse) and Karen's Shop.
- **`/tests`** - Self-contained GDScript test framework + cases (run headless; see TESTPLAN.md).
- **`/Documents`** - The definitive source of truth (GDD, VerticalSlice.md, CodeArchitecture.md, Roadmap.md).
- **`/UnityProject`** - The legacy Unity 5 prototype codebase (Deprecated).
- **`/2D_Assets`** & **`/3D_Assets`** - Art resources, textures, and the placeholder NickProto model.
