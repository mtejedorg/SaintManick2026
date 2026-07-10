# Asset Index

Entry point for "does this asset already exist?" before generating anything new. Each linked manifest is maintained by the agent that owns that asset type — check the manifest, not the raw folder (avoids opening images/meshes just to confirm existence, and surfaces which of several similarly-named files is actually the canonical one).

| Manifest | Owner | Covers |
|---|---|---|
| [2D_Assets/MANIFEST.md](2D_Assets/MANIFEST.md) | `artist-2d` | UI/HUD art, icons, logos, textures, legacy menu mockups |
| [3D_Assets/MANIFEST.md](3D_Assets/MANIFEST.md) | `artist-3d` | Character/enemy/prop meshes, `.glb`/`.blend` pipeline output |
| [AIConcepts/MANIFEST.md](AIConcepts/MANIFEST.md) | `artist-3d` | Concept art / T-pose source images feeding the 3D pipeline |

Not covered here (small enough that the agent's own file is the manifest):
- Shaders (`assets/shaders/`) — see the "Shader library" table in `.claude/agents/shader-artist.md`
- Audio (`audio/`) — see `audio-designer` briefs in `Documents/audio/`

## Maintenance
- Each manifest is updated by its owning agent at handoff (new asset generated → append a line).
- `code-architect`'s end-of-session housekeeping checks manifests against actual folder contents and flags drift — it does not silently rewrite them. Reconciliation is the owning agent's job.
