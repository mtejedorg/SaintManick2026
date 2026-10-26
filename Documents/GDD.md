> [!IMPORTANT]
> **MASTER SOURCE OF TRUTH — Vertical Slice stage (rev. 3, 2026-10-26)**
> This Game Design Document is the officially approved vision for Saint Manick. It supersedes every earlier draft, PDF and presentation in the archives. It is written for the **current stage**: the mechanics are defined, the ten-zone level layout is decided, and the Vertical Slice is the demo. Every mechanic in §3–§6 marked **[SLICE]** is implemented and verified in the build; everything marked **[POST-SLICE]** is designed but deliberately not built yet. Numbers live in the data files named next to them (`.tres`), never only here. **Numbers mirror the `.tres`/scene at commit 8937f29** (rev. 3 applies the owner decisions of 2026-10-26; where this document and a data file ever disagree, the file wins).

# Game Design Document: Saint Manick

![Saint Manick Logo](images/logo.png)

*A 2.5D Beat'em Up Game by Hugsy Games*

---

## 1. Game Overview & Identity

### 1.1. Elevator Pitch
**Saint Manick** is a retro-inspired 2.5D beat'em up set in a decadent, neon-drenched dystopian future. Players control **Nick**, a rogue corporate enforcer — bionic arm, katana, and a grudge — fighting through the radial districts of the massive city of Saint Manick. Guided by **Karen** via a surveillance drone, Nick cuts his way to the great central tower to save the last hope of the human species: a little girl.

### 1.2. Key Information
- **Genre:** 2.5D Action Roguelite / Beat'em Up
- **Engine:** Godot Engine 4.6 (Forward+), GDScript
- **Platforms:** PC (Standalone Windows), 1920×1080 canvas, keyboard or gamepad
- **Target Audience:** Fans of classic beat'em ups (*Streets of Rage*, *Final Fight*) and hardcore action roguelites (*Hades*, *Dead Cells*) who appreciate punishing difficulty, meta-progression and lore-rich settings blended with ambient rhythm mechanics.
- **Current deliverable:** the **Vertical Slice** — Zones 1–10 of a Factory → Neon District run ending at The Headliner boss, with the full death → shop → retry loop. Detailed zone design: `VerticalSlice.md`.

### 1.3. Core Pillars
1. **Classic Beat'em Up Flow:** Fun, heavy-hitting combat that respects the genre's legacy while introducing modern fluidity and combo progression. Players are free to mash and chain — **combat is never gated by a stamina resource**.
2. **The Beat as the World's Heartbeat:** This is **not a rhythm game**. The player is never required to act on the beat. The game's internal tempo (the *Conductor*) drives **enemies and traps**: attack telegraphs, projectiles and hazard timings all pulse to the beat, so a player who learns to feel the heartbeat knows when to dodge and when to strike — and is never punished for ignoring it. **The tempo is dynamic**: it rises with enemy density and jumps for the boss. *(Polyrhythm layers are supported by the engine and reserved for later bosses — **[POST-SLICE]**.)*
3. **Radial Dystopian World:** The architecture improves and rises as the player moves toward the centre of the city.
4. **Dynamic Diegetic Camera (Nier Automata style):** The interface is the live feed of **Karen's drone**. The drone flies between a 2.5D side-scrolling beat'em up view and a top-down bullet-hell view. The shift is **mechanical, not cosmetic**: depth (Z-axis) movement is locked in side-scroll and unlocks only in top-down (§3.1, §3.5).
5. **Fair-but-Tense Roguelite Loop:** Short and tense. Nick has limited HP, a regenerating shield and a pool of lives, so **true death (permadeath) is rare** but always threatened. On permadeath, collected resources persist and buy permanent upgrades in Karen's Shop. Because upgrades persist, a dead player returns *over-levelled* and climbs back quickly. Target pacing: an **average player clears the slice in 2–3 runs, a weaker player in 4–5** (§5.4).

---

## 2. Story, Setting & Lore

### 2.1. The World of Saint Manick
A dystopian future where robotics and rampant technological growth have devastated Earth's natural resources. The common people have been pushed into the marginal suburbs, living in squalor while spending their remaining money on the technology they need to survive.

