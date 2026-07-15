# SAINT MANICK — Handoff rev. 6 (machine work COMPLETE — human track remains)

**Date:** 2026-07-11 (rev. 5: 2026-07-07)
**State (independently re-verified, not carried from executor reports):** import clean · smoke clean with **zero warnings** · **123/123 tests pass** (baseline raised from 100 by the T1–T7 improvement cycle — the ≥100 floor in §1 is now ≥123) · working tree clean (the previously dirty `headliner_brutalizer_tpose.png` was superseded by `_v2` and committed with the mesh-gen output in `f745b39`).

Everything a model can do headlessly is now done, reviewed, and committed. Three executor rounds ran against this handoff lineage:
1. **Antigravity (Gemini)** — machine-track base M1–M7. Review found 2 critical wrong decisions + 3 half-done tasks (see git history of rev. 4 and `fix(...)` commits `a8cc965`…`8a63907`).
2. **Sonnet dev agent, round 1** — corrections C1–C5 + M5b/M6b/M7b + M8–M14. Review verified everything; one defect found and fixed (`9cdaff5`, gamepad JoyButton indices).
3. **Sonnet dev agent, round 2** — animation pipeline (`91f117a`, `785a51d`). Review verified everything (details in §2). One under-flagged issue promoted to a task (§3, A1).

- **Engine:** Godot 4.6.3, Forward+ · **Main scene:** `levels/slice/vertical_slice.tscn` · **Design source of truth:** `Documents/GDD.md`
- Full task specs and history: `git log --oneline` from `c57dd34` onward; rev. 4 text in `git show 9e984bf:Documents/HANDOFF.md`.

---

## 1. Validation protocol (run after EVERY change — unchanged)

Godot console binary: `C:\Users\MARCO\Tools\Godot\Godot_v4.6.3-stable_win64_console.exe` — **`test -x` it first.**

```bash
GODOT="/c/Users/MARCO/Tools/Godot/Godot_v4.6.3-stable_win64_console.exe"
PROJ="/c/Users/MARCO/Documents/GitHub/SAINT MANICK"   # space in path — always quote

test -x "$GODOT" || { echo "BINARY MISSING — abort"; exit 1; }
"$GODOT" --headless --path "$PROJ" --import          > /tmp/imp.log   2>&1
"$GODOT" --headless --path "$PROJ" --quit-after 300  > /tmp/smoke.log 2>&1
"$GODOT" --headless --path "$PROJ" --script tests/run_tests.gd

grep -iE "SCRIPT ERROR|Parse Error|Compile Error|Failed to load|SHADER ERROR|Failed loading resource|No loader found|Blender path|clash|renamed|already in the scene|Load Error" /tmp/imp.log /tmp/smoke.log
# For anything touching models/animation, ALSO grep: "track|bone|skeleton|clip|animation" (case-insensitive)
```

Pass = exit 0, zero grep hits, **tests ≥ 123** and never decreasing. Current baseline has a **zero-warning smoke log** — any new warning is a regression.

---

## 2. What is DONE and verified (do not redo, do not revert)

**Combat & systems (rev. 3/4 machine track):** dash i-frames (0.25 s) · named combo routes from `ComboDef` resources (`characters/player/combos/*.tres`) with combo-tree gating via `PlayerProfile.unlocked_combos` (Tri-Cut/Launcher auto-granted; Sweeper/Battery Ram shop-purchased) · Ability Bar (+4 light/+9 heavy, out-of-combat decay, **never a cost gate on basic inputs**) with EMP Dash-Cancel (25) and Bass Drop (full bar, detonates on downbeat) · Bruiser: shield + guard-break hyper-armor + beat-synced telegraph (hitbox live only in ACTIVE step) · three currencies (`scrap`/`cells`=Rare Scrap/`cores`=Data Cores) earned at Enforcer/Zone 8/Zone 9/Headliner, persisted, on HUD + results · data-driven shop (`_core/persistence/shop_upgrades/*.tres`) · real `[input]` map with gamepad (roll = B/1, ultimate = LB/9 — corrected JoyButton indices, hardware-unverified) · VCR overlay shader · combo cap ×50 + reset-on-damage · themed menus, HUD slots per GDD §6.1 · per-zone lighting first pass · save migration recovering legacy `persistent_scrap` · docs synced.

**Animation (round 2, reviewed and verified 2026-07-07):**
- **Root cause discovered by probing:** `3D_Assets/Characters/Nick/nick_body_v2.glb` has **no skeleton at all** (static posed mesh) — animation was never going to work on it. The rigged source of truth is `Animations/Pro Sword and Shield Pack/nick_body_v2.fbx` (33-bone Mixamo skeleton, `mixamorig_*` underscore convention).
- `nick_visual.tscn` now instances the rigged FBX, reapplies the original diffuse (`nick_body_v2_0.png`) via `surface_material_override`, and attaches `characters/player/nick_animations.tres` — an AnimationLibrary with exactly the 11 semantic clips (`idle, run, jump, fall, dash, roll, attack_light, attack_heavy, attack_combo, hit_react, death`; loop on idle/run/fall). Mapping table in commit `91f117a`. No dedicated Mixamo dash clip exists — "dash" is a strafe substitute; flag for feel review.
- `player.tscn`'s `PlayerAnimationController.animation_map` filled 1:1; the long-standing "AnimationPlayer not found" warning is gone; `play("idle")` runs clean in smoke.
- Katana attachment (`785a51d`) was **superseded 2026-07-11**: the glb proved degenerate and the body mesh has its own baked-in sword — see H2. `KatanaHitbox` deliberately untouched throughout (still the fixed Area3D under `MeshInstance3D`) — gameplay hit detection unchanged by design.

