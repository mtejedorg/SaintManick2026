# Saint Manick: Code Architecture & Rules

This document outlines the strict coding standards and architectural patterns for the **Saint Manick** Godot 4 codebase. To maintain a clean, scalable, and bug-free project, all GDScript development must adhere to these rules.

## 1. The Godot Philosophy: Composition over Inheritance
Godot relies on a **Node Tree** paradigm. Instead of building massive, monolithic scripts attached to a single object (like a 2000-line `Player.gd`), we build features by composing small, single-purpose Nodes together as children.
- **Rule:** Scripts should be as small as possible. If a script is managing Health, Input, and State simultaneously, break it into smaller child nodes (e.g., `HealthComponent`, `InputHandler`).

---

## 2. Naming Conventions
We strictly follow the official Godot style guide:
- **Files & Folders:** `snake_case` (e.g., `player_controller.gd`, `main_menu.tscn`).
- **Nodes & Classes:** `PascalCase` (e.g., `PlayerController`, `SignalBus`).
- **Variables & Functions:** `snake_case` (e.g., `current_health`, `take_damage()`).
- **Constants:** `SCREAMING_SNAKE_CASE` (e.g., `MAX_SPEED`, `GRAVITY`).
- **Signals:** Past-tense `snake_case` verbs (e.g., `enemy_died`, `health_changed`).

---

## 3. Project Structure (Feature-Based)
Do not organize folders by file type (e.g., avoiding a massive `/Scripts` folder). Organize by **Feature**.
```text
res://
├── _core/                # Autoloads, Global Enums, SignalBus
├── characters/
│   ├── player/           # player.tscn, player.gd, animations
│   ├── enemies/
│   │   ├── runner/       # runner.tscn, runner.gd
│   │   └── bruiser/      # bruiser.tscn, bruiser.gd
├── levels/
│   └── factory/          # factory_zone_1.tscn, level_assets
└── ui/
    └── hud/              # hud.tscn, hud.gd
```

---

