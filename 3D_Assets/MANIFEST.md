# 3D_Assets Manifest

Maintained by `artist-3d`. Check this before generating a new mesh — most duplicate-generation risk in this project lives here (see `generated/` and `enforcers_ai/` below). Append a row at handoff; don't let this drift from the folder — `code-architect` housekeeping flags drift, it doesn't silently fix it.

`used_by` is grep-verified against `*.tscn` (as of 2026-07-11) — not guessed. Fields marked `unverified` (tri count, palette) need the generating/reviewing artist to fill in; don't fabricate them.

## In use (wired into a scene — do not delete without updating the scene first)

| File | Size | used_by | Tris | Accent |
|---|---|---|---|---|
| `../Animations/Pro Sword and Shield Pack/nick_body_v2.fbx` (rigged, outside 3D_Assets) | — | **INTERIM enemy body (batch R, 2026-10-27):** `characters/shared/enemy_body_visual.tscn` -> Runner (x0.95, ~1.7 m) and Bruiser (1.3/1.22/1.22, ~2.2 m); also Nick via `nick_visual.tscn`. Clips from `characters/player/nick_animations.tres`, driven by `characters/shared/enemy_animator.gd` | 11,756, 33 bones (`mixamorig_*`), Skeleton3D verified by `probe_meshes.gd` | no texture: near-black base + magenta tint/rim on enemies; stands in until generated enemy meshes land |
| `Characters/Nick/NickProto.fbx` | — | `characters/shared/character_visual.tscn` — **no longer used by Runner/Bruiser** (batch R swapped them to the rigged body, 171,808 -> 11,756 tris each); kept for the CharacterVisual unit tests | 171,808, 75 bones, bind pose only (T-pose at runtime) | dark base + magenta rim (CharacterVisual tint) |
| `enforcers_ai/clean/Enforcer_Hammer.glb` | 503 KB | `characters/enemies/enforcer/enforcer_visual.tscn` (x1.51 -> 3.0 m, 2026-10-24) | 22,280 — static, unrigged | magenta rim 3.5; body surface's baked full-body pink emission (energy 4) is overridden with dark metal in the scene; the 280-tri pink "Wire" surface 1 is STRIPPED at load (`stripped_surfaces`, batch R4 — the rim overlay drew it as pale bars at the feet), 22,000 tris drawn |
| `generated/headliner_brutalizer_raw.glb` (+ `_0.png`) | 1.6 MB | `characters/enemies/headliner/headliner_visual.tscn` (rotated upright, x6 -> 6 m, 2026-10-24) | 11,276 — static, unrigged | texture kept; amber rim 4 (magenta in phase 2). Ships WITHOUT normals — CharacterVisual generates them at runtime |
| `Props_and_Misc/dron fbx 2.fbx` | — | `characters/enemies/sniper/sniper_visual.tscn` (x22 -> ~1.1 m, 2026-10-24) | 2,552 — static, empty "Take 001" clip | dark-metal override, orange rim |
| `Characters/Nick/nick_body_v2_0.png` | 915 KB | `characters/player/nick_visual.tscn` (texture) | n/a | **cyan #00F5FF (batch T6, 2026-10-28):** every pixel with hue 280-340 deg and saturation > 0.35 (164,567 of 1,048,576) hue-shifted to 184 deg, value kept; the rest untouched (pale low-saturation pink highlights remain). Re-import pending (done by the next `--import`). Original magenta kept as `Characters/Nick/nick_body_v2_0_magenta_backup.png` (unreferenced backup) |
| `Characters/Nick/nick_body_v2_0_magenta_backup.png` | 904 KB | — backup of the pre-T6 magenta texture; not referenced by any scene | n/a | magenta (original) |

## Characters/ — not currently wired (check before assuming stale)

| File | Size | Notes |
|---|---|---|
| `Props_and_Misc/nick_katana.glb` | 8.6 KB | **Orphaned 2026-07-11** — render probe found the mesh is degenerate: 172 verts forming a flat ~56 m × 0.85 m × 8.7 m ribbon centered on its origin (p50 vertex distance 19.5 m). In-game it rendered as a giant glow-plane across the zone. The `NickKatana`/`KatanaBoneAttachment` nodes were removed from `player.tscn`; the rigged body FBX (Mixamo Sword & Shield pack) has its **own sword baked into the skinned mesh**, which the animation clips were authored for — that is now the weapon visual. `KatanaHitbox` unaffected (never parented to the visual, by design). |
| `Characters/Nick/nick_bionic_arm.glb` | 24.6 KB | **Orphaned 2026-07-11** (commit `fe254a4`) — was instanced as a static, unrigged sibling in `nick_visual.tscn`; probe showed the geometry is degenerate (flat, untextured ~2.5m blob detached from the shoulder). Node deleted. Kept on disk pending HANDOFF option (c): a proper bionic arm skinned into the body mesh. The arm's *mechanical* identity now lives in `_core/components/hitbox_3d.gd`-driven `BionicArmHitbox` (commit `7232e70`), independent of this visual. |
| `Characters/Nick/nick_body.glb` | 13.4 KB | Same name/size as `generated/nick_body.glb` — likely the canonical copy of that pipeline output. Not referenced by any `.tscn` found. |
| `Characters/Nick/nick_body_v2.glb` | 1.24 MB | Larger revision of `nick_body.glb`. Not referenced directly (only its `_0.png` texture is). Confirm with senior-dev whether the mesh itself is pending integration or the texture-only reference is intentional. |
| `Characters/Nick/nick_body_v2.fbx` | — | FBX counterpart to `nick_body_v2.glb`. |
| `Characters/Nick/Nick.max` | — | 3ds Max source file — not a Godot-importable asset, source/reference only. |
| `Characters/Headliner/boss_brutalizer_base.glb` | 14.5 KB | **DEGENERATE — never wire.** Not referenced by any scene. The Headliner uses `generated/headliner_brutalizer_raw.glb` (see In use). |

