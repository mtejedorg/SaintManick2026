# Saint Manick — Claude Project Config

## Project
Godot **4.6.3** (Forward+), GDScript. 2.5D Action-Roguelite Beat'em up — this is a **3D project** filmed by a constrained camera: `CharacterBody3D`, `Area3D`, `Node3D`. Never `Node2D`/`CharacterBody2D`.
Vertical slice (Zones 1–10) complete, dressed and audited through round 4 (Oct 2026). Player character: Nick. Main scene: `ui/menus/title_screen.tscn`. Two entry points (owner direction 2026-10-27): **START DEMO** → loadout pick → the slice, no shop, nothing banked; **START RUN** → Level One (not built yet; stands in as Karen's Shop → the slice). Mid-term target: public demo first, then a production-quality Level One with the shop. The slice itself is `levels/slice/vertical_slice.tscn`.
Design source of truth: `Documents/GDD.md`. Full architecture contracts: `Documents/CodeArchitecture.md` — read §7 (Conductor) before touching anything beat-driven.

## Stack & toolchain
- **Engine:** Godot 4.6.3 stable, Forward+, GDScript only. Headless/console binary: `C:\Users\MARCO\Tools\Godot\Godot_v4.6.3-stable_win64_console.exe` (the validation protocol below depends on it).
- **Art generation:** local ComfyUI (`D:\AI\ComfyUI\ComfyUI_windows_portable_stable`) driven by the `assetforge` skill (2D art, one-shot meshes) and `modelgen` (full character pipeline; mesh backends in priority order Tripo → Rodin → Meshy → local TRELLIS). Blender cleanup runs over the Blender MCP socket on :9876.
- **Implementation executor:** multi-file work routes through the agent system (see Agent routing); `senior-dev` decides when to hand off to cravify/Antigravity. Never invoke cravify directly.
- **Knowledge infra:** MemPalace MCP (decision history) · `ASSETS.md` + per-folder `MANIFEST.md` (asset inventory) · `graphify-out/` (structure graph — caveats in Knowledge routing) · `Documents/` (design truth).
- **Commits:** conventional style with scope — `feat(player): …`, `fix(audio): …`, `docs(claude): …`. End of session → `/housekeeping` (`/hk`): commit, MemPalace sync, graphify-update flag.

## Repo map
```
_core/            autoloads + shared systems: components/, juice/, persistence/ (shop_upgrades/), pool/, state_machine/
characters/       player/ (states, camera_states/, combos/), enemies/<type>/, shared/
levels/           slice/vertical_slice.tscn (main scene), components/, factory/
ui/  vfx/  assets/  audio/   feature-based UI · effects · shaders+materials · OGG music+SFX
tests/            run_tests.gd + framework/ + cases/ (100+ assertions across ~42 case files)
Documents/        GDD.md · CodeArchitecture.md · HANDOFF.md · VerticalSlice.md · tools/balance_tool.html
2D_Assets/ 3D_Assets/ AIConcepts/   art source + generated output — each has a MANIFEST.md (index: ASSETS.md)
Animations/       Mixamo packs — incl. the RIGGED nick_body_v2.fbx (see gotchas)
old/  Build/  Renders_and_Videos/   archive & output — never edit, excluded from graphify
```

## Validation protocol (run after EVERY code change)
Console binary: `C:\Users\MARCO\Tools\Godot\Godot_v4.6.3-stable_win64_console.exe`. **`test -x` it first** — a missing binary has produced fake-clean pipelines (error went to the grep filter, exit 0). Project path contains a space — always quote.

```bash
GODOT="/c/Users/MARCO/Tools/Godot/Godot_v4.6.3-stable_win64_console.exe"
PROJ="/c/Users/MARCO/Documents/GitHub/SAINT MANICK"

test -x "$GODOT" || { echo "BINARY MISSING — abort"; exit 1; }
"$GODOT" --headless --path "$PROJ" --import          > /tmp/imp.log   2>&1
"$GODOT" --headless --path "$PROJ" --quit-after 300  > /tmp/smoke_title.log 2>&1                                   # main scene = title screen
"$GODOT" --headless --path "$PROJ" --quit-after 300 res://levels/slice/vertical_slice.tscn > /tmp/smoke.log 2>&1   # the slice, ~300 frames
"$GODOT" --headless --path "$PROJ" --script tests/run_tests.gd               # exits 1 on failure

grep -iE "SCRIPT ERROR|Parse Error|Compile Error|Failed to load|SHADER ERROR|Failed loading resource|No loader found|Blender path|clash|renamed|already in the scene|Load Error" /tmp/imp.log /tmp/smoke_title.log /tmp/smoke.log
```

Pass = exit 0, zero grep hits, **tests ≥ 200 and never decreasing** (610 as of 2026-10-28), zero-warning smoke logs apart from the three known exit-time audio-leak lines (`ObjectDB instances leaked`, `resources still in use`, `Lambda capture … freed`) — any new warning is a regression. The Zone 1 encounter now genuinely fires during the slice smoke (the player starts inside its trigger), so a spawner/encounter regression shows up here first.

**Visual gate (run after anything that touches scenes, materials, shaders, lights or models):** `"$GODOT" --path "$PROJ" res://tools/capture/capture_scene.tscn -- --out=res://Captures/<name>/` renders every zone at the real drone camera plus HUD, menus and a character lineup (window flashes ~40 s), and READ the PNGs. `tools/capture/probe_meshes.gd` (headless) prints skeleton/tris/bounds for candidate meshes; `tools/capture/mesh_gallery.gd` renders them; `tools/capture/probe_triggers.tscn` (headless) proves the player body trips the slice's triggers. `Captures/` is git-ignored. Touching models/animation? Also grep `track|bone|skeleton|clip|animation` (case-insensitive).

**Export gate (D32, run before any build you hand to someone):** templates live in `%APPDATA%\Godot\export_templates.6.3.stable\`; the preset is `export_presets.cfg` (committed; it excludes tests/, tools/, 2D_Assets/, AIConcepts/, Documents/, archives). `"$GODOT" --headless --path "$PROJ" --export-release "Windows Desktop" "Build/SaintManick_Demo/SaintManick.exe"` then smoke the exe itself: `Build/SaintManick_Demo/SaintManick.exe --headless --quit-after 300 --log-file <abs path>` (title) and the same with `-- --start-run` appended (the title screen jumps into the slice; release templates refuse a scene path); exit 0 and no `No loader found`/`Failed loading` lines in the log. Runtime assets must not live in excluded folders (the title logo moved to `ui/menus/art/` for exactly this reason - the exe smoke caught it, the editor never would).

**Audit executor/agent DONE claims by grep/log before building on them** — every executor round so far needed corrections a green test gate did not catch.

## Architecture (locked contracts — summary; full text in Documents/CodeArchitecture.md)
Autoloads (`_core/`): `SignalBus` · `Conductor` · `SaveManager` · `GameManager` · `HitStop` · `AudioManager`.

- **Conductor** is a programmable tempo engine — the *world's* heartbeat. Enemies, hazards, and HUD subscribe to `SignalBus.beat(layer, i)` / `downbeat` / `tempo_changed`; no gameplay system reads a clock or audio position directly. The player is never beat-validated. There is no canonical BPM (~128 is only the Slice's resting tempo).
- **Signals over direct node calls** — but SignalBus is for genuinely *global* events only. Parent↔child within one scene uses plain node signals, not the bus.
- **StateMachine pattern** (node-based HSM) for player/enemy/camera behavior — add states, not if/elif chains. The camera FSM (`characters/player/camera_states/`) owns the side-scroll↔top-down movement-constraint swap. Player states self-heal a null `player` ref via `owner` in `enter()`.
- **Damage flows one way:** `Hitbox` (Area3D) overlaps `Hurtbox` → `take_hit(DamageInfo)` → `HealthComponent` owns the universal death rule and emits bus signals. No raw ints; hazards/QTEs use the same path. `Hurtbox3D` auto-joins `player_hurtbox`/`enemy_hurtbox` groups in `_ready()` — custom hurtbox scripts must call `super._ready()` (AoE like Bass Drop targets by group).
- **No magic numbers** — `Resource` configs (`.tres`): enemy stats, `ComboDef` combos (`characters/player/combos/`), shop upgrades (`_core/persistence/shop_upgrades/`). First-pass values in `Documents/tools/balance_tool.html`, then mirrored to `.tres`.
- **SaveManager** is the only thing that touches `user://`; persists meta-progression only (never volatile run state).
- **Projectile pooling** (`_core/pool/`, established Zone 10) — extend it, don't bypass.
- **Physics layers:** world 1 · player body 2 · enemy bodies 3 (mask world+player+enemies) · hitboxes/hurtboxes 10–14. Any Area3D that must detect Nick's BODY masks layer 2; hitboxes mask the hurtbox layers. Until 2026-10-24 the player sat on layer 1 and no trigger in the slice ever fired — `tools/capture/probe_triggers.tscn` guards this.
- **Rails:** each zone's combat plane is a `Path3D`; `player.current_path` is a setter that eases Nick onto a new rail over 0.3 s; top-down shifts pass `null`. Rail ends must overlap the next trigger (`tests/cases/test_rail_reachability.gd`).
- Feature-based folders (`characters/enemies/<type>/`, `levels/<zone>/`, `ui/<feature>/`) — never a type-based `/Scripts` folder. Official Godot style-guide naming throughout; signals are past-tense verbs.

## Godot 4 / engine gotchas (each has already bitten)
- **Exports keep `editor/export/convert_text_resources_to_binary=false`** (project.godot): with the default conversion the exported `nick_visual.tscn` lost its `libraries/` AnimationLibrary and every Nick clip reported "not found" in the .exe while the editor was clean. The exe smoke caught it; do not flip it back without re-running the export gate.
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
- **Never pause the whole tree from a tool** (CSG never rebuilds, cameras never move → black frames); freeze with `process_mode = DISABLED` on the actors instead. `Area3D` signal callbacks must not `add_child` or flip `monitoring/monitorable` directly — `call_deferred`.
- **Legacy HUD PNGs in `2D_Assets/UI_and_Menus/` are full 1920×1080 canvases**; the cropped, ASCII-named copies the HUD uses live in `ui/hud/art/`. Never gate a texture load on `FileAccess.file_exists("res://…png")` — it is false in exported builds; use `ResourceLoader.exists`.
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

## Knowledge routing — files vs. MemPalace vs. graphify

Rule of thumb: **files hold the current truth · MemPalace holds the why · graphify holds the high-level shape.** When two sources disagree, the file (code/doc) wins — the others are derived.

| Question | Source |
|---|---|
| Code flow, signal wiring, dependencies — "how does this system work *now*?" | Grep/Glob `.gd`/`.tscn` directly. Code is the only source of truth for code. |
| Design specs, narrative, balance numbers | `Documents/` — GDD.md, VerticalSlice.md, zone docs |
| Task status, blockers, remaining work, booby traps | `Documents/HANDOFF.md` (§3 tasks, §4 traps) |
| Architecture contract/pattern being touched | `Documents/CodeArchitecture.md` (summary above) |
| "Why was X built this way?" / "What was decided about Y?" | MemPalace `mempalace_search` — decision, rationale, date, session context |
| "What was done last session?" | `mempalace_kg_timeline` (decisions) + `git log --oneline` (commits) |
| "Does this asset/zone/item exist?" / in-use vs. superseded | `ASSETS.md` → per-folder `MANIFEST.md`. Always check before generating. |
| Big-picture structure overview — "what are the core abstractions, how do modules cluster?" | `graphify-out/graph.json` / `graph.html` — with the caveats below |
| "What should I test?" / "Is this tested?" | Manual: `TESTPLAN.md`. Automated: `tests/run_tests.gd` + `tests/cases/` |

**MemPalace holds pointers, not copies** — the design lives in `Documents/GDD.md`; the *why* lives in MemPalace. New architectural/design decisions go into MemPalace at housekeeping, never into a parallel doc.

**graphify caveats (both have burned time before):**
- graphify has **no GDScript/Godot-scene extractor** (as of v0.9.9) — it never answers code-flow questions. For "how does X call Y", grep the code; don't open the graph.
- The graph is **refresh-on-demand and goes stale**: check the build date in `graphify-out/GRAPH_REPORT.md` against `git log` — if structural files changed since, treat it as stale and run `/graphify --update` (housekeeping flags this automatically). Scope is pinned by `.graphifyignore` to code/scene structure only (Documents/, assets, archives excluded — those route via the table above).

**Starting a feature or bugfix, in order:** HANDOFF §3 (is it blocked/done already?) → CodeArchitecture §X for the contract you're touching → MemPalace only if still blocked or the change contradicts a past decision.
