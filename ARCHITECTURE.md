# Архитектура «maze off»

Этот файл — карта того, как всё устроено и как части игры взаимодействуют друг с
другом. Написан для быстрой ориентации: «куда лезть», а не как замена чтению кода.
Подробные соглашения и минные поля — в [CLAUDE.md](CLAUDE.md), это его дополнение
с упором на диаграммы.

**Всё процедурное.** `main.tscn`, `menu.tscn`, `player.tscn` — заглушки в один узел.
Реальный мир, HUD и все экраны строятся кодом в `_ready()`/`_build_*()`. Значит: на
диаграммах ниже узлы сцены — это не `.tscn`-файлы, а то, что код создаёт в рантайме.

---

## 1. Карта модулей — кто на кого ссылается

```mermaid
graph TD
    GameConfig["config.gd (autoload GameConfig)<br/>сохранения · XP/SP · локаль · пассивки"]

    Menu["menu.gd<br/>меню, режимы, настройки, Дневник"]
    Main["main.gd (~4500 строк)<br/>оркестратор уровня: мир, HUD, победа/смерть"]
    Player["player.gd<br/>движение, свет/воля, активные навыки"]
    SkillsMenu["skills_menu.gd<br/>колесо Апекса, магазин навыков"]

    Textures["textures.gd (MazeTextures)<br/>фабрика процедурных текстур"]
    UIStyle["ui_style.gd (UIStyle)<br/>единый стиль кнопок/панелей"]

    Enemy["pursuer.gd<br/>враги: BFS-погоня по сетке"]
    Boss["boss.gd + boss_door.gd<br/>Тёмное Ядро и дверь-босс"]
    Guests["guest_runner/thief/wisp/burrow.gd<br/>редкие мини-события"]

    Pickups["shard.gd · station.gd · door.gd · exit.gd<br/>подбираемое и переходы"]
    FX["burst.gd · sparkle.gd · spark.gd · sonar.gd<br/>screenfx.gd · fog_patch.gd · beacon.gd<br/>эффект-ноды (самоудаляются)"]
    HUDIcons["hud_icons.gd · skill_hud_icon.gd · skill_icons.gd<br/>иконки HUD/колеса"]
    Touch["touch_joystick.gd<br/>мобильный джойстик"]
    Organic["organic_floor.gd<br/>(мёртвый код, _organic=false)"]

    Menu -->|"читает/пишет"| GameConfig
    Main -->|"читает/пишет"| GameConfig
    Player -->|"читает"| GameConfig
    SkillsMenu -->|"читает/пишет"| GameConfig

    Menu -->|"instantiate main.tscn"| Main
    Main -->|"preload player.tscn + set_script"| Player
    Main -->|"открывает поверх себя (CanvasLayer 10)"| SkillsMenu
    Main -->|"инстанцирует и передаёт game=self"| Enemy
    Main --> Boss
    Main --> Guests
    Main --> Pickups
    Main --> FX
    Main --> HUDIcons
    Main --> Touch

    Player -->|"вызывает game.flash_message/beep/…"| Main
    Pickups -->|"game.collect_shard/set_checkpoint/…"| Main
    Enemy -->|"_game.on_player_death/…"| Main
    Boss -->|"_game.flash_message/on_boss_phase2"| Main

    Main --> Textures
    Menu --> UIStyle
    Main --> UIStyle
    SkillsMenu --> UIStyle
    Pickups --> Textures
    Boss --> Textures
```

**Правило связи**: дочерние ноды (враги, подбираемое, эффекты) не хранят
глобальное состояние сами — они дёргают методы `main.gd` через `game`/`_game`
ссылку (`game.flash_message(...)`, `game.collect_shard(...)`, `game.bump_stat`
через `GameConfig` напрямую). `main.gd` — единственный источник истины для
состояния текущего уровня; `GameConfig` — для состояния между уровнями/сессиями.

---

## 2. Экраны и переходы (menu.gd ↔ main.gd)

