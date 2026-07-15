# 3D_Assets Manifest

Maintained by `artist-3d`. Check this before generating a new mesh — most duplicate-generation risk in this project lives here (see `generated/` and `enforcers_ai/` below). Append a row at handoff; don't let this drift from the folder — `code-architect` housekeeping flags drift, it doesn't silently fix it.

`used_by` is grep-verified against `*.tscn` (as of 2026-07-11) — not guessed. Fields marked `unverified` (tri count, palette) need the generating/reviewing artist to fill in; don't fabricate them.

## In use (wired into a scene — do not delete without updating the scene first)

| File | Size | used_by | Tris | Accent |
|---|---|---|---|---|
| `Characters/Nick/NickProto.fbx` | — | `characters/shared/character_visual.tscn` | unverified | unverified |
| `Characters/Nick/nick_body_v2_0.png` | — | `characters/player/nick_visual.tscn` (texture) | n/a | unverified |

## Characters/ — not currently wired (check before assuming stale)

| File | Size | Notes |
|---|---|---|
| `Props_and_Misc/nick_katana.glb` | 8.6 KB | **Orphaned 2026-07-11** — render probe found the mesh is degenerate: 172 verts forming a flat ~56 m × 0.85 m × 8.7 m ribbon centered on its origin (p50 vertex distance 19.5 m). In-game it rendered as a giant glow-plane across the zone. The `NickKatana`/`KatanaBoneAttachment` nodes were removed from `player.tscn`; the rigged body FBX (Mixamo Sword & Shield pack) has its **own sword baked into the skinned mesh**, which the animation clips were authored for — that is now the weapon visual. `KatanaHitbox` unaffected (never parented to the visual, by design). |
| `Characters/Nick/nick_bionic_arm.glb` | 24.6 KB | **Orphaned 2026-07-11** (commit `fe254a4`) — was instanced as a static, unrigged sibling in `nick_visual.tscn`; probe showed the geometry is degenerate (flat, untextured ~2.5m blob detached from the shoulder). Node deleted. Kept on disk pending HANDOFF option (c): a proper bionic arm skinned into the body mesh. The arm's *mechanical* identity now lives in `_core/components/hitbox_3d.gd`-driven `BionicArmHitbox` (commit `7232e70`), independent of this visual. |
| `Characters/Nick/nick_body.glb` | 13.4 KB | Same name/size as `generated/nick_body.glb` — likely the canonical copy of that pipeline output. Not referenced by any `.tscn` found. |
| `Characters/Nick/nick_body_v2.glb` | 1.24 MB | Larger revision of `nick_body.glb`. Not referenced directly (only its `_0.png` texture is). Confirm with senior-dev whether the mesh itself is pending integration or the texture-only reference is intentional. |
| `Characters/Nick/nick_body_v2.fbx` | — | FBX counterpart to `nick_body_v2.glb`. |
| `Characters/Nick/Nick.max` | — | 3ds Max source file — not a Godot-importable asset, source/reference only. |
| `Characters/Headliner/boss_brutalizer_base.glb` | 14.5 KB | Zone 10 boss base mesh. Not referenced by any `.tscn` found — check with senior-dev/level-designer whether the Headliner encounter scene wires this some other way (e.g. runtime-loaded, not `ext_resource`). |

## enforcers_ai/ — cleaned pipeline output vs. raw generation

| File | Size | Notes |
|---|---|---|
| `enforcers_ai/clean/Enforcer_Fists.glb` | 503 KB | Cleaned/rigged variant — check with artist-3d whether this or `generated/enforcer_fists_rigged.glb` is canonical before generating a new one. |
| `enforcers_ai/clean/Enforcer_Hammer.glb` | 503 KB | |
| `enforcers_ai/clean/Enforcer_Sword.glb` | 503 KB | |
| `enforcers_ai/clean/Weapon_FistL.glb` | 5.3 KB | |
| `enforcers_ai/clean/Weapon_FistR.glb` | 5.3 KB | |
| `enforcers_ai/clean/Weapon_Hammer.glb` | 12.5 KB | |
| `enforcers_ai/clean/Weapon_Katana.glb` | 8.8 KB | Possible duplicate of `Props_and_Misc/nick_katana.glb` (which is the one actually in-scene) — confirm before treating either as spare. |
| `enforcers_ai/enforcers_clean.blend` (+ `.blend1` backup) | 1.7 MB | Blender source for the clean/ exports above. |
| `enforcers_ai/fists_hunyuan.glb` | 5.8 MB | Raw Hunyuan3D generation output, pre-cleanup. |
| `enforcers_ai/hammer_hunyuan.glb` | 6.0 MB | Raw Hunyuan3D generation output, pre-cleanup. |
| `enforcers_ai/sword_hunyuan.glb` | 3.6 MB | Raw Hunyuan3D generation output, pre-cleanup. |

