> [!IMPORTANT]
> **MASTER SOURCE OF TRUTH — Vertical Slice stage (rev. 2, 2026-10-24)**
> This Game Design Document is the officially approved vision for Saint Manick. It supersedes every earlier draft, PDF and presentation in the archives. It is written for the **current stage**: the mechanics are defined, the ten-zone level layout is decided, and the Vertical Slice is the demo. Every mechanic in §3–§6 marked **[SLICE]** is implemented and verified in the build; everything marked **[POST-SLICE]** is designed but deliberately not built yet. Numbers live in the data files named next to them (`.tres`), never only here.

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
- **Double Jump:** a permanent **shop unlock** (Karen's Shop, 200 Scrap). Nothing in the slice *requires* it; it expands platforming and mid-air combat positioning. *(Decision rev. 2: the slice does **not** start with it unlocked; see `VerticalSlice.md` "Player Loadout".)*
- **No depth movement in side-scroll:** Nick is locked to a single combat plane; the up/down inputs do nothing. Depth (Z) freedom unlocks **exclusively** in top-down mode (§3.5).
- **Rails:** each zone's combat plane is a `Path3D`; Nick blends onto the active rail over 0.3 s when the camera hands him a new one. *(Curved rails and a camera that yaws with them are **[POST-SLICE]** — the slice's rails are straight with a short depth dip in Zone 2.)*
- **Falls:** falling out of the world is **not** a reload — Nick returns to his last safe ground and pays HP (20) through the universal damage rule (§5).
- **Ground & wall detection:** `CharacterBody3D` physics; the player body lives on physics layer 2 ("player"), enemies on layer 3, the world on layer 1.

### 3.2. Combat System & Combos **[SLICE]**
Nick fights with two tools that read as one fighter: the **katana** (A, light — fast, blade-forward) and the **bionic arm** (B, heavy — slow, charged, mechanical). There is **no stamina**: mash and chain at will. Basic values *(`characters/player/states/player_state_attack.gd`)*:

| Input | Damage | Window | Knockback | Notes |
|---|---|---|---|---|
| A (light, katana) | 12 | 0.3 s | 4 | hits pressure shields ×1 |
| B (heavy, arm) | 28 | 0.3 s (0.6 s as a chain finisher) | 8 | pressures shields at **×2** but does **not** shatter them |

**Combo routes** *(`characters/player/combos/*.tres` — the Combo Skill Tree, §5.2; a matched route replaces the generic finisher and ends the chain)*:

| Route | Input | Finisher | Identity |
|---|---|---|---|
| **Tri-Cut** | A-A-A | 20 dmg, knockback 4 | three fast blade cuts; single targets |
| **Launcher** | A-A-B | 35 dmg, knockback 12, **launches** | blade opens, arm punches the enemy airborne |
| **Sweeper** | A-B-B | 20 dmg, hitbox ×1.5 wide | wide spinning arm strike; crowd control |
| **Battery Ram** | B-B | 40 dmg, **guard-breaking + shield-breaker**, 0.8 s | the only pure-arm route; the arm commits |

