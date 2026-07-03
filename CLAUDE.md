# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## Committing — always ask first

- **Never run `git commit` (or `git push`) without explicit permission.** Do not commit on your own initiative, even when the work is finished and the smoke test passes. Staging and amending count too — when in doubt, stop and ask.
- **Permission to commit is single-use, not a standing order.** A request to commit applies only to the work that exists at that moment. If you make further edits afterward — even right after committing — those new changes must NOT be committed without asking again. "Commit this" never authorizes committing the *next* round of changes.

## What this is

A 2D top-down "escape the dark maze" game built in **Godot 4.6** with **GDScript**, rendered with the **GL Compatibility** renderer (`project.godot`). Neon/Tron visual style. No build step — Godot runs the project directly.

**Game modes** (single «Играть» screen in the menu; gated at runtime by `GameConfig.active_run`):
- **Уровни** (`active_run == -1`) — classic 50-level campaign (difficulty curve stretched: level 40 ≈ old level 20). Progress banks permanently; skills bought/reinforced for SP.
- **Накал** (`active_run` 0..2) — roguelite descent. 3 slots; each run starts from zero (flash+dash+smother), 3 lives for the whole run, endless depth. Carried **ember** is a losable/bankable stake; stations double as **altars** (bank + shop).
- **Спуск дня** (`active_run == DAILY_SLOT` = 3) — daily run: seed = date+level (same maze for everyone), one attempt per day, results/streak in `daily_history`. A hidden 4th run slot reusing the Накал machinery.
- **Difficulty** (`GameConfig.difficulty` 0..2, selector on the «Играть» screen): Тлеющий (easier, rewards ×0.75) / Горящий (base) / Пылающий (in Уровни: **no stations**, light ×2, shards give double gulps + reveal charge; rewards ×1.5). Legacy `hard_mode` migrates to `difficulty=2` on load.

## Commands

Godot is **not on PATH**. Paths per machine:

```bash
# macOS
GODOT="/Applications/Godot.app/Contents/MacOS/Godot"
# Windows (эта машина): это ПАПКА с именем .exe, внутри — консольный exe
GODOT="/c/Users/Varenysheva_E_A/Downloads/Godot_v4.6.3-stable_win64.exe/Godot_v4.6.3-stable_win64_console.exe"

# Run the game (boots res://menu.tscn → Играть → res://main.tscn)
"$GODOT" --path .

# Boot straight into gameplay (uses GameConfig.level from the save; forces Уровни)
"$GODOT" --path . res://main.tscn

# Import assets — REQUIRED after adding any .mp3/.wav/.png, or load() returns null
"$GODOT" --headless --import --path .

# Headless "smoke test" — the only automated check (no unit tests / linter):
"$GODOT" --headless --path . res://main.tscn --quit-after 90 2>&1 \
  | grep -iE "error|SCRIPT|parse|invalid|nonexistent" | grep -viE "resources still|audio"
# "1 resources still in use at exit" is benign. Verify the command actually ran
# (empty output on a WRONG path also looks "clean" — bash passes silently).
```

**The plain smoke test only exercises Уровни.** To test Накал/Спуск дня paths (ember, altar, ranks, `enemy_heat`, daily seed), write a throwaway `SceneTree` harness that calls `GameConfig.start_new_run(0)` (or `start_daily_run()`) before `change_scene_to_file("res://main.tscn")`, runs frames, asserts against `current_scene`. Delete the harness after. **Harnesses pollute the user's save** (level pointer, stats, SP, run slots) — set `GameConfig.test_mode = true` where possible and restore/clean the save afterwards.

No screenshot tool in the engine: to see rendered output, write a throwaway scene that instances the game, awaits `RenderingServer.frame_post_draw`, then saves `get_viewport().get_texture().get_image()`. Run it **windowed** (in `--headless` the `frame_post_draw` signal never fires and the harness hangs). Delete after.

## Architecture

**Everything is procedural.** `main.tscn`, `menu.tscn`, `player.tscn` are one-node stubs — world, walls, lights, HUD are built in code. To change the world or UI, edit `.gd` files, not scenes. No `.tres` — UI is code-side theme overrides, `StyleBoxFlat`, shaders.