### 2.2. Radial City Design & Districts
The city is a **radial composition**: buildings in a district never exceed the height of the next district closer to the centre, so the player always sees the inner city and the final tower. Nick traverses:

1. **The Suburbs** — the outermost ring; ruined and poor; no environmental hazards; the game's tutorial. **[POST-SLICE]**
2. **The Industrial Factory** — toxic heavy machinery: toxic pits that deal damage over time, rhythmic piston crushers, a security lock with a beat-driven bomb grid. **[SLICE — Zones 1–4]**
3. **The Neon Entertainment District** — high-tech, bright, hostile; holograms and clubs; pure enemy density rather than strict hazards, plus the market's security purge (escape) and the elevator ascent to the rooftop. **[SLICE — Zones 5–10]**
4. **The Corporate High-Rise** — pristine and sterile; moving laser grids and drone strikes synced to the music. **[POST-SLICE]**
5. **The Central Tower** — Karen's true headquarters and the final fight. **[POST-SLICE]**

![Dystopian City Concept](images/radial_city.png)

### 2.3. Characters
- **Nick:** A former mid-level corporate enforcer who went rogue — he knows the system from the inside, which is exactly why he can't let it stand. His right arm is fully bionic from the shoulder: heavy, dangerous, marked with neon along the plating — his **power hand** (hard pushes, charged strikes, special abilities). His left hand holds a katana — his **speed hand** (fast cuts and slashes). He moves in a beat-up urban hoodie, an underdog against the armoured corporate machinery he used to serve. Nick is world-weary, not edgy. He fights because someone has to.
  > **Narrative note (open):** The origin of Nick's bionic arm is a deliberate blank — the most interesting question the game can ask about him. When the story team fills it in, the answer should connect to his break from the corporation.
- **Karen:** The deuteragonist and secret antagonist. A ruthless corporate director manipulating Nick with simulated emotions of love and vengeance. She wants to test Nick as the definitive combat weapon to take absolute control of the city.
- **The Drone:** Karen's surveillance drone — the player's camera and the host of the HUD.

### 2.4. Visual Identity
**Neon-noir, neon rim, not baked textures.** A dark world (near-black navy ambient) lit by neon sources; characters read by their rim glow: **Nick cyan `#00F5FF`**, grunts, Bruiser and Enforcer **magenta `#FF00AA`**, the Sniper **orange `#FF8000`** (explosive/ranged), The Headliner **amber** turning **magenta** in phase 2. Red/white-hot rim flashes are the universal attack telegraph. Factory zones are warm sodium + cyan; Neon zones magenta + cyan; Zone 10 is a beat-animated stage. Everything the player sees is a surveillance feed (§6.2).

---

## 3. Gameplay Mechanics

### 3.1. Movement & Navigation (Verticality) **[SLICE]**
Nick moves left and right with inertia, but the environment is rarely flat:
- **Jump:** dedicated button. Levels require jumping stairs, gaps and dropping into lower areas. *(Data: `characters/player/player.gd` — `jump_force 18`, gravity ×3, `max_speed 8`.)*
- **Double Jump:** **unlocked from the start in the demo build** *(Decision D1: `_core/persistence/player_profile.gd` `double_jump_unlocked` defaults to `true`, and an old save that never bought it loads it unlocked too)*. The Karen's Shop item (200 Scrap, once) stays in the data as the **[POST-SLICE]** purchase for the full game, where it returns as a permanent unlock. Nothing in the slice *requires* it; it expands platforming and mid-air combat positioning.
- **No depth movement in side-scroll:** Nick is locked to a single combat plane; the up/down inputs do nothing. Depth (Z) freedom unlocks **exclusively** in top-down mode (§3.5).
- **Rails:** each zone's combat plane is a `Path3D`; Nick blends onto the active rail over 0.3 s when the camera hands him a new one. *(Curved rails and a camera that yaws with them are **[POST-SLICE]** — the slice's rails are straight with a short depth dip in Zone 2.)*
- **Falls:** falling out of the world is **not** a reload — Nick returns to his last safe ground and pays HP (20) through the universal damage rule (§5). The cost ignores dash/roll i-frames (a dash off the edge still pays) but not the respawn grace; a survivable fall shows a "SIGNAL LOST −20 HP" card and grants a 0.5 s grace.
- **Ground & wall detection:** `CharacterBody3D` physics; the player body lives on physics layer 2 ("player"), enemies on layer 3, the world on layer 1.

