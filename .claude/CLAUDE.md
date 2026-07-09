# Saint Manick — Claude Project Config

## Project
Godot **4.6.3** (Forward+), GDScript. 2.5D Action-Roguelite Beat'em up — this is a **3D project** filmed by a constrained camera: `CharacterBody3D`, `Area3D`, `Node3D`. Never `Node2D`/`CharacterBody2D`.
Vertical slice (Zones 1–10) complete. Player character: Nick. Main scene: `levels/slice/vertical_slice.tscn`.
Design source of truth: `Documents/GDD.md`. Full architecture contracts: `Documents/CodeArchitecture.md` — read §7 (Conductor) before touching anything beat-driven.

## Validation protocol (run after EVERY code change)
Console binary: `C:\Users\MARCO\Tools\Godot\Godot_v4.6.3-stable_win64_console.exe`. **`test -x` it first** — a missing binary has produced fake-clean pipelines (error went to the grep filter, exit 0). Project path contains a space — always quote.

```bash
GODOT="/c/Users/MARCO/Tools/Godot/Godot_v4.6.3-stable_win64_console.exe"
PROJ="/c/Users/MARCO/Documents/GitHub/SAINT MANICK"

test -x "$GODOT" || { echo "BINARY MISSING — abort"; exit 1; }
"$GODOT" --headless --path "$PROJ" --import          > /tmp/imp.log   2>&1
"$GODOT" --headless --path "$PROJ" --quit-after 300  > /tmp/smoke.log 2>&1   # main scene, ~300 frames
"$GODOT" --headless --path "$PROJ" --script tests/run_tests.gd               # exits 1 on failure

grep -iE "SCRIPT ERROR|Parse Error|Compile Error|Failed to load|SHADER ERROR|Failed loading resource|No loader found|Blender path|clash|renamed|already in the scene|Load Error" /tmp/imp.log /tmp/smoke.log
```

Pass = exit 0, zero grep hits, **tests ≥ 100 and never decreasing**, zero-warning smoke log (baseline is zero warnings — any new warning is a regression). Touching models/animation? Also grep `track|bone|skeleton|clip|animation` (case-insensitive).

**Audit executor/agent DONE claims by grep/log before building on them** — every executor round so far needed corrections a green test gate did not catch.

## Architecture (locked contracts — summary; full text in Documents/CodeArchitecture.md)
Autoloads (`_core/`): `SignalBus` · `Conductor` · `SaveManager` · `GameManager` · `HitStop` · `AudioManager`.

- **Conductor** is a programmable tempo engine — the *world's* heartbeat. Enemies, hazards, and HUD subscribe to `SignalBus.beat(layer, i)` / `downbeat` / `tempo_changed`; no gameplay system reads a clock or audio position directly. The player is never beat-validated. There is no canonical BPM (~128 is only the Slice's resting tempo).
- **Signals over direct node calls** — but SignalBus is for genuinely *global* events only. Parent↔child within one scene uses plain node signals, not the bus.
- **StateMachine pattern** (node-based HSM) for player/enemy/camera behavior — add states, not if/elif chains. The camera FSM (`characters/player/camera_states/`) owns the side-scroll↔top-down movement-constraint swap. Player states self-heal a null `player` ref via `owner` in `enter()`.
- **Damage flows one way:** `Hitbox` (Area3D) overlaps `Hurtbox` → `take_hit(DamageInfo)` → `HealthComponent` owns the universal death rule and emits bus signals. No raw ints; hazards/QTEs use the same path. `Hurtbox3D` auto-joins `player_hurtbox`/`enemy_hurtbox` groups in `_ready()` — custom hurtbox scripts must call `super._ready()` (AoE like Bass Drop targets by group).
- **No magic numbers** — `Resource` configs (`.tres`): enemy stats, `ComboDef` combos (`characters/player/combos/`), shop upgrades (`_core/persistence/shop_upgrades/`). First-pass values in `tools/balance_tool.html`, then mirrored to `.tres`.
- **SaveManager** is the only thing that touches `user://`; persists meta-progression only (never volatile run state).
- **Projectile pooling** (`_core/pool/`, established Zone 10) — extend it, don't bypass.
- Feature-based folders (`characters/enemies/<type>/`, `levels/<zone>/`, `ui/<feature>/`) — never a type-based `/Scripts` folder. Official Godot style-guide naming throughout; signals are past-tense verbs.

