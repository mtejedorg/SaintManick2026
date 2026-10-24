# Vertical Slice: Detailed Level Design (rev. 2 — 2026-10-24, matches the build)

**Objective:** A playable demo that condenses the core pillars of *Saint Manick* — combat, the beat-driven world, camera shifts, platforming and the roguelite meta-loop — into one polished showcase. Scene: `levels/slice/vertical_slice.tscn`; zone names are `"SECTOR NN — NAME"` (the audio and boss activation read the number).

**Theme:** **Factory (Zones 1–4) → Neon District (Zones 5–10).** Audio and lighting follow that arc: industrial (1–4), neon market (5–7), neon high-rise ascent (8–9), the boss track (10).

**Music:** heavy industrial techno-metal. The Conductor rests at **128 BPM** and rises with enemy density (+2 per active enemy, cap +16); the Headliner's phase 2 runs at **160 BPM**. The tempo drives every hazard and telegraph; the player is never required to act on the beat (GDD §1.3). Current audio files are placeholder tones on the correct grid.

**Player loadout:** HP 120, shield 40, 3 lives, Dash and Roll, Tri-Cut and Launcher. **Double Jump, Sweeper and Battery Ram are shop unlocks** (GDD §5.2) — nothing in the slice requires them. Before each run the player equips a Run Booster in Karen's Shop (title screen → shop → run).

---

## The Meta-Loop (present and verified)
1. Nick dies with 0 lives → **Game Over** → **Karen's Shop** (currencies banked). Abandoning from pause banks them too.
2. The player spends **Scrap / Cells / Cores** on permanent upgrades and equips a Run Booster.
3. Nick re-enters from Zone 1, over-levelled for the early zones.
4. Numbers are tuned in `tools/balance_tool.html` toward 2–3 runs (average) / 4–5 (weaker). *The current yields (≈2320 Scrap for a full clear, ≈4640 with Scrap Magnet) are far above the tool's assumptions — see GDD Appendix B.*

> **Universal death rule (everywhere):** damage drains shield → HP. HP 0 costs a **life** and respawns Nick at the last zone checkpoint (full HP/shield, 1 s grace). Permadeath only at **HP 0 + 0 lives**. Hazards, falls (20 HP, back to the last safe ground) and escape failures obey the same rule.

---

## The Block-by-Block Path

### Zone 1 — SECTOR 01 · Street Entrance (2.5D, Factory floor)
- **Geometry:** 30 m straight corridor, no hazards. Depth locked.
- **Enemies:** 3 Runners, one wave each, from two spawn points.
- **Purpose:** teach Light/Heavy, Jump and Dash/Roll against beat-telegraphed attacks.

### Zone 2 — SECTOR 02 · Piston Gauntlet (2.5D)
- **Geometry:** 60 m of six disconnected 5 m platforms over a toxic pit, with a short depth dip in the rail; a seventh platform bridges the last gap to Zone 3.
- **Hazards:** 6 ceiling pistons that cock back on beat 4 and **slam on the downbeat**, cascading one beat apart; the last three accelerate to every two beats as Nick approaches. The pit deals **5 damage per beat** while Nick stands in it; its floor lets him climb back out.
- **Enemies:** 3 Runners, one per platform — fight them or juggle them into the pit.

### Zone 3 — SECTOR 03 · Security Lock (top-down)
- **Geometry:** 25×25 m room. Entering the centre locks both blast doors (red holo gates) and the drone climbs to the top-down view; depth movement unlocks, jump is suppressed.
- **Enemies:** wave 1 — 4 Runners from the corners; wave 2 — 1 Bruiser (break his guard with heavies or Battery Ram while dodging bombs).
- **Hazard:** the bomb grid — a 5×5 checkerboard; one set warns for a measure (amber) and ignites on the next downbeat (red), so safe cells alternate **every measure**. Active only while the encounter runs.
- **Exit:** gates open; the drone returns to 2.5D and depth re-locks.

### Zone 4 — SECTOR 04 · Scaffolding & Vista (2.5D)
- **Geometry:** ~50 m of catwalk with two plank gaps and recovery ledges beneath. The **Central Tower** and a skyline of neon-strip towers stand in the fog behind.
- **Enemies:** three waves (3R+1B · 2R + **2 Snipers on the elevated catwalks** · 2R+2B). Snipers aim on beat 3, lock on 4, fire on 1. *(Composition exceeds the original 4R+2S brief — GDD Decision D9.)*