### 3.2. Combat System & Combos **[SLICE]**
Nick fights with two tools that read as one fighter: the **katana** (A, light — fast, blade-forward) and the **bionic arm** (B, heavy — slow, charged, mechanical). There is **no stamina**: mash and chain at will. Basic values *(`characters/player/states/player_state_attack.gd`)*:

| Input | Damage | Window (hit 1 / 2 / 3 of a chain) | Knockback | Notes |
|---|---|---|---|---|
| A (light, katana) | 12 | 0.3 / 0.3 / 0.6 s | 4 | hits pressure shields ×1 |
| B (heavy, arm) | 28 | 0.45 / 0.45 / 0.75 s | 8 | pressures shields at **×2** but does **not** shatter them |

*Decision D3:* heavy windows are deliberately slower than lights so that the named routes out-DPS heavy mashing (`heavy_attack_durations`; a matched route uses its own `ComboDef.duration` instead).

**Combo routes** *(`characters/player/combos/*.tres` — the Combo Skill Tree, §5.2; a matched route replaces the generic finisher and ends the chain)*:

| Route | Input | Finisher | Identity |
|---|---|---|---|
| **Tri-Cut** | A-A-A | 32 dmg, knockback 4, 0.6 s | three fast blade cuts; single targets |
| **Launcher** | A-A-B | 40 dmg, knockback 12, 0.6 s, **launches** | blade opens, arm punches the enemy airborne |
| **Sweeper** | A-B-B | 20 dmg, knockback 8, 0.5 s, hitbox ×1.5 wide | wide spinning arm strike; crowd control |
| **Battery Ram** | B-B | 55 dmg, **guard-breaking + shield-breaker**, 0.8 s | the only pure-arm route; the arm commits |

- **Air attacks:** A/B pressed while airborne attack in the air (the ground routes apply). A dedicated *Air-Combo* route that holds launched enemies airborne is **[POST-SLICE]**.
- **Shields — two kinds:** the **Bruiser** carries an 80-point *HP shield* (`HealthComponent`, `bruiser_stats.tres`): light hits pressure it ×1, heavy hits ×2, overflow carries to HP, it regenerates 12/s after 3 s, and while it holds the Bruiser has hyper-armour (no knockback or stun). *(Decision D7: raised from 50 to 80. Because of the ×2 shield-damage multiplier, a generic heavy deals 56 shield damage, so **two** generic heavies still break it (overflow carries to HP) while **Battery Ram** breaks it outright in one hit; the owner will revisit this.)* The **Enforcer** and **The Headliner** use a *state shield* (on/off per cycle phase): while it is up, non-breaker hits deal nothing and are absorbed without knockback or stun; only **Battery Ram** and **Bass Drop** (`is_shield_breaker`) shatter it and stun them for two beats.
- **Hit feedback:** hit-stop (0.08 s at 5 % time scale), camera shake (light 0.05 / heavy 0.1), cyan sparks for light hits and magenta for heavy, enemy knockback + stun. A hit is classed *heavy* at ≥ 20 damage, so every route finisher (Tri-Cut 32, Launcher 40, Sweeper 20, Battery Ram 55) gets heavy feedback and +9 meter. Hitboxes are fixed boxes in front of Nick — katana 1.5 wide × 1.5 tall × 2.5 m deep, arm 3.0 wide × 3.0 tall × 1.6 m deep (the arm sweeps a wide arc, which matters in top-down) — deliberately **not** parented to the animated weapon so hit detection stays deterministic.
- **Nick getting hit:** a hit that gets through (dodge i-frames and the respawn grace never reach this point) puts Nick in a hurt state: knockback away from the source and a stagger capped at **0.4 s**, so a stagger never spans a whole beat.
- **Defensive move — Dash & Roll:**
  - **Dash** (dedicated input: Shift / RB): 0.25 s burst at 18 m/s (~4.5 m), **fully invincible** for its duration, **0.3 s** shared dodge cooldown (Decision D6; was 0.5 s).
  - **Roll** (dedicated input: Ctrl / B): 0.45 s of i-frames then a 0.2 s vulnerable recovery tail, **11 m/s** (~7.2 m per roll; Decision D14, was 18 m/s). The primary way to survive bullet hell in top-down.
  - **Pass-through (Decision D17):** Nick passes through enemy bodies **only while dash/roll i-frames are active**; the pass-through ends with the i-frames.
  - **Beat-aligned reward (never a gate; Decision D6):** a dodge started within **±0.06 s** of a primary beat edge refunds **half** of its dodge cooldown (0.15 s of 0.3 s) and grants +4 ability meter **at most once per 2 beats**, so on-beat dash chains cannot stay near-invulnerable. A short **cyan rim flash** on Nick is the cue that the dodge landed on the beat.
  - **Free dodge cancel (Decision D22):** once an attack has connected, a dash/roll pressed in the **last 40 % of that hit's recovery** cancels the recovery for free (the dodge cooldown still applies). The paid EMP Dash-Cancel (§3.3) works earlier, in the active window.

