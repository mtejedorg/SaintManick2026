# Development Roadmap: Saint Manick

This roadmap outlines the phases of development required to take the project from its current **early prototype state** (movement and basic camera tracking only) to a fully playable **vertical slice** representing the first complete district and boss fight.

---

## Current State Analysis
- **Codebase:** 3 core C# scripts (Base component ID system, physics-based movement, basic raycast-based collision detection, and X-axis camera follow).
- **Unity Version:** Locked to Unity 5.5.0f3.
- **Visual Assets:** UI mockups (HUD, main menu, Game Over), character renders, and wooden platform textures are ready for integration.
- **Missing Core Systems:** Combat system, enemy AI, level management, UI/HUD scripting, upgrade shop, and audio manager.

---

## Milestone 1: Core Combat & Inputs (Input & Attack Integration)
**Goal:** Implement fluid combat inputs, hitboxes, and attack animation states.
- [ ] **Combat State Integration:** Add combat triggers and transitions in the Animator using `HitA` (Light Attack) and `HitB` (Heavy Attack).
- [ ] **Hitbox Management:** Create a script for attacking hitboxes that activate during specific frames of the animation.
- [ ] **Combo State Machine:** Build a basic combo buffer that allows inputs to chain (e.g., A-A-B).
- [ ] **Hit Registration:** Implement an `IDamageable` interface on components to handle damage, stun, and knockback.

## Milestone 2: UI Integration & HUD (Diegetic Drone Feed)
**Goal:** Implement the main menu, high scores, and the live HUD battery system.
- [ ] **Interactive HUD:** Map Nick's health to the 12-segment battery UI assets (`batería-1.png` to `batería-llena.png`). Set up segments to drain sequentially upon damage.
- [ ] **Ability Bar and Lives HUD:** Map the Ability Bar (fills on combo hits — see GDD §3.3) and display extra lives (1-4 Nick icons) based on player state variables.
- [ ] **Main Menu Scenes:** Ingest main menu buttons (PLAY, HISCORE, OPCIONES), adding mouse hover pointers and click triggers.
- [ ] **High Score Loading:** Script the Hiscore menu to read score rankings from `highScores.json` in StreamingAssets.

## Milestone 3: Enemy AI & Spawners (Combat Encounters)
**Goal:** Create basic grunt enemies to populate the first district.
- [ ] **Base Enemy Controller:** Implement a simple patrol AI that detects Nick and moves into combat range.
- [ ] **Enemy Types:** 
  - *Suburban Brawler:* Standard melee unit.
  - *Shielded Scrapper:* Block-heavy unit requiring Heavy Attacks to stun.
- [ ] **Encounter Triggers:** Create zone triggers that lock the camera and spawn waves of enemies, unlocking the camera only when all enemies are defeated.

## Milestone 4: Level Design & Camera Shifts (District 1: Suburbs)
**Goal:** Create a complete level structure for the Suburbs district.
- [ ] **Radial Level Assembly:** Build the Suburbs level using decadent assets, ensuring building heights respect the radial constraint (views of inner districts visible in the background).
- [ ] **Camera Trigger System:** Set up triggers along the level path that command the `CameraController` to shift perspective (e.g., locking Y/Z offsets, panning, or changing depth bounds).
- [ ] **Hazard Zones:** Add environmental obstacles (e.g., decaying electrified neon wires, platform gaps) that test wall-jump and precision-jump physics.

## Milestone 5: Karen's Shop & Upgrades (Progression Hub)
**Goal:** Build the interstitial shop scene to allow upgrades.
- [ ] **Shop Scene UI:** Design the UI interface representing the interior of Karen's Shop (outside the city districts).
- [ ] **Upgrade Logic:** Hook up scrap/credits collected from enemies to buy extra lives, boost health/shield/ability-bar parameters, and purchase/unlock new combo strings.
- [ ] **Radial Map Ingestion:** Create the interactive map screen displaying the city's radial districts, marking the current progress and next level path.

## Milestone 6: Boss Battle & Audio Polish (Vertical Slice Completion)
**Goal:** Develop the first boss encounter and finish audio loading.
- [ ] **Boss Controller:** Implement the Suburbs District Boss with two distinct phases:
  - *Phase 1 (Standard):* Defends with a shield, telegraphs heavy slams.
  - *Phase 2 (Enraged):* Shield breaks at 50% health, attacks become faster, and neon debris falls from the ceiling.
- [ ] **Audio Manager:** Create a script to parse `audio.json` and load soundtracks, background industrial hums, and punch/hit sound effects from StreamingAssets.
- [ ] **Build Pipeline:** Package a standalone PC Windows build for playtesting and verification.