### Orchestration — `main.gd` (~3000 lines)
Gameplay root: `_build_world()`, `_build_hud()`, win/death, checkpoints, ranks, events, run-mode hooks (`bank_ember`, `enemy_heat`), boss-gift skill executors (`mirage_decoy`, `breach_wall`, `chrono_freeze`), `_announce_milestones`. Post-win stats screen ends in **buttons** (Дальше / Заново / Магазин навыков / В меню via `_stats_choice` + `_apply_stats_choice`) — hotkey restarts (R/F5/Space) were deliberately removed; restart only through menus. `MAX_LEVEL = 50`.

### Walls — ¾ view (fake 3D)
Wall tile = beveled `CanvasTexture` (albedo+normal) shifted **up by `WALL_H`** (top face) + south face strip + **pooled side faces**: `_update_side_faces()` lays ≤`SIDE_POOL_MAX` (300) reusable sprites around the screen at ~8 Hz, side chosen by player-relative perspective (wall right of player shows its west face). **Do not create per-wall side sprites** — ~8k even invisible CanvasItems cost ~35 FPS on GL Compatibility (measured). Kill-switch: `WALL_SIDE_FACES := false`. Depth: `y_sort_enabled` on main + floor containers.

### Skills (player.gd `_try_*`)
- Base (free): flash Q, dash Shift **or Space**, smother R («Тление»: dim to a spark, speed ×0.55, visibility 0.2 — enemies lose you).
- Purchasable/milestone: sonar E, shield C, guide G, reveal F. Each unlocks EITHER for SP OR automatically via `SKILL_MILESTONES` (config.gd: shards/kills/stations/levels stats).
- **Boss gifts** (never purchasable): mirage T, breach Y, chrono V — granted one per victory over the door-boss.
- **Apex H**: form = top-mastered skill from a 9-skill pool (base 6 + gifts) — see `top_mastered`, `_apply_apex_form`. Requires an active chaser to fire.
- **Repeat purchase = reinforcement**: buying an owned skill adds +1★ mastery (`MASTERY_PER_LEVEL` uses), cap 5★; base skills cost `max(cost, 2)` SP. Mastery = uses/10, +15%/★ via `mastery_bonus`.
- **Воля (will)** is the skill resource (regen + shards + station gulps); **Свет (energy)** is survival only. Stations are refuges: light doesn't drain while inside (`charge_sources`).
- Combos: dash during flash = «Световое копьё» (×1.5); sonar during reveal = «Всевидение». Frozen enemies (stun ≥ 0.5s) take +1 damage — the «Щит+Вспышка» rule.
- Visibility: enemy sight radius scales with `player.visibility_factor()` (flash/ember brighten you, smother hides you).

### Passives — self-growing, always on
`GameConfig.PASSIVE_DEFS`: level 0..5 derived from stats (`dist_total`, `stations_used`, `time_survived`, `shards_total`, `levels_cleared`, `skills_cast`). Applied in `player._apply_passives()` by level. **Not purchasable, no toggles**; reset with stats. The old `passives` dict is save-compat legacy only.

### Boss — optional door
On levels divisible by 5 a crimson skull portal (`boss_door.gd`) leads to an arena built as a **hidden extra floor** (`_boss_floor`, `_building_arena` skips stations/shards). Victory → `_boss_victory()`: next gift from `BOSS_GIFTS`, teleport back, level continues. Fragment deaths are counted via the **single hook `_note_enemy_death`** on every kill path (regular `_die` and apex `_destroy_chaser`) — do not add kill paths that bypass it. `boss_test_enabled` (settings → Тестирование) still forces the old full-arena level.

### Enemies — `pursuer.gd`
Grid-locked BFS per floor. Types 0-2 (SLOW/FAST/CYCLIC) + elites: 3 СТРАЖ (25+, 6HP, sight ×1.4), 4 ФАНТОМ (30+, 1HP, speed 1.3), 5 ПИЯВКА (35+, contact drains **Волю**). Arrays `MAX_HP/TYPE_MULT/VIEW_MULT/LIGHT_COSTS/TYPE_COLORS` are indexed by type — extend all of them together (and `textures.make_enemy`). `distract_to(cell, dur)` is the mirage hook.

### Events (`_trigger_event`)
quake (rare, ~6%: destroys ≤6 inner walls — only odd/even partition cells, never pillars/borders), relief, fog (**local fog blobs** `fog_patch.gd`, not global), leak, flicker, shift. Positive once-per-level extras: Резонанс (3 clean shards → reveal), Эхо шарда (delayed second shard), Тишина (2 quick hits → freeze all), Маяк (`beacon.gd`, with player→beacon pulse hint, toggle `beacon_pulse`).

