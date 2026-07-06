# Saint Manick — Claude Project Config

## Project
Godot 4, 2.5D Action-Roguelite Beat'em up. Vertical slice (Zones 1-10) complete.
Player character: Nick. Main scene: `levels/slice/vertical_slice.tscn`.

## Agent routing

**Orchestration layer (runs in Fable):**
- **`code-architect`** — Entry point for all non-trivial requests. Reviews scope, breaks down architectural implications, identifies which specialists to engage, orchestrates delegation to the right agent(s), and reviews the result. Handles triage, architecture decisions, cross-system impact analysis, docs updates, and end-of-session housekeeping.

**Specialist agents (routed by code-architect or called directly for trivial tasks):**

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

## Key constraints
- modelgen/assetforge meshes: always pass `--style neon --accent R G B` in Stage 3B — this project's art direction is neon rim, not baked textures (cyan `0.0 0.85 1.0` default, magenta for brutes, orange for explosives)
- Signals over direct node calls for cross-component communication
- StateMachine pattern for player/enemy behavior — add states, not if/elif chains
- Projectile pooling established in Zone 10 — extend it, don't bypass
- No built-in spawn markers in wave_spawner scenes (node-name clash bug)
- Fall detection: last safe ground + HP cost, not full reload
- No magic numbers — use Resource configs or constants