```mermaid
stateDiagram-v2
    [*] --> RootMenu: старт игры (run/main_scene = menu.tscn)

    RootMenu --> ModeScreen: «Играть»
    RootMenu --> Settings: «Настройки»
    RootMenu --> Help: «Справка»

    ModeScreen --> LevelPick: карточка «Уровни»
    ModeScreen --> RunsSlots: карточка «Накал»
    ModeScreen --> DailyDive: карточка «Спуск дня»
    ModeScreen --> LairSelect: карточка «Логово»
    ModeScreen --> Tutorial: кнопка «Обучение»
    ModeScreen --> Journal: кнопка «Дневник»
    ModeScreen --> Bestiary: кнопка «Бестиарий»

    LevelPick --> GamePlay: GameConfig.active_run = -1
    RunsSlots --> Briefing: выбор пустого слота
    Briefing --> GamePlay: «Начать забег» → start_new_run()
    RunsSlots --> GamePlay: продолжить существующий слот
    DailyDive --> GamePlay: start_daily_run() (active_run = DAILY_SLOT)
    LairSelect --> GamePlay: GameConfig.lair_mode = true
    Tutorial --> GamePlay: GameConfig.tutorial_mode = true

    GamePlay --> ResultsScreen: on_player_win() → _show_stats_screen()
    GamePlay --> TutorialDone: on_player_win() в tutorial_mode\n(пауза + кнопка «Понятно»)
    GamePlay --> GameOver: on_player_death() / забег окончен
    GamePlay --> RootMenu: Esc из паузы → _goto_menu()

    ResultsScreen --> GamePlay: «Дальше»/«Заново» → _restart()
    ResultsScreen --> ModeScreen: «В меню» → _goto_menu()
    TutorialDone --> ModeScreen: GameConfig.open_mode_on_start=true\nменю сразу открывает «Играть»
    GameOver --> RootMenu: Esc → _goto_menu()

    note right of GamePlay
        main.tscn — одна и та же сцена
        для ВСЕХ режимов; ветвление —
        через GameConfig.active_run /
        .tutorial_mode / .lair_mode
    end note
```

Ключевой файл-переключатель — **`GameConfig.active_run`**:

| Значение | Режим | Где живёт прогресс |
|---|---|---|
| `-1` | Уровни (классика, 50 уровней) | глобальный профиль (`level`, `max_unlocked_level`, `xp`, `skill_points`) |
| `0..2` | Накал, слоты 1–3 | `GameConfig.runs[slot]` |
| `3` (`DAILY_SLOT`) | Спуск дня | `GameConfig.runs[DAILY_SLOT]` + `daily_history` |
| `-1` + `lair_mode=true` | Логово | `GameConfig.lair_level`, `lair_max_unlocked` |
| `-1` + `tutorial_mode=true` | Обучение | нигде — `add_xp`/`bump_stat`/`add_skill_use` игнорируются (см. §6) |

---

## 3. Жизненный цикл уровня — `main.gd _ready()` → `_build_world()`

```mermaid
sequenceDiagram
    participant M as main.gd _ready()
    participant BW as _build_world()
    participant Grid as _make_grid() / growing-tree
    participant Floor as _build_floor(f)
    participant Doors as _place_doors()
    participant Exit as _place_exit()
    participant Pl as _spawn_player()
    participant Enemies as _spawn_enemies()/_spawn_elites()
    participant HUD as _build_hud()

    M->>BW: параметры уровня (_cols/_rows/_floors из GameConfig+_level)
    BW->>Grid: карвинг лабиринта на каждый этаж
    BW->>Floor: стены (¾-вид), пол, шарды, станции
    BW->>Doors: переходы между этажами (заперты без ключа)
    BW->>Exit: BFS дальнейшая точка от _entry_cell
    BW->>Pl: инстанс player.tscn, позиция = _entry_cell
    BW->>Enemies: типы/количество по _level, элиты с 25+
    M->>HUD: HUD, скиллы, пауза, звук
    M-->>M: level % 5 == 0 → _setup_boss_door() (дверь-босс)
```

Отдельные ветки внутри `_build_world()` (см. CLAUDE.md за деталями):

- **Мега-лабиринт** (уровень ≥ `MEGA_MAZE_FROM_LEVEL`): `_entry_cell` случайная,
  не `(0,0)` — весь код, работающий со стартом/финишем, обязан использовать
  `_entry_cell`, а не жёсткий угол.
- **Дверь-босс**: строит скрытый «этаж-арену» (`_boss_floor = _floors`, уже ПОСЛЕ
  `_place_exit()`, так что exit никогда не попадает на арену).
- **Обучение/Логово**: `_build_world()` подменяет размеры/флаги ДО общей ветки
  карвинга — см. блок `if GameConfig.tutorial_mode / elif GameConfig.lair_mode`.

---

## 4. Игрок: навыки и ресурсы

