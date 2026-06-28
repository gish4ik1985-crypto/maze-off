# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## Committing — always ask first

- **Never run `git commit` (or `git push`) without explicit permission.** Do not commit on your own initiative, even when the work is finished and the smoke test passes. Staging and amending count too — when in doubt, stop and ask.
- **Permission to commit is single-use, not a standing order.** A request to commit applies only to the work that exists at that moment. If you make further edits afterward — even right after committing — those new changes must NOT be committed without asking again. "Commit this" never authorizes committing the *next* round of changes.

## What this is

A 2D top-down "escape the dark maze" game built in **Godot 4.6** with **GDScript**, rendered with the **GL Compatibility** renderer (`project.godot`). Neon/Tron visual style. No build step — Godot runs the project directly.

**Two game modes** (selected from the menu, gated at runtime by `GameConfig.active_run`):
- **Уровни** (`active_run == -1`) — the classic finite level-checklist (lives reset per level, progress banks permanently, level select, classic skill/SP menu). Unchanged legacy mode.
- **Накал** (`active_run` 0..2) — a roguelite descent. 3 save slots; each run starts **from zero** (only flash+dash), 3 lives for the *whole* run, endless depth, death ends the run. The carried **Накал** (ember) is a losable/bankable stake; **altars** (stations) bank it into in-run currency spent at an altar shop. See "Game modes & runs" below.

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

**Booting `main.tscn` directly runs Уровни mode** (`load_game()` forces `active_run = -1`), so the Накал code paths (ember, altar, ranks, biome HUD, `enemy_heat`) are **not** exercised by the plain smoke test. To test/iterate on Накал, use a throwaway `SceneTree` harness that calls `GameConfig.start_new_run(0)` before `change_scene_to_file("res://main.tscn")`, runs frames, then asserts against the live `current_scene`. Delete the harness after. (This is how `_ember`/`bank_ember`/`_altar_buy`/`_compute_rank`/`_apply_biome` were verified.)

There is **no screenshot tool** in the engine and the godot MCP can't capture frames. To see rendered output, write a throwaway scene/script that instances the game, awaits `RenderingServer.frame_post_draw`, then `get_viewport().get_texture().get_image().save_png(...)`, and run it windowed (not `--headless`). Delete the harness after.

## Architecture

**Everything is built procedurally in GDScript.** `main.tscn`, `menu.tscn`, and `player.tscn` are one-node stubs — the world, every wall/light/collectible, and the entire HUD are constructed in code at runtime. To change the world or UI, edit the `.gd` files, not the scenes.

### Orchestration — `main.gd` (~2200 lines)
The gameplay root. `_ready()` reads `GameConfig` then calls `_build_world()` (floors, doors, exit, player, enemies), `_build_hud()`, `_build_screen_fx()`, audio. `_process()` drives time, HUD, random events, the reveal/darkness vignette, and the floor-change toast. Also owns win/death, checkpoints, ranks, and public methods other nodes call back into (`collect_shard`, `use_key`, `flash_message`, `beep`, `enemy_hit_fx`, `flash_screen`, `reveal`, `regenerate_floor`, plus run-mode hooks `bank_ember`, `enemy_heat`). The level-complete (`on_player_win`) and death (`on_player_death`) paths branch on `GameConfig.active_run`: Накал advances the run slot (endless, lives carry, ember rewarded), Уровни keeps the legacy global behavior. `MAX_LEVEL` is the cap only in Уровни; Накал raises it to ~9999 so the descent is endless (maze size still plateaus at `MAX_DIM`/`MAX_FLOORS`).

### Game modes & runs (Накал)
`main.gd` constants near the top tune the run economy: `EMBER_PER_SHARD`, `EMBER_LEVEL_BONUS`, `EMBER_CLEAN_BONUS`, `EMBER_STREAK_STEP/MAX`, `EMBER_HEAT_FULL`, and `ALTAR_OFFER` (the altar shop list + ember prices).
- **Ember (Накал)** — `_ember` (carried, at risk), `_ember_banked` (currency), `_ember_streak` (clean-floor run → `_ember_mult()`). Carried ember drives `enemy_heat()` (0..1), which the pursuer reads to scale aggression and which main feeds to `player.ember_glow` (brighter light). Death burns half the carried ember + the streak; banking moves carried→banked. `_persist_ember()` writes back into the active run slot dict.
- **Altars** — in Накал, `station.gd` calls back into `bank_ember()` on entry (auto-bank + checkpoint). The shop overlay is `_open_altar_shop()` / `_altar_refresh()` / `_altar_buy()` (pause → "Алтарь — магазин"); it spends banked ember to set `GameConfig.skills_unlocked`/`passives` for the rest of the run.
- **Ranks** — `_compute_rank()` (both modes) scores a level by shard %, no-damage (`_level_clean`), no-skills-used (snapshotted `_skill_uses_at_start`), and time → S/A/B/C/D, shown on the win screen and recorded into `GameConfig.stats["rank_*"]` and the run slot's `ranks` history.

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

