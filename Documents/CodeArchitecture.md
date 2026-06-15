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

---

## 10. Combat Contract: Hitboxes, Hurtboxes & Damage
Standardize how damage flows so every attacker/victim is interchangeable.
- **Hurtbox / Hitbox:** Reusable component nodes built on `Area3D`. A `Hitbox` (on an attack) overlaps a `Hurtbox` (on a victim) and calls `hurtbox.take_hit(damage_info)`.
- **DamageInfo:** A lightweight `Resource` (or `RefCounted`) carrying `amount`, `knockback`, `stun`, `is_shield_breaker`, `source`. No raw ints passed around.
- **Death rule lives in one place:** The `HealthComponent` implements the universal rule (shield → HP; HP 0 → lose a life & respawn; 0 HP + 0 lives → permadeath) and emits `SignalBus.player_died` / `player_life_lost`. Hazards and QTE failures route through the *same* component — never a separate code path.

---

## 11. Persistence (SaveManager)
Meta-progression (Scrap, permanent upgrades, unlocked combos, Run Booster slots) must survive death and quit.
- **The Pattern:** A `SaveManager.gd` autoload reads/writes a single `save_data.tres` (or JSON) under `user://`.
- **Rule:** Only the SaveManager touches `user://`. Shop purchases mutate an in-memory `PlayerProfile` resource and request a save; runs read from it on start. The active run's volatile state (current HP, lives, run scrap) is **not** persisted — only meta-progression is.

---

## 12. Performance: Pooling for Bullet-Hell
Top-down phases spawn many projectiles; GDScript `instantiate()`/`queue_free()` churn will stutter.
- **Rule:** Projectiles (and other high-frequency spawns) come from an **object pool** — pre-instantiated, reset and reused, never freed mid-combat. Consider `MultiMeshInstance3D` for dense, identical bullet visuals.