## generated/ — pipeline iteration history (cleanup candidates)

Not referenced by any scene. This looks like the raw output trail from multiple mesh-gen attempts across the modelgen/assetforge pipeline (TripoSR, TRELLIS, Hunyuan, ComfyUI backends) rather than shippable assets. **Do not delete without confirming with artist-3d/senior-dev** — but also don't treat any of these as "the" Enforcer/Nick mesh without checking scene wiring first; none of them currently are it.

| File | Size |
|---|---|
| `enforcer.glb` | 2.6 MB |
| `enforcer_v2.glb` | 2.2 MB |
| `enforcer_eval.glb` (+ `enforcer_eval_0.png`) | 1.4 MB |
| `enforcer_auto_test_hunyuan.glb` | 3.6 MB |
| `enforcer_fists_rigged.glb` | 742 KB |
| `enforcer_trellis.glb` (+ `enforcer_trellis_0.png`) | 326 KB |
| `enforcer_trellis_textured.glb` (+ `_0.png`) | 1.4 MB |
| `boss_brutalizer_base.glb` | 14.5 KB — identical size to `Characters/Headliner/boss_brutalizer_base.glb`, likely the same file duplicated across folders |
| `boss_brutalizer_base_comfyui.glb` (+ `_0.png`) | 1.6 MB |
| `nick_body.glb` | 13.4 KB — duplicate of `Characters/Nick/nick_body.glb` |
| `nick_body_comfyui.glb` (+ `_0.png`) | 918 KB |
| `nick_bionic_arm.glb` | 24.6 KB — duplicate of `Characters/Nick/nick_bionic_arm.glb` |
| `nick_bionic_arm_comfyui.glb` | 1.9 MB |
| `nick_katana.glb` | 8.6 KB — duplicate of `Props_and_Misc/nick_katana.glb` |
| `nick_katana_comfyui.glb` | 918 KB |
| `headliner_brutalizer_raw.glb` (+ `_0.png`) | 1.6 MB | Raw mesh-gen output from `AIConcepts/headliner_brutalizer_tpose_v2.png`. **Probe 2026-07-11: this is the GOOD one** — 8892 verts, detailed textured mech with glowing accents. Needs scale (normalized ~1 m, lying horizontal) but is sound source material. |
| `headliner_brutalizer_rigged.glb` | 19.7 KB | Rigged pass (22 bones) — **probe 2026-07-11: geometry destroyed**; decimated to 209 verts, a flat blob. Rig salvageable only as reference. |
| `headliner_brutalizer.glb` | 10.2 KB | "Polished" output — **probe 2026-07-11: unusable**. Same 209-vert flat blob as `_rigged`, AND the skeleton was stripped (no Skeleton3D). Same failure class as `nick_bionic_arm.glb`. **Do NOT wire this into the Headliner scene.** The pipeline must be re-run from `_raw` with a sane decimation target for a 6 m boss. (Boss scene currently uses no mesh at all — capsule + shared `character_visual.tscn`.) |

## Root-level

| File | Size | Notes |
|---|---|---|
| `neon_enforcers.blend` | 142 KB | Blender source, root level — relation to `enforcers_ai/enforcers_clean.blend` unconfirmed. |
| `neon_enforcers_beauty.png` | — | Render/beauty shot, reference only. |

## Poly budgets and material conventions
See `.claude/agents/artist-3d.md` — those are durable project conventions (not per-file state) and stay there, not duplicated here.