- **Air attacks:** A/B pressed while airborne attack in the air (the ground routes apply). A dedicated *Air-Combo* route that holds launched enemies airborne is **[POST-SLICE]**.
- **Shields (universal rule):** Bruiser, Enforcer and Headliner carry a shield. Light hits pressure it ×1, heavy hits ×2, overflow carries to HP. Only **Battery Ram** and **Bass Drop** *shatter* a shield outright. *(The Bruiser's 50-point shield therefore falls to two generic heavies — see Decision D7 in the audit if that should be raised to 80 so Battery Ram is the intended answer.)*
- **Hit feedback:** hit-stop (0.08 s at 5 % time scale), camera shake (light 0.05 / heavy 0.1), cyan sparks for light hits and magenta for heavy, enemy knockback + stun. Hitboxes are fixed boxes in front of Nick (katana 2.5 m reach, arm 1.6 m), deliberately **not** parented to the animated weapon so hit detection stays deterministic.
- **Defensive move — Dash & Roll:**
  - **Dash** (dedicated input: Shift / RB): 0.25 s burst at 18 m/s, **fully invincible** for its duration, 0.5 s shared dodge cooldown.
  - **Roll** (dedicated input: Ctrl / B): 0.45 s of i-frames then a 0.2 s vulnerable recovery tail, 18 m/s. The primary way to survive bullet hell in top-down.
  - **Beat-aligned reward (never a gate):** a dodge started within ±0.12 s of a beat edge refunds its cooldown and grants +4 ability meter. *(Audit Decision D6 proposes narrowing the window to ±0.06 s and halving the refund so on-beat dash chains cannot stay ~60 % invulnerable.)*

### 3.3. The Ability Bar (Combat Resource) **[SLICE]**
In place of stamina, Nick has an **Ability Bar** (the HUD's old stamina slot). It is a *reward* meter, never a limiter — nothing Nick does is blocked by an empty bar. *(Data: `player.gd`.)*
- **Filling:** +4 per light hit, +9 per heavy hit (classified by damage ≥ 20), +4 per beat-aligned dodge. Out of combat (2 s without a landed hit) it decays at 5/s.
- **Partial spender — EMP Dash-Cancel (25):** during an attack's recovery, Dash cancels straight into a dash, ignoring the dodge cooldown.
- **Full-bar ultimate — Bass Drop (100):** press Ultimate (L / LB) with a full bar to *arm* it; it detonates on the **next downbeat** — the one place the game leans on the beat for spectacle: 60 damage, radius 6 m, shield-breaker, knockback 16, stun 1 s, to every enemy in range. *(Audit Decision D8: radius 10 / damage 90 to read as "screen-clearing".)*
- **[POST-SLICE]:** **Overclock** (~5 s attack speed/damage surge) and the **Ground-Pound** partial spender are designed but not built; additional abilities and a larger bar are future shop items.

### 3.4. Rhythm-Action Escape Sequences (the "Run or Die" sequences) **[SLICE — Zone 8]**
Bespoke traversal set pieces inspired by *Rayman Legends*: the world (collapsing floor, closing blast doors, falling signs) moves to the beat while Nick sprints, jumps and dashes. Reading the heartbeat makes it flow, but inputs are *traversal*, not note-matching.
- **Failure is NOT instant death:** a clipped door or a falling sign costs **HP** (12–15, roughly one battery segment), a touch of the pursuing kill wall costs 15 per beat. Only the universal death rule applies (§5).

### 3.5. Dynamic Camera Perspectives **[SLICE]**
The camera is Karen's drone and moves to give Nick the best tactical view *(`characters/player/drone_camera.gd`, a camera state machine: Sidescroll → Transitioning → TopDown)*.
- **Side-scrolling (depth locked):** offset (0, 3, 10); lateral movement only; jump enabled.
- **Top-down bullet hell (depth unlocked):** the drone climbs to offset (0, 15, 5) and pitches 60°; Nick moves freely on X and Z; **jumping is suppressed**; the roll is the evasive tool. Used in Zone 3 (security lock), Zone 6 (plaza) and the Headliner's phase 2.
- **Transitions:** a 1.5 s tween (2 s for the boss). On completion the player's movement constraint flips (plane-locked ↔ free) and Nick blends onto the new rail. Every shift fires a VCR glitch burst (§6.2).

---

## 4. Enemies & Bosses

### 4.1. The Grunts (rhythmic telegraphing) **[SLICE]**
Enemies hit hard; in compensation their attacks are locked to the Conductor so the beat is a readable cue. All telegraphs use the same language: a white-hot rim flash one beat before the hit. Stats live in `characters/enemies/<type>/<type>_stats.tres`.

| Enemy | HP | Hit | Shield | Scrap | Behaviour |
|---|---|---|---|---|---|
| **Runner** (Scrap-Punk Junkie) | 30 | 8 | — | 8 | chases within aggro range; telegraphs on a beat, lunges on the next |
| **Bruiser** (Riot-Shield Enforcer) | 90 | 20 | 50 | 50 | plants and swings **only on the downbeat** (telegraph on beat 4; hitbox live for exactly one beat); heavy hits pressure the shield, Battery Ram shatters it |
| **Sniper** (Laser-Sight Turret) | 24 | 18 | — | 25 | aims on beat 3, locks on beat 4, **fires on beat 1**; the beam widens/brightens through the cycle |

Scene-placed grunts stay dormant until Nick is within their aggro range; any enemy that falls out of the world is removed silently (no reward). The tempo controller only counts active enemies.

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
A heavily shielded enforcer *(`enforcer_stats.tres`: HP 600, hit 22, Scrap 300, **15 Cells**)*. The first hard **beat-reading test**: an 8-beat cycle — shield up (beat 3 → 1), telegraph (beat 2), a **3-hit burst on beats 2/3/4** (the third hit ×1.3 damage, ×1.8 knockback), then two vulnerable recovery beats at ×1.5 damage taken. The shield is up only while he advances; a shield-breaker hit (Battery Ram / Bass Drop) stuns him for two beats. Its death triggers the Zone 8 security purge.

### 4.4. The Vertical-Slice Boss: The Headliner **[SLICE — Zone 10]**
A towering holographic VJ/DJ idol projected above the rooftop plaza *(`headliner_stats.tres`: HP 1500, hit 25, Scrap 1000, 1 Data Core)*.
- **Phase 1 (side-scroll, 128 BPM):** the Enforcer's cycle at boss scale — shield, telegraph, lunge, recovery — with a 3.5 m shield bubble.
- **Phase 2 (at 50 % HP):** the track jumps to **160 BPM**, the drone executes a Nier-style shift to **top-down bullet hell**, depth movement unlocks, and the Headliner raises a shield while firing a pooled **projection storm**: a 12-shot radial on beat 1, aimed shots on beats 2 and 4, an 8-shot spiral on beat 3 (10 damage each). The phase ends when a shield-breaker lands **or after 24 beats, when the shield overheats** — so a first-run player without Battery Ram is never soft-locked.
- **Enraged:** back to side-scroll, no shield, +20 % speed, melee duel to the finish.
- **Holo-walls and crowd-surge hazards** from the original concept are **[POST-SLICE]**; the slice's phase-2 hazard is the projection storm alone.
- Beating The Headliner ends the Vertical Slice: a 2.5 s hold, then the results screen → Karen's Shop.

### 4.5. The Final Boss: Karen **[POST-SLICE]**
Once Nick reaches the central tower, the truth is revealed: Karen used the journey to test Nick as the ultimate weapon. The shop was her laboratory, and the drone that served as the player's camera becomes her weapon. A checkpoint sits immediately before this fight (**Retry Boss / Full Run** choice). *Camera-as-weapon guiding principle: the drone degrades the feed, never replaces it — Nick stays visible at all times (forced zoom-outs, brief 90° tilts, "signal-loss" static that hides enemy telegraphs so the player survives on the audio heartbeat).*

---

## 5. Progression: The Roguelite Loop & Karen's Shop **[SLICE]**

Saint Manick is **tense and short, but fair**. No mid-level save-scumming.
- **The universal death rule:** Nick has an HP battery (120), a regenerating **shield** (40; regenerates 12/s after 3 s without damage) and **3 lives**. Damage drains shield, then HP. **HP 0 costs a life**: Nick respawns at full HP/shield at the **last zone checkpoint** (every zone entry is a checkpoint; cleared encounters stay cleared, uncleared ones reset) with 1 s of grace. **Permadeath happens only when HP hits 0 with 0 lives remaining** — three lives are three respawns. Hazards, falls and escape failures obey the same rule through the same component.
- **Permadeath → Game Over → Karen's Shop.** The run's currencies are banked, permanent upgrades are bought, a Run Booster is equipped, and a new run starts from Zone 1. Abandoning a run from the pause menu banks the currencies the same way.
- **The Karen Checkpoint** (Retry Boss / Full Run before the final fight) is **[POST-SLICE]**.
- **Meta-progression & out-levelling:** shop upgrades are permanent, so a returning Nick clears the early zones quickly.
- **Difficulty targets:** tuned with `tools/balance_tool.html` toward **2–3 runs (average) / 4–5 runs (weaker)**. *(Audit Decision D2: the slice's scrap yield is ~3.7× the tool's assumptions and prices are flat — a cost curve and caps are proposed before the demo is tuned.)*

### 5.1. Currencies
| Currency (in-game label) | Source in the slice | Sink |
|---|---|---|
| **Scrap** (`SCRAP`) — "Common Scrap" | every enemy kill (8–1000, see §4) | cumulative upgrades, Double Jump |
| **Cells** (`CELLS`) — "Rare Scrap" | the Enforcer (15), the Zone 8 escape (10), the Zone 9 elevator (10) | combo-tree nodes (Sweeper 20, Battery Ram 25) |
| **Cores** (`CORES`) — "Data Cores" | district bosses only (The Headliner: 1) | the extra Run Booster slot (1) |

### 5.2. The Upgrade Structure *(data: `_core/persistence/shop_upgrades/*.tres`)*
- **Cumulative items (repeatable, stack):** Max HP +20 (100 Scrap), Max Shield +10 (150), Extra Life (300). **Double Jump** (200, once). *Damage and armour tiers are designed but **[POST-SLICE]**.*
- **Combo Skill Tree:** a chain — **Tri-Cut → Launcher** (free, granted to every profile) **→ Sweeper (20 Cells) → Battery Ram (25 Cells)**. Nick must own each node before buying the next. Locked routes still work as generic hits. *(A branching visual tree is **[POST-SLICE]**; the slice's tree is linear.)*

### 5.3. Run Boosters
Before each run, Nick equips temporary boosters in Karen's Shop:
- **Tempo Shield** — an *overshield*: +50 % max shield for the run.
- **Adrenaline** — +20 % move speed.
- **Scrap Magnet** — ×2 Scrap drops.
- **Slots:** 1 by default; the **Extra Run Booster Slot** (1 Data Core) adds a second; the same booster cannot occupy two slots. *(Suburbs Skip and Extra-Life boosters are **[POST-SLICE]**.)*

### 5.4. Tempo & Intensity *(see `CodeArchitecture.md` §7)*
The Conductor rests at **128 BPM**. The IntensityController raises the target by +2 BPM per active enemy (cap +16), sampled on primary beats, and is suspended during boss fights; the Headliner's phase 2 sets **160 BPM** directly. Zone music loops on the Conductor grid (zones 128, boss 160).

---

## 6. UI/UX Design **[SLICE]**

The interface is diegetic: the camera feed transmitted by Karen's drone. The game boots to a **title screen** (START RUN → Karen's Shop → run; QUIT).

### 6.1. The HUD
- **Battery Health Bar:** 12 segments (top-right) with the regenerating **shield** as a thin cyan strip along its top edge.
- **Ability Bar:** the old stamina slot — a horizontal meter under the battery; fills with hits, drives EMP Dash-Cancel and Bass Drop (§3.3).
- **Extra Lives:** stacked battery icons (one per remaining life, up to four shown).
- **Currencies:** SCRAP (cyan), CELLS (magenta), CORES (white), top-left.
- **Epic Combo Multiplier:** a cyan counter that grows with successive landed hits; a whiff or taking damage drops it; at ×50 it glitches and explodes in neon colours (the cap is cosmetic in the slice).
- **Beat pulse:** a small ring at the top centre pulses on every beat (cyan) and downbeat (magenta) — an implicit metronome.
- **Zone title card:** "SECTOR NN — NAME" slides in on every zone entry.
- **Boss bar:** a magenta bar in a dark panel at the bottom when a boss or mini-boss activates.

### 6.2. Visual Camera Effects (VCR)
A constant faint scanline overlay and vignette sell the surveillance feed. Whenever Nick takes damage or the drone changes perspective, the feed suffers a **chromatic-aberration burst** that decays over ~0.45 s. Pause, game over, results, shop and title all live on the same feed.

### 6.3. Controls
| Action | Keyboard | Gamepad |
|---|---|---|
| Move | A/D (←/→) | Left stick / D-pad |
| Jump | Space | A |
| Light / Heavy | J / K | X / Y |
| Dash / Roll | Shift / Ctrl | RB / B |
| Ultimate (Bass Drop) | L | LB |
| Pause | Esc | Start |

---

## 7. Technical Architecture
See `CodeArchitecture.md` for the locked contracts. In brief: Godot 4.6 (Forward+), GDScript; node-based state machines for Nick, enemies and the camera; a global `SignalBus` for cross-system events; the **Conductor** autoload as the single tempo authority; one-way damage flow `Hitbox → Hurtbox → HealthComponent`; `Resource` data for every number; `SaveManager` persisting meta-progression only; object pooling for projectiles.

---

## Appendix A — What the slice deliberately leaves out (designed, not built)
Overclock · Ground-Pound · dedicated Air-Combo route · parry · polyrhythm layers · holo-wall / crowd-surge boss hazards · Karen checkpoint (Retry Boss / Full Run) · damage & armour upgrade tiers · branching combo tree · Suburbs Skip / Extra-Life boosters · curved rails with camera yaw · destructible props · Suburbs, Corporate and Tower districts and their bosses · camera-as-weapon.

## Appendix B — Open balance decisions (from the 2026-10-24 audit; numbers in `.tres`, tune in `tools/balance_tool.html`)
D2 shop economy (cost growth, caps, yields) · D3 combo DPS ordering (heavy windows, finisher damage) · D4 Cells costs vs the 35-per-run income · D6 beat-dodge reward window · D7 Bruiser shield 50 → 80 · D8 Bass Drop radius/damage · D9 Zone 4–7 encounter compositions · D10 escape kill-wall speed · boss HP vs player DPS.