**Improvement cycle T1–T7 (2026-07-09→11, reviewed and verified):**
- **T1 dodge economy** (`99f9750`): dash/roll i-frames end at ~60% of duration (vulnerable recovery tail) + dash cooldown; beat-aligned dodges grant an ability-meter bonus and skip the cooldown. Tests: `test_dodge_economy.gd`.
- **T2 shield hierarchy** (`047f34c`): only Battery Ram / Bass Drop are true shield-breakers (`is_shield_breaker`); generic heavies apply `shield_damage_multiplier = 2.0` with overflow-to-HP instead of insta-popping guards. Tests: `test_shield_hierarchy.gd`.
- **T3 checkpoint respawn** (`00b310d`): life loss teleports to the last zone trigger via GameManager checkpoint tracking — no full-run reload. Tests: `test_checkpoint_respawn.gd`.
- **T4 IntensityController** (`6e962a4`): child of Conductor; `target_bpm = 128 + min(active_enemies × 2, 16)`, sampled on primary beats, suspended during boss fights. **Dormancy contract:** scene-placed dormant bosses are excluded via `owner.is_active` / `owner.is_active_boss` — any future dormant enemy must expose one of these or it will inflate the tempo count. Tests: `test_intensity_controller.gd`.
- **T5 Bruiser window** (`0cc2abf`): swing hitbox deactivates on the next primary *beat* (~0.47 s), not the next downbeat (~1.9 s).
- **T6 bionic-arm hitbox** (`fe254a4` + `7232e70`): see A1 below.
- **T7 dead data** (`6e962a4`): unused `damage_multipliers` removed from `ComboDef` and all combo `.tres`.

---

## 3. REMAINING WORK — almost entirely human now