## Godot 4 / engine gotchas (each has already bitten)
- **A single failing importer aborts the ENTIRE import queue with exit 0** — that's why `import/blender/enabled=false` is set (don't revert). If new assets mysteriously "don't exist" at runtime, check for missing `.import` files first.
- **`.tscn` text edits:** property lines bind to the nearest node header above — insert whole node blocks after the previous node's last property; keep `load_steps` = ext + sub + 1; diff after every edit.
- **Shaders:** `depth_draw_never`, not `depth_draw_disabled` (Godot 3); `hint_screen_texture` uniform, not `SCREEN_TEXTURE`. A bad render_mode fails silently — material renders nothing, game still runs; only the log shows it.
- Cannot `@export var x: Node3D` on a script extending `Resource` — use a plain `var`.
- JoyButton enum: 11 = D-pad Up, 5 = Guide — roll is B (1), ultimate is LB (9).
- Test framework disconnects ALL SignalBus connections in `after_each()` — reconnect explicitly (pattern in `test_game_manager.gd`).
- A StateMachine calling `initial_state.enter()` from `_ready()` runs before a child state's `await owner.ready` completes — resolve owner-derived refs synchronously.
- No built-in spawn markers in wave_spawner scenes — base scenes must not pre-define children that level scenes also add (node-name clash).
- `HealthComponent.max_shield` defaults to **0** — shields are explicit (player from GameManager, Bruiser from `bruiser_stats.tres`).
- Zone names are `"SECTOR NN — DESCRIPTION"` — the audio parser reads the first integer; Enforcer activation string-matches `"07"`/`"ENFORCER"`.
- **`nick_body_v2.glb` is UNRIGGED** (static posed mesh) — the rigged body is `Animations/Pro Sword and Shield Pack/nick_body_v2.fbx` (33-bone Mixamo skeleton, `mixamorig_*`); clip library is `characters/player/nick_animations.tres` (semantic keys — don't rename). Probe ANY generated mesh for a Skeleton3D before wiring animation; assume nothing.

## Design rules (do not revert)
- **Heavy attacks are free** — the Ability Bar is a reward, never a cost gate on basic inputs (GDD §3.3).
- Dash/roll i-frames · dormant-boss gating · pause-menu Esc ownership · WHITE-tint-keeps-textures.
- `KatanaHitbox` is intentionally NOT parented to the katana visual — hit detection stays deterministic regardless of animation. Changing that is a design change, not a bugfix.
- Fall detection: last safe ground + HP cost, not full reload.
- Art direction is **neon rim, not baked textures** — modelgen/assetforge meshes always pass `--style neon --accent R G B` in Stage 3B (cyan `0.0 0.85 1.0` default, magenta for brutes, orange for explosives).
- Audio: OGG **Vorbis** only; music sits on the Conductor grid (zones 128 BPM, boss 160 BPM). AudioManager no-ops on missing files by design — check `.import` existence + `default_bus_layout.tres` (Music −6 dB, Ambience −9 dB) before suspecting wiring.

## Agent routing

**Orchestration layer (runs in Fable):**
- **`code-architect`** — Entry point for all non-trivial requests. Reviews scope, breaks down architectural implications, identifies which specialists to engage, orchestrates delegation to the right agent(s), and reviews the result. Handles triage, architecture decisions, cross-system impact analysis, docs updates, and end-of-session housekeeping.

**Specialist agents:**

| Request type | Specialist agent |
|---|---|
| Feature implementation, refactor, multi-file bugfix | `senior-dev` |
| UI scene, HUD, menu, theme, design review | `ui-designer` |
| Game feel, input windows, feedback, hitbox clarity | `ux-designer` |
| Manual testing, scenario-based bug hunting | `tester` |
| Code review, diff review, static analysis, test coverage | `qa-reviewer` |
| Combat mechanics, roguelite systems, balance, specs | `mechanics-designer` |
| Zone design, encounter flow, pacing, level layout | `level-designer` |
| UI icons, textures, sprites, 2D art generation | `artist-2d` |
| Character/enemy/prop 3D models, .glb pipeline | `artist-3d` |
| Hit sparks, screen shake, particles, shaders | `vfx-artist` |
| WorldEnvironment, SDFGI, bloom, tone mapping, lighting pipeline | `render-pipeline` |
| Custom shaders (.gdshader), rim lighting, dissolve, hit flash | `shader-artist` |
| SFX briefs, music structure, audio wiring | `audio-designer` |
| Dialogue, lore, boss intros, item copy, tone | `narrative-designer` |
| "where is X" / "what was decided about Y" / "how does Z work" | `librarian` |

**Routing default: spawn the specialist directly.** If a request clearly maps to one row above, spawn that agent straight from the calling session — don't hop through `code-architect` first, it just re-derives context the specialist will derive again. Reserve `code-architect` for requests that are genuinely ambiguous, span multiple specialists, or have cross-system architectural impact (new autoload, new shared pattern, anything touching how systems talk to each other).

**Knowledge lookups vs. implementation:** a question ("does X exist", "how does Y connect", "why was Z built this way") is not the same task as changing code. Route knowledge questions to `librarian` before spawning an implementation specialist — it's cheap and often means the specialist doesn't need to spawn at all.

## Knowledge lookup decision tree (when to use what)

**Starting a feature or bugfix:**
- First: `Documents/HANDOFF.md` §3 for blockers, task status, remaining work
- Second: `Documents/CodeArchitecture.md` §X for the contract/pattern you're touching
- Third (if blocked): Search MemPalace for related prior decisions and gotchas

**"Why was X built this way?" / "What was the decision on Y?"**
→ Search MemPalace (`mempalace_search`). The decision, rationale, date, and session context live there. MemPalace holds pointers to docs, not copies — the design lives in `Documents/GDD.md`; the *why* lives in MemPalace.

**"Does this asset/zone/item exist?" / "What's in-use vs. superseded?"**
→ `ASSETS.md` (top-level) + per-folder `MANIFEST.md` (2D_Assets/, 3D_Assets/, etc.). Check here before generating duplicates.

**"How does this system work?" (code flow, signals, dependencies)**
→ Grep/Glob `.gd`/`.tscn` files directly. (graphify doesn't work here: no GDScript/Godot-scene support as of v0.9.9, doesn't extract actual game code.)

**"What should I test?" / "Is this tested?"**
→ Manual scenarios: `TESTPLAN.md` (by hand, by player feel). Automated: `tests/run_tests.gd` + cases in `tests/cases/`.

**"What was done last session?"**
→ MemPalace timeline (`mempalace_kg_timeline`) for architectural/design decisions, or `git log --oneline` for implementation commits.

**Design specs, narrative, balance numbers:**
→ `Documents/` folder (GDD.md, zone docs, etc.). MemPalace holds decision *pointers*, not copies.
