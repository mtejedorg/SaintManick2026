# Vertical Slice: Detailed Level Design

**Objective:** A playable prototype that condenses the core pillars of *Saint Manick* (combat, the beat-driven world, camera shifts, platforming, and the roguelite meta-loop) into a single polished showcase.

**Theme:** A blend of **District 2 (Factory)** and **District 3 (Neon)**. The slice flows from the toxic, piston-driven factory into the hostile neon market, ending at the Neon district boss.

**Music Vibe:** Heavy Industrial Techno Metal. The Slice's **resting tempo is ~128 BPM**, but tempo is **dynamic** — an IntensityController ramps it up with enemy density and during top-down bullet-hell stages, and the boss may layer a polyrhythm (see `CodeArchitecture.md` §7, the Conductor). The tempo *internally* drives every hazard and enemy telegraph — the player is never required to act on the beat (see GDD §1.3), but reading the heartbeat makes survival flow. **Audio is metronome-only for now**; music loops come later, slaved to the Conductor.

**Player Loadout:** Nick starts with Double Jump, the basic Combos, Air-Combos, and the Dash/Roll already unlocked. At the start screen the player selects their **1 Temporary Run Booster** to exercise the economy integration.

---

## Build Plan: Two Slices

The prototype ships in two stages so we can prove the riskiest systems early without building everything at once:

- **Slice A — "First Blood" (Build A):** Zones 1–7, ending at the **Rhythm Enforcer mini-boss**. Proves combat feel, platforming, the first camera shift, beat-driven hazards, and — critically — the **death → shop → retry meta-loop** (see below). This is the minimum that validates the core experience.
- **Slice B — "The Headliner" (Build B):** Adds Zones 8–10 — the QTE escape, the elevator endurance fight, and the **Neon district boss, The Headliner** (GDD §4.4), including a mid-fight top-down bullet-hell phase.

### The Meta-Loop (must be present in Slice A)
The slice is **not** a single linear playthrough. The roguelite loop is itself a core pillar and must be testable:
1. Nick dies (HP 0 with 0 lives) → **Game Over** to **Karen's Shop**.
2. Player spends collected **Scrap** on permanent upgrades (HP, damage, a life, mitigation, shield, or a combo node) and re-selects a Run Booster.
3. Player re-enters from **Zone 1**, now over-leveled for the early zones (the climb back is fast).
4. Numbers tuned via `tools/balance_tool.html` toward the targets: average player clears the slice in 2–3 runs, weaker in 4–5.

> **Universal death rule (everywhere in the slice):** damage drains shield → HP. HP at 0 costs a **life** (respawn at full). Permadeath only at **HP 0 + 0 lives**. QTE and hazard failures obey this same rule — nothing is instant-death.

---

## The Block-by-Block Path

### Zone 1: The Linear Tutorial (2.5D) — Factory floor
- **Geometry:** 30-meter straight, flat 2.5D corridor. Safe and predictable. (Depth movement is locked here, as in all 2.5D sections.)
- **Enemies:** 3x *Runners* (Scrap-Punk Junkies), spawning one at a time.
- **Purpose:** Teach Light/Heavy attacks, jumping, and the **Dash/Roll** dodge against beat-telegraphed attacks — no environmental distractions.

### Zone 2: The Piston Platforming (2.5D)
- **Geometry:** A 60-meter hazardous section over a toxic pit (DoT if Nick falls in but survives the landing). Nick jumps across wide, disconnected platforms. The camera begins to curve, introducing curved 2.5D traversal.
- **Hazards:** 6 ceiling pistons slamming on the **downbeat** (every 4 beats at 128 BPM). The pattern accelerates toward the end of the pit.
- **Enemies:** 3x *Runners* on the platforms — fight them or juggle them into the pit with Air-Combos while timing jumps against the crushers.

### Zone 3: The Security Room Shift (Top-Down)
- **Geometry:** A 25×25 m square room. Nick enters in 2.5D; reaching the center locks the blast doors.
- **The Shift Trigger:** Center-of-room trigger. Camera tweens to top-down over ~1.5s and **depth movement unlocks** — Nick can now move on Z and X; jumping is suppressed, the roll is the evasion tool.
- **Enemies (Wave 1):** 4x *Runners* swarm from the corners.
- **Hazards:** The "Security System" drops bombs in a grid; safe cells alternate every 2 measures of the track.
- **Enemies (Wave 2):** 1x *Bruiser* (Riot-Shield) — break his shield with the Heavy/B-B combo while dodging bombs.
- **Exit:** Doors unlock; camera tweens back to 2.5D and re-locks depth.

