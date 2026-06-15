# Saint Manick

**Saint Manick** is a 2.5D Action-Roguelite Beat'em up set in a decadent, neon-drenched dystopian future. Players control **Nick**, an android combat unit fighting through the radial districts of the city. Guided by **Karen** via a surveillance drone, Nick must fight his way to the great central tower. 

The game features classic heavy beat'em up combat blended with ambient rhythm mechanics, punishing roguelite meta-progression, and dynamic *Nier Automata* style camera shifts where the perspective seamlessly transitions from 2.5D side-scrolling to Top-Down 3D bullet hells.

---

## Project Status: Pre-Production Complete
The initial design phase is 100% complete. We have successfully pivoted the game's vision and are preparing to migrate from Unity to **Godot Engine 4.x**. 

What we have accomplished in pre-production:
1. **Master GDD:** Completely rewrote the Game Design Document to lock in the Action-Roguelite loop, the rhythm mechanics, the plot twist (Karen is the final boss), the biome layout, and the diegetic Drone UI.
2. **Vertical Slice Design:** Mapped out a highly detailed, 10-Zone block-by-block level design document for the initial prototype.
3. **Code Architecture:** Established rigid coding laws for Godot (Node-based Hierarchical State Machines, Global Signal Bus, Resource data management, and strict naming conventions).

---

## Directory Structure

The repository is organized as follows:

- **`/Documents`** - **[MASTER DESIGN FOLDER]** Contains the definitive source of truth for the project.
  - `GDD.md`: The complete Game Design Document.
  - `VerticalSlice.md`: The 10-Zone block-by-block level design blueprint for the prototype.
  - `CodeArchitecture.md`: The strict coding rules and patterns for GDScript.
  - `/Archive`: Contains all legacy (pre-Godot/pre-Roguelite) design drafts, PDFs, and presentations.
- **`/UnityProject`** - The legacy Unity 5 prototype codebase (Deprecated).
- **`/2D_Assets`** & **`/3D_Assets`** - Art resources, textures, and models.
- **`/Renders_and_Videos`** - Media, concept art renders, and promotional videos.
- **`/Mempalace`** & **`/GoogleDrive`** - Additional legacy lore notes and external drive backups.
- **`/Build`** - Destination folder for compiled game executables.