### Zone 5 — SECTOR 05 · Neon Market (2.5D)
- **Geometry:** a tiered street descending two steps, market stalls and crates (static in the slice).
- **Enemies:** three waves (3R+1B · 3R+1B · 2R+1B). *(Decision D9.)*

### Zone 6 — SECTOR 06 · Plaza Brawl (top-down)
- **Geometry:** a 30×30 m plaza (sunk 4 m) sealed by cyan holo walls at both ends; two cover pillars.
- **Enemies:** wave 1 — 8 Runners + 2 Bruisers from ten points around the rim; wave 2 — 3 Snipers. A pure crowd fight for the Sweeper and the roll.

### Zone 7 — SECTOR 07 · Enforcer (2.5D)
- **Geometry:** a 37.5 m strip after the plaza; a tall barrier stops Nick skipping the fight; 3 Runners guard the approach.
- **Mini-boss:** **The Rhythm Enforcer** — HP 600, 22 per hit, 3-hit beat bursts (GDD §4.3). Drops 300 Scrap + 15 Cells. Its death arms the escape.

### Zone 8 — SECTOR 08 · Escape (the Market Purge)
- **Trigger:** the instant the Enforcer dies, a visible magenta kill wall starts 10 m behind Nick and advances at 3 m/s (15 damage per beat on contact).
- **Course:** a blast door that closes every 4 beats (12 damage), a falling sign on an 8-beat cycle with a 2-beat flashing warning (15), a collapsing platform (shakes 0.5 s, falls, resets after 3 s), two 30 m floors with a 5 m gap, and 2 Runners posted at the door and the gap. ~60 m; single jump suffices.
- **Reward:** 10 Cells at the end trigger. *Length/speed tuning is open (GDD Decision D10).*

### Zone 9 — SECTOR 09 · Ascent (the elevator)
- **Geometry:** an 8×6 m freight elevator rising 19 m to the rooftop. Boarding hands Nick the elevator's own rail; once the platform has reached the top **and** both waves are dead, the rail hands him to the rooftop.
- **Waves:** 3 Runners · then 2 Bruisers + 2 Runners after a 5 s cooldown, with shield-regen windows between. Dying on the elevator resets it to the bottom.
- **Reward:** 10 Cells.

### Zone 10 — SECTOR 10 · The Headliner
- **Geometry:** a 25×14 m rooftop dock; a low holo rail on the camera side, a gate that seals behind Nick, beat-animated stage lighting.
- **Boss:** **The Headliner** — HP 1500, phase 2 at 50 % with the top-down projection storm at 160 BPM, overheating after 24 beats if no shield-breaker lands; Enraged melee finish (GDD §4.4). Drops 1000 Scrap + 1 Data Core.
- **Victory:** 2.5 s hold → results screen → shop.

---

## First-Pass Numbers (as built — tune in `tools/balance_tool.html`)
| Entity | HP | Hit dmg | Shield | Scrap | Cells | Notes |
|---|---|---|---|---|---|---|
| Nick | 120 (12 seg) | Light 12 / Heavy 28 | 40 (12/s after 3 s) | — | — | 3 lives |
| Runner | 30 | 8 | — | 8 | — | aggro range, telegraph → lunge |
| Bruiser | 90 | 20 | 50 | 50 | — | downbeat only |
| Sniper | 24 | 18 | — | 25 | — | arms within 16 m; fires on beat 1 |
| Rhythm Enforcer | 600 | 22 (third hit 28.6) | state-based | 300 | 15 | Zone 7 |
| The Headliner | 1500 | 25 / bullets 10 | state-based | 1000 | 1 Core | Zone 10 |

Hazards: piston 15 (knockback 5) · bomb cell 15 (knockback 6) · toxic pit 5 per beat · falling sign 15 · blast door 12 · kill wall 15 per beat · fall out of the world 20.

Shop: Max HP +20 = 100 Scrap · Max Shield +10 = 150 · Extra Life = 300 · Double Jump = 200 · Sweeper = 20 Cells · Battery Ram = 25 Cells · Extra Booster Slot = 1 Core.