## 4. State Management (Hierarchical State Machines)
Combat mechanics (especially beat'em ups) require complex state tracking. We will use a **Node-Based Hierarchical State Machine (HSM)**.
- **The Pattern:** The parent entity (e.g., Player) has a child node called `StateMachine`. The `StateMachine` has child nodes for each state (`Idle`, `Run`, `Attack`, `Airborne`).
- **The Logic:** Only the *active* state node processes logic (`_physics_process`). When a state finishes (e.g., an attack animation ends), it tells the `StateMachine` to transition to the next state.
- **Why?** It completely eliminates massive `if/else` ladders in the main controller and makes adding new combos or enemy behaviors trivial.

---

## 5. Event Management (The Signal Bus)
To prevent tight coupling, scripts should rarely call methods on each other directly (e.g., the Player should not know the UI exists). We use a **Global Signal Bus**.
- **The Pattern:** An Autoload (Singleton) named `SignalBus.gd` holds definitions for all global game events.
- **Execution:**
  1. The Player takes damage and emits: `SignalBus.player_health_changed.emit(new_health)`
  2. The HUD script listens: `SignalBus.player_health_changed.connect(_on_health_changed)`
  3. The HUD updates itself. The Player and HUD remain completely decoupled.
- **Rule — global bus is for *global* events only.** The SignalBus is a convenience that becomes an untraceable god-object if abused. Use it **only** for genuinely cross-system events (player health → HUD, enemy died → score, beat → everything). For local parent↔child communication *within one scene* (e.g., a StateMachine telling its parent an animation finished), use **plain node signals**, not the bus.

---

## 6. Data Management (Resources)
Avoid hardcoding numbers (health, speed, combo damage, shop prices) inside scripts or scattering them across exported variables in the inspector.
- **The Pattern:** We use Custom Godot `Resource` scripts.
- **Execution:** Create a script `enemy_stats.gd` extending `Resource`. We then create `.tres` files for each enemy (e.g., `runner_stats.tres`, `bruiser_stats.tres`) and plug them into the enemy nodes. This allows designers to tweak balance universally without opening code files.
- **Source of truth for numbers:** First-pass values live in `tools/balance_tool.html`; once tuned, mirror them into the `.tres` files. Combos are data too — define combos/abilities as `Resource`s (`combo_def.gd`) so the Combo Skill Tree is data-driven.

---

## 7. The Conductor (Tempo Engine Autoload) — *the heart of the engine*
The beat is the **world's heartbeat**: it drives enemies and traps, **not** the player (see GDD §1.3). The Conductor is the single authority for it.

**Metronome-master, not track-slave.** The Conductor is a *programmable tempo engine*, not a reader of a fixed audio track. It owns its own running clock (driven by a high-resolution timer / accumulated `delta`, corrected against the audio output latency) and **emits the beat itself**. Recorded music, when it arrives, is aligned *to* the Conductor — never the other way around. This is what makes dynamic tempo possible.

- **Variable tempo:** The current BPM is a property that gameplay can change at runtime. An **IntensityController** raises/lowers tempo based on game state — enemy count, bullet-hell stage, boss phase — and the Conductor ramps smoothly (or snaps, per the cue) to the new BPM. There is **no single canonical BPM**; ~128 is only the Slice's resting tempo.
- **Polyrhythm via meter layers:** The Conductor runs one or more independent **meter layers**, each with its own subdivision (e.g., a 4/4 layer and a 3/4 layer). Each layer emits its own beat signal, so a boss can telegraph two patterns on conflicting meters simultaneously. Most content subscribes only to the primary layer.
- **Signals (global):**
  - `SignalBus.beat(layer, beat_index)` — every beat of a layer.
  - `SignalBus.downbeat(layer, measure_index)` — first beat of each measure.
  - `SignalBus.tempo_changed(new_bpm)` — when the IntensityController shifts tempo.
- **Consumers:** Enemy telegraphs, hazard timing (pistons, bombs, lasers), and HUD pulse subscribe to these signals only. **No gameplay system reads a clock or audio position directly** — they react to Conductor signals, keeping everything in lockstep across tempo changes.
- **Player independence:** Nothing the *player* does is validated against the beat. The Conductor exists purely to schedule the world.
- **Future audio reconciliation (note):** Recorded loops can't change tempo without pitch artifacts. When real music lands, the plan is tempo-locked stems crossfaded per intensity state (or middleware-style section switching), all slaved to the Conductor's clock. Building metronome-first deliberately avoids baking a fixed-tempo assumption into gameplay.

---

## 8. 2.5D Means 3D Nodes (Project Dimensionality)
This is a **3D project**, not a 2D one. The "2.5D" look is a 3D world filmed by a constrained camera.
- **Rule:** Characters are `CharacterBody3D`; hit/hurtboxes are `Area3D`; the world is built from `Node3D` scenes. Do **not** use `Node2D`/`CharacterBody2D`.
- **Plane-locking:** In side-scroll mode, movement is constrained to a single combat plane (Z-input ignored). In top-down mode the constraint is released and Nick moves freely on X/Z. This constraint swap is owned by the camera state machine (§9), not scattered across the player controller.

---

## 9. Camera-Mode State Machine
The 2.5D ↔ top-down shift is a first-class state machine, modeled with the same HSM pattern as combat (§4).
- **States:** `Sidescroll`, `Transitioning`, `TopDown`.
- **The Pattern:** `drone_camera.gd` hosts a `CameraStateMachine`. Trigger volumes (`Area3D`) in the level emit a request; the machine `Tween`s the camera transform over the transition and, on completion, flips the player's movement-constraint flag (plane-locked ↔ free-roam) and suppresses/enables jump.
- **Decoupling:** Levels never move the camera directly — they emit a signal the camera FSM responds to.
- **The handshake (batch H, Oct 2026):** when the shift lands the camera FSM emits `SignalBus.camera_shift_finished(top_down)`. Top-down encounters spawn their first wave and unlock their gates only on that signal (gates lock immediately); a checkpoint taken mid-shift records the *destination* mode. Nothing else may guess "the shift is over" from a timer.
- **Side-scroll framing (batch P):** the side-scroll state leads the player by 2.5 m in the facing direction and holds the camera height while Nick is airborne (2.5 m dead zone), so the ground never jumps on a hop. Top-down framing is unchanged.

---

## 10. Combat Contract: Hitboxes, Hurtboxes & Damage
Standardize how damage flows so every attacker/victim is interchangeable.
- **Hurtbox / Hitbox:** Reusable component nodes built on `Area3D`. A `Hitbox` (on an attack) overlaps a `Hurtbox` (on a victim) and calls `hurtbox.take_hit(damage_info)`.
- **DamageInfo:** A lightweight `RefCounted` carrying `amount`, `knockback`, `stun`, `is_shield_breaker`, `source`, `ignores_iframes`, `is_environmental`. No raw ints passed around.
- **Death rule lives in one place:** The `HealthComponent` implements the universal rule (shield → HP; HP 0 → lose a life & respawn; 0 HP + 0 lives → permadeath) and emits `SignalBus.player_died` / `player_life_lost`. Hazards and QTE failures route through the *same* component — never a separate code path.
- **The death sequence (batches J/K/P):** lethal hit → `HealthComponent` emits `player_died`, calls `GameManager.record_lethal_hit(damage_info)` (the killer's name) and `call_deferred`s `GameManager.begin_death_beat()` — the chain must never run inside the physics flush (§13). The death beat holds a 0.9 s real-time slow-motion stop (`DEATH_BEAT_SECONDS`, a banner "DESTROYED BY <killer>") while the player sits in `StateDead` with input locked; then `respawn_or_game_over()` spends a life, emits `player_life_lost`, the respawn banner, teleports to the checkpoint and emits `player_respawned`, or ends the run. Every deferred step carries a token (`_death_beat_token`); `cancel_death_beat()` (new run, abandon) invalidates it. Tests that kill Nick `await` one process frame before asserting.
- **Three kinds of invulnerability, never merged:** dodge i-frames (`Player.set_dodge_iframes`, which also drops the enemy-body layer from Nick's collision mask for the dodge only — restored on respawn); respawn/fall **grace** (`HealthComponent.grace_invincible`, granted by `GameManager.grant_respawn_grace`, weakref-safe, never touches the mask); and `DamageInfo.ignores_iframes` (a fall off the edge still costs HP through i-frames but not through grace). `DamageInfo.is_environmental` marks hazard ticks (pit) so a zero-knockback, zero-stun *attack* is still an attack.
- **Shields:** `HealthComponent.max_shield` defaults to 0; shields are explicit (player from GameManager, Bruiser from its stats). A hit fully absorbed by a shield emits `hit_blocked`, not `hit_landed`; the shield crossing to 0 emits `shield_broken(position)` once (steel burst, shake, SFX, rim restores).
- **Hit feedback is graded by `DamageInfo.amount`** in `HitStop` (light / heavy / finisher / kill), with the merge rule "longer and deeper wins"; a `replace` stop exists only for the death beat.

---

## 11. Persistence (SaveManager)
Meta-progression (Scrap, permanent upgrades, unlocked combos, Run Booster slots) must survive death and quit.
- **The Pattern:** A `SaveManager.gd` autoload reads/writes a single `save_data.tres` (or JSON) under `user://`.
- **Rule:** Only the SaveManager touches `user://`. Shop purchases mutate an in-memory `PlayerProfile` resource and request a save; runs read from it on start. The active run's volatile state (current HP, lives, run scrap) is **not** persisted — only meta-progression is. Writes are atomic with a `.bak` (batch H).
- **Demo mode (batch O, owner direction 2026-10-27):** `GameManager.start_new_run(demo := true)` sets `demo_mode`; a demo run banks nothing and saves nothing except settings (`post_run_scene()` returns the title, the shop otherwise; `_bank_run_currencies` is a no-op; `seen_controls`/hints stay in memory). Every route and Double Jump count as unlocked in a demo. Code that writes the profile must check `demo_mode` first.
- **Settings** (volumes, fullscreen, accessibility toggles) live in the profile and are applied by `SaveManager.apply_settings()` at autoload `_ready` (the title re-applies idempotently), so a scene launched directly still honours them.
- **Tests are hermetic:** the test runner swaps `SaveManager.save_path` to a temp profile before the first case and restores it afterwards; a test must never read or write `user://save_data.tres`.

---

## 12. Performance: Pooling for Bullet-Hell
Top-down phases spawn many projectiles; GDScript `instantiate()`/`queue_free()` churn will stutter.
- **Rule:** Projectiles (and other high-frequency spawns) come from an **object pool** — pre-instantiated, reset and reused, never freed mid-combat. Consider `MultiMeshInstance3D` for dense, identical bullet visuals.

---

## 13. The Physics-Flush Rule, Layers and Deferred Work (added Oct 2026 — every bite is in HANDOFF §4)
- **Never mutate physics state inside a physics callback.** `Area3D` `area_entered`/`body_entered` handlers (hitboxes, triggers, pools) must not `add_child`, free, or flip `monitoring`/`monitorable`/`use_collision` directly — use `set_deferred` / `call_deferred`. The lethal-hit → respawn chain is deferred for this reason (§10); `ObjectPool` and `ZoneEncounter` gates use `set_deferred`.
- **Every deferred spawn carries a generation token** (`ZoneEncounter._generation`, the elevator start, the death beat, onboarding prompts, staggered wave entries): a respawn or a new run bumps the generation and the stale callback returns early. No "is this still valid?" guessing by node state.
- **Physics layers:** world 1 · player body 2 · enemy bodies 3 (mask world + player + enemies) · hitboxes/hurtboxes 10–14. Any `Area3D` that must detect Nick's *body* masks layer 2; hitboxes mask the hurtbox layers only. `tools/capture/probe_triggers.tscn` proves the slice's triggers fire.
- **Timers are pause-safe and time-scale-safe by intent:** gameplay timers pause with the tree; the death beat, focus grace and hit-stop use real seconds (`ignore_time_scale`) so a hit-stop can never stretch them.
- **Rails:** `player.current_path` is a setter that eases Nick onto the rail; top-down passes `null`; rail ends must overlap the next trigger (`test_rail_reachability`). Gates and barriers stand at least 11.5 m above the floor (the double jump reaches ~11 m; `test_level_fixes` probes every gate).
- **Tuning is data:** player numbers live in `characters/player/player_tuning.tres` (`PlayerTuning`), enemy numbers in `*_stats.tres`, combos in `ComboDef` resources, run boosters in `_core/persistence/run_boosters/`. Tests assert invariants against the shipped resources, never hand-copied values; `Documents/tools/balance_tool.html` mirrors the resources and `test_balance_tool_parity` keeps it honest.
- **Global signals added since §5 was written:** `camera_shift_finished`, `banner_requested`, `boss_shield_changed`, `beat_dodge_landed`, `shield_broken`, `screen_flash_requested`, `enemy_telegraphed`. Each has a single emitter and documented listeners; a parent↔child concern never goes on the bus.