## enforcers_ai/ — cleaned pipeline output vs. raw generation

| File | Size | Notes |
|---|---|---|
| `enforcers_ai/clean/Enforcer_Fists.glb` | 503 KB | Static, unrigged, 22,280 tris (2.1 m, pivot offset x~-3.2, cyan accent). Not wired. `generated/enforcer_fists_rigged.glb` is the rigged attempt. |
| `enforcers_ai/clean/Enforcer_Hammer.glb` | 503 KB | Static, unrigged, 22,280 tris (1.99 m, pivot at the feet). **IN USE** — see In use. |
| `enforcers_ai/clean/Enforcer_Sword.glb` | 503 KB | Static, unrigged, 22,280 tris (1.89 m, pivot x~+3.0, flat white). Not wired. |
| `enforcers_ai/clean/Weapon_FistL.glb` | 5.3 KB | |
| `enforcers_ai/clean/Weapon_FistR.glb` | 5.3 KB | |
| `enforcers_ai/clean/Weapon_Hammer.glb` | 12.5 KB | |
| `enforcers_ai/clean/Weapon_Katana.glb` | 8.8 KB | Possible duplicate of `Props_and_Misc/nick_katana.glb` (which is the one actually in-scene) — confirm before treating either as spare. |
| `enforcers_ai/enforcers_clean.blend` (+ `.blend1` backup) | 1.7 MB | Blender source for the clean/ exports above. |
| `enforcers_ai/fists_hunyuan.glb` | 5.8 MB | Raw Hunyuan3D generation output, pre-cleanup. |
| `enforcers_ai/hammer_hunyuan.glb` | 6.0 MB | Raw Hunyuan3D generation output, pre-cleanup. |
| `enforcers_ai/sword_hunyuan.glb` | 3.6 MB | Raw Hunyuan3D generation output, pre-cleanup. |

## generated/ — pipeline iteration history (cleanup candidates)

Not referenced by any scene (except `headliner_brutalizer_raw.glb`, IN USE since 2026-10-24). This looks like the raw output trail from multiple mesh-gen attempts across the modelgen/assetforge pipeline (TripoSR, TRELLIS, Hunyuan, ComfyUI backends) rather than shippable assets. **Do not delete without confirming with artist-3d/senior-dev** — but also don't treat any of these as "the" Enforcer/Nick mesh without checking scene wiring first; none of them currently are it.

| File | Size |
|---|---|
| `enforcer.glb` | 2.6 MB |
| `enforcer_v2.glb` | 2.2 MB |
| `enforcer_eval.glb` (+ `enforcer_eval_0.png`) | 1.4 MB |
| `enforcer_auto_test_hunyuan.glb` | 3.6 MB |
| `enforcer_fists_rigged.glb` | 742 KB |
| `enforcer_trellis.glb` (+ `enforcer_trellis_0.png`) | 326 KB |
| `enforcer_trellis_textured.glb` (+ `_0.png`) | 1.4 MB |
| `boss_brutalizer_base.glb` | 14.5 KB — identical size to `Characters/Headliner/boss_brutalizer_base.glb`. **DEGENERATE — never wire.** |
| `boss_brutalizer_base_comfyui.glb` (+ `_0.png`) | 1.6 MB |
| `nick_body.glb` | 13.4 KB — duplicate of `Characters/Nick/nick_body.glb` |
| `nick_body_comfyui.glb` (+ `_0.png`) | 918 KB |
| `nick_bionic_arm.glb` | 24.6 KB — duplicate of `Characters/Nick/nick_bionic_arm.glb` |
| `nick_bionic_arm_comfyui.glb` | 1.9 MB |
| `nick_katana.glb` | 8.6 KB — duplicate of `Props_and_Misc/nick_katana.glb` |
| `nick_katana_comfyui.glb` | 918 KB |
| `headliner_brutalizer_raw.glb` (+ `_0.png`) | 1.6 MB | Raw mesh-gen output from `AIConcepts/headliner_brutalizer_tpose_v2.png`. **IN USE (2026-10-24)** by `characters/enemies/headliner/headliner_visual.tscn` — see In use. 8892 verts / 11,276 tris, textured, no normals in the file. |
| `headliner_brutalizer_rigged.glb` | 19.7 KB | **DEGENERATE — never wire.** Rigged pass (22 bones) — **probe 2026-07-11: geometry destroyed**; decimated to 209 verts, a flat blob. Rig salvageable only as reference. |
| `headliner_brutalizer.glb` | 10.2 KB | **DEGENERATE — never wire.** "Polished" output — **probe 2026-07-11: unusable**. Same 209-vert flat blob as `_rigged`, AND the skeleton was stripped (no Skeleton3D). Same failure class as `nick_bionic_arm.glb`. **Do NOT wire this into the Headliner scene.** A rigged Headliner must be re-run from `_raw` with a sane decimation target for a 6 m boss. |

## Root-level

| File | Size | Notes |
|---|---|---|
| `neon_enforcers.blend` | 142 KB | Blender source, root level — relation to `enforcers_ai/enforcers_clean.blend` unconfirmed. |
| `neon_enforcers_beauty.png` | — | Render/beauty shot, reference only. |

## Poly budgets and material conventions
See `.claude/agents/artist-3d.md` — those are durable project conventions (not per-file state) and stay there, not duplicated here.