### A1 · Bionic arm — RESOLVED via option (a) (2026-07-11, `fe254a4` + `7232e70`)
A headless render probe settled the decision without eyes-on-game: `nick_bionic_arm.glb` was **degenerate geometry** (flat untextured ~2.5 m blob floating through Nick's head, frozen while the body animates), so option (b) would have bone-attached garbage. The `NickBionicArm` node is deleted; the rigged body's own right arm carries the look. Mechanically the arm now exists as `BionicArmHitbox` — heavy (B) attacks fire a punch hitbox (x 0.8 offset, 2× cross-section) distinct from the katana's blade (`7232e70`).
**Still open as option (c), folded into H2:** re-export the character with a proper bionic arm skinned into the body mesh — the visual duality (GDD §2.3) currently reads only through the body mesh's own arm.

### H2 · Nick visual sign-off (editor/eyes) — render-probe pass done 2026-07-11; three items resolved
Machine render probes (evidence PNGs were generated headless; findings independently re-verified):
1. ~~Body texture UVs~~ **RESOLVED** — diffuse reads correctly (hooded figure, glowing circuit panels), no smearing.
2. ~~Katana grip~~ **RESOLVED by removal** — `nick_katana.glb` turned out to be degenerate geometry (a flat ~56 m ribbon rendering as a giant glow-plane in-game). The attachment was removed; the rigged body FBX (Mixamo Sword & Shield pack) has its **own sword baked into the skinned mesh**, matched to every animation clip. `KatanaHitbox` untouched.
3. A1 decision above (resolved earlier).
4. ~~Scale/feet~~ **RESOLVED** — the rigged body rendered at 0.98 m with feet 0.67 m below the capsule. `nick_visual.tscn` now scales `NickBody` ×2.045 at y +0.368; bone-measured span is exactly −1.0 … +1.0 vs the 2 m capsule.
5. Animation feel (still human): clip choices (esp. strafe-as-dash) and transition snapping — only direct `play()`, no crossfades.
6. **NEW (probe findings for the eyes-on pass):**
   - Nick's accent panels and baked sword glow **magenta**, but canon is cyan Nick / magenta enemies (H5) — decide whether to retint the texture or accept it.
   - The body mesh has extra baked geometry: a scabbard-like stick at the back shoulder and the sword. Check they read fine in motion.

### H3 · Enemy models (human + modelgen pipeline)
Unchanged from rev. 3: generate distinct models per archetype (`/modelgen`, Stage 3B `--style neon --accent`, cyan default/magenta brutes/orange explosives), human approves, machine builds `<name>_visual.tscn` mirroring `nick_visual.tscn` and swaps instances. Capsules: grunts ≈2 m, Enforcer 3 m, Headliner 6 m. **New wrinkle from the round-2 discovery:** if enemies should ever animate, make sure the generated meshes are actually rigged before wiring — probe for a Skeleton3D first (nick's GLB wasn't; assume nothing).

### H4 · Real audio (human authoring/sourcing)
All 19 files in `audio/sfx|music|ambience/` are synthetic test tones. Replace keeping the same filenames, OGG **Vorbis** only. Music on the Conductor grid: zones 128 BPM, boss 160 BPM. Author `audio/music/boss_headliner_phase2.ogg` (160 BPM, same length/bar grid as phase A) — then a machine repoints `BossMusicB` in `headliner.tscn` and runs `--import`. New SFX hooks worth covering now: Bass Drop detonation, combo-cap celebration, EMP dash-cancel.

### H5 · Visual grading sign-off (eyes, after A1/H2)
Rim glow (cyan Nick / magenta enemies), bloom levels, per-zone light identity, Zone 10 beat-animated stage light, VCR overlay intensity (exported params on `ui/vcr/vcr_overlay.tscn`).

### H6 · Playtest gauntlet (hands + ears)
The rev. 3 list plus this cycle's additions — verify at minimum:
1. Fresh boot: no boss bar/music in Zone 1; Esc truly pauses; music doesn't restart across zones 1→3.
2. Sector 07 Enforcer dormancy/boss-bar behavior; boss phase 2 at 50% (visual + 160 BPM); death → 2.5 s hold → results.
3. **Heavy attacks work with an empty ability bar** (the Antigravity regression — must never return).
4. Named routes on exact strings; locked routes (Sweeper/Battery Ram pre-purchase) fall back to generic hits; buy them in the shop and confirm they unlock.
5. Ability bar: fills +4/+9, decays out of combat, EMP dash-cancel in recovery, Bass Drop arms at full and lands on a downbeat.
6. Bruiser: red rim one beat ahead, damage only during its active step, Battery Ram breaks its guard.
7. Currencies: full run banks scrap + cells (Enforcer/Zone 8/Zone 9) + 1 core (Headliner); shop prices in the right currencies; old save keeps its migrated scrap; +1 booster slot item works.
8. Combo caps at ×50 with celebration; resets when Nick takes damage.
9. Nick animates through idle/run/jump/roll/attacks; katana stays in hand; VCR glitch on damage and camera shifts.
10. Full run on gamepad **hardware**: jump A, attacks X/Y, dash RB, roll B, ultimate LB (indices were fixed blind — verify on a real pad).

---

## 4. Booby traps (cumulative — every executor reads this)

1. **Do not revert:** `import/blender/enabled=false` · `depth_draw_never` · dormant-boss gating · pause-menu Esc ownership · WHITE-tint-keeps-textures · dash/roll i-frames · heavy-attacks-are-free (GDD §3.3: the Ability Bar is a reward, never a cost gate on basic inputs).
2. **`nick_body_v2.glb` is UNRIGGED** — do not switch `nick_visual.tscn` back to it "for cleanliness"; the rigged body lives in `Animations/Pro Sword and Shield Pack/nick_body_v2.fbx`. The consolidated clip library is `characters/player/nick_animations.tres` (semantic keys, do not rename).
3. **.tscn text edits:** property lines bind to the nearest node header above — insert whole node blocks after the previous node's last property; `load_steps` = ext + sub + 1; diff after every edit. (The Antigravity light corruption happened exactly this way.)
4. **Executor reports lie by omission** — audit DONE claims by grep/log before building on them. All three rounds needed corrections a green test gate did not catch.
5. Godot 4 gotchas that already bit: `SCREEN_TEXTURE` → `hint_screen_texture` uniform · JoyButton enum (11 = D-pad Up, 5 = Guide — not B/shoulder) · a bad shader render_mode fails silently · a single failing importer aborts the whole import queue with exit 0.
6. AudioManager no-ops on missing files by design; check `.import` existence + `default_bus_layout.tres` (Music −6 dB, Ambience −9 dB) before suspecting wiring.
7. Test framework disconnects all SignalBus connections in `after_each()` — reconnect explicitly (pattern in `test_game_manager.gd`).
8. Zone names `"SECTOR NN — DESCRIPTION"` (audio parser reads first integer); Enforcer activation string-matches `"07"`/`"ENFORCER"`.
9. Player states self-heal a null `player` ref via `owner` in `enter()`; camera FSM lives in `characters/player/camera_states/`.
10. `HealthComponent.max_shield` defaults to **0** — shields are explicit (player from GameManager, Bruiser from `bruiser_stats.tres`).
11. `Hurtbox3D` auto-joins `player_hurtbox`/`enemy_hurtbox` groups in `_ready()` — Bass Drop and any future AoE target by group; custom hurtbox scripts must keep calling `super._ready()` or replicate it.
12. `KatanaHitbox` is intentionally NOT parented to the katana visual — hit detection stays deterministic regardless of animation. If someone later wants animation-driven hitboxes, that's a design change, not a bugfix.
