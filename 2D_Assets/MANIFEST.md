# 2D_Assets Manifest

Maintained by `artist-2d`. Check this before generating a new UI asset. No scene wiring was found for anything in this folder (`2D_Assets` doesn't appear in any `.tscn` as of 2026-07-08) — this is a legacy/raw asset dump (source PSDs, ADs, marketing mockups), not the curated AI-pipeline icon set described in `artist-2d.md`'s size/palette conventions. That set doesn't exist yet; this manifest tracks it once it starts.

Grouped by subfolder rather than itemized — hundreds of raw source files (numbered sequences, PSD/AI layers) where per-file detail isn't load-bearing. If a specific file becomes relevant (referenced in a scene, handed off for integration), promote it to its own line.

## Logos_and_Branding/ (28 files)
Brand logos and marketing artboards — `.ai`/`.pdf` source files plus exported `.png`/`.jpg`. Includes the primary Saint Manick logo (`logo1.png`, `LOGO.ai`) and typography source (`tipografía saint manick*.ai`). Not neon-noir in-game UI art — treat as brand reference only.

## Misc_Images/ (11 files)
Reference images and numbered artboards (`Mesa-de-trabajo-*.jpg`), one external reference piece (`melody_s_escape_by_theshadow2013-*.png`). Mood/reference material, not shippable assets.

## Textures_and_Materials/ (8 files)
Tileable material textures (gravel, leather, rusted metal, rough wood) as `.jpg`/`.tif`, mostly with normal maps. Generic texture library — check here before sourcing a new material texture externally.

## UI_and_Menus/ (94 files)
Raw menu/HUD mockup exports — pre-Godot, pre-neon-noir-direction based on file naming (Spanish labels: "menú principal", "opción menu pause"). Subfolders:
- `2/` — main menu mockup (background, buttons, pointer states)
- `3/` — numbered UI sequence (12 frames) + exit/play button variants
- `game voer/` — game-over screen mockup
- `OPCIÓN PAUSE/` — pause menu mockup
- Root level: health/life-count icons (`*-vida-extra.png`), stamina/battery bar frames (`batería-*.png`, `estamina-*.png`), layered PSD sources (`INTERFAZ*.psd`, `interfaz por capas*`)

These predate the current neon-noir art direction (see `.claude/agents/artist-2d.md` visual language) and the actual in-engine HUD (`ui-designer`'s domain). Treat as legacy reference for what UI *elements* are needed (health, stamina, pause, game-over), not as current-style source art.

## AI-Generated UI Assets
Empty — populate as `artist-2d` generates assets via the assetforge pipeline, per the size/palette conventions in `.claude/agents/artist-2d.md`.

| File | Type | Size (px) | Palette | Status |
|---|---|---|---|---|
| _(none yet)_ | | | | |