### Zone 4: The Scaffolding & Vista (2.5D)
- **Geometry:** A 50-meter run of wide construction scaffolding curving around the factory exterior. Forgiving platforming (no pixel-precise jumps).
- **Visuals:** Camera pans out; the **Central Tower** is fully visible in the parallax background, establishing the city's scale.
- **Hazards & Enemies:** 2x *Snipers* on elevated, unreachable background platforms; laser sights lock on to the beat. 4x *Runners* spawn on the scaffolding. Manage the melee swarm while dashing through sniper fire.

### Zone 5: Neon Market Entrance (2.5D)
- **Geometry:** A wide, cluttered neon street with destructible signs, crates, and descending stairs. (Transition from Factory to Neon theme.)
- **Enemies:** A chaotic mix of 3x *Runners* and 1x *Bruiser*.

### Zone 6: Market Square Ambush (Top-Down)
- **Geometry:** A huge circular plaza.
- **The Shift Trigger:** Entering the plaza seals it with holographic walls; camera shifts top-down (depth unlocked).
- **Enemies:** A 360° mob — 8x *Runners* backed by 2x *Snipers* on the edges. A pure bullet-hell crowd fight testing crowd-control combos (A-B-B Sweeper) and the roll.

### Zone 7: The Mini-Boss Arena  *(← Slice A ends here)*
- **Geometry:** The end of the plaza.
- **The Mini-Boss:** **"The Rhythm Enforcer"** — a heavily shielded enforcer. Suggested first-pass: **HP 600, 22 dmg/hit**.
- **Mechanic:** The first hard **beat-reading test**. The Enforcer attacks in 3-hit bursts locked to the beat; the telegraph is a clear visual+audio cue, so a player who reads the heartbeat can dash/roll each hit and counter. The beat *helps* the player — it never forces input timing.
- **On defeat (Slice A):** Drops the slice's reward Scrap and returns to a results/shop screen so the meta-loop is exercised end-to-end.

### Zone 8: The Rhythm-Action Escape (Market Purge)
- **The Trigger:** The instant the Mini-Boss dies, the market's security purge activates.
- **Gameplay:** A frenetic, *Rayman Legends*-style escape. The music kicks into overdrive and the world — collapsing floor, falling neon signs, closing blast doors — moves to the beat. Sprint, jump, Double Jump across gaps, and dash through closing doors.
- **Failure is HP-cost, not death:** Each missed input (clipped by a sign, caught by a closing door) costs **HP**, not an instant kill. Run out of HP → lose a life per the universal rule. This keeps the sequence thrilling rather than a permadeath rug-pull. Suggested per-fail cost: ~1–2 battery segments.

### Zone 9: The Classic Elevator
- **Geometry:** Nick lands on a massive industrial freight elevator ascending the skyscraper exterior toward the boss arena.
- **Gameplay:** A classic endurance fight on a moving platform — waves of *Runners* and *Bruisers* drop on as it climbs. Shield-regen windows between waves let skilled players reset.

### Zone 10: The Headliner — Neon District Boss  *(← Slice B ends here)*
- **The Climax:** The elevator reaches the rooftop arena where **The Headliner** (GDD §4.4) is projected above the crowd. Suggested first-pass: **HP 1500, multi-phase**.
- **Gameplay:** A multi-phase fight testing everything in the slice — heavy combo/shield-breaking, beat-reading the holo-wall and crowd-surge hazards, and surviving a mid-fight Nier camera shift into a **top-down bullet-hell** projection-storm phase (roll-dodging beat-driven patterns). Beating The Headliner ends the Vertical Slice.

---

## First-Pass Numbers (tune in `tools/balance_tool.html`)
| Entity | HP | Hit dmg | Notes |
|--------|----|---------|-------|
| Nick | 120 (12 seg) | Light 12 / Heavy 28 | + Shield 40 (regen 12/s after 3s), 3 lives |
| Runner | 30 | 8 | fast, squishy, swarms |
| Bruiser | 90 | 20 | shielded; break with B-B |
| Sniper | 24 | 18 | ranged, locks on-beat |
| Rhythm Enforcer (mini) | 600 | 22 | Slice A boss |
| The Headliner (boss) | 1500 | phase-based | Slice B boss |

These are starting values, not final balance — load the balance tool, pick the **Slice A** or **Slice B** scope, and tune toward the 2–3 / 4–5 runs-to-clear targets.