### Biomes & per-level theming
`BIOMES` in `main.gd` (3 entries, each a name + neon palette) cycle every `BIOME_SPAN` (5) floors via `_apply_biome()`, which sets `_wall_color` from the biome palette and `_biome_name` (shown in the HUD). The wall tint, edge-glow color, and ambient background are all derived from `_wall_color`. `WALL_THEMES`/`ORGANIC_THEMES` are the older per-level palettes — `WALL_THEMES` now only seeds the default `_wall_color`; `ORGANIC_THEMES` is dead (`_organic` hardcoded `false`).

### Global state — `GameConfig` (`config.gd`, autoload)
Singleton holding tunables, current level, XP/skill-points, skill unlocks, per-skill mastery, and passives. Saves/loads to `user://maze_off.cfg` via `ConfigFile`. The **menu writes** to it (level selection, settings, passives); **gameplay reads** it. Progression: XP → SP at `XP_PER_SP`; skill mastery scales active-skill power.

**Two isolated profiles + save routing (critical):** the "live" vars (`level`, `lives`, `xp`, `skill_points`, `skills_unlocked`, `skill_uses`, `passives`) are a *view* that gameplay reads. They mirror either the global Уровни profile (`active_run == -1`) or a Накал run slot (`active_run` 0..2). `runs` is a 3-element array of run-snapshot dicts (level/depth/lives/ember/skills/ranks/ended); `stats` is global aggregate stats. **`save_game()` routes by `active_run`**: in a run it writes ONLY the slot + stats (`_save_runs_and_stats`), never the global sections — so run progress never clobbers Уровни progress. `start_new_run`/`resume_run`/`leave_run`/`end_run` swap profiles via `_load_run_into_live`/`_sync_live_into_run`; `leave_run`/`end_run` then call `load_levels_profile()` to restore the global view. **Order matters in `end_run`: persist while `active_run >= 0`, *then* reset it** (resetting first would route the save to the global profile and corrupt it — this was a real bug, regression-tested).

### Player — `player.gd`
`CharacterBody2D`. Grid-free movement with wall-slide, an energy/light system that **only drains** (refills come from one-time station "gulps", not standing), and active skills via `_try_*` (`flash`/`dash`/`sonar`/`shield`/`guide`→spark/`reveal`/`apex`). Other nodes call `hit_by_enemy`, `is_shielded`, `apply_enemy_effect`, `add_shake`, `respawn`. Public `ember_glow` (0..1, set by main in Накал) brightens/enlarges the lights — the "the more Накал you carry, the brighter you burn" signal; it's 0 in Уровни so behavior is unchanged.

### Enemies — `pursuer.gd` (group `"enemy"`)
Three types (SLOW/FAST/CYCLIC). **Navigation is strictly grid-locked**: BFS on the enemy's own floor grid, moving center-of-cell to adjacent-center — it cannot cut corners or pass through walls. Speed is dynamic (≈150% of player speed when out of view to close distance, scaling down to ≤player-speed when visible/near); in Накал it's further multiplied by the game's `enemy_heat()` (carried-ember aggression). Enemies spawn distributed across floors and chase the player's cell *projected* onto their own floor. Contact: with player shielded → enemy frozen 4s (no damage); else → light damage + 1s stun. Recoil is visual-only (offsets the sprite, never the logical position).

### Self-managing effect nodes
`burst.gd` (ring+light), `sparkle.gd` (CPUParticles2D — GPU particles are unreliable on Compatibility), `sonar.gd`, `spark.gd` (guide comet). Pattern: spawn one, set params **before** `add_child`, it animates via `_process` and `queue_free`s itself.

### Other pieces
`station.gd` (blue energy crystals: one-time charge + recharge gauge + checkpoint; **in Накал also the altar** — calls back into `bank_ember()` on entry), `shard.gd` (gold collectibles = keys; also grant ember in Накал), `door.gd` (inter-floor teleport, lockable), `exit.gd`, `menu.gd` (neon main menu, all procedural; **builds the run-slot screen, the new-run briefing, and the Статистика screen** alongside the legacy level-select/settings/passives/help — panels toggle visibility, with a persistent top-left "Назад"), `skills_menu.gd` (the SP-based skill tree, used by Уровни pause; Накал uses the altar shop instead), `touch_joystick.gd` (mobile), `organic_floor.gd` (rounded-tunnel floor for organic levels).

## Conventions

- Comments and in-game strings are in **Russian**; match that when editing.
- UI/effects are built with code-side theme overrides and `StyleBoxFlat`/shaders — there are **no `.tres` theme/resource files**.
- After editing a texture/shader generator, re-run the headless smoke test, then verify visuals via a capture harness (the engine has no live screenshot).