```mermaid
graph LR
    subgraph Resources["Ресурсы (player.gd)"]
        Energy["energy = Свет<br/>расход = выживание,\nгаснет → смерть"]
        Will["will = Воля<br/>топливо навыков,\nкормят осколки/станции"]
    end

    subgraph Base["Базовые (бесплатно)"]
        Flash["Q Вспышка"]
        Dash["Shift/Space Рывок"]
        Smother["R Тление"]
    end

    subgraph Purchasable["За SP или авто (SKILL_MILESTONES)"]
        Sonar["E Сонар"]
        Shield["C Щит"]
        Guide["G Искра"]
        Reveal["F Озарение"]
        Pulse["B Пульс"]
    end

    subgraph Gifts["Дары босса (никогда не покупаются)"]
        Mirage["T Мираж"]
        Breach["Y Разлом"]
        Chrono["V Хронос"]
    end

    Apex["H Апекс — форма = самый\nпрокачанный из 9 навыков"]

    Will --> Base
    Will --> Purchasable
    Will --> Gifts
    Base --> Apex
    Purchasable --> Apex
    Gifts --> Apex

    Combo1["Рывок во время Вспышки →\n«Световое копьё» ×1.5"]
    Combo2["Сонар во время Озарения →\n«Всевидение», глушит врагов"]
    Dash -.-> Combo1
    Flash -.-> Combo1
    Sonar -.-> Combo2
    Reveal -.-> Combo2
```

**Мастерство**: повторная «покупка» уже открытого навыка — не покупка, а
усиление (+1★, максимум 5★, `MASTERY_PER_LEVEL` применений на звезду). Апекс
берёт форму от навыка с наибольшим ★ (`GameConfig.top_mastered`).

**Пассивки** (`GameConfig.PASSIVE_DEFS`) — отдельный слой, всегда включены,
растут САМИ от статистики (`dist_total`, `stations_used`, …), не покупаются и
не выключаются. Читаются в `player._apply_passives()`.

---

## 5. Враги, боссы и события

```mermaid
graph TD
    Pursuer["pursuer.gd<br/>BFS по сетке своего этажа"]
    Types["Типы 0-2: SLOW/FAST/CYCLIC<br/>Элиты 3-5: Страж/Фантом/Пиявка<br/>(25+/30+/35+ уровень)"]
    Apex["main.gd apex_ready + player Апекс<br/>срабатывает только при активном преследователе"]

    BossDoor["boss_door.gd<br/>кримзонный портал, level % 5 == 0"]
    Arena["скрытый доп. этаж (_boss_floor)<br/>_building_arena=true → без шардов/станций"]
    BossCore["boss.gd Тёмное Ядро<br/>CHASE/DOUSE/CHARGE/RECOVER"]
    Gift["BOSS_GIFTS → mirage/breach/chrono<br/>победа = 1 дар за раз"]

    Events["_trigger_event() (main.gd)<br/>quake·relief·fog·leak·flicker·shift"]
    Positive["Резонанс·Эхо шарда·Тишина·Маяк<br/>раз за уровень, позитивные"]
    Guests["guest_runner/thief/wisp/burrow.gd<br/>редкие мини-события, спавнятся отдельно"]

    Pursuer --> Types
    Types --> Apex
    BossDoor --> Arena --> BossCore --> Gift
    Gift -.->|"даёт новый навык"| Apex
    Events --> Positive
```

Единая точка учёта убийств — `_note_enemy_death()` (main.gd), вызывается из
ОБОИХ путей смерти врага (`pursuer._die()` и `_destroy_chaser()` апекса).
**Не добавляй новый путь убийства врага в обход этого хука** — на нём висят
статистика/бестиарий/майлстоуны.

---

## 6. Сохранения и прогресс (`config.gd` / autoload `GameConfig`)

```mermaid
graph TD
    Live["Живые переменные GameConfig<br/>(level, xp, skill_points, skills_unlocked, stats, …)"]
    SaveFile["maze_off.cfg (ConfigFile)<br/>user://"]

    Live -->|"save_game()"| SaveFile
    SaveFile -->|"load_game() при старте"| Live

    subgraph Routing["save_game() маршрутизация"]
        direction LR
        R1["active_run == -1 (Уровни/Логово)<br/>→ пишет ГЛОБАЛЬНЫЕ секции"]
        R2["active_run >= 0 (Накал/Спуск дня)<br/>→ пишет ТОЛЬКО runs[slot] + stats"]
    end

    Live --> Routing

    TestMode["test_mode = true<br/>(настройки → Тестирование)"]
    TutMode["tutorial_mode = true<br/>(транзиентный, не сохраняется)"]
    TestMode -.->|"add_xp/bump_stat/\nmax_stat/check_skill_milestones\n— no-op"| Live
    TutMode -.->|"те же геймплейные мутаторы\nигнорируются (см. ниже)"| Live
```

