# LEVEL ONE — The Suburbs (design rev. 1, 2026-10-27)

> **Status: DESIGN ONLY — nothing in this document is built.** Level One is the first district of the full game, launched from **START RUN** (owner direction 2026-10-27, `HANDOFF.md` §2b). The public demo stays the vertical slice (`VerticalSlice.md`, START DEMO, no shop). This document is the production brief for Level One; it extends the GDD (rev. 3.1, §8) and resolves nothing the owner has deferred. Every number not already fixed by the GDD or a `.tres` is **first pass** and goes through `Documents/tools/balance_tool.html` before it reaches data.
>
> Sources: `GDD.md` rev. 3 · `VerticalSlice.md` rev. 3 · `HANDOFF.md` §2b/§3-D · MemPalace (wing SaintManick, room decisions: audit decisions of 2026-10-26, owner direction of 2026-10-27) · specialist briefs by level-designer, mechanics-designer and narrative-designer (2026-10-27), reconciled here (Appendix A lists where they diverged and what this revision chose).

---

## 0. One-page summary

**What Level One is.** District 1 of the radial city: **THE SUBURBS**, the outermost ring — ruined, poor, scavenged tech. Eight sectors (seven zones and a boss arena), **12–15 minutes** on a first clear and **6–8** over-levelled, ending at the district boss, the **Junk-Yard Maestro**, who drops the game's first **Data Core**. It is new content: the slice's ten zones are untouched and become the Factory and Neon levels of the full game later.

**Why the Suburbs and not a remake of the slice.** The GDD already names the Suburbs district 1 and "the game's tutorial" (§2.2). A demo player who buys the game starts on new content instead of replaying the demo with a shop bolted on; the demo stays a true slice from the middle of the game; and the slice does not fork into a demo version and a game version. Cost: one boss, one soft hazard, one environment kit — no new enemy archetype.

**How it plays.** Six side-scroll sectors, one top-down arena (S03), and a boss that shifts side → top-down → side. The district rests at **96 BPM** (first pass; the slice rests at 128) so the one-beat telegraph is 0.625 s long for the player's first fights, and because 96 × 4/3 = 128: the Maestro's last phase literally hands the world over to the Factory's tempo. The level teaches every verb the slice assumes (move, jump, light, heavy, the white-hot telegraph, dash/roll, combo routes, the fall rule, top-down, shields, run-or-die, dash-through) and one new idea, **reading the bar**: speaker cabs ("Bass Stacks") whose lamps count the beat and pulse on the downbeat, and a meter change to 3/4 before the boss tests both.

