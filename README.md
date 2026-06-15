# Saint Manick

**Saint Manick** is a 2.5D Action-Roguelite Beat'em up set in a decadent, neon-drenched dystopian future. Players control **Nick**, an android combat unit fighting through the radial districts of the city. Guided by **Karen** via a surveillance drone, Nick must fight his way to the great central tower. 

The game features classic heavy beat'em up combat blended with ambient rhythm mechanics, punishing roguelite meta-progression, and dynamic *Nier Automata* style camera shifts where the perspective seamlessly transitions from 2.5D side-scrolling to Top-Down 3D bullet hells.

---

## Project Status: Vertical Slice Prototype (Build A+B) Complete

We have successfully migrated the project to **Godot 4.6** and completed the massive `/goal` sprint to build the foundational **Vertical Slice**. 

**Current Functional Systems:**
- **Drone Camera & Perspective Shifts:** A dynamic Camera3D that tracks the player in 2.5D and seamlessly tweens into a Top-Down perspective when passing through a `CameraShiftTrigger` Area3D.
- **Rhythm Conductor:** An Autoload running a global 128 BPM timer. Enemies hook into the Conductor's signals to synchronize their attacks (e.g. Snipers firing on the downbeat).
- **Roguelite Meta-Loop:** `GameManager` Autoload tracking Max HP, Lives, and Scrap. If Nick dies, the player is routed to **Karen's Shop** (`karens_shop.tscn`) to purchase permanent upgrades using Scrap before restarting.
- **Modular Combat Architecture:** Decoupled Godot components including `HealthComponent`, `Hurtbox3D`, and `Hitbox3D` that govern damage without hardcoded dependencies.
- **Enemy AI Roster:** The 4 prototype enemies (Runner, Bruiser, Sniper, Enforcer, Headliner) have basic chase logic and deal damage upon collision.
- **Master Level Sequence:** `vertical_slice.tscn` connects the 2.5D `Path3D` traversal sequence directly into a bounded Top-Down boss arena.

---

## Next Steps / Immediate Roadmap

With the foundational mechanics blocking out the core loop, the next phase focuses on **game-feel, combat depth, and content creation**.

1. **Combat Combo System Expansion:** 
   - Implement the Hierarchical State Machine (HSM) logic for chained attacks (Light/Heavy strings) and air juggles.
   - Add hit-stop (freeze-frame) and screen-shake for heavy attacks.
2. **Visual Polish & Animation:**
   - Replace the `CapsuleMesh` placeholder characters with rigged 3D models.
   - Integrate Godot `AnimationPlayer` / `AnimationTree` for run, dash, roll, and attack animations.
3. **Level Geometry & Shaders:**
   - Replace `CSGBox3D` block-outs with actual environmental 3D assets (Factory and Neon districts).
   - Implement the proper post-processing stack (bloom, chromatic aberration, retro grading).
4. **Audio & The Rhythm UI:**
   - Integrate the industrial techno backing track.
   - Build the diegetic UI elements (perhaps a heartbeat monitor on the drone UI) so players can *see* the Conductor's tempo if they want to optimize their dodges.

---

## Directory Structure

- **`/_core`** - Autoloads (GameManager, Conductor, SignalBus) and modular node Components (Health, Hitboxes).
- **`/characters`** - Player and Enemy scripts, HSM states, and scenes.
- **`/levels`** - The Vertical Slice prototype map and its trigger components.
- **`/ui`** - The diegetic Input Overlay and Karen's Shop interface.
- **`/Documents`** - The definitive source of truth (GDD, VerticalSlice.md, CodeArchitecture.md).
- **`/UnityProject`** - The legacy Unity 5 prototype codebase (Deprecated).
- **`/2D_Assets`** & **`/3D_Assets`** - Legacy art resources, textures, and models.
