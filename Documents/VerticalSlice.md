# Vertical Slice: Detailed Level Design (rev. 3 — 2026-10-26, matches the build)

*Numbers mirror the `.tres`/scene at commit 8937f29 (`levels/slice/vertical_slice.tscn`, `characters/enemies/*/*_stats.tres`, `characters/player/combos/*.tres`); where this document and a data file disagree, the file wins. World X positions below are scene coordinates.*

**Objective:** A playable demo that condenses the core pillars of *Saint Manick* — combat, the beat-driven world, camera shifts, platforming and the roguelite meta-loop — into one polished showcase. Scene: `levels/slice/vertical_slice.tscn`; zone names are `"SECTOR NN — NAME"` (the audio and boss activation read the number).

**Theme:** **Factory (Zones 1–4) → Neon District (Zones 5–10).** Audio and lighting follow that arc: industrial (1–4), neon market (5–7), neon high-rise ascent (8–9), the boss track (10).

**Music:** heavy industrial techno-metal. The Conductor rests at **128 BPM** and rises with enemy density (+2 per active enemy, cap +16); the Headliner's phase 2 runs at **160 BPM**. The tempo drives every hazard and telegraph; the player is never required to act on the beat (GDD §1.3). Current audio files are placeholder tones on the correct grid.

**Player loadout:** HP 120, shield 40, 3 lives, Dash and Roll, Tri-Cut and Launcher. **Sweeper and Battery Ram are shop unlocks** (GDD §5.2) — nothing in the slice requires them. **Double Jump ships unlocked in the demo build** (Decision D1; the Karen's Shop item stays as a [POST-SLICE] purchase, GDD §5.2). Before each run the player equips a Run Booster in Karen's Shop (title screen → shop → run).

---

## The Meta-Loop (present and verified)
1. Nick dies with 0 lives → a 0.9 s death beat → **Game Over** ("DESTROYED BY <enemy>") → **Karen's Shop** (currencies banked). Abandoning from pause banks them too.
2. The player spends **Scrap / Cells / Cores** on permanent upgrades and equips a Run Booster.
3. Nick re-enters from Zone 1, over-levelled for the early zones.
4. Numbers are tuned in `tools/balance_tool.html` toward 2–3 runs (average) / 4–5 (weaker). *The current yields (up to ≈2020 Scrap for a full clear, ≈4040 with Scrap Magnet; ≈35 Cells) are far above the tool's assumptions — see GDD Appendix B (D2, D4 deferred). The Zone 4 Snipers are non-blocking: they pay Scrap only if killed before the wave clears.*

> **Universal death rule (everywhere):** damage drains shield → HP. HP 0 costs a **life**: after the 0.9 s death beat (input locked, hit-stop, death clip) Nick respawns at the last zone checkpoint (full HP/shield, 1 s grace, ability bar emptied). Permadeath only at **HP 0 + 0 lives**. Hazards, falls (20 HP, back to the last safe ground, 0.5 s grace, "SIGNAL LOST" card) and escape failures obey the same rule.

---

## The Block-by-Block Path

### Zone 1 — SECTOR 01 · Street Entrance (2.5D, Factory floor)
- **Geometry:** 30 m straight corridor, no hazards. Depth locked. A pair of 12 m tall holo-gates (x −1.5 and x 28) soft-locks the corridor during the encounter and opens on clear with a "GO ->" card.
- **Enemies:** 3 Runners, one wave each, from two spawn points.
- **Purpose:** teach Light/Heavy, Jump and Dash/Roll against beat-telegraphed attacks. Control prompts show here until the player's first Zone 2 entry ever (D34).

### Zone 2 — SECTOR 02 · Piston Gauntlet (2.5D)
- **Geometry:** 60 m of six disconnected 5 m platforms over a toxic pit, with a short depth dip in the rail; a seventh platform bridges the last gap to Zone 3.
- **Hazards:** 6 ceiling pistons that cock back on beat 4 and **slam on the downbeat**, cascading one beat apart; the last three accelerate to every two beats as Nick approaches. The pit deals **5 damage per beat** while Nick (or a knocked-in grunt) stands in it; its floor lets him climb back out.
- **Enemies:** 3 Runners, on platforms 2, 4 and 6 — fight them or juggle them into the pit.

### Zone 3 — SECTOR 03 · Security Lock (top-down)
- **Geometry:** 25×25 m room. Entering the centre locks both blast doors (red holo gates) and the drone climbs to the top-down view (offset (0, 12, 4.5), cyan ground ring under Nick); depth movement unlocks, jump is suppressed.
- **Enemies:** wave 1 — 4 Runners from the corners; wave 2 — 3 Runners (the Bruiser's debut moved to Zone 4, D9/D16). Dodge bombs while you fight.
- **Hazard:** the bomb grid — a 5×5 checkerboard; one set warns for a measure (amber) and ignites on the next downbeat (red), so safe cells alternate **every measure**. Active only while the encounter runs.
- **Exit:** gates open; the drone returns to 2.5D and depth re-locks.

### Zone 4 — SECTOR 04 · Scaffolding & Vista (2.5D)
- **Geometry:** ~50 m of catwalk (x 122.5–173) with two plank gaps and recovery ledges beneath (plank gaps: Decision D24 deferred), soft-locked by a 12 m tall holo-gate pair (x 130 and x 160) that opens on clear with the GO card. The **Central Tower** and a skyline of neon-strip towers stand in the fog behind.
- **Enemies:** **one wave** — 3 Runners + 1 Bruiser (the Bruiser's debut) + **2 Snipers on the elevated catwalks**. The Snipers are non-blocking (they do not hold the gate; any left alive are removed silently when the wave clears). Snipers aim at Nick in 3D (beat 3 aim, beat 4 lock, beat 1 fire; 0.6 m live beam = hitbox). *(Composition differs from the original 4R+2S brief by the Bruiser — Decisions D9/D16.)*

### Zone 5 — SECTOR 05 · Neon Market (2.5D)
- **Geometry:** a tiered street descending over two ramps (top tier to lower tier, about 3 m) and an exit ramp down to the plaza level; market stalls and crates (static in the slice). Soft-locked by a 12 m tall holo-gate pair (x 166 and x 202) that opens on clear with the GO card.
- **Enemies:** **one wave** — 3 Runners + 1 Bruiser. *(Decisions D9/D16.)*

### Zone 6 — SECTOR 06 · Plaza Brawl (top-down)
- **Geometry:** a 30×30 m plaza (sunk 4 m) sealed by cyan holo walls at both ends; four cover pillars.
- **Enemies:** wave 1 — 8 Runners + 2 Bruisers from ten points around the rim; wave 2 — 3 Snipers. A pure crowd fight for the Sweeper and the roll.

### Zone 7 — SECTOR 07 · Enforcer (2.5D)
- **Geometry:** a 40 m strip (x 240–280) after the plaza, sealed by an entry gate behind Nick once the fight starts and a tall barrier (x 279) that stops him skipping it and opens when the Enforcer dies; 3 Runners guard the approach (they wake with the zone).
- **Mini-boss:** **The Rhythm Enforcer** — HP 900, 22 per hit, 3-hit beat bursts (GDD §4.3). Drops 300 Scrap + 15 Cells. Its death opens the barrier and arms the escape.

### Zone 8 — SECTOR 08 · Escape (the Market Purge)
- **Trigger:** the instant the Enforcer dies, a visible magenta kill wall starts 10 m behind Nick and advances at **5.5 m/s** (15 damage per beat on contact). Nick at full run (8 m/s) outpaces it by roughly 9 s.
- **Course (~119 m, from the Zone 7 barrier at x 279 to the end trigger at x 398):** two blast doors (x 295 and x 330) that each close every 4 beats for 2 beats (12 damage), the second two beats out of phase; two falling signs (x 310 and x 360) on an 8-beat cycle with a 2-beat flashing warning (15 damage), the second four beats out of phase; a collapsing platform (x 313; shakes 0.5 s, falls, resets after 3 s); two floors (30 m and 90 m) separated by a 5 m gap; and 2 Runners posted at the first door and the gap. Single jump suffices.
- **Reward:** 10 Cells at the end trigger. *(Decision D10 applied: the course was ~60 m at 3 m/s.)*

### Zone 9 — SECTOR 09 · Ascent (the elevator)
- **Geometry:** an 8×6 m freight elevator (entry trigger ~x 407, platform x 409) rising 19 m to the rooftop. Boarding hands Nick the elevator's own rail; once the platform has reached the top **and** both waves are dead, the rail hands him to the rooftop. *(Zones 9–10 moved +60 m east with the longer Zone 8 course.)*
- **Waves:** 3 Runners · then 2 Bruisers + 2 Runners after a 5 s cooldown, with shield-regen windows between. Dying on the elevator resets it to the bottom.
- **Reward:** 10 Cells.

### Zone 10 — SECTOR 10 · The Headliner
- **Geometry:** a 25×14 m rooftop dock (centre x 425; dock trigger x 417); a low holo rail on the camera side, a gate that seals behind Nick, beat-animated stage lighting.
- **Boss:** **The Headliner** — HP 2400, phase 2 at 50 % with the top-down projection storm at 160 BPM, overheating after 24 beats if no shield-breaker lands; Enraged melee finish (GDD §4.4). Drops 1000 Scrap + 1 Data Core.
- **Victory:** 2.5 s hold → results screen → shop.

---

## First-Pass Numbers (as built — tune in `tools/balance_tool.html`)
| Entity | HP | Hit dmg | Shield | Scrap | Cells | Notes |
|---|---|---|---|---|---|---|
| Nick | 120 (12 seg) | Light 12 / Heavy 28 | 40 (12/s after 3 s) | — | — | 3 lives |
| Runner | 30 | 8 | — | 8 | — | aggro range, telegraph → lunge |
| Bruiser | 90 | 20 | 80 | 50 | — | downbeat only; debuts in Zone 4 |
| Sniper | 24 | 18 | — | 25 | — | arms within 16 m; fires on beat 1; 0.6 m beam |
| Rhythm Enforcer | 900 | 22 (third hit 28.6) | state-based | 300 | 15 | Zone 7 |
| The Headliner | 2400 | 25 / bullets 10 | state-based | 1000 | 1 Core | Zone 10 |

Player actions: generic windows light 0.3 / 0.3 / 0.6 s, heavy 0.45 / 0.45 / 0.75 s · finishers Tri-Cut 32 · Launcher 40 · Sweeper 20 · Battery Ram 55 · dash 18 m/s for 0.25 s · roll 11 m/s (0.45 s i-frames + 0.2 s tail, ~7.2 m) · dodge cooldown 0.3 s (beat-aligned ±0.06 s refunds half) · Bass Drop 90 damage, radius 10 m · fall cost 20 HP.

Hazards: piston 15 (knockback 5) · bomb cell 15 (knockback 6) · toxic pit 5 per beat · falling sign 15 · blast door 12 · kill wall 15 per beat (5.5 m/s) · fall out of the world 20.

Shop: Max HP +20 = 100 Scrap · Max Shield +10 = 150 · Extra Life = 300 · Double Jump = 200 ([POST-SLICE] purchase; unlocked in the demo) · Sweeper = 20 Cells · Battery Ram = 25 Cells · Extra Booster Slot = 1 Core.
