# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## What this is

A 2D top-down "escape the dark maze" game built in **Godot 4.6** with **GDScript**, rendered with the **GL Compatibility** renderer (`project.godot`). Neon/Tron visual style. No build step — Godot runs the project directly.

## Commands

Godot is **not on PATH**; use the bundle binary:

```bash
GODOT="/Applications/Godot.app/Contents/MacOS/Godot"

# Run the game (boots the main scene, res://menu.tscn → Play → res://main.tscn)
"$GODOT" --path .

# Boot straight into gameplay, bypassing the menu (uses GameConfig.level from the save)
"$GODOT" --path . res://main.tscn

# Import assets — REQUIRED after adding any .mp3/.png/etc., or load() returns null
"$GODOT" --headless --import --path .

# Headless "smoke test" — the only automated check (there is no unit-test framework or linter).
# Runs the gameplay scene a few frames and surfaces parse/runtime errors:
"$GODOT" --headless --path . res://main.tscn --quit-after 90 2>&1 \
  | grep -iE "error|SCRIPT|parse|invalid|nonexistent" | grep -viE "resources still|audio"
# "1 resources still in use at exit" is a benign headless-shutdown warning, not a code error.
```

There is **no screenshot tool** in the engine and the godot MCP can't capture frames. To see rendered output, write a throwaway scene/script that instances the game, awaits `RenderingServer.frame_post_draw`, then `get_viewport().get_texture().get_image().save_png(...)`, and run it windowed (not `--headless`). Delete the harness after.

## Architecture

**Everything is built procedurally in GDScript.** `main.tscn`, `menu.tscn`, and `player.tscn` are one-node stubs — the world, every wall/light/collectible, and the entire HUD are constructed in code at runtime. To change the world or UI, edit the `.gd` files, not the scenes.

### Orchestration — `main.gd` (~1450 lines)
The gameplay root. `_ready()` reads `GameConfig` then calls `_build_world()` (floors, doors, exit, player, enemies), `_build_hud()`, `_build_screen_fx()`, audio. `_process()` drives time, HUD, random events, the reveal/darkness vignette, and the floor-change toast. Also owns win/death, checkpoints, and public methods other nodes call back into (`collect_shard`, `use_key`, `flash_message`, `beep`, `enemy_hit_fx`, `flash_screen`, `reveal`, `regenerate_floor`).

### Maze grid model
`_grids[floor]` is a 2D bool array `grid[gy][gx]` (`true` = wall), sized `gw × gh` where `gw = cols*2+1`, `gh = rows*2+1`. Passage cells sit at odd coords, walls at even, pillars at intersections. **Floors are stacked vertically in world space**: floor `f`'s container Node2D is offset by `f * _floor_gap`, so a world Y position encodes its floor. Wall open-mask (`_wall_open_mask`) is 8-bit: cardinals N=1,E=2,S=4,W=8 + diagonals (16/32/64/128) used to fill convex corners.

### Lighting & darkness (shaped by the GL Compatibility renderer)
- `CanvasModulate` (`_dark`/`_ambient`) darkens the **world layer only** (not CanvasLayers). Ambient is derived per-level from the theme color.
- The player (`player.gd`) carries **three `PointLight2D`s**: `_light` (shadows), `_wall_light` (edge blaze, `light_mask=2`), `_cone` (forward projector rotated to `_facing`).
- Walls are `Sprite2D`s using normal-mapped `CanvasTexture`s — the normal-map encoding in `textures.gd` is tuned for the GLES3/Compatibility decoder; **don't switch renderers casually.**
- Fog-of-war is a **screen-space vignette** (`darkness.gdshader`, a normal-blend black radial) on a layer-1 `ColorRect`; since the camera centers the player, it reads as a visibility ball. It opens during "Озарение" (reveal). Bloom is a `WorldEnvironment` with glow (works in Compatibility on 4.6).
- **CanvasLayer ordering matters**: world = layer 0; `_tint` + darkness vignette = layer 1; HUD = layer 2; `screenfx.gd` (gold/danger edge vignettes via `vignette.gdshader`, additive) + full-screen flash = layer 3.

### Procedural art — `textures.gd` (`class_name MazeTextures`)
Central factory of `static func`s returning textures: `make_wall_tile`, `make_gem` (crystals), `make_ball`, `make_light`, `make_cone_light`, `make_enemy`, `make_player_orb`, `make_ring`. Used by the player, enemies, stations, shards, exit, doors, and effects. Change a generator here and it propagates everywhere.

### Per-level theming
`WALL_THEMES` (and `ORGANIC_THEMES`, currently dead — `_organic` is hardcoded `false`) in `main.gd` are bright neon base colors cycled by level. The wall tint, edge-glow color, and ambient background are all derived from the current theme color.

### Global state — `GameConfig` (`config.gd`, autoload)
Singleton holding tunables, current level, XP/skill-points, skill unlocks, per-skill mastery, and passives. Saves/loads to `user://maze_off.cfg` via `ConfigFile`. The **menu writes** to it (level selection, settings, passives); **gameplay reads** it. Progression: XP → SP at `XP_PER_SP`; skill mastery scales active-skill power.

### Player — `player.gd`
`CharacterBody2D`. Grid-free movement with wall-slide, an energy/light system that **only drains** (refills come from one-time station "gulps", not standing), and active skills via `_try_*` (`flash`/`dash`/`sonar`/`shield`/`guide`→spark/`reveal`/`apex`). Other nodes call `hit_by_enemy`, `is_shielded`, `apply_enemy_effect`, `add_shake`, `respawn`.

### Enemies — `pursuer.gd` (group `"enemy"`)
Three types (SLOW/FAST/CYCLIC). **Navigation is strictly grid-locked**: BFS on the enemy's own floor grid, moving center-of-cell to adjacent-center — it cannot cut corners or pass through walls. Speed is dynamic (≈150% of player speed when out of view to close distance, scaling down to ≤player-speed when visible/near). Enemies spawn distributed across floors and chase the player's cell *projected* onto their own floor. Contact: with player shielded → enemy frozen 4s (no damage); else → light damage + 1s stun. Recoil is visual-only (offsets the sprite, never the logical position).

### Self-managing effect nodes
`burst.gd` (ring+light), `sparkle.gd` (CPUParticles2D — GPU particles are unreliable on Compatibility), `sonar.gd`, `spark.gd` (guide comet). Pattern: spawn one, set params **before** `add_child`, it animates via `_process` and `queue_free`s itself.

### Other pieces
`station.gd` (blue energy crystals: one-time charge + 3s recharge gauge + checkpoint), `shard.gd` (gold collectibles = keys), `door.gd` (inter-floor teleport, lockable), `exit.gd`, `menu.gd` (neon main menu, all procedural), `skills_menu.gd`, `touch_joystick.gd` (mobile), `organic_floor.gd` (rounded-tunnel floor for organic levels).

## Conventions

- Comments and in-game strings are in **Russian**; match that when editing.
- UI/effects are built with code-side theme overrides and `StyleBoxFlat`/shaders — there are **no `.tres` theme/resource files**.
- After editing a texture/shader generator, re-run the headless smoke test, then verify visuals via a capture harness (the engine has no live screenshot).