**The meta-loop.** START RUN → (fresh profile: straight into S01; later: Karen's Shop first) → run → permadeath → Game Over → shop → run; victory → results → shop. One save: the demo is a read-only overlay that banks nothing. **Double Jump becomes a real purchase** (the demo forces it on), never required, rewarded twice. First-pass full clear ≈ **1 050 Scrap / 35 Cells / 1 Core** (the slice pays ≈ 2 020 / 35 / 1).

**What must be built.** The Maestro (new boss, new `BossPhaseDef` resource), the Bass Stack hazard, a `LevelDef` resource that routes START RUN and maps zone numbers per level, a Conductor meter API (`set_meter` on the next downbeat, `meter_changed`), meter-relative Sniper and piston, a Scrap cache pickup, the Suburbs environment kit, a 96 BPM loop with a 3/4 stem and a three-section boss track, Karen's calibration lines and the Maestro's broadcast. **Eleven production batches** sized like the audit batches (§10).

**What the owner must decide.** Fifteen new questions (§9.2: ten design, five narrative), the big ones: what follows a Maestro victory while Level Two does not exist (recommended: chain into the slice as the Factory/Neon stand-in), and the resting tempo (recommended: 96). The eight deferred audit decisions are listed as inputs with a recommended option each (§9.1) and are **not** resolved here.

---

## 1. Premise and narrative

### 1.1 Premise
Nick enters the city at its outermost ring because the road to the Central Tower starts here, and so does Karen's signal. She tells him the girl is held in the Tower and the outer ring is the quiet way in: thin surveillance, nothing worse than junkies and the odd eviction squad. She is half right. The Suburbs are where she chose to calibrate him.

The district answers to the **Junk-Yard Maestro**, a local sound man who built a walking stage out of speaker cabs and dead neon and keeps the last party in the ring running on stolen power. He wants one thing: the music never stops, because when it does the eviction crawlers roll. What he never says is who keeps his amps fed. The corporation tolerates him — a dancing district does not riot — and his gear came factory-sealed, from Karen's division.

Nick silences the band. The broadcast goes dark, the junkyard gate opens on the Factory chimneys, and the Maestro's last count lands at 128, the next district's tempo. The arm's origin stays blank (GDD §2.3).

### 1.2 Tone for this district
- **Poorer and quieter than the slice.** The Neon District shouts; the Suburbs mutter. Neon is salvaged and half-lit; world text reads like price tags, eviction notices and slogans aimed at people who cannot afford them.
- **96 BPM dub through blown cones.** Short lines, room between them. The Factory is a shape on the skyline, never a sound.
- **Nick says little.** He has seen this paperwork from the other side of the shield.
- **Karen: warm, precise, a little too interested.** Uses his name often; praise is measurable; vocabulary of signal, read, telemetry, output, calibration, "my drone". One slip ("the asset… you do, I mean") on a reward beat, then never again.
- **The Maestro: a broadcast voice.** Late-night DJ, generous, funny, addresses "Suburbs", counts everything; the only one still throwing a party; never says who pays for it.
- **Banned:** "tutorial", "press [button]" in speech, "hero", "chosen", meta words ("respawn", "run"), profanity past "hell", em-dashes in speech, Karen saying "love" or "trust me".
- **The re-read trail** (a second playthrough should see Karen): "no sponsor" in the station ID; a small glyph on the S01 drone boot screen that reappears on a crate behind the S08 stage; the Maestro's "tell whoever's flying it the show's not for sale"; Karen's victory line.

### 1.3 Sector names (the card shows the string verbatim; in-scene names are all caps as in the slice)
| Sector | Card text | Alternative | What the player sees that tells the story |
|---|---|---|---|
| 01 | `SECTOR 01 — LAST STOP` | END OF THE LINE | a burnt-out bus, destination board still flickering `CENTRAL`; the drone feed boots with a small corner glyph |
| 02 | `SECTOR 02 — STILT ROW` | HIGH WATER ROW | every porch taps one stolen power line; the water tower reads `WE STAY`, paint fresher than the houses |
| 03 | `SECTOR 03 — CUL-DE-SAC` | DEAD END CIRCLE | every door stencilled `PROPERTY RECLAIMED`, same date; one welcome mat left |
| 04 | `SECTOR 04 — PIRATE RADIO` | THE MAST | a mast of welded lamp posts; extension cords from every window to the cabs — the street pays for the music with its own power |
| 05 | `SECTOR 05 — EVICTION LINE` | FLOODLIGHT ROW | furniture on the pavement; the barricade ticker scrolls `RELOCATION IS OPPORTUNITY` |
| 06 | `SECTOR 06 — THE SWEEP` | CLEARANCE | the crawler's blade still carries a porch swing from the last street |
| 07 | `SECTOR 07 — THE STACKS` | SCRAP HEIGHTS | junk piles with hand-written price tags; from the top, the Factory chimneys, then the Tower |
| 08 | `SECTOR 08 — JUNK-YARD MAESTRO` | THE LAST PARTY | empty car-seat bleachers, a candle on each; behind the stage an open crate stamped with the S01 boot glyph |

Optional card subtitles exist in the narrative brief (`Route discontinued.` … `Tonight only. Every night.`); the zone card has no subtitle label today, so they need `ui-designer`.

### 1.4 The Maestro's voice and the boss intro copy
**Station ID** (between tracks, from S04 on): `You're tuned to Ninety-Six Point Junk. No licence, no sponsor, no last call.` · `Junk-Yard Radio, from the bottom of the pile to anyone with a battery left.`
**S04, counting the band in** (every "one" lands on a downbeat): `Evening, Suburbs. Lights out, rent due, band's still here. One, two, three, four.` · `Somebody's brawling under my mast. Fine. At least hit on the one. Two, three, four.` · `They cut the power, so we borrowed it back. Here comes the drop. And one.`
**S07, the waltz turn:** `Slow it down, Suburbs. Grab somebody you haven't lost yet. One, two, three.` · `A waltz for the evicted. One, two, three. One, two, three.`

**Boss bar:** `JUNK-YARD MAESTRO` · **Intro card:** `JUNK-YARD MAESTRO` / `LIVE FROM THE BOTTOM OF THE PILE`
**Entering the amphitheatre:**
```
Hold the music. We've got a walk-in. Hoodie, one metal arm, no ticket.
You came out here to stop the party? Friend, the party is all that's left.
And you brought a camera. Tell whoever's flying it the show's not for sale.
NICK: Last party I went to, I was working the door.
```
| Phase | Card (priority banner) | Maestro, over the silent count-in bar | Karen |
|---|---|---|---|
| P1 | `SOUNDCHECK` | `Check, check. Loud enough? Good. One, two, three, four.` | `He flares on four. Get over the wave.` |
| P2 | `WALTZ  3/4` | `Let's take it down. Partners, please. One, two, three.` | `Meter drop. Taking my drone up.` |
| P3 | `ENCORE  128` | `Encore! Pick it up for the cheap seats. One, two, three, four.` | `Same bar, faster beat. Finish it.` |

**Overheat stun:** `No, no, no. Who's on the desk? I'm clipping!` · `The cabs are cooking. Give me a second. Somebody fan the cabs!`
**Death lines:** `Keep the station on. When it goes quiet, they come for the street.` · `That's the set, Suburbs. Goodnight. Somebody else play loud.`
**Victory card:** `DISTRICT 1 CLEARED` · **Karen after the victory** (first read relief, re-read a test report): `Three tempos, and your output never dropped. Good. Rest now, Nick. The Factory runs hot.`

**Game Over names** (`DESTROYED BY`): Runner `SCRAP-PUNK` · Bruiser `EVICTION SQUAD` · Sniper `TURRET DRONE` · crawler `EVICTION CRAWLER` · `FALLING SIGN` and `THE DROP` (existing) · `BASS STACK` · `JUNK-YARD MAESTRO` (the Thump and the vinyl must name the boss as their source). **Karen on a lost life:** `Signal's back. So are you. Let's call that one a calibration error.` · `Vitals restored. I need you whole, Nick. Again, please.` · `I logged what dropped you. It won't surprise either of us twice.`

Localisation flags: "Ninety-Six Point Junk" puns on 96 BPM (keep the number if L2 changes it, or rename the station); spoken counts must keep their beat length (lamps and stems are cut to them).

---

## 2. Level One at a glance

| Item | Value |
|---|---|
| Scene | `levels/suburbs/level_one.tscn` (new), launched by START RUN through a `LevelDef` (§8) |
| Sectors | **8** — seven zones and the boss arena, named `SECTOR 01 — NAME` … `SECTOR 08 — NAME` |
| First clear / replay | **12–15 min** (boss ≈ 2 min) / **6–8 min** over-levelled — first pass |
| Camera rhythm | 6 side-scroll · 1 top-down (S03, at the 25 % mark, the slice's Zone 3 rhythm) · boss shifts side → top-down → side (the Headliner's rhythm) |
| Resting tempo | **96 BPM, 4/4** (first pass; owner decision L2). IntensityController +2 per active enemy, cap +16, so the level peaks at 112, still under the Factory's 128 |
| Boss tempo | P1 96 BPM 4/4 → P2 96 BPM **3/4** → P3 **128 BPM** 4/4 (§5) |
| Checkpoints | every sector entry, as in the slice; cleared encounters stay cleared, uncleared ones reset; falls return Nick to the last safe ground for 20 HP |
| Enemies | Runner, Bruiser, Sniper only — **no new archetype** (owner decision L9) |
| Hazards | one soft, beat-driven hazard, the **Bass Stack** (a GDD §2.2 extension: "no environmental hazards" read as *no industrial hazards*; owner decision L7) · an escape (the eviction crawler) · falls |
| Numbering | **per level, 01–08**; the slice is not renumbered (owner decision L1). Today AudioManager tiers, the ZoneAtmosphere table and the Enforcer's activation key on the global zone number; a `LevelDef` on each level root takes those lookups over, with a slice profile that reproduces today's tables byte for byte |

**Why 96 BPM (first pass).** (1) A one-beat telegraph lasts 0.625 s at 96 against 0.469 s at 128 — forgiveness for the first fights without touching any enemy value. (2) District identity: a slow dub / boom-bap junk band through scavenged speakers, against the Factory's techno-metal. (3) One bar of 3/4 at 96 lasts exactly one bar of 4/4 at 128 (1.875 s), so the Maestro's last shift keeps the bar and only speeds the beat. Cost: every beat-length window stretches with it (the Bruiser's live hitbox becomes 0.625 s; the Sniper's cycle 2.5 s), and the Conductor needs a per-level resting BPM (today it captures the autoload's export once). The mechanics brief preferred keeping 128 everywhere to avoid that API; the owner decides (L2).

---

## 3. Zone table

| # | Working name | Camera | Encounter | Hazard / set piece | Reward beat (first pass) | Purpose |
|---|---|---|---|---|---|---|
| 1 | SECTOR 01 — LAST STOP | side | W1: 1 Runner · W2: 2 Runners (flank) | trash-bag wall (first jump) · holo-gate pair | 24 Scrap | move, jump, light, heavy, the telegraph, dash/roll |
| 2 | SECTOR 02 — STILT ROW | side | 3 placed Runners (`wake_zone "02"`) | canal bed (safe drop) · 4 m culvert void | 24 Scrap · **Scrap cache** on the water tower (Double Jump only; 40 Scrap, decision L6) | platforming, Launcher, the fall rule |
| 3 | SECTOR 03 — CUL-DE-SAC | **top-down** | W1: 3 Runners · W2: 4 Runners | burnt cars as pillars; no hazard | 56 Scrap · **5 Cells** on clear | depth, roll, ground ring, beat-dodge cue |
| 4 | SECTOR 04 — PIRATE RADIO | side | 1 Sniper (blocking, reachable) + 2 Runners | **Bass Stack debut** (knockback, 0 damage) · the Maestro's broadcast | 41 Scrap | downbeat reading, the Sniper cycle |
| 5 | SECTOR 05 — EVICTION LINE | side | W1: 1 Bruiser · W2: 1 Bruiser + 2 Runners + 1 non-blocking Sniper | corporate barricade · holo-gate pair | 116–141 Scrap · **10 Cells** on clear | shields, heavy ×2, the downbeat swing — the mixed exam |
| 6 | SECTOR 06 — THE SWEEP | side (escape) | 1 posted Runner | **eviction crawler** (kill wall, 4.5 m/s) · 2 falling neon signs · collapsing porch · 4 m gap | 8 Scrap · **10 Cells** at the end trigger | run-or-die rules, dash pass-through |
| 7 | SECTOR 07 — THE STACKS | side | 2 placed Runners (`wake_zone "07"`) | junk-stack climb · Bass Stacks (6 damage) · **the meter drops to 3/4** | 16 Scrap · Double Jump shortcut | breather; counting in three |
| 8 | SECTOR 08 — JUNK-YARD MAESTRO | side → top-down → side | the Maestro (+3 Runners in P3, 0 Scrap) | tempo and meter shifts · corner Bass Stacks | **700 Scrap · 10 Cells · 1 Data Core** (GDD §4.2) | the final exam |
| | | | | | **≈ 1 050 Scrap · 35 Cells · 1 Core** | |

**Pacing:** low → breathe → medium → low/teach → high → set piece → breathe → boss. Two intense sectors (S05, S06) sit back to back, never three. Scrap values are the mechanics brief's per-kill yields (Runner 8, Bruiser 50, Sniper 25) applied to the compositions above; the per-zone-type budget behind them is in §6.4.

---

## 4. Zone-by-zone

World X runs east from 0. Each sector has its own straight `Path3D` rail (`Path_S01` …) and every rail end overlaps the next trigger (`test_rail_reachability.gd`). The single-jump apex is about 5.5 m (`jump_force 18`, gravity ×3); Double Jump reaches about 11 m. Gates are the slice's 12 m holo-gate pairs with the GO card. All first pass.

### S01 — LAST STOP (x 0–40)
- **Geometry:** a flat 40 m street. Nick steps off a burnt-out bus at x 2. A 1.2 m trash-bag wall at x 10 is the first required jump. Holo gates at x 18 and x 38 soft-lock a 20 m arena.
- **Opening:** Karen's drone feed boots (VCR burst, a "SIGNAL ACQUIRED" card); her calibration lines carry the control prompts inside the fiction (the shop is her laboratory, GDD §4.5).
- **W1:** 1 Runner from marker `S01_East` — at 96 BPM its white-hot flash is the slowest telegraph in the game, and the prompt names it. **W2:** 2 Runners from `S01_West` and `S01_East`, the first flank; the DASH/ROLL card lands here.
- **Exit:** gates open with the GO card.

### S02 — STILT ROW (x 40–110)
- **Geometry:** stilt houses over a drainage canal. The street ends at x 55; the canal bed is 2.5 m below with ramps out at x 58 and x 92 — dropping in costs nothing, it is ground, not void. Porch roofs at +2.5 m and rooftops at +5 m form a high route. A water tower at x 80 holds a **Scrap cache at +12 m**, 7 m above the nearest roof: only Double Jump reaches it (decision L6).
- **Enemies:** 3 placed Runners (one in the canal, two on roofs); they are ledge-aware, so a Launcher off a roof is the natural first combo lesson. **No gate** — a skippable breather.
- **Fall rule:** a 4 m void culvert at x 98–102 teaches "SIGNAL LOST −20 HP" late and cheaply; a single jump clears it.

### S03 — CUL-DE-SAC (x 110–140, top-down)
- **Geometry:** a 30 × 24 m turning circle ringed by burnt houses, three burnt cars as pillars.
- **Shift:** entering the centre locks red gates at the two street mouths; the drone climbs to (0, 12, 4.5), the ground ring appears, depth unlocks, jump is suppressed; the TOP-DOWN card fires after `camera_shift_finished(true)`.
- **W1:** 3 Runners from three house doors. **W2:** 4 Runners from the four corners, forcing rolls through the ring. No hazard: the camera is the lesson, and Karen points out the cyan beat-dodge flash as a reward.
- **Exit:** back to side-scroll; gates unlock on `camera_shift_finished(false)` with the GO card. 5 Cells on clear (new `ZoneEncounter.cells_reward`, the pattern of `escape_sequence.gd`).

### S04 — PIRATE RADIO (x 140–185)
- **Geometry:** a lot under an illegal radio mast. A 2.5 m crate step leads to a 5 m water-tank platform at x 176. Holo gates at x 158 and x 184.
- **Bass Stacks:** two speaker cabs at x 150 and x 166, each with **four count-in lamps**. Lamp *n* lights on beat *n*; on beat 4 all four flash white-hot (the telegraph); **the pulse lands on the downbeat**: a 3 m shockwave along the rail, knockback 8, **0 damage** (decision L7). The pulse also hits enemy hurtboxes, so the player can shove Runners with it.
- **Encounter:** 1 Sniper on the water tank, blocking and reachable, + 2 Runners. The Sniper aims on beat 3, locks on beat 4, fires on beat 1 — the same downbeat as the stacks. Lesson: the downbeat is when the world hits.
- **Narrative:** the Maestro's pirate broadcast plays here first; his voice counts the band in.

### S05 — EVICTION LINE (x 185–225)
- **Geometry:** a boarded-up street; a corporate barricade with floodlights at x 224; holo gates at x 190 and x 222; a 5 m balcony at x 212.
- **W1:** 1 Bruiser alone from `S05_East` — card "HEAVY HITS CRACK SHIELDS"; it plants and swings only on the downbeat (telegraph on beat 4). **W2:** 1 Bruiser + 2 Runners, plus 1 non-blocking Sniper on the balcony — the mixed exam. 10 Cells on clear.
- **Exit:** clearing W2 sounds the barricade siren and **the Sweep starts** (new `escape_sequence` start hook, §8): the gate behind stays shut, the gate ahead opens.

### S06 — THE SWEEP (x 225–300, escape)
- **Pursuer:** an **eviction crawler** — a tracked demolition rig with a dozer blade (the kill wall reskinned). It starts 10 m behind Nick at **4.5 m/s** (the slice uses 5.5) and deals 15 per beat on contact; at full run (8 m/s) Nick outpaces it by about 9 s over the 75 m course.
- **Course:** two falling neon signs at x 245 and x 280 (8-beat cycle, 2-beat flashing warning, the second offset by 4 beats — at 96 BPM a cycle is 5 s); a collapsing porch roof at x 258 (if it drops, Nick lands on the canal bed: slower, never a fall cost); one 4 m gap at x 268 (single jump).
- **Teach:** 1 Runner posted at x 252 where it is cheaper to **dash through** than to fight (pass-through during i-frames, D17). **No blast doors** — they are industrial and stay fresh for the Factory.
- **Reward:** 10 Cells at the end trigger at x 300.

### S07 — THE STACKS (x 300–350)
- **Geometry:** junk stacks climb 0 → +7.5 m in three 2.5 m steps, then drop into the junkyard gate. On the skyline behind, the Factory chimneys rise, then the Central Tower (pillar 3: the radial city).
- **Bass Stacks** at x 312 and x 330, now dealing **6 damage**. **Meter teach:** a trigger at x 322 switches the broadcast to a waltz; the Conductor changes the meter to **3/4 on the next downbeat** (new API, §8). One lamp on every cab goes dark, the cabs pulse every 3 beats (1.875 s), the HUD downbeat ring follows, the Maestro counts "one, two, three".
- **Enemies:** 2 placed Runners only (no Sniper in a 3/4 bar until it is meter-relative, §8). **Double Jump shortcut:** a crane hook at +11 m skips the second stack lane.
- **Exit:** a gate of stacked cars under a neon "MAESTRO" sign is the boss trigger. The meter resets to 4/4 as the boss activates.

### S08 — Junk-Yard Maestro (x 350–378)
See §5.

---

## 5. The Junk-Yard Maestro

**Fantasy:** the band leader keeps changing the song; you win by hearing the new count. A 6 m mech of scavenged speaker cabs and torn neon signs, its "head" a turntable deck; rim magenta (the brute rule). GDD §4.2: *makeshift mech of scrap speakers & neon signs; beat hook: BPM / time-signature shifts per phase*.

**Arena:** a **28 × 16 m** junkyard amphitheatre (the Headliner's dock is 25 × 14 m; the top-down rings need the room), walled on every side so there is no void. The side-scroll rail runs at z 0; a holo gate seals behind Nick; four corner Bass Stacks sit dormant in P1; two crushed-car stacks act as top-down pillars. Dormant-boss gating: the boss activates only from the arena trigger.

**The readable rule: the Maestro never changes two things at once.** P1 → P2 keeps the beat (96) and shortens the bar (4 → 3). P2 → P3 keeps the bar (1.875 s) and speeds the beat (96 → 128). Every shift lands on a downbeat and opens with **one silent count-in measure** — no attacks, the cab lamps count, the VCR glitches, Karen calls the change. A cab's lamp count always shows the time signature; the player learned that language in S04 and S07.

| Phase | Camera · tempo | Cycle | Ends |
|---|---|---|---|
| **P1 "Soundcheck"** | side · 96 BPM · 4/4 | 8 beats. Beats 1–3: state shield up while advancing. Beat 4: speakers flare white-hot. Beat 5 (downbeat): **Thump** — a floor shockwave travelling both ways along the rail at 10 m/s, 18 damage; jump it or dash through. Beats 6–8: vulnerable, ×1.5 damage taken. | HP ≤ 60 % (first pass; the Headliner shifts at 50 %) |
| **P2 "Waltz"** | top-down (2 s shift) · 96 BPM · **3/4** | Shield up. Downbeat: all four corner cabs pulse a **5 m ring** (0.6 m band, 10 damage) and the Maestro fires a **6-shot vinyl ring** from the pool (8 damage). Beat 2: rest. Beat 3: lamps white-hot. Safe ground is the centre, but the vinyl ring comes from there, so the player rolls through one band or the other. | a shield-breaker (Battery Ram / Bass Drop) lands, **or 24 beats (8 bars) pass and the speakers overheat** (first pass; D19 may shorten it to 16). Either way: a 6-beat "blown speakers" stun at ×1.5, then back to side-scroll |
| **P3 "Encore"** | side · **128 BPM** · 4/4 | No shield. 8 beats: a Thump on beat 1 **and** beat 3 (double wave), +20 % speed. 3 Runners rush in at the phase start (0 Scrap — a boss reset after a respawn must never be a Scrap farm); fodder that fills the meter for a Bass Drop. | death |

**No soft-lock without Battery Ram:** P1 always opens a vulnerable window; P2 always ends by the overheat (the Headliner's rule); P3 has no shield. A first-run loadout (Tri-Cut + Launcher) beats it; Battery Ram and Bass Drop only shorten P2.

**Stats (first pass, `characters/enemies/maestro/maestro_stats.tres`):**

| Field | Enforcer | **Maestro** | Headliner |
|---|---|---|---|
| `max_health` | 900 | **1 500** | 2 400 |
| `damage` (melee / Thump) | 22 | **18** | 25 |
| projectile / ring | — | **8 / 10** | 10 |
| `speed` | 2.0 | **1.5** (P3 ×1.2) | 1.5 |
| `knockback` / `stun` | 10 / 1.5 | **10 / 2.0** | 12 / 2.0 |
| `scrap` / `cells` / cores | 300 / 15 / 0 | **700 / 10 / 1** | 1 000 / 0 / 1 (code literal) |

Phase data lives in a new **`BossPhaseDef`** resource (an array in `maestro_phases.tres`): `hp_threshold, bpm, beats_per_measure, camera_mode, shield_overheat_beats, add_count, add_scene, shockwave_count, damage_mult, speed_mult, vulnerable_beats, vulnerable_damage_taken_mult`. The Headliner's `160.0` and `add_cores(1)` literals migrate to data in the same batch (new `EnemyStats.cores`).

**Engine needs (§8):** `Conductor.set_meter(layer, beats_per_measure)` applied on the next downbeat with the counters preserved (today `register_layer` resets `beat_index`, `measure_index` and `time_accumulator`, which drops or doubles a beat mid-fight); a new `SignalBus.meter_changed(layer, beats_per_measure)` for the AudioManager stem switch and the HUD ring; a tempo **snap** for P3 (the ramp is 20 BPM/s); and `_on_run_started` resetting the primary meter to the level's resting meter (today it keeps the previous run's meter, so a game over in 3/4 would start the next run in 3/4). **Respawn** (`boss_reset`) restores 4/4, the resting BPM, full HP, recalls the vinyl pool and the adds.

**Edge cases for the tester:** death during a count-in (meter and BPM restored); Bass Drop armed across a meter change (it detonates on the new meter's downbeat); pause during the victory hold; a breaker that crosses two thresholds runs both transitions once, in order; the camera returning from P2 on a lost life.

**Success criteria:** a first-timer without Battery Ram wins within 4 lives on the average preset; playtesters can name what changed at each phase unprompted; no shield state ever outlasts its overheat.

**Victory:** 2.5 s hold → "DISTRICT 1 CLEARED" card → what follows (decision L3).

---

## 6. The meta-loop as it applies to Level One

### 6.1 Flow
1. **Title → START RUN.** Fresh profile (no Level One run ever started): **straight into S01**, no shop, no booster — a 0-Scrap shop is a wall of greyed rows before the first punch; the first death then *introduces* the shop as a reward (decision L4). Every later START RUN: **Karen's Shop first** (spend, equip) → run.
2. **Run** under the universal death rule (GDD §5): 120 HP, 40 shield, 3 lives = 3 respawns, sector-entry checkpoints, 0.9 s death beat.
3. **Permadeath** → Game Over ("DESTROYED BY <enemy>", sector reached out of 8, banked currencies, NEW BEST) → shop → run.
4. **Victory** → 2.5 s hold → results (sectors 8/8, currencies, the Core, a first-clear banner) → shop → run, or the chained continuation (L3).
5. **Abandon** from the pause menu banks like a game over → shop.

| Screen | Exists | Level One change |
|---|---|---|
| `ui/menus/title_screen.tscn` | yes | START RUN routes through the `LevelDef` (fresh profile → run, otherwise → shop); sub-label "LEVEL ONE — THE SUBURBS"; CLEARED mark once cleared |
| `ui/menus/demo_loadout.tscn` | yes | unchanged; sets the current level to the slice |
| `ui/shop/karens_shop.tscn` | yes | `_on_start_run` hardcodes the slice scene path (`karens_shop.gd:431`) and must read the current level; the Double Jump row goes live; a first-visit Karen line; a "BEST: SECTOR NN" line |
| `ui/menus/run_results_screen.tscn` | yes | the hardcoded `"ZONES CLEARED %d / 10"` reads the level's zone count; first-clear banner; the Core earned |
| `ui/menus/game_over_screen.tscn` | yes | sector reached out of N; NEW BEST |
| pause / options | yes | none (abandon already uses `post_run_scene()`) |

**One save for demo and Level One.** Level One writes the profile only at bank moments (game over, victory, abandon — `_bank_run_currencies`), including the new progress fields. The demo (`GameManager.demo_mode`) is a **read-only overlay**: it reads the profile's upgrades, forces Double Jump on, takes its boosters from `demo_boosters`, banks nothing and writes no progress field. "Best sector" is a record written at run end, never a resume point, so the SaveManager meta-only contract holds.

### 6.2 Fresh profile and Double Jump
A fresh profile starts with HP 120 · shield 40 · 3 lives · Tri-Cut + Launcher (`SaveManager.STARTER_COMBOS`) · dash + roll · **no Double Jump** · 1 booster slot · 0 / 0 / 0. **Data trap:** `player_profile.gd` defaults `double_jump_unlocked = true` and ResourceSaver never writes defaults, so every profile has it today. Level One flips the default to `false`; `player.gd:178` grants it when `GameManager.demo_mode or profile.double_jump_unlocked`; saves that explicitly wrote `true` keep it; `test_batch_l.gd` and `test_save_manager.gd` are rewritten, not deleted (decision L5). **Contract with the level:** nothing in Level One requires Double Jump (highest required rise 2.5 m, widest required gap 4 m); it is rewarded by the S02 cache and the S07 shortcut, pays off in traversal (fewer 20-HP falls, recovery after a knockback off a ledge), against Snipers (air repositioning across the beam) and in Maestro P3 (the double Thump is tight with one jump, comfortable with two).

### 6.3 Shop and currencies in Level One
| Item (`_core/persistence/shop_upgrades/`) | Cost | Level One role |
|---|---|---|
| `upgrade_max_hp.tres` | 100 Scrap, repeatable | first buy for most players |
| `upgrade_max_shield.tres` | 150 Scrap, repeatable | arena survival |
| `upgrade_extra_life.tres` | 300 Scrap, repeatable | the weaker player's main lever |
| `upgrade_double_jump.tres` | 200 Scrap, once (price: decision L5) | a real purchase, gates nothing |
| `combo_unlock_sweeper.tres` | 20 Cells (needs Launcher) | top-down crowd control (S03, Maestro P2) |
| `combo_unlock_battery_ram.tres` | 25 Cells (needs Sweeper) | the shield answer for Bruiser and Maestro; never required (overheat) |
| `upgrade_booster_slot.tres` | 1 Core, once | the first Maestro reward |

**Cells by sector type** (grunts never pay Cells): top-down arena 5 (S03) · the mixed exam 10 (S05) · the escape 10 (S06) · the boss 10 (S08) = **35**, level with the slice, so a clear buys both combo nodes at today's prices or Sweeper then Battery Ram across two runs (D4 input). **Cores:** the first Maestro kill buys the Extra Booster Slot; a second Core has no sink yet — recommended: every kill drops one and Cores bank for later sinks (a third slot, the Karen Checkpoint, Overclock; decision L8). **Damage / armour tiers** ([POST-SLICE]) are not needed for Level One: offence grows through the combo tree, defence through HP / shield / lives; revisit with D2.

### 6.4 Yield budget and run-by-run expectation (first pass)
Per-sector-type yields (the mechanics brief; numbers live in `*_stats.tres`, `ZoneEncounter.cells_reward`, `maestro_stats.tres`): onboarding fight 3 Runners 24 · ordinary fight 40–80 · traversal 20–50 · top-down arena 50–240 + 5 Cells · mixed exam 120–140 + 10 Cells · escape ≈ 10 + 10 Cells · boss 700 + 10 Cells + 1 Core. Applied to §3: **≈ 1 050 Scrap / 35 Cells / 1 Core** per full clear, a pre-boss bank of **≈ 350**.

**Why lower than the slice (≈ 2 020):** Scrap is per kill and a tutorial district fields two Bruisers, not eight; Level One is the first third of a future Suburbs → Factory → Neon run on the same price list, so a Suburbs clear must not buy out the survival stack. **Tension to settle in the tool:** the mechanics brief sized a pre-boss bank of ≈ 950 (2–4 items); this layout banks ≈ 350 before the Maestro (2–3 items). The levers, in order: the S03 and S05 wave sizes (cheap), the cache value, the Maestro's Scrap — or accept a slower shop cadence. The balance tool's own verdict on the slice is "every preset clears on run 1: the shop gates nothing", and a tutorial district is easier still, so if a LEVEL ONE preset shows run-1 clears the levers are **Maestro HP/damage and the lives count, not the yields**: yields set the shopping cadence, threat sets the run count (D2 input).

| Average player (target 2–3 runs) | Starts with | Reaches | Banks (S / C / Core) | Buys |
|---|---|---|---|---|
| Run 1 | 120 / 40 / 3 | dies in Maestro P2–P3 | ≈ 350 / 25 / 0 | Sweeper, Max HP ×2, Max Shield |
| Run 2 | 160 / 50 / 3, Sweeper | **clears** | +1 050 / 35 / 1 | Battery Ram, Extra Life, Max HP ×3, Double Jump, Booster Slot |
| Run 3 | 220 / 50 / 4, Ram, booster ×2 | clears (replay) | +1 050 / 35 / 1 | Max Shield ×2, Extra Life … (D2 caps) |

| Weaker player (target 4–5 runs) | Starts with | Reaches | Banks | Buys |
|---|---|---|---|---|
| Run 1 | base | dies in S05 W2 | ≈ 150 / 5 | Max HP |
| Run 2 | 140 / 40 / 3 | dies in the Sweep or S07 | ≈ 280 / 25 | Sweeper, Max HP, Max Shield |
| Run 3 | 160 / 50 / 3, Sweeper | dies at the Maestro | ≈ 350 / 35 | Extra Life, Max HP ×2 (Cells 40: Ram affordable) |
| Run 4 | 200 / 50 / 4, Ram | dies in P3 or clears | ≈ 350 or +1 050 | Extra Life, Max Shield |
| Run 5 | 200 / 60 / 5 | **clears** | +1 050 / 35 / 1 | Double Jump, Booster Slot |

**LEVEL ONE preset for `balance_tool.html`** (describe only; refresh the stale SLICE preset first — it still carries Enforcer 600, Headliner 1 500, Bruiser shield 50 and the pre-D9/D16 waves): the shared archetype table + `maestro` (1 500 / 18 / 700 S / 10 C / 1 Core, cycle beats per phase, adds at 0 Scrap); sector rows (type, camera, R/B/S per wave, completion Cells, Cores); economy inputs (keep %, fatal-zone %, growth, caps per repeatable for D2, the Magnet multiplier for D15, the Cells price switch for D4, a Double Jump buy policy); flow "run 1 without booster"; threat (DPS, attacker cap, BPM 96, exposure, Maestro BPM per phase); targets 2–3 / 4–5.

### 6.5 Run Boosters
| Booster | Today (`game_manager.gd` consts) | Level One |
|---|---|---|
| Tempo Shield | ×1.5 max shield | keep |
| Adrenaline | ×1.2 move speed | keep — helps traversal and the Sweep |
| Scrap Magnet | ×2 Scrap — **D15 open** | an input: at ×2 a Maestro-wall death banks ≈ 700 instead of ≈ 350, compressing the weaker curve by about a run; recommended ×1.5 (owner decides). If D15 changes the value, the three consts move into a `RunBoosterDef` resource in the same batch (no magic numbers) |
| Suburbs Skip [POST-SLICE] | — | gets its premise only if a victory chains into the next level (L3); out of scope until then |
| Extra-Life booster [POST-SLICE] | — | out of scope: it duplicates the 300-Scrap Extra Life and flattens the weaker curve |

---

## 7. Onboarding
Level One owns the teaching sequence; the slice's Zone 1 prompts stay demo-only (`seen_controls` is shared, so a demo player would otherwise skip Level One's teaching — Level One gets its own seen-flag, decision L4). Teaching happens through Karen's calibration lines and the existing card component (`levels/components/onboarding_prompts.gd` extended with a per-zone schedule), never text walls.

Cards take the lead words below; `onboarding_prompts.gd` appends the bindings (e.g. `ATTACK  J/X LIGHT · K/Y HEAVY`). Every Karen line is 80 characters or fewer and never says "tutorial".

| # | Skill | Sector | Card | Karen, over the feed |
|---|---|---|---|---|
| 0 | Feed boot | S01 | `SIGNAL ACQUIRED` | `Signal acquired. She's still in the Tower, Nick. Every district gets you closer.` — Nick: `Then route me. Quietly.` |
| 1 | Move | S01 spawn | `MOVE` | `There you are. Walk for me. I need a clean read on your gait.` |
| 2 | Jump | S01 trash wall | `JUMP` | `Trash wall. Over it. I'm logging the lift, so make it look easy.` |
| 3 | Light attack | S01 W1 | `ATTACK` | `Blade hand first. Fast cuts. Show me how quick the left side is.` |
| 4 | The telegraph: white-hot means one beat to the hit | S01 W1 | `WATCH THE FLASH` | `See him flare white? One beat, then he swings. Everything out here keeps time.` |
| 5 | Heavy (free, never gated) | S01 W1 | `HEAVY` | `Now the arm. It costs you nothing, so don't ration it. Full output, please.` |
| 6 | Dash / roll i-frames | S01 W2 | `DODGE` | `Two of them. Dash or roll through the swing. For a breath, nothing touches you.` |
| 7 | Combo routes: Tri-Cut, Launcher | S02 rooftops | `TRI-CUT · LAUNCHER` | `Three cuts, or two and the arm. Launch him off the roof. I want to see the arc.` |
| 8 | Safe drops vs the void, the fall rule | S02 | `LOOK DOWN` | `The canal bed holds. The culvert doesn't. Drop in there and I lose you.` |
| 8b | The Double Jump cache (no Double Jump yet) | S02 | — | `Scrap cache on the water tower. Out of reach today. I'll remember where it is.` |
| 9 | Top-down: depth, roll, ring | S03 | `TOP-DOWN` | `Taking my drone up. Depth is yours now. Roll, don't jump. The cyan ring is you.` |
| 10 | Beat-dodge cue (a reward only) | S03 | `BEAT DODGE` | `Cyan flash. You dodged on the beat. The asset adapts fast. You do, I mean.` |
| 11 | Ability Bar | first full meter, usually S03–S04 | `BASS DROP READY` | `Meter's full. Arm it; it lands on the next downbeat. Everything near you goes.` |
| 12 | Downbeat hazards and lamps | S04 | `DOWNBEAT` | `Count the lamps. Four lit, then it pushes. It doesn't hurt. Yet.` |
| 13 | The Sniper cycle | S04 | `AIM · LOCK · FIRE` | `Turret on the tank. Aims on three, locks on four, fires on one. Be gone by one.` |
| 14 | Shields, heavy ×2, the Bruiser's downbeat | S05 | `HEAVY CRACKS SHIELDS` | `Riot shield. Blade scratches it, arm cracks it. He only swings on the downbeat.` |
| 15 | Run-or-die rules | S06 | `RUN` | `Eviction crawler. It doesn't stop, it doesn't steer. Mind the signs. Run, Nick.` |
| 16 | Dash through enemies | S06 | `DASH THROUGH` | `Don't fight him. Dash straight through. He isn't worth the seconds.` |
| 17 | Counting in three | S07 | `COUNT IN THREE` | `Meter's changed. One lamp's dark. Three to the bar now. Count with him.` |
| 18 | Boss shields, vulnerable windows, overheat | S08 | `BREAK OR OUTLAST` | `Shield's up while he plays. Bass Drop breaks it, or wait. Those cabs will cook.` |

Line 8b sells the Double Jump purchase on the first run — a visible "come back later" goal, not a gate.

---

## 8. New systems and assets versus what the slice provides

| The slice provides (reuse as-is or by config) | Genuinely NEW for Level One (each costs batch time) |
|---|---|
| Death rule, checkpoints, banking, abandon, `demo_mode`, `post_run_scene()`, results / game over / shop / pause / options screens | **`LevelDef` resource** (`levels/level_def.gd`): id, display name, scene, `zone_count`, `resting_bpm`, resting meter, zone → music-tier map, zone → atmosphere row, boss activation keys, `next_level_id`, onboarding seen-flag name — plus `GameManager.current_level`. It replaces the hardcoded slice paths (`title_screen.gd`, `demo_loadout.gd`, `karens_shop.gd:431`), the results "/ 10", and the global zone-number lookups in `AudioManager.tier_for_zone`, `ZoneAtmosphere.parse_zone_number` and the Enforcer's `"07"` match. A slice `LevelDef` reproduces today's tables so the demo is unchanged and the existing tests guard it |
| `PlayerProfile`, `SaveManager` (atomic write, backup) | **Profile fields:** `double_jump_unlocked` default → `false` + demo grant; `seen_level_one_prompts`; `level_one_cleared`, `level_one_best_zone`, `level_one_clears`, `level_one_runs_started` (bank time only, never in demo). Optional `player_base_stats.tres` for the literal 120 / 40 / 3 in `start_new_run` |
| Conductor tempo, `tempo_changed`, meter layers (`register_layer(name, beats_per_measure)`), IntensityController | **Conductor API:** per-level resting BPM taken from the `LevelDef` on `run_started`; `set_meter(layer, beats)` applied on the next downbeat with counters preserved; `SignalBus.meter_changed(layer, beats)`; a tempo snap; `_on_run_started` resets the primary meter (today it inherits the previous run's) |
| Bruiser (already reads `beats_per_measure`), Enforcer / Headliner (`beat_index == 3`, safe for n ≥ 3) | **Meter-relative telegraphs** for the Sniper (`sniper.gd` matches beats 3 / 4 / 1 — it never fires in 3/4) and `ceiling_piston.gd` (`BEATS_PER_MEASURE := 4`) — required before any Sniper shares a 3/4 bar |
| `zone_trigger`, `zone_encounter` + `wave_def` (named markers, `blocking`), `wave_spawner`, `holo_gate` pairs + GO card, `camera_shift_trigger`, dormant grunts with `wake_zone` | **`ZoneEncounter.cells_reward`** (S03, S05 — the pattern of `escape_sequence.cells_reward`) · **`EnemyStats.cores`** (Maestro; the Headliner's `add_cores(1)` literal migrates) |
| `escape_sequence` + `escape_kill_wall` (the crawler is a reskin at 4.5 m/s) + `escape_falling_hazard` (neon signs) + `escape_collapsing_hazard` (porch) + respawn resets | **Escape start hook:** `escape_sequence.gd` listens only to `miniboss_defeated`; S06 needs a `start_on` ZoneEncounter (S05 W2 clear) |
| Runner, Bruiser, Sniper — unchanged; **no new enemy archetype** | **Junk-Yard Maestro:** scene + HSM states (P1, Count-in, P2, Overheat, P3), `maestro_stats.tres`, `maestro_phases.tres` (`BossPhaseDef`), Thump shockwave hitbox, vinyl ring through `_core/pool/`, corner-cab rings, Runner adds at 0 Scrap, `boss_reset`, boss bar + shield strip (existing) |
| Toxic pit / pistons / bomb grid (stay in the Factory) | **Bass Stack hazard** (`levels/components/bass_stack.gd/.tscn`): lamps = the meter, a linear pulse in side-scroll and a ring in top-down, damage through Hitbox → Hurtbox → HealthComponent, masks player and enemy hurtbox groups, `damage` and `knockback` exports (0 / 8 in S04, 6 / 8 in S07, 10 in the arena) |
| `onboarding_prompts` (ATTACK, TOP-DOWN, BASS DROP READY cards) | **Per-zone card schedule** + Level One's own seen-flag + 4 new cards |
| Fall rule, `SIGNAL LOST` card, last-safe-ground | **Scrap cache pickup** (`levels/components/scrap_cache`): one grant per run, resets on a new run (decision L6) |
| `zone_atmosphere` (per-zone tween), `stage_light` (arena), CSG skyline pattern, `assets/materials/` kit | **Suburbs environment kit:** stilt houses, canal, burnt cars and bus, chain-link, radio mast, junk stacks, speaker cabs, scrap neon signs, eviction barricade, the crawler, a skyline with the Factory chimneys and the Tower; atmosphere rows (cool sodium + magenta junk neon) |
| AudioManager (OGG Vorbis on the Conductor grid, tiers 1–4 / 5–7 / 8–9, no-op on missing files) | **Audio:** a Suburbs loop at 96 BPM (4/4 plus a 3/4 waltz stem), a three-section boss track (96 4/4 · 96 3/4 · 128 4/4), SFX for the Thump, lamp tick, crawler and vinyl, Maestro vocal counts; a level-aware music map (via `LevelDef`) |
| Zone card, LIFE LOST / LAST LIFE banners, DESTROYED BY (`GameManager.killer_name()` prefers `stats.display_name`) | **Narrative hookup:** Karen's calibration lines, the Maestro's broadcast and intro, the card copy (§1, §7). **Catch:** without per-level stat copies or a `display_name` override on the `LevelDef`, the grunts print RUNNER / BRUISER / SNIPER and the crawler (a reused `EscapeKillWall`) prints KILL WALL; the Thump and the vinyl must carry the Maestro as their `DamageInfo` source |
| Tests: `probe_triggers`, golden-path traversal, rail reachability, trigger isolation, deferred-spawn guard, capture tool | **Extended to the new scene** + a LEVEL ONE capture set; the export gate smokes the exe into START RUN |
| `balance_tool.html` SLICE preset | **SLICE preset refresh + LEVEL ONE preset** (§6.4) |

**Not recommended for Level One:** a level select (there is one level), Factory-continuation code beyond the `next_level_id` field and the L3 chaining, difficulty tiers (every encounter would need tiered data; the shop *is* the difficulty slider), a new HUD element (a "WAVE 1/2" chip only if D27 asks for one), the Suburbs Skip and Extra-Life boosters.

---

## 9. Open owner decisions

### 9.1 The eight deferred audit decisions, as inputs (none is resolved here — the owner decides)
| Decision | How Level One depends on it | Options (as the audit framed them) | Recommended option |
|---|---|---|---|
| **D2** shop economy | repeat clears at flat prices stack HP / shield / lives without limit; Level One adds yields | flat · cost curve · caps · re-tuned yields | measure with the LEVEL ONE preset first; then **caps** (e.g. HP ×5, Shield ×5, Life ×2) before release; a curve only if caps are not enough |
| **D4** Cells costs | income 35 per clear against a 45 tree (Sweeper 20 + Ram 25) | A: 15 / 20 · keep 20 / 25 | the briefs split (level: A; mechanics: keep 20 / 25 so Sweeper lands after run 1 and Ram after run 2). **Recommended: keep 20 / 25** and re-measure after the first playtest |
| **D15** Scrap Magnet | doubles the Maestro-wall bank | keep ×2 · lower · remove | **×1.5**, moved into a `RunBoosterDef` |
| **D18** top-down facing | S03 and Maestro P2 | A: 8-way · status quo | **A** — Sweeper and arm arcs need depth aim |
| **D19** boss shield uptime vs HP | a third shielded boss; P2 overheat 24 vs 16 beats | keep 24 · shorten · scale with HP | first pass **24** (mirrors the Headliner); test 16 after the first playtest; shield up ≤ 35 % of fight time |
| **D24** Zone 4 planks | only if traversal reuses planks | as the audit framed it | Level One uses solid gaps with recovery ledges until decided |
| **D27** HUD counters | two-wave encounters in S01, S03, S05 | none · wave counter · enemies-left | a "WAVE 1/2" chip in gated encounters only |
| **D33** stagger tiers / post-stagger protection | the weaker player in S03 / S05 crowds risks stun-lock | as the audit framed it | adopt **post-stagger protection** before Level One ships; tiers can wait |

### 9.2 New decisions Level One forces
| # | Question | Options | Recommended (owner decides) |
|---|---|---|---|
| **L1** | Sector numbering | (a) per level 01–08 via `LevelDef` · (b) a distinct global block 11–18 · (c) renumber the slice | **(a)** — the demo stays untouched and it scales to five districts |
| **L2** | Resting tempo | (a) 96 BPM (per-level resting BPM in the Conductor) · (b) 128 everywhere (no API, less district identity, 0.47 s telegraphs for the first fights) · (c) 120 | **(a) 96** |
| **L3** | What follows a Maestro victory while Level Two does not exist | (a) results → shop → Level One again · (b) **chain straight into the slice inside the same run** (HP and lives carried; the slice's prompts suppressed) as the Factory/Neon stand-in · (c) a "to be continued" card → shop | **(b)**: START RUN becomes a full ≈ 30 min run ending at the Headliner, the Suburbs Skip booster gets its premise, and the slice stays reachable from START RUN. Costs: the run shows two "SECTOR 01" cards unless the `LevelDef` prefixes the district; the run-by-run tables in §6.4 assume the run ends at the Maestro and must be re-based (a chained clear banks ≈ 3 000 Scrap) |
| **L4** | Fresh-profile flow and the tutorial flag | run-first + own seen-flag · shop-first · shop-first with unaffordable rows hidden | **run-first**, `seen_level_one_prompts` separate from `seen_controls` |
| **L5** | Double Jump in the full game | (a) the profile starts locked, the demo forces it on, price 200 · (b) unlocked everywhere and the shop item is cut · price 150 / 250 | **(a) at 200** — keeps D1's demo intent and gives Level One's rewards meaning |
| **L6** | The Double Jump rewards | (a) the S02 cache (40 Scrap first pass) + the S07 shortcut · (b) shortcut only — the mechanics brief warns a purchase-gated pickup can read as "required" and pickups are a new system | **(a)** with the cache small and visible (a goal, not a gate); drop to (b) if playtesters read it as required |
| **L7** | How far the Bass Stack extends "no environmental hazards" (GDD §2.2) | (a) knockback only outside the boss · (b) S04 knockback only, S07 6 damage, arena 10 · (c) decorative outside the boss | **(b)** — a harmless lesson first, then a light test |
| **L8** | Cores on repeat Maestro kills | every kill · first only | **every kill**; Cores bank for later sinks |
| **L9** | A native Suburbs enemy | (a) none — the three grunts fit (junkies, riot-shield eviction squad, surveillance drones) · (b) one new heavy · (c) an Enforcer variant (700 HP / 250 Scrap / 15 Cells) as a mid-level mini-boss if S05 tests too light | **(a)**; keep (c) as the fallback the mechanics brief sized |
| **L10** | What starts Maestro P3 | (a) always after P2 (time) · (b) HP ≤ 30 % | **(a)** — every first-clear player hears all three tempos |
| **L11** | Does the Maestro survive? | (a) dies with the mech · (b) the mech blows, the man walks off, his station returns as a voice in later districts · (c) dies; the station loops a recording | **(b)** — audio only; a later broadcast can say the crawlers rolled once the music stopped |
| **L12** | Is the girl mentioned in Level One? | (a) no · (b) once, unnamed, in Karen's boot line · (c) environment only | **(b)** — Nick needs a reason to walk inward, and Karen using her is the GDD's manipulation |
| **L13** | Does the drone glitch suspiciously this early? | (a) never · (b) once, a VCR drop over "tell whoever's flying it" · (c) several | **(b)** — reads as interference; with the S08 glyph that is the whole re-read trail |
| **L14** | District names on Game Over | (a) `SCRAP-PUNK` / `EVICTION SQUAD` / `TURRET DRONE` (needs the `display_name` hook, §8) · (b) the slice names | **(a)** — the Suburbs should read as a place |
| **L15** | Is Karen's corporation named? | (a) unnamed ("the corporation", "the Tower"); the glyph is its only mark · (b) named on the stencils | **(a)** — a name on every notice points at her too early |

---

## 10. Production estimate

Each batch is one focused session sized like the audit batches A–O in `HANDOFF.md` §2: 5–20 commits, its own tests, and the CLAUDE.md gate (import + title smoke + slice smoke + Level One smoke once it exists + tests **never below 447 and rising**, zero grep hits, no new warnings; the visual gate whenever scenes, materials or models change; executor DONE claims audited by grep or log). Art and audio are human / modelgen work that runs in parallel from batch 5 on.

| # | Batch | Deliverables | Depends on | Gate |
|---|---|---|---|---|
| 1 | **Level routing & profile** | `LevelDef` + a slice def + a Level One def; `GameManager.current_level` read by title / shop / demo / results / game over; progress fields; Double Jump flip + demo grant; run-first flow + `seen_level_one_prompts`; `player_base_stats.tres`; START RUN opens an empty `level_one.tscn` | L1, L4, L5 | demo never writes progress · a Level One run banks · fresh profile → run · the rewritten Double Jump tests · slice smoke byte-identical |
| 2 | **Conductor & data prerequisites** | per-level resting BPM; `set_meter` + `meter_changed` + resting-meter reset + tempo snap; meter-relative Sniper and piston; `EnemyStats.cores` (Headliner migrated); `ZoneEncounter.cells_reward`; Enforcer activation via `LevelDef`; the `escape_sequence` `start_on` hook | 1, L2 | the meter lands on a downbeat with counters intact · a post-3/4 run starts in 4/4 · the Sniper fires in 3/4 and 5/4 · a foreign "07" is ignored · pistons unchanged in 4/4 |
| 3 | **New level components** | `bass_stack` (lamps, pulse, ring, both hurtbox groups), `scrap_cache`, the onboarding per-zone schedule + 4 cards, a component test scene | 2, L6, L7 | a Bass Stack hit goes through Hitbox → Hurtbox → HealthComponent and follows 3/4 · one cache grant per run |
| 4 | **Greybox S01–S04** | CSG geometry, rails, triggers, encounters, markers, gates, the S03 shift, the S04 stacks and Sniper | 3 | `probe_triggers` + golden-path traversal + rail reachability + trigger isolation extended to Level One · visual gate S01–S04 |
| 5 | **Greybox S05–S07 + arena shell** | the Bruiser waves, the Sweep (crawler, signs, porch, gap, posted Runner), the S07 meter trigger and shortcut, the cache, arena walls and seal | 4 | escape respawn test · meter returns to 4/4 at the arena · a no-Double-Jump traversal sweep proves nothing requires it · visual gate |
| 6 | **Maestro logic (placeholder mesh)** | HSM states, `maestro_stats.tres`, `maestro_phases.tres`, Thump, count-in, P2 rings and vinyl through the pool, overheat, P3 snap, the Runner rush, the Core drop, boss bar + shield strip, `boss_reset` | 5, L10 | phase-transition tests · 24-beat overheat without a breaker (no soft-lock) · a double-threshold hit runs both transitions once · bullets recalled on respawn and death · dormant gating · adds pay 0 |
| 7 | **Maestro & environment art, pass 1** | `/modelgen --style neon --accent 1.0 0.0 0.67` for the Maestro, the crawler and the Bass Stack; the Suburbs kit core; `probe_meshes` on every mesh before wiring | 6 (silhouette spec) | probe output in the handoff · mesh gallery · visual gate · export gate (assets outside excluded folders) |
| 8 | **Dressing & light** | kit placement, `LevelDef` atmosphere rows, skylines with the Factory and Tower, arena stage lights | 7 | visual gate on all eight sectors; telegraph and lamp readability checked at the drone camera |
| 9 | **Audio & narrative** | the 96 BPM loop + 3/4 stem, the three-section boss track, SFX, Karen's calibration and Maestro lines, final zone names | 6 | `.import` files exist · AudioManager resolves tiers through `LevelDef` · a listen pass on the grid |
| 10 | **Onboarding & economy hookup** | the card schedule and copy, the SLICE preset refresh + LEVEL ONE preset mirrored to `.tres`, caps if D2, `RunBoosterDef` if D15, NEW BEST / first-clear banners | 3, 9, D2 / D4 / D15 | onboarding tests (per-sector cards, own flag) · yield totals match the tool · caps enforced |
| 11 | **Integration & release** | the L3 victory path, TESTPLAN Level One gauntlet, a fresh audit-lens round, the export gate with the exe smoked into START RUN | 1–10 | exe smoke clean · golden path title → Maestro → shop → new run · tester sign-off |

**Eleven batches.** Batches 1–2 can start before the layout is final and before any owner answer except L1 / L2 / L4 / L5; batch 10 waits on the economy decisions; batches 7–9 run in parallel with 6–8 as human / modelgen work. Handoff: 1–6, 8, 11 → `senior-dev`; 7 → `artist-3d`; 9 → `audio-designer` + `narrative-designer`; 10 → `mechanics-designer`; `ux-designer` reviews after the first playtest; `tester` on 6 and 11.

---

## Appendix A — Reconciliation notes (where the specialist briefs diverged)
| Topic | level-designer | mechanics-designer | This revision |
|---|---|---|---|
| Resting tempo | 96 BPM (teach, identity, 96 × 4/3 = 128) | keep 128 (no new API) | **96**, owner decides (L2) |
| Maestro structure | side → top-down 3/4 → side 128; P2 is a shielded bullet phase; 24-beat overheat; 3 adds in P3 | side-scroll only; 4/4 @128 → 3/4 @140 → 5/4 @150 with shielded RE-TUNE breaks of 16 beats; 2 adds per break | the level designer's staging (it owns the arena, and "never change two things at once" is the readable rule); the mechanics brief's stat fields, `BossPhaseDef`, 0-Scrap adds, edge cases; overheat 24 first pass with 16 as the D19 alternative |
| Mini-boss | none; the Enforcer debuts in the Factory | an Enforcer variant (700 HP) as a Cells source | **none** in Level One; the variant kept as the L9 fallback; its 15 Cells redistributed to S05 (10) and the Maestro (10) so a clear still pays 35 |
| Cells sources | the Sweep and the Maestro | arenas 5, set piece 10, mini-boss 15, boss 0 | S03 5 · S05 10 · S06 10 · S08 10 = 35 |
| Scrap budget | TBD by mechanics | 9-zone template ≈ 1 650, pre-boss ≈ 950 | ≈ 1 050 / pre-boss ≈ 350 from the actual compositions; the gap is a tool input (§6.4) |
| Double Jump cache | a water-tower cache rewards the purchase | no purchase-gated pickups | cache kept small and visible, owner decides (L6) |
| Victory path | chain into the slice (b) | flag + Core + CLEARED, no continuation code | **(b)** recommended, owner decides (L3) |
| Level data | `LevelProfile` (zone → tier / atmosphere / activation key) | `LevelDef` (id, scene, zone_count, music map, next_level_id) | one **`LevelDef`** carrying both |
| Batches | 10 (level-side) | 5 (systems-side) | 11 merged (§10) |