### 3.3. The Ability Bar (Combat Resource) **[SLICE]**
In place of stamina, Nick has an **Ability Bar** (the HUD's old stamina slot). It is a *reward* meter, never a limiter — nothing Nick does is blocked by an empty bar. *(Data: `player.gd`.)*
- **Filling:** +4 per light hit, +9 per heavy hit (classified by damage ≥ 20), +4 per beat-aligned dodge (at most once per 2 beats). Out of combat (2 s without a landed hit) it decays at 5/s. **Losing a life empties the bar** (Decision D28) and disarms an armed Bass Drop.
- **Partial spender — EMP Dash-Cancel (25):** during the **active window** of a hit (hitbox live, the first 60 % of its duration), Dash cancels straight into a dash, ignoring the dodge cooldown.
- **Full-bar ultimate — Bass Drop (100):** press Ultimate (L / LB) with a full bar to *arm* it; it detonates on the **next downbeat** — the one place the game leans on the beat for spectacle: **90 damage, radius 10 m**, shield-breaker, knockback 16, stun 1 s, to every enemy in range *(Decision D8: was 60 / 6 m; the Zone 10 dock is 25 × 14 m, so it now reads as "screen-clearing")*.
- **[POST-SLICE]:** **Overclock** (~5 s attack speed/damage surge) and the **Ground-Pound** partial spender are designed but not built; additional abilities and a larger bar are future shop items.

### 3.4. Rhythm-Action Escape Sequences (the "Run or Die" sequences) **[SLICE — Zone 8]**
Bespoke traversal set pieces inspired by *Rayman Legends*: the world (collapsing floor, closing blast doors, falling signs) moves to the beat while Nick sprints, jumps and dashes. Reading the heartbeat makes it flow, but inputs are *traversal*, not note-matching.
- **Failure is NOT instant death:** a clipped door or a falling sign costs **HP** (12–15, roughly one battery segment), a touch of the pursuing kill wall costs 15 per beat. Only the universal death rule applies (§5).
- **The pursuer (Decision D10):** the kill wall starts 10 m behind Nick and advances at **5.5 m/s** over a ~119 m course; Nick at full run (8 m/s) still outpaces it by roughly 9 s. The course carries two blast doors and two falling signs, deliberately out of phase with each other (`cycle_offset`). Layout: `VerticalSlice.md` Zone 8.

### 3.5. Dynamic Camera Perspectives **[SLICE]**
The camera is Karen's drone and moves to give Nick the best tactical view *(`characters/player/drone_camera.gd`, a camera state machine: Sidescroll → Transitioning → TopDown)*.
- **Side-scrolling (depth locked):** offset (0, 3, 10); lateral movement only; jump enabled.
- **Top-down bullet hell (depth unlocked):** the drone climbs to offset **(0, 12, 4.5)** *(Decision D21; was (0, 15, 5))* and pitches 60°; Nick moves freely on X and Z (W/S, ↑/↓ or stick up/down move him in depth); **jumping is suppressed**; the roll is the evasive tool. A **cyan ground ring** under Nick shows his position while top-down. Used in Zone 3 (security lock), Zone 6 (plaza) and the Headliner's phase 2.
- **Transitions:** a 1.5 s tween (2 s for the boss). On completion the player's movement constraint flips (plane-locked ↔ free) and Nick blends onto the new rail. Every shift fires a VCR glitch burst (§6.2).

---

## 4. Enemies & Bosses

### 4.1. The Grunts (rhythmic telegraphing) **[SLICE]**
Enemies hit hard; in compensation their attacks are locked to the Conductor so the beat is a readable cue. All telegraphs use the same language: a white-hot rim flash one beat before the hit. Stats live in `characters/enemies/<type>/<type>_stats.tres`.

| Enemy | HP | Hit | Shield | Scrap | Behaviour |
|---|---|---|---|---|---|
| **Runner** (Scrap-Punk Junkie) | 30 | 8 | — | 8 | chases within aggro range; telegraphs on a beat, lunges on the next |
| **Bruiser** (Riot-Shield Enforcer) | 90 | 20 | 80 | 50 | plants and swings **only on the downbeat** (telegraph on beat 4; hitbox live for exactly one beat); heavy hits pressure the shield, Battery Ram shatters it |
| **Sniper** (Laser-Sight Turret) | 24 | 18 | — | 25 | arms only within 16 m; aims on beat 3, locks on beat 4, **fires on beat 1**; the beam widens 0.15 → 0.3 → 0.6 m through the cycle; aims at Nick in 3D, and its hitbox is the full 0.6 m beam |

Scene-placed grunts stay dormant until Nick enters their zone (their `wake_zone`) or, with none set, comes within their aggro range; grunts are ledge-aware and never walk off an edge on their own (knockback still can). Any enemy that falls out of the world is removed silently (no reward). The toxic pit damages enemies as well as Nick, so knocking a grunt into it is a valid kill with normal Scrap. The tempo controller only counts active enemies.

> **Parry — deferred [POST-SLICE].** Not designed into any enemy. When added, beat-synced telegraphs make its window a natural fit.

### 4.2. District Boss Roster
| District | Boss | Concept | Beat hook | Status |
|---|---|---|---|---|
| 1 · Suburbs | **Junk-Yard Maestro** | Makeshift mech of scrap speakers & neon signs | BPM / time-signature shifts per phase | [POST-SLICE] |
| 2 · Factory | **The Overseer** | Smelter/crane rig weaponising the foundry | Piston-slam AoEs on the downbeat | [POST-SLICE] |
| 3 · Neon District | **The Headliner** | Holographic VJ/DJ idol commanding the crowd | Phase change to 160 BPM; projection storm | **[SLICE]** |
| 4 · Corporate | **The Auditor** | Cold security-AI executive construct | Laser sweeps on-beat | [POST-SLICE] |
| 5 · Tower | **Karen** | The corporate director — final boss | The most chaotic (§4.5) | [POST-SLICE] |

Defeating a district boss drops a **Data Core** (§5.1).

### 4.3. The Mini-Boss: The Rhythm Enforcer **[SLICE — Zone 7]**
A heavily shielded enforcer *(`enforcer_stats.tres`: HP 900, hit 22, Scrap 300, **15 Cells**; Decision D13: was 600)*. The first hard **beat-reading test**: an 8-beat cycle — shield up while he advances (2 beats), **telegraph on beat 1**, a **3-hit burst on beats 2/3/4** (the third hit ×1.3 damage, ×1.8 knockback), then two vulnerable recovery beats at ×1.5 damage taken. The shield is up only while he advances; a shield-breaker hit (Battery Ram / Bass Drop) stuns him for two beats. The arena is sealed by an entry gate behind Nick and a tall barrier ahead. Its death opens the barrier and triggers the Zone 8 security purge.

### 4.4. The Vertical-Slice Boss: The Headliner **[SLICE — Zone 10]**
A towering holographic VJ/DJ idol projected above the rooftop plaza *(`headliner_stats.tres`: HP 2400, hit 25, Scrap 1000, 1 Data Core; Decision D13: was 1500)*.
- **Phase 1 (side-scroll, 128 BPM):** shield up while it advances (3.5 m bubble), a one-beat telegraph, a **single lunge**, then four vulnerable recovery beats at ×1.5 damage taken.
- **Phase 2 (at 50 % HP):** the track jumps to **160 BPM**, the drone executes a Nier-style shift to **top-down bullet hell**, depth movement unlocks, and the Headliner raises a shield while firing a pooled **projection storm**: a 12-shot radial on beat 1, aimed shots on beats 2 and 4, an 8-shot spiral on beat 3 (10 damage each). The phase ends when a shield-breaker lands **or after 24 beats, when the shield overheats** — so a first-run player without Battery Ram is never soft-locked. *(Shield uptime vs HP is Decision D19, to be revisited after human testing.)*
- **Enraged:** back to side-scroll, no shield, +20 % speed, melee duel to the finish.
- **Holo-walls and crowd-surge hazards** from the original concept are **[POST-SLICE]**; the slice's phase-2 hazard is the projection storm alone.
- Beating The Headliner ends the Vertical Slice: a 2.5 s hold, then the results screen → Karen's Shop.

### 4.5. The Final Boss: Karen **[POST-SLICE]**
Once Nick reaches the central tower, the truth is revealed: Karen used the journey to test Nick as the ultimate weapon. The shop was her laboratory, and the drone that served as the player's camera becomes her weapon. A checkpoint sits immediately before this fight (**Retry Boss / Full Run** choice). *Camera-as-weapon guiding principle: the drone degrades the feed, never replaces it — Nick stays visible at all times (forced zoom-outs, brief 90° tilts, "signal-loss" static that hides enemy telegraphs so the player survives on the audio heartbeat).*

---

## 5. Progression: The Roguelite Loop & Karen's Shop **[SLICE]**

Saint Manick is **tense and short, but fair**. No mid-level save-scumming.
- **The universal death rule:** Nick has an HP battery (120), a regenerating **shield** (40; regenerates 12/s after 3 s without damage) and **3 lives**. Damage drains shield, then HP. **HP 0 costs a life**: after a **0.9 s death beat** (input locked, a slow-motion hit-stop and the death clip; Decision D20) Nick respawns at full HP/shield at the **last zone checkpoint** (every zone entry is a checkpoint; cleared encounters stay cleared, uncleared ones reset) with 1 s of grace and an empty ability bar (§3.3). **Permadeath happens only when HP hits 0 with 0 lives remaining** — three lives are three respawns — and ends in the same death beat. Hazards, falls and escape failures obey the same rule through the same component.
- **Permadeath → Game Over → Karen's Shop.** The Game Over screen shows the banked Scrap, the zone reached and a **"DESTROYED BY <enemy>"** line naming the lethal hit's source (the LIFE LOST banner carries the same name). The run's currencies are banked, permanent upgrades are bought, a Run Booster is equipped, and a new run starts from Zone 1. Abandoning a run from the pause menu banks the currencies the same way.
- **The Karen Checkpoint** (Retry Boss / Full Run before the final fight) is **[POST-SLICE]**.
- **Meta-progression & out-levelling:** shop upgrades are permanent, so a returning Nick clears the early zones quickly.
- **Difficulty targets:** tuned with `tools/balance_tool.html` toward **2–3 runs (average) / 4–5 runs (weaker)**. *(Audit Decision D2, **deferred as too early**: the slice's scrap yield was ~3.7× the tool's assumptions at the 2026-10-24 audit and prices are flat; the D9/D16 recompositions lower a full clear to ≈2020 Scrap, not yet re-measured against the tool. A cost curve and caps wait for human testing.)*

### 5.1. Currencies
| Currency (in-game label) | Source in the slice | Sink |
|---|---|---|
| **Scrap** (`SCRAP`) — "Common Scrap" | every enemy kill (8–1000, see §4) | cumulative upgrades, Double Jump ([POST-SLICE] purchase) |
| **Cells** (`CELLS`) — "Rare Scrap" | the Enforcer (15), the Zone 8 escape (10), the Zone 9 elevator (10) | combo-tree nodes (Sweeper 20, Battery Ram 25) |
| **Cores** (`CORES`) — "Data Cores" | district bosses only (The Headliner: 1) | the extra Run Booster slot (1) |

### 5.2. The Upgrade Structure *(data: `_core/persistence/shop_upgrades/*.tres`)*
- **Cumulative items (repeatable, stack):** Max HP +20 (100 Scrap), Max Shield +10 (150), Extra Life (300). **Double Jump** (200, once) remains a **[POST-SLICE]** purchase: the demo build ships it unlocked (§3.1). *Damage and armour tiers are designed but **[POST-SLICE]**.*
- **Combo Skill Tree:** a chain — **Tri-Cut → Launcher** (free, granted to every profile) **→ Sweeper (20 Cells) → Battery Ram (25 Cells)**. Nick must own each node before buying the next. Locked routes still work as generic hits. *(A branching visual tree is **[POST-SLICE]**; the slice's tree is linear.)*

### 5.3. Run Boosters
Before each run, Nick equips temporary boosters in Karen's Shop:
- **Tempo Shield** — an *overshield*: +50 % max shield for the run.
- **Adrenaline** — +20 % move speed.
- **Scrap Magnet** — ×2 Scrap drops. *(Decision D15 deferred.)*
- **Slots:** 1 by default; the **Extra Run Booster Slot** (1 Data Core) adds a second; the same booster cannot occupy two slots. *(Suburbs Skip and Extra-Life boosters are **[POST-SLICE]**.)*

### 5.4. Tempo & Intensity *(see `CodeArchitecture.md` §7)*
The Conductor rests at **128 BPM**. The IntensityController raises the target by +2 BPM per active enemy (cap +16), sampled on primary beats, and is suspended during boss fights; the Headliner's phase 2 sets **160 BPM** directly. Zone music loops on the Conductor grid (zones 128, boss 160).

---

## 6. UI/UX Design **[SLICE]**

The interface is diegetic: the camera feed transmitted by Karen's drone. The game boots to a **title screen** (START RUN → Karen's Shop → run; OPTIONS; QUIT).

### 6.1. The HUD
- **Battery Health Bar:** 12 segments (top-right) with the regenerating **shield** as a thin cyan strip along its top edge.
- **Ability Bar:** the old stamina slot — a horizontal meter under the battery; fills with hits, drives EMP Dash-Cancel and Bass Drop (§3.3).
- **Extra Lives:** stacked battery icons (one per remaining life, up to four shown).
- **Currencies:** SCRAP (cyan), CELLS (magenta), CORES (white), top-left.
- **Epic Combo Multiplier:** a cyan counter that grows with successive landed hits; a whiff or taking damage drops it; at ×50 it glitches and explodes in neon colours (the cap is cosmetic in the slice).
- **Beat pulse:** a small ring at the top centre pulses on every beat (cyan) and downbeat (magenta) — an implicit metronome.
- **Zone title card:** "SECTOR NN — NAME" slides in on every zone entry. The same card carries the "LIFE LOST — N LEFT" / "LAST LIFE" banner.
- **Encounter gates and the GO card:** Zones 1, 4 and 5 are soft screen-locked by a pair of 12 m tall cyan holo-gates (Decision D23) that raise when the encounter starts and open when it is cleared, with a "GO ->" card. (Top-down encounters keep their gates shut until the camera has shifted back.) *(HUD counters are Decision D27, deferred.)*
- **Control prompts:** the Zone 1 prompts are shown only until the player's first Zone 2 entry ever (`seen_controls` in the profile; Decision D34).
- **Boss bar:** a magenta bar in a dark panel at the bottom when a boss or mini-boss activates.

### 6.2. Visual Camera Effects (VCR)
A constant faint scanline overlay and vignette sell the surveillance feed. Whenever Nick takes damage or the drone changes perspective, the feed suffers a **chromatic-aberration burst** that decays over ~0.45 s. Pause, game over, results, shop and title all live on the same feed.

### 6.3. Controls
| Action | Keyboard | Gamepad |
|---|---|---|
| Move | A/D or ←/→ | Left stick / D-pad |
| Depth (top-down only) | W/S or ↑/↓ | Left stick up/down / D-pad up/down |
| Jump | Space | A |
| Light / Heavy | J / K | X / Y |
| Dash / Roll | Shift / Ctrl | RB / B |
| Ultimate (Bass Drop) | L | LB |
| Pause | Esc | Start |
| Options | button on the title screen and the pause menu | same |

- **Depth:** W/S (and the equivalent stick/D-pad axis) do nothing in side-scroll; they move Nick in depth only while the drone is top-down (§3.1, §3.5).
- **Free cancel:** a dash/roll press in the last 40 % of an attack's recovery, once the hit connected, cancels it for no meter (§3.2); the 25-meter EMP Dash-Cancel works in the active window (§3.3).
- **Beat-dodge cue:** a dodge started within ±0.06 s of a beat flashes Nick's rim cyan (§3.2).
- **Options menu (Decision D25):** Master / Music / SFX volume and a fullscreen toggle, reachable from the title screen and the pause menu, saved in the profile.
- **Auto-pause (Decision D29):** the slice pauses itself when the window loses focus.

---

## 7. Technical Architecture
See `CodeArchitecture.md` for the locked contracts. In brief: Godot 4.6 (Forward+), GDScript; node-based state machines for Nick, enemies and the camera; a global `SignalBus` for cross-system events; the **Conductor** autoload as the single tempo authority; one-way damage flow `Hitbox → Hurtbox → HealthComponent`; `Resource` data for every number; `SaveManager` persisting meta-progression only; object pooling for projectiles.

---

## Appendix A — What the slice deliberately leaves out (designed, not built)
Overclock · Ground-Pound · dedicated Air-Combo route · parry · polyrhythm layers · holo-wall / crowd-surge boss hazards · Karen checkpoint (Retry Boss / Full Run) · damage & armour upgrade tiers · branching combo tree · Suburbs Skip / Extra-Life boosters · curved rails with camera yaw · destructible props · Suburbs, Corporate and Tower districts and their bosses · camera-as-weapon · the Double Jump shop purchase (the demo ships it unlocked).

## Appendix B — Open balance decisions (from the 2026-10-24 audit; numbers in `.tres`, tune in `tools/balance_tool.html`)
**Resolved in rev. 3 (applied in code at 8937f29):** D1 Double Jump unlocked in the demo · D3 heavy windows 0.45/0.45/0.75 s and finishers Tri-Cut 32 / Launcher 40 / Battery Ram 55 / Sweeper 20 · D6 beat-dodge ±0.06 s, half refund, cooldown 0.3 s, cyan cue · D7 Bruiser shield 80 (owner will revisit: two generic heavies still break it) · D8 Bass Drop 10 m / 90 · D9/D16 Zone 3–5 wave compositions · D10 kill wall 5.5 m/s over ~119 m · D13 boss HP (Enforcer 900, Headliner 2400) · D14 roll 11 m/s · D17 pass-through on dodge i-frames · D20 death beat · D21 top-down camera (0, 12, 4.5) + ground ring · D22 free cancel · D23 holo gates + GO card · D25 options menu · D28 meter resets on a lost life · D29 auto-pause · D34 prompts once.

**Still open / deferred (do not tune until decided):**
- D2 shop economy: cost curve, caps and yields deferred as too early (prices are flat).
- D4 Cells costs: income is 35 per clear against 45 in the combo tree (Sweeper 20 + Battery Ram 25); proposal A is 15 / 20.
- D15 Scrap Magnet: ×2 Scrap booster, decision deferred.
- D18 top-down facing: proposal A is 8-way facing; deferred.
- D19 boss shield uptime vs HP: revisit after human testing.
- D24 Zone 4 planks: decision deferred.
- D27 HUD counters: decision deferred.
- D33 stagger tiers and post-stagger protection: decision deferred.
