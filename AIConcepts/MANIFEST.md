# AIConcepts Manifest

Maintained by `artist-3d` (primary consumer — these are T-pose source images for the mesh-gen pipeline: concept → T-pose refine → mesh). Check here before regenerating a concept image for a character that already has one.

## Nick
| File | Notes |
|---|---|
| `nick_body_tpose.png` | T-pose source, used for mesh generation. |
| `nick_final.png` / `nick_final_flipped.png` / `nick_final_v2.png` | Finalized concept art, not T-pose (posed/hero shots). `_flipped` is a mirrored variant. `_v2` supersedes `nick_final.png` — confirm with artist-3d before treating the v1 as current. |
| `nick_katana.png` | Weapon concept, corresponds to `3D_Assets/Props_and_Misc/nick_katana.glb`. |
| `nick_v2_a_cyan.png` / `nick_v2_b_magenta.png` / `nick_v2_c_violet.png` | Three accent-color variants of the v2 concept — Nick's canon accent is cyan per `.claude/agents/artist-3d.md`; the magenta/violet variants are exploration, not alternate canon. |
| `nick_variant_a_streetfighter.png` / `nick_variant_b_runner.png` / `nick_variant_c_underground.png` | Three early design-direction variants (pre-`nick_final`). Historical — kept for reference, not active source art. |

## Enforcer (enemy)
| File | Notes |
|---|---|
| `enforcer_tpose.png` / `enforcer_tpose_v2.png` | T-pose source images. `_v2` supersedes v1 — confirm before using v1. |
| `enforcer_refined.png` | Refined (SDXL img2img) pass on the concept. |
| `EnforcerFists.png` / `EnforcerHammer.png` / `EnforcerSword.png` | Per-weapon-variant concepts, correspond to `3D_Assets/enforcers_ai/clean/Enforcer_{Fists,Hammer,Sword}.glb`. |

## Headliner (Zone 10 boss)
| File | Notes |
|---|---|
| `headliner_brutalizer_tpose.png` / `headliner_brutalizer_tpose_v2.png` | T-pose source for the "Brutalizer" variant, corresponds to `3D_Assets/Characters/Headliner/boss_brutalizer_base.glb`. `_v2` is the latest (and currently has uncommitted local changes — see note above). |
| `headliner_variant_a_executive.png` / `headliner_variant_b_brutalizer.png` / `headliner_variant_c_phantom.png` | Three early design-direction variants. "Brutalizer" (variant B) is the one that got built — `executive`/`phantom` are unbuilt alternates, kept for reference. |
