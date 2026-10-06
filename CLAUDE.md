# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## Committing — always ask first

- **Never run `git commit` (or `git push`) without explicit permission.** Do not commit on your own initiative, even when the work is finished and the smoke test passes. Staging and amending count too — when in doubt, stop and ask.
- **Permission to commit is single-use, not a standing order.** A request to commit applies only to the work that exists at that moment. If you make further edits afterward — even right after committing — those new changes must NOT be committed without asking again. "Commit this" never authorizes committing the *next* round of changes.

## Definition of done — never make the user ask for these

Every feature/mechanic/balance change is finished ONLY when all of the
following are done in the same session, unprompted. The user has had to
repeat these requests; treat them as standing orders.

1. **Work on a version branch, not on the current one.** A new version's
   worth of work (`v.1.11`, `v.1.12`, …) gets its own branch created at the
   start — `git checkout -b v.1.N` — before the first edit. Never build a
   new version's changes on top of the previous version's branch.
2. **Sync the design docs**: `GAMEDESIGN.md` (a new numbered section with
   the diagnosis, what was decided, what was implemented, what was
   deliberately deferred) **and** the status dashboard at the top of that
   file, plus `ARCHITECTURE.md` if the change adds a new system, hook, or
   convention other code must follow.
3. **Regenerate the `.html` twins — by script, not by hand.**
   `GAMEDESIGN.html`, `ARCHITECTURE.html`, `CLAUDE.html` and `README.html`
   are GENERATED from the `.md` files: edit only the `.md`, then run
   `python tools/md2html.py` (v5.6; `--check` just reports staleness, and
   `tools/verify.sh` runs it). Never edit a `.html` twin directly — the next
   run overwrites it. Hand-maintained twins had silently lost ~50 KB of
   GAMEDESIGN text by v5.5.
4. **Update the in-game Кодекс.** Two files, and they are NOT the ones the
   file names suggest — check before editing:
   - `codex.gd` — article data (`body` / `body_en`): add or extend the
     article that describes the mechanic. **Also add its unlock rule to
     `Codex.UNLOCK`** (v6.0): the Codex opens article by article as the
     player MEETS the thing (a ladder entry, an enemy type, a mode…), so an
     article about anything absent from level 1 needs a rule — no entry means
     "open from the first minute". `tools/verify.gd` fails on a typo'd key or
     condition, and on an article the "finished everything" profile still
     can't open. New mechanic → its `LADDER` id is the natural condition
     (`ladder:<id>`).
   - `menu.gd` — everything else: the figures in `_codex_figure`.
   There is NO changelog any more: the "What's new" section and the "About
   versions" window were removed in v6.0 (the player asked for them gone —
   the `CHANGELOG_*` constants are history now). Don't reintroduce a
   per-version text duty. A mechanic the player can't read about in-game is
   still not shipped.
5. **Verify with harnesses, then delete them.** Headless smoke for
   Уровни; a throwaway `SceneTree` harness for anything smoke doesn't
   reach (Накал, special levels, menu screens, per-slide UI). Back up
   **the active profile's save file** before, diff it after — find it via
   `user://profiles.cfg`, NOT by assuming `maze_off.cfg`; see the
   save-safety section below.
6. **Re-measure the screen bounds** — see the next section. Any text
   added anywhere in `menu.gd` can push a panel off-screen; this has
   already been reported three separate times.

## Screen bounds — measure, never eyeball

`project.godot` uses `stretch/mode="canvas_items"` with
`aspect="keep_height"`, so **the viewport is ALWAYS 720 units tall** no
matter the window size — only the width varies. "Fits the screen" therefore
means one concrete check: nothing in the centered `_root_col` column may
extend past 720 in viewport units. Window pixels are irrelevant; a harness
comparing against `get_window().size.y` measures nothing.

**After ANY edit that adds or lengthens text in `menu.gd`** — a help slide,
a Codex article, a journal panel, a bestiary card, a settings row — run a
throwaway harness that walks every slide of every carousel and every panel,
and asserts against `get_viewport().get_visible_rect().size.y`. Do this
unprompted; the user should never be the one to notice it.

Two failure modes, both real and both silent:
- **Overflow** — content runs past the bottom edge (Дневник, «Путь
  мастерства», reported 29.07.2026).
- **Clipping without scroll** — a `ScrollContainer` with a hardcoded
  `custom_minimum_size` and `SCROLL_MODE_DISABLED` simply cuts the content
  off, with no scrollbar to hint at it. Справка lost up to 1026px this way
  because its 600×450 cap had been hand-tuned to the tallest slide *of that
  era* and quietly went stale as the content grew.