**Обучение не должно прокачивать реальный профиль** — оно намеренно ведёт
себя как `test_mode` для мутаторов `add_xp`/`bump_stat`/`max_stat`/
`check_skill_milestones`, но живое `skill_uses` (мастерство) обучение
ЧИТАЕТ для отслеживания своих шагов («нажми Q» и т.п.) — поэтому вместо
блокировки записи используется снимок/откат
(`main.gd: _tut_skill_uses_snapshot` / `_tut_restore_skill_uses()`),
применяемый в `_goto_menu()` перед `save_game()`.

**Порядок в `end_run` важен**: сначала персист пока `active_run >= 0`,
потом сброс — обратный порядок ломает глобальный профиль (см. CLAUDE.md).

---

## 7. UI-слои и общий стиль

```mermaid
graph TD
    L0["CanvasLayer 0 — мир"]
    L1["CanvasLayer 1 — тьма/тинт (CanvasModulate)"]
    L2["CanvasLayer 2 — HUD"]
    L3["CanvasLayer 3 — screenfx (виньетки)"]
    L4["CanvasLayer 4 — результаты/оверлеи (_show_stats_screen,\n_show_tutorial_complete_screen, altar shop)"]
    L10["CanvasLayer 10 — skills_menu (магазин навыков)"]

    L0 --> L1 --> L2 --> L3 --> L4 --> L10

    UIStyle["UIStyle.make_button() / .panel_stylebox()<br/>ЕДИНСТВЕННАЯ фабрика стиля"]
    L2 -.-> UIStyle
    L4 -.-> UIStyle
    L10 -.-> UIStyle
    Menu2["menu.gd (отдельная сцена, свой стек панелей)"] -.-> UIStyle
```

Все Button-ы обязаны идти через `UIStyle` (main.gd, menu.gd, skills_menu.gd) —
исторически несколько экранов рисовали свои кнопки вручную и расходились
стилем (см. CLAUDE.md, «Every Button… must go through UIStyle»).

`menu.gd` — плоский стек панелей-соседей в одной колонке
(`_menu_box`, `_settings_scroll`, `_help_scroll`, `_runs_box`, …),
переключаемых через `_hide_all_panels()` + показ нужной. Обратная навигация —
`_go_back()`, иерархия описана в шапке функции.

---

## 8. Локализация

```mermaid
graph LR
    Locale["GameConfig.locale (ru/en)"]
    TT["GameConfig.tt(ru, en)<br/>инлайн-пара строк"]
    T["GameConfig.t(key)<br/>словарь STRINGS{ru,en}"]
    Pairs["Локальные RU/EN константы + аксессор<br/>(BESTIARY/lore_en, DIFF_NAMES/_EN,\nSKILL_INFO/_EN, HELP_SLIDE_TITLES/_EN, …)"]

    Locale --> TT
    Locale --> T
    Locale --> Pairs
```

Три параллельных паттерна локализации в проекте (все три — по дизайну, не
случайность): `tt()` для сообщений/разовых строк, `t(key)` для стабильного UI
меню, отдельные `_EN`-константы + функция-аксессор для больших таблиц данных
(бестиарий, сложности, майлстоуны, слайды справки, changelog). Если пишешь
новый текст — используй `tt()`, если не заводишь под него отдельную таблицу.

---

## 9. Куда лезть за конкретной задачей

| Задача | Файл(ы) |
|---|---|
| Новый активный навык игрока | `player.gd` (`_try_*`), `main.gd` (`_update_skills_hud`, HUD-иконка), `skills_menu.gd` (`SKILL_INFO`) |
| Новый враг/элита | `pursuer.gd`, `main.gd` (`_spawn_elites`, массивы `MAX_HP/TYPE_MULT/…`), `config.gd` (`BESTIARY`) |
| Новое случайное событие | `main.gd` (`_trigger_event`, `_update_events`) |
| Новый «гость лабиринта» | `guest_*.gd` + спавн в `main.gd` (`_spawn_guest`) |
| Новый экран меню | `menu.gd` (`_build_*` + `_on_open_*` + `_hide_all_panels()`) |
| Новая пассивка | `config.gd` (`PASSIVE_DEFS`/`PASSIVE_DEFS_EN`), читает `player._apply_passives()` |
| Новый текст/сообщение | обернуть в `GameConfig.tt(ru, en)` — см. §8 |
| Новая механика Накала | `config.gd` (`RUN_CONTRACTS`, обеты), `main.gd` (`_ember_mult`, `_persist_ember`) |

---

*Этот файл описывает структуру на момент версии 1.7. При крупных
архитектурных изменениях (новый режим, смена автозагрузки, новый слой UI) —
обнови соответствующую диаграмму.*