### Audio
Procedural WAVs in `sounds/` (generators in the session scratchpad, seeds fixed): `ambient_dark.wav` (96s seamless D-minor drone + pentatonic melody; also menu music at −12 dB), `chase_pulse.wav` (heartbeat layer, volume driven by `has_active_chaser()`/heat in `_update_music`), `sk_*.wav` skill sounds. Buses **Music/SFX are created at runtime** in `config.gd:_ensure_audio_buses()`; every player sets `bus`; volumes = settings sliders. WAV loops need `loop_mode/loop_end` set in `_load_audio` (import defaults don't loop).

### Global state — `GameConfig` (config.gd, autoload)
Live vars mirror either the global Уровни profile or a run slot. `save_game()` routes by `active_run` — in a run it writes ONLY slot+stats, never global sections. **Order in `end_run`: persist while `active_run >= 0`, then reset** (regression-tested; resetting first corrupts the global profile). `runs` has **4** slots (3 Накал + DAILY_SLOT); UI loops use `RUN_SLOTS`(3), save/load loops use `runs.size()`. New stat keys MUST be added to the initial `stats` dict or they won't survive a restart (load only reads pre-declared keys). `test_mode` (settings → Тестирование) suppresses XP/stats/history/daily recording — use it in harnesses. `bump_stat`/`max_stat` are the only sanctioned stat mutators.

### Menu — `menu.gd`
Root menu: Играть / Настройки / Справка / Выход. «Играть» opens the mode screen (Уровни-continue + level picker + difficulty toggle, Накал slots, Спуск дня, Обучение, Дневник, Пассивки). **Every `_on_open_*` must call `_hide_all_panels()` first** — panels are siblings in one column; a forgotten visible panel pushes the new one off-screen ("button does nothing"). `_go_back()` is hierarchical: mode-screen children return to the mode screen, the rest to root. Дневник = merged stats/results: «Голос лабиринта» (randomized coaching lines), «Твой стиль» (skill icons + uses + apex forecast), history, daily streak. Reset-progress lives in settings with a two-click confirm.

### Skills menu — `skills_menu.gd` (pause + post-win «Магазин навыков»)
Apex wheel (`ApexWheel` inner class): apex node center, 9 skill nodes on a ring — dark plates + colored rings (ring width = mastery), gold mastery pips, HD icons (`SkillIcons.make_hd` = 2× render + Lanczos downscale), hover/selection rings, mastery threads to the center (brightest pulsing thread + travelling spark = current apex form). Click a node → description panel (fixed 340px width, all labels autowrap — otherwise the wheel shifts). Below: АКТИВНЫЕ column (SP shop with reinforcement buttons and concrete ×N→×M effect lines via `_mastery_line`/`MASTERY_WHAT`) and a read-only column (self-growing passives + gift statuses). Whole page is one ScrollContainer.

### Other pieces
`textures.gd` (`MazeTextures` factory — a generator change propagates everywhere; normal-map encoding tuned for GL Compatibility, don't switch renderers), `station.gd` (gulp + will + checkpoint + altar + refuge), `shard.gd` (passes position for echo), `door.gd`, `exit.gd`, `screenfx.gd` (gold/danger/heat vignettes — heat = ember heartbeat edge), `fog_patch.gd`, `beacon.gd`, `boss.gd`, `boss_door.gd`, `skill_icons.gd` (`SkillIcons.make/make_hd`), `hud_icons.gd`, `touch_joystick.gd`, `organic_floor.gd` (dead — `_organic` is false).

## Conventions

- Comments and ALL in-game strings are in **Russian** — включая новые навыки/панели (bug precedent: gift skills showed raw English ids because SKILL_INFO entries were missing).
- Key R belongs to Тление; **no hotkey restarts anywhere** — restart only via pause/results menus.
- CanvasLayer order: world 0, darkness/tint 1, HUD 2, screenfx 3, results overlay 4, skills_menu 10.
- Effect nodes: set params **before** `add_child`; CPUParticles2D only (GPU particles unreliable on Compatibility).
- Maze grid: `grid[gy][gx]`, passages at odd coords, walls at even; wall open-mask N=1,E=2,S=4,W=8 + diagonals. Floors stacked vertically: world Y encodes floor (`f * _floor_gap`).
- Пассивки never become purchasable again; boss gifts never appear in SP/altar shops.