**Never hardcode a carousel card's height.** Use `_fit_carousel()` (menu.gd):
height follows the content while it fits, then clamps to the measured
remaining space (`_root_col.size.y - sc.size.y` is everything else in the
column — measured, not guessed) and lets `SCROLL_MODE_AUTO` take over.
Scrollbar width is reserved inside the content
(`_carousel_content_width()`), so a bar appearing on one slide never
reflows text or shifts the arrows. Call `_refit_carousel_deferred()` at the
end of every `_populate_*_slide` — Godot needs a frame before
`get_combined_minimum_size()` reflects newly added children.

If a single slide still needs more than ~500px of scrolling, that's a
content problem: split it into two slides rather than making the card
taller.

## Spawn safety — swapping grid dimensions invalidates `_entry_cell`

`_entry_cell` is picked EARLY in level init, from the campaign maze
dimensions. Every code path that later swaps `_cols`/`_rows` — the door-boss
arena, the superboss arena, the oval levels, Логово, anything added next —
**must explicitly re-set `_entry_cell` afterwards.** Otherwise the entry
points outside the new grid and the player spawns in the void: no walls, no
stations, no route to the exit, just a black screen.

This has now shipped twice: the superboss arena (GAMEDESIGN §27) and the
door-boss arena on mega-maze levels 30+ (§28 — the player reported "opened
level 49 and it's dark"; entry was (44,15) in a 12×10 arena). Note the
second one only reproduces with `boss_test_enabled` on, which is a
session-only flag that turns *every* level into an arena — so plain
level-by-level testing missed it.

**The same applies to every point the code TELEPORTS the player to**, not just
the level entry: floor-to-floor doors, shortcut portals, the return from a boss
arena, the choice-room portals. Level 50 shipped this bug a third time — the
door drops you "one floor down, same cell", which is wrong when the arena floor
is smaller than the oval floor above and padded with solid wall (§37). Use
`validate_arrival(body, floor)` (main.gd) after any such teleport; it snaps to
the nearest passage and logs `invalid` like the entry net does.

**Structural guard (v5.6):** field sizes now change ONLY through `_adopt_field_size(cols, rows)` (permanent — boss/superboss arena; re-set `_entry_cell` right after) and `_with_field_size(cols, rows, fn)` (temporary — guaranteed restore of all four of `_cols/_rows/_gw/_gh`). Never assign them directly outside `_init_level_dims`. `tools/verify.gd` also asserts `_gw == _cols*2+1` and `_gh == _rows*2+1` after every scenario (including the superboss test arena) — the four spawn bugs all began with these drifting apart.

`_validate_entry_cell()` (main.gd) is the safety net: it snaps an invalid
entry to the nearest real passage and logs a warning containing the word
**`invalid`**, which the standard smoke-test grep catches. Don't remove that
word, and don't treat the net as a licence to skip the explicit re-set.

**When testing levels, test playability, not construction.** Assert that the
entry is inside the grid, is not a wall, has built walls around it, and that
the exit is BFS-reachable. A harness that only checks "did objects get
created" passes straight through this whole bug class — that is exactly how
§27 shipped. And sweep every mode: Уровни on both Горящий and Пылающий,
Логово, Накал, **and with `boss_test_enabled` on**.

## Physics callbacks — never build Area2D/collisions inside `body_entered`

Godot 4.7 raises «Can't change this state while flushing queries» (hundreds per level) when a `body_entered`/`area_entered` handler creates an `Area2D`, a `CollisionShape2D` or toggles `monitoring`. Floors are built lazily, so `door.gd` → `_ensure_floor_built()` did exactly that. Any handler that builds content (floors, arenas, spawns) must hop out of the physics step with `call_deferred` — see `door.gd::_enter` and `boss_door.gd`.

## Adding a mechanic with a per-level chance

**A once-per-level mechanic needs a once-per-level roll.** Rolling inside a
loop over objects silently becomes "almost always": the herder role rolled per
enemy, so with ~15 enemies and a 0.5 chance it landed on someone 99.997% of the
time, and the fallback branch (giving the role to a Sentinel) was unreachable.
Roll once after spawning, then pick a carrier at random — see
`_assign_herder_role()` (main.gd).


**Do not add a new `*_CHANCE` constant.** Frequency belongs to the biome
(`BIOMES[..].rules` in main.gd, GAMEDESIGN §26): a biome is a rule set that
owns its themed mechanics for its whole `BIOME_SPAN` stretch. Add a key to
`rules` and read it via `_biome_chance()` / `_apply_biome_weights()` +
`_weighted_pick()`. The `rules` key answers "which biome does it rule";
"when is the mechanic introduced at all" is answered by the ladder below.
Reason this rule exists: before v1.11 every mechanic rolled its own
independent lottery, so the player met 1-2 random flashes out of a pool of
~15 per level and never learned any of them — lots of content, nothing to
build mastery on.

**Do not add a new `*_FROM_LEVEL` constant either.** Every level threshold
lives in ONE registry, `GameConfig.LADDER` (config.gd, GAMEDESIGN §38); code
asks `_mech_ready("pits")` (main.gd), never a local constant. Three rules the
registry enforces, all of them regressions that already shipped:

1. **A mechanic's level must fall inside the stretch of the biome that owns
   it** (`BIOME_SPAN` = 5). Otherwise the biome's theme line promises a
   mechanic that is still gated — the Azure Mines advertised shortcut portals
   on levels 1-5 while the gate stood at 8, and the Crimson Depths advertised
   chasms on 6-10 while they waited for 15.
2. **Never hardcode a theme string that names a mechanic.** The biome line is
   generated by `_biome_theme_line()` from what is both biome-allowed and
   ladder-unlocked, so it cannot lie. Add a clause to `BIOME_CLAUSES`.
3. **A new mechanic needs a `what`/`what_en` line** — it becomes the one-time
   «Новое: …» card shown on its entry level (`_announce_ladder`). A mechanic
   that appears in the world without ever introducing itself is exactly the
   complaint that produced §38.

Threshold numbers repeated in prose (codex.gd articles say "from level N")
must be updated with the registry — grep for the old number.

## What this is

A 2D top-down "escape the dark maze" game built in **Godot 4.6** with **GDScript**, rendered with the **GL Compatibility** renderer (`project.godot`). Neon/Tron visual style. No build step — Godot runs the project directly.

**Game modes** (single «Играть» screen in the menu; gated at runtime by `GameConfig.active_run`):
- **Уровни** (`active_run == -1`) — classic 50-level campaign. **The exit is never sealed; its LOCATION is unknown** (GAMEDESIGN §39, v2.0): shards are optional **clues** that narrow it down (floor → compass side → distance → map pin, `_grant_clue`/`_clue_text` in main.gd), and they stay keys for inter-floor doors. `exit_located()` gates the guide spark, the pulse and the minimap marker — anything that would hand the exit over must check it. Tutorial keeps the old "collect all to unseal" rule (difficulty curve stretched: level 40 ≈ old level 20). Progress banks permanently; skills bought/reinforced for SP. From the `LADDER` entry «mega_maze» (level 30) — "мега-лабиринт": higher size/floor caps (`MAX_DIM_MEGA`/`MAX_FLOORS_MEGA`, main.gd) and a randomized `_entry_cell` instead of the fixed (0,0) corner (grid is one connected component regardless of carve start, so any cell works as spawn). Any code assuming the player starts at `Vector2i(0,0)` (farthest-cell BFS, `_passage_cells`/`_dead_end_cells` exclusion, optimal-path calc, win-screen minimap swatch) must use `_entry_cell` instead — that assumption bit us once already (see `_place_exit`, `_compute_optimal_path_len`, `_show_stats_screen`).
- **Накал** (`active_run` 0..2) — roguelite descent. 3 slots; each run starts from zero (flash+dash+smother), 3 lives for the whole run, endless depth. Carried **ember** is a losable/bankable stake; stations double as **altars** (bank + shop).
- **Спуск дня** (`active_run == DAILY_SLOT` = 3) — daily run: seed = date+level (same maze for everyone), one attempt per day, results/streak in `daily_history`. A hidden 4th run slot reusing the Накал machinery.
- **Difficulty** (`GameConfig.difficulty` 0..2, selector on the «Играть» screen): Тлеющий (easier, rewards ×0.75) / Горящий (base) / Пылающий (in Уровни: **no stations**, light ×2, shards give double gulps + reveal charge; rewards ×1.5). Legacy `hard_mode` migrates to `difficulty=2` on load.

## Commands

Godot is **not on PATH**. Paths per machine:

```bash
# macOS
GODOT="/Applications/Godot.app/Contents/MacOS/Godot"
# Windows (эта машина): это ПАПКА с именем .exe, внутри — консольный exe
# Проект ведётся на Godot 4.7.2 — на 4.6 больше не проверяем (решение автора 29.09.2026).
GODOT="/c/Users/Admin/Desktop/Godot_v4.7.2-stable_win64.exe/Godot_v4.7.2-stable_win64_console.exe"

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

**One-command check: `tools/verify.sh`** (v5.6) или **`tools/verify.bat` на Windows-машине без bash** (AUDIT 05.10.2026: та же логика в PowerShell, ASCII-only). Runs the smoke test, then `tools/verify.gd` — a permanent playability sweep (entry inside the grid and not in a wall, exit BFS-reachable) over Уровни on both Горящий and Пылающий, `boss_test_enabled`, Логово 1-10, Пещеры, Накал, Спуск дня, обучение, plus special assertions (arena pocket shape, spawn distance from `_entry_cell`, arena-door setup) — then compares md5 of EVERY `.cfg` in the user dir before/after (all profiles, no need to resolve the active one). Exit code 1 on any failure. Run it before every commit that touches level generation, and add a scenario to `verify.gd` when a new mode or arena appears. Verified to actually fail when the exit is broken (mutation test) — an empty pass proves nothing otherwise.

**Gameplay bot: `tools\bot.bat`** (GAMEDESIGN §94). Plays Уровни for real in 3 styles (speedrun / pro / noob) × 8 levels and prints per-run stats (`BOTRESULT|style|level|outcome|sec|deaths|hits|shards|stuck`) plus a summary. Env overrides: `BOT_LEVELS`, `BOT_MODES`, `BOT_DIFF`, `BOT_TIMEOUT`. Sets `test_mode` every frame; the wrapper snapshots save hashes. Use it to catch regressions in pathing/doors/win-flow that `verify.gd` (build-level) cannot see — it walks the level like a player. Gotchas it already cost us: a cell navigator must check the wall BETWEEN cells (`grid[c.y+n.y+1][c.x+n.x+1]`), and a driven player needs `started = true` or the game silently doesn't tick (no drain, no enemies).

**The plain smoke test only exercises Уровни.** To test Накал/Спуск дня paths (ember, altar, ranks, `enemy_heat`, daily seed), write a throwaway `SceneTree` harness that calls `GameConfig.start_new_run(0)` (or `start_daily_run()`) before `change_scene_to_file("res://main.tscn")`, runs frames, asserts against `current_scene`. Delete the harness after. **Harnesses pollute the user's save** (level pointer, stats, SP, run slots) — set `GameConfig.test_mode = true` where possible and restore/clean the save afterwards.

**There is NO single save file — the game uses PROFILES, and `user://maze_off.cfg` is usually the WRONG file to check.** (`config.gd`, `_save_path`/`_ensure_profiles`.) The layout:

- `user://profiles.cfg` — the index: `[meta] list` (profile names), `[meta] active` (the one in play), `[paths] map` (name → save path).
- `user://profiles/p_<sha256-16>.cfg` — one file per profile created in-game.
- `user://maze_off.cfg` — **only** the path of the FIRST profile (`"Игрок 1"`), kept as-is for pre-v1.9 migration. If the player later created another profile and switched to it, this file is a stale leftover that the game never reads.

**Therefore: resolve the active profile's path before backing anything up.** Read `profiles.cfg` → `[meta] active` → look it up in `[paths] map`. Backing up `maze_off.cfg` and diffing it proves *nothing* about the player's real progress. Real incident (2026-08-05, v5.0): a whole session's worth of "save untouched, md5 identical" checks — including claims written into GAMEDESIGN and a commit message — were run against `maze_off.cfg` while the active profile was `comp1` → `profiles/p_94c2d7203af2a8ad.cfg`. The legacy file said `level=1`, so the player was even told their progress had been reset; their actual profile was level 46 with 139 SP and untouched. The verification was worthless in both directions — it could not have detected damage, and it manufactured a false alarm.

On Windows the whole tree lives in `%APPDATA%\Godot\app_userdata\Maze\`.

**Related harness gotcha — this includes `test_mode` itself, and it has already caused pollution.** Setting `GameConfig.level` (or any other saved field) in a harness's `_initialize()` does NOT stick: the `GameConfig` autoload loads the active profile in its own `_ready()`, which runs afterwards and overwrites it. `test_mode` is *itself a saved setting* (`[settings] test_mode`), so a harness that sets `test_mode = true` in `_initialize()` has it silently reset to the profile's value (normally `false`) — and every `test_mode`-guarded write then fires for real. Real incident (2026-08-05, v5.1): a screen-bounds harness walked all 88 Codex articles, each `_codex_open` called `codex_mark_read` → `save_game()`, and the player's profile came back with every article flagged as read — destroying the brand-new «what haven't I read» feature before they ever saw it. Restored from backup. **Set `test_mode` (and any other saved field) AFTER the autoload is ready** — e.g. on the first `_process` tick once `current_scene` exists — and re-assert it after any `change_scene_to_file`.

**`test_mode` now gates every write — but the flag has to actually be set, and THAT is the part that keeps failing.** `GameConfig.save_game()` opens with `if test_mode: return` (`config.gd`), one chokepoint for the whole project. Chasing individual call sites is no longer the job; **making sure the flag is true at the moment the write fires** is.

Why the chokepoint exists (2026-07-06): `main.gd::_show_start_hint()` fires ~1.6s into level 1 via `call_deferred` from `_ready()`, needs no player input, and called `save_game()` unconditionally. A windowed screenshot harness left open ~10s on level 1 was enough wall-clock time for that timer to land and overwrite the real save with the harness's zeroed state — level 45 → 1, XP/SP → 0, skills relocked, no backup. Per-call-site guards had produced only the illusion of safety; the guard moved into `save_game()` itself.

What still bites, and did again in v5.1: `test_mode` is **itself a saved setting**, so setting it in a harness's `_initialize()` is silently undone when the `GameConfig` autoload loads the profile in its own `_ready()` — see the harness-gotcha paragraph below. Set it after the autoload is ready, re-assert it after every `change_scene_to_file`, and still **back up the active profile file** (resolved via `profiles.cfg`, see above) before any harness that runs for real wall-clock seconds. `bump_stat`/`max_stat` check the flag separately; that's belt-and-braces, not the main line of defence.

No screenshot tool in the engine: to see rendered output, write a throwaway scene that instances the game, awaits `RenderingServer.frame_post_draw`, then saves `get_viewport().get_texture().get_image()`. Run it **windowed** (in `--headless` the `frame_post_draw` signal never fires and the harness hangs). Delete after.

## Architecture

**Everything is procedural.** `main.tscn`, `menu.tscn`, `player.tscn` are one-node stubs — world, walls, lights, HUD are built in code. To change the world or UI, edit `.gd` files, not scenes. No `.tres` — UI is code-side theme overrides, `StyleBoxFlat`, shaders.

### Orchestration — `main.gd` (~8400 lines)
Gameplay root: `_build_world()`, `_build_hud()`, win/death, checkpoints, ranks, events, run-mode hooks (`bank_ember`, `enemy_heat`), boss-gift skill executors (`mirage_decoy`, `breach_wall`, `chrono_freeze`), `_announce_milestones`. Post-win stats screen ends in **buttons** (Дальше / Заново / Магазин навыков / В меню via `_stats_choice` + `_apply_stats_choice`) — hotkey restarts (R/F5/Space) were deliberately removed; restart only through menus. `MAX_LEVEL = 50`.

### Walls — ¾ view (fake 3D), rendered via TileMapLayer (v1.8+)
One `TileMapLayer` per floor (`_floor_tilemaps[f]`) renders AND collision/occludes every wall cell — not a node per cell (pre-1.8 architecture: one Node2D+Sprite2D(s)+LightOccluder2D+CollisionShape2D per wall, ~25-50k nodes on mega-maze floors, multi-second freezes on level load/menu exit; see ARCHITECTURE.md §3 for the full before/after). Tile texture = `MazeTextures.make_wall_tile_combined()` — beveled `CanvasTexture` (albedo+normal) cap + optional south-face strip baked into ONE image (`TILE+WALL_H` tall; transparent strip when no face needed), shifted **up by `WALL_H`** via `TileData.texture_origin`. Sources are built lazily per `(mask, with_face)` key and cached in `_wall_tile_source_id` on the level's shared `_wall_tileset` (`_ensure_wall_tile_source`) — same caching principle as the old `_wall_tex_cache`, just keyed to a TileSet source id instead of a texture. Physics (full-tile collision polygon) and occlusion (full-tile occluder polygon) live on the TileSet's physics/occlusion layers, configured once per source. **Side faces (east/west) were NOT moved to TileMap** — still the pre-existing pooled system: `_update_side_faces()` lays ≤`SIDE_POOL_MAX` (300) reusable sprites around the screen at ~8 Hz, side chosen by player-relative perspective (wall right of player shows its west face), candidates tracked in `_side_cells[f]` (`Vector2i(gx,gy) -> sides:int`, registered by `_register_side_cell` at paint time). **Do not create per-wall side sprites** — ~8k even invisible CanvasItems cost ~35 FPS on GL Compatibility (measured). Kill-switch: `WALL_SIDE_FACES := false`. Depth: `y_sort_enabled` on main + floor containers + each `TileMapLayer`. Runtime wall changes (quake event, Breach skill via `_set_wall`; door-regen event via `regenerate_floor`) just call `TileMapLayer.set_cell()`/`erase_cell()`/`clear()` — no manual node bookkeeping. **`_organic` is live, not dead code** (it was, up to v4.0): `main.gd` sets `_organic = GameConfig.caves_mode`, so the whole Пещеры mode runs through it. Organic wall cells paint an invisible-but-collidable tile (`_ensure_invisible_wall_source`) because `organic_floor.gd` draws the visual itself via `_draw()`. The old "organic levels 11-20" idea is what died — the flag outlived it and now carries Caves.

### Skill unlocks in the campaign (v5.7) — relics, not purchases
In «Уровни» only Flash is open from the start. Every other campaign skill is a **relic**: a `skill_<id>` entry in `GameConfig.LADDER` (level) + `RELIC_ORDER`; `main.gd::_place_relic()` puts a `relic.gd` pillar in a dead end of the entry floor, and `_grant_missed_relic()` hands the skill out on victory if it was missed (so nobody gets stuck). `try_buy_skill` refuses these skills in the campaign — SP only reinforces. **Never read `e["level"]` from LADDER directly** — go through `ladder_level()/ladder_ready()/ladder_new_at()`: Ember/Daily read the old compressed levels from `LADDER_RUN_LEVEL`. New campaign skill = a `skill_*` LADDER entry + `RELIC_ORDER` + a `verify.gd` relic scenario; keep relic levels ≥3 apart and off 5/10/15 (first boss gifts).

### Skill loadout (v6.5) — you carry a few, not all
`GameConfig.loadout` (≤ `loadout_slots()`: campaign 2 → 3 at level 8 → 4 at level 16, Ember 4, tutorial all). `player._skill_ready(id)` needs the skill unlocked AND in the loadout; the Apex is outside the pool and its form comes from `top_mastered`, which only looks at the loadout. New unlocks need no hook — `loadout_auto()` (called from the HUD tick) equips them into a free slot. A new active skill = `LOADOUT_POOL` + `SKILL_DEFS` + `main.gd::_press_skill` + `skills_menu.SKILL_INFO`. GAMEDESIGN §86.

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
Grid-locked BFS per floor. Types 0-2 (SLOW/FAST/CYCLIC) + elites: 3 СТРАЖ (LADDER 27+, 6HP, sight ×1.4), 4 ФАНТОМ (33+, 1HP, speed 1.3), 5 ПИЯВКА (37+, contact drains **Волю**; second Фантом from 42). Gate levels live in `LADDER` (`elite_*` entries) — `main.gd:2809`-area comments and this line were stale at 25+/30+/35+ until the 05.10.2026 audit. Arrays `MAX_HP/TYPE_MULT/VIEW_MULT/LIGHT_COSTS/TYPE_COLORS` are indexed by type — extend all of them together (and `textures.make_enemy`). `distract_to(cell, dur)` is the mirage hook.

### Events (`_trigger_event`)
quake (rare, ~6%: destroys ≤6 inner walls — only odd/even partition cells, never pillars/borders), relief, fog (**local fog blobs** `fog_patch.gd`, not global), leak, flicker, shift. Positive once-per-level extras: Резонанс (3 clean shards → reveal), Эхо шарда (delayed second shard), Тишина (2 quick hits → freeze all), Маяк (`beacon.gd`, with player→beacon pulse hint, toggle `beacon_pulse`).

### Audio
Procedural WAVs in `sounds/` (generators in the session scratchpad, seeds fixed): `ambient_dark.wav` (96s seamless D-minor drone + pentatonic melody; also menu music at −12 dB), `chase_pulse.wav` (heartbeat layer, volume driven by `has_active_chaser()`/heat in `_update_music`), `sk_*.wav` skill sounds. Buses **Music/SFX are created at runtime** in `config.gd:_ensure_audio_buses()`; every player sets `bus`; volumes = settings sliders. WAV loops need `loop_mode/loop_end` set in `_load_audio` (import defaults don't loop).

### Global state — `GameConfig` (config.gd, autoload)
Live vars mirror either the global Уровни profile or a run slot. `save_game()` routes by `active_run` — in a run it writes ONLY slot+stats, never global sections. **Order in `end_run`: persist while `active_run >= 0`, then reset** (regression-tested; resetting first corrupts the global profile). `runs` has **4** slots (3 Накал + DAILY_SLOT); UI loops use `RUN_SLOTS`(3), save/load loops use `runs.size()`. New stat keys MUST be added to the initial `stats` dict or they won't survive a restart (load only reads pre-declared keys). `test_mode` (settings → Тестирование) suppresses XP/stats/history/daily recording — use it in harnesses. `bump_stat`/`max_stat` are the only sanctioned stat mutators.

### Menu — `menu.gd`
Root menu: Играть / Настройки / Кодекс / Выход. «Играть» opens the mode screen (Уровни-continue + level picker + difficulty toggle, Накал slots, Спуск дня, Обучение, Дневник, Пассивки). **Every `_on_open_*` must call `_hide_all_panels()` first** — panels are siblings in one column; a forgotten visible panel pushes the new one off-screen ("button does nothing"). `_go_back()` is hierarchical: mode-screen children return to the mode screen, the rest to root. Дневник = merged stats/results: «Голос лабиринта» (randomized coaching lines), «Твой стиль» (skill icons + uses + apex forecast), history, daily streak. Reset-progress lives in settings with a two-click confirm.

### Skills menu — `skills_menu.gd` (pause + post-win «Магазин навыков»)
Apex wheel (`ApexWheel` inner class): apex node center, 9 skill nodes on a ring — dark plates + colored rings (ring width = mastery), gold mastery pips, HD icons (`SkillIcons.make_hd` = 2× render + Lanczos downscale), hover/selection rings, mastery threads to the center (brightest pulsing thread + travelling spark = current apex form). Click a node → description panel (fixed 340px width, all labels autowrap — otherwise the wheel shifts). Below: АКТИВНЫЕ column (SP shop with reinforcement buttons and concrete ×N→×M effect lines via `_mastery_line`/`MASTERY_WHAT`) and a read-only column (self-growing passives + gift statuses). Whole page is one ScrollContainer.

### Other pieces
`textures.gd` (`MazeTextures` factory — a generator change propagates everywhere; normal-map encoding tuned for GL Compatibility, don't switch renderers), `station.gd` (gulp + will + checkpoint + altar + refuge), `shard.gd` (passes position for echo), `door.gd`, `exit.gd`, `screenfx.gd` (gold/danger/heat vignettes — heat = ember heartbeat edge), `fog_patch.gd`, `beacon.gd`, `boss.gd`, `boss_door.gd`, `skill_icons.gd` (`SkillIcons.make/make_hd`), `hud_icons.gd`, `touch_joystick.gd`, `organic_floor.gd` (live — draws the Пещеры floor, `_organic = caves_mode`), `ui_style.gd` (`UIStyle` — the ONE neon button/panel factory, see Conventions below).

## Conventions

- Comments and ALL in-game strings are in **Russian** — включая новые навыки/панели (bug precedent: gift skills showed raw English ids because SKILL_INFO entries were missing).
- Key R belongs to Тление; **no hotkey restarts anywhere** — restart only via pause/results menus.
- CanvasLayer order: world 0, darkness/tint 1, HUD 2, screenfx 3, results overlay 4, skills_menu 10.
- Effect nodes: set params **before** `add_child`; CPUParticles2D only (GPU particles unreliable on Compatibility).
- Maze grid: `grid[gy][gx]`, passages at odd coords, walls at even; wall open-mask N=1,E=2,S=4,W=8 + diagonals. Floors stacked vertically: world Y encodes floor (`f * _floor_gap`).
- Пассивки never become purchasable again; boss gifts never appear in SP/altar shops.
- **HUD elements go into the edge-anchored containers of `_build_hud()`, never at "x = a neighbour's x + N".** The v5.9 HUD placed the light/will bars at a fixed `sx = 250`; with 8+ skills unlocked the skill icons ran into them (GAMEDESIGN §80). Add a row to the right/centre/bottom `VBoxContainer`; the skill bar centres itself in `_layout_skills()`. Skill icons come ONLY from `SkillIcons.make()` / `make_glyph()` (cached; one `match` glyph per skill in `_glyph`) — never hand-rolled pixel loops. Complex outlines with sharp notches (a heart) must be glyphs, not `HudIcon` polylines: `draw_polyline` spikes at sharp corners.
- **Every `Button` anywhere in the game MUST go through `UIStyle.make_button()` / `UIStyle.style_button()` (`ui_style.gd`)** — the dark-panel neon look (StyleBoxFlat normal/hover/pressed/disabled + hover "breathe" scale tween). Bug precedent (2026-07): pause menu, altar shop, skills-menu shop, results screen, and the "About versions" window (a native `AcceptDialog`!) had all drifted to plain default-grey Godot buttons because each screen either hand-rolled its own `Button.new()` or, in menu.gd's case, kept its own **copy** of the styling code instead of sharing one. `menu.gd`'s `_make_button`/`_style_button` are now thin wrappers around `UIStyle` — don't reintroduce a local copy. Any custom-styled dialog/modal (not just buttons) should use `UIStyle.panel_stylebox()` for its background, not a native `AcceptDialog`/`ConfirmationDialog` (those render with the OS/editor theme, not the game's neon skin). Exception: `_make_touch_button` (mobile virtual joystick overlay) is deliberately translucent/distinct — not a "menu", don't try to unify it.
- **After any UI/menu pass, spot-check every screen for style/back-button consistency** — not just the one the user pointed at. This bug existed in ≥6 places simultaneously (pause, altar, skills shop, results, About-versions dialog); a partial fix reliably draws a follow-up complaint. Same "check everywhere, not just the reported screen" habit applies to panel-bounds/scrolling too (see `_fit_panels()` note above) — when in doubt, sweep all of menu.gd's screens, not just the one mentioned.
- **One back control per screen — the persistent top-left `← Назад`/`_back_btn` (menu.gd) or the pause overlay's own top-left arrow (main.gd).** Never ALSO add a bottom "Назад"/"Закрыть" button that calls the same handler — that's pure duplication, not redundancy-as-safety-net (bug precedent 2026-07: Настройки, Уровни, Логово, Накал×2, Дневник, Бестиарий, Спуск дня, Справка, and skills_menu's "Закрыть (Esc)" all had a second button doing exactly what the corner arrow already does; pause menu's "Продолжить" duplicated its own corner arrow too). If a screen's only exit action IS going back, it needs no bottom button at all — the corner arrow (always visible, set by every `_on_open_*`) is enough. A bottom button is only legitimate when it does something ELSE (e.g. "Начать забег" in the Накал briefing).
- **Any row of settings/options (label + control) must share ONE alignment pattern**, not mix `CheckButton.text=...` (which reserves its own built-in left padding) with `HBoxContainer{ Label(SIZE_EXPAND_FILL) ; control }` rows — the two render with different left edges even at the same `custom_minimum_size`/font_size (bug precedent 2026-07, settings screen: toggle labels sat ~9px right of slider/dropdown labels). Always build toggle rows as `HBoxContainer[Label, CheckButton(text="")]`, matching `_settings_check()` in menu.gd — never let a `CheckButton`/`OptionButton`/etc. carry its own label text if it sits in a column with plain-Label rows.
- **A description/info panel whose content length varies (skill info, node details, …) must be TOP-aligned (`BoxContainer.ALIGNMENT_BEGIN`), never CENTER-aligned**, when it lives in a fixed-height container — center alignment makes the title/first line drift up or down depending on how much text follows (bug precedent 2026-07, skills_menu.gd's `desc_box`: a short skill's name sat lower than a long skill's name). Top-alignment keeps the anchor point (title) fixed regardless of body length.
- **In-game notifications (`flash_message` in main.gd, `_toast` in menu.gd) must render as a bordered panel (`UIStyle.panel_stylebox()`), not bare colored/outlined text** — and must give the player time to read: duration scales with text length (`flash_message`) and `flash_message`'s toast has a visible "×" to dismiss early. Bare colored text that auto-vanishes in ~1.6s reads as a glitchy flicker, not a message (bug precedent 2026-07). Position any new toast/notification below `HUD_BAND` so it doesn't overlap the HUD's own bars/icons.
- **Any color-coded legend (minimap, chart, etc.) must use the ACTUAL colors it's describing** — a legend where every swatch is the same neutral grey glyph/text color (e.g. old `"■ Старт   ■ Выход"` all drawn in one grey font color) tells the player nothing about which color means what (bug precedent 2026-07, the post-level results minimap: start/exit/optimal-path/heat legend was unreadable because none of the "■" glyphs carried their real color). Build legends from real `ColorRect`/gradient swatches sampled from the same color logic as the thing being explained (see `_legend_swatch`/`_legend_heat_swatch` in main.gd).
- **`GridContainer` cannot center itself — it has no `alignment` property** (unlike H/VBoxContainer or HFlowContainer). If its parent ends up wider than the grid's natural width — which happens routinely here, since `root`'s own width is the MAX over every sibling panel's minimum width, not just the currently-visible one — the grid silently hugs the parent's left edge while a `Label` sitting right above it (with `horizontal_alignment = CENTER`) looks perfectly centered, because that Label centers its *text* within its own stretched rect, not the rect itself. The mismatch reads as "the text is centered but the buttons below it are broken" (bug precedent 2026-07: level-select and lair-select grids, both stuck to the left edge on wide windows). Fix: `grid.size_flags_horizontal = Control.SIZE_SHRINK_CENTER` on every `GridContainer` that sits in a column with centered Labels — check this whenever a new `GridContainer` is added anywhere in menu.gd.
