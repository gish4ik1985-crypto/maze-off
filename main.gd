extends Node2D

const TILE := 48.0        # размер одной клетки сетки в пикселях
const WALL_H := 12.5      # высота «блока» стены в ¾-виде (сдвиг крышки вверх, пиксели)
# Боковые грани блоков (лево/право): видимая сторона зависит от позиции игрока —
# он слева от стены → видит её левую грань (перспектива от игрока). Переключатель
# ниже — быстрый откат: false полностью отключает боковые грани (создание и
# обновление), возвращая вид «только крышка + южная грань».
# [2026-07-27] Выключено: пул боковых граней клал спрайты с рассинхроном
# освещения — у углов/швов они читались как светло-серые «квадратики» на
# стенах при подходе игрока вплотную (многосерийный баг-репорт со скринами).
# Крышки, южные грани и неоновые кромки стен рисуются TileMap'ом как прежде.
const WALL_SIDE_FACES := false
const WALL_SIDE_W := 7.0  # ширина боковой грани (пиксели)
const OCCLUDER_OVERLAP := 1.5  # на сколько px тень стены шире физ.квадрата — без
								# этого на стыке соседних стен свет "протекает"
								# ярким квадратиком, когда игрок вплотную у стены
const MAX_LEVEL := 50     # всего уровней; сложность растянута: ур.40 ≈ прежний ур.20
const ORGANIC_FROM := 11  # с этого уровня лабиринт ветвится как корни/ветки
const MAX_FLOORS := 4     # потолок числа этажей
const MAX_DIM := 44       # потолок размера лабиринта по стороне
const MAX_STATIONS := 40  # потолок станций НА УРОВЕНЬ (см. §46/§53 в GAMEDESIGN);
                          # на многоэтажных уровнях делится между этажами (_spawn_floor_pickups)
# [BUGFIX 02.08.2026, v4.3] Пещеры всегда один этаж — деление MAX_STATIONS
# на _floors (§53) для них не срабатывает никогда, а формула станций
# (_spawn_cave_pickups, 0.22 * число узлов) растёт линейно с размером графа.
# Обзорный харнесс: Пещера 10 (127 узлов) — 27-28 станций, БОЛЬШЕ, чем на
# любом уровне кампании (потолок там держится в районе 6-11 именно за счёт
# деления по этажам). Итог — на поздних Пещерах убежище на каждом шагу и
# давление Света исчезает. Отдельный, более скромный потолок — тот же
# порядок величины, что видит кампания на своём самом крупном одноэтажном
# случае.
const MAX_CAVES_STATIONS := 16
const SHARDS_PER_FLOOR := 5  # осколков света на этаж

# ── «Мега-лабиринт» (с 30-го уровня «Уровней») ──────────────────────────────
# Раньше рост _cols/_rows/_floors упирался в потолок (MAX_DIM/MAX_FLOORS)
# задолго до 30-го уровня, и вход всегда стоял в углу (0,0) — переход между
# уровнями ощущался как жёсткий сброс на то же самое место, а не как спуск
# всё глубже в один большой лабиринт. С этого уровня потолки выше (реальный,
# ощутимый скачок сложности) и старт — случайная проходимая клетка (grid —
# один связный лабиринт целиком, войти можно с любой клетки без потери
# проходимости, так что выход по-прежнему гарантированно достижим).
const MAX_DIM_MEGA := 60
const MAX_FLOORS_MEGA := 6

# ── Накал (режим забега) ─────────────────────────────────────────────────────
const EMBER_PER_SHARD   := 10.0    # Накал за осколок (умножается на серию)
const EMBER_PER_CLUE    := 12.0    # [§44] Накал за улику о выходе — плата за
                                   # новый основной цикл, а не за подметание
# [§44] Поднято с 25. Причина: до §39 забег собирал 10-15 обязательных осколков
# за этаж (100-150 Накала), теперь типичный сбор 4-6 — доход просел почти вдвое,
# хотя риск и ставка не изменились. Часть разницы возвращает этот бонус, часть —
# EMBER_PER_CLUE ниже: платить стоит за то, что игра теперь просит делать.
const EMBER_LEVEL_BONUS := 35.0    # Накал за пройденный этаж
const EMBER_CLEAN_BONUS := 20.0    # доп. Накал, если этаж пройден без потери жизни
const EMBER_STREAK_STEP := 0.25    # +25% к набору за каждый этаж серии
const EMBER_STREAK_MAX  := 8       # потолок серии
const EMBER_HEAT_FULL   := 200.0   # при стольких единицах несомого Накала — макс. «жар»
# Цены апгрейдов на алтаре (в Накале), валюта — забанканный Накал.
const ALTAR_OFFER := [
	{"id": "sonar",    "name": "Сонар (E)",          "name_en": "Sonar (E)",  "cost": 60},
	{"id": "shield",   "name": "Щит (C)",            "name_en": "Shield (C)", "cost": 70},
	{"id": "guide",    "name": "Искра (G)",          "name_en": "Guide (G)",  "cost": 90},
	{"id": "reveal",   "name": "Озарение (F)",       "name_en": "Reveal (F)", "cost": 90},
	{"id": "pulse",    "name": "Пульс (B)",          "name_en": "Pulse (B)",  "cost": 80},
]

const FLOOR_COLOR := Color(0.07, 0.08, 0.11)  # цвет пола (виден только при свете)

# Неоновые цвета стен по уровням (стиль Tron). Это ЯРКИЕ базовые цвета — из них
# textures.gd выводит тёмную крышку блока, цветной ореол грани и оттенок фона.
const WALL_THEMES := [
	Color(0.18, 0.72, 1.00),  # 1: электрик-циан
	Color(0.30, 0.52, 1.00),  # 2: лазурный синий
	Color(0.20, 0.92, 0.85),  # 3: бирюза/аква
	Color(0.50, 0.46, 1.00),  # 4: сине-фиолетовый
	Color(0.42, 0.78, 1.00),  # 5: ледяной голубой
]
var _wall_color: Color = WALL_THEMES[0]

# ── Супербосс (GAMEDESIGN.md §25) — ФУНДАМЕНТ: арена + два типа стен. ──────
# Пока без самого босса (AI — отдельный заход). «Крепкие» стены иммунны к
# любому разрушению (будущий лазер босса, а заодно уже существующие Разлом/
# землетрясение — см. guard в _set_wall) и всегда рисуются нейтральным
# стальным цветом, вне зависимости от неоновой темы уровня (WALL_THEMES/
# ORGANIC_THEMES — все они насыщенные, сталь должна контрастировать с
# ЛЮБОЙ из них, а не только с текущей).
const STRONG_WALL_COLOR := Color(0.78, 0.81, 0.86)
const SUPERBOSS_ARENA_COLS := 34
const SUPERBOSS_ARENA_ROWS := 26
var _strong_cells: Dictionary = {}   # floor_index -> {Vector2i(gx,gy): true}

# Деформация формы (§1/§25 «уточнения перед стартом») — двойной овал: 48-49
# целиком овальные (single-floor), 50 — овал на этаже 0 + арена супербосса
# на отдельном этаже 1 (см. _make_oval_grid, _place_superboss_door).
const OVAL_LEVELS := [48, 49]
const SUPERBOSS_OVAL_COLS := 66   # крупнее эффективного потолка 48/49 (60×48)
const SUPERBOSS_OVAL_ROWS := 54
var _oval_level: bool = false
var _oval_entry: Vector2i = Vector2i(-1, -1)
var _oval_exit: Vector2i = Vector2i(-1, -1)
var _superboss_spawned: bool = false

# Неоновые тоннели (уровни 11-20): тёплый «биолюм» — корни/споры/магма
const ORGANIC_THEMES := [
	Color(1.00, 0.55, 0.18),  # тёплый янтарь
	Color(0.55, 1.00, 0.30),  # споровый лайм
	Color(1.00, 0.28, 0.30),  # магма
	Color(0.30, 0.78, 1.00),  # ледяной грот
	Color(1.00, 0.78, 0.20),  # золото
]
var _organic: bool = false
var _organic_color: Color = ORGANIC_THEMES[0]

# ── Биомы ────────────────────────────────────────────────────────────────────
# Каждые BIOME_SPAN этажей биом сменяется (циклически). Палитра биома задаёт цвет
# стен, ореол граней и оттенок фона (ambient выводится из _wall_color).
#
# [GAMEDESIGN §26 «Биом = набор правил»] Ключ "rules" делает биом не только
# палитрой и топологией, но и ТЕМОЙ механик. До этого каждая механика (ямы,
# порталы-срезки, тёмные станции, гости, события, событийные комнаты) катала
# свою независимую лотерею — игрок за уровень видел 1-2 случайные вспышки из
# пула ~15 и не успевал НИ ОДНУ выучить. Теперь каждая полоса из BIOME_SPAN
# уровней гарантированно даёт свои 2-3 механики и не даёт чужих: тема живёт
# 5 уровней подряд, её успеваешь освоить, а смена биома реально меняет игру.
#
# Поля "rules":
#   shortcut/pits/dark_stations — ВЕРОЯТНОСТЬ спавна (1.0 = гарантированно,
#     0.0 = механики в этом биоме нет). Порог ввода механики стоит сверху и
#     живёт в GameConfig.LADDER (§38) — «когда механика вообще появляется»
#     решает лестница, «в каком биоме она правит» — эти правила. Порог обязан
#     лежать ВНУТРИ полосы своего биома, иначе биом пообещает то, чего нет.
#   guests/events/rooms — ВЕСА выбора внутри своего пула (не вероятность
#     появления самого гостя/события: их частоту задают таймеры). Веса
#     умножаются на базовые, отсутствующий ключ = вес 1.0.
# [GAMEDESIGN §49/§50] Материал стен по биому — план «текстуры вместо оттенка»
# (идея записана 01.08.2026, ведётся по одному биому за версию). Каждый биом
# либо остаётся на нейтральном техно-генераторе по умолчанию (MAT_DEFAULT),
# либо получает собственный: MAT_ORGANIC — Багровые недра (§49, нарост),
# MAT_TECHNOCEUM — Лазурные шахты (§50, инопланетный техноцех: пластины,
# заклёпки, энергожила). Один массив вместо if/elif по биомам — добавление
# следующего материала это новая запись здесь, не переписывание вызовов.
const MAT_DEFAULT := 0
const MAT_ORGANIC := 1
const MAT_TECHNOCEUM := 2
const MAT_FLORA := 3   # [§51] Споровые пустоты — заросли, третий и последний пилот
const BIOME_WALL_MATERIAL := [MAT_TECHNOCEUM, MAT_ORGANIC, MAT_FLORA]
const BIOME_SPAN := 5
const BIOMES := [
	{
		"name": "Лазурные шахты",
		"name_en": "Azure Mines",
		"colors": [
			Color(0.18, 0.72, 1.00), Color(0.30, 0.52, 1.00),
			Color(0.20, 0.92, 0.85), Color(0.42, 0.78, 1.00), Color(0.50, 0.46, 1.00),
		],
		# Тема: СРЕЗКИ И ВОРОВСТВО. Рукотворная топология "rooms" — залы,
		# соединённые ходами; порталы-срезки читаются как техника шахт, вор
		# охотится за светом в обжитом месте. Учит навигации и маршруту.
		"rules": {
			"shortcut": 1.0, "pits": 0.0, "dark_stations": 0.0,
			"mimics": 1.0, "herders": 0.0,   # §34: биом обмана — подделки под станции
			"escalation": 1.25,              # §35: шахты терпеливее — тут ищут маршрут
			"guests": {"thief": 3.0, "hunt": 1.0, "wisp": 1.0, "burrows": 0.5},
			"events": {"flicker": 2.0, "shift": 2.0, "fog": 0.5, "quake": 0.5},
			"rooms": {"choice": 3.0, "echo": 3.0},
		},
	},
	{
		"name": "Багровые недра",
		"name_en": "Crimson Depths",
		"colors": [
			Color(1.00, 0.32, 0.26), Color(1.00, 0.50, 0.16),
			Color(1.00, 0.22, 0.42), Color(0.96, 0.66, 0.20), Color(1.00, 0.40, 0.30),
		],
		# Тема: ПРОВАЛЫ И ПОГОНЯ. Узкие извилистые коридоры ("tree") + ямы =
		# Рывок перестаёт быть кнопкой «убежать» и становится инструментом
		# прохода. Землетрясение/утечка держат землю нестабильной.
		"rules": {
			"shortcut": 0.0, "pits": 1.0, "dark_stations": 0.0,
			"mimics": 0.0, "herders": 1.0,   # §34: тесные коридоры — вотчина загонщика
			"escalation": 1.0,               # §35: базовый темп
			"guests": {"hunt": 3.0, "burrows": 2.0, "thief": 0.5, "wisp": 0.5},
			"events": {"quake": 3.0, "leak": 2.0, "fog": 0.5},
			"rooms": {"shard_altar": 3.0, "dark_trap": 3.0},
		},
	},
	{
		"name": "Споровые пустоты",
		"name_en": "Spore Wastes",
		"colors": [
			Color(0.55, 1.00, 0.30), Color(0.30, 1.00, 0.62),
			Color(0.72, 0.96, 0.22), Color(0.40, 0.92, 0.55), Color(0.62, 1.00, 0.40),
		],
		# Тема: ТЬМА И СКРЫТНОСТЬ. Разреженная сетка ("sparse") — враги видят
		# издалека, тёмные станции сосут Свет, туман глушит обзор. Единственный
		# биом, где Тление важнее скорости: учит играть заметностью.
		"rules": {
			"shortcut": 0.0, "pits": 0.0, "dark_stations": 1.0,
			"mimics": 0.0, "herders": 0.5,   # §34: открытая пещера — загон работает хуже
			"escalation": 0.8,               # §35: тут тебя и так видно — давим раньше
			"guests": {"wisp": 2.0, "burrows": 2.0, "hunt": 1.0, "thief": 0.5},
			"events": {"fog": 3.0, "leak": 2.0, "quake": 0.3},
			"rooms": {"parasite": 3.0, "echo": 2.0},
		},
	},
]
var _biome: int = 0
var _biome_name: String = ""
var _maze_phase: int = 0   # ритм формы: 0 обычный, 1 узкий, 2 широкий (п.1)
var _mega_maze: bool = false      # с уровня LADDER «mega_maze» — увеличенные потолки размера
var _entry_cell: Vector2i = Vector2i.ZERO   # клетка входа на 1-й этаж (обычно (0,0), случайная в мега-лабиринте)
var _hard: bool = false    # хард-режим «Уровней»: без станций (см. _ready)

# --- Позитивные события (GAMEDESIGN п.10): каждое — максимум раз за уровень ---
var _clean_shard_streak: int = 0     # осколки подряд без урона (Резонанс)
var _resonance_done: bool = false    # Резонанс уже был на этом уровне
var _echo_done: bool = false         # Эхо шарда уже было
const ECHO_DARK_CHANCE := 0.18       # §10.3 «тёмная сторона»: засада вместо второго осколка
var _mercy_done: bool = false        # Заморозка-передышка уже была
var _last_hit_time: float = -100.0   # время прошлого удара (для передышки)

# --- Событийные комнаты (GAMEDESIGN.md §5) ---
# Раз в уровень (с уровня LADDER «event_rooms», вероятность EVENT_ROOM_CHANCE)
# вырезается небольшая комната на этаже входа, роль решается случайно из
# EVENT_ROOM_KINDS. Предвестник — золотистое мерцание за 3-5 клеток до
# комнаты (_event_room_warned, разово), без текста — игрок просто чувствует.
const EVENT_ROOM_CHANCE := 0.5
const EVENT_ROOM_KINDS := ["shard_altar", "dark_trap", "choice", "echo", "parasite"]
const EVENT_ROOM_WARN_CELLS := 4.0   # предвестник срабатывает в пределах ~4 клеток
var _event_room_cell: Vector2i = Vector2i(-1, -1)
var _event_room_kind: String = ""
var _event_room_warned: bool = false
var _wall_tex_cache: Dictionary = {}   # open_mask(int) -> CanvasTexture (на время постройки уровня)

var _level: int
var _floors: int
var _cols: int
var _rows: int
var _gw: int
var _gh: int
var _floor_gap: float
var _grids: Array = []
var _cave_graph: Dictionary = {}       # [§62] граф CaveGraph текущего уровня Пещер (пусто вне caves_mode)
var _caves_graph_active: bool = false  # [§62] true пока строится/жив графовый этаж Пещер — читают pursuer.gd (движение/LOS)
var _cave_entry_node: int = -1         # [§62] реальный индекс узла-входа — точнее, чем гонять через приближённую _entry_cell
var _cave_exit_node: int = -1          # [§62] реальный индекс узла-выхода
var _drain_mult: float = 1.0
var _floor_containers: Array = []      # Node2D на каждый этаж
var _floor_built: Dictionary = {}      # какие этажи уже физически построены (см. _ensure_floor_built)
var _floor_is_arena: Dictionary = {}   # [WALLPERF-2026-07] f -> true для этажа-арены двери-босса (без шардов/станций)
var _organic_floors: Array = []        # organic_floor на каждый этаж (для перерисовки)
# [TILEMAP-1.8] Стены рендерятся и коллизионируются через TileMapLayer (один
# на этаж) вместо ноды на каждую клетку-стену — было ~25-50k нод на этаж на
# мега-уровнях (см. ARCHITECTURE.md), вход в уровень занимал секунды. История
# промежуточного варианта (общее физ.тело на этаж, без TileMap) — тег
# WALLPERF-2026-07 в git-истории; он больше не используется.
var _floor_tilemaps: Array = []        # TileMapLayer на каждый этаж
var _wall_tileset: TileSet = null      # общий TileSet уровня, пересоздаётся в _build_world
var _wall_tile_source_id: Dictionary = {}  # int(mask*2+with_face) -> source_id в _wall_tileset
var _wall_invisible_source_id: int = -1    # source для органических этажей (коллизия+тень, без картинки)
var _door_links: Dictionary = {}       # Vector3i(f,cx,cy) -> Array[Vector3i] (переходы между этажами)
var _exit_cell: Vector2i = Vector2i.ZERO
var _exit_floor: int = 0
var _exit_node: Node = null
var _start_exit_dist: float = 1.0   # дистанция старт->выход, для «дыхания» эмбиента (см. _update_music)

# ── Пульс (навык B): звуковой ориентир по коридору, не по прямой ────────────
var _pulse_was_active: bool = false
var _pulse_recalc_timer: float = 0.0
var _pulse_ping_timer: float = 0.0
var _pulse_steps: float = 1.0        # оставшиеся шаги BFS-пути до выхода (кэш)
var _pulse_steps_base: float = 1.0   # шаги в момент активации — точка отсчёта «близости»

var _player: CharacterBody2D
var _cp_pos: Vector2
var _cp_floor: int = 0

var _lives: int = 3
var _shards_collected: int = 0
var _shards_total: int = 0
var _shards_remaining: Array = []   # сколько осколков ещё не собрано на каждом этаже
var _last_floor: int = -1           # для надписи при заходе на новый этаж
var _keys: int = 0

# Накал (активно только при GameConfig.active_run >= 0)
var _ember: float = 0.0          # несомый Накал (под угрозой при гибели)
var _ember_banked: int = 0       # забанканная валюта (тратится на алтаре)
var _ember_streak: int = 0       # серия чистых этажей → множитель набора
var _level_clean: bool = true    # на текущем этаже ещё не теряли жизнь
var _skill_uses_at_start: int = 0  # снимок суммы применений навыков (для ранга «без способностей»)
var _ember_label: Label          # HUD-индикатор Накала
var _altar_layer: CanvasLayer    # оверлей магазина-алтаря
var _altar_rows: GridContainer   # сетка карточек товаров
var _altar_bank_lbl: Label

var _visited: Dictionary = {}    # Vector3i(floor,cx,cy) -> true (для миникарты)
var _heat_map: Dictionary = {}   # Vector3i(floor,cx,cy) -> float (секунды в клетке)
var _heat_sample_t: float = 0.0
# «Эхо времени» (§7, GameConfig.echo_time_enabled/echo_trails) — записывает
# нормализованные (0..1) координаты пути на ЭТАЖЕ ВХОДА этого номера уровня,
# перезаписывая прошлый забег при победе (см. on_player_win). Сэмплится той
# же кадансой, что и _heat_map (0.5с), только пока флаг включён.
var _echo_trail_now: Array = []
const ECHO_TRAIL_MAX_SAMPLES := 400   # ограничение по памяти/размеру сейва на очень долгий уровень
var _optimal_path_len: int = 0   # длина BFS-кратчайшего пути (в клетках)
var _last_rank_line: String = ""    # для экрана результатов (см. on_player_win/_show_stats_screen)
var _last_rank_detail: String = ""

# Босс
const BOSS_EVERY_N := 10         # каждые N уровней в режиме Накал → босс-этаж
const BOSS_ARENA_COLS := 12
const BOSS_ARENA_ROWS := 10
var _boss_level: bool = false
var _superboss_level: bool = false   # §25 GAMEDESIGN.md — финальный уровень кампании (MAX_LEVEL)
var _boss: Node = null
var _boss_fragments: int = 0     # живых фрагментов в фазе 2
var _superboss: Node = null      # §25 GAMEDESIGN.md — тестовый супербосс (не путать с дверным _boss)
const MAX_ALLIES := 2            # §25 шаг 4 — союзники-петы (фундамент, без окна навыков призыва)
var _stats_choice: String = "next"   # выбор на экране результатов
var _boss_floor: int = -1        # индекс скрытого этажа-арены (двер-босс)
var _boss_arena_mode: bool = false      # игрок сейчас на арене
var _boss_defeated_this_level: bool = false
var _boss_return_pos: Vector2 = Vector2.ZERO
var _boss_return_floor: int = 0

# Режим «Логово»: один этаж, тронный зал босса в центре лабиринта (см.
# GameConfig.lair_mode/lair_level). Победа = смерть босса, не золотой выход.
var _lair_active: bool = false
# [v4.0, §60] Режим «Пещеры»: обычный find-the-exit (двери/выход/враги — общий
# путь, что и у «Уровней»), но пол organic (см. GameConfig.caves_mode/level).
var _caves_active: bool = false
var _building_arena: bool = false       # флаг для _build_floor: без станций/осколков
# Дары боссов (по одному за победу, в этом порядке). Все три — активные навыки
# с мастерством и СВОИМИ формами Апекса (Апекс принимает форму самого
# прокачанного навыка — дары расширяют его вариативность).
const BOSS_GIFTS := ["mirage", "breach", "chrono"]
const BOSS_GIFT_NAMES := {"mirage": "Мираж (T)", "breach": "Разлом (Y)", "chrono": "Хронос (V)"}
const BOSS_GIFT_NAMES_EN := {"mirage": "Mirage (T)", "breach": "Breach (Y)", "chrono": "Chrono (V)"}
var _toast_time: float = 0.0
var _elapsed: float = 0.0
var _won: bool = false
var _dead: bool = false
var _paused: bool = false
var _game_over: bool = false

# Случайные события
var _events_enabled: bool = true
var _event_cd: float = 0.0
var _event_active: float = 0.0
# Предвестник (бэклог v1.10 «иконки-предвестники случайных событий») — вид
# события решается заранее, за EVENT_WARN_LEAD секунд до срабатывания, и
# показывается тусклой пульсирующей иконкой-глифом того же события (тем же
# символом, что потом в полноценном сообщении) — игрок учится узнавать,
# что приближается, вместо того чтобы событие било без единого сигнала.
var _event_warn_active: bool = false
var _event_warn_kind: String = ""
var _event_warn_t: float = 0.0
const EVENT_WARN_LEAD := 2.4
const EVENT_ICONS := {
	"quake": "⛰", "shift": "▦", "relief": "✦", "fog": "≈", "leak": "⚠", "flicker": "⚡",
}

# «Живой лабиринт» (GAMEDESIGN.md §10.4) — раз в уровень, не раньше 30 сек,
# если BFS-путь до ближайшей цели (осколок/выход) заметно длиннее, чем по
# прямой (игрок «застрял» в длинном обходе), одна стена рядом растворяется
# явным неоновым эффектом, открывая короткий путь. В отличие от обычной
# регенерации этажа — только ОДНА конкретная стена, прямо у игрока.
var _living_maze_done: bool = false
var _living_maze_cd: float = 30.0
const LIVING_MAZE_DETOUR_MULT := 2.2
const LIVING_MAZE_MIN_STEPS := 6
const LIVING_MAZE_RADIUS := 5

# Маяк (GAMEDESIGN.md п.10.6) — одна временная плюшка-цель за уровень
var _beacon_cd: float = 0.0
var _beacon_spawned: bool = false

# «Гости лабиринта» (GAMEDESIGN.md п.14) — случайное необязательное
# мини-событие, максимум одно за уровень: охота/огонёк/норы/вор.
var _guest_cd: float = 0.0
var _guest_spawned: bool = false

# Обучение: пошаговый степ-трекер (см. _build_tutorial_hud/_update_tutorial).
# У каждого шага — ЦЕЛЬ (в верхней строке) и УРОК: сообщение при выполнении,
# объясняющее, ЧТО это за объект/действие и зачем оно в игре.
# Обучение — TUTORIAL_STAGE_COUNT (3) коротких последовательных мини-уровней
# (GameConfig.tutorial_stage), а не один большой лабиринт разом: каждый этап —
# своя тема, экран «этап пройден» между ними (см. on_player_win). Один и тот
# же движок шагов (_tut_step/_update_tutorial) переиспользуется для всех трёх —
# просто разные массивы шагов и разная стартовая обстановка (_tut_setup_stage_extras).
const TUTORIAL_STEPS_0 := [
	{"goal": "Двигайся: стрелки или WASD",
	 "lesson": "Пока ты движешься во тьме — твой Свет гаснет. Погаснет совсем — жизнь потеряна.",
	 "goal_en": "Move: arrow keys or WASD",
	 "lesson_en": "While you move in the dark, your Light fades. If it runs out completely — you lose a life."},
	{"goal": "Нажми Z, потом X — стойка света (или колесо мыши)",
	 "lesson": "Стойка — твоя ручка Света. ТУСКЛЫЙ: расход ×0.45, тебя почти не видят — но идёшь вслепую. ЯРКИЙ: видишь дальше всего, только горишь ×2.4 и заметен издалека. Свет — не таймер, а валюта за возможность видеть.",
	 "goal_en": "Press Z, then X — light stance (or the mouse wheel)",
	 "lesson_en": "The stance is your Light dial. DIM: drain x0.45, they barely see you — but you walk near-blind. BRIGHT: you see farthest, you just burn x2.4 and are visible from afar. Light is not a timer, it is currency you spend on seeing."},
	{"goal": "Собери золотой осколок света",
	 "lesson": "Осколок: глоток Света, капля Воли, КЛЮЧ от дверей между этажами — и УЛИКА о выходе. Выход не заперт, но и не отмечен: где он, ты не знаешь. Каждая улика сужает круг — этаж, сторона света, расстояние, точка на карте. Осколки необязательны: они покупают знание, а не очки.",
	 "goal_en": "Collect a golden shard of light",
	 "lesson_en": "A shard: a sip of Light, a drop of Will, a KEY for doors between floors — and a CLUE about the exit. The exit is not sealed, but it is not marked either: you do not know where it is. Each clue narrows it down — floor, compass side, distance, a pin on the map. Shards are optional: they buy knowledge, not points."},
	{"goal": "Нажми Q — Вспышка, чтобы осмотреться",
	 "lesson": "Вспышка озаряет всё вокруг — а в упор БЬЁТ врага. Но яркий свет выдаёт тебя тьме.",
	 "goal_en": "Press Q — Flash, to look around",
	 "lesson_en": "Flash lights up everything around you — and HITS an enemy point-blank. But bright light gives you away to the dark."},
	{"goal": "Нажми Shift — Рывок, чтобы сорваться с места",
	 "lesson": "Рывок спасает из ловушек. Рывок СКВОЗЬ врага — таран: урон ему, не тебе.",
	 "goal_en": "Press Shift — Dash, to burst away",
	 "lesson_en": "Dash saves you from traps. Dashing THROUGH an enemy — a tackle: damage to it, not to you."},
	{"goal": "Нажми R — Тление, чтобы спрятаться",
	 "lesson": "Тление гасит тебя до искры: враги теряют след. Медленно — но невидимо.",
	 "goal_en": "Press R — Smother, to hide",
	 "lesson_en": "Smother dims you to a spark: enemies lose your trail. Slow — but invisible."},
	{"goal": "Впереди враг. Подойди и встреться с ним — отбейся любым способом",
	 "lesson": "Контакт с врагом гасит Свет (в реальной игре) — Вспышка в упор бьёт его, Рывок сквозь него таранит, Тление прячет тебя раньше, чем он заметит. Выбирай по ситуации.",
	 "goal_en": "An enemy ahead. Approach and meet it — fend it off any way you like",
	 "lesson_en": "Enemy contact drains your Light (in a real run) — Flash point-blank hits it, Dash through it tackles it, Smother hides you before it even notices. Pick what fits."},
	{"goal": "Дойди до синего кристалла и наберись света",
	 "lesson": "Кристалл — убежище: глоток Света, Воля, точка возврата. Рядом с ним Свет не гаснет.",
	 "goal_en": "Reach the blue crystal and refill your light",
	 "lesson_en": "A crystal is a refuge: a sip of Light, Will, a checkpoint. Your Light doesn't fade near it."},
	{"goal": "Пройди по коридору и оглянись — за тобой остаётся тлеющий след",
	 "lesson": "Клетки, по которым ты прошёл, тлеют: это ТВОЯ земля, на ней Свет тратится медленнее. Тьма отвоёвывает её обратно — тем быстрее, чем ярче ты горишь. Отсюда выбор: разогнать свет и видеть дальше, теряя тыл, — или пригаситься и удержать коридор за спиной.",
	 "goal_en": "Walk down the corridor and look back — a smouldering trail stays behind you",
	 "lesson_en": "The cells you walk keep smouldering: that ground is YOURS, and Light drains slower on it. The dark takes it back — faster the brighter you burn. Hence the choice: burn bright and see further while losing your rear, or dim down and hold the corridor behind you."},
	{"goal": "Нажми M — Метка, чтобы приколоть эту клетку силой",
	 "lesson": "Метка держит клетку своей 45 секунд, что бы ни делала тьма. Цена — кусок самого Света, а не Воли, как у остальных навыков: ты жертвуешь обзором и запасом, а не перезарядкой. Ей же можно намеренно прикрыть развилку перед тем, как уйти вперёд.",
	 "goal_en": "Press M — Mark, to pin this cell by force",
	 "lesson_en": "A Mark holds a cell as yours for 45 seconds no matter what the dark does. The cost is a chunk of Light itself, not Will like every other skill — you trade sight and stamina, not a cooldown. Use it to deliberately cover a junction before you move on."},
	{"goal": "Теперь НАЙДИ выход — он не отмечен на карте",
	 "lesson": "",
	 "goal_en": "Now FIND the exit — it is not marked on your map",
	 "lesson_en": ""},
]
const TUTORIAL_STEPS_1 := [
	{"goal": "Двигайся: стрелки или WASD",
	 "lesson": "Второй этап обучения: продвинутые навыки. Всё, что уже умеешь (Q/Shift/R), здесь тоже работает.",
	 "goal_en": "Move: arrow keys or WASD",
	 "lesson_en": "Tutorial stage two: advanced skills. Everything you already know (Q/Shift/R) still works here."},
	{"goal": "Нажми E — Сонар, чтобы увидеть планировку сквозь тьму",
	 "lesson": "Сонар — чистая разведка, не бой: кольцо расходится сквозь стены, послесвечение держит обзор ещё несколько секунд.",
	 "goal_en": "Press E — Sonar, to see the layout through the dark",
	 "lesson_en": "Sonar is pure recon, not combat: the ring passes through walls, and its afterglow keeps you seeing for a few more seconds."},
	{"goal": "Нажми C — Щит, чтобы поставить защиту",
	 "lesson": "Щит замораживает врага при контакте вместо урона по тебе. Замороженный враг уязвим — на нём +1 урона от любого удара.",
	 "goal_en": "Press C — Shield, to raise a guard",
	 "lesson_en": "Shield freezes an enemy on contact instead of hurting you. A frozen enemy is vulnerable — +1 damage from any hit."},
	{"goal": "Держи Щит и во время него сделай Рывок рядом с врагом — комбо «Щит + Рывок»",
	 "lesson": "Комбо «Щит + Рывок»: рывок под щитом замораживает врага И бьёт тараном — сильнее, чем по отдельности.",
	 "goal_en": "Hold Shield and Dash near the enemy while it's up — the «Shield + Dash» combo",
	 "lesson_en": "«Shield + Dash» combo: dashing while shielded freezes the enemy AND rams it — stronger than either alone."},
	{"goal": "Нажми G — Искра, она укажет путь к цели",
	 "lesson": "Искра сама летит по кратчайшему маршруту — сперва к непойманным осколкам, потом к выходу.",
	 "goal_en": "Press G — Guide, it points the way to your goal",
	 "lesson_en": "The guide spark flies the shortest route on its own — to unclaimed shards first, then to the exit."},
	{"goal": "Нажми F — Озарение, чтобы разогнать тьму",
	 "lesson": "Озарение раздвигает тьму на весь этаж на несколько секунд — заряжается постепенно, от осколков и станций.",
	 "goal_en": "Press F — Reveal, to push back the dark",
	 "lesson_en": "Reveal pushes back the dark across the whole floor for a few seconds — it charges gradually, from shards and stations."},
	{"goal": "Нажми B — Пульс, чтобы почувствовать врагов сквозь стены",
	 "lesson": "Пульс — звуковой ориентир: чувствуешь направление и силу угрозы, даже не видя её.",
	 "goal_en": "Press B — Pulse, to sense enemies through walls",
	 "lesson_en": "Pulse is an audio cue: you sense the direction and strength of danger even without seeing it."},
	{"goal": "Найди золотой ВЫХОД",
	 "lesson": "",
	 "goal_en": "Find the golden EXIT",
	 "lesson_en": ""},
]
const TUTORIAL_STEPS_2 := [
	{"goal": "Двигайся: стрелки или WASD",
	 "lesson": "Третий этап: новые механики лабиринта — тёмные станции и ямы-провалы.",
	 "goal_en": "Move: arrow keys or WASD",
	 "lesson_en": "Tutorial stage three: newer maze mechanics — dark stations and pits."},
	{"goal": "Впереди тёмная воронка — она тянет твой Свет. Погаси её Вспышкой (Q) или Сонаром (E)",
	 "lesson": "Тёмная станция — воронка, всасывающая Свет и подпитывающая врагов рядом фиолетовым ореолом. Гаси активным навыком или встань у станции света — она подавит воронку.",
	 "goal_en": "A dark funnel ahead is draining your Light. Douse it with Flash (Q) or Sonar (E)",
	 "lesson_en": "A dark station is a funnel draining your Light and buffing nearby enemies with a violet aura. Douse it with an active skill, or stand near a light station — it suppresses the funnel."},
	{"goal": "Впереди яма-провал — разгонись и сделай Рывок (Shift), чтобы перепрыгнуть",
	 "lesson": "Яма блокирует обычный проход, как стена, но во время Рывка ты проносишься сквозь неё насквозь.",
	 "goal_en": "A pit ahead blocks the way — get a run-up and Dash (Shift) across",
	 "lesson_en": "A pit blocks normal passage like a wall, but a Dash carries you straight through it."},
	{"goal": "Найди золотой ВЫХОД",
	 "lesson": "",
	 "goal_en": "Find the golden EXIT",
	 "lesson_en": ""},
]

func _tutorial_steps() -> Array:
	match GameConfig.tutorial_stage:
		1: return TUTORIAL_STEPS_1
		2: return TUTORIAL_STEPS_2
		_: return TUTORIAL_STEPS_0

func _tut_field(step: Dictionary, key: String) -> String:
	if GameConfig.locale == "en":
		return str(step.get(key + "_en", step.get(key, "")))
	return str(step.get(key, ""))
var _tut_label: Label
var _tut_panel: PanelContainer      # полупрозрачный попап цели шага
var _tut_lesson_panel: PanelContainer   # временный попап-урок «✓ …»
var _tut_lesson_label: Label
var _tut_lesson_time: float = 0.0
var _tut_arrow_t: float = 0.0       # таймер пульса-стрелки к цели шага
var _tut_step: int = 0
var _tut_dash_baseline: int = 0
var _tut_flash_baseline: int = 0
var _tut_smother_baseline: int = 0
var _tut_mark_baseline: int = 0
var _tut_sonar_baseline: int = 0
var _tut_shield_baseline: int = 0
var _tut_guide_baseline: int = 0
var _tut_reveal_baseline: int = 0
var _tut_pulse_baseline: int = 0
var _tut_station_used: bool = false
var _tut_combo_done: bool = false      # этап 1: комбо Щит+Рывок случилось хоть раз
var _tut_enemy: Node = null            # этап 0: враг для шага «встреться с врагом»
var _tut_darkstation: Node = null      # этап 2: тёмная станция для соответствующего шага
var _tut_pit: Node = null              # этап 2: яма для соответствующего шага
var _tut_freeze: bool = false          # пауза геймплея (не тот же _paused — HUD/таймеры уроков тикают)
var _tut_skill_uses_snapshot: Dictionary = {}   # для отката прокачки мастерства после обучения

# Интерфейс
var _time_label: Label
var _fps_label: Label          # счётчик FPS (внизу слева, если включён в настройках)
var _level_label: Label
var _win_label: Label
var _hud_layer: CanvasLayer     # слой HUD (layer 2) — прячем на экране результатов
var _msg_label: Label
var _event_label: Label
var _energy_bar: ProgressBar
var _energy_fill: StyleBoxFlat
var _will_bar: ProgressBar
# [GAMEDESIGN §29] Индикатор стойки света: три сегмента + подпись с расходом.
var _stance_row: Control
var _stance_segs: Array[ColorRect] = []
var _stance_label: Label
var _will_fill: StyleBoxFlat
# Навыки в HUD: id -> {chip, cap, name, base, accent, ready, glow}. Компактные
# чипы (keycap + кулдаун) в нижней панели; видимостью управляем по разблокировке.
var _skills_ui: Dictionary = {}
var _skill_bar: Control       # нижняя панель-экшенбар с чипами навыков
var _lives_label: Label
var _shards_label: Label
# [GAMEDESIGN §32] Чип серии осколков: висит справа от счётчика осколков,
# появляется со второго чистого осколка, показывает текущий множитель XP.
var _streak_label: Label
var _keys_label: Label
var _lives_icon: HudIcon
var _shards_icon: HudIcon
var _keys_icon: HudIcon
var _shards_shown: int = -1   # последнее показанное число (для «пинка» иконки при изменении)
var _keys_shown: int = -1
var _boost_row: Control       # накопительная пассивка «Разгон» (иконка + значение)
var _adapt_row: Control       # накопительная пассивка «Адаптация»
var _boost_label: Label
var _adapt_label: Label
var _reveal_glow_on: bool = false   # крутится ли подсветка готового «Озарения»
var _toast_label: Label
var _toast_panel: PanelContainer   # фон-плашка тоста (см. flash_message) — не просто жёлтый текст
# Общий вертикальный стек верхних всплывающих сообщений: цель обучения,
# урок обучения и обычный тост — раньше все три позиционировались отдельно
# фиксированными офсетами и перекрывали друг друга, если появлялись разом
# (жалоба «надписи пересекаются и уходят за экран»). VBoxContainer сам
# укладывает их друг под другом и не даёт места скрытым (invisible) панелям.
var _top_stack: VBoxContainer
var _minimap: TextureRect
var _joystick: Control
var _tint: ColorRect
var _tint_target: Color = Color(0, 0, 0, 0)

# [GAMEDESIGN §33 «Эскалация»] Напряжение внутри уровня растёт со временем.
# До этого единственным источником давления была РОВНАЯ утечка Света: минута
# первая ощущалась как минута четвёртая, и ковырять уровень бесконечно было
# бесплатно. Теперь у уровня три стадии, и порог считается от нормы времени
# ранга (`par` в _compute_rank), поэтому он сам масштабируется с размером
# уровня — на 50-м никто не требует уложиться в норму 1-го.
#   0 — тишина: исследуй спокойно;
#   1 — тьма густеет: обзор ужимается, лабиринт начинает давить;
#   2 — охота: просыпается ЛОВЧИЙ, который не теряет след.
const ESCALATION_STAGE1_MULT := 1.15   # доля нормы времени до стадии 1
const ESCALATION_STAGE2_MULT := 1.90   # ... до стадии 2
const ESCALATION_VISION := [1.0, 0.90, 0.80]   # множитель обзора по стадиям
var _escalation_stage: int = 0
var _hunter: Node2D = null
var _pause_overlay: Control
var _pause_info: Label
var _xp_bar: ProgressBar
var _sp_label: Label

# Активные навыки: клавиша (для keycap) + русское имя + акцентный неон.
const SKILL_DEFS := [
	{"id": "flash",  "key": "Q",     "name": "Вспышка",  "accent": Color(0.45, 0.85, 1.0)},
	{"id": "dash",   "key": "Shift", "name": "Рывок",    "accent": Color(0.45, 0.85, 1.0)},
	{"id": "smother", "key": "R",    "name": "Тление",   "accent": Color(0.7, 0.58, 1.0)},
	{"id": "mirage",  "key": "T",    "name": "Мираж",    "accent": Color(0.8, 0.7, 1.0)},
	{"id": "breach",  "key": "Y",    "name": "Разлом",   "accent": Color(1.0, 0.55, 0.3)},
	{"id": "chrono",  "key": "V",    "name": "Хронос",   "accent": Color(0.4, 0.95, 0.9)},
	{"id": "sonar",  "key": "E",     "name": "Сонар",    "accent": Color(0.45, 0.85, 1.0)},
	{"id": "shield", "key": "C",     "name": "Щит",      "accent": Color(0.45, 0.85, 1.0)},
	{"id": "guide",  "key": "G",     "name": "Искра",    "accent": Color(0.45, 0.85, 1.0)},
	{"id": "reveal", "key": "F",     "name": "Озарение", "accent": Color(1.0, 0.82, 0.35)},
	{"id": "pulse",  "key": "B",     "name": "Пульс",    "accent": Color(1.0, 0.62, 0.85)},
	{"id": "mark",   "key": "M",     "name": "Метка",    "accent": Color(1.0, 0.55, 0.15)},
	{"id": "apex",   "key": "H",     "name": "Апекс",    "accent": Color(1.0, 0.2, 0.3)},
]

# HUD-текст обновляем не каждый кадр, а ~15 раз/с: покадровое форматирование
# десятка строк (таймер, кулдауны, XP) зря грузит CPU, особенно на мобилке.
var _hud_accum: float = 999.0
const HUD_INTERVAL := 1.0 / 15.0

var _dark: CanvasModulate
var _ambient: Color
var _reveal_time: float = 0.0

# Высота верхней HUD-панели (лог. px). Камера резервирует эту полосу сверху:
# граница лабиринта и игрок никогда не заходят под HUD (hud_top_inset).
const HUD_BAND := 74.0

var _dark_mat: ShaderMaterial   # виньетка «туман войны» вокруг игрока
var _dark_open: float = 0.0     # 0 = виньетка закрыта, 1 = открыта (Озарение)
# [GAMEDESIGN §45] Луч: [дальность, фокус] на каждую стойку света.
# Фокус — косинусный порог в шейдере: больше значит уже конус.
const BEAM_BY_STANCE := [
	[0.62, 0.72],   # Тусклая: узкий, но самый дальний — фонарь-щуп
	[0.46, 0.52],   # Ровная: компромисс
	[0.26, 0.20],   # Яркая: почти во все стороны, зато недалеко — заливка
]
const BEAM_SMOTHER := 0.10      # Тление: луч почти гаснет, остаётся искра
const DARK_MAX := 0.93          # базовое затемнение по краям экрана
const DARK_INNER := 0.50        # базовый радиус полностью видимой зоны (доли полувысоты)
const DARK_OUTER := 0.76        # базовый радиус полного затемнения
var _vision: float = 1.0        # текущий масштаб радиуса видимости (плавный)
var _vision_target: float = 1.0 # цель: 1.0 — норма; <1 ужимает обзор (утечка/туман)
var _sonar_vision_time: float = 0.0   # >0, пока действует раздвижка обзора от Сонара
var _sonar_vision_mult: float = 1.0   # текущий множитель обзора от Сонара (>1 — шире)

var _fx   # менеджер экранных эффектов (screenfx.gd)
var _music: AudioStreamPlayer
var _music_chase: AudioStreamPlayer   # реактивный слой «сердца погони»

# Звуковые эффекты (загружаются один раз, проигрываются разовыми плеерами)
var _sfx_shard: AudioStream   # подбор осколка
var _sfx_key: AudioStream     # ключ потрачен, дверь открылась
var _sfx_win: AudioStream     # уровень пройден
var _sfx_beep: AudioStream    # глоток энергии с кристалла-станции
var _sfx_damage: AudioStream  # удар врага по свету
var _sfx_sonar: AudioStream   # навык «Сонар»
var _sfx_sparkle: AudioStream # навык «Искра» (Guide)
var _sfx_flash: AudioStream   # процедурные звуки навыков (sk_*.wav)
var _sfx_dash: AudioStream
var _sfx_shield: AudioStream
var _sfx_smother: AudioStream
var _sfx_reveal: AudioStream
var _sfx_apex: AudioStream

func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS   # чтобы ввод работал во время паузы
	get_tree().paused = false

	# Апекс раньше открывался молча где-то внутри магазина/статов — игрок не
	# понимал, включился навык или нет (у него даже не было иконки в HUD).
	# Теперь явный баннер + звук в момент открытия, в любом режиме и экране.
	if not GameConfig.apex_unlocked.is_connected(_on_apex_unlocked):
		GameConfig.apex_unlocked.connect(_on_apex_unlocked)

	# ¾-вид: стены — блоки с крышкой, сдвинутой на WALL_H вверх (см. _ensure_wall_tile_source).
	# y_sort на main + на контейнерах этажей сортирует крышки стен относительно
	# игрока/врагов по глубине без переноса их в контейнеры этажей.
	y_sort_enabled = true

	# В режиме «Накал» спуск бесконечный — снимаем потолок уровней.
	var _lvl_cap: int = 9999 if GameConfig.active_run >= 0 else MAX_LEVEL
	_level = clampi(GameConfig.level, 1, _lvl_cap)
	# «Мега-лабиринт»: только классические «Уровни» (не Накал/Логово — у них
	# своя кривая), с 30-го уровня — выше потолки размера, реальный скачок сложности.
	_mega_maze = _mech_ready("mega_maze") and GameConfig.active_run < 0
	var dim_cap: int = MAX_DIM_MEGA if _mega_maze else MAX_DIM
	var floor_cap: int = MAX_FLOORS_MEGA if _mega_maze else MAX_FLOORS
	_floors = mini(_level, floor_cap)
	_cols = mini(GameConfig.cols + (_level - 1) * 2, dim_cap)
	_rows = mini(GameConfig.rows + int((_level - 1) * 1.5), dim_cap - 12)
	# Ритм формы (GAMEDESIGN п.1): уровни чередуются обычный → узкий → широкий.
	# Узкий — длинные тесные коридоры (клаустрофобия, рывок/флеш критичны);
	# широкий — открытые пространства с петлями (враги видят издалека).
	# Ритм включается с 4-го уровня, чтобы старт оставался классическим.
	_maze_phase = ((_level - 1) % 3) if _level >= 4 else 0
	if _maze_phase == 1:   # узкий: вытянуть и сузить
		_cols = mini(int(_cols * 1.3), dim_cap)
		_rows = maxi(int(_rows * 0.6), 6)
	# Обучение: маленький гарантированно безопасный лабиринт (1 этаж, без
	# запертых дверей и врагов — на уровне 1 они и так не спавнятся) и никаких
	# случайных событий/маяка, чтобы ничего не отвлекало от пошаговых подсказок.
	if GameConfig.tutorial_mode:
		_level = 1
		_floors = 1
		# [BUGFIX 02.08.2026, v4.3] `_mega_maze` строкой выше уже посчитан по
		# ГЛОБАЛЬНОМУ `GameConfig.level` (прогресс кампании «Уровни»), а не по
		# `_level` этого режима — тот переопределяется только НИЖЕ, в этой же
		# ветке. Игрок с прогрессом ≥30 в «Уровнях», зайдя в Обучение/Логово/
		# Пещеры, получал бы `_mega_maze == true` и, как следствие, СЛУЧАЙНЫЙ
		# `_entry_cell` вместо фиксированного (0,0) — «своя кривая», которую
		# комментарий у _mega_maze выше обещает НЕ применять вне «Уровней»,
		# на деле применялась. Найдено обзорным харнессом всех режимов:
		# «Логово 10» при GameConfig.level=50 (типичный прогресс тестового
		# сейва) давало условный путь вход→трон в 18 клеток вместо ожидаемых
		# ~70 — случайный вход изредка выпадал рядом с тронным залом.
		# Явный сброс в каждой НЕ-кампанийской ветке — дешевле и безопаснее,
		# чем переставлять расчёт `_mega_maze` ниже всей цепочки веток.
		_mega_maze = false
		# Этап 0 (основы) умещается в маленький 11x7, как и раньше; этапам 1/2
		# (больше навыков/декораций на этаж — враг для комбо, тёмная станция
		# И яма разом) нужно чуть просторнее, иначе тесно и трудно избежать
		# случайных столкновений decораций друг с другом.
		if GameConfig.tutorial_stage == 0:
			_cols = 11
			_rows = 7
		else:
			_cols = 14
			_rows = 9
	elif GameConfig.lair_mode:
		# Логово: один большой этаж с тронным залом босса в центре. Растёт и
		# усложняется по всем 10 уровням — самый большой лабиринт к 10-му.
		_lair_active = true
		_level = clampi(GameConfig.lair_level, 1, GameConfig.LAIR_LEVELS)
		_floors = 1
		_maze_phase = 0
		_mega_maze = false   # [BUGFIX 02.08.2026, v4.3] см. комментарий в ветке tutorial_mode выше
		_cols = mini(16 + (_level - 1) * 2, MAX_DIM)
		_rows = mini(11 + (_level - 1) * 2, MAX_DIM - 12)
	elif GameConfig.caves_mode:
		# [v4.0, §60] Пещеры: отдельный режим, а не правка «Уровней» — тот же
		# find-the-exit, что в кампании (двери/выход/враги идут обычным путём,
		# см. общий else ниже), но пол рисуется organic_floor.gd (скруглённые
		# тоннели) вместо прямых стен. Один этаж на уровень — как у Логова,
		# намеренно просто для первой версии режима.
		_caves_active = true
		_level = clampi(GameConfig.caves_level, 1, GameConfig.CAVES_LEVELS)
		_floors = 1
		_maze_phase = 0
		_mega_maze = false   # [BUGFIX 02.08.2026, v4.3] см. комментарий в ветке tutorial_mode выше
		_cols = mini(14 + (_level - 1) * 3, MAX_DIM)
		_rows = mini(10 + (_level - 1) * 2, MAX_DIM - 12)

	_gw = _cols * 2 + 1
	_gh = _rows * 2 + 1
	_floor_gap = (_gh + 2) * TILE

	# Спуск дня: детерминированная генерация — сид от даты забега + номера
	# уровня. У всех игроков в этот день один и тот же лабиринт.
	if GameConfig.is_daily():
		var run_d = GameConfig.runs[GameConfig.DAILY_SLOT]
		var date_s: String = str(run_d.get("date", GameConfig.today_str())) if run_d != null else GameConfig.today_str()
		seed(hash("mazeoff|%s|%d" % [date_s, _level]))

	# Вход на 1-й этаж: обычно угол (0,0). В мега-лабиринте — случайная клетка,
	# чтобы каждый уровень не ощущался жёстким сбросом на то же самое место
	# (growing-tree покрывает всю сетку одним связным деревом независимо от
	# точки старта карвинга, так что выход всё равно гарантированно достижим
	# из любой клетки).
	_entry_cell = Vector2i(randi() % _cols, randi() % _rows) if _mega_maze else Vector2i.ZERO

	# «Пылающая» сложность в «Уровнях»: станций нет — свет только из осколков.
	# Баланс: удвоенный запас света + осколки дают двойной глоток и заряд
	# Озарения (см. collect_shard/_spawn_player). В «Накале» станции остаются
	# (они же алтари), сложность там влияет на врагов/награды.
	_hard = GameConfig.difficulty >= 2 and GameConfig.active_run < 0 and not GameConfig.tutorial_mode and not GameConfig.lair_mode and not GameConfig.caves_mode

	# Усложнение по уровням: быстрее разрядка и темнее фон (растянуто на больше
	# уровней, чтобы рост ощущался постепенно, а не таймером-обрывом)
	_drain_mult = 1.0 + (_level - 1) * 0.02
	var dark_scale := maxf(0.55, 1.0 - (_level - 1) * 0.015)

	_events_enabled = GameConfig.events_enabled and not GameConfig.tutorial_mode
	_event_cd = randf_range(10.0, 16.0)
	_living_maze_done = false
	_living_maze_cd = 30.0
	_beacon_cd = randf_range(20.0, 40.0)
	_beacon_spawned = GameConfig.tutorial_mode   # маяк отключён на обучении
	_guest_cd = randf_range(18.0, 38.0)
	_guest_spawned = GameConfig.tutorial_mode    # гости отключены на обучении
	_lives = maxi(1, GameConfig.lives + GameConfig.diff_extra_lives())
	# Накал: подтянуть несомый/забанканный/серию из слота забега
	if GameConfig.active_run >= 0:
		var r: Dictionary = GameConfig.runs[GameConfig.active_run]
		_ember        = float(r.get("ember_carried", 0))
		_ember_banked = int(r.get("ember_banked", 0))
		_ember_streak = int(r.get("ember_streak", 0))
		_level_clean  = true
	# Снимок применений активных навыков — для ранга «пройдено без способностей».
	_skill_uses_at_start = 0
	for sk in ["flash", "dash", "sonar", "shield", "guide", "reveal", "pulse"]:
		_skill_uses_at_start += int(GameConfig.skill_uses.get(sk, 0))
	_apply_biome()
	if GameConfig.caves_mode:
		# [v4.0, §60] _apply_biome() всё равно подставила бы название кампанийского
		# биома (например «Лазурные шахты») по номеру уровня — Пещеры не участвуют
		# в ротации биомов кампании, и это название было бы просто неверным,
		# а не только «не в тему». Своё имя, свой цвет стен для рим-глоу боковых
		# граней (стены невидимы, но _wall_color всё ещё используется где-то ещё).
		_biome_name = GameConfig.tt("Пещеры", "Caves")
		_wall_color = Color(0.55, 0.42, 0.30)
		# [BUGFIX 02.08.2026, v4.3] `_apply_biome()` выше уже выставила `_biome`
		# через `_biome_of_level(_level)` — но та функция делит на кампанийский
		# BIOME_SPAN=5 и берёт `_level` = caves_level (1..CAVES_LEVELS=10).
		# Итог: `_biome` циклится только между индексами 0 (1-5) и 1 (6-10) —
		# биом 2 (Споровые пустоты, единственный дом тёмных станций в таблице
		# правил) физически не наступает НИ НА ОДНОМ уровне Пещер. Обзорный
		# харнесс подтвердил: 0 тёмных станций и 0 мимиков за все 10 уровней
		# (мимики тоже почти не попадали в своё окно — см. правки лестницы
		# ниже). Пересчитываем `_biome` для Пещер по СОБСТВЕННОЙ ширине полосы,
		# чтобы все 3 биома гарантированно уместились в 10 уровнях: 1-4 →
		# Лазурные шахты (срезки/мимики), 5-8 → Багровые недра (ямы/загонщик),
		# 9-10 → Споровые пустоты (тёмные станции) — то же правило из комментария
		# у BIOMES выше («порог обязан лежать внутри полосы своего биома»),
		# просто с другой шириной полосы (см. _biome_of_level_mode).
		_biome = _biome_of_level_mode(_level)
		# ORGANIC_THEMES — готовая палитра, заведённая для органических полов,
		# но ни разу не использованная (organic_floor.gd был мёртвым кодом).
		# Цикл по уровню — та же идея, что у ротации биомов кампании.
		_organic_color = ORGANIC_THEMES[(_level - 1) % ORGANIC_THEMES.size()]
	# [v4.0, §60] Единственное место, где ожил старый мёртвый флаг: до сих пор
	# organic_floor.gd не подключался ни к чему (см. CLAUDE.md). Пещеры —
	# единственный режим, где он включается; во всех остальных остаётся false,
	# как и было.
	_organic = GameConfig.caves_mode

	# Фон (CanvasModulate): тёмный, но НЕ чёрный — тонирован неоном темы, чтобы
	# грани стен читались по всему лабиринту и сплошная чернота не давила на глаза.
	# Луминанс ~0.10 на 1-м уровне, мягко темнеет вглубь (dark_scale).
	var neon := _wall_color
	_ambient = Color(
		(neon.r * 0.15 + 0.022) * dark_scale,
		(neon.g * 0.16 + 0.028) * dark_scale,
		(neon.b * 0.17 + 0.038) * dark_scale,
		1.0)

	_build_world()
	_build_hud()

	# Разовая подсказка новичку: на самом первом уровне (и только пока игрок ни
	# разу его не проходил) через пару секунд пускаем искру-путеводитель к
	# выходу — бесплатно, не тратя Волю. Дальше блуждание в темноте — уже
	# без подсказок, как и задумано.
	if _level == 1 and GameConfig.active_run < 0 and not GameConfig.tutorial_mode \
			and not GameConfig.lair_mode and not GameConfig.start_hint_shown:
		call_deferred("_show_start_hint")
	_build_screen_fx()
	if GameConfig.tutorial_mode:
		_build_tutorial_hud()
	_start_music()
	_load_sfx()
	if DisplayServer.is_touchscreen_available():
		_build_touch_controls()

	# При продолжении забега из меню — заметный баннер: на какой ты глубине и банк.
	# Снимает путаницу «этаж 1 = уровень 1» и подтверждает, что прогресс на месте.
	if GameConfig.active_run >= 0 and GameConfig.resumed:
		GameConfig.resumed = false
		_show_resume_banner()
	# Горизонт — именованная веха спуска: объявляем на входе (глубины 1, 6, 11…).
	var horizon_shown := false
	if GameConfig.active_run >= 0 and (_level - 1) % GameConfig.HORIZON_SPAN == 0:
		horizon_shown = true
		call_deferred("flash_message", GameConfig.tt("⌘ Горизонт %d: %s", "⌘ Horizon %d: %s") % [GameConfig.horizon_index(_level) + 1, GameConfig.horizon_name(_level)])
	# [GAMEDESIGN §26] Тема биома — какие механики правят следующие BIOME_SPAN
	# уровней. Без этого тоста перераспределение механик остаётся невидимым.
	call_deferred("_announce_biome", 5.0 if horizon_shown else 0.0)
	# [§38] Карточка новой механики — ПОСЛЕ темы биома: сначала «по каким
	# правилам живут эти пять уровней», потом «а вот что здесь появилось».
	call_deferred("_announce_ladder", (10.0 if horizon_shown else 5.0))

func _process(delta: float) -> void:
	if _paused:
		return

	if _toast_time > 0.0:
		_toast_time -= delta
		if _toast_time <= 0.0 and _toast_panel:
			_toast_panel.visible = false

	# Время и события идут только после первого движения игрока
	var has_started: bool = _player and is_instance_valid(_player) and _player.started
	if not _won and not _dead and has_started:
		_elapsed += delta
		_update_events(delta)
		_update_beacon(delta)
		_update_guests(delta)
		_update_escalation()
		_update_watchers(delta)
		_update_hearths(delta)
		_update_living_maze(delta)
		_update_event_room_warning()
		if GameConfig.tutorial_mode:
			_update_tutorial()
		_mark_visited()
		_check_exit_sighted()   # [§39] набрёл на портал — улики больше не нужны
		_heat_sample_t += delta
		if _heat_sample_t >= 0.5:
			_heat_sample_t = 0.0
			_sample_heat()
			if GameConfig.echo_time_enabled:
				_sample_echo_trail()

	if _player and is_instance_valid(_player):
		# Надпись при заходе на новый этаж: сколько осколков на нём осталось
		if _player.current_floor != _last_floor:
			_last_floor = _player.current_floor
			var rem: int = int(_shards_remaining[_last_floor]) if _last_floor >= 0 and _last_floor < _shards_remaining.size() else 0
			flash_message(GameConfig.tt("Этаж %d · осколков: %d", "Floor %d · shards: %d") % [_last_floor + 1, rem])

		if _joystick:
			_player.touch_dir = _joystick.output

	# HUD-текст — на троттлинге (~15 Гц), а не каждый кадр (см. _update_hud)
	_hud_accum += delta
	if _hud_accum >= HUD_INTERVAL:
		_hud_accum = 0.0
		_update_hud()

	# Боковые грани стен — перспектива от игрока, троттлинг ~8 Гц
	_side_accum += delta
	if _side_accum >= 0.125:
		_side_accum = 0.0
		_update_side_faces()

	# Реактивная музыка: слой погони вплывает/тает по обстановке
	_update_music(delta)
	_update_pulse(delta)

	# Озарение
	if _dark:
		if _reveal_time > 0.0:
			_reveal_time -= delta
			_dark.color = _dark.color.lerp(Color(0.85, 0.85, 0.9), 0.12)
		else:
			_dark.color = _dark.color.lerp(_ambient, 0.06)

	# Виньетка-«туман войны»: приоткрывается во время Озарения, иначе закрыта.
	# Утечка света / густой туман, наоборот, ужимают радиус видимости (темнее, тяжелее).
	if _dark_mat:
		# Внутри кляксы тумана виньетка тоже ужимается (локально, пока игрок в ней).
		var vt := _vision_target
		if _sonar_vision_time > 0.0:
			_sonar_vision_time -= delta
			vt = maxf(vt, _sonar_vision_mult)
		else:
			_sonar_vision_mult = 1.0
		if _player and is_instance_valid(_player) and _player.has_method("is_fogged") and _player.is_fogged():
			vt = minf(vt, 0.65)
		_vision = lerpf(_vision, vt, 0.07)
		_dark_mat.set_shader_parameter("inner", DARK_INNER * _vision)
		_dark_mat.set_shader_parameter("outer", DARK_OUTER * _vision)
		_update_beam(delta)
		_dark_open = lerpf(_dark_open, 1.0 if _reveal_time > 0.0 else 0.0, 0.12)
		_dark_mat.set_shader_parameter("max_dark", lerpf(DARK_MAX, 0.0, _dark_open))
		# Центр виньетки следует за экранной позицией игрока: у краёв лабиринта
		# камера упирается в границу, игрок съезжает от центра — и «шар видимости»
		# должен оставаться на игроке, иначе он пропадает в темноте.
		if _player and is_instance_valid(_player):
			var vp := get_viewport()
			var sp: Vector2 = vp.get_canvas_transform() * _player.global_position
			var vs: Vector2 = vp.get_visible_rect().size
			if vs.x > 0.0 and vs.y > 0.0:
				_dark_mat.set_shader_parameter("center", sp / vs)

	# Цветовой тинт событий
	if _tint:
		_tint.color = _tint.color.lerp(_tint_target, 0.1)

# Обновление HUD-текста. Вызывается из _process на троттлинге (~15 Гц): кулдауны
# показываются с точностью 0.1 с, поэтому форматировать десяток строк каждый кадр
# незачем — это лишние аллокации строк и переразметка лейблов (заметно на мобилке).
func _update_hud() -> void:
	if not _won and not _dead and _player and is_instance_valid(_player):
		_time_label.text = GameConfig.tt("%.1f с", "%.1f s") % _elapsed
		var lvl_word := GameConfig.tt("Глубина", "Depth") if GameConfig.active_run >= 0 else GameConfig.tt("Уровень", "Level")
		var sp_tag := "      SP %d" % GameConfig.skill_points if GameConfig.skill_points > 0 else ""
		_level_label.text = GameConfig.tt("%s %d   ·   %s   ·   этаж %d / %d%s", "%s %d   ·   %s   ·   floor %d / %d%s") % [lvl_word, _level, _biome_name, _player.current_floor + 1, _floors, sp_tag]

	# Индикатор Накала + «жар» (ярче горишь → агрессивнее враги)
	if _ember_label and is_instance_valid(_ember_label):
		var heat := enemy_heat()
		var hot := "   🔥" if heat > 0.5 else ""
		_ember_label.text = GameConfig.tt("НАКАЛ %d   ·   банк %d   ·   ×%.2f%s", "EMBER %d   ·   bank %d   ·   ×%.2f%s") % [int(_ember), _ember_banked, _ember_mult(), hot]
		_ember_label.add_theme_color_override("font_color", Color(1.0, 0.72, 0.3).lerp(Color(1.0, 0.4, 0.2), heat))
		if _player and is_instance_valid(_player):
			_player.ember_glow = heat
		# Жар читается телом: оранжевая «горящая» кромка экрана + сердцебиение.
		if _fx:
			_fx.set_heat(heat)

	if _player and is_instance_valid(_player):
		var r: float = clampf(_player.energy / _player.max_energy, 0.0, 1.0)
		_energy_bar.value = lerpf(_energy_bar.value, r, 0.4)   # плавная «стрелка» света
		# Явный порог, а не гладкий градиент по всей полосе (раньше жёлтый
		# и красный уже смешивались на середине шкалы — тревога срабатывала
		# «незаметно раньше времени»): жёлтый держится почти до конца, и только
		# ниже LOW_LIGHT_THRESHOLD полоса резко идёт в красный — однозначный
		# сигнал «пора искать станцию», а не постепенное потускнение.
		const LOW_LIGHT_THRESHOLD := 0.3
		var low_t: float = clampf(1.0 - r / LOW_LIGHT_THRESHOLD, 0.0, 1.0)
		_energy_fill.bg_color = Color(1.0, 0.85, 0.3).lerp(Color(0.95, 0.15, 0.15), low_t)
		if _will_bar:
			var wr: float = clampf(_player.will / _player.max_will, 0.0, 1.0)
			_will_bar.value = lerpf(_will_bar.value, wr, 0.4)
		_update_stance_hud()

		# Экранный эффект: красная тревога ниже 40% света.
		if _fx:
			_fx.set_danger(clampf((0.4 - r) / 0.4, 0.0, 1.0))

		_update_skills_hud()

		if GameConfig.progressive_enabled:
			_boost_row.visible = true
			_adapt_row.visible = true
			_boost_label.text = GameConfig.tt("Разгон  +%d%%", "Momentum  +%d%%") % int(_player.momentum_bonus * 100.0)
			_adapt_label.text = GameConfig.tt("Адаптация  −%d%%", "Adaptation  −%d%%") % int(_player.adapt_bonus * 100.0)
		else:
			_boost_row.visible = false
			_adapt_row.visible = false

	if _fps_label:
		_fps_label.text = "FPS: %d" % Engine.get_frames_per_second()

	# XP / SP в HUD
	if _sp_label:
		_sp_label.text = GameConfig.t("sp_xp") % [GameConfig.skill_points, GameConfig.xp, GameConfig.XP_PER_SP]
	if _xp_bar:
		_xp_bar.value = GameConfig.xp

# --- Случайные события ---

func _update_events(delta: float) -> void:
	if not _events_enabled or not _mech_ready("events"):
		return

	if _event_active > 0.0:
		_event_active -= delta
		if _event_active <= 0.0:
			_end_event()
		return

	_event_cd -= delta

	if not _event_warn_active and _event_cd <= EVENT_WARN_LEAD:
		_event_warn_active = true
		_event_warn_kind = _roll_event_kind()
		_event_warn_t = 0.0
		_show_event_warning(_event_warn_kind)
	if _event_warn_active and _event_label:
		_event_warn_t += delta
		_event_label.modulate.a = 0.35 + 0.35 * (0.5 + 0.5 * sin(_event_warn_t * 7.0))

	if _event_cd <= 0.0:
		_trigger_event(_event_warn_kind)
		_event_warn_active = false

# Выбор типа события — вынесено из _trigger_event, чтобы предвестник
# (_update_events) мог решить, ЧТО случится, заранее, до самого срабатывания.
func _roll_event_kind() -> String:
	# [GAMEDESIGN §26] Базовые веса = прежние вероятности (quake остаётся
	# редким везде), поверх — модификаторы биома: в Недрах трясёт втрое чаще,
	# в Пустотах правит туман, в Шахтах — техногенные сбои света.
	var base := {
		"quake": 0.06, "relief": 0.12, "fog": 0.22,
		"leak": 0.20, "flicker": 0.20, "shift": 0.20,
	}
	# [§62, v.4.3] Графовые Пещеры: у quake/shift/fog теперь есть графовые
	# аналоги (_do_quake_graph/_do_shift_graph/_spawn_fog_patches, графовая
	# ветка) — веса те же, что у клеточных уровней, ничего больше не гасим.
	if _caves_graph_active:
		base = {"quake": 0.06, "relief": 0.12, "fog": 0.22, "leak": 0.20, "flicker": 0.20, "shift": 0.20}
	var kind := _weighted_pick(_apply_biome_weights(base, "events"))
	return kind if kind != "" else "leak"

# Тусклая пульсирующая иконка-предвестник — тот же глиф, что появится в
# полноценном сообщении события, просто заранее и вполнакала.
func _show_event_warning(kind: String) -> void:
	if not _event_label:
		return
	_event_label.text = str(EVENT_ICONS.get(kind, "?"))
	_event_label.add_theme_color_override("font_color", Color(0.85, 0.85, 0.9))
	_event_label.modulate = Color(1, 1, 1, 0.35)
	_event_label.visible = true

func _trigger_event(kind: String = "") -> void:
	if kind == "":
		kind = _roll_event_kind()
	var dur := randf_range(3.0, 5.0)
	_event_active = dur
	_event_label.modulate = Color(1, 1, 1, 1)

	match kind:
		"quake":
			# ЗЕМЛЕТРЯСЕНИЕ: часть внутренних стен этажа рушится, открывая проходы.
			_event_label.text = GameConfig.tt("⛰ Землетрясение — стены рушатся!", "⛰ Earthquake — walls are collapsing!")
			_event_label.add_theme_color_override("font_color", Color(1.0, 0.65, 0.3))
			_tint_target = Color(0.5, 0.35, 0.15, 0.14)
			if _caves_graph_active:
				_do_quake_graph()
			else:
				_do_quake()
		"shift":
			_event_label.text = GameConfig.tt("▦ Лабиринт сдвигается", "▦ The maze is shifting")
			_event_label.add_theme_color_override("font_color", Color(0.8, 0.6, 1.0))
			_tint_target = Color(0.4, 0.25, 0.6, 0.14)
			if _caves_graph_active:
				_do_shift_graph()
			else:
				_maze_shift()
		"relief":
			# Раньше давал ПОЛНОЕ Озарение (снимал тьму целиком, как навык F) —
			# бесплатное событие обесценивало и тьму, и сам навык/Апекс. Теперь —
			# как туман/утечка: расширяет радиус видимости (+60%), но тьма по
			# краям остаётся, напряжение не пропадает полностью.
			_event_label.text = GameConfig.tt("✦ Просвет", "✦ Clearing")
			_event_label.add_theme_color_override("font_color", Color(0.5, 1.0, 0.6))
			_tint_target = Color(0.2, 0.6, 0.3, 0.10)
			_vision_target = 1.6
			if _player:
				_player.energy = minf(_player.max_energy, _player.energy + 0.3)
		"fog":
			# Туман теперь ЛОКАЛЬНЫЙ: 2-3 кляксы на этаже игрока — появились,
			# поклубились и рассосались. Видимость падает только ВНУТРИ пятна
			# (fog_patch.gd повторяет короткий apply_event, пока игрок в нём).
			_event_label.text = GameConfig.tt("≈ Пятна тумана", "≈ Patches of fog")
			_event_label.add_theme_color_override("font_color", Color(0.6, 0.8, 1.0))
			_tint_target = Color(0.25, 0.4, 0.7, 0.10)
			_spawn_fog_patches()
		"leak":
			_event_label.text = GameConfig.tt("⚠ Утечка света", "⚠ Light leak")
			_event_label.add_theme_color_override("font_color", Color(1.0, 0.5, 0.4))
			_tint_target = Color(0.7, 0.2, 0.2, 0.16)
			_vision_target = 0.5   # утечка режет радиус видимости вдвое — прям темно
			if _player:
				_player.apply_event("leak", dur)
		"flicker":
			_event_label.text = GameConfig.tt("⚡ Перебой света", "⚡ Power flicker")
			_event_label.add_theme_color_override("font_color", Color(1.0, 0.9, 0.4))
			_tint_target = Color(0.1, 0.1, 0.1, 0.12)
			_vision_target = 0.6   # перебой света тоже ужимает обзор + свет пульсирует
			if _player:
				_player.apply_event("flicker", dur)

	_event_label.visible = true

# Кляксы тумана: 2-3 пятна в проходах этажа игрока, не вплотную к нему
# (4..14 клеток) — чтобы туман встречался на пути, а не накрывал внезапно.
func _spawn_fog_patches() -> void:
	if _player == null or not is_instance_valid(_player):
		return
	var f: int = _player.current_floor
	if f < 0 or f >= _grids.size() or f >= _floor_containers.size():
		return
	# [§62, v.4.2] Графовая версия — позиции узлов графа, не клетки
	# сетки-заглушки (та полностью открыта и не отражает реальную форму
	# тоннеля; для чисто визуального тумана это не риск спавна-в-стене, как
	# у Соглядатая/Очага/Метки, но пятно вполне могло бы оказаться в
	# нарисованной сплошной породе, а не в тоннеле — нечитаемо).
	if _caves_graph_active:
		var nodes: Array = _cave_graph.get("nodes", [])
		if nodes.is_empty():
			return
		var idxs: Array = range(nodes.size())
		idxs.shuffle()
		var container_g: Node2D = _floor_containers[f]
		var spawned_g := 0
		var want_g := randi_range(2, 3)
		for idx in idxs:
			if spawned_g >= want_g:
				break
			var world_g: Vector2 = (nodes[idx] as Vector2) + Vector2(0, f * _floor_gap)
			var d_g: float = world_g.distance_to(_player.global_position)
			if d_g < TILE * 4.0 or d_g > TILE * 28.0:
				continue
			var patch_g := Node2D.new()
			patch_g.set_script(load("res://fog_patch.gd"))
			patch_g.radius = randf_range(140.0, 210.0)
			patch_g.dur = randf_range(14.0, 22.0)
			patch_g.floor_index = f
			patch_g.position = nodes[idx]
			container_g.add_child(patch_g)
			spawned_g += 1
		return
	var cells := _passage_cells(false, _grids[f])
	cells.shuffle()
	var container: Node2D = _floor_containers[f]
	var spawned := 0
	var want := randi_range(2, 3)
	for c in cells:
		if spawned >= want:
			break
		var local := _cell_to_world(c)
		var world := local + container.position
		var d := world.distance_to(_player.global_position)
		if d < TILE * 4.0 or d > TILE * 14.0:
			continue
		var patch := Node2D.new()
		patch.set_script(load("res://fog_patch.gd"))
		patch.radius = randf_range(140.0, 210.0)
		patch.dur = randf_range(14.0, 22.0)
		patch.floor_index = f
		patch.position = local
		container.add_child(patch)
		spawned += 1

# Землетрясение: рушим до 6 случайных внутренних стен на этаже игрока.
# [§62, v.4.2] Графовая версия землетрясения: «стены рушатся, открывая
# проходы» — буквально добавляем НОВЫЕ рёбра между геометрически близкими,
# но пока не связанными узлами (та же формулировка события, что и в
# клеточной версии, только вместо разрушения случайных стен — открытие
# новых коротких связей). Не трогаем существующие узлы/рёбра — только
# ДОБАВЛЯЕМ, поэтому уже пройденный путь/владение/позиции не протухают.
# Перестройка коллизии/occlusion/рендера этажа — полный вызов
# CaveFloorBuild.build на обновлённом графе (дёшево, см. §62 шаг 5 часть 1:
# единицы-десятки мс даже на мега-размере); старые дети контейнера
# помечаются queue_free() и добавляются новые в том же кадре — на один
# кадр возможно кратковременное дублирование (не критично для разового
# события, полноценная замена без единого кадра рассинхрона потребовала
# бы отдельного двойного буфера, непропорционально для этой правки).
func _do_quake_graph() -> void:
	if not _caves_graph_active or _floor_containers.is_empty():
		return
	var container: Node2D = _floor_containers[0]
	if container == null:
		return
	var nodes: Array = _cave_graph.get("nodes", [])
	var edges: Array = _cave_graph.get("edges", [])
	if nodes.size() < 4:
		return
	var adj := {}
	for i in nodes.size():
		adj[i] = {}
	for e in edges:
		adj[e.x][e.y] = true
		adj[e.y][e.x] = true
	var candidates: Array[Vector2i] = []
	for i in nodes.size():
		for j in range(i + 1, nodes.size()):
			if adj[i].has(j):
				continue
			if (nodes[i] as Vector2).distance_to(nodes[j]) < TILE * 6.0:
				candidates.append(Vector2i(i, j))
	if candidates.is_empty():
		return
	candidates.shuffle()
	var rng := RandomNumberGenerator.new()
	rng.seed = randi()
	var polylines: Array = _cave_graph.get("polylines", [])
	var added := 0
	for pair in candidates:
		if added >= 2:
			break
		edges.append(pair)
		polylines.append(CaveGraph.edge_polyline(nodes[pair.x], nodes[pair.y], rng))
		added += 1
	if added == 0:
		return
	_cave_graph["edges"] = edges
	_cave_graph["polylines"] = polylines
	for c in container.get_children():
		c.queue_free()
	var level_size := Vector2(float(_cols) * TILE * 1.7, float(_rows) * TILE * 1.7)
	CaveFloorBuild.build(container, _cave_graph, level_size, 12.0, TILE * 1.2, TILE, _wall_color, TILE * 0.4)

# [§62, v.4.3] Графовый аналог _maze_shift: клеточная версия открывает один
# закрытый проход и закрывает другой на объездном пути между теми же двумя
# точками — связность гарантирована, потому что закрытие происходит на уже
# существующем обходном маршруте. У графа нет "закрытых стен" между всеми
# соседними клетками, зато есть то же деление рёбер на MST (единственный
# гарантированный каркас связности — см. CaveGraph._build_mst) и "лишние"
# рёбра сверх дерева (циклы-развилки, _extra_loop_edges). Закрываем ТОЛЬКО
# лишнее ребро (MST не трогаем — связность графа остаётся доказуемой) и
# открываем новое, тем же способом, что и _do_quake_graph (короткая пара
# геометрически близких, но пока не связанных узлов) — тот же эффект
# "один путь закрылся, другой открылся", без риска разорвать граф.
func _do_shift_graph() -> void:
	if not _caves_graph_active or _floor_containers.is_empty() or _player == null:
		return
	var container: Node2D = _floor_containers[0]
	if container == null:
		return
	var nodes: Array = _cave_graph.get("nodes", [])
	var edges: Array = _cave_graph.get("edges", [])
	var mst_edges: Array = _cave_graph.get("mst_edges", [])
	if nodes.size() < 4 or edges.size() <= mst_edges.size():
		return   # нет лишних рёбер сверх дерева — закрывать нечего

	var mst_set := {}
	for e in mst_edges:
		mst_set["%d_%d" % [mini(e.x, e.y), maxi(e.x, e.y)]] = true

	# Кандидаты на закрытие: не-MST рёбра, чья середина не рядом с игроком
	# (тот же запас TILE*2, что у клеточной версии, только считаем от
	# середины ребра, а не от клетки-стены).
	var closable: Array[int] = []
	for i in edges.size():
		var e: Vector2i = edges[i]
		if mst_set.has("%d_%d" % [mini(e.x, e.y), maxi(e.x, e.y)]):
			continue
		var mid: Vector2 = ((nodes[e.x] as Vector2) + (nodes[e.y] as Vector2)) * 0.5
		if mid.distance_to(_player.global_position) < TILE * 2.0:
			continue
		closable.append(i)
	if closable.is_empty():
		return

	# Адъяцентность ДО закрытия — кандидат на открытие ищем среди пар, ещё
	# не соединённых напрямую (закрываемое ребро намеренно не открываем
	# заново тем же ходом — иначе шаг ничего не меняет).
	var adj := {}
	for i in nodes.size():
		adj[i] = {}
	for e in edges:
		adj[e.x][e.y] = true
		adj[e.y][e.x] = true
	var open_candidates: Array[Vector2i] = []
	for i in nodes.size():
		for j in range(i + 1, nodes.size()):
			if adj[i].has(j):
				continue
			if (nodes[i] as Vector2).distance_to(nodes[j]) < TILE * 6.0:
				open_candidates.append(Vector2i(i, j))
	if open_candidates.is_empty():
		return   # некуда открывать — лучше не закрывать вообще, чем сузить граф без компенсации

	closable.shuffle()
	var close_idx: int = closable[0]
	open_candidates.shuffle()
	var open_pair: Vector2i = open_candidates[0]

	var polylines: Array = _cave_graph.get("polylines", [])
	edges.remove_at(close_idx)
	polylines.remove_at(close_idx)
	var rng := RandomNumberGenerator.new()
	rng.seed = randi()
	edges.append(open_pair)
	polylines.append(CaveGraph.edge_polyline(nodes[open_pair.x], nodes[open_pair.y], rng))

	_cave_graph["edges"] = edges
	_cave_graph["polylines"] = polylines
	for c in container.get_children():
		c.queue_free()
	var level_size := Vector2(float(_cols) * TILE * 1.7, float(_rows) * TILE * 1.7)
	CaveFloorBuild.build(container, _cave_graph, level_size, 12.0, TILE * 1.2, TILE, _wall_color, TILE * 0.4)

func _do_quake() -> void:
	if _player == null or not is_instance_valid(_player):
		return
	var f: int = _player.current_floor
	if f < 0 or f >= _grids.size():
		return
	var broken := 0
	var tries := 0
	while broken < 6 and tries < 200:
		tries += 1
		var gx := 1 + randi() % (_gw - 2)
		var gy := 1 + randi() % (_gh - 2)
		if not (_grids[f] as Array)[gy][gx]:
			continue
		# Не трогаем «пеньки» на пересечениях (нечётная+нечётная не бывает стеной,
		# чётная+чётная — опорный столб): рушим только перегородки между клетками.
		if gx % 2 == gy % 2:
			continue
		_set_wall(f, gx, gy, false)
		var bb := Node2D.new()
		bb.set_script(load("res://burst.gd"))
		bb.color = Color(0.9, 0.65, 0.35, 1.0)
		bb.max_scale = 3.5
		bb.dur = 0.5
		add_child(bb)
		bb.global_position = Vector2(gx * TILE + TILE * 0.5, gy * TILE + TILE * 0.5 + f * _floor_gap)
		broken += 1
	if _player.has_method("add_shake"):
		_player.add_shake(10.0, 0.6)

# «Живой лабиринт» (§10.4) — см. комментарий у объявления полей выше.
func _update_living_maze(delta: float) -> void:
	if _living_maze_done or not _events_enabled or _building_arena or _superboss_level:
		return
	if _living_maze_cd > 0.0:
		_living_maze_cd -= delta
		return
	if _player == null or not is_instance_valid(_player):
		return
	var path := guide_path_to_exit(_player.global_position, _player.current_floor)
	if path.size() < LIVING_MAZE_MIN_STEPS:
		return
	var from: Vector2 = path[0]
	var to: Vector2 = path[path.size() - 1]
	var straight_cells: float = from.distance_to(to) / (TILE * 2.0)
	var path_cells: float = float(path.size() - 1)
	if straight_cells < 1.0 or path_cells < straight_cells * LIVING_MAZE_DETOUR_MULT:
		return
	if _dissolve_wall_toward_goal(from, to):
		_living_maze_done = true
		flash_message(GameConfig.tt("◈ Лабиринт сжалился — стена впереди растворилась", "◈ The maze took pity — a wall ahead dissolved"))

# Ищет ближайшую подходящую внутреннюю стену в направлении цели (в радиусе
# LIVING_MAZE_RADIUS тайлов от игрока) и убирает её — та же техника, что у
# землетрясения (_do_quake: только перегородки между клетками, не «пеньки» и
# не границы), но выбор не случайный, а по направлению к цели.
func _dissolve_wall_toward_goal(from: Vector2, to: Vector2) -> bool:
	if _player == null or not is_instance_valid(_player):
		return false
	var f: int = _player.current_floor
	if f < 0 or f >= _grids.size():
		return false
	var grid: Array = _grids[f]
	var dir: Vector2 = to - from
	if dir.length() < 1.0:
		return false
	dir = dir.normalized()
	var gx0 := int(round(from.x / TILE))
	var gy0 := int(round((from.y - f * _floor_gap) / TILE))
	var best := Vector2i(-1, -1)
	var best_score := -INF
	var r := LIVING_MAZE_RADIUS
	for gy in range(maxi(1, gy0 - r), mini(_gh - 1, gy0 + r)):
		for gx in range(maxi(1, gx0 - r), mini(_gw - 1, gx0 + r)):
			if gx % 2 == gy % 2:
				continue   # только перегородки между клетками, не пеньки-пересечения
			if not (grid[gy][gx]):
				continue
			var wpos := Vector2(gx * TILE + TILE * 0.5, gy * TILE + TILE * 0.5)
			var to_wall: Vector2 = wpos - from
			var d: float = to_wall.length()
			if d < 1.0 or d > TILE * float(r):
				continue
			var score: float = dir.dot(to_wall.normalized()) - d / (TILE * float(r)) * 0.3
			if score > best_score:
				best_score = score
				best = Vector2i(gx, gy)
	if best.x < 0:
		return false
	_set_wall(f, best.x, best.y, false)
	var bb := Node2D.new()
	bb.set_script(load("res://burst.gd"))
	bb.color = Color(0.5, 1.0, 0.6, 1.0)
	bb.max_scale = 3.5
	bb.dur = 0.6
	add_child(bb)
	bb.global_position = Vector2(best.x * TILE + TILE * 0.5, best.y * TILE + TILE * 0.5 + f * _floor_gap)
	return true

func _end_event() -> void:
	_event_label.visible = false
	_tint_target = Color(0, 0, 0, 0)
	_vision_target = 1.0   # вернуть нормальный радиус видимости
	# Следующее событие — реже на низких уровнях, чаще на высоких
	var lo := maxf(6.0, 16.0 - _level)
	_event_cd = randf_range(lo, lo + 8.0)

# --- Маяк (GAMEDESIGN.md п.10.6) ---

func _update_beacon(delta: float) -> void:
	if _beacon_spawned or not _mech_ready("events"):
		return
	_beacon_cd -= delta
	if _beacon_cd <= 0.0:
		_spawn_beacon()

func _spawn_beacon() -> void:
	_beacon_spawned = true   # не чаще раза за уровень, даже если спавн не удался
	if _player == null or not is_instance_valid(_player):
		return
	var f: int = _player.current_floor
	if f < 0 or f >= _grids.size() or f >= _floor_containers.size():
		return
	var grid: Array = _grids[f]
	var cells := _passage_cells(f == 0, grid)
	if cells.is_empty():
		return
	# Не спавним слишком близко к игроку (в клетках сетки) — иначе не «добежать», а «зайти».
	var p_local: Vector2 = _player.global_position - Vector2(0, f * _floor_gap)
	var pcx: int = clampi(int(round((p_local.x / TILE - 1.5) / 2.0)), 0, _cols - 1)
	var pcy: int = clampi(int(round((p_local.y / TILE - 1.5) / 2.0)), 0, _rows - 1)
	var far_cells: Array[Vector2i] = []
	for c in cells:
		if absi(c.x - pcx) + absi(c.y - pcy) >= 6:
			far_cells.append(c)
	if far_cells.is_empty():
		far_cells = cells
	far_cells.shuffle()
	var cell: Vector2i = far_cells[0]

	var b := Area2D.new()
	b.set_script(load("res://beacon.gd"))
	b.game = self
	_floor_containers[f].add_child(b)
	b.global_position = Vector2((cell.x * 2 + 1) * TILE + TILE * 0.5, (cell.y * 2 + 1) * TILE + TILE * 0.5) \
		+ Vector2(0, f * _floor_gap)
	beep()   # тихий «пинг» — игрок знает, что маяк появился, но не знает где

# Вызывается из beacon.gd при достижении игроком. kind — один из
# gold/azure/crimson/silver/emerald (см. BEACON_KINDS в beacon.gd).
func beacon_reward(kind: String) -> void:
	match kind:
		"gold":
			_beacon_bonus_shards(2)
			flash_message(GameConfig.tt("🗼 Маяк: +2 осколка", "🗼 Beacon: +2 shards"))
		"azure":
			if _player and is_instance_valid(_player):
				_player.energy = _player.max_energy
			flash_message(GameConfig.tt("🗼 Маяк: Свет полностью восполнен", "🗼 Beacon: Light fully restored"))
		"crimson":
			for e in get_tree().get_nodes_in_group("enemy"):
				if "stun_time" in e:
					e.stun_time = maxf(e.stun_time, 5.0)
			flash_message(GameConfig.tt("🗼 Маяк: враги заморожены", "🗼 Beacon: enemies frozen"))
		"silver":
			_beacon_reset_random_cooldown()
			flash_message(GameConfig.tt("🗼 Маяк: навык снова готов", "🗼 Beacon: a skill's cooldown was reset"))
		"emerald":
			if GameConfig.active_run >= 0:
				_ember += 50.0 * _ember_mult()
				flash_message(GameConfig.tt("🗼 Маяк: +50 Накала", "🗼 Beacon: +50 Ember"))
			else:
				_beacon_bonus_shards(1)
				flash_message(GameConfig.tt("🗼 Маяк: +1 осколок", "🗼 Beacon: +1 shard"))
	if _fx:
		_fx.gold_pulse(0.8)

func _beacon_bonus_shards(n: int) -> void:
	_shards_total += n
	for i in n:
		collect_shard()

func _beacon_reset_random_cooldown() -> void:
	if _player == null or not is_instance_valid(_player):
		return
	var opts := ["flash_cd", "dash_cd", "sonar_cd", "shield_cd", "guide_cd"]
	opts.shuffle()
	for prop in opts:
		if prop in _player:
			_player.set(prop, 0.0)
			return

# --- «Гости лабиринта» (GAMEDESIGN.md п.14) ---
# Случайные необязательные мини-события со своим таймером: максимум одно за
# уровень, о появлении сообщает баннер. Не меняют правил — добавляют выбор.

func _update_guests(delta: float) -> void:
	if _guest_spawned or not _mech_ready("guests") or _boss_arena_mode:
		return
	_guest_cd -= delta
	if _guest_cd <= 0.0:
		_spawn_guest()

func _spawn_guest() -> void:
	_guest_spawned = true   # не чаще раза за уровень, даже если спавн не удался
	if _player == null or not is_instance_valid(_player):
		return
	var f: int = _player.current_floor
	if f < 0 or f >= _grids.size() or f >= _floor_containers.size():
		return
	# [GAMEDESIGN §26] Гость выбирается не равновероятно, а по весам биома:
	# в Шахтах чаще вор, в Недрах — беглец/кроты, в Пустотах — огонёк.
	var base := {"hunt": 1.0, "wisp": 1.0, "burrows": 1.0}
	# Вор интересен, когда есть что красть: несомый Накал или запас света.
	if GameConfig.active_run >= 0 or _mech_ready("guests"):
		base["thief"] = 1.0
	var pick := _weighted_pick(_apply_biome_weights(base, "guests"))
	match pick:
		"hunt":
			var cell := _guest_far_cell(f, 6)
			if cell.x < 0:
				return
			var g := Area2D.new()
			g.set_script(load("res://guest_runner.gd"))
			g.game = self
			g.floor_index = f
			_floor_containers[f].add_child(g)
			g.global_position = _cell_to_world(cell) + Vector2(0, f * _floor_gap)
			flash_message(GameConfig.tt("⚑ Охота: беглец в лабиринте — поймай, пока не ускользнул!", "⚑ Hunt: a runner is in the maze — catch it before it slips away!"))
			beep()
		"wisp":
			var w := Node2D.new()
			w.set_script(load("res://guest_wisp.gd"))
			w.game = self
			add_child(w)
			w.global_position = _player.global_position + Vector2(0, -40)
			flash_message(GameConfig.tt("✨ Огонёк-союзник рядом: он отвлекает тьму от тебя", "✨ A friendly wisp is near: it distracts the dark from you"))
		"burrows":
			var cells := _passage_cells(f == 0, _grids[f])
			cells.shuffle()
			var placed := 0
			for c in cells:
				if placed >= 3:
					break
				var world := _cell_to_world(c) + Vector2(0, f * _floor_gap)
				var d: float = world.distance_to(_player.global_position)
				if d < TILE * 3.0 or d > TILE * 12.0:
					continue
				var b := Node2D.new()
				b.set_script(load("res://guest_burrow.gd"))
				b.game = self
				b.floor_index = f
				b.cell = c
				_floor_containers[f].add_child(b)
				b.global_position = world
				placed += 1
			if placed > 0:
				flash_message(GameConfig.tt("⛏ Кроты роются под этажом — не стой над норами!", "⛏ Moles are digging under the floor — don't stand over the burrows!"))
				if _player.has_method("add_shake"):
					_player.add_shake(5.0, 0.3)
		"thief":
			var tcell := _guest_far_cell(f, 5)
			if tcell.x < 0:
				return
			var t := Area2D.new()
			t.set_script(load("res://guest_thief.gd"))
			t.game = self
			t.floor_index = f
			_floor_containers[f].add_child(t)
			t.global_position = _cell_to_world(tcell) + Vector2(0, f * _floor_gap)
			flash_message(GameConfig.tt("🜲 Вор почуял твой свет — не дай ему коснуться тебя!", "🜲 A thief senses your light — don't let it touch you!"))
			beep()

# Случайная клетка-проход этажа f не ближе min_d клеток от игрока
# (или (-1,-1), если не нашлась).
func _guest_far_cell(f: int, min_d: int) -> Vector2i:
	var cells := _passage_cells(f == 0, _grids[f])
	if cells.is_empty():
		return Vector2i(-1, -1)
	var p_local: Vector2 = _player.global_position - Vector2(0, f * _floor_gap)
	var pcx: int = clampi(int(round((p_local.x / TILE - 1.5) / 2.0)), 0, _cols - 1)
	var pcy: int = clampi(int(round((p_local.y / TILE - 1.5) / 2.0)), 0, _rows - 1)
	var far: Array[Vector2i] = []
	for c in cells:
		if absi(c.x - pcx) + absi(c.y - pcy) >= min_d:
			far.append(c)
	if far.is_empty():
		far = cells
	return far[randi() % far.size()]

# Беглец пойман: щедрая награда — Накал в забеге, осколок+Воля в «Уровнях».
func guest_runner_caught(pos: Vector2) -> void:
	GameConfig.add_xp(100)
	if GameConfig.active_run >= 0:
		_ember += 40.0 * _ember_mult()
		flash_message(GameConfig.tt("⚑ Беглец пойман: +Накал!", "⚑ Runner caught: +Ember!"))
	else:
		_beacon_bonus_shards(1)
		if _player and is_instance_valid(_player):
			_player.add_will(0.5)
		flash_message(GameConfig.tt("⚑ Беглец пойман: осколок и Воля!", "⚑ Runner caught: a shard and Will!"))
	if _fx:
		_fx.gold_pulse(1.0)
	var sp := CPUParticles2D.new()
	sp.set_script(load("res://sparkle.gd"))
	sp.spark_color = Color(1.0, 0.8, 0.2)
	sp.spark_amount = 26
	sp.spark_speed = 240.0
	add_child(sp)
	sp.global_position = pos

func guest_runner_escaped() -> void:
	flash_message(GameConfig.tt("Беглец ускользнул во тьму…", "The runner slipped away into the dark…"))

# Вор коснулся игрока: забирает часть несомого Накала (или глоток света).
func guest_thief_steal() -> Dictionary:
	if GameConfig.active_run >= 0 and _ember > 0.0:
		var amount: float = minf(_ember * 0.3, 60.0)
		_ember -= amount
		flash_message(GameConfig.tt("🜲 Вор украл %d Накала — догони его!", "🜲 A thief stole %d Ember — catch it!") % int(amount))
		return {"ember": amount}
	if _player and is_instance_valid(_player):
		var amount: float = minf(_player.energy * 0.25, 0.5)
		_player.energy = maxf(0.0, _player.energy - amount)
		flash_message(GameConfig.tt("🜲 Вор глотнул твоего света — догони его!", "🜲 A thief sipped your light — catch it!"))
		return {"light": amount}
	return {}

# Вор убит: добыча возвращается с процентами (+25%).
func guest_thief_killed(loot: Dictionary, pos: Vector2) -> void:
	GameConfig.add_xp(80)
	if loot.has("ember"):
		_ember += float(loot["ember"]) * 1.25
		flash_message(GameConfig.tt("🜲 Вор наказан: Накал вернулся с лихвой!", "🜲 Thief punished: Ember came back with interest!"))
	elif loot.has("light"):
		if _player and is_instance_valid(_player):
			_player.energy = minf(_player.max_energy, _player.energy + float(loot["light"]) * 1.25)
		flash_message(GameConfig.tt("🜲 Вор наказан: свет вернулся с лихвой!", "🜲 Thief punished: light came back with interest!"))
	else:
		flash_message(GameConfig.tt("🜲 Вор пойман до кражи!", "🜲 Thief caught before it could steal!"))
	if _fx:
		_fx.gold_pulse(0.8)
	var sp := CPUParticles2D.new()
	sp.set_script(load("res://sparkle.gd"))
	sp.spark_color = Color(0.7, 0.4, 1.0)
	sp.spark_amount = 22
	sp.spark_speed = 220.0
	add_child(sp)
	sp.global_position = pos

func guest_thief_escaped(loot: Dictionary) -> void:
	if loot.is_empty():
		flash_message(GameConfig.tt("Вор растворился во тьме ни с чем.", "The thief dissolved into the dark empty-handed."))
	else:
		flash_message(GameConfig.tt("Вор скрылся с добычей…", "The thief escaped with its loot…"))

# --- Обучение ---

# Постоянный «текущий шаг» под верхней HUD-полосой — не пересекается с ней
# (полоса занимает верх экрана, эта подсказка сразу под ней).
func _build_tutorial_hud() -> void:
	# Обучение живьём читает GameConfig.skill_uses для отслеживания шагов
	# (нажал Q/Shift/R) — снимок нужен, чтобы отменить эту прокачку мастерства
	# в конце обучения (см. _tut_restore_skill_uses).
	_tut_skill_uses_snapshot = GameConfig.skill_uses.duplicate()
	_tut_dash_baseline = int(GameConfig.skill_uses.get("dash", 0))
	_tut_flash_baseline = int(GameConfig.skill_uses.get("flash", 0))
	_tut_smother_baseline = int(GameConfig.skill_uses.get("smother", 0))
	_tut_mark_baseline = int(GameConfig.skill_uses.get("mark", 0))
	_tut_sonar_baseline = int(GameConfig.skill_uses.get("sonar", 0))
	_tut_shield_baseline = int(GameConfig.skill_uses.get("shield", 0))
	_tut_guide_baseline = int(GameConfig.skill_uses.get("guide", 0))
	_tut_reveal_baseline = int(GameConfig.skill_uses.get("reveal", 0))
	_tut_pulse_baseline = int(GameConfig.skill_uses.get("pulse", 0))
	_tut_step = 0
	_tut_station_used = false
	_tut_combo_done = false
	_tut_setup_stage_extras()
	# Цель этапа — первым сообщением, до любых шагов.
	var stage_intro: String = GameConfig.tt("Этап обучения %d из %d.", "Tutorial stage %d of %d.") \
		% [GameConfig.tutorial_stage + 1, GameConfig.TUTORIAL_STAGE_COUNT]
	call_deferred("flash_message", stage_intro)

	# Попап цели шага + попап-урок «✓ …» — оба живут в общем стеке _top_stack
	# (см. _build_hud) вместе с обычным тостом: раньше все три позиционировались
	# независимо фиксированными офсетами и перекрывали друг друга при одновременном
	# показе (жалоба «надписи пересекаются и уходят за экран»). VBoxContainer сам
	# укладывает их друг под другом; move_child держит цель/урок над тостом.
	_tut_panel = _tut_make_panel(Color(0.3, 0.6, 1.0))
	_tut_panel.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	_top_stack.add_child(_tut_panel)
	_top_stack.move_child(_tut_panel, 0)
	_tut_label = _tut_panel.get_child(0)
	_tut_label.add_theme_color_override("font_color", Color(1.0, 0.95, 0.75))
	_tut_set_goal(_tut_field(_tutorial_steps()[0], "goal"))

	_tut_lesson_panel = _tut_make_panel(Color(0.4, 1.0, 0.6))
	_tut_lesson_panel.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	_tut_lesson_panel.visible = false
	_top_stack.add_child(_tut_lesson_panel)
	_top_stack.move_child(_tut_lesson_panel, 1)
	_tut_lesson_label = _tut_lesson_panel.get_child(0)
	_tut_lesson_label.add_theme_color_override("font_color", Color(0.75, 1.0, 0.85))

# Полупрозрачная плашка-указатель обучения (панель + label внутри).
func _tut_make_panel(accent: Color) -> PanelContainer:
	var p := PanelContainer.new()
	var sb := StyleBoxFlat.new()
	sb.bg_color = Color(0.03, 0.05, 0.10, 0.72)
	sb.set_corner_radius_all(10)
	sb.set_border_width_all(1)
	sb.border_color = Color(accent.r, accent.g, accent.b, 0.55)
	sb.content_margin_left = 18
	sb.content_margin_right = 18
	sb.content_margin_top = 8
	sb.content_margin_bottom = 8
	p.add_theme_stylebox_override("panel", sb)
	p.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var l := Label.new()
	l.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	l.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	l.custom_minimum_size = Vector2(560, 0)
	l.add_theme_font_size_override("font_size", 19)
	_label_outline(l, 4)
	l.mouse_filter = Control.MOUSE_FILTER_IGNORE
	p.add_child(l)
	return p

# Сменить цель шага с мягким проявлением.
func _tut_set_goal(goal: String) -> void:
	_tut_label.text = "▸ %s" % goal
	_tut_panel.modulate.a = 0.0
	var tw := create_tween()
	tw.tween_property(_tut_panel, "modulate:a", 1.0, 0.35)

# Показать урок выполненного шага (сам гаснет в _update_tutorial).
func _tut_show_lesson(text: String) -> void:
	_tut_lesson_label.text = "✓ %s" % text
	_tut_lesson_panel.visible = true
	_tut_lesson_time = 5.0
	_tut_lesson_panel.modulate.a = 0.0
	var tw := create_tween()
	tw.tween_property(_tut_lesson_panel, "modulate:a", 1.0, 0.3)

# Цель-объект текущего шага (для стрелки-указателя): осколок/кристалл/выход,
# либо декорация конкретного этапа (враг/тёмная станция/яма — _tut_enemy и т.п.).
func _tut_target_pos() -> Vector2:
	if _player == null or not is_instance_valid(_player):
		return Vector2.INF
	var grp := ""
	match GameConfig.tutorial_stage:
		0:
			match _tut_step:
				1: grp = "shard"
				5:
					if _tut_enemy != null and is_instance_valid(_tut_enemy):
						return _tut_enemy.global_position
				6: grp = "station"
				7: grp = "exit"
		1:
			match _tut_step:
				3:
					if _tut_enemy != null and is_instance_valid(_tut_enemy):
						return _tut_enemy.global_position
				7: grp = "exit"
		2:
			match _tut_step:
				1:
					if _tut_darkstation != null and is_instance_valid(_tut_darkstation):
						return _tut_darkstation.global_position
				2:
					if _tut_pit != null and is_instance_valid(_tut_pit):
						return _tut_pit.global_position
				3: grp = "exit"
	if grp == "":
		return Vector2.INF
	var best := Vector2.INF
	var best_d := 1e18
	for n in get_tree().get_nodes_in_group(grp):
		if not is_instance_valid(n):
			continue
		var d: float = n.global_position.distance_squared_to(_player.global_position)
		if d < best_d:
			best_d = d
			best = n.global_position
	return best

# Ставит декорации конкретного этапа обучения: врага (этапы 0 и 1) или тёмную
# станцию + яму (этап 2). Обычные объекты (осколок/станция/выход) уже кладутся
# штатным конвейером _spawn_floor_pickups — здесь только то, что ему не нужно
# делать на обычных уровнях. Подальше от входа (0,0), чтобы не встречать
# врага/преграду сразу же, без разгона/понимания навыков.
func _tut_setup_stage_extras() -> void:
	_tut_enemy = null
	_tut_darkstation = null
	_tut_pit = null
	if _floor_containers.is_empty() or _grids.is_empty():
		return
	var container: Node2D = _floor_containers[0]
	var grid: Array = _grids[0]
	var cells := _passage_cells(true, grid)
	cells.shuffle()
	var candidates: Array[Vector2i] = []
	for c in cells:
		if absi(c.x) + absi(c.y) >= 3:
			candidates.append(c)
	if candidates.is_empty():
		candidates = cells
	if candidates.is_empty():
		return

	match GameConfig.tutorial_stage:
		0, 1:
			_tut_enemy = _tut_spawn_enemy(candidates[0])
		2:
			var ds := Area2D.new()
			ds.set_script(load("res://dark_station.gd"))
			ds.game = self
			ds.floor_index = 0
			ds.position = _cell_to_world(candidates[0])
			container.add_child(ds)
			_tut_darkstation = ds
			if candidates.size() > 1:
				var pit := StaticBody2D.new()
				pit.set_script(load("res://pit.gd"))
				pit.game = self
				pit.floor_index = 0
				pit.position = _cell_to_world(candidates[1])
				container.add_child(pit)
				_tut_pit = pit

# Враги (как и в _spawn_one_enemy/_spawn_superboss_escort) — дети main, НЕ
# floor-контейнера: container сдвинут на f*_floor_gap только визуально/для
# пикапов, а pursuer.gd сам кодирует этаж прямо в position + _enemy_floor.
func _tut_spawn_enemy(cell: Vector2i) -> Node:
	var e := Node2D.new()
	e.set_script(load("res://pursuer.gd"))
	e.enemy_type = 0   # SLOW — самый безобидный, для первой контролируемой встречи
	e.spawn_level = 1
	e._enemy_floor = 0
	e.position = _cell_to_world(cell)
	e.target = _player
	e._game = self
	e.process_mode = Node.PROCESS_MODE_PAUSABLE
	add_child(e)
	return e

func is_tutorial_frozen() -> bool:
	return _tut_freeze

# Полупрозрачная стрелка-указатель: летит от игрока к цели шага (как пульс маяка).
func _tut_emit_arrow(target: Vector2) -> void:
	var from: Vector2 = _player.global_position
	var dir := target - from
	if dir.length() < 100.0:
		return   # цель уже рядом — указатель не нужен
	dir = dir.normalized()
	var s := Sprite2D.new()
	s.texture = MazeTextures.make_light(52)
	s.modulate = Color(1.0, 0.92, 0.5, 0.5)
	add_child(s)
	s.global_position = from + dir * 44.0
	var tw := s.create_tween()
	tw.tween_property(s, "global_position", from + dir * 210.0, 1.0) \
		.set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	tw.parallel().tween_property(s, "modulate:a", 0.0, 1.0)
	tw.tween_callback(s.queue_free)

# Вызывается станцией (station.gd) при успешном «глотке» — засчитывает шаг
# «дойди до кристалла», независимо от того, на каком он сейчас месте в списке.
func tutorial_station_used() -> void:
	_tut_station_used = true

func _update_tutorial() -> void:
	if _tut_label == null or not is_instance_valid(_tut_label):
		return

	# Пауза геймплея, пока читается попап-урок (не тот же _paused/меню паузы —
	# HUD и сам таймер урока продолжают тикать, замирают только игрок/враги).
	if _tut_lesson_time > 0.0:
		_tut_lesson_time -= get_process_delta_time()
		if _tut_lesson_time <= 0.0:
			_tut_freeze = false
			if _player and is_instance_valid(_player):
				_player.active = true
			if is_instance_valid(_tut_lesson_panel):
				var tw := create_tween()
				tw.tween_property(_tut_lesson_panel, "modulate:a", 0.0, 0.4)
				tw.tween_callback(func() -> void: _tut_lesson_panel.visible = false)
		return   # шаги не проверяем, пока не закончится урок

	var steps := _tutorial_steps()
	var advanced := false
	match GameConfig.tutorial_stage:
		0:
			match _tut_step:
				0: advanced = _player != null and is_instance_valid(_player) and _player.started
				# Шаг стойки (§29): засчитывается, когда игрок реально подвигал
				# ручку — флаг ставит on_light_stance_changed.
				1: advanced = _tut_stance_changed
				2: advanced = _shards_collected >= 1
				3: advanced = int(GameConfig.skill_uses.get("flash", 0)) > _tut_flash_baseline
				4: advanced = int(GameConfig.skill_uses.get("dash", 0)) > _tut_dash_baseline
				5: advanced = int(GameConfig.skill_uses.get("smother", 0)) > _tut_smother_baseline
				6:
					# Встреча с врагом: либо игрок его одолел (узел исчез/погашен —
					# исход недоказуем сложнее, чем контакт, поэтому шире), либо
					# просто подошёл вплотную — контакт уже случился по факту.
					advanced = _tut_enemy == null or not is_instance_valid(_tut_enemy) \
						or (_player != null and is_instance_valid(_player) \
							and _player.global_position.distance_to(_tut_enemy.global_position) < 70.0)
				7: advanced = _tut_station_used
				# [§42] Шаг про захваченную землю: засчитывается, когда игрок
				# протоптал заметный след, а не сделал один шаг.
				8: advanced = _claim_time.size() >= 6
				# [§56] Метка (M) — учим сразу после территории, раз она эту
				# территорию и держит.
				9: advanced = int(GameConfig.skill_uses.get("mark", 0)) > _tut_mark_baseline
		1:
			match _tut_step:
				0: advanced = _player != null and is_instance_valid(_player) and _player.started
				1: advanced = int(GameConfig.skill_uses.get("sonar", 0)) > _tut_sonar_baseline
				2: advanced = int(GameConfig.skill_uses.get("shield", 0)) > _tut_shield_baseline
				3:
					if not _tut_combo_done and _player != null and is_instance_valid(_player) \
							and _player.has_method("is_shielded") and _player.is_shielded() \
							and _player.has_method("is_dashing") and _player.is_dashing():
						_tut_combo_done = true
					advanced = _tut_combo_done
				4: advanced = int(GameConfig.skill_uses.get("guide", 0)) > _tut_guide_baseline
				5: advanced = int(GameConfig.skill_uses.get("reveal", 0)) > _tut_reveal_baseline
				6: advanced = int(GameConfig.skill_uses.get("pulse", 0)) > _tut_pulse_baseline
		2:
			match _tut_step:
				0: advanced = _player != null and is_instance_valid(_player) and _player.started
				1: advanced = _tut_darkstation == null or not is_instance_valid(_tut_darkstation) or not _tut_darkstation.active
				2:
					advanced = _tut_pit != null and is_instance_valid(_tut_pit) and _player != null \
						and is_instance_valid(_player) and _player.has_method("is_dashing") and _player.is_dashing() \
						and _player.global_position.distance_to(_tut_pit.global_position) < 70.0

	if advanced and _tut_step < steps.size() - 1:
		# Урок выполненного шага: объясняем, ЧТО это было и зачем оно в игре.
		var lesson := _tut_field(steps[_tut_step], "lesson")
		_tut_step += 1
		_tut_set_goal(_tut_field(steps[_tut_step], "goal"))
		beep()
		if lesson != "":
			_tut_show_lesson(lesson)
			_tut_freeze = true
			if _player and is_instance_valid(_player):
				_player.active = false

	# Пульс-стрелка к цели шага раз в ~1.4 сек.
	_tut_arrow_t -= get_process_delta_time()
	if _tut_arrow_t <= 0.0:
		_tut_arrow_t = 1.4
		var target := _tut_target_pos()
		if target != Vector2.INF:
			_tut_emit_arrow(target)

# --- Пауза ---

# Свернули игру / переключились на другое окно — автоматическая пауза
# (звук глушит GameConfig, он живёт и в меню).
func _notification(what: int) -> void:
	if what == NOTIFICATION_APPLICATION_FOCUS_OUT:
		if not _paused and not _won and not _dead and not _game_over:
			_toggle_pause()

func _toggle_pause() -> void:
	_paused = not _paused
	get_tree().paused = _paused
	_pause_overlay.visible = _paused
	if _fx:
		_fx.visible = not _paused   # не показывать виньетки поверх меню паузы
	if _paused:
		_refresh_pause()

func _refresh_pause() -> void:
	var en := GameConfig.locale == "en"
	var t := ("[ Active skills ]" if en else "[ Активные навыки ]") + char(10)
	t += (("Q — Flash     Shift — Dash") if en else ("Q — Вспышка     Shift — Рывок")) + char(10)
	t += (("E — Sonar       C — Shield") if en else ("E — Сонар       C — Щит")) + char(10)
	t += (("G — Guide (path to exit)") if en else ("G — Искра (путь к выходу)")) + char(10)
	if _player:
		t += ((("F — Reveal (%d%%)") if en else ("F — Озарение (%d%%)")) + char(10)) % int(_player.reveal_charge * 100.0)
	else:
		t += (("F — Reveal") if en else ("F — Озарение")) + char(10)
	t += (("B — Pulse (audio guide to exit)") if en else ("B — Пульс (звуковой ориентир к выходу)")) + char(10) + char(10)

	t += ("[ Passive skills ]" if en else "[ Пассивные навыки ]") + char(10)
	var names_ru := {
		"save": "Энергосбережение", "capacity": "Емкость",
		"charge": "Быстрая зарядка", "range": "Дальний свет",
		"legs": "Легкие ноги", "magic": "Эффективная магия",
	}
	var names_en := {
		"save": "Energy saving", "capacity": "Capacity",
		"charge": "Fast charge", "range": "Long light",
		"legs": "Light legs", "magic": "Efficient magic",
	}
	var names = names_en if en else names_ru
	var any := false
	for k in names:
		if GameConfig.passives.get(k, false):
			t += ("• %s" % names[k]) + char(10)
			any = true
	if not any:
		t += (("— none chosen —") if en else ("— невыбраны —")) + char(10)

	if GameConfig.progressive_enabled and _player:
		t += char(10) + (("[ Accumulating ]") if en else ("[ Накопительные ]")) + char(10)
		t += ((("Momentum: +%d%% speed") if en else ("Разгон: +%d%% скорости")) % int(_player.momentum_bonus * 100.0)) + char(10)
		t += ((("Adaptation: −%d%% drain") if en else ("Адаптация: −%d%% разрядки")) % int(_player.adapt_bonus * 100.0)) + char(10)

	_pause_info.text = t

	if _minimap:
		_minimap.texture = _build_minimap_texture()

func _restart() -> void:
	get_tree().paused = false
	get_tree().reload_current_scene()

func _tut_restore_skill_uses() -> void:
	for k in _tut_skill_uses_snapshot:
		GameConfig.skill_uses[k] = _tut_skill_uses_snapshot[k]

func _goto_menu() -> void:
	if GameConfig.tutorial_mode:
		_tut_restore_skill_uses()   # обучение не должно прокачивать мастерство навыков
	GameConfig.tutorial_mode = false
	GameConfig.lair_mode = false
	if GameConfig.active_run >= 0:
		# Накал: гибель завершает забег, иначе — сохраняем и продолжим позже.
		if _game_over:
			GameConfig.end_run()
		else:
			GameConfig.leave_run()
	else:
		GameConfig.save_game()
	get_tree().paused = false
	get_tree().change_scene_to_file("res://menu.tscn")

func _open_skills_menu() -> void:
	_pause_overlay.visible = false
	var sm := CanvasLayer.new()
	sm.set_script(load("res://skills_menu.gd"))
	add_child(sm)
	sm.closed.connect(func():
		if is_instance_valid(_pause_overlay):
			_pause_overlay.visible = true)

func _unhandled_input(event: InputEvent) -> void:
	if not (event is InputEventKey and event.pressed and not event.echo):
		return
	var k: int = event.keycode

	if _won or _game_over:
		if k == KEY_ESCAPE:
			_goto_menu()
		return

	if k == KEY_ESCAPE or k == KEY_P:
		# Если открыт магазин-алтарь — Escape закрывает его и возвращает в паузу,
		# а не снимает паузу под открытым экраном (иначе игра шла бы «за» меню).
		if is_instance_valid(_altar_layer):
			if k == KEY_ESCAPE:
				_close_altar_shop()
			return
		_toggle_pause()

# --- Генерация лабиринта (recursive backtracker) ---

func _make_grid() -> Array:
	var grid: Array = []
	grid.resize(_gh)
	for y in _gh:
		var row := []
		row.resize(_gw)
		for x in _gw:
			row[x] = true
		grid[y] = row

	# Growing-tree: чаще берём самую свежую клетку (длинные коридоры),
	# иногда — случайную из активных (ветвление). Для органических уровней
	# больше ветвлений — структура напоминает корни/ветви дерева.
	# Узкая фаза ритма — только длинные коридоры; широкая — больше ветвлений.
	var newest_prob := 1.0
	if _maze_phase == 2:
		newest_prob = 0.6
	var visited := {}
	var active: Array[Vector2i] = []
	var start := Vector2i(0, 0)
	visited[start] = true
	grid[1][1] = false
	active.append(start)

	while not active.is_empty():
		var idx: int = active.size() - 1 if randf() < newest_prob else randi() % active.size()
		var c: Vector2i = active[idx]
		var neighbors := _unvisited_neighbors(c, visited)
		if neighbors.is_empty():
			active.remove_at(idx)
		else:
			var n: Vector2i = neighbors[randi() % neighbors.size()]
			visited[n] = true
			grid[n.y * 2 + 1][n.x * 2 + 1] = false
			grid[c.y + n.y + 1][c.x + n.x + 1] = false
			active.append(n)

	# Широкая фаза ритма: «заплетаем» лабиринт — сносим часть внутренних стен
	# между соседними проходами. Появляются петли и открытые «залы»: другой вид
	# страха («вышел в пустоту»), враги разгоняются на прямых.
	if _maze_phase == 2:
		for cy in _rows:
			for cx in _cols:
				# стена справа и стена снизу от клетки (cx,cy)
				if cx + 1 < _cols and randf() < 0.14:
					grid[cy * 2 + 1][cx * 2 + 2] = false
				if cy + 1 < _rows and randf() < 0.14:
					grid[cy * 2 + 2][cx * 2 + 1] = false

	return grid

func _unvisited_neighbors(c: Vector2i, visited: Dictionary) -> Array[Vector2i]:
	var res: Array[Vector2i] = []
	for d in [Vector2i(1, 0), Vector2i(-1, 0), Vector2i(0, 1), Vector2i(0, -1)]:
		var n: Vector2i = c + d
		if n.x >= 0 and n.x < _cols and n.y >= 0 and n.y < _rows and not visited.has(n):
			res.append(n)
	return res

# «Двойной овал» (§1/§25, OVAL_LEVELS/уровень 50) — growing-tree, но
# ОГРАНИЧЕННОЕ клетками кольца между двумя эллипсами (не всей прямоугольной
# сеткой). Кольцо узкое, поэтому путь от входа до выхода почти всегда идёт
# «почти по всему кругу» — коротких срезок через центр физически нет (центр
# вообще не входит в кольцо, там сплошные стены). Возвращает и саму сетку,
# и клетки входа/выхода (противоположные концы кольца).
func _make_oval_grid(cols: int, rows: int) -> Dictionary:
	var gw := cols * 2 + 1
	var gh := rows * 2 + 1
	var grid: Array = []
	grid.resize(gh)
	for y in gh:
		var row := []
		row.resize(gw)
		for x in gw:
			row[x] = true
		grid[y] = row

	var cx0: float = (cols - 1) * 0.5
	var cy0: float = (rows - 1) * 0.5
	var rx_outer: float = maxf(2.0, cx0 * 0.92)
	var ry_outer: float = maxf(2.0, cy0 * 0.92)
	var rx_inner: float = rx_outer * 0.55
	var ry_inner: float = ry_outer * 0.55

	var ring_cells: Array[Vector2i] = []
	var ring_set: Dictionary = {}
	for cy in rows:
		for cx in cols:
			var dxo: float = (float(cx) - cx0) / rx_outer
			var dyo: float = (float(cy) - cy0) / ry_outer
			if dxo * dxo + dyo * dyo > 1.0:
				continue
			var dxi: float = (float(cx) - cx0) / maxf(0.01, rx_inner)
			var dyi: float = (float(cy) - cy0) / maxf(0.01, ry_inner)
			if dxi * dxi + dyi * dyi < 1.0:
				continue
			var c := Vector2i(cx, cy)
			ring_cells.append(c)
			ring_set[c] = true

	if ring_cells.is_empty():
		# Слишком маленькая сетка для кольца — откатываемся на обычное дерево.
		return {"grid": _make_grid(), "entry": Vector2i(0, 0), "exit": Vector2i(cols - 1, rows - 1)}

	# Случайная точка кольца — иначе вход/выход всегда оказывались бы в одном
	# и том же месте (ring_cells[0] всегда первая клетка в порядке сканирования
	# сетки, а не что-то зависящее от randi/randf).
	var start: Vector2i = ring_cells[randi() % ring_cells.size()]
	var visited: Dictionary = {start: true}
	var active: Array[Vector2i] = [start]
	grid[start.y * 2 + 1][start.x * 2 + 1] = false

	while not active.is_empty():
		var idx: int = active.size() - 1
		var c: Vector2i = active[idx]
		var neighbors: Array[Vector2i] = []
		for d in [Vector2i(1, 0), Vector2i(-1, 0), Vector2i(0, 1), Vector2i(0, -1)]:
			var n: Vector2i = c + d
			if ring_set.has(n) and not visited.has(n):
				neighbors.append(n)
		if neighbors.is_empty():
			active.remove_at(idx)
		else:
			var n: Vector2i = neighbors[randi() % neighbors.size()]
			visited[n] = true
			grid[n.y * 2 + 1][n.x * 2 + 1] = false
			grid[c.y + n.y + 1][c.x + n.x + 1] = false
			active.append(n)

	# Выход — самая дальняя (по числу шагов от входа) достигнутая клетка
	# кольца: почти всегда «на другой стороне круга».
	var best: Vector2i = start
	var best_d := -1
	for c in ring_cells:
		if not visited.has(c):
			continue
		var d: int = absi(c.x - start.x) + absi(c.y - start.y)
		if d > best_d:
			best_d = d
			best = c
	return {"grid": grid, "entry": start, "exit": best}

# --- Построение мира ---

func _build_world() -> void:
	_dark = CanvasModulate.new()
	_dark.color = _ambient
	add_child(_dark)

	# Bloom: мягкий неоновый ореол вокруг ярких граней, кристаллов и света игрока.
	var env := Environment.new()
	env.background_mode = Environment.BG_CANVAS
	env.glow_enabled = true
	env.glow_intensity = 1.15
	env.glow_strength = 1.2
	env.glow_bloom = 0.32
	env.glow_blend_mode = Environment.GLOW_BLEND_MODE_ADDITIVE
	env.glow_hdr_threshold = 0.62
	env.glow_hdr_scale = 2.2
	for i in 7:
		env.set_glow_level(i, 1.0 if i >= 1 and i <= 3 else 0.0)
	var we := WorldEnvironment.new()
	we.environment = env
	add_child(we)

	# Босс-этаж: каждые BOSS_EVERY_N уровней в режиме Накал, или принудительно при тест-флаге.
	# Логово (свой центральный тронный зал) исключает оба этих случая.
	_boss_level = not GameConfig.lair_mode and (
		(_level > 0 and _level % BOSS_EVERY_N == 0 and GameConfig.active_run >= 0)
		or GameConfig.boss_test_enabled)
	if _boss_level:
		_floors = 1
		_cols = BOSS_ARENA_COLS
		_rows = BOSS_ARENA_ROWS
		_gw = _cols * 2 + 1
		_gh = _rows * 2 + 1
		_floor_gap = (_gh + 2) * TILE
		# [SPAWN-SAFETY 2026-07-29] Тот же баг, что уже чинили для арены
		# супербосса (GAMEDESIGN §27, баг 1): на мега-лабиринте (уровни 30+)
		# _entry_cell выбирается СЛУЧАЙНО по всему полю (до 60×48) задолго до
		# этой подмены размеров на арену 12×10 — и остаётся указывать наружу.
		# Игрок появлялся в пустоте: ни стен, ни станций, экран просто чёрный
		# (жалоба «открыл 49 уровень — темнота», тест-флаг боссов был включён).
		# Угол (1,1) свободен: рамка идёт по краю, ближайший пилон — в (3,2).
		_entry_cell = Vector2i(1, 1)

	# Супербосс (§25): финал кампании «Уровни» (MAX_LEVEL), только там — не в
	# Накале/Спуске дня/Логове/обучении. Раньше был только тестовый вызов
	# spawn_superboss_test() — теперь это уровень 50 по-настоящему.
	_superboss_level = (_level == MAX_LEVEL and GameConfig.active_run < 0
		and not GameConfig.tutorial_mode and not GameConfig.lair_mode)
	# Деформация формы (обсуждалось 26.07.2026, до решения сделать ур.50
	# супербоссом): двойной овал — вместо обычного дерева проходов кольцевой
	# коридор почти по всему кругу до выхода. Примирено с супербоссом так:
	# 48-49 — целиком овальные уровни (single-floor, как и другие особые
	# уровни); 50 — овал на этаже 0 (крупнее, чем 49), а в конце кольца —
	# единственная дверь на отдельный этаж 1 с самой ареной супербосса.
	_oval_level = _level in OVAL_LEVELS and GameConfig.active_run < 0 \
		and not GameConfig.tutorial_mode and not GameConfig.lair_mode and not _boss_level
	if _oval_level:
		_floors = 1
	if _superboss_level:
		_boss_level = false
		_floors = 2
		_cols = SUPERBOSS_OVAL_COLS
		_rows = SUPERBOSS_OVAL_ROWS
		_gw = _cols * 2 + 1
		_gh = _rows * 2 + 1
		_floor_gap = (_gh + 2) * TILE
		# _entry_cell переопределится после генерации овального этажа 0 ниже
		# (см. цикл построения сетки) — овал сам решает, где его «вход».

	_wall_tex_cache.clear()
	_side_cells.clear()
	_side_pool.clear()          # спрайты пула умирают вместе с контейнерами этажей
	_side_pool_parent = null
	# [TILEMAP-1.8] Новый TileSet на уровень (цвет стен/размеры не переживают
	# смену уровня — проще пересоздать, чем вычищать источники старого).
	_wall_tileset = TileSet.new()
	_wall_tileset.tile_size = Vector2i(int(TILE), int(TILE))
	_wall_tileset.add_physics_layer()
	_wall_tileset.add_occlusion_layer()
	_wall_tile_source_id.clear()
	_wall_invisible_source_id = -1
	_floor_tilemaps.clear()
	_grids.clear()
	_floor_built.clear()

	# [§62, v.4.2] Пещеры: первая версия настоящих кротовых нор — граф
	# комнат-узлов (CaveGraph) вместо growing-tree сетки, см. GAMEDESIGN.md
	# §62. Полностью отдельная ветка, не общий код с сеточными режимами
	# ниже — нулевой риск для Уровней/Накала/Логова/арен/оврала: они
	# продолжают идти через клеточный путь без единой правки.
	if GameConfig.caves_mode:
		_build_cave_floor_graph()
		return

	for f in _floors:
		var grid: Array
		var is_oval_floor := false
		if _superboss_level and f == 0:
			# Этаж 0 финала — овал (крупнее 48/49), с его дальнего конца дверь
			# ведёт на этаж 1 (см. _place_superboss_door).
			var oval: Dictionary = _make_oval_grid(_cols, _rows)
			grid = oval["grid"]
			_oval_entry = oval["entry"]
			_oval_exit = oval["exit"]
			_entry_cell = _oval_entry
			is_oval_floor = true
		elif _superboss_level and f == 1:
			# Этаж 1 финала — сама арена супербосса, размер которой меньше, чем
			# у овального этажа 0 (тот же приём паддинга, что и у обычной
			# дверь-боссовской арены в _setup_boss_door: BFS/маски стен требуют
			# единый формат координат для всех этажей уровня).
			var ares: Array = _make_superboss_arena_grid(SUPERBOSS_ARENA_COLS, SUPERBOSS_ARENA_ROWS)
			grid = ares[0]
			_strong_cells[f] = ares[1]
			while grid.size() < _gh:
				var prow := []
				prow.resize(_gw)
				for x in _gw:
					prow[x] = true
				grid.append(prow)
			for y in grid.size():
				while (grid[y] as Array).size() < _gw:
					(grid[y] as Array).append(true)
		elif _boss_level:
			grid = _make_arena_grid()
		elif f == 0 and _oval_level:
			var oval2: Dictionary = _make_oval_grid(_cols, _rows)
			grid = oval2["grid"]
			_oval_entry = oval2["entry"]
			_oval_exit = oval2["exit"]
			_entry_cell = _oval_entry
			is_oval_floor = true
		else:
			grid = _make_grid()
		if _lair_active:
			_carve_boss_room(grid)
		# [GAMEDESIGN §17] Структурное разнообразие внутри уровня — не трогает
		# арену босса/Логово/супербосса (у них своя расчистка), обучение
		# (лабиринт и так маленький и должен быть предсказуемым для первого шага)
		# и овальные этажи (§1 — доп. карвинг сломал бы «почти по всему кругу»,
		# открыв срезки через кольцо).
		if not _boss_level and not _lair_active and not _superboss_level and not GameConfig.tutorial_mode and not _organic and not is_oval_floor:
			if _cols >= 10 and _rows >= 8:
				_carve_rooms(grid)
			_carve_zonal_density(grid)
			# [GAMEDESIGN §17.2] Биом-зависимая топология — поверх дерева-основы
			# (гарантия проходимости не портится, эти проходы только ДОБАВЛЯЮТ
			# связи, а не убирают их).
			_apply_biome_topology(grid)
			# [§40] Скелет режем ПОСЛЕДНИМ: zonal density и топология биома
			# правят стены, и артерия, вырезанная до них, местами заросла бы.
			_carve_spine(f, grid)
			# §5: только этаж входа, не хард-режим (там и так изменена экономика
			# света — лишний риск/сюрприз ни к чему) — после zonal density,
			# чтобы та не «съела» уже вырезанную комнату.
			if f == 0 and not _hard:
				_event_room_cell = _carve_event_room(grid)
				if _event_room_cell.x >= 0:
					# [GAMEDESIGN §26] Тип комнаты — по весам биома, а не ровной
					# лотереей из пяти: тема полосы уровней должна звучать и здесь.
					var room_base := {}
					for k in EVENT_ROOM_KINDS:
						room_base[k] = 1.0
					_event_room_kind = _weighted_pick(_apply_biome_weights(room_base, "rooms"))
		_grids.append(grid)
	# ВАЖНО: арену супербосса НЕЛЬЗЯ помечать _floor_is_arena — этот флаг
	# отключает и станции, и осколки разом (так сделано для арены дверь-босса).
	# По §25 станции зарядки на арене супербосса нужны (жалоба «не смог найти
	# станций зарядки»): бой длинный, а осколков тут нет. Осколки же наоборот
	# не нужны — они открывают портал-выход, которого на этом уровне нет
	# (победа = смерть босса). Разделение — в _spawn_floor_pickups.
	# Стены/станции/осколки строятся только для этажа входа сразу — остальные
	# этажи мега-лабиринта (до 6 этажей × 60×60 клеток) откладываются до первого
	# фактического спуска через дверь (ensure_floor_built), иначе уровень 30+
	# создаёт под сотню тысяч нод разом — и постройка, и выход в меню (freeing
	# всего этого дерева) занимают многие секунды. Данные сетки (_grids) для
	# путей/выхода/BFS считаются заранее и не требуют построенных нод.
	_validate_entry_cell()
	_ensure_floor_built(0)
	_spawn_time_echoes()

	if _boss_level:
		_spawn_player()
		_spawn_boss(0)
	elif _superboss_level:
		_spawn_player()
		# §1/§25: победа = смерть босса на этаже 1, как раньше — просто теперь
		# перед ней есть овальный этаж 0 (см. _place_superboss_door). Центр
		# арены на этаже 1 — условная цель для Искры/минимапы/BFS-путей.
		_place_superboss_door()
		_exit_cell = Vector2i(SUPERBOSS_ARENA_COLS / 2, SUPERBOSS_ARENA_ROWS / 2)
		_exit_floor = 1
		_compute_optimal_path_len()
		flash_message(GameConfig.tt(
			"☠ Кольцевой путь к финалу — иди по кольцу почти до конца, там дверь к стражу лабиринта",
			"☠ A ring path to the finale — follow the loop nearly all the way around, a door to the maze's guardian waits at the end"))
	elif _lair_active:
		_spawn_player()
		# Тронный зал — геометрический центр лабиринта; Искра/Озарение/минимап
		# нацеливаются на него так же, как на обычный выход (тот же _exit_cell).
		_exit_cell = Vector2i(_cols / 2, _rows / 2)
		_exit_floor = 0
		_compute_optimal_path_len()
		_spawn_boss(0)
		_lair_populate_enemies()
	else:
		_place_doors()
		_place_exit()
		_spawn_player()
		if _level % 5 == 0 and _level >= 5 and not GameConfig.tutorial_mode and not GameConfig.lair_mode and not GameConfig.caves_mode:
			_setup_boss_door()
		_compute_optimal_path_len()
		if GameConfig.darkness_chaser and _level >= 4:
			_spawn_enemies()
		# §5: контент событийной комнаты кладём ЗДЕСЬ, не сразу после
		# _ensure_floor_built(0) — _exit_cell/_exit_floor ещё не установлены
		# до _place_exit() (тот же класс проблемы с «протухшими» координатами,
		# что и с _entry_cell/_exit_cell в других местах, см. CLAUDE.md).
		_populate_event_room()

# [§62, v.4.2] Пещеры (первая версия графового режима) — вызывается ВМЕСТО
# клеточного пути в _build_world(), не вместе с ним. Строит один этаж
# (Пещеры всегда single-floor) по CaveGraph: реальная физика/occlusion/
# рендер атомарно через CaveFloorBuild (шаг 5, части 1-3), вход/выход через
# CaveGraph.pick_entry_exit (шаг 5, часть 2), станции/осколки на узлах
# графа через CaveGraph.spawnable_nodes (шаг 4, часть 4).
#
# Что НАМЕРЕННО отложено (решено один раз, не забыто — см. GAMEDESIGN.md
# §62): двери (Пещеры и так один этаж — не нужны), Метка/Соглядатай/Очаг
# (спавнят по клетке приближённой сетки-заглушки, небезопасно — см.
# _update_watchers/_update_hearths), землетрясение/сдвиг лабиринта
# (мутируют TileMap, которого у графового этажа нет вообще). Враги/мимики/
# тёмные станции/ямы/срезки УЖЕ подключены (см. _spawn_cave_enemies/
# _spawn_cave_pickups/_spawn_cave_hazards). События relief/leak/flicker
# (чисто игроко-локальные, без обращения к сетке) — тоже включены,
# см. ветвление в _roll_event_kind().
#
# `_grids[0]` заполняется ПОЛНОСТЬЮ ОТКРЫТОЙ сеткой-заглушкой той же формы
# (`_gw`×`_gh`), что и у клеточных уровней — не для коллизии (та настоящая,
# через CaveFloorBuild), а только чтобы общий код, трогающий `_grids[f]`
# без ветвления на caves_mode (минимап, `_compute_optimal_path_len`,
# `_validate_entry_cell`), не падал по индексу. Точность миникарты/% пути
# на графовых Пещерах поэтому ниже, чем на клеточных уровнях — известное
# ограничение первой версии, не баг.
func _build_cave_floor_graph() -> void:
	_caves_graph_active = true
	var level_size := Vector2(float(_cols) * TILE * 1.7, float(_rows) * TILE * 1.7)
	var node_count: int = clampi(int(float(_cols * _rows) / 9.0), 8, 160)
	# [BUGFIX 01.08.2026, §62] Расширено с TILE*0.95 — на резких неровных
	# поворотах у игрока (радиус 14) было мало запаса, из-за чего он
	# застревал при диагональном вводе (см. заметку у CaveGraph.edge_polyline
	# про причину — скольжение вдоль стен в player.gd рассчитано на прямые
	# углы). Более широкий тоннель прощает угол поворота, даже когда сама
	# ломаная всё ещё неровная (см. правку amplitude/mid_count там же).
	var branch_width: float = TILE * 1.2
	var rng := RandomNumberGenerator.new()
	rng.seed = randi()   # наследует seed()-детерминизм Спуска дня, выставленный выше в _build_world

	# [BUGFIX 01.08.2026, §62] CaveGraph.generate сэмплирует узлы РАВНОМЕРНО
	# по всему [0,size] прямоугольнику, включая сам край, — не глядя на
	# border_margin/рамку коллизии ниже. Живой харнесс поймал ровно это:
	# случайный вход оказался с координатой, СОВПАДАЮЩЕЙ с level_size.y
	# (буквально на границе уровня) — игрок заспавнился внутри защитной
	# рамки. Резервируем отступ ЗДЕСЬ, генерируя граф в урезанном
	# прямоугольнике и сдвигая все узлы/ломаные внутрь на edge_margin —
	# ни один узел физически не может оказаться ближе edge_margin к краю.
	var edge_margin: float = TILE * 2.0
	var gen_size := Vector2(maxf(200.0, level_size.x - edge_margin * 2.0), maxf(200.0, level_size.y - edge_margin * 2.0))
	var offset := Vector2(edge_margin, edge_margin)
	var nodes: Array = []
	var polylines: Array = []
	# [BUGFIX 01.08.2026, §62] Даже с запасом между радиусами узлов
	# (CaveGraph.generate) извилистые рёбра иногда проходят достаточно
	# близко к чужому несвязанному узлу/ребру, чтобы физически соприкоснуться
	# в растровой маске — между формально несвязанными частями графа тогда
	# нет стены вообще (баг «игрок проходит сквозь стены», репродуцирован
	# живой игрой). Полная гарантия на этапе генерации была бы геометрической
	# маршрутизацией с учётом препятствий — вместо этого перегенерируем с
	# новым сидом до CAVE_GEN_MAX_ATTEMPTS раз, если утечка обнаружена
	# постфактум (CaveCollision.has_leak). На проверенных сериях сидов
	# несколько попыток почти всегда достаточно.
	const CAVE_GEN_MAX_ATTEMPTS := 6
	# [BUGFIX 02.08.2026, §62] Станция/тёмная станция/мимик ставятся на узел
	# графа с CircleShape2D радиусом 40 (station.gd/dark_station.gd/mimic.gd).
	# Старый room_radius_min = TILE*0.75 = 36 иногда давал узлы МЕНЬШЕ этого
	# радиуса — пикап физически торчал своим кругом за пределы проходимой
	# комнаты, прямо в стену (репродуцировано харнессом cave_station_bug_hunt,
	# см. GAMEDESIGN.md §62: L1 попытка 0, узел радиусом 36.01 против пикапа
	# 40 — выступ ~4 юнита). Минимум поднят так, чтобы ЛЮБОЙ узел графа был
	# больше самого крупного пикапа с запасом.
	const CAVE_ROOM_RADIUS_MIN := TILE * 0.95   # 45.6, > 40 (макс. радиус пикапа)
	for attempt in CAVE_GEN_MAX_ATTEMPTS:
		_cave_graph = CaveGraph.generate(gen_size, node_count, branch_width * 1.6, 0.15, CAVE_ROOM_RADIUS_MIN, TILE * 1.35, rng)
		nodes = _cave_graph["nodes"]
		for i in nodes.size():
			nodes[i] = nodes[i] + offset
		polylines = _cave_graph["polylines"]
		for pi in polylines.size():
			var pts: PackedVector2Array = polylines[pi]
			for i in pts.size():
				pts[i] = pts[i] + offset
			polylines[pi] = pts
		# Явная перезапись — не полагаемся на то, что Array-значение внутри
		# Dictionary всегда мутируется "через" локальную переменную-ссылку.
		_cave_graph["nodes"] = nodes
		_cave_graph["polylines"] = polylines
		if not CaveCollision.has_leak(_cave_graph, level_size, 12.0, branch_width, TILE * 0.4):
			break
		rng.seed = randi()

	var edges: Array = _cave_graph["edges"]
	var pick := CaveGraph.pick_entry_exit(nodes, edges, rng)
	var entry_node: int = pick["entry"]
	var exit_node: int = pick["exit"]
	_cave_entry_node = entry_node
	_cave_exit_node = exit_node

	var dummy_grid: Array = []
	dummy_grid.resize(_gh)
	for y in _gh:
		var row := []
		row.resize(_gw)
		for x in _gw:
			row[x] = false
		dummy_grid[y] = row
	_grids.append(dummy_grid)

	var container := Node2D.new()
	container.name = "CaveFloor0"
	add_child(container)
	# [BUGFIX 01.08.2026, §62] border_margin в маске — лёгкий запас (не
	# основная защита от побега за карту, для этого есть отдельная жёсткая
	# рамка в CaveFloorBuild._add_boundary_frame). Держим МАЛЕНЬКИМ намеренно:
	# первая версия использовала TILE*1.5=72 — этого хватало, чтобы съесть
	# ЦЕЛУЮ комнату у края, если туда случайно попадал вход/выход (проверено
	# живым харнессом: игрок заспавнился прямо в стене). Margin должен только
	# закрывать щели контура у самого края маски, не откусывать игровое
	# пространство.
	CaveFloorBuild.build(container, _cave_graph, level_size, 12.0, branch_width, TILE, _wall_color, TILE * 0.4)
	_floor_containers.resize(maxi(_floor_containers.size(), 1))
	_floor_containers[0] = container
	_floor_built[0] = true

	var entry_pos: Vector2 = nodes[entry_node]
	var exit_pos: Vector2 = nodes[exit_node]
	# Приближённые клетки заглушки-сетки — нужны только для generic-кода
	# (минимап/Искра/оптимальный путь), реальную позицию игрока/выхода ниже
	# выставляем напрямую из графа, не через эти клетки.
	_entry_cell = _world_to_cell(entry_pos, 0)
	_exit_cell = _world_to_cell(exit_pos, 0)
	_exit_floor = 0

	_spawn_player()
	_player.position = entry_pos
	_start_exit_dist = maxf(1.0, entry_pos.distance_to(exit_pos))

	var exit := Area2D.new()
	exit.set_script(load("res://exit.gd"))
	exit.game = self
	exit.position = exit_pos
	add_child(exit)
	_exit_node = exit
	_refresh_exit_lock()

	_spawn_cave_pickups(nodes, entry_node, container)
	_spawn_cave_hazards(nodes, edges, entry_node, exit_node, container)
	if GameConfig.darkness_chaser and _level >= 4:
		_spawn_cave_enemies(nodes, edges, entry_node)

	_compute_optimal_path_len()
	# [§62, v.4.2] _events_enabled НЕ трогаем (остаётся тем, что уже задал
	# общий код выше в _build_world) — _roll_event_kind() сама исключает
	# quake/shift/fog для графовых Пещер (см. ветвление там), общий
	# рубильник больше не нужен.

# [§62, v.4.2] Станции/осколки/тёмные станции/мимики на узлах графа —
# графовый аналог _spawn_floor_pickups (тот же принцип: станции первыми,
# тёмные станции/мимики на СЛЕДУЮЩИХ узлах — аналог station_cells[used..]
# в клеточной версии, осколки на оставшихся). Гейтинг — та же таблица
# правил биома, что и в клеточной версии (_mech_ready + _biome_chance +
# _biome_cycle): Пещеры используют её и сейчас (см. _apply_biome — имя/цвет
# переопределены, но сама таблица биомов кампании — нет), так что новых
# *_CHANCE-констант заводить не нужно (см. CLAUDE.md).
func _spawn_cave_pickups(nodes: Array, entry_node: int, container: Node2D) -> void:
	var spawnable: Array = CaveGraph.spawnable_nodes(nodes, entry_node)
	spawnable.shuffle()

	var station_target: int = clampi(int(float(nodes.size()) * 0.22), GameConfig.station_count, MAX_CAVES_STATIONS)
	var station_n: int = mini(station_target, spawnable.size())
	var used := {}
	for i in station_n:
		var idx: int = spawnable[i]
		used[idx] = true
		var st := Area2D.new()
		st.set_script(load("res://station.gd"))
		st.game = self
		st.floor_index = 0
		st.position = nodes[idx]
		container.add_child(st)

	var cave_gate: bool = not (_boss_level or _lair_active or _superboss_level or GameConfig.tutorial_mode or _hard)
	var extra_cursor: int = station_n
	if cave_gate and _mech_ready("dark_stations") and randf() <= _biome_chance("dark_stations"):
		var n: int = mini(1 + _biome_cycle(), 3)
		var count: int = mini(n, spawnable.size() - extra_cursor)
		for i in count:
			var idx: int = spawnable[extra_cursor + i]
			used[idx] = true
			var ds := Area2D.new()
			ds.set_script(load("res://dark_station.gd"))
			ds.game = self
			ds.floor_index = 0
			ds.position = nodes[idx]
			container.add_child(ds)
		extra_cursor += count

	if cave_gate and _mech_ready("mimics") and randf() <= _biome_chance("mimics"):
		var n: int = mini(1 + _biome_cycle(), 2)
		var count: int = mini(n, spawnable.size() - extra_cursor)
		for i in count:
			var idx: int = spawnable[extra_cursor + i]
			used[idx] = true
			var m := Area2D.new()
			m.set_script(load("res://mimic.gd"))
			m.game = self
			m.floor_index = 0
			m.is_graph_mode = true
			m.position = nodes[idx]
			container.add_child(m)
		extra_cursor += count

	var shard_candidates: Array = []
	for idx in spawnable:
		if not used.has(idx):
			shard_candidates.append(idx)
	if shard_candidates.is_empty():
		shard_candidates = spawnable   # запасной путь: лучше рядом со станцией, чем нигде
	var sc: int = mini(SHARDS_PER_FLOOR, shard_candidates.size())
	for i in sc:
		var sh := Area2D.new()
		sh.set_script(load("res://shard.gd"))
		sh.game = self
		sh.position = nodes[shard_candidates[i]]
		container.add_child(sh)
		_shards_total += 1
	_shards_remaining.resize(1)
	_shards_remaining[0] = sc

# [§62, v.4.2] Ямы и срезки на графе. Оба — просто Area2D/StaticBody2D на
# позиции узла (как в клеточной версии), никакой перекраски стен не делают
# (в отличие от Метки/Соглядатая/Очага, которые остаются выключены — см.
# _update_watchers/_update_hearths). Тот же гейтинг через таблицу правил
# биома, что и у станций/мимиков выше.
const SHORTCUT_MIN_DIST_WORLD := TILE * 16.0   # графовый аналог SHORTCUT_MIN_DIST_CELLS (8 клеток) — минимальная dijkstra-дистанция для пары порталов

func _spawn_cave_hazards(nodes: Array, edges: Array, entry_node: int, exit_node: int, container: Node2D) -> void:
	var cave_gate: bool = not (_boss_level or _lair_active or _superboss_level or GameConfig.tutorial_mode)

	# Ямы (§17.5) — не гейтятся _hard (преграда, не расход света).
	if cave_gate and _mech_ready("pits") and randf() <= _biome_chance("pits"):
		var want: int = mini(1 + _biome_cycle(), 3)
		var candidates: Array = CaveGraph.spawnable_nodes(nodes, entry_node)
		candidates.shuffle()
		var placed_pos: Array[Vector2] = []
		var placed := 0
		for idx in candidates:
			if idx == exit_node:
				continue
			var pos: Vector2 = nodes[idx]
			var too_close := false
			for p in placed_pos:
				if p.distance_to(pos) < TILE * 8.0:
					too_close = true
					break
			if too_close:
				continue
			var pit := StaticBody2D.new()
			pit.set_script(load("res://pit.gd"))
			pit.game = self
			pit.floor_index = 0
			pit.position = pos
			container.add_child(pit)
			placed_pos.append(pos)
			placed += 1
			if placed >= want:
				break

	# Срезки (§17.4) — пара узлов, достаточно далёких по КРАТЧАЙШЕМУ ПУТИ
	# графа (не по прямой — иначе «срезка» ничего не срезала бы).
	if cave_gate and _mech_ready("shortcut") and randf() <= _biome_chance("shortcut"):
		var want_pairs: int = mini(1 + _biome_cycle() / 2, 2)
		var used_nodes := {}
		for _pair in want_pairs:
			var cand: Array = []
			for idx in CaveGraph.spawnable_nodes(nodes, entry_node):
				if not used_nodes.has(idx):
					cand.append(idx)
			cand.shuffle()
			if cand.is_empty():
				break
			var a: int = cand[0]
			var result := CaveGraph.dijkstra(nodes, edges, a)
			var dist: Array = result["dist"]
			var far: Array = []
			for idx in cand:
				if idx != a and dist[idx] != INF and dist[idx] >= SHORTCUT_MIN_DIST_WORLD:
					far.append(idx)
			if far.is_empty():
				break
			var b: int = far[randi() % far.size()]
			used_nodes[a] = true
			used_nodes[b] = true
			var pa := Area2D.new()
			pa.set_script(load("res://shortcut_portal.gd"))
			pa.game = self
			pa.floor_index = 0
			pa.position = nodes[a]
			container.add_child(pa)
			var pb := Area2D.new()
			pb.set_script(load("res://shortcut_portal.gd"))
			pb.game = self
			pb.floor_index = 0
			pb.position = nodes[b]
			container.add_child(pb)
			pa.partner = pb
			pb.partner = pa

# [§62, v.4.2] Враги на графовых Пещерах — та же прогрессия числа/типов, что
# и у _spawn_enemies() (шаг 4 через уровень, чередуя SLOW/FAST/CYCLIC), но
# БЕЗ элиты/загонщика/Соглядатая — они опираются на _flood_size/_herd_cut_cell
# (клеточный разлив), который на графе не осмыслен, и ни разу не проверялись
# на графовой модели (см. общую заметку у _build_cave_floor_graph). Позиции —
# узлы графа подальше от входа (аналог _far_spawn_cells через dijkstra).
func _spawn_cave_enemies(nodes: Array, edges: Array, entry_node: int) -> void:
	var counts := [0, 0, 0]
	var step := 4
	while step <= _level:
		var idx: int = int((step - 4) / 4) % 3
		counts[idx] += 1
		step += 4
	var types: Array = []
	for _i in mini(counts[0], 6): types.append(0)
	for _i in mini(counts[1], 6): types.append(1)
	for _i in mini(counts[2], 6): types.append(2)
	if types.is_empty():
		return
	types.shuffle()

	var result := CaveGraph.dijkstra(nodes, edges, entry_node)
	var dist: Array = result["dist"]
	var far_nodes: Array = []
	var max_d := 0.0
	for d in dist:
		if d != INF:
			max_d = maxf(max_d, d)
	for i in nodes.size():
		if i != entry_node and dist[i] != INF and dist[i] > max_d * 0.4:
			far_nodes.append(i)
	if far_nodes.is_empty():
		far_nodes = CaveGraph.spawnable_nodes(nodes, entry_node)
	far_nodes.shuffle()

	for i in types.size():
		if far_nodes.is_empty():
			break
		var node_idx: int = far_nodes[i % far_nodes.size()]
		var pur := Node2D.new()
		pur.set_script(load("res://pursuer.gd"))
		pur.enemy_type = int(types[i])
		pur.spawn_level = _level
		pur._enemy_floor = 0
		pur.position = nodes[node_idx]
		pur.target = _player
		pur._game = self
		pur.process_mode = Node.PROCESS_MODE_PAUSABLE
		add_child(pur)

# Тронный зал: расчищаем прямоугольную комнату в центре лабиринта — и стены
# между клетками, и «пеньки»-пилоны на пересечениях (тот же приём, что и
# землетрясение в _do_quake, только по всей площади комнаты сразу).
func _carve_boss_room(grid: Array) -> void:
	var cx: int = _cols / 2
	var cy: int = _rows / 2
	var radius: int = 1 if _level <= 4 else 2
	var gx0: int = maxi(1, (cx - radius) * 2)
	var gx1: int = mini(_gw - 2, (cx + radius) * 2 + 2)
	var gy0: int = maxi(1, (cy - radius) * 2)
	var gy1: int = mini(_gh - 2, (cy + radius) * 2 + 2)
	for gy in range(gy0, gy1 + 1):
		for gx in range(gx0, gx1 + 1):
			grid[gy][gx] = false

# [GAMEDESIGN §17.1] Комнаты-вставки: 1-2 случайных прямоугольных «зала»
# (2x2..3x3 клетки) поверх свежесрезанного дерева — тот же приём, что и
# тронный зал Логова (_carve_boss_room), просто в случайном месте и поменьше.
# Только СНОСИТ стены, поэтому связность (дерево уже было проходимо целиком)
# не портится — комнаты не могут отрезать часть лабиринта.
# ══ §40 «ПОЗВОНОЧНИК ЭТАЖА» (план 2.x, пункт П1) ════════════════════════════
# §39 сделал выход тем, что надо ИСКАТЬ. Но искать можно только там, где о
# пространстве можно построить ГИПОТЕЗУ. Равномерный случайный карв гипотез не
# допускает: все коридоры одинаковы, ни одного места нельзя запомнить, поэтому
# улика «выход в северо-восточной части» оставалась числом, а не догадкой —
# сузить круг она сужала, а идти всё равно приходилось наугад.
#
# Даём этажу читаемый скелет:
#   • АРТЕРИЯ — сквозной прямой коридор вдоль длинной стороны. Магистраль: по
#     ней быстро попадаешь в любую часть этажа и по ней же понимаешь, где ты.
#   • ЗАЛЫ-ОРИЕНТИРЫ — 2-3 открытые площадки 3×3 на артерии, у каждой свой
#     цвет и СТОЛП СВЕТА, который пробивается сквозь виньетку тьмы
#     (darkness.gdshader: max_dark 0.93 < 1.0 — щель для яркого света
#     оставлена намеренно). Ориентир видно издалека, и тьма впервые становится
#     проходимой по приметам, а не наощупь.
#
# Безопасность генерации: карвинг только ОТКРЫВАЕТ стены поверх уже связного
# дерева, поэтому связность и достижимость выхода не могут пострадать, а
# _entry_cell не трогается вовсе (см. предупреждение о спавне в CLAUDE.md).
const SPINE_HUB_MIN := 2
const SPINE_HUB_MAX := 3
const HUB_COLORS := [
	Color(0.35, 0.85, 1.00),   # лазурный
	Color(1.00, 0.55, 0.25),   # янтарный
	Color(0.75, 0.45, 1.00),   # аметистовый
]
# Скелет хранится ПО ЭТАЖАМ: карвинг всех этажей происходит сразу, а сами
# этажи строятся лениво (_ensure_floor_built), поэтому одна общая переменная
# к моменту расстановки меток держала бы геометрию последнего карвленного
# этажа — метки нижних этажей встали бы по чужой линии.
# [§43] Клетки, занятые объектами (станция, тёмная станция, мимик). Осколки и
# прочая мелочь обязаны их обходить: два предмета в одной клетке визуально
# сливаются в один и подбирается только верхний.
var _occupied_cells: Dictionary = {}   # Vector3i(f,cx,cy) -> true
var _spine_by_floor: Dictionary = {}   # f -> Array[Vector2i] клетки артерии
var _hub_by_floor: Dictionary = {}     # f -> Array[Vector2i] центры залов

func _carve_spine(f: int, grid: Array) -> void:
	# [§43] Скелет нужен там, где без него не сориентироваться. На маленьких
	# ранних этажах (примерно до 20×12) он не помогает, а СНОСИТ лабиринт:
	# сквозной коридор и залы 3×3 на сетке 16×10 — это уже не скелет, а
	# планировка комнат. Жалоба игрока «уровни 1-3 не похожи на лабиринт».
	if _cols < 20 or _rows < 12:
		return
	var horizontal: bool = _cols >= _rows
	var spine: Array = []
	if horizontal:
		# Линия не по центру ровно, а с разбросом: центральная магистраль на
		# каждом этаже читалась бы как разлиновка, а не как место.
		var cy: int = clampi(_rows / 2 + (randi() % 3 - 1), 1, _rows - 2)
		for cx in range(_cols - 1):
			grid[cy * 2 + 1][cx * 2 + 2] = false   # стена между (cx,cy) и (cx+1,cy)
		for cx in range(_cols):
			spine.append(Vector2i(cx, cy))
	else:
		var cx2: int = clampi(_cols / 2 + (randi() % 3 - 1), 1, _cols - 2)
		for cy in range(_rows - 1):
			grid[cy * 2 + 2][cx2 * 2 + 1] = false
		for cy in range(_rows):
			spine.append(Vector2i(cx2, cy))

	# Залы на артерии, равномерно по её длине, с отступом от краёв — зал у
	# самой кромки читается как тупик, а не как узел.
	var hubs: Array = []
	# [§43] Залов столько, сколько выдержит площадь: на 20×12 даже два зала
	# заметно разрежают этаж, на 60×48 три — редкие островки.
	var area: int = _cols * _rows
	var cap: int = SPINE_HUB_MIN if area < 700 else SPINE_HUB_MAX
	var n: int = SPINE_HUB_MIN + (randi() % maxi(cap - SPINE_HUB_MIN + 1, 1))
	for i in n:
		var t: float = float(i + 1) / float(n + 1)
		var c: Vector2i = spine[clampi(int(round(t * float(spine.size() - 1))), 2, spine.size() - 3)]
		if c.x < 1 or c.y < 1 or c.x > _cols - 2 or c.y > _rows - 2:
			continue
		for gy in range(maxi(1, c.y * 2 - 1), mini(_gh - 2, c.y * 2 + 3) + 1):
			for gx in range(maxi(1, c.x * 2 - 1), mini(_gw - 2, c.x * 2 + 3) + 1):
				grid[gy][gx] = false
		hubs.append(c)
	_spine_by_floor[f] = spine
	_hub_by_floor[f] = hubs

# [§40] Визуальная подпись скелета. Без неё карвинг остаётся невидимым: игрок
# идёт по широкому коридору и не понимает, что это магистраль.
func _spawn_structure_marks(f: int, container: Node2D) -> void:
	if _boss_level or _lair_active or _superboss_level or GameConfig.tutorial_mode or _organic:
		return
	# Артерия: редкая цепочка тусклых бликов по полу — «разметка дороги».
	# Каждая третья клетка, иначе на 60 клеток длины это 60 спрайтов ради
	# эффекта, который читается и с шагом 3.
	var spine: Array = _spine_by_floor.get(f, [])
	var hubs: Array = _hub_by_floor.get(f, [])
	for i in spine.size():
		if i % 3 != 0:
			continue
		var m := Sprite2D.new()
		m.texture = MazeTextures.make_light(34)
		m.modulate = Color(0.55, 0.85, 1.0, 0.22)
		m.position = _cell_to_world(spine[i])
		container.add_child(m)
	# Залы: столп света своего цвета. Яркость подобрана так, чтобы пробиваться
	# сквозь виньетку (max_dark 0.93) — ориентир должен быть виден ИЗДАЛЕКА,
	# иначе он не ориентир, а просто украшение под ногами.
	for i in hubs.size():
		var col: Color = HUB_COLORS[i % HUB_COLORS.size()]
		var pos: Vector2 = _cell_to_world(hubs[i])
		# Замер скриншот-харнессом показал: мягкое пятно на 0.30 альфы читается
		# с трёх клеток и пропадает с девяти — то есть ориентиром не работает.
		# Отсюда три слоя вместо одного и, главное, СИЛУЭТ: вертикальный столп
		# отличим от круглого ореола игрока и от всего прочего света в игре.
		var halo := Sprite2D.new()
		halo.texture = MazeTextures.make_light(280)
		halo.modulate = Color(col.r, col.g, col.b, 0.55)
		halo.position = pos
		container.add_child(halo)
		# [БАГ v2.1→v2.8, найден игроком по скриншоту] Масштаб (0.42, 3.4) на
		# текстуре 110px давал видимую высоту 374px — почти 8 клеток. Столп
		# простреливал стены на несколько тайлов вверх/вниз (зал 3×3 — это
		# всего ~144px), и получалась «дыра» в геометрии: свет как будто
		# протекал сквозь сплошную стену. Высота теперь заведомо меньше
		# открытой площадки зала, столп больше не выходит за её пределы.
		var pillar := Sprite2D.new()
		pillar.texture = MazeTextures.make_light(110)
		pillar.modulate = Color(col.r, col.g, col.b, 0.75)
		pillar.scale = Vector2(0.42, 0.85)         # вытянутый столп, но внутри зала
		pillar.position = pos
		container.add_child(pillar)
		var core := Sprite2D.new()
		core.texture = MazeTextures.make_light(72)
		core.modulate = Color(col.r, col.g, col.b, 1.0)
		core.position = pos
		container.add_child(core)
		var lt := PointLight2D.new()
		lt.texture = MazeTextures.make_light(420)
		lt.color = col
		lt.energy = 2.0
		lt.position = pos
		container.add_child(lt)

# [§43] Сколько комнат выдерживает этаж. Комната — это дыра в лабиринте:
# на большой площади она читается как зал, на маленькой съедает уровень.
# Замер, из-за которого функция появилась: открытость ур.1 была 0.71 при
# норме лабиринта ~0.50 (жалоба «это просто комнаты, а не лабиринт»).
func _room_budget() -> int:
	var area: int = _cols * _rows
	if area < 260:
		return 0     # ур.1-2: комнат нет вовсе, только лабиринт
	if area < 600:
		return 1
	if area < 1400:
		return 2
	return 3

# Потолок стороны комнаты — тоже от площади: 4×4 на сетке 20×13 это 12% этажа.
func _room_max_side() -> int:
	var area: int = _cols * _rows
	if area < 600:
		return 2
	if area < 1400:
		return 3
	return 4

func _carve_rooms(grid: Array) -> void:
	var budget: int = _room_budget()
	if budget <= 0:
		return
	var room_count: int = mini(1 + (1 if randf() < 0.5 else 0), budget)
	var side: int = _room_max_side()
	for _i in room_count:
		var rw: int = 2 + randi() % maxi(side - 1, 1)
		var rh: int = 2 + randi() % maxi(side - 1, 1)
		var cx0: int = randi() % maxi(1, _cols - rw)
		var cy0: int = randi() % maxi(1, _rows - rh)
		var gx0: int = maxi(1, cx0 * 2)
		var gx1: int = mini(_gw - 2, (cx0 + rw) * 2)
		var gy0: int = maxi(1, cy0 * 2)
		var gy1: int = mini(_gh - 2, (cy0 + rh) * 2)
		for gy in range(gy0, gy1 + 1):
			for gx in range(gx0, gx1 + 1):
				grid[gy][gx] = false

# §5: вырезает одну небольшую (3×3 клетки прохода) комнату для событийного
# наполнения (см. _populate_event_room) — тем же приёмом, что _carve_rooms,
# но возвращает координату центра, чтобы main.gd знал, куда класть контент.
# Не гарантирует место, если подходящей клетки не нашлось (Vector2i(-1,-1)).
func _carve_event_room(grid: Array) -> Vector2i:
	if not _mech_ready("event_rooms") or randf() > EVENT_ROOM_CHANCE:
		return Vector2i(-1, -1)
	var cells := _passage_cells(true, grid)
	cells.shuffle()
	for c in cells:
		if c.x < 2 or c.y < 2 or c.x > _cols - 3 or c.y > _rows - 3:
			continue   # нужен запас по краям для комнаты 3x3
		var gx0: int = c.x * 2 - 1
		var gx1: int = c.x * 2 + 3
		var gy0: int = c.y * 2 - 1
		var gy1: int = c.y * 2 + 3
		for gy in range(gy0, gy1 + 1):
			for gx in range(gx0, gx1 + 1):
				grid[gy][gx] = false
		return c
	return Vector2i(-1, -1)

# §5: наполняет вырезанную _carve_event_room комнату содержимым по типу
# (_event_room_kind). Вызывается ПОСЛЕ _place_exit() — «выбор» и «эхо» знают,
# где выход, только к этому моменту.
func _populate_event_room() -> void:
	if _event_room_cell.x < 0 or _floor_containers.is_empty():
		return
	var container: Node2D = _floor_containers[0]
	var center: Vector2 = _cell_to_world(_event_room_cell)
	match _event_room_kind:
		"shard_altar":
			var sh := Area2D.new()
			sh.set_script(load("res://shard.gd"))
			sh.game = self
			sh.position = center
			container.add_child(sh)
			_shards_total += 1
			if _shards_remaining.size() > 0:
				_shards_remaining[0] = int(_shards_remaining[0]) + 1
			var guard := Node2D.new()
			guard.set_script(load("res://pursuer.gd"))
			guard.enemy_type = 0   # SLOW — патрулирует вокруг алтаря
			guard.spawn_level = _level
			guard._enemy_floor = 0
			guard.position = center + Vector2(60, 0)
			guard.target = _player
			guard._game = self
			guard.process_mode = Node.PROCESS_MODE_PAUSABLE
			add_child(guard)
		"dark_trap":
			_spawn_event_trigger(container, center, "dark_trap")
		"choice":
			_spawn_event_trigger(container, center + Vector2(-55, 0), "choice_station")
			_spawn_event_trigger(container, center + Vector2(55, 0), "choice_exit")
		"echo":
			_spawn_event_trigger(container, center, "echo")
		"parasite":
			_spawn_event_trigger(container, center, "parasite")

func _spawn_event_trigger(container: Node2D, pos: Vector2, kind: String) -> void:
	var t := Area2D.new()
	t.set_script(load("res://event_room_trigger.gd"))
	t.game = self
	t.kind = kind
	t.floor_index = 0
	t.position = pos
	container.add_child(t)

# Предвестник (§5): золотистое мерцание за ~4 клетки до комнаты, без текста,
# один раз за уровень. Проверяется только пока комната ещё не «сработала».
func _update_event_room_warning() -> void:
	if _event_room_warned or _event_room_cell.x < 0:
		return
	if _player == null or not is_instance_valid(_player) or int(_player.current_floor) != 0:
		return
	var center: Vector2 = _cell_to_world(_event_room_cell)
	if _player.global_position.distance_to(center) <= TILE * 2.0 * EVENT_ROOM_WARN_CELLS:
		_event_room_warned = true
		if _fx:
			_fx.gold_pulse(0.8)

# «Выбор» (§5, choice_station/choice_exit) — телепорт к ближайшей станции
# этажа игрока либо к порталу-выходу уровня. Игрок не знает заранее, какой
# из двух одинаковых порталов куда ведёт.
func event_room_teleport(body: Node, target: String) -> void:
	var dest: Vector2 = Vector2.INF
	var dest_floor := 0
	if target == "station":
		var best_d := INF
		for s in get_tree().get_nodes_in_group("station"):
			if not is_instance_valid(s):
				continue
			var d: float = body.global_position.distance_to(s.global_position)
			if d < best_d:
				best_d = d
				dest = s.global_position
				dest_floor = int(body.current_floor) if "current_floor" in body else 0
	else:
		dest = _cell_to_world(_exit_cell) + Vector2(0, _exit_floor * _floor_gap)
		dest_floor = _exit_floor
	if dest == Vector2.INF:
		flash_message(GameConfig.tt("Портал не сработал — некуда вести", "The portal fizzled — nowhere to go"))
		return
	body.global_position = dest
	if "current_floor" in body:
		body.current_floor = dest_floor
	if body.has_method("snap_camera"):
		body.snap_camera()
	if _fx:
		_fx.flash(Color(0.4, 0.6, 1.0), 0.3)
	beep()

# «Эхо» (§5) — безопасная комната, разовая искра-указатель в сторону выхода
# (тот же приём, что и у обучения/маяка — _tut_emit_arrow).
func event_room_echo_ping(body: Node) -> void:
	if int(body.current_floor) != _exit_floor:
		return   # выход на другом этаже — направление ещё не имеет смысла
	var target: Vector2 = _cell_to_world(_exit_cell) + Vector2(0, _exit_floor * _floor_gap)
	_tut_emit_arrow(target)

# «Паразит» (§5) — враги этажа чуют прилив силы игрока и на 15 сек бегут
# быстрее (переиспользует множитель тёмной стороны эха шарда, тот же принцип).
func event_room_parasite_buff(f: int) -> void:
	for e in get_tree().get_nodes_in_group("enemy"):
		if is_instance_valid(e) and "_enemy_floor" in e and int(e._enemy_floor) == f and e.has_method("apply_ambush_alert"):
			e.apply_ambush_alert(15.0)
	flash_message(GameConfig.tt("🟣 Прилив сил — но рядом что-то пробудилось", "🟣 A surge of strength — but something nearby just woke up"))
	if _fx:
		_fx.gold_pulse(1.5)

# [GAMEDESIGN §17.3] Неоднородная плотность: лабиринт делится на грубую сетку
# 2×2 зон, у каждой — свой случайный шанс «заплести» петлю (снести внутреннюю
# стену между соседними проходами). Тот же приём, что уже даёт широкая фаза
# ритма ниже в _make_grid (там шанс один на весь этаж) — здесь шанс зависит от
# зоны, так что в одном уровне соседствуют более «тесный» и более «дырявый»
# участки. Только сносит стены — связность не портится.
func _carve_zonal_density(grid: Array) -> void:
	# Узкая фаза (1) — намеренно длинные тесные коридоры без петель, не трогаем.
	# Широкая фаза (2) уже сама «заплетает» петли по всей площади ниже в
	# _make_grid (фикс. шанс 0.14 равномерно) — не накладываем зональную сверху,
	# иначе на одном этаже удваивается эффект (замерено: до +25% лишних проходов
	# вместо задуманного разнообразия — лабиринт становится однородно дырявым,
	# а не «тесно тут, дырявo там»). Зональная версия — только на «обычной»
	# фазе (0), где сегодня нет вообще никакого разрежения.
	if _maze_phase != 0:
		return
	var zones_x := 2
	var zones_y := 2
	var zone_w: int = maxi(1, _cols / zones_x)
	var zone_h: int = maxi(1, _rows / zones_y)
	var zone_density: Dictionary = {}
	# [§43] Верхняя граница «дырявости» зоны — от площади этажа: на маленьком
	# 22% лишних проходов означают, что коридоров не остаётся вовсе.
	var dmax: float = 0.22 if (_cols * _rows) >= 900 else 0.10
	for zy in zones_y:
		for zx in zones_x:
			zone_density[Vector2i(zx, zy)] = randf_range(0.03, dmax)
	for cy in _rows:
		for cx in _cols:
			var zx: int = clampi(cx / zone_w, 0, zones_x - 1)
			var zy: int = clampi(cy / zone_h, 0, zones_y - 1)
			var p: float = zone_density[Vector2i(zx, zy)]
			if cx + 1 < _cols and randf() < p:
				grid[cy * 2 + 1][cx * 2 + 2] = false
			if cy + 1 < _rows and randf() < p:
				grid[cy * 2 + 2][cx * 2 + 1] = false

# [GAMEDESIGN §17.2] Биом задаёт не только цвет, но и характер пространства —
# разные алгоритмы карвинга ПОВЕРХ уже готового дерева (_make_grid). Дерево
# остаётся гарантией связности, эти проходы только добавляют петли/залы,
# никогда не убирают достижимость:
#   "rooms"  — «рукотворные» биомы (шахты): пара крупных залов 2-4 клетки,
#              читается как «архитектура», не природная нора.
#   "sparse" — «органические» биомы (споровые пустоты): всей площадью снесена
#              заметная доля внутренних стен — почти открытая пещера, враги
#              видны издалека, нужна другая тактика.
#   "tree"   — как сейчас, без изменений (биом по умолчанию).
const BIOME_TOPOLOGY := ["rooms", "tree", "sparse"]

func _apply_biome_topology(grid: Array) -> void:
	var topo: String = BIOME_TOPOLOGY[_biome % BIOME_TOPOLOGY.size()]
	match topo:
		"rooms":
			# [§43] Комнаты биома идут СВЕРХ _carve_rooms, поэтому считаем их из
			# того же бюджета площади — иначе на ур.1-5 (Лазурные шахты как раз
			# биом «rooms») этаж превращался в анфиладу залов.
			var budget: int = _room_budget()
			if budget <= 0:
				return
			var side: int = _room_max_side()
			var room_count: int = mini(2 + randi() % 2, budget)
			for _i in room_count:
				var rw: int = 2 + randi() % maxi(side - 1, 1)
				var rh: int = 2 + randi() % maxi(side - 1, 1)
				var cx0: int = randi() % maxi(1, _cols - rw)
				var cy0: int = randi() % maxi(1, _rows - rh)
				var gx0: int = maxi(1, cx0 * 2)
				var gx1: int = mini(_gw - 2, (cx0 + rw) * 2)
				var gy0: int = maxi(1, cy0 * 2)
				var gy1: int = mini(_gh - 2, (cy0 + rh) * 2)
				for gy in range(gy0, gy1 + 1):
					for gx in range(gx0, gx1 + 1):
						grid[gy][gx] = false
		"sparse":
			# [§43] Доля разрежения зависит от площади: 0.22 на каждую стену —
			# это чуть ли не снос сетки, если этаж маленький.
			var sp: float = 0.22 if (_cols * _rows) >= 900 else 0.12
			for cy in _rows:
				for cx in _cols:
					if cx + 1 < _cols and randf() < sp:
						grid[cy * 2 + 1][cx * 2 + 2] = false
					if cy + 1 < _rows and randf() < sp:
						grid[cy * 2 + 2][cx * 2 + 1] = false
		_:
			pass   # "tree" — обычный growing-tree, без изменений

# Население Логова: враги гуще и злее, чем в кампании на том же номере уровня —
# 10 уровней должны ощущаться боевым испытанием, а не прогулкой к боссу.
# Пара Стражей (элита, 6HP) охраняет подступы к тронному залу с 6-го Логова.
func _lair_populate_enemies() -> void:
	var n_slow: int = mini(2 + _level, 8)
	var n_fast: int = mini(maxi(0, _level - 1), 6)
	var n_cyclic: int = mini(maxi(0, _level - 3), 5)
	var types: Array = []
	for _i in n_slow:   types.append(0)
	for _i in n_fast:   types.append(1)
	for _i in n_cyclic: types.append(2)
	types.shuffle()
	var cells := _far_spawn_cells(_grids[0], types.size())
	for i in mini(types.size(), cells.size()):
		_spawn_one_enemy(int(types[i]), cells[i], 0)
	if _level >= 6:
		var room_c := Vector2i(_cols / 2, _rows / 2)
		var guard_cells := _passage_cells(false, _grids[0])
		guard_cells.shuffle()
		var placed := 0
		for c in guard_cells:
			if placed >= 2:
				break
			if c == room_c:
				continue
			if absi(c.x - room_c.x) + absi(c.y - room_c.y) <= 3:
				_spawn_one_enemy(3, c, 0)   # Страж: броня, дальнее зрение
				placed += 1

func _spawn_enemies() -> void:
	# Количество врагов каждого типа в зависимости от уровня. Раньше рост шёл
	# скачками (уровни 11/12/15/18 разом добавляли врагов) — теперь плюс один
	# враг через уровень, чередуя тип (4→SLOW, 6→FAST, 8→CYCLIC, 10→SLOW, ...),
	# так угроза растёт на каждом шаге, а не редкими рывками. Работает и в
	# бесконечном Накале — счётчик каждого типа просто ограничен сверху.
	var counts := [0, 0, 0]
	var step := 4
	while step <= _level:
		var idx: int = int((step - 4) / 4) % 3
		counts[idx] += 1
		step += 4
	# Элита глубоких уровней: Страж (25+), Фантом (30+), Пиявка (35+).
	_spawn_elites()
	var n_slow: int   = mini(counts[0], 6)
	var n_fast: int   = mini(counts[1], 6)
	var n_cyclic: int = mini(counts[2], 6)

	var types: Array = []
	for _i in n_slow:   types.append(0)
	for _i in n_fast:   types.append(1)
	for _i in n_cyclic: types.append(2)
	types.shuffle()

	# Распределяем врагов ПО ЭТАЖАМ (со случайного старта), чтобы единственный
	# враг не сидел всегда на стартовом этаже, который игрок быстро покидает —
	# тогда враги встречаются на всём пути вниз, а не только в начале.
	var base: int = (randi() % _floors) if _floors > 0 else 0
	for i in types.size():
		var f: int = (i + base) % maxi(1, _floors)
		var cells := _far_spawn_cells(_grids[f], 1)
		if cells.is_empty():
			continue
		_spawn_one_enemy(int(types[i]), cells[0], f)
	_assign_herder_role()

# [GAMEDESIGN §34/§35] Назначение роли ЗАГОНЩИКА — одним броском на уровень и
# ПОСЛЕ того, как заспавнены все враги, включая элиту.
#
# Раньше бросок делался на КАЖДОГО врага в цикле спавна, и это тихо ломало
# смысл шанса: при `herders` 0.5 и полутора десятках врагов роль доставалась
# кому-нибудь практически всегда (0.5^15), то есть биомный шанс ничего не
# значил, а запасной путь через Стража не мог сработать вовсе. Поймано
# харнессом: Страж-загонщик не встретился ни на 14 сидах подряд.
#
# Кандидаты: обычные типы всегда, СТРАЖ — только с HERDER_ELITE_FROM_LEVEL
# (медленный бронированный «архетип стены», перекрывать выход — ровно его
# работа). Фантом со скоростью 1.3 в этой роли не оставлял бы игроку выхода,
# Пиявка ест Волю — два наказания в одном враге; оба не участвуют.
func _assign_herder_role() -> void:
	if _herder_placed or not _mech_ready("herder"):
		return
	if GameConfig.tutorial_mode or _boss_level or _superboss_level:
		return
	if randf() > _biome_chance("herders"):
		return
	var candidates: Array = []
	for e in get_tree().get_nodes_in_group("enemy"):
		if not is_instance_valid(e) or not ("role_herder" in e):
			continue
		var t: int = int(e.get("enemy_type"))
		if t <= 2 or (t == 3 and _level >= HERDER_ELITE_FROM_LEVEL):
			candidates.append(e)
	if candidates.is_empty():
		return
	var pick: Node = candidates[randi() % candidates.size()]
	_herder_placed = true
	pick.role_herder = true
	# Читаемость: загонщик должен опознаваться до того, как игрок поймёт его
	# повадку на своей шкуре — иначе это выглядит как сломанный AI.
	pick.modulate = Color(1.0, 0.85, 0.45)

# Супербосс §25 — арена-фундамент. Большое открытое поле (обычные пилоны-
# укрытия ПОГИБАЮТ от будущего лазера, «крепкие» — нет) вместо обычного
# лабиринта. Возвращает [grid, strong_cells: Dictionary]. Без AI босса —
# только геометрия и два типа стен, тестируется отдельно (см.
# _spawn_superboss_test), реальный уровень 50 кампании пока НЕ тронут —
# нельзя подменять живой финальный уровень, пока нет самого босса.
func _make_superboss_arena_grid(cols: int, rows: int) -> Array:
	var gw := cols * 2 + 1
	var gh := rows * 2 + 1
	var grid: Array = []
	grid.resize(gh)
	for gy in gh:
		var row := []
		row.resize(gw)
		for gx in gw:
			row[gx] = (gx == 0 or gx == gw - 1 or gy == 0 or gy == gh - 1)
		grid[gy] = row
	# Пилоны-укрытия регулярной сеткой; каждый второй — «крепкий» (см.
	# STRONG_WALL_COLOR), остальные обычные (разрушаемые). Чередование, а не
	# случайность — расстановка должна быть предсказуемой и читаемой игроком
	# ДО столкновения с разницей (урок §22 «непонятные объекты»).
	var strong: Dictionary = {}
	var idx := 0
	var cy := 3
	while cy < rows - 3:
		var cx := 3
		while cx < cols - 3:
			var gx := cx * 2 + 1
			var gy := cy * 2 + 1
			grid[gy][gx] = true
			if idx % 2 == 0:
				strong[Vector2i(gx, gy)] = true
			idx += 1
			cx += 4
		cy += 4
	return [grid, strong]

# [SPAWN-SAFETY 2026-07-29] Общая страховка от целого КЛАССА багов: любой
# режим/уровень, который подменяет _cols/_rows после того, как _entry_cell уже
# выбран (арена дверь-босса, арена супербосса, овал, Логово, что появится
# дальше), рискует оставить точку входа снаружи новой сетки или внутри стены.
# Итог всегда одинаков и молчалив: игрок стоит в пустоте, вокруг чернота, до
# выхода не дойти. Так уже было дважды — с ареной супербосса (GAMEDESIGN §27)
# и с ареной дверь-босса на уровнях 30+ (§28).
#
# Здесь — последний рубеж перед постройкой этажа входа: если клетка входа
# невалидна, снимаем её на ближайший реальный проход и ГРОМКО сообщаем.
# Слово «invalid» в тексте не случайно: смоук-тест грепает именно его, так
# что будущая регрессия этого класса свалит обычную автопроверку, а не
# доедет молча до игрока.
# [SPAWN-SAFETY 2026-07-30] Тот же класс багов, что и _validate_entry_cell, но
# для ПЕРЕХОДА через дверь. door.gd телепортирует «на ту же клетку этажом
# ниже» (body.global_position += delta_y), и это верно, пока у этажей одна
# планировка. На уровне 50 это не так: этаж 0 — овал 66×54, а этаж 1 — арена
# супербосса 34×26, добитая до тех же размеров СПЛОШНОЙ СТЕНОЙ. Дверь, стоящая
# вне площади арены, высаживала игрока внутрь этого монолита: чернота, стен не
# видно (ты в них), выхода нет (жалоба 30.07.2026 — «на 50 уровне при очередном
# переходе появился в темноте»).
#
# Зовётся из door.gd СРАЗУ после телепорта. Если клетка прибытия непроходима —
# снимаем на ближайший реальный проход этого этажа и громко сообщаем словом
# invalid, которое ловит стандартный греп смоук-теста.
func validate_arrival(body: Node2D, f: int) -> void:
	if body == null or not is_instance_valid(body):
		return
	if f < 0 or f >= _grids.size():
		return
	var grid: Array = _grids[f]
	var local: Vector2 = body.global_position - Vector2(0, f * _floor_gap)
	var cell := _world_to_cell(body.global_position, f)
	if _cell_is_open(grid, cell):
		return
	var cells := _passage_cells(false, grid)
	if cells.is_empty():
		push_error("SPAWN-SAFETY: invalid arrival on floor %d and no passages" % f)
		return
	var best: Vector2i = cells[0]
	var best_d: int = 1 << 30
	for c in cells:
		var d: int = absi(c.x - cell.x) + absi(c.y - cell.y)
		if d < best_d:
			best_d = d
			best = c
	body.global_position = _cell_to_world(best) + Vector2(0, f * _floor_gap)
	if body.has_method("snap_camera"):
		body.snap_camera()
	push_warning("SPAWN-SAFETY: invalid arrival cell %s on floor %d (level %d) — snapped to %s"
		% [str(cell), f, _level, str(best)])

func _validate_entry_cell() -> void:
	if _grids.is_empty():
		return
	var grid: Array = _grids[0]
	if _cell_is_open(grid, _entry_cell):
		return
	var was := _entry_cell
	var cells := _passage_cells(false, grid)
	if cells.is_empty():
		push_error("SPAWN-SAFETY: invalid entry cell %s and no passages on floor 0" % str(was))
		return
	var clamped := Vector2i(clampi(was.x, 0, _cols - 1), clampi(was.y, 0, _rows - 1))
	var best: Vector2i = cells[0]
	var best_d: int = 1 << 30
	for c in cells:
		var d: int = absi(c.x - clamped.x) + absi(c.y - clamped.y)
		if d < best_d:
			best_d = d
			best = c
	_entry_cell = best
	push_warning("SPAWN-SAFETY: invalid entry cell %s for grid %dx%d (level %d) — snapped to %s"
		% [str(was), _cols, _rows, _level, str(best)])

# Клетка существует в сетке и является проходом (не стеной).
func _cell_is_open(grid: Array, c: Vector2i) -> bool:
	if c.x < 0 or c.y < 0 or c.x >= _cols or c.y >= _rows:
		return false
	var gy: int = c.y * 2 + 1
	var gx: int = c.x * 2 + 1
	if gy < 0 or gy >= grid.size():
		return false
	var row: Array = grid[gy]
	if gx < 0 or gx >= row.size():
		return false
	return not bool(row[gx])

func _make_arena_grid() -> Array:
	var grid: Array = []
	grid.resize(_gh)
	for gy in _gh:
		var row := []
		row.resize(_gw)
		for gx in _gw:
			row[gx] = (gx == 0 or gx == _gw - 1 or gy == 0 or gy == _gh - 1)
		grid[gy] = row
	# Несколько колонн-укрытий для тактики
	var pillars := [
		Vector2i(3, 2), Vector2i(3, _rows - 3),
		Vector2i(_cols - 4, 2), Vector2i(_cols - 4, _rows - 3),
		Vector2i(_cols / 2, _rows / 2 - 1), Vector2i(_cols / 2, _rows / 2 + 1),
	]
	for p: Vector2i in pillars:
		var gx: int = p.x * 2 + 1
		var gy: int = p.y * 2 + 1
		if gx > 0 and gx < _gw - 1 and gy > 0 and gy < _gh - 1:
			grid[gy][gx] = true
	return grid

func _spawn_boss(boss_floor: int = 0) -> void:
	# В тест-режиме разблокируем вспышку и сонар, чтобы босс был проходим
	if GameConfig.boss_test_enabled:
		GameConfig.skills_unlocked["flash"] = true
		GameConfig.skills_unlocked["sonar"] = true

	var center_cell := Vector2i(BOSS_ARENA_COLS / 2, BOSS_ARENA_ROWS / 2) if _boss_arena_mode else Vector2i(_cols / 2, _rows / 2)
	# CharacterBody2D — не Node2D: боссу нужна настоящая физическая коллизия со
	# стенами (см. комментарий в шапке boss.gd), иначе рывок пробивает пилоны.
	var b := CharacterBody2D.new()
	b.set_script(load("res://boss.gd"))
	b.position = _cell_to_world(center_cell) + Vector2(0, maxi(boss_floor, 0) * _floor_gap)
	b.set_meta("game", self)
	b.process_mode = Node.PROCESS_MODE_PAUSABLE
	add_child(b)
	_boss = b
	_boss_fragments = 0
	if _lair_active:
		flash_message(GameConfig.tt("☠ Логово %d/%d: тронный зал в центре — дойди и повергни владыку тьмы.\nQ (Вспышка) бьёт вблизи, E (Сонар) усиливает удар ×2",
			"☠ Lair %d/%d: the throne room is at the center — reach it and defeat the dark lord.\nQ (Flash) hits up close, E (Sonar) doubles the damage") % [_level, GameConfig.LAIR_LEVELS])
	else:
		flash_message(GameConfig.tt("⚠ Тёмное Ядро\nПодойди и нажми Q (Вспышка)\nE (Сонар) усилит удар ×2",
			"⚠ The Dark Core\nGet close and press Q (Flash)\nE (Sonar) doubles the hit"))

# Арена в виде скрытого дополнительного «этажа» ниже последнего + багровая
# дверь на случайном этаже лабиринта. Игрок волен игнорировать её.
# Единственная дверь в конце овального этажа 0 финала — ведёт на этаж 1
# (сама арена супербосса, строится лениво через door.gd -> _ensure_floor_built,
# см. хук в _ensure_floor_built ниже). Всегда открыта — ключ тут не нужен,
# это не бонусный контент, а обязательный переход к финальному бою.
func _place_superboss_door() -> void:
	if _oval_exit.x < 0:
		return
	var local := _cell_to_world(_oval_exit)
	var d_a := _make_door(local, _floor_gap, 1, false)
	var d_b := _make_door(_cell_to_world(Vector2i(1, 1)) + Vector2(0, _floor_gap), -_floor_gap, 0, false)
	d_a.partner = d_b
	d_b.partner = d_a
	var na := Vector3i(0, _oval_exit.x, _oval_exit.y)
	var nb := Vector3i(1, 1, 1)
	_door_links[na] = [nb]
	_door_links[nb] = [na]

# Супербосс спавнится не сразу (этаж 1 строится лениво, как и у обычной
# дверь-боссовской арены) — а при первом реальном построении этажа 1, см.
# хук в _ensure_floor_built. Тот же контент, что раньше создавался в _ready()
# для единственного этажа 0 старой (безовальной) версии финала.
func _spawn_superboss_on_floor1() -> void:
	if _player == null or not is_instance_valid(_player):
		return
	var sb := CharacterBody2D.new()
	sb.set_script(load("res://superboss.gd"))
	sb._game = self
	sb._player = _player
	sb._floor_idx = 1
	# main — PROCESS_MODE_ALWAYS (ввод на паузе), дети наследуют: без явного
	# PAUSABLE босс продолжал бы ездить и жечь стены лазером ПОКА ИГРА НА
	# ПАУЗЕ. Тот же явный флаг стоит у игрока/врагов/дверь-босса.
	sb.process_mode = Node.PROCESS_MODE_PAUSABLE
	add_child(sb)
	sb.global_position = Vector2(_gw * TILE * 0.5, _gh * TILE * 0.5 + 1 * _floor_gap)
	_superboss = sb
	_spawn_superboss_escort(1, _grids[1], sb)
	flash_message(GameConfig.tt(
		"☠ ФИНАЛ: механический страж лабиринта. Лазер бьёт по стенам — крепкие (стальные) устоят.\nОбычная Вспышка почти не ранит — жди, пока лазер откроет уязвимость, и бей Рывок+Вспышка",
		"☠ FINALE: the maze's mechanical guardian. Its laser breaks walls — steel ones hold.\nA plain Flash barely hurts it — wait for the laser to expose a weak point, then hit Dash+Flash"))

func _setup_boss_door() -> void:
	_boss_floor = _floors
	var saved_cols := _cols
	var saved_rows := _rows
	_cols = BOSS_ARENA_COLS
	_rows = BOSS_ARENA_ROWS
	var arena := _make_arena_grid()
	_cols = saved_cols
	_rows = saved_rows
	# Сетка арены меньше сетки этажа — дополняем стенами до общего размера,
	# чтобы BFS врагов и маски стен работали в одном формате координат.
	while arena.size() < _gh:
		var row := []
		row.resize(_gw)
		for x in _gw:
			row[x] = true
		arena.append(row)
	for y in arena.size():
		while (arena[y] as Array).size() < _gw:
			(arena[y] as Array).append(true)
	_grids.append(arena)
	# [WALLPERF-2026-07] Арену босса раньше строили здесь СРАЗУ, при инициализации
	# уровня — но это ещё один полноразмерный этаж (~столько же нод, сколько
	# этаж входа), и он строился ДАЖЕ если игрок ни разу не тронет дверь-босса
	# (level % 5 == 0 — то есть на КАЖДОМ 5-м уровне, включая все мега-уровни
	# 30/35/40/45/50). Теперь она, как и обычные этажи, строится лениво —
	# см. _floor_is_arena/_ensure_floor_built и вызов в enter_boss_arena().
	_floor_is_arena[_boss_floor] = true
	# Дверь — в случайном тупике/проходе случайного этажа, подальше от старта.
	# [WALLPERF-2026-07] Раньше эта дверь цеплялась к _floor_containers[rf], что
	# ЗАСТАВЛЯЛО сразу физически построить случайный этаж только ради одной ноды.
	# Как и обычные двери-переходы (см. _make_door), она не нуждается в контейнере
	# этажа — просто ребёнок main с позицией, сдвинутой на floor_gap этого этажа.
	# Сам этаж rf по-прежнему построится лениво, когда игрок дойдёт до него.
	var rf := randi() % _floors
	var cells := _passage_cells(false, _grids[rf])
	cells.shuffle()
	for c in cells:
		if c.x + c.y < 6:
			continue   # не у самого старта
		var d := Area2D.new()
		d.set_script(load("res://boss_door.gd"))
		d.game = self
		d.position = _cell_to_world(c) + Vector2(0, rf * _floor_gap)
		add_child(d)
		break

func enter_boss_arena() -> void:
	if _boss_arena_mode or _boss_defeated_this_level or _boss_floor < 0:
		return
	if _player == null or not is_instance_valid(_player):
		return
	_boss_arena_mode = true
	_boss_return_pos = _player.global_position
	_boss_return_floor = _player.current_floor
	_ensure_floor_built(_boss_floor)  # [WALLPERF-2026-07] арена строится только сейчас, не заранее
	_player.global_position = _cell_to_world(Vector2i(0, 0)) + Vector2(0, _boss_floor * _floor_gap)
	_player.current_floor = _boss_floor
	_player.teleport_cooldown = 1.0
	_spawn_boss(_boss_floor)
	flash_message(GameConfig.tt("☠ Арена Тёмного Ядра\nПобеда принесёт ДАР — новый навык", "☠ The Dark Core's arena\nVictory grants a GIFT — a new skill"))

# Победа над дверным боссом: дар (новый навык) и возврат в лабиринт.
func _boss_victory() -> void:
	_boss_arena_mode = false
	_boss_defeated_this_level = true
	# Первая победа над обычной дверь-боссом (☠) открывает витрину «Навыки
	# призыва» в Магазине — раньше это висело на супербоссе (ур. 50), поэтому
	# навык был доступен практически только на переигровке уже пройденного
	# финала. Дверь-босс встречается с 5-го уровня — намного раньше.
	var summon_first_time := not GameConfig.door_boss_defeated
	GameConfig.door_boss_defeated = true
	var given := ""
	for id in BOSS_GIFTS:
		if not GameConfig.skills_unlocked.get(id, false):
			GameConfig.skills_unlocked[id] = true
			given = id
			break
	var summon_note := (GameConfig.tt("\n✦ Открыта витрина «Навыки призыва» в Магазине навыков", "\n✦ The «Summon Skills» shelf is now open in the Skill Shop")) if summon_first_time else ""
	if given != "":
		flash_message(GameConfig.tt("☠ ДАР ЯДРА: «%s»\nНовый навык — и новая форма Апекса", "☠ CORE GIFT: «%s»\nA new skill — and a new Apex form") %
			(BOSS_GIFT_NAMES_EN[given] if GameConfig.locale == "en" else BOSS_GIFT_NAMES[given]) + summon_note)
	else:
		GameConfig.add_xp(800)
		if GameConfig.active_run >= 0:
			_ember += 120.0 * _ember_mult()
			_persist_ember()
		flash_message(GameConfig.tt("☠ Ядро побеждено · все дары уже твои — награда Накалом и опытом", "☠ The Core is defeated · you already have all its gifts — reward in Ember and XP") + summon_note)
	GameConfig.save_game()
	if _fx:
		_fx.gold_pulse(2.5)
		_fx.flash(Color(1.0, 0.6, 0.5), 0.3)
	play_sfx(_sfx_win)
	if _player and is_instance_valid(_player):
		_player.respawn(_boss_return_pos, _boss_return_floor)

func on_boss_phase2(boss_pos: Vector2) -> void:
	_boss = null
	_boss_fragments = 3
	var offsets := [Vector2(-80, -60), Vector2(80, -60), Vector2(0, 80)]
	for i in 3:
		var frag := Node2D.new()
		frag.set_script(load("res://pursuer.gd"))
		frag.enemy_type = 1   # FAST
		frag.spawn_level = _level
		frag._enemy_floor = _boss_floor if _boss_arena_mode else 0
		frag.position = boss_pos + offsets[i]
		frag.target = _player
		frag._game = self
		frag.set_meta("boss_fragment", true)
		frag.process_mode = Node.PROCESS_MODE_PAUSABLE
		add_child(frag)
	flash_message(GameConfig.tt("Тёмное Ядро расщепилось · Щит + Вспышка", "The Dark Core split · Shield + Flash"))

func on_boss_fragment_killed() -> void:
	_boss_fragments -= 1
	if _boss_fragments > 0:
		flash_message(GameConfig.tt("Фрагмент погашен · осталось %d", "Fragment extinguished · %d left") % _boss_fragments)
	if _boss_fragments <= 0 and not _won:
		if _boss_arena_mode:
			_boss_victory()
		else:
			on_player_win()   # авторский тест-режим боссов: этаж = арена

# ЕДИНЫЙ хук смерти фрагмента босса — обязателен на КАЖДОМ пути уничтожения
# врага (обычный бой _die/on_enemy_defeated и Апекс _destroy_chaser). Раньше
# счётчик уменьшала только отдельная ветка вспышки, а смерть от сонара/тарана/
# площадной вспышки шла мимо — все фрагменты мертвы, а победа не наступала.
# Мету снимаем до декремента: один фрагмент = ровно один вызов.
func _note_enemy_death(e: Node2D) -> void:
	if e.has_meta("boss_fragment"):
		e.remove_meta("boss_fragment")
		on_boss_fragment_killed()

# Вызывается игроком при каждом применении Вспышки (Q). Наносит урон боссу/фрагментам
# (на босс-этаже) и, независимо от этажа, обычным врагам вблизи — Вспышка не только
# «осмотреться», но и оружие ближней дистанции для агрессивного стиля игры.
const FLASH_HIT_RADIUS := 140.0

func on_player_flash(player_pos: Vector2) -> void:
	if _won or _dead:
		return
	skill_hit_enemies(player_pos, FLASH_HIT_RADIUS, 1, "flash")
	if _superboss and is_instance_valid(_superboss):
		_superboss.try_hit(player_pos, false)
	if not _boss_level and not _boss_arena_mode and not _lair_active:
		return
	if _boss and is_instance_valid(_boss):
		if _boss.has_method("try_flash_hit"):
			_boss.try_flash_hit(player_pos)
	# Фаза 2: фрагменты — обычные враги (группа "enemy"), их уже бьёт
	# skill_hit_enemies выше; отдельной ветки урона больше нет — раньше две
	# параллельные системы HP расходились, и победа не засчитывалась.

# «Световое копьё» (рывок во время вспышки, player.gd::_try_dash) — отдельный
# хук от обычной Вспышки: супербоссу (§25) важно различать голый навык и
# комбо, обычным врагам/дверь-боссу разница не нужна (skill_hit_enemies уже
# посчитал попадание по вспышке).
func on_player_light_spear(player_pos: Vector2) -> void:
	if _won or _dead:
		return
	if _superboss and is_instance_valid(_superboss):
		_superboss.try_hit(player_pos, true)

# Лазер супербосса (§25): ломает клетки по прямой от from_pos в направлении
# dir, останавливается на границе арены ИЛИ на первой «крепкой» стене
# (_strong_cells — _set_wall тихо отказывает её ломать, тот жеguard, что
# уже защищает крепкие пилоны от Разлома/землетрясения). Возвращает число
# реально разрушенных клеток.
func superboss_laser_break(from_pos: Vector2, dir: Vector2, floor_idx: int, max_cells: int) -> int:
	if floor_idx < 0 or floor_idx >= _grids.size() or dir.length() < 0.01:
		return 0
	var local := from_pos - Vector2(0, floor_idx * _floor_gap)
	var gx := int(local.x / TILE)
	var gy := int(local.y / TILE)
	var step := Vector2i(1, 0) if absf(dir.x) >= absf(dir.y) else Vector2i(0, 1)
	if (dir.x if step.x != 0 else dir.y) < 0.0:
		step = -step
	var grid: Array = _grids[floor_idx]
	var broken := 0
	var cx := gx
	var cy := gy
	for i in max_cells:
		cx += step.x
		cy += step.y
		if cx <= 0 or cx >= _gw - 1 or cy <= 0 or cy >= _gh - 1:
			break
		if not (grid[cy][cx] as bool):
			continue   # уже проход — луч летит дальше, не тратясь на пустоту
		_set_wall(floor_idx, cx, cy, false)
		if not (grid[cy][cx] as bool):
			broken += 1
			var bb := Node2D.new()
			bb.set_script(load("res://burst.gd"))
			bb.color = Color(1.0, 0.25, 0.2, 1.0)
			bb.max_scale = 4.0
			bb.dur = 0.4
			add_child(bb)
			bb.global_position = Vector2(cx * TILE + TILE * 0.5, cy * TILE + TILE * 0.5 + floor_idx * _floor_gap)
		else:
			break   # уткнулись в крепкую стену (иммунна) — луч дальше не идёт
	return broken

# Союзник-«отражение» (§25) — спавнит ally.gd, ограничение по числу
# одновременно живых петов. Вызывается из навыка призыва (player.gd::_try_summon),
# который сам гейтится GameConfig.summon_unlocked (открывается победой над
# дверь-боссом, см. _boss_victory). Возвращает true, если призыв состоялся.
func summon_ally() -> bool:
	if _player == null or not is_instance_valid(_player):
		return false
	if get_tree().get_nodes_in_group("ally").size() >= MAX_ALLIES:
		if has_method("flash_message"):
			flash_message(GameConfig.tt("Союзников уже максимум", "Already at max allies"))
		return false
	var a := CharacterBody2D.new()
	a.set_script(load("res://ally.gd"))
	a.game = self
	a.player = _player
	a.process_mode = Node.PROCESS_MODE_PAUSABLE   # иначе пет живёт и бьёт на паузе
	add_child(a)
	a.global_position = _player.global_position + Vector2(randf_range(-40, 40), randf_range(-40, 40))
	if has_method("flash_message"):
		flash_message(GameConfig.tt("✦ Зеркальный союзник призван", "✦ Mirror ally summoned"))
	return true

func on_superboss_defeated(_pos: Vector2) -> void:
	_superboss = null
	var first_time := not GameConfig.superboss_defeated
	GameConfig.superboss_defeated = true
	# [SAVE-SAFETY] test_mode не гейтит save_game() само по себе (см. CLAUDE.md,
	# инцидент 2026-07-06) — харнесс, дёргающий этот колбэк, иначе дописывает
	# синтетические тестовые поля в РЕАЛЬНЫЙ сейв активного профиля.
	if not GameConfig.test_mode:
		GameConfig.save_game()
	if first_time:
		flash_message(GameConfig.tt("☠ Супербосс повержен!", "☠ Superboss defeated!"))
	else:
		flash_message(GameConfig.tt("☠ Супербосс повержен (тест)", "☠ Superboss defeated (test)"))
	if _fx:
		_fx.gold_pulse(2.5)
	# На реальном уровне 50 победа над супербоссом = победа на уровне —
	# заводит обычный конвейер результатов/наград (тестовый спавн
	# spawn_superboss_test() этой веткой не идёт, _superboss_level там false).
	if _superboss_level:
		on_player_win()
		return
	play_sfx(_sfx_win)

# Тестовый спавн супербосса (§25) поверх отдельного «лишнего» этажа — не
# трогает реальный уровень 50. Возвращает индекс построенного этажа.
func spawn_superboss_test() -> int:
	var cols := SUPERBOSS_ARENA_COLS
	var rows := SUPERBOSS_ARENA_ROWS
	_cols = cols
	_rows = rows
	_gw = cols * 2 + 1
	_gh = rows * 2 + 1
	var res: Array = _make_superboss_arena_grid(cols, rows)
	var grid: Array = res[0]
	var strong: Dictionary = res[1]
	var f: int = _grids.size()
	_grids.append(grid)
	_strong_cells[f] = strong
	_build_floor(f, grid)
	var sb := CharacterBody2D.new()
	sb.set_script(load("res://superboss.gd"))
	sb._game = self
	sb._player = _player
	sb._floor_idx = f
	sb.position = Vector2(_gw * TILE * 0.5, _gh * TILE * 0.5) + Vector2(0, f * _floor_gap)
	sb.process_mode = Node.PROCESS_MODE_PAUSABLE   # см. комментарий в ветке _superboss_level
	add_child(sb)
	_superboss = sb

	_spawn_superboss_escort(f, grid, sb)
	return f

# Миньоны-эскорт + антистанции (§25, шаг 3). Эскорт — элита Страж (тип 3,
# броня) с пометкой meta "boss_escort", ускоряется рядом с активной
# антистанцией (см. pursuer.gd::_escort_buff_mult). Антистанции стоят в
# стороне от центра — тактика «сначала погасить подпитку эскорта». Эскорт
# держится у босса: короткий агр вокруг него (leash_node, см. pursuer.gd) —
# отогнал игрока за пределы радиуса или потерял из виду — Страж возвращается
# к боссу, а не гоняется по всей арене как обычный преследователь.
func _spawn_superboss_escort(f: int, grid: Array, sb: Node2D) -> void:
	var cells := _passage_cells(false, grid)
	cells.shuffle()
	if cells.is_empty():
		return
	var n_escort := 3
	for i in mini(n_escort, cells.size()):
		var pur := Node2D.new()
		pur.set_script(load("res://pursuer.gd"))
		pur.enemy_type = 3   # Страж — броня, тематически «защитник»
		pur.spawn_level = _level
		pur._enemy_floor = f
		pur.position = _cell_to_world(cells[i]) + Vector2(0, f * _floor_gap)
		pur.target = _player
		pur._game = self
		pur.process_mode = Node.PROCESS_MODE_PAUSABLE
		pur.set_meta("boss_escort", true)
		pur.leash_node = sb
		add_child(pur)

	var n_anti := 2
	for i in mini(n_anti, maxi(0, cells.size() - n_escort)):
		var c: Vector2i = cells[n_escort + i]
		var a := Area2D.new()
		a.set_script(load("res://antistation.gd"))
		a.game = self
		a.floor_index = f
		a.position = _cell_to_world(c) + Vector2(0, f * _floor_gap)
		a.process_mode = Node.PROCESS_MODE_PAUSABLE
		add_child(a)

# Урон "по площади" от активных навыков (Вспышка/Сонар) — превращает их из
# чисто обзорных в боевые: подойти и сбить врага, а не только убегать от него.
# Возвращает число уничтоженных этим попаданием (не число задетых).
func skill_hit_enemies(center: Vector2, radius: float, dmg: int, source: String) -> int:
	var kills := 0
	for e in get_tree().get_nodes_in_group("enemy"):
		if not is_instance_valid(e):
			continue
		if e.global_position.distance_to(center) <= radius and e.has_method("take_damage"):
			if e.take_damage(dmg, source):
				kills += 1
	return kills

# Вызывается pursuer.gd (_die), когда враг уничтожен обычным боем (не Апексом —
# у того своя, более щедрая награда через _destroy_chaser/apex_overload).
func on_enemy_defeated(e: Node2D, source: String) -> void:
	GameConfig.add_xp(30)
	# [GAMEDESIGN §32] Награда на МЕСТЕ убийства, а не только в счётчике XP,
	# который игрок увидит на экране результатов.
	var at: Vector2 = e.global_position if is_instance_valid(e) else Vector2.INF
	if GameConfig.active_run >= 0:
		var em: float = 3.0 * _ember_mult()
		_ember += em
		_show_reward(at, "+30 XP  +%d" % int(round(em)), Color(1.0, 0.62, 0.35), 14)
	else:
		_show_reward(at, "+30 XP", Color(0.85, 0.95, 1.0), 14)
	beep()
	GameConfig.bump_stat("enemies_killed")
	if "enemy_type" in e:
		GameConfig.bump_stat("kill_t%d" % int(e.enemy_type))   # бестиарий
	_announce_milestones()
	_note_enemy_death(e)

# Баннер об открытых за достижения навыках (см. SKILL_MILESTONES в config.gd).
func _announce_milestones() -> void:
	for id in GameConfig.check_skill_milestones():
		var nm_ru: String = {"sonar": "Сонар (E)", "shield": "Щит (C)", "guide": "Искра (G)", "reveal": "Озарение (F)", "pulse": "Пульс (B)"}.get(id, id)
		var nm_en: String = {"sonar": "Sonar (E)", "shield": "Shield (C)", "guide": "Guide (G)", "reveal": "Reveal (F)", "pulse": "Pulse (B)"}.get(id, id)
		var nm: String = nm_en if GameConfig.locale == "en" else nm_ru
		flash_message(GameConfig.tt("🔓 Открыт навык «%s» — %s!", "🔓 Skill unlocked: «%s» — %s!") % [nm, GameConfig.milestone_text(id)])
		if _fx:
			_fx.gold_pulse(2.0)
			_fx.flash(Color(1.0, 0.9, 0.5), 0.25)
		play_sfx(_sfx_key)

# [GAMEDESIGN §18] Режим открылся при пересечении порога max_unlocked_level —
# явный баннер, тот же приём, что у _announce_milestones. Сравнение
# old/new (а не просто «уже открыт») — чтобы старые сохранения, уже прошедшие
# порог, не получили тост задним числом при первом же уровне после патча.
func _announce_mode_unlocks(old_unlocked: int, new_unlocked: int) -> void:
	if old_unlocked < GameConfig.MODE_UNLOCK_DAILY and new_unlocked >= GameConfig.MODE_UNLOCK_DAILY:
		flash_message(GameConfig.tt("🔓 Открыт режим «Спуск дня» — один лабиринт на всех, одна попытка в день!", "🔓 «Daily Dive» unlocked — one maze for everyone, one attempt a day!"))
		if _fx:
			_fx.gold_pulse(2.0)
			_fx.flash(Color(1.0, 0.85, 0.35), 0.25)
		play_sfx(_sfx_key)
	if old_unlocked < GameConfig.MODE_UNLOCK_EMBER and new_unlocked >= GameConfig.MODE_UNLOCK_EMBER:
		flash_message(GameConfig.tt("🔓 Открыт режим «Накал» — спуск за огнём, 3 жизни на весь забег!", "🔓 «Ember» unlocked — descend for fire, 3 lives for the whole run!"))
		if _fx:
			_fx.gold_pulse(2.0)
			_fx.flash(Color(1.0, 0.55, 0.25), 0.25)
		play_sfx(_sfx_key)
	if old_unlocked < GameConfig.MODE_UNLOCK_LAIR and new_unlocked >= GameConfig.MODE_UNLOCK_LAIR:
		flash_message(GameConfig.tt("🔓 Открыт режим «Логово» — 10 уровней, владыка тьмы в центре лабиринта!", "🔓 «Lair» unlocked — 10 levels, a dark lord at the maze's center!"))
		if _fx:
			_fx.gold_pulse(2.0)
			_fx.flash(Color(1.0, 0.3, 0.35), 0.25)
		play_sfx(_sfx_key)

# Апекс открылся (GameConfig.apex_unlocked) — явный баннер + звук + вспышка,
# чтобы это было невозможно пропустить (раньше происходило молча).
func _on_apex_unlocked() -> void:
	flash_message(GameConfig.tt(
		"⚡ АПЕКС (H) открыт! Сработает только при реальной погоне — форма зависит от твоего самого прокачанного навыка.",
		"⚡ APEX (H) unlocked! It only fires when a chaser is actually on you — its form depends on your most-mastered skill."))
	if _fx:
		_fx.gold_pulse(2.5)
		_fx.flash(Color(1.0, 0.25, 0.35), 0.3)
	play_sfx(_sfx_key)

func _spawn_elites() -> void:
	var elites: Array = []
	if _mech_ready("elite_guard"):
		elites.append(3)
	if _mech_ready("elite_phantom"):
		elites.append(4)
	if _mech_ready("elite_leech"):
		elites.append(5)
	if _level >= 42:
		elites.append(4)   # второй фантом на самом дне
	for type in elites:
		var f := randi() % _floors
		var cells := _passage_cells(false, _grids[f])
		cells.shuffle()
		for c in cells:
			if c.x + c.y >= 8:
				_spawn_one_enemy(type, c, f)
				break

# [GAMEDESIGN §33] Стадия эскалации по прошедшему времени. Норма времени та
# же, что в ранге (_compute_rank), поэтому «долго» на 50-м уровне и на 1-м —
# разные числа секунд, а не одна константа.
func _escalation_target_stage() -> int:
	if GameConfig.tutorial_mode or _boss_arena_mode or _superboss_level or _won or _dead:
		return 0
	var par: float = 20.0 + _level * 12.0
	# [GAMEDESIGN §35] Биом растягивает или поджимает терпение лабиринта. В
	# Споровых пустотах тебя и так видно издалека, поэтому давление приходит
	# раньше; в Лазурных шахтах уровень про поиск маршрута — там дают время.
	# Ключ необязателен: биом без него играет по базовому темпу (1.0).
	var patience: float = 1.0
	var rules := _biome_rules()
	if not rules.is_empty():
		patience = maxf(float(rules.get("escalation", 1.0)), 0.25)
	if _elapsed >= par * ESCALATION_STAGE2_MULT * patience:
		return 2
	if _elapsed >= par * ESCALATION_STAGE1_MULT * patience:
		return 1
	return 0

func _update_escalation() -> void:
	var want: int = _escalation_target_stage()
	if want <= _escalation_stage:
		return   # стадии только растут: уровень не «успокаивается» обратно
	_escalation_stage = want
	match _escalation_stage:
		1:
			# Тьма густеет: обзор ужимается, по краям — холодная кромка. Без
			# текста-объяснения: игрок должен ПОЧУВСТВОВАТЬ, что стало тяжелее.
			_vision_target = minf(_vision_target, ESCALATION_VISION[1])
			_tint_target = Color(0.06, 0.06, 0.12, 0.13)
			flash_message(GameConfig.tt(
				"◆ Лабиринт заметил, что ты задержался — тьма густеет",
				"◆ The maze noticed you lingering — the dark thickens"))
		2:
			_vision_target = minf(_vision_target, ESCALATION_VISION[2])
			_tint_target = Color(0.12, 0.04, 0.10, 0.16)
			_spawn_hunter()
			flash_message(GameConfig.tt(
				"☣ ЛОВЧИЙ пробудился: он не потеряет твой след. Уходи.",
				"☣ The STALKER has woken: it will not lose your trail. Leave."))
			if _player and is_instance_valid(_player) and _player.has_method("add_shake"):
				_player.add_shake(7.0, 0.5)

# Ловчий: один на уровень, на этаже игрока, подальше от него. Медленный
# (SLOW-тип), но с `relentless` — не теряет след. Смысл в том, чтобы дать
# давление «пора уходить», а не убить: от него можно уйти, но не спрятаться.
func _spawn_hunter() -> void:
	if _hunter != null and is_instance_valid(_hunter):
		return
	if _player == null or not is_instance_valid(_player):
		return
	var f: int = _player.current_floor
	if f < 0 or f >= _grids.size():
		return
	var cell := _guest_far_cell(f, 7)
	if cell.x < 0:
		return
	_spawn_one_enemy(0, cell, f)
	# _spawn_one_enemy добавляет врага последним ребёнком — забираем его,
	# чтобы донастроить. Отдельного «спавни и верни» варианта заводить не стали:
	# лишний параметр в горячей функции ради одного вызова.
	var kids := get_children()
	for i in range(kids.size() - 1, -1, -1):
		var k: Node = kids[i]
		if k.has_method("hear") and "relentless" in k:
			_hunter = k
			break
	if _hunter == null:
		return
	_hunter.relentless = true
	# Медленнее обычного и заметно крупнее: игрок должен опознать его с первого
	# взгляда, а не выяснять экспериментально, кто из врагов не отстаёт.
	if "speed_mult" in _hunter:
		_hunter.speed_mult = 0.75
	_hunter.scale = Vector2(1.35, 1.35)
	_hunter.modulate = Color(1.0, 0.45, 0.75)

func _spawn_one_enemy(type: int, cell: Vector2i, floor_idx: int) -> Node2D:
	var pur := Node2D.new()
	pur.set_script(load("res://pursuer.gd"))
	pur.enemy_type = type
	pur.spawn_level = _level
	pur._enemy_floor = floor_idx
	pur.position = _cell_to_world(cell) + Vector2(0, floor_idx * _floor_gap)
	pur.target = _player
	pur._game = self
	# main — PROCESS_MODE_ALWAYS (ввод на паузе), поэтому враг по наследованию тоже
	# не вставал бы на паузе. Явно делаем его PAUSABLE, чтобы замирал при паузе.
	pur.process_mode = Node.PROCESS_MODE_PAUSABLE
	add_child(pur)
	return pur

# BFS от (0,0) — возвращает до `count` ячеек из дальней половины лабиринта.
func _far_spawn_cells(grid: Array, count: int) -> Array[Vector2i]:
	var start := Vector2i(0, 0)
	var dist_map := {start: 0}
	var queue: Array[Vector2i] = [start]
	var max_d := 0
	while not queue.is_empty():
		var c: Vector2i = queue.pop_front()
		for d in [Vector2i(1,0), Vector2i(-1,0), Vector2i(0,1), Vector2i(0,-1)]:
			var n: Vector2i = c + d
			if n.x < 0 or n.x >= _cols or n.y < 0 or n.y >= _rows or dist_map.has(n):
				continue
			if not grid[c.y + n.y + 1][c.x + n.x + 1]:
				dist_map[n] = dist_map[c] + 1
				max_d = maxi(max_d, dist_map[n])
				queue.append(n)

	# Берём ячейки из дальней половины (BFS-расстояние > max/2)
	var threshold := max_d / 2
	var far: Array[Vector2i] = []
	for k: Vector2i in dist_map.keys():
		if dist_map[k] > threshold:
			far.append(k)
	far.shuffle()
	return far.slice(0, count)

# Строит этаж f (стены/станции/осколки), если он ещё не был построен —
# вызывается один раз для этажа входа и лениво из door.gd перед спуском на
# следующий этаж (см. main.gd для причин: см. комментарий в _build_world).
func _ensure_floor_built(f: int) -> void:
	if _floor_built.get(f, false):
		return
	if f < 0 or f >= _grids.size():
		return
	_floor_built[f] = true
	# [WALLPERF-2026-07] арена босса строится без шардов/станций — тот же флаг,
	# что раньше выставлялся вокруг прямого вызова _build_floor в _setup_boss_door.
	var was_arena := _building_arena
	if _floor_is_arena.get(f, false):
		_building_arena = true
	_build_floor(f, _grids[f])
	_building_arena = was_arena
	if _superboss_level and f == 1 and not _superboss_spawned:
		_superboss_spawned = true
		_spawn_superboss_on_floor1()

func _build_floor(f: int, grid: Array) -> void:
	var container := Node2D.new()
	container.position = Vector2(0, f * _floor_gap)
	# ¾-вид: стены внутри контейнера должны сортироваться по глубине с игроком/
	# врагами (прямыми детьми main) — y_sort рекурсивно объединяет пространства.
	container.y_sort_enabled = true
	add_child(container)
	_floor_containers.resize(maxi(_floor_containers.size(), f + 1))
	_floor_containers[f] = container

	# [TILEMAP-1.8] Один TileMapLayer на этаж рендерит и коллизионирует ВСЕ
	# стены разом (см. _paint_wall_tile/_set_wall/regenerate_floor) — раньше
	# была нода (или несколько) на каждую стену, см. историю коммитов тега
	# WALLPERF-2026-07 для предыдущего (промежуточного) варианта оптимизации.
	var tile_map := TileMapLayer.new()
	tile_map.tile_set = _wall_tileset
	tile_map.y_sort_enabled = true
	container.add_child(tile_map)
	_floor_tilemaps.resize(maxi(_floor_tilemaps.size(), f + 1))
	_floor_tilemaps[f] = tile_map

	if _organic:
		# Органический пол: плавные скруглённые тоннели по форме лабиринта.
		var of := Node2D.new()
		of.set_script(load("res://organic_floor.gd"))
		of.tile = TILE
		of.cols = _cols
		of.rows = _rows
		of.gw = _gw
		of.gh = _gh
		of.col = _organic_color
		of.grid = grid
		container.add_child(of)
		_organic_floors.resize(maxi(_organic_floors.size(), f + 1))
		_organic_floors[f] = of
	else:
		var floor_node := Polygon2D.new()
		floor_node.color = FLOOR_COLOR
		floor_node.polygon = PackedVector2Array([
			Vector2(0, 0),
			Vector2(_gw * TILE, 0),
			Vector2(_gw * TILE, _gh * TILE),
			Vector2(0, _gh * TILE),
		])
		container.add_child(floor_node)

	for gy in _gh:
		for gx in _gw:
			if grid[gy][gx]:
				_paint_wall_tile(tile_map, f, gx, gy)

	_spawn_floor_pickups(f, grid, container)

# Станции (они же чекпоинты) и осколки света. В хард-режиме станций НЕТ —
# свет только из осколков. Вынесено из _build_floor в отдельную функцию,
# т.к. regenerate_floor() тоже должно её вызывать — иначе, как было раньше,
# после перегенерации коридоров (событие «Живой лабиринт»/дверь с regen_chance)
# старые станции/осколки остаются на СТАРЫХ мировых позициях, которые новый
# рисунок стен запросто накрывает стеной: объект есть, но зажат в стене и
# недостижим (см. GAMEDESIGN.md — баг на уровне 25).
func _spawn_floor_pickups(f: int, grid: Array, container: Node2D) -> void:
	if _building_arena:
		return   # арена босса: голые стены, без станций/осколков
	var cells := _passage_cells(f == 0, grid)
	cells.shuffle()
	var area: int = _cols * _rows
	var density: float = float(GameConfig.station_count) / (16 * 10)
	# Растянуто на больше уровней (было ×2.25 уже к 6 уровню — резкий скачок
	# от «богатого» старта к «сушняку»); теперь тот же итоговый максимум к 12.
	var lvl_factor: float = 1.0 + (mini(_level, 24) - 1) * 0.0625
	var scaled: int = max(GameConfig.station_count, int(area * density * lvl_factor))
	# [GAMEDESIGN §46 долг / §53] MAX_STATIONS сам по себе — потолок НА УРОВЕНЬ,
	# а не на этаж: раньше каждый этаж независимо упирался в один и тот же
	# потолок, и уровень с несколькими этажами получал его же, умноженный на
	# число этажей (мега-уровни: 6 этажей × 40 = 240 станций за уровень —
	# Свет переставал быть давлением вообще). Бюджет теперь делится поровну
	# между этажами уровня, так что итог не растёт от одной лишь их прибавки.
	var floor_cap: int = MAX_STATIONS
	if _floors > 1:
		floor_cap = maxi(6, int(ceil(float(MAX_STATIONS) / float(_floors))))
	var count: int = mini(mini(scaled, floor_cap), cells.size())
	if _hard:
		count = 0
	elif GameConfig.run_contract() == "ashes":
		count = maxi(1, count / 2)   # «Пепельный путь»: алтарей вдвое меньше
	# Арена супербосса (§25): фиксированное скромное число станций вместо
	# обычной формулы — она на 34×26 дала бы потолок в MAX_STATIONS (40 штук),
	# что превратило бы арену в поле бесплатного света. И НЕ обнуляем их в
	# «Пылающем»: там правило «станций нет» держится на том, что свет берут
	# из осколков, а осколков на арене нет — иначе финал стал бы непроходим.
	if _superboss_level:
		count = mini(6, cells.size())
	# Снисхождение лабиринта: серия рангов D — первый кристалл гарантированно
	# рядом со стартом (игрок начинает в клетке (0,0) первого этажа).
	if GameConfig.rank_pity_active() and f == 0 and count > 0:
		var best_i := 0
		var best_d := 999999
		for i in cells.size():
			var d: int = absi(cells[i].x) + absi(cells[i].y)
			if d < best_d:
				best_d = d
				best_i = i
		var near: Vector2i = cells[best_i]
		cells.remove_at(best_i)
		cells.insert(0, near)
		call_deferred("flash_message", GameConfig.tt("Лабиринт снисходителен: кристалл ждёт рядом", "The maze shows mercy: a crystal waits nearby"))
	for i in count:
		var st := Area2D.new()
		st.set_script(load("res://station.gd"))
		st.game = self
		st.floor_index = f
		st.position = _cell_to_world(cells[i])
		container.add_child(st)
		_occupied_cells[Vector3i(f, cells[i].x, cells[i].y)] = true

	_spawn_dark_stations(f, cells, count, container)
	_spawn_mimics(f, cells, count, container)
	_spawn_pits(f, grid, container)
	_spawn_intra_shortcut(f, grid, container)
	_spawn_zone_markers(f, grid, container)
	_spawn_structure_marks(f, container)   # [§40] разметка артерии и столпы залов
	_spawn_claim_field(f, container)       # [§41] поле захваченной земли

	# Осколки света (собираемые бонусы). На арене супербосса их нет: осколок —
	# это ключ, открывающий портал-выход (v1.9), а портала на финале нет,
	# победа = смерть босса. Иначе сбор последнего осколка выдал бы игроку
	# бессмысленное «Все осколки собраны! Теперь — к ВЫХОДУ».
	if _superboss_level:
		_shards_remaining.resize(maxi(_shards_remaining.size(), f + 1))
		_shards_remaining[f] = 0
		return
	# [§43] Клетки, уже занятые станциями/тёмными станциями/мимиками, исключены:
	# осколок, лежащий на станции, читается как одна вещь и не подбирается
	# отдельно (жалоба игрока). Занятость собирается в _occupied_cells при
	# расстановке — здесь мы просто её уважаем.
	var shard_cells: Array = []
	for c in _passage_cells(f == 0, grid):
		if not _occupied_cells.has(Vector3i(f, c.x, c.y)):
			shard_cells.append(c)
	if shard_cells.is_empty():
		shard_cells = _passage_cells(f == 0, grid)   # запасной путь: лучше рядом, чем нигде
	shard_cells.shuffle()
	var sc: int = mini(SHARDS_PER_FLOOR, shard_cells.size())
	for i in sc:
		var sh := Area2D.new()
		sh.set_script(load("res://shard.gd"))
		sh.game = self
		sh.position = _cell_to_world(shard_cells[i])
		container.add_child(sh)
		_shards_total += 1
	_shards_remaining.resize(maxi(_shards_remaining.size(), f + 1))
	_shards_remaining[f] = sc   # осколков на этом этаже (для счётчика «осталось»)
	_refresh_exit_lock()

# [§38] Пороги переехали в GameConfig.LADDER — единый реестр «что и когда
# открывается». Здесь остались только те числа, которые лестницей не являются.
const HERDER_ELITE_FROM_LEVEL := 30   # роль Стражу — только на глубине
var _herder_placed: bool = false

# [GAMEDESIGN §34] Мимик — подделка под станцию. Ставится в те же клетки, что
# и станции (station_cells сверх занятых настоящими), чтобы стоял среди них, а
# не в случайном тупике: смысл в том, что ты не можешь на глаз отличить.
# В «Пылающем» станций нет вовсе — там подделка себя мгновенно выдаёт, поэтому
# мимиков тоже нет.
func _spawn_mimics(f: int, station_cells: Array, used: int, container: Node2D) -> void:
	if not _mech_ready("mimics"):
		return
	if _boss_level or _lair_active or _superboss_level or GameConfig.tutorial_mode or _organic or _hard:
		return
	if randf() > _biome_chance("mimics"):
		return
	if used >= station_cells.size():
		return
	var n: int = mini(1 + _biome_cycle(), 2)
	for i in mini(n, station_cells.size() - used):
		var c: Vector2i = station_cells[used + i]
		var m := Area2D.new()
		m.set_script(load("res://mimic.gd"))
		m.game = self
		m.floor_index = f
		m.cell = c
		m.position = _cell_to_world(c)
		container.add_child(m)
		_occupied_cells[Vector3i(f, c.x, c.y)] = true

# Хук для mimic.gd: превратить подделку во врага на её месте.
func spawn_mimic_enemy(cell: Vector2i, f: int) -> void:
	if f < 0 or f >= _grids.size():
		return
	_spawn_one_enemy(1, cell, f)   # FAST: мимик бьёт скоростью, а не бронёй
	if _player and is_instance_valid(_player) and _player.has_method("add_shake"):
		_player.add_shake(6.0, 0.35)

# [§62] Графовый аналог spawn_mimic_enemy — та же роль (FAST на месте
# подделки), но по мировой позиции узла графа, не по клетке сетки.
func spawn_mimic_enemy_graph(pos: Vector2, f: int) -> void:
	var pur := Node2D.new()
	pur.set_script(load("res://pursuer.gd"))
	pur.enemy_type = 1   # FAST
	pur.spawn_level = _level
	pur._enemy_floor = f
	pur.position = pos
	pur.target = _player
	pur._game = self
	pur.process_mode = Node.PROCESS_MODE_PAUSABLE
	add_child(pur)
	if _player and is_instance_valid(_player) and _player.has_method("add_shake"):
		_player.add_shake(6.0, 0.35)

# Тёмные станции (§22, dark_station.gd) — воронки, всасывающие свет, редкие
# в обычной кампании/Накале/Спуске дня. Не на арене босса/Логове/обучении
# (гейт по тем же флагам, что и обычный дверь-босс, main.gd:1510) — новая
# долгосрочная механика не должна путаться с уже насыщенными спецрежимами.
# Ставится в клетки СВЕРХ уже занятых обычными станциями (station_cells[count..]),
# чтобы не оказаться поверх одной из них.
# [GAMEDESIGN §35] В «Пылающем» тёмных станций НЕТ намеренно: они тянут Свет,
# а восполнить его там нечем (станций нет вовсе) — это не сложность, а
# безвыходность. Мимики там же и по обратной причине: подделке под станцию
# нечем маскироваться, если настоящих станций на уровне не бывает.
func _spawn_dark_stations(f: int, station_cells: Array, used: int, container: Node2D) -> void:
	if not _mech_ready("dark_stations"):
		return
	if _boss_level or _lair_active or _superboss_level or GameConfig.tutorial_mode or _organic or _hard:
		return
	# [GAMEDESIGN §26] Шанс больше не общий: тёмные станции — тема Споровых
	# пустот (там их гарантированно 1+), в прочих биомах их нет вовсе.
	if randf() > _biome_chance("dark_stations"):
		return
	if used >= station_cells.size():
		return
	var n: int = mini(1 + _biome_cycle(), 3)
	for i in mini(n, station_cells.size() - used):
		var ds := Area2D.new()
		ds.set_script(load("res://dark_station.gd"))
		ds.game = self
		ds.floor_index = f
		ds.position = _cell_to_world(station_cells[used + i])
		container.add_child(ds)
		_occupied_cells[Vector3i(f, station_cells[used + i].x, station_cells[used + i].y)] = true

# Вероятность — из правил биома (§26), не константа.

# Ямы-провалы (§17.5, pit.gd) — редкая ландшафтная преграда: не стена, не
# проход, требует активного Рывка, чтобы пересечь. Одна на этаж максимум,
# не слишком близко к старту/выходу (иначе рывок понадобится сразу же, без
# разгона — неприятный сюрприз, а не тактическая преграда).
func _spawn_pits(f: int, grid: Array, container: Node2D) -> void:
	if not _mech_ready("pits"):
		return
	# [GAMEDESIGN §35] В «Пылающем» ямы теперь ЕСТЬ. Раньше все тематические
	# механики там отключались одним махом, и самая сложная сложность игралась
	# беднее лёгкой: биомы теряли темы. Яма ничего не делает с экономикой света
	# (это преграда, а не расход), поэтому мешать «нет станций» ей нечем.
	if _boss_level or _lair_active or _superboss_level or GameConfig.tutorial_mode or _organic:
		return
	# [GAMEDESIGN §26] Ямы — тема Багровых недр (гарантированы), в других
	# биомах не появляются: Рывок-как-инструмент осваивается одной полосой.
	if randf() > _biome_chance("pits"):
		return
	var cells := _passage_cells(f == 0, grid)
	cells.shuffle()
	# Второй заход в тему (уровни 16-30, 31-45…) плотнее первого — иначе
	# повторный биом читается как копия уже пройденного.
	var want: int = mini(1 + _biome_cycle(), 3)
	var placed := 0
	var placed_cells: Array[Vector2i] = []
	for c in cells:
		if f == 0 and (absi(c.x - _entry_cell.x) + absi(c.y - _entry_cell.y)) < 4:
			continue
		# Внимание: этаж 0 строится _ensure_floor_built(0) РАНЬШЕ _place_exit() —
		# _exit_cell на этом этапе ещё не тот, что будет на самом деле для этого
		# уровня (см. CLAUDE.md про класс багов со stale _entry_cell/_exit_cell).
		# Проверяем только для этажей, которые строятся ЛЕНИВО через door.gd —
		# к тому моменту _place_exit() уже отработал.
		if f != 0 and f == _exit_floor and (absi(c.x - _exit_cell.x) + absi(c.y - _exit_cell.y)) < 4:
			continue
		# Ямы не должны срастаться в сплошную преграду: две рядом стоящие
		# перекрывают перекрёсток целиком, и обойти его уже нечем.
		if _cell_too_close(c, placed_cells, 4):
			continue
		var pit := StaticBody2D.new()
		pit.set_script(load("res://pit.gd"))
		pit.game = self
		pit.floor_index = f
		pit.position = _cell_to_world(c)
		container.add_child(pit)
		placed_cells.append(c)
		placed += 1
		if placed >= want:
			return

# Вероятность — из правил биома (§26), не константа.
const SHORTCUT_MIN_DIST_CELLS := 8   # манхэттенская дистанция — иначе «срезка» ничего не срезает

# Внутриэтажные порталы-срезки (§17.4, shortcut_portal.gd) — пара телепортов
# НА ОДНОМ этаже (в отличие от обычных дверей между этажами). Секрет, который
# нужно найти: соединяет две достаточно далёкие друг от друга точки этажа.
func _spawn_intra_shortcut(f: int, grid: Array, container: Node2D) -> void:
	if not _mech_ready("shortcut"):
		return
	# [GAMEDESIGN §35] В «Пылающем» срезки тоже включены: они экономят ПУТЬ, а
	# значит и Свет — на сложности без станций это осмысленная находка, а не
	# подарок. Тёмные станции и мимики там по-прежнему выключены (см. их функции).
	if _boss_level or _lair_active or _superboss_level or GameConfig.tutorial_mode or _organic:
		return
	# Овальные уровни (48-49 и кольцо 50-го) держатся на том, что срезки через
	# середину физически нет — игрок обязан пройти почти всё кольцо. Телепорт
	# между двумя точками кольца отменял бы весь смысл этой формы.
	if _oval_level:
		return
	# [GAMEDESIGN §26] Срезки — тема Лазурных шахт (гарантированы), в других
	# биомах их нет: пять уровней подряд игрок реально учится искать пары.
	if randf() > _biome_chance("shortcut"):
		return
	var cells := _passage_cells(f == 0, grid)
	if cells.size() < 2:
		return
	cells.shuffle()
	# Со второго захода в тему — вторая пара порталов на этаже (уровни 16+).
	var want_pairs: int = mini(1 + _biome_cycle() / 2, 2)
	var used: Array[Vector2i] = []
	for _pair in want_pairs:
		var a := Vector2i(-1, -1)
		var b := Vector2i(-1, -1)
		for c in cells:
			if _cell_too_close(c, used, 3):
				continue
			if a.x < 0:
				a = c
				continue
			if absi(c.x - a.x) + absi(c.y - a.y) >= SHORTCUT_MIN_DIST_CELLS:
				b = c
				break
		if a.x < 0 or b.x < 0:
			return
		used.append(a)
		used.append(b)
		var pa := Area2D.new()
		pa.set_script(load("res://shortcut_portal.gd"))
		pa.game = self
		pa.floor_index = f
		pa.position = _cell_to_world(a)
		container.add_child(pa)
		var pb := Area2D.new()
		pb.set_script(load("res://shortcut_portal.gd"))
		pb.game = self
		pb.floor_index = f
		pb.position = _cell_to_world(b)
		container.add_child(pb)
		pa.partner = pb
		pb.partner = pa

# Клетка ближе min_d (манхэттен) к любой из уже занятых. Общий помощник для
# спавнов, которым важно не ставить два объекта вплотную.
func _cell_too_close(c: Vector2i, taken: Array, min_d: int) -> bool:
	for t in taken:
		if absi(c.x - t.x) + absi(c.y - t.y) < min_d:
			return true
	return false

const ZONE_MARKER_PER_ZONE := 4
const ZONE_MARKER_PALETTE := [
	Color(1.0, 0.55, 0.25), Color(0.35, 0.85, 1.0), Color(0.75, 0.35, 1.0), Color(0.4, 1.0, 0.55),
]

# [GAMEDESIGN §17.6] Процедурно размеченные зоны — та же грубая сетка 2×2,
# что уже делит этаж для неоднородной плотности (_carve_zonal_density), но
# только для читаемости: у каждой четверти свой акцентный цвет, несколько
# тусклых декоративных бликов на проходах. Чисто визуально, никакой
# механики — лабиринт читается как последовательность мест, а не шум.
func _spawn_zone_markers(f: int, grid: Array, container: Node2D) -> void:
	if not _mech_ready("zone_markers"):
		return
	if _boss_level or _lair_active or _superboss_level or GameConfig.tutorial_mode or _organic or _hard:
		return
	var zones_x := 2
	var zones_y := 2
	var zone_w: int = maxi(1, _cols / zones_x)
	var zone_h: int = maxi(1, _rows / zones_y)
	var palette: Array = ZONE_MARKER_PALETTE.duplicate()
	palette.shuffle()
	var cells := _passage_cells(f == 0, grid)
	cells.shuffle()
	var per_zone: Dictionary = {}
	for c in cells:
		var zx: int = clampi(c.x / zone_w, 0, zones_x - 1)
		var zy: int = clampi(c.y / zone_h, 0, zones_y - 1)
		var key := Vector2i(zx, zy)
		var n: int = int(per_zone.get(key, 0))
		if n >= ZONE_MARKER_PER_ZONE:
			continue
		per_zone[key] = n + 1
		var col: Color = palette[(zy * zones_x + zx) % palette.size()]
		var m := Sprite2D.new()
		m.texture = MazeTextures.make_light(30)
		m.modulate = Color(col.r, col.g, col.b, 0.16)
		m.position = _cell_to_world(c)
		container.add_child(m)

# Битовая маска открытых сторон стены-клетки (gx,gy) на этаже f.
# Сторона «открыта», если соседняя клетка сетки — проход (grid==false).
# Выход за границы трактуем как стену (закрыто).
# Кардиналы: N=1, E=2, S=4, W=8. Диагонали (для заполнения выпуклых углов):
# NE=16, SE=32, SW=64, NW=128.
func _wall_open_mask(f: int, gx: int, gy: int) -> int:
	var grid: Array = _grids[f]
	var m := 0
	if gy - 1 >= 0 and not grid[gy - 1][gx]:
		m |= 1
	if gx + 1 < _gw and not grid[gy][gx + 1]:
		m |= 2
	if gy + 1 < _gh and not grid[gy + 1][gx]:
		m |= 4
	if gx - 1 >= 0 and not grid[gy][gx - 1]:
		m |= 8
	if gy - 1 >= 0 and gx + 1 < _gw and not grid[gy - 1][gx + 1]:
		m |= 16
	if gy + 1 < _gh and gx + 1 < _gw and not grid[gy + 1][gx + 1]:
		m |= 32
	if gy + 1 < _gh and gx - 1 >= 0 and not grid[gy + 1][gx - 1]:
		m |= 64
	if gy - 1 >= 0 and gx - 1 >= 0 and not grid[gy - 1][gx - 1]:
		m |= 128
	return m

# [TILEMAP-1.8] Крышка+грань теперь одна текстура тайла — см.
# _ensure_wall_tile_source/MazeTextures.make_wall_tile_combined ниже, у
# _add_wall (см. историю коммитов) были отдельные _wall_texture/_wall_face_texture.

# Текстуры боковых граней (кэш на уровень, две ориентации).
func _wall_side_texture(dir: int) -> Texture2D:
	var key := "side_w" if dir < 0 else "side_e"
	if not _wall_tex_cache.has(key):
		match _current_wall_material():
			MAT_ORGANIC:
				_wall_tex_cache[key] = MazeTextures.make_organic_wall_side(int(WALL_SIDE_W), int(TILE), _wall_color, dir)
			MAT_TECHNOCEUM:
				_wall_tex_cache[key] = MazeTextures.make_techno_wall_side(int(WALL_SIDE_W), int(TILE), _wall_color, dir)
			MAT_FLORA:
				_wall_tex_cache[key] = MazeTextures.make_flora_wall_side(int(WALL_SIDE_W), int(TILE), _wall_color, dir)
			_:
				_wall_tex_cache[key] = MazeTextures.make_wall_side(int(WALL_SIDE_W), int(TILE), _wall_color, dir)
	return _wall_tex_cache[key]

# [§49/§50] Материал стен на аренах/Логове/супербоссе всегда нейтральный —
# особая механика не должна путаться со сменой биомной темы.
func _current_wall_material() -> int:
	if _boss_level or _lair_active or _superboss_level:
		return MAT_DEFAULT
	return BIOME_WALL_MATERIAL[_biome % BIOME_WALL_MATERIAL.size()]

# [TILEMAP-1.8] Строит (лениво, кэш по ключу mask*2+with_face) TileSetAtlasSource
# для стены с данной маской: совмещённая текстура крышка+грань (сдвинута вверх
# на WALL_H через texture_origin — тот же визуальный эффект, что раньше давал
# vis.position=(0,-WALL_H) у Sprite2D), физика (полный квадрат клетки) и
# occlusion-полигон (тень) на тайле. Источник переиспользуется всеми клетками
# с одинаковой маской на всех этажах уровня (как раньше кэш _wall_tex_cache).
func _ensure_wall_tile_source(mask: int, with_face: bool, strong: bool = false) -> int:
	var key := mask * 4 + (2 if with_face else 0) + (1 if strong else 0)
	if _wall_tile_source_id.has(key):
		return _wall_tile_source_id[key]
	var color := STRONG_WALL_COLOR if strong else _wall_color
	# [§49/§50] «Крепкие» стены (супербосс) всегда нейтральные независимо от
	# биома — то же правило, что и у _current_wall_material() для арен/Логова.
	var material: int = MAT_DEFAULT if strong else _current_wall_material()
	var tex: CanvasTexture
	match material:
		MAT_ORGANIC:
			tex = MazeTextures.make_organic_wall_tile_combined(int(TILE), int(WALL_H), mask, color, with_face)
		MAT_TECHNOCEUM:
			tex = MazeTextures.make_techno_wall_tile_combined(int(TILE), int(WALL_H), mask, color, with_face)
		MAT_FLORA:
			tex = MazeTextures.make_flora_wall_tile_combined(int(TILE), int(WALL_H), mask, color, with_face)
		_:
			tex = MazeTextures.make_wall_tile_combined(int(TILE), int(WALL_H), mask, color, with_face)
	var src := TileSetAtlasSource.new()
	src.texture = tex
	var total_h := int(TILE) + int(WALL_H)
	src.texture_region_size = Vector2i(int(TILE), total_h)
	var source_id := _wall_tileset.add_source(src)
	src.create_tile(Vector2i.ZERO)
	var td := src.get_tile_data(Vector2i.ZERO, 0)
	td.texture_origin = Vector2i(0, int(WALL_H))
	var half := TILE * 0.5
	var square := PackedVector2Array([
		Vector2(-half, -half), Vector2(half, -half), Vector2(half, half), Vector2(-half, half),
	])
	td.add_collision_polygon(0)
	td.set_collision_polygon_points(0, 0, square)
	# Тень шире тайла на OCCLUDER_OVERLAP по трём сторонам (соседние occluder'ы
	# слегка перекрываются, а не стыкуются впритык — иначе на стыке остаётся
	# суб-пиксельная щель и свет "протекает" сквозь неё ярким квадратиком).
	# Северная (верхняя, -y) сторона расширена ДОПОЛНИТЕЛЬНО на WALL_H: визуальная
	# "крышка" стены нарочно сдвинута вверх на WALL_H через texture_origin (см.
	# выше) — это фейковый 3D-козырёк, накрывающий верхние WALL_H px соседней
	# клетки. Если тень остаётся на истинном плоском квадрате, в этой полосе
	# рисуется графика стены, а тени там нет — свет игрока честно освещает эти
	# пиксели, и получается яркое пятно поверх нарисованной "крышки". Продлевая
	# occluder туда же, куда сдвинута картинка, убираем это рассогласование.
	var occ_half := half + OCCLUDER_OVERLAP
	var occ_top := half + WALL_H
	var occ_square := PackedVector2Array([
		Vector2(-occ_half, -occ_top), Vector2(occ_half, -occ_top),
		Vector2(occ_half, occ_half), Vector2(-occ_half, occ_half),
	])
	var occ_poly := OccluderPolygon2D.new()
	occ_poly.polygon = occ_square
	occ_poly.closed = true
	td.set_occluder(0, occ_poly)
	_wall_tile_source_id[key] = source_id
	return source_id

# Источник-«невидимка» для органических этажей: та же физика+тень, но без
# картинки (визуал там рисует organic_floor.gd своим _draw()).
func _ensure_invisible_wall_source() -> int:
	if _wall_invisible_source_id >= 0:
		return _wall_invisible_source_id
	var t := int(TILE)
	var img := Image.create_empty(t, t, false, Image.FORMAT_RGBA8)   # прозрачный по умолчанию
	var src := TileSetAtlasSource.new()
	src.texture = ImageTexture.create_from_image(img)
	src.texture_region_size = Vector2i(t, t)
	var source_id := _wall_tileset.add_source(src)
	src.create_tile(Vector2i.ZERO)
	var td := src.get_tile_data(Vector2i.ZERO, 0)
	var half := TILE * 0.5
	var square := PackedVector2Array([
		Vector2(-half, -half), Vector2(half, -half), Vector2(half, half), Vector2(-half, half),
	])
	td.add_collision_polygon(0)
	td.set_collision_polygon_points(0, 0, square)
	var occ_half := half + OCCLUDER_OVERLAP
	var occ_square := PackedVector2Array([
		Vector2(-occ_half, -occ_half), Vector2(occ_half, -occ_half),
		Vector2(occ_half, occ_half), Vector2(-occ_half, occ_half),
	])
	var occ_poly := OccluderPolygon2D.new()
	occ_poly.polygon = occ_square
	occ_poly.closed = true
	td.set_occluder(0, occ_poly)
	_wall_invisible_source_id = source_id
	return source_id

# Ставит тайл стены (gx,gy) этажа f в его TileMapLayer. Заменяет прежний
# _add_wall (нода на каждую клетку) — теперь клетка ставится в один
# TileMapLayer на этаж, без единой лишней ноды.
func _paint_wall_tile(tile_map: TileMapLayer, f: int, gx: int, gy: int) -> void:
	if _organic:
		# Органические уровни рисуют стены сами (скруглённые тоннели) — тайлу
		# нужна только коллизия+тень.
		tile_map.set_cell(Vector2i(gx, gy), _ensure_invisible_wall_source(), Vector2i.ZERO)
		return
	var mask := _wall_open_mask(f, gx, gy)
	# Южная грань нужна, когда юг открыт в проход ЛИБО клетка на нижнем краю
	# лабиринта (иначе под сдвинутой крышкой просвечивал бы пол).
	var with_face := (mask & 4) != 0 or gy == _gh - 1
	var strong: bool = _strong_cells.has(f) and (_strong_cells[f] as Dictionary).has(Vector2i(gx, gy))
	tile_map.set_cell(Vector2i(gx, gy), _ensure_wall_tile_source(mask, with_face, strong), Vector2i.ZERO)
	_register_side_cell(f, gx, gy, mask)

# Боковые (восток/запад) грани НЕ рисуются на каждой стене (даже невидимые
# ~8k спрайтов стоили ~35 FPS канвасу GL Compatibility) — только регистрация:
# какие клетки имеют открытую сторону. Рисует их маленький пул спрайтов вокруг
# экрана (_update_side_faces), переиспользуя не больше SIDE_POOL_MAX штук.
func _register_side_cell(f: int, gx: int, gy: int, mask: int) -> void:
	if not WALL_SIDE_FACES:
		return
	while _side_cells.size() <= f:
		_side_cells.append({})
	var cells: Dictionary = _side_cells[f]
	var sides := (1 if (mask & 8) != 0 else 0) | (2 if (mask & 2) != 0 else 0)
	var key := Vector2i(gx, gy)
	if sides != 0:
		cells[key] = sides
	elif cells.has(key):
		cells.erase(key)

# Перспектива от игрока: стена правее игрока показывает ЛЕВУЮ грань, левее —
# ПРАВУЮ. Пул спрайтов раскладывается по стенам вокруг экрана ~8 раз/с;
# за кадром граней нет вовсе — ни узлов, ни стоимости.
var _side_accum: float = 0.0
var _side_cells: Array = []        # floor -> Dictionary{Vector2i(gx,gy) -> sides:int} ([TILEMAP-1.8] раньше Array[Node2D])
var _side_pool: Array = []         # переиспользуемые Sprite2D боковых граней
var _side_pool_parent: Node2D = null
const SIDE_POOL_MAX := 300
const SIDE_NEAR_X := 1150.0
const SIDE_NEAR_Y := 720.0

func _update_side_faces() -> void:
	if not WALL_SIDE_FACES or _player == null or not is_instance_valid(_player):
		return
	var f: int = _player.current_floor
	if f < 0 or f >= _side_cells.size() or f >= _floor_containers.size():
		return
	var container: Node2D = _floor_containers[f]
	if container == null or not is_instance_valid(container):
		return
	# Контейнер этажа сменился (телепорт/перестройка) — пул переезжает.
	if _side_pool_parent != container:
		_side_pool = _side_pool.filter(func(s): return is_instance_valid(s))
		for s in _side_pool:
			if s.get_parent():
				s.get_parent().remove_child(s)
			container.add_child(s)
		_side_pool_parent = container

	var pp: Vector2 = _player.global_position
	var used := 0
	var cells: Dictionary = _side_cells[f]
	for cell: Vector2i in cells:
		if used >= SIDE_POOL_MAX:
			break
		var bp: Vector2 = _grid_to_world(cell.x, cell.y, f)
		if absf(bp.x - pp.x) >= SIDE_NEAR_X or absf(bp.y - pp.y) >= SIDE_NEAR_Y:
			continue
		var sides: int = cells[cell]
		var dir := 0
		if bp.x > pp.x and (sides & 1) != 0:
			dir = -1   # стена правее игрока → видна её западная (левая) грань
		elif bp.x <= pp.x and (sides & 2) != 0:
			dir = 1    # стена левее → восточная (правая) грань
		if dir == 0:
			continue
		var spr: Sprite2D
		if used < _side_pool.size():
			spr = _side_pool[used]
		else:
			spr = Sprite2D.new()
			spr.light_mask = 1   # только общий свет — неон грани запечён
			container.add_child(spr)
			_side_pool.append(spr)
		spr.texture = _wall_side_texture(dir)
		# Со сдвигом -WALL_H/2 спрайт выступает над верхней кромкой своей клетки.
		# Если у соседа СВЕРХУ рисуется та же грань — полоса сплошная, выступ
		# накрыт её спрайтом, резать нельзя (иначе щели на каждом шве). Если
		# продолжения нет (угол/торец стены) — выступ ловит свет ярким
		# «зубчиком» поверх тёмной крышки, поэтому верх обрезаем по кромке.
		var cont: bool = (int(cells.get(cell + Vector2i(0, -1), 0)) & sides & (1 if dir < 0 else 2)) != 0
		if cont:
			spr.region_enabled = false
			spr.position = bp - container.global_position \
				+ Vector2(float(dir) * (TILE * 0.5 + WALL_SIDE_W * 0.5), -WALL_H * 0.5)
		else:
			spr.region_enabled = true
			spr.region_rect = Rect2(0, WALL_H * 0.5, WALL_SIDE_W, TILE - WALL_H * 0.5)
			spr.position = bp - container.global_position \
				+ Vector2(float(dir) * (TILE * 0.5 + WALL_SIDE_W * 0.5), -WALL_H * 0.25)
		spr.visible = true
		used += 1
	for i in range(used, _side_pool.size()):
		var s: Sprite2D = _side_pool[i]
		if is_instance_valid(s):
			s.visible = false

func _place_doors() -> void:
	# [§44] door_pairs = 1 везде и всегда, а первая пара по коду ВСЕГДА открыта —
	# значит запертых дверей в игре не существовало вовсе, ключи копились и не
	# тратились, хотя Кодекс и обучение обещали «осколок — ключ от дверей».
	# Со своего уровня лестницы добавляем вторую, запертую пару: обычная
	# остаётся открытой (тупик невозможен), а осколок получает вторую причину
	# существовать помимо улики — короткий путь вниз.
	var pairs: int = clampi(GameConfig.door_pairs, 1, 4)
	if _mech_ready("locked_doors") and not GameConfig.tutorial_mode:
		pairs = maxi(pairs, 2)
	for f in range(_floors - 1):
		# Порталы ставим в «выемки» — клетки-тупики этого этажа. Если тупиков мало,
		# добиваем обычными проходами, чтобы число порталов не уменьшилось.
		var cells := _dead_end_cells(_grids[f])
		cells.shuffle()
		if cells.size() < pairs:
			var extra := _passage_cells(true)
			extra.shuffle()
			for e in extra:
				if not cells.has(e):
					cells.append(e)
		for p in mini(pairs, cells.size()):
			var c: Vector2i = cells[p]
			var local := _cell_to_world(c)
			# Первая пара (p == 0) всегда открыта — гарантированный путь.
			# Остальные заперты и требуют осколок-ключ.
			var lock := p > 0
			var d_a := _make_door(local + Vector2(0, f * _floor_gap), _floor_gap, f + 1, lock)
			var d_b := _make_door(local + Vector2(0, (f + 1) * _floor_gap), -_floor_gap, f, lock)
			d_a.partner = d_b
			d_b.partner = d_a
			# Запоминаем переход между этажами для поиска пути «Искрой»
			var na := Vector3i(f, c.x, c.y)
			var nb := Vector3i(f + 1, c.x, c.y)
			if not _door_links.has(na):
				_door_links[na] = []
			_door_links[na].append(nb)
			if not _door_links.has(nb):
				_door_links[nb] = []
			_door_links[nb].append(na)

func _make_door(pos: Vector2, dy: float, target_floor: int, locked: bool) -> Area2D:
	var d := Area2D.new()
	d.set_script(load("res://door.gd"))
	d.delta_y = dy
	d.target_floor = target_floor
	d.game = self
	d.locked = locked
	# Перегенерация — только если дверей не меньше 4 (иначе искать проход слишком тяжело)
	var regen_ok: bool = GameConfig.door_regen_enabled and GameConfig.door_pairs >= 4
	d.regen_chance = GameConfig.door_regen_chance if regen_ok else 0.0
	d.position = pos
	add_child(d)
	d.add_to_group("door")
	return d

# Переходы между этажами — односторонние (вниз). После спуска убираем все порталы,
# ведущие на пройденные верхние этажи (target_floor < текущего): назад дороги нет.
func seal_below(floor_idx: int) -> void:
	for dr in get_tree().get_nodes_in_group("door"):
		if is_instance_valid(dr) and dr.target_floor < floor_idx:
			if dr.has_method("vanish"):
				dr.vanish()
			else:
				dr.queue_free()

func _place_exit() -> void:
	var lf := _floors - 1
	var c: Vector2i
	if lf == 0 and _oval_level and _oval_exit.x >= 0:
		# §1: выход овальных уровней — дальний конец кольца, а не случайная
		# BFS-самая-дальняя клетка (которая на кольце и так обычно им и
		# окажется, но явный расчёт надёжнее совпадения).
		c = _oval_exit
	else:
		c = _farthest_cell(_grids[lf], _entry_cell if lf == 0 else Vector2i.ZERO)
	_exit_cell = c
	_exit_floor = lf
	var exit := Area2D.new()
	exit.set_script(load("res://exit.gd"))
	exit.game = self
	exit.position = _cell_to_world(c) + Vector2(0, lf * _floor_gap)
	add_child(exit)
	_exit_node = exit
	_refresh_exit_lock()

func _spawn_player() -> void:
	_player = preload("res://player.tscn").instantiate()
	_player.speed = GameConfig.player_speed
	_player.drain_per_sec = GameConfig.drain_per_sec * _drain_mult * GameConfig.diff_drain_mult()
	_player.max_energy = GameConfig.max_energy
	# Хард-режим: станций нет — запас света удвоен, чтобы уровня хватало впритык
	# (плюс двойные глотки с осколков, см. collect_shard).
	if _hard:
		_player.max_energy *= 2.0
	# Благословение лабиринта: серия рангов S/A — стартовый свет ярче на 15%.
	if GameConfig.rank_blessing_active():
		_player.max_energy *= 1.15
		call_deferred("flash_message", GameConfig.tt("✨ Благословение лабиринта: свет ярче (серия рангов %d)", "✨ Blessing of the maze: light burns brighter (rank streak %d)") % GameConfig.rank_good_streak)
	# Снисхождение в Пылающем (станций нет): вместо кристалла — чуть больше света.
	elif GameConfig.rank_pity_active() and _hard:
		_player.max_energy *= 1.15
		call_deferred("flash_message", GameConfig.tt("Лабиринт снисходителен: света чуть больше", "The maze shows mercy: a bit more light"))
	_player.position = _cell_to_world(_entry_cell)
	# main — PROCESS_MODE_ALWAYS, поэтому игрок по наследованию двигался бы и на
	# паузе. Явно PAUSABLE — замирает вместе с миром при паузе.
	_player.process_mode = Node.PROCESS_MODE_PAUSABLE
	add_child(_player)

	_cp_floor = 0
	_cp_pos = _player.position

	# Дистанция старт->выход — точка отсчёта для лёгкого «дыхания» эмбиента
	# по мере приближения к цели (см. _update_music).
	var exit_pos := _cell_to_world(_exit_cell) + Vector2(0, _exit_floor * _floor_gap)
	_start_exit_dist = maxf(1.0, _player.position.distance_to(exit_pos))

func _farthest_cell(grid: Array, from: Vector2i = Vector2i.ZERO) -> Vector2i:
	var start := from
	var dist := {start: 0}
	var queue: Array[Vector2i] = [start]
	var best := start
	var best_d := 0
	while not queue.is_empty():
		var c: Vector2i = queue.pop_front()
		if dist[c] > best_d:
			best_d = dist[c]
			best = c
		for d in [Vector2i(1, 0), Vector2i(-1, 0), Vector2i(0, 1), Vector2i(0, -1)]:
			var n: Vector2i = c + d
			if n.x < 0 or n.x >= _cols or n.y < 0 or n.y >= _rows or dist.has(n):
				continue
			var mx := c.x + n.x + 1
			var my := c.y + n.y + 1
			if not grid[my][mx]:
				dist[n] = dist[c] + 1
				queue.append(n)
	return best

func _passage_cells(exclude_start: bool, grid: Array = []) -> Array[Vector2i]:
	var arr: Array[Vector2i] = []
	for cy in _rows:
		for cx in _cols:
			if exclude_start and cx == _entry_cell.x and cy == _entry_cell.y:
				continue
			# Если передана сетка — пропускаем клетки-стены (колонны арены босса),
			# иначе объекты спавнятся внутри стены и их не собрать.
			if not grid.is_empty() and grid[cy * 2 + 1][cx * 2 + 1]:
				continue
			arr.append(Vector2i(cx, cy))
	return arr

# Клетки-«выемки» (тупики): проход ровно с ОДНОЙ открытой стороной — естественный
# карман со стенами с трёх сторон. Клетку входа исключаем. Используется для порталов.
func _dead_end_cells(grid: Array) -> Array[Vector2i]:
	var res: Array[Vector2i] = []
	for cy in _rows:
		for cx in _cols:
			if cx == _entry_cell.x and cy == _entry_cell.y:
				continue
			var gx := cx * 2 + 1
			var gy := cy * 2 + 1
			var open := 0
			if gy - 1 >= 0 and not grid[gy - 1][gx]: open += 1
			if gy + 1 < _gh and not grid[gy + 1][gx]: open += 1
			if gx - 1 >= 0 and not grid[gy][gx - 1]: open += 1
			if gx + 1 < _gw and not grid[gy][gx + 1]: open += 1
			if open == 1:
				res.append(Vector2i(cx, cy))
	return res

# [GAMEDESIGN §32 «Награда в моменте»] Множитель за серию осколков без урона.
# Растёт на STREAK_STEP за каждый осколок после первого и упирается в потолок:
# без потолка длинный чистый уровень выдавал бы абсурдные числа, а смысл серии
# в том, чтобы поощрять аккуратность на дистанции 3-7 осколков, а не в том,
# чтобы стать основным источником XP.
const STREAK_STEP := 0.25
const STREAK_MULT_MAX := 2.5

func shard_streak_mult() -> float:
	return minf(1.0 + maxi(_clean_shard_streak - 1, 0) * STREAK_STEP, STREAK_MULT_MAX)

# Показать всплывающую награду на месте события. pos — мировая точка; если её
# не передали (Vector2.INF), берём позицию игрока.
func _show_reward(pos: Vector2, text: String, color: Color, size: int = 16, offset: Vector2 = Vector2.ZERO) -> void:
	if GameConfig.tutorial_mode:
		return   # в обучении и без того плотно от попапов-уроков
	var at: Vector2 = pos
	if at == Vector2.INF or at == Vector2.ZERO:
		if _player == null or not is_instance_valid(_player):
			return
		at = _player.global_position
	var t := Node2D.new()
	t.set_script(load("res://float_text.gd"))
	t.text = text
	t.color = color
	t.font_size = size
	t.global_position = at + offset
	add_child(t)

# Чип серии в HUD: дёргается при росте, чтобы прирост было видно, а не только
# прочитать. Цвет теплеет с длиной серии — к потолку становится золотым.
func _pulse_streak_hud() -> void:
	if _streak_label == null or not is_instance_valid(_streak_label):
		return
	var t := create_tween()
	_streak_label.scale = Vector2(1.25, 1.25)
	t.tween_property(_streak_label, "scale", Vector2.ONE, 0.22)

# [GAMEDESIGN §36 «Слышно и их»] Обратный канал к §31: игрок слышит рык
# охотящегося врага сквозь стены. Зовётся из pursuer раз в ~2.4 с, пока враг
# в CHASE и не заморожен.
#
# ГЛАВНОЕ ОГРАНИЧЕНИЕ: подсказка даёт НАПРАВЛЕНИЕ и НИЧЕГО больше. Кольцо
# рисуется не на враге, а рядом с игроком — на фиксированном расстоянии в
# сторону источника. Иначе это был бы вечный бесплатный сонар: игрок читал бы
# точные позиции всех преследователей сквозь стены, и тьма перестала бы
# работать вовсе. Ни числа врагов, ни дистанции звук не выдаёт.
const HEAR_CUE_DIST := 132.0   # на каком расстоянии от игрока рисуется метка

func enemy_noise(pos: Vector2, radius: float, enemy_floor: int) -> void:
	if _won or _dead or _player == null or not is_instance_valid(_player):
		return
	if int(_player.current_floor) != enemy_floor:
		return   # звук не проходит между этажами
	var hear: float = radius
	if _player.has_method("hearing_mult"):
		hear *= _player.hearing_mult()
	var to: Vector2 = pos - _player.global_position
	if to.length() > hear:
		return
	var dir: Vector2 = to.normalized() if to.length() > 1.0 else Vector2.RIGHT
	var cue := Node2D.new()
	cue.set_script(load("res://noise_ring.gd"))
	cue.radius = 46.0                      # маленькая метка, а не разлив по карте
	cue.color = Color(1.0, 0.35, 0.42)     # багровый = «за тобой», не путать с §31
	cue.dur = 0.85
	cue.global_position = _player.global_position + dir * HEAR_CUE_DIST
	add_child(cue)

# [GAMEDESIGN §31 «Шум»] Громкий навык слышен врагам на своём этаже, даже если
# между вами стена: заметность отвечает за «видно ли тебя», шум — за «слышно
# ли». Это второй канал угрозы, из-за которого каждое нажатие навыка стало
# решением: Сонар покажет планировку, но позовёт Стража.
#
# Зовётся из player.gd после УСПЕШНОГО применения навыка (не при неудачной
# попытке — иначе игрок платил бы шумом за пустое нажатие в кулдаун).
# Радиус в мировых px, dur — сколько секунд враг будет искать источник.
const GROUND_DANGER_HEAR_BONUS := 0.30   # [§41 план 2.x — П5], см. ground_danger()

func make_noise(world_pos: Vector2, radius: float, dur: float = 3.0) -> void:
	if radius <= 0.0 or _won or _dead:
		return
	var f: int = _player.current_floor if _player and is_instance_valid(_player) else 0
	var heard := false
	for e in get_tree().get_nodes_in_group("enemy"):
		if not is_instance_valid(e) or not e.has_method("hear"):
			continue
		# Строго свой этаж: этажи разнесены по мировому Y, и без этой проверки
		# «шум» дотягивался бы до соседнего этажа через _floor_gap.
		if "_enemy_floor" in e and int(e._enemy_floor) != f:
			continue
		# [§41 план 2.x — П5] «Тьма злее там, где ты её отогнал»: враг на
		# свежеотвоёванной клетке слышит чуть дальше — тьма там навострила уши.
		var hear_r: float = radius * (1.0 + GROUND_DANGER_HEAR_BONUS * ground_danger_at(e.global_position, f))
		if e.global_position.distance_to(world_pos) > hear_r:
			continue
		if e.hear(_world_to_cell(world_pos, f), dur):
			heard = true
	# Кольцо рисуем всегда, когда шум был громким: игрок должен видеть радиус
	# и когда рядом никого нет — так он и учит, что тихо, а что нет.
	var ring := Node2D.new()
	ring.set_script(load("res://noise_ring.gd"))
	ring.radius = radius
	ring.color = Color(1.0, 0.55, 0.35) if heard else Color(0.75, 0.85, 1.0)
	ring.position = world_pos - Vector2(0, f * _floor_gap)
	if f < _floor_containers.size() and _floor_containers[f] != null:
		_floor_containers[f].add_child(ring)
	else:
		add_child(ring)

# Обратное к _cell_to_world для мировой точки на этаже f.
func _world_to_cell(world_pos: Vector2, f: int) -> Vector2i:
	var local: Vector2 = world_pos - Vector2(0, f * _floor_gap)
	var gx: int = int(floor((local.x - TILE * 0.5) / TILE))
	var gy: int = int(floor((local.y - TILE * 0.5) / TILE))
	return Vector2i(clampi((gx - 1) / 2, 0, maxi(_cols - 1, 0)), clampi((gy - 1) / 2, 0, maxi(_rows - 1, 0)))

func _cell_to_world(cell: Vector2i) -> Vector2:
	var gx := cell.x * 2 + 1
	var gy := cell.y * 2 + 1
	return Vector2(gx * TILE + TILE * 0.5, gy * TILE + TILE * 0.5)

func _grid_to_world(gx: int, gy: int, f: int) -> Vector2:
	return Vector2(gx * TILE + TILE * 0.5, gy * TILE + TILE * 0.5) + Vector2(0, f * _floor_gap)

# Мировые границы (Rect2) лабиринта на этаже f — для ограничения камеры по краям.
# Этаж f смещён по Y на f*_floor_gap; сетка занимает _gw×_gh клеток по TILE.
func floor_world_bounds(f: int) -> Rect2:
	var top: float = f * _floor_gap
	return Rect2(Vector2(0.0, top), Vector2(_gw * TILE, _gh * TILE))

# Высота верхней HUD-полосы (лог. px = мировые единицы при zoom 1). Камера резервирует
# её сверху, чтобы граница лабиринта и игрок не заходили под HUD.
func hud_top_inset() -> float:
	return HUD_BAND

# Соседние клетки-проходы для поиска пути «Искрой»: открытые проходы текущего
# этажа + переходы через двери на соседние этажи. node = Vector3i(этаж, cx, cy).
func _cell_neighbors(node: Vector3i) -> Array:
	var res: Array = []
	var f: int = node.x
	var cx: int = node.y
	var cy: int = node.z
	var grid: Array = _grids[f]
	for d in [Vector2i(1, 0), Vector2i(-1, 0), Vector2i(0, 1), Vector2i(0, -1)]:
		var nx: int = cx + d.x
		var ny: int = cy + d.y
		if nx < 0 or nx >= _cols or ny < 0 or ny >= _rows:
			continue
		# стена между клетками — на серединной координате сетки; false = проход
		if not grid[cy + ny + 1][cx + nx + 1]:
			res.append(Vector3i(f, nx, ny))
	if _door_links.has(node):
		for nb in _door_links[node]:
			res.append(nb)
	return res

# Кратчайший путь (мировые точки) от позиции игрока к выходу — для «Искры».
# BFS по клеткам всех этажей; путь обрезается по первому переходу на другой
# этаж, чтобы огонёк вёл по текущему этажу к нужной двери (или к выходу).
func _show_start_hint() -> void:
	await get_tree().create_timer(1.6).timeout
	GameConfig.start_hint_shown = true
	# [SAVE-SAFETY 2026-07-06] Раньше save_game() здесь срабатывало БЕЗУСЛОВНО,
	# не проверяя test_mode (в отличие от большинства мест, где test_mode
	# подавляет запись) — оконный харнесс на уровне 1, провисевший даже пару
	# секунд реального времени, перезаписывал НАСТОЯЩЕЕ сохранение игрока
	# тестовым/обнулённым состоянием GameConfig. Реальный инцидент: прогресс
	# (уровень 45, XP, навыки) был потерян именно так. test_mode обязан
	# защищать от побочной записи — здесь тоже.
	if not GameConfig.test_mode:
		GameConfig.save_game()
	if not is_instance_valid(_player):
		return
	var path: PackedVector2Array = guide_path_to_exit(_player.global_position, _player.current_floor)
	if path.size() < 2:
		return
	var spark := Node2D.new()
	spark.set_script(load("res://spark.gd"))
	spark.path_points = path
	add_child(spark)

func guide_path_to_exit(from_pos: Vector2, from_floor: int) -> PackedVector2Array:
	if from_floor < 0 or from_floor >= _grids.size():
		return PackedVector2Array()
	var sx: int = clampi(int(round((from_pos.x / TILE - 1.5) / 2.0)), 0, _cols - 1)
	var sy: int = clampi(int(round(((from_pos.y - from_floor * _floor_gap) / TILE - 1.5) / 2.0)), 0, _rows - 1)
	var start := Vector3i(from_floor, sx, sy)

	# v1.9: приоритет цели — сначала непойманные осколки-ключи (на любом уже
	# построенном этаже), и только когда все собраны (goals пуст) — сам
	# портал-выход. Так игрок сначала идёт за ключами, а не утыкается в
	# запертый портал.
	var goals := {}
	for sh in get_tree().get_nodes_in_group("shard"):
		if not is_instance_valid(sh):
			continue
		var p := sh.get_parent()
		var sf: int = _floor_containers.find(p)
		if sf < 0:
			sf = from_floor
		var shx: int = clampi(int(round((sh.global_position.x / TILE - 1.5) / 2.0)), 0, _cols - 1)
		var shy: int = clampi(int(round(((sh.global_position.y - sf * _floor_gap) / TILE - 1.5) / 2.0)), 0, _rows - 1)
		goals[Vector3i(sf, shx, shy)] = true
	# [§39] Портал становится целью Искры, ТОЛЬКО когда он найден. Пока
	# неизвестен — Искра ведёт к осколкам, то есть к уликам: она инструмент
	# следствия, а не стрелка «иди сюда, тут выход».
	if goals.is_empty():
		if not exit_located():
			return PackedVector2Array()
		goals[Vector3i(_exit_floor, _exit_cell.x, _exit_cell.y)] = true

	var prev := {}
	var visited := {start: true}
	var queue: Array[Vector3i] = [start]
	var goal_found := Vector3i(-1, -1, -1)
	if goals.has(start):
		goal_found = start
	while not queue.is_empty() and goal_found.x == -1:
		var cur: Vector3i = queue.pop_front()
		for nb in _cell_neighbors(cur):
			if not visited.has(nb):
				visited[nb] = true
				prev[nb] = cur
				queue.append(nb)
				if goals.has(nb):
					goal_found = nb
					break
	if goal_found.x == -1:
		return PackedVector2Array()

	# Восстановить последовательность клеток start -> goal_found
	var cells: Array[Vector3i] = []
	var c: Vector3i = goal_found
	while c != start:
		cells.append(c)
		c = prev[c]
	cells.append(start)
	cells.reverse()

	# Мировые точки, обрезая по первому переходу на другой этаж
	var out := PackedVector2Array()
	out.append(from_pos)
	for cell in cells:
		if cell.x != from_floor:
			break
		out.append(_grid_to_world(cell.y * 2 + 1, cell.z * 2 + 1, from_floor))
	return out

# [§39] Цель Пульса. Раньше он мерил путь до выхода и потому становился
# мёртвым грузом на всю первую половину уровня — навык, купленный за SP,
# ничего не делал, пока не собраны улики. Теперь, пока выход неизвестен,
# Пульс щупает НЕИЗВЕДАННОЕ: пик учащается по мере приближения к ближайшей
# непройденной клетке. Это ровно тот инструмент, который нужен в поиске —
# «куда я ещё не ходил», — и он честно перестаёт быть нужен, когда выход
# найден и цель становится конкретной.
func pulse_path(from_pos: Vector2, from_floor: int) -> PackedVector2Array:
	if exit_located():
		return guide_path_to_exit(from_pos, from_floor)
	if from_floor < 0 or from_floor >= _grids.size():
		return PackedVector2Array()
	var sx: int = clampi(int(round((from_pos.x / TILE - 1.5) / 2.0)), 0, _cols - 1)
	var sy: int = clampi(int(round(((from_pos.y - from_floor * _floor_gap) / TILE - 1.5) / 2.0)), 0, _rows - 1)
	var start := Vector3i(from_floor, sx, sy)
	var prev := {}
	var visited := {start: true}
	var queue: Array[Vector3i] = [start]
	var goal := Vector3i(-1, -1, -1)
	while not queue.is_empty() and goal.x == -1:
		var cur: Vector3i = queue.pop_front()
		for nb in _cell_neighbors(cur):
			if visited.has(nb):
				continue
			visited[nb] = true
			prev[nb] = cur
			queue.append(nb)
			if not _visited.has(nb):
				goal = nb
				break
	if goal.x == -1:
		return PackedVector2Array()
	var cells: Array[Vector3i] = []
	var c: Vector3i = goal
	while c != start:
		cells.append(c)
		c = prev[c]
	cells.append(start)
	cells.reverse()
	var out := PackedVector2Array()
	out.append(from_pos)
	for cell in cells:
		if cell.x != from_floor:
			break
		out.append(_grid_to_world(cell.y * 2 + 1, cell.z * 2 + 1, from_floor))
	return out

func _mark_visited() -> void:
	if _player == null or not is_instance_valid(_player):
		return
	var f: int = _player.current_floor
	# [§62, v.4.2] Графовые Пещеры: владение адресуется по узлу графа, не по
	# клетке сетки-заглушки — сама claim/decay-логика ниже (_claim/
	# is_claimed/claim_strength/ground_danger) не меняется вообще, она уже
	# работает с произвольным Vector3i-ключом (см. cave_claim.gd, шаг 4
	# часть 3); здесь узел просто кодируется как Vector3i(f, node_idx, 0) —
	# не заводим отдельный Vector2i-путь ради того, чтобы не трогать
	# сигнатуры четырёх функций ради одного вызывающего места.
	if _caves_graph_active:
		var nodes: Array = _cave_graph.get("nodes", [])
		if nodes.is_empty():
			return
		var local_pos: Vector2 = _player.global_position - Vector2(0, f * _floor_gap)
		var node_idx: int = CaveClaim.nearest_node(nodes, local_pos)
		var key := Vector3i(f, node_idx, 0)
		_visited[key] = true
		if _player.has_method("set_ground_claimed"):
			_player.set_ground_claimed(is_claimed(key))
		_claim(key)
		return
	var px: float = _player.global_position.x
	var py: float = _player.global_position.y - f * _floor_gap
	var cx: int = int(round((px / TILE - 1.5) / 2.0))
	var cy: int = int(round((py / TILE - 1.5) / 2.0))
	if cx >= 0 and cx < _cols and cy >= 0 and cy < _rows:
		var key := Vector3i(f, cx, cy)
		_visited[key] = true
		# Порядок важен: сначала спрашиваем, БЫЛА ли клетка своей, и только
		# потом захватываем её заново. Иначе игрок всегда стоял бы на «своей»
		# земле — просто потому, что шаг сюда её и захватил.
		if _player.has_method("set_ground_claimed"):
			_player.set_ground_claimed(is_claimed(key))
		_claim(key)

# ══ §41 «ТЬМА ОТБИРАЕТ ТЕРРИТОРИЮ» (план 2.x, П2) ═══════════════════════════
# Второй глагол игры — БОРОТЬСЯ ВО ТЬМЕ — до сих пор не существовал как
# действие. Тьма ничего не делала: она была декорацией и таймером расхода
# света. Бороться можно только с тем, что давит в ответ.
#
# Теперь пройденная клетка ОСТАЁТСЯ ТЛЕТЬ — это захваченная земля. Тьма
# отвоёвывает её обратно, и тем быстрее, чем ярче и заметнее игрок
# (visibility_factor: стойка света, вспышка, ореол Накала; Тление, наоборот,
# держит землю дольше всех). Так свет впервые становится не только тем, что
# ты тратишь, но и тем, что ты УДЕРЖИВАЕШЬ.
#
# Цена вопроса — не только вид: на своей земле Свет течёт медленнее, на
# отвоёванной тьмой — быстрее (player.gd, CLAIM_DRAIN_*). Отсюда решение,
# которого раньше не было: разогнать свет и видеть больше, теряя тыл, — или
# пригаситься и удержать коридор за спиной.
#
# _visited (память карты) и _claim_time (владение) РАЗДЕЛЕНЫ намеренно.
# Если бы тьма стирала и память, Пульс со своим «веди к неизведанному» (§39.1)
# гнал бы игрока назад по уже пройденному, а поиск превратился бы в бег по
# кругу. Тьма отнимает землю, но не отнимает то, что ты уже понял.
const CLAIM_TTL_BASE := 40.0     # секунд держится клетка при ровной видимости
const CLAIM_TTL_MIN := 8.0
var _claim_time: Dictionary = {}   # Vector3i -> _elapsed в момент захвата
var _claim_first_time: Dictionary = {}   # Vector3i -> _elapsed НАЧАЛА текущего непрерывного стрика владения (§59)
var _claim_layers: Array = []      # Node2D-поле следа на каждый этаж

# Механика выключена там, где она мешала бы поставленной режиссуре: обучение
# (первые уроки должны быть простыми), арены и Логово (там своя сцена).
func _claim_enabled() -> bool:
	# [§42] Обучение включено: новый шаг обучения показывает именно след.
	return not (_boss_level or _lair_active or _superboss_level or _boss_arena_mode)

func _claim(key: Vector3i) -> void:
	if not _claim_enabled():
		return
	# [GAMEDESIGN §59, П7 «Тлеющий очаг»] Момент начала ТЕКУЩЕГО непрерывного
	# владения — отдельно от _claim_time (который хранит момент ПОСЛЕДНЕГО
	# подтверждения и переписывается при каждом шаге по своей земле). Если
	# клетка уже была своей — стрик продолжается, отметка не двигается. Если
	# нет (стрик оборвался или это первый заход) — начинаем заново. Порядок
	# критичен: спросить ДО того, как _claim_time перезапишется ниже — тот
	# же принцип, что уже описан в _mark_visited для set_ground_claimed.
	if not is_claimed(key):
		_claim_first_time[key] = _elapsed
	_claim_time[key] = _elapsed

# Сколько держится земля ИМЕННО СЕЙЧАС. Ярче игрок — короче срок: свет, которым
# ты себя выдаёшь, и есть то, на что тьма реагирует.
func claim_ttl() -> float:
	var vis := 1.0
	if _player and is_instance_valid(_player) and _player.has_method("visibility_factor"):
		vis = maxf(0.25, _player.visibility_factor())
	return maxf(CLAIM_TTL_MIN, CLAIM_TTL_BASE / vis)

# 1.0 — только что захвачено, 0.0 — тьма отвоевала.
func claim_strength(key: Vector3i) -> float:
	if not _claim_time.has(key):
		return 0.0
	var age: float = _elapsed - float(_claim_time[key])
	var ttl := claim_ttl()
	if age >= ttl:
		return 0.0
	return clampf(1.0 - age / ttl, 0.0, 1.0)

func is_claimed(key: Vector3i) -> bool:
	return claim_strength(key) > 0.0

# [GAMEDESIGN §41 «Чего НЕ делали» / план 2.x — П5] «Тьма злее там, где ты её
# отогнал»: клетка, которую тьма СОВСЕМ НЕДАВНО отвоевала, даёт врагам рядом
# чуть более острые чувства — она ещё «помнит» присутствие. Свежесть считаем
# от того же _claim_time, не заводя отдельный словарь: клетка не в дневнике
# владения вовсе (никогда не была захвачена) → опасности нет, это просто
# нейтральная тьма, а не отвоёванная.
const LOST_WINDOW := 12.0   # сколько секунд после потери клетка «свежо опасна»

# 1.0 — только что потеряна, 0.0 — либо ещё своя, либо потеряна давно.
# Горящая метка (§52) держит _claim_time свежим, пока горит, поэтому на её
# клетке age < ttl всегда — danger возвращает 0.0 сам собой, без спецкода.
func ground_danger(key: Vector3i) -> float:
	if not _claim_time.has(key):
		return 0.0
	var age: float = _elapsed - float(_claim_time[key])
	var ttl := claim_ttl()
	if age < ttl:
		return 0.0   # ещё своя — не потеряна
	var since_loss: float = age - ttl
	if since_loss >= LOST_WINDOW:
		return 0.0
	return clampf(1.0 - since_loss / LOST_WINDOW, 0.0, 1.0)

func ground_danger_at(world_pos: Vector2, f: int) -> float:
	if not _claim_enabled():
		return 0.0
	if _caves_graph_active:
		var nodes: Array = _cave_graph.get("nodes", [])
		if nodes.is_empty():
			return 0.0
		var local_pos: Vector2 = world_pos - Vector2(0, f * _floor_gap)
		var node_idx: int = CaveClaim.nearest_node(nodes, local_pos)
		return ground_danger(Vector3i(f, node_idx, 0))
	var c: Vector2i = _world_to_cell(world_pos, f)
	return ground_danger(Vector3i(f, c.x, c.y))

# [GAMEDESIGN §59, план «после 2.x» — П7] «Тлеющий очаг» — симметричная
# награда к Соглядатаю (§57): вместо порога свежей ПОТЕРИ земли — порог
# длительного НЕПРЕРЫВНОГО владения. 0.0, пока клетка не своя ИЛИ стрик
# моложе DEVOTION_THRESHOLD; 1.0 по достижении порога (без угасания — это
# разовый триггер «уже заслужил», а не убывающая величина, как у danger).
const DEVOTION_THRESHOLD := 45.0   # секунд непрерывного, не прерывавшегося владения

func ground_devotion(key: Vector3i) -> float:
	if not is_claimed(key):
		return 0.0
	if not _claim_first_time.has(key):
		return 0.0
	var held: float = _elapsed - float(_claim_first_time[key])
	return clampf(held / DEVOTION_THRESHOLD, 0.0, 1.0)

# [GAMEDESIGN §57, план «после 2.x» — П6] «Соглядатай»: враг, которого
# рождает сама брошенная территория. Не случайный шанс за тик (CLAUDE.md
# прямо запрещает новую *_CHANCE-константу под мехнику) — порог: если
# СРАЗУ несколько соседних клеток около игрока свежепотеряны, это читается
# как «беспечно бросил кусок земли», а не «пара клеток просто состарилась».
# Реагирует на состояние, которое и так уже посчитано в _claim_time —
# ни отдельного журнала событий, ни лишнего словаря.
const WATCHER_CHECK_INTERVAL := 3.0    # как часто вообще проверяем условие
const WATCHER_DANGER_THRESHOLD := 4    # столько свежих (см. WATCHER_FRESH_MIN) клеток разом — повод
const WATCHER_FRESH_MIN := 0.7         # "свежих" = потеряны совсем недавно, не на исходе LOST_WINDOW
const WATCHER_RADIUS_CELLS := 10       # где вообще ищем кандидатов — вокруг игрока
const WATCHER_MAX_PER_FLOOR := 2       # [урок §53/MAX_STATIONS] жёсткий потолок — не мега-уровню плодиться
const WATCHER_SPAWN_COOLDOWN := 25.0

var _watcher_check_t: float = 0.0
var _watcher_cd: float = 0.0

const WATCHER_RADIUS_WORLD := TILE * 20.0   # графовый аналог WATCHER_RADIUS_CELLS в мировых юнитах

func _update_watchers(delta: float) -> void:
	if not _mech_ready("watcher") or not _claim_enabled():
		return
	if _player == null or not is_instance_valid(_player):
		return
	_watcher_cd = maxf(0.0, _watcher_cd - delta)
	_watcher_check_t -= delta
	if _watcher_check_t > 0.0:
		return
	_watcher_check_t = WATCHER_CHECK_INTERVAL
	if _watcher_cd > 0.0:
		return
	var f: int = _player.current_floor
	var on_floor := 0
	for e in get_tree().get_nodes_in_group("enemy"):
		# Группа "enemy" делят и антистанции/тёмные станции/гости (§25/§34) —
		# у них нет ни stationary, ни _enemy_floor, отсюда проверка "in e".
		if is_instance_valid(e) and "_enemy_floor" in e and bool(e.get("stationary")) and int(e._enemy_floor) == f:
			on_floor += 1
	if on_floor >= WATCHER_MAX_PER_FLOOR:
		return

	# [§62, v.4.2] Графовая версия: адресация по узлу (cave_claim.gd,
	# ключ Vector3i(f,node_idx,0), уже используется _mark_visited/
	# ground_danger_at), позиция — РЕАЛЬНЫЙ узел графа, не приближённая
	# клетка сетки-заглушки — тот класс риска, что раньше держал эту
	# функцию выключенной, здесь не возникает вовсе.
	if _caves_graph_active:
		var nodes: Array = _cave_graph.get("nodes", [])
		if nodes.is_empty():
			return
		var candidates_g: Array = _fresh_danger_nodes_near_player_graph(nodes)
		if candidates_g.size() < WATCHER_DANGER_THRESHOLD:
			return
		var idx: int = candidates_g[randi() % candidates_g.size()]
		_spawn_watcher_graph(nodes[idx], f)
		_watcher_cd = WATCHER_SPAWN_COOLDOWN
		return

	var candidates: Array = _fresh_danger_cells_near_player(f, WATCHER_RADIUS_CELLS)
	if candidates.size() < WATCHER_DANGER_THRESHOLD:
		return
	# [BUGFIX v3.8] _claim_time может пережить перерисовку коридоров этажа
	# (regenerate_floor чистит _visited, но не владение) — клетка, бывшая
	# проходом в момент захвата, к моменту спавна вполне может оказаться
	# стеной нового рисунка. Тот же класс бага, что раньше ловил станции и
	# осколки (см. §25/GAMEDESIGN, «баг на уровне 25»); фильтруем по
	# ТЕКУЩЕЙ сетке, а не доверяем словарю на слово.
	var safe: Array = []
	for c in candidates:
		if _cell_is_passage(f, c):
			safe.append(c)
	if safe.size() < WATCHER_DANGER_THRESHOLD:
		return
	var cell: Vector2i = safe[randi() % safe.size()]
	_spawn_watcher(cell, f)
	_watcher_cd = WATCHER_SPAWN_COOLDOWN

# Узлы графа рядом с игроком, чья потеря ещё совсем свежа — графовый
# аналог _fresh_danger_cells_near_player. Ключи _claim_time для графовых
# Пещер имеют вид Vector3i(f, node_idx, 0) — см. _mark_visited.
func _fresh_danger_nodes_near_player_graph(nodes: Array) -> Array:
	var out: Array = []
	if _player == null or not is_instance_valid(_player):
		return out
	var player_pos: Vector2 = _player.global_position
	for key in _claim_time:
		if not (key is Vector3i):
			continue
		var k: Vector3i = key
		if k.x != 0 or k.z != 0:
			continue
		if k.y < 0 or k.y >= nodes.size():
			continue
		var pos: Vector2 = nodes[k.y]
		if pos.distance_to(player_pos) > WATCHER_RADIUS_WORLD:
			continue
		if ground_danger(k) >= WATCHER_FRESH_MIN:
			out.append(int(k.y))
	return out

# Графовый аналог _spawn_watcher — та же роль (реюз SLOW + stationary),
# просто по мировой позиции узла, не через _spawn_one_enemy(cell).
func _spawn_watcher_graph(pos: Vector2, f: int) -> void:
	var pur := Node2D.new()
	pur.set_script(load("res://pursuer.gd"))
	pur.enemy_type = 0   # SLOW
	pur.spawn_level = _level
	pur._enemy_floor = f
	pur.position = pos
	pur.target = _player
	pur._game = self
	pur.process_mode = Node.PROCESS_MODE_PAUSABLE
	pur.stationary = true
	pur.modulate = Color(0.55, 0.35, 0.78, 0.92)
	pur.scale = Vector2(0.92, 0.92)
	add_child(pur)

# Клетка (в логических координатах _cols/_rows, не в сетке стен) — проход
# в АКТУАЛЬНОЙ сетке этажа f прямо сейчас? Используется там, где данные
# могли протухнуть между моментом записи и моментом чтения (см. выше).
func _cell_is_passage(f: int, cell: Vector2i) -> bool:
	if f < 0 or f >= _grids.size():
		return false
	if cell.x < 0 or cell.x >= _cols or cell.y < 0 or cell.y >= _rows:
		return false
	var grid: Array = _grids[f]
	var gy: int = cell.y * 2 + 1
	var gx: int = cell.x * 2 + 1
	if gy < 0 or gy >= grid.size() or gx < 0 or gx >= grid[gy].size():
		return false
	return not bool(grid[gy][gx])

# Клетки рядом с игроком, чья потеря ещё совсем свежа (см. ground_danger).
# Радиус — в клетках сетки, не в мировых пикселях, как у claim_cells_near.
func _fresh_danger_cells_near_player(f: int, radius: int) -> Array:
	var out: Array = []
	if _player == null or not is_instance_valid(_player):
		return out
	var px: int = int(round((_player.global_position.x / TILE - 1.5) / 2.0))
	var py: int = int(round(((_player.global_position.y - f * _floor_gap) / TILE - 1.5) / 2.0))
	for key in _claim_time:
		if key.x != f:
			continue
		if absi(key.y - px) > radius or absi(key.z - py) > radius:
			continue
		if ground_danger(key) >= WATCHER_FRESH_MIN:
			out.append(Vector2i(key.y, key.z))
	return out

# Соглядатай реюзает тип SLOW (тот же приём, что у Ловчего — _spawn_hunter):
# новый Type в пяти индексируемых по типу массивах ради одного реcкина —
# лишняя структурная правка. Отличает его только флаг stationary и тинт.
func _spawn_watcher(cell: Vector2i, f: int) -> void:
	var pur := _spawn_one_enemy(0, cell, f)
	if pur == null:
		return
	pur.set("stationary", true)
	pur.modulate = Color(0.55, 0.35, 0.78, 0.92)   # холодный лиловый — «наблюдатель», не «враг из толпы»
	pur.scale = Vector2(0.92, 0.92)

# [GAMEDESIGN §59, план «после 2.x» — П7] «Тлеющий очаг»: симметричная
# награда к Соглядатаю. Не порог из НЕСКОЛЬКИХ клеток разом (как у
# Соглядатая) — тут порог другого рода: ОДНА клетка, которую игрок держит
# своей непрерывно дольше DEVOTION_THRESHOLD. `_hearth_rewarded` не даёт
# одной и той же клетке кормить игрока бесконечно (не фарм-петля, а
# разовое «уже заслужил»).
const HEARTH_CHECK_INTERVAL := 3.0
const HEARTH_RADIUS_CELLS := 10
const HEARTH_MAX_PER_FLOOR := 1   # [урок §53/MAX_STATIONS] щедро, но не бесконтрольно
const HEARTH_SPAWN_COOLDOWN := 20.0

var _hearth_check_t: float = 0.0
var _hearth_cd: float = 0.0
var _hearth_rewarded: Dictionary = {}   # Vector3i -> true — клетки, уже отдавшие Очаг

func _update_hearths(delta: float) -> void:
	if not _mech_ready("hearth") or not _claim_enabled():
		return
	if _player == null or not is_instance_valid(_player):
		return
	_hearth_cd = maxf(0.0, _hearth_cd - delta)
	_hearth_check_t -= delta
	if _hearth_check_t > 0.0:
		return
	_hearth_check_t = HEARTH_CHECK_INTERVAL
	if _hearth_cd > 0.0:
		return
	var f: int = _player.current_floor
	var on_floor := 0
	for h in get_tree().get_nodes_in_group("hearth"):
		if is_instance_valid(h) and int(h.get("floor_index")) == f:
			on_floor += 1
	if on_floor >= HEARTH_MAX_PER_FLOOR:
		return

	# [§62, v.4.2] Графовая версия — адресация по узлу, позиция реальная
	# (тот же принцип, что у _update_watchers выше).
	if _caves_graph_active:
		var nodes: Array = _cave_graph.get("nodes", [])
		if nodes.is_empty():
			return
		var candidates_g: Array = _devoted_nodes_near_player_graph(nodes)
		if candidates_g.is_empty():
			return
		var idx: int = candidates_g[randi() % candidates_g.size()]
		_spawn_hearth_graph(idx, nodes[idx], f)
		_hearth_cd = HEARTH_SPAWN_COOLDOWN
		return

	var candidates: Array = _devoted_cells_near_player(f, HEARTH_RADIUS_CELLS)
	if candidates.is_empty():
		return
	# [урок §58] сверяем с ТЕКУЩЕЙ сеткой, а не верим словарю на слово.
	var safe: Array = []
	for c in candidates:
		if _cell_is_passage(f, c):
			safe.append(c)
	if safe.is_empty():
		return
	var cell: Vector2i = safe[randi() % safe.size()]
	_spawn_hearth(cell, f)
	_hearth_cd = HEARTH_SPAWN_COOLDOWN

# Узлы графа рядом с игроком, чьё непрерывное владение уже выслужило Очаг —
# графовый аналог _devoted_cells_near_player.
func _devoted_nodes_near_player_graph(nodes: Array) -> Array:
	var out: Array = []
	if _player == null or not is_instance_valid(_player):
		return out
	var player_pos: Vector2 = _player.global_position
	for key in _claim_first_time:
		if not (key is Vector3i):
			continue
		var k: Vector3i = key
		if k.x != 0 or k.z != 0:
			continue
		if k.y < 0 or k.y >= nodes.size():
			continue
		if _hearth_rewarded.has(k):
			continue
		var pos: Vector2 = nodes[k.y]
		if pos.distance_to(player_pos) > WATCHER_RADIUS_WORLD:
			continue
		if ground_devotion(k) >= 1.0:
			out.append(int(k.y))
	return out

# Графовый аналог _spawn_hearth — по индексу/мировой позиции узла.
func _spawn_hearth_graph(idx: int, pos: Vector2, f: int) -> void:
	_hearth_rewarded[Vector3i(f, idx, 0)] = true
	var h := Area2D.new()
	h.set_script(load("res://hearth.gd"))
	h.game = self
	h.floor_index = f
	if f >= _floor_containers.size() or _floor_containers[f] == null:
		return
	_floor_containers[f].add_child(h)
	h.global_position = pos

# Клетки рядом с игроком, чьё непрерывное владение уже выслужило Очаг
# (ground_devotion ≥ 1.0) и которые его ещё не получали.
func _devoted_cells_near_player(f: int, radius: int) -> Array:
	var out: Array = []
	if _player == null or not is_instance_valid(_player):
		return out
	var px: int = int(round((_player.global_position.x / TILE - 1.5) / 2.0))
	var py: int = int(round(((_player.global_position.y - f * _floor_gap) / TILE - 1.5) / 2.0))
	for key in _claim_first_time:
		if key.x != f:
			continue
		if absi(key.y - px) > radius or absi(key.z - py) > radius:
			continue
		if _hearth_rewarded.has(key):
			continue
		if ground_devotion(key) >= 1.0:
			out.append(Vector2i(key.y, key.z))
	return out

func _spawn_hearth(cell: Vector2i, f: int) -> void:
	_hearth_rewarded[Vector3i(f, cell.x, cell.y)] = true
	var h := Area2D.new()
	h.set_script(load("res://hearth.gd"))
	h.game = self
	h.floor_index = f
	if f >= _floor_containers.size() or _floor_containers[f] == null:
		return
	_floor_containers[f].add_child(h)
	h.global_position = _cell_to_world(cell) + Vector2(0, f * _floor_gap)

# Вызывается hearth.gd при подборе — та же роль, что beacon_reward у маяка.
func hearth_reward() -> void:
	flash_message(GameConfig.tt("🔥 Тлеющий очаг: капля Воли за верность земле", "🔥 Smouldering Hearth: a drop of Will for loyal ground"))
	if _fx:
		_fx.gold_pulse(0.8)

# Цвет тлеющей земли: у своей — тёплый живой тон, у угасающей — холодный.
# Игрок должен видеть НЕ только «есть след/нет следа», а как он гаснет.
func claim_color(s: float) -> Color:
	var warm := Color(1.0, 0.78, 0.42)
	var cold := Color(0.30, 0.52, 0.85)
	var c := cold.lerp(warm, s)
	# Альфа поднята после замера скриншотом: на 0.05-0.21 след физически был,
	# но глазами не читался — особенно рядом со столпом зала, который его
	# перебивал. Тот же провал, что был у первой версии ориентира (§40).
	return Color(c.r, c.g, c.b, 0.12 + 0.38 * s)

# Клетки следа рядом с игроком — для отрисовки одним _draw (claim_field.gd).
# Отдаём уже посчитанную силу: узел-поле не должен знать про формулы времени.
func claim_cells_near(f: int, radius: int) -> Array:
	var out: Array = []
	if _player == null or not is_instance_valid(_player) or not _claim_enabled():
		return out
	var pf: int = _player.current_floor
	if pf != f:
		return out
	var px: int = int(round((_player.global_position.x / TILE - 1.5) / 2.0))
	var py: int = int(round(((_player.global_position.y - pf * _floor_gap) / TILE - 1.5) / 2.0))
	var ttl := claim_ttl()
	var expired: Array = []
	for key in _claim_time:
		if key.x != f:
			continue
		if absi(key.y - px) > radius or absi(key.z - py) > radius:
			continue
		var age: float = _elapsed - float(_claim_time[key])
		# [§41 план 2.x П5] Запись держим ЕЩЁ LOST_WINDOW секунд сверх ttl —
		# именно за это время ground_danger() читает «свежесть» потери. Стереть
		# раньше значило бы, что клетка перестаёт быть опасной раньше, чем
		# перестаёт быть свежепотерянной.
		if age >= ttl + LOST_WINDOW:
			expired.append(key)   # чистим на месте: словарь не должен пухнуть
			continue
		out.append([Vector2i(key.y, key.z), clampf(1.0 - age / ttl, 0.0, 1.0)])
	for k in expired:
		_claim_time.erase(k)
		_claim_first_time.erase(k)   # [§59] стрик владения кончился вместе с самим владением
	return out

# [§41] Один узел-поле на этаж: весь тлеющий след рисуется его единственным
# _draw(), а не спрайтом на клетку (см. комментарий в claim_field.gd).
func _spawn_claim_field(f: int, container: Node2D) -> void:
	if not _claim_enabled():
		return
	var cf := Node2D.new()
	cf.set_script(load("res://claim_field.gd"))
	cf.game = self
	cf.floor_index = f
	cf.tile = TILE
	container.add_child(cf)
	_claim_layers.resize(maxi(_claim_layers.size(), f + 1))
	_claim_layers[f] = cf

# [GAMEDESIGN §45, часть 2] Горящая метка: игрок жертвует куском самого
# Света (а не Воли, как все остальные навыки — см. player.gd:_try_mark),
# чтобы приколоть клетку под ногами. Приколотая клетка держит владение,
# ПОКА жив узел mark.gd — он раз в секунду заново зовёт _claim(key), и
# возраст записи не успевает вырасти, так что claim_ttl (зависящий от
# видимости) её не берёт. Ни новый словарь, ни правки claim_strength не
# понадобились — метка просто "подкармливает" уже существующий механизм.
func place_mark() -> bool:
	if not _claim_enabled():
		return false
	if _player == null or not is_instance_valid(_player):
		return false
	var f: int = _player.current_floor
	if f < 0 or f >= _floor_containers.size() or _floor_containers[f] == null:
		return false
	# [BUGFIX 01.08.2026, §62] Клеточный ключ/позиция (_cell_to_world по
	# приближённой клетке сетки-заглушки) не совпадают с тем, что читает
	# claim-система на графовых Пещерах (Vector3i(f,node_idx,0), см.
	# _mark_visited/ground_danger_at) — метка визуально уезжала бы не туда
	# и физически НЕ держала бы владение (_claim писал в ключ, который
	# больше никто не читает). Тот же класс несоответствия, что уже
	# чинили для Соглядатая/Очага.
	var key: Vector3i
	var pos: Vector2
	if _caves_graph_active:
		var nodes: Array = _cave_graph.get("nodes", [])
		if nodes.is_empty():
			return false
		var local_pos: Vector2 = _player.global_position - Vector2(0, f * _floor_gap)
		var node_idx: int = CaveClaim.nearest_node(nodes, local_pos)
		key = Vector3i(f, node_idx, 0)
		pos = nodes[node_idx] + Vector2(0, f * _floor_gap)
	else:
		var px: int = int(round((_player.global_position.x / TILE - 1.5) / 2.0))
		var py: int = int(round(((_player.global_position.y - f * _floor_gap) / TILE - 1.5) / 2.0))
		key = Vector3i(f, px, py)
		pos = _cell_to_world(Vector2i(px, py)) + Vector2(0, f * _floor_gap)
	_claim(key)
	var m := Node2D.new()
	m.set_script(load("res://mark.gd"))
	m.game = self
	m.mark_key = key
	_floor_containers[f].add_child(m)
	m.global_position = pos
	return true

# [§42] Счётчики владения землёй для ранга: сколько замеров игрок простоял на
# своей, ещё не отвоёванной территории. Считаем здесь, потому что этот сэмплер
# уже тикает раз в полсекунды — отдельный таймер был бы дублированием.
var _ground_samples: int = 0
var _own_ground_samples: int = 0

func _sample_heat() -> void:
	if _player == null or not is_instance_valid(_player):
		return
	if _claim_enabled():
		_ground_samples += 1
		if _player.has_method("on_own_ground") and _player.on_own_ground():
			_own_ground_samples += 1
	var f: int = _player.current_floor
	var px: float = _player.global_position.x
	var py: float = _player.global_position.y - f * _floor_gap
	var cx: int = int(round((px / TILE - 1.5) / 2.0))
	var cy: int = int(round((py / TILE - 1.5) / 2.0))
	if cx >= 0 and cx < _cols and cy >= 0 and cy < _rows:
		var k := Vector3i(f, cx, cy)
		_heat_map[k] = _heat_map.get(k, 0.0) + 0.5

# «Эхо времени» (§7) — только этаж входа (floor 0): у мега-лабиринтов число
# этажей может отличаться между забегами, а «эхо» привязано к номеру уровня,
# не к конкретной сборке лабиринта, — этаж 0 есть всегда и с ним всё просто.
func _sample_echo_trail() -> void:
	if _player == null or not is_instance_valid(_player):
		return
	if int(_player.current_floor) != 0:
		return
	if _echo_trail_now.size() >= ECHO_TRAIL_MAX_SAMPLES:
		return
	var fx: float = clampf(_player.global_position.x / (TILE * 2.0 * maxf(1.0, float(_cols))), 0.0, 1.0)
	var fy: float = clampf(_player.global_position.y / (TILE * 2.0 * maxf(1.0, float(_rows))), 0.0, 1.0)
	_echo_trail_now.append(Vector2(fx, fy))

# Раскладывает тусклые метки-отпечатки прошлого забега на этом же номере
# уровня (этаж 0). Нормализованные координаты не гарантируют попадание точно
# в проход на другой планировке — попавшие в стену клетки просто пропускаются,
# так что показывается лишь то, что реально совпало (частично, но честно).
func _spawn_time_echoes() -> void:
	if not GameConfig.echo_time_enabled:
		return
	if GameConfig.tutorial_mode or _lair_active or _superboss_level or _hard or _organic:
		return
	if _floor_containers.is_empty() or _grids.is_empty():
		return
	var trail = GameConfig.echo_trails.get(_level, null)
	if trail == null or not (trail is Array) or trail.is_empty():
		return
	var grid: Array = _grids[0]
	var container: Node2D = _floor_containers[0]
	var n: int = trail.size()
	var step: int = maxi(1, int(ceil(float(n) / 40.0)))   # не больше ~40 меток на уровень
	var i := 0
	while i < n:
		var v: Vector2 = trail[i]
		var cx: int = clampi(int(v.x * _cols), 0, _cols - 1)
		var cy: int = clampi(int(v.y * _rows), 0, _rows - 1)
		var gx := cx * 2 + 1
		var gy := cy * 2 + 1
		if gy < grid.size() and gx < (grid[gy] as Array).size() and not grid[gy][gx]:
			var e := Node2D.new()
			e.set_script(load("res://time_echo.gd"))
			e.position = _cell_to_world(Vector2i(cx, cy))
			e.recency = float(i) / maxf(1.0, float(n - 1))
			container.add_child(e)
		i += step

func _compute_optimal_path_len() -> void:
	# [§62, v.4.2] Графовая версия — честная dijkstra-дистанция по узлам
	# графа (в мировых юнитах), а не BFS по клеточному приближению
	# сетки-заглушки (тот BFS давал "количество шагов" по прямоугольнику
	# без стен вообще, число почти не связанное с реальной длиной пути).
	# Делим на TILE — величина используется ниже как "условные клетки" для
	# оценки времени/эффективности (_optimal_path_len * TILE), тот же
	# масштаб, что и у клеточной версии.
	if _caves_graph_active:
		var nodes: Array = _cave_graph.get("nodes", [])
		var edges: Array = _cave_graph.get("edges", [])
		if nodes.is_empty() or _cave_entry_node < 0 or _cave_exit_node < 0:
			_optimal_path_len = 0
			return
		var result := CaveGraph.dijkstra(nodes, edges, _cave_entry_node)
		var dist: Array = result["dist"]
		var d: float = dist[_cave_exit_node] if _cave_exit_node < dist.size() else INF
		_optimal_path_len = int(d / TILE) if d != INF else 0
		return
	var start := Vector3i(0, _entry_cell.x, _entry_cell.y)
	var goal  := Vector3i(_exit_floor, _exit_cell.x, _exit_cell.y)
	var dist  := {start: 0}
	var queue: Array[Vector3i] = [start]
	while not queue.is_empty():
		var cur: Vector3i = queue.pop_front()
		if cur == goal:
			_optimal_path_len = dist[cur]
			return
		for nb in _cell_neighbors(cur):
			if not dist.has(nb):
				dist[nb] = dist[cur] + 1
				queue.append(nb)
	_optimal_path_len = 0

# Экран «Обучение пройдено» — та же стилистика, что и обычный экран
# результатов (тёмная плашка с рамкой, кнопка через UIStyle), плюс явная
# пауза: игрок должен осознанно нажать «Понятно», а не пропустить надпись,
# как раньше (жалоба: экран победы либо не был виден, либо исчезал без следа).
func _show_tutorial_complete_screen() -> void:
	await _show_tutorial_stage_screen(
		GameConfig.tt("Обучение пройдено!", "Tutorial complete!"),
		GameConfig.tt(
			"Дальше — режим «УРОВНИ»: 50 уровней вглубь, новые навыки за SP,\n" +
			"враги, боссы и осколки-ключи. Свет — жизнь. Тьма — не прощает.",
			"Next up — «LEVELS» mode: 50 levels deep, new skills for SP,\n" +
			"enemies, bosses and shard-keys. Light is life. The dark shows no mercy."),
		GameConfig.tt("Понятно", "Got it"))

# Общий модальный экран обучения — используется и для финального завершения,
# и для перехода между этапами (_show_tutorial_stage_complete). Параметризован
# заголовком/текстом/кнопкой, чтобы не дублировать вёрстку.
func _show_tutorial_stage_screen(title_text: String, body_text: String, btn_text: String) -> void:
	get_tree().paused = true

	var overlay := CanvasLayer.new()
	overlay.layer = 4
	overlay.process_mode = Node.PROCESS_MODE_ALWAYS
	add_child(overlay)

	if _hud_layer:
		_hud_layer.visible = false

	var bg := ColorRect.new()
	bg.color = Color(0.01, 0.01, 0.04, 0.7)
	bg.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	overlay.add_child(bg)

	var center := CenterContainer.new()
	center.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	overlay.add_child(center)

	var panel := PanelContainer.new()
	panel.add_theme_stylebox_override("panel", UIStyle.panel_stylebox(Color(1.0, 0.85, 0.3, 0.6)))
	center.add_child(panel)

	var col := VBoxContainer.new()
	col.add_theme_constant_override("separation", 18)
	col.custom_minimum_size = Vector2(560, 0)
	panel.add_child(col)

	var title := Label.new()
	title.text = title_text
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	title.add_theme_font_size_override("font_size", 30)
	title.add_theme_color_override("font_color", Color(1.0, 0.85, 0.3))
	col.add_child(title)

	var body := Label.new()
	body.text = body_text
	body.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	body.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	body.add_theme_font_size_override("font_size", 17)
	body.add_theme_color_override("font_color", Color(0.9, 0.9, 1.0))
	col.add_child(body)

	var btn_row := HBoxContainer.new()
	btn_row.alignment = BoxContainer.ALIGNMENT_CENTER
	col.add_child(btn_row)
	var ok_btn := UIStyle.make_button(btn_text, func() -> void:
		if is_instance_valid(overlay):
			overlay.queue_free(), 190, 46, 20)
	ok_btn.process_mode = Node.PROCESS_MODE_ALWAYS
	btn_row.add_child(ok_btn)

	while is_instance_valid(overlay):
		await get_tree().process_frame

	get_tree().paused = false

func _show_stats_screen() -> void:
	var vp_size: Vector2 = get_viewport().get_visible_rect().size

	var overlay := CanvasLayer.new()
	overlay.layer = 4
	add_child(overlay)

	# Прячем HUD (вместе с большим баннером победы) — на экране результатов он лишь
	# засоряет картинку и мешает фону читаться затемнённым. Сцена перезагрузится в
	# _restart(), так что восстанавливать видимость не нужно.
	if _hud_layer:
		_hud_layer.visible = false

	# Затемняющая вуаль: проявляется плавно и НЕ до конца — лабиринт виден сквозь неё.
	var bg := ColorRect.new()
	bg.color = Color(0.01, 0.01, 0.04, 0.0)
	bg.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	overlay.add_child(bg)
	var bg_alpha := 0.70   # целевая непрозрачность вуали

	# Тепловая карта (этаж 0)
	var cell_px: int = clamp(int((vp_size.x * 0.45) / float(maxi(_cols, 1))), 4, 20)
	var map_w: int = _cols * cell_px
	var map_h: int = _rows * cell_px
	var img := Image.create_empty(map_w, map_h, false, Image.FORMAT_RGBA8)
	img.fill(Color(0.04, 0.04, 0.08, 1.0))

	var max_heat: float = 0.1
	for v in _heat_map.values():
		max_heat = maxf(max_heat, float(v))

	# Оптимальный путь (подсвечиваем зелёным)
	var opt_cells: Dictionary = {}
	var s0 := Vector3i(0, _entry_cell.x, _entry_cell.y)
	var g0 := Vector3i(_exit_floor, _exit_cell.x, _exit_cell.y)
	var prev_opt: Dictionary = {}
	var vis_opt: Dictionary = {s0: true}
	var q_opt: Array[Vector3i] = [s0]
	var found_opt := false
	while not q_opt.is_empty() and not found_opt:
		var cur: Vector3i = q_opt.pop_front()
		if cur == g0:
			found_opt = true
			var c2 := cur
			while c2 != s0:
				if c2.x == 0:
					opt_cells[Vector2i(c2.y, c2.z)] = true
				c2 = prev_opt.get(c2, s0)
			break
		for nb in _cell_neighbors(cur):
			if not vis_opt.has(nb):
				vis_opt[nb] = true
				prev_opt[nb] = cur
				q_opt.append(nb)

	for cy in _rows:
		for cx in _cols:
			var k := Vector3i(0, cx, cy)
			var heat: float = float(_heat_map.get(k, 0.0)) / max_heat
			var col: Color
			if opt_cells.has(Vector2i(cx, cy)):
				col = Color(0.1, 0.8, 0.3, 1.0).lerp(Color(0.6, 1.0, 0.5, 1.0), heat)
			elif heat > 0.0:
				if heat < 0.4:
					col = Color(0.1, 0.4, 1.0, 1.0).lerp(Color(0.1, 0.9, 0.9, 1.0), heat / 0.4)
				elif heat < 0.75:
					col = Color(0.1, 0.9, 0.9, 1.0).lerp(Color(1.0, 0.9, 0.2, 1.0), (heat - 0.4) / 0.35)
				else:
					col = Color(1.0, 0.9, 0.2, 1.0).lerp(Color(1.0, 1.0, 1.0, 1.0), (heat - 0.75) / 0.25)
			else:
				col = Color(0.07, 0.07, 0.12, 1.0)
			for dy in cell_px:
				for dx in cell_px:
					img.set_pixel(cx * cell_px + dx, cy * cell_px + dy, col)

	# Старт и выход (старт — не всегда угол (0,0): см. _entry_cell/мега-лабиринт)
	for dy in cell_px:
		for dx in cell_px:
			if _entry_cell.x < _cols and _entry_cell.y < _rows:
				img.set_pixel(_entry_cell.x * cell_px + dx, _entry_cell.y * cell_px + dy, Color(0.3, 1.0, 0.6, 1.0))
			if _exit_cell.x < _cols and _exit_cell.y < _rows:
				img.set_pixel(_exit_cell.x * cell_px + dx, _exit_cell.y * cell_px + dy, Color(1.0, 0.5, 0.1, 1.0))

	# --- Композиция по центру: заголовок · карта · легенда · статистика · подсказка ---
	var center := CenterContainer.new()
	center.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	overlay.add_child(center)

	var col := VBoxContainer.new()
	col.alignment = BoxContainer.ALIGNMENT_CENTER
	col.add_theme_constant_override("separation", 16)
	center.add_child(col)

	# Заголовок — расшифровка ранга (раньше жила только в мелькавшей 1 секунду
	# жёлтой надписи и терялась насовсем; теперь часть постоянного экрана).
	var title := Label.new()
	title.add_theme_font_size_override("font_size", 26)
	title.add_theme_color_override("font_color", Color(1.0, 0.85, 0.3))
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	title.text = _last_rank_line if _last_rank_line != "" else (GameConfig.tt("Глубина %d пройдена", "Depth %d cleared") % _level if GameConfig.active_run >= 0 else GameConfig.tt("Уровень %d пройден", "Level %d cleared") % _level)
	_label_outline(title, 5)
	col.add_child(title)

	if _last_rank_detail != "":
		var detail_lbl := Label.new()
		detail_lbl.add_theme_font_size_override("font_size", 14)
		detail_lbl.add_theme_color_override("font_color", Color(0.75, 0.8, 0.9))
		detail_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		detail_lbl.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		detail_lbl.custom_minimum_size = Vector2(560, 0)
		detail_lbl.text = _last_rank_detail
		_label_outline(detail_lbl, 3)
		col.add_child(detail_lbl)

	# Карта (по центру, без растяжения — чтобы не искажать пиксели)
	var map_tex := TextureRect.new()
	map_tex.texture = ImageTexture.create_from_image(img)
	map_tex.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	map_tex.custom_minimum_size = Vector2(map_w, map_h)
	map_tex.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	col.add_child(map_tex)

	# Легенда — раньше все квадраты были одного серого цвета текста и не
	# показывали, какому реально цвету на карте что соответствует (жалоба
	# «из скрина непонятно, что такое старт/выход/оптимальный путь»). Теперь
	# каждый пункт — квашратик РЕАЛЬНОГО цвета из отрисовки карты выше, плюс
	# настоящий цветовой градиент вместо текста-стрелки для «тепла».
	var legend_row := HBoxContainer.new()
	legend_row.alignment = BoxContainer.ALIGNMENT_CENTER
	legend_row.add_theme_constant_override("separation", 16)
	col.add_child(legend_row)
	_legend_swatch(legend_row, Color(0.3, 1.0, 0.6, 1.0), GameConfig.tt("старт", "start"))
	_legend_swatch(legend_row, Color(1.0, 0.5, 0.1, 1.0), GameConfig.tt("выход", "exit"))
	_legend_swatch(legend_row, Color(0.3, 0.9, 0.4, 1.0), GameConfig.tt("твой оптимальный путь", "your optimal path"))
	_legend_heat_swatch(legend_row)

	# Сравнение с симулированными игроками
	var optimal_t: float = float(_optimal_path_len) * TILE / maxf(GameConfig.player_speed, 1.0) if _optimal_path_len > 0 else _elapsed
	var median_t:  float = optimal_t * 1.7 + float(_level) * 2.0
	var ratio: float = median_t / maxf(_elapsed, 0.01)
	var pct: int = clamp(int(50.0 + 40.0 * (ratio - 1.0) / (ratio + 0.5)), 1, 99)

	var stats_lbl := Label.new()
	stats_lbl.add_theme_font_size_override("font_size", 19)
	stats_lbl.add_theme_color_override("font_color", Color(0.9, 0.9, 1.0))
	stats_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	stats_lbl.text = (
		GameConfig.tt("Время: %.1f с   ·   оптимум: %.1f с\nТы быстрее %d%% игроков",
			"Time: %.1f s   ·   optimum: %.1f s\nYou're faster than %d%% of players") %
		[_elapsed, optimal_t, pct]
	)
	_label_outline(stats_lbl, 4)
	col.add_child(stats_lbl)

	# Отступ перед подсказкой
	var spacer := Control.new()
	spacer.custom_minimum_size = Vector2(0, 10)
	col.add_child(spacer)

	# ── Кнопки выбора: дальше / заново / меню / навыки. Никаких «любых клавиш»
	# и хоткеев рестарта — осознанный выбор мышью/кликом.
	_stats_choice = "next"
	var btn_row := HBoxContainer.new()
	btn_row.alignment = BoxContainer.ALIGNMENT_CENTER
	btn_row.add_theme_constant_override("separation", 12)
	col.add_child(btn_row)

	var mk := func(txt: String, choice: String) -> Button:
		return UIStyle.make_button(txt, func() -> void:
			_stats_choice = choice
			if is_instance_valid(overlay):
				overlay.queue_free(), 190, 46, 18)
	btn_row.add_child(mk.call(GameConfig.tt("Дальше ▶", "Next ▶"), "next"))
	if GameConfig.active_run < 0:
		btn_row.add_child(mk.call(GameConfig.tt("↻ Заново", "↻ Replay"), "replay"))
	# «Магазин навыков» — открывает полноценное меню навыков поверх результатов
	# (тот же skills_menu, что в паузе). Только в «Уровнях»: в Накале прокачка
	# на алтаре, из экрана результатов туда не попасть по правилам забега.
	if GameConfig.active_run < 0:
		var sk_btn := UIStyle.make_button(GameConfig.tt("Магазин навыков", "Skill shop"), func() -> void:
			var sm := CanvasLayer.new()
			sm.set_script(load("res://skills_menu.gd"))
			sm.layer = 6   # поверх оверлея результатов (layer 4)
			add_child(sm), 210, 46, 18)
		btn_row.add_child(sk_btn)
	btn_row.add_child(mk.call(GameConfig.tt("В меню", "To menu"), "menu"))

	# Проявление вуали; ждём выбор кнопкой (без таймаута и «любой клавиши»).
	while is_instance_valid(overlay):
		var dt := get_process_delta_time()
		bg.color.a = minf(bg_alpha, bg.color.a + dt * (bg_alpha / 0.35))
		await get_tree().process_frame

# Один пункт легенды карты: квадратик РЕАЛЬНОГО цвета + подпись — чтобы цвет
# на карте и цвет в легенде совпадали один в один (не просто серый текст).
func _legend_swatch(parent: Control, col: Color, text: String) -> void:
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 6)
	parent.add_child(row)

	var sw := ColorRect.new()
	sw.color = col
	sw.custom_minimum_size = Vector2(14, 14)
	row.add_child(sw)

	var lbl := Label.new()
	lbl.text = text
	lbl.add_theme_font_size_override("font_size", 13)
	lbl.add_theme_color_override("font_color", Color(0.75, 0.78, 0.85))
	_label_outline(lbl, 3)
	row.add_child(lbl)

# Пункт легенды для «тепла» — настоящий градиент (те же цвета, что и в
# отрисовке карты выше: синий → бирюза → жёлтый → белый), а не текст-стрелка.
func _legend_heat_swatch(parent: Control) -> void:
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 6)
	parent.add_child(row)

	var w := 44
	var img := Image.create_empty(w, 14, false, Image.FORMAT_RGBA8)
	for x in w:
		var heat := float(x) / float(w - 1)
		var col: Color
		if heat < 0.4:
			col = Color(0.1, 0.4, 1.0, 1.0).lerp(Color(0.1, 0.9, 0.9, 1.0), heat / 0.4)
		elif heat < 0.75:
			col = Color(0.1, 0.9, 0.9, 1.0).lerp(Color(1.0, 0.9, 0.2, 1.0), (heat - 0.4) / 0.35)
		else:
			col = Color(1.0, 0.9, 0.2, 1.0).lerp(Color(1.0, 1.0, 1.0, 1.0), (heat - 0.75) / 0.25)
		for y in 14:
			img.set_pixel(x, y, col)
	var tex := TextureRect.new()
	tex.texture = ImageTexture.create_from_image(img)
	tex.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	tex.custom_minimum_size = Vector2(w, 14)
	row.add_child(tex)

	var lbl := Label.new()
	lbl.text = GameConfig.tt("где ты чаще всего проходил", "where you passed most often")
	lbl.add_theme_font_size_override("font_size", 13)
	lbl.add_theme_color_override("font_color", Color(0.75, 0.78, 0.85))
	_label_outline(lbl, 3)
	row.add_child(lbl)

# Действие по выбору на экране результатов. «Заново» переигрывает ТОТ ЖЕ
# уровень (прогресс на следующий уже сохранён — просто откатываем указатель).
func _apply_stats_choice() -> void:
	match _stats_choice:
		"menu":
			_goto_menu()
		"replay":
			if GameConfig.active_run < 0:
				GameConfig.level = _level
				GameConfig.save_game()
			_restart()
		_:
			_restart()

func _build_minimap_texture() -> ImageTexture:
	if _caves_graph_active:
		return _build_cave_minimap_texture()
	var img := Image.create_empty(_cols, _rows, false, Image.FORMAT_RGBA8)
	img.fill(Color(0.08, 0.08, 0.11, 1.0))
	var f: int = _player.current_floor if (_player and is_instance_valid(_player)) else 0
	var cur := Vector2i(-1, -1)
	if _player and is_instance_valid(_player):
		var px: float = _player.global_position.x
		var py: float = _player.global_position.y - f * _floor_gap
		cur = Vector2i(int(round((px / TILE - 1.5) / 2.0)), int(round((py / TILE - 1.5) / 2.0)))
	for key in _visited:
		if key.x == f and key.y >= 0 and key.y < _cols and key.z >= 0 and key.z < _rows:
			# [§41] Память о карте остаётся навсегда, а ВЛАДЕНИЕ гаснет:
			# так на карте видно, какая часть этажа ещё твоя.
			var st: float = claim_strength(key)
			var memory := Color(0.26, 0.34, 0.38)
			var mine := Color(0.5, 0.85, 0.7)
			img.set_pixel(key.y, key.z, memory.lerp(mine, st))
	# [§39] Метка выхода появляется на карте только после того, как он найден —
	# по уликам или своими глазами.
	if _exit_located and f == _exit_floor 			and _exit_cell.x >= 0 and _exit_cell.x < _cols 			and _exit_cell.y >= 0 and _exit_cell.y < _rows:
		img.set_pixel(_exit_cell.x, _exit_cell.y, Color(1.0, 0.55, 0.95))
	if cur.x >= 0 and cur.x < _cols and cur.y >= 0 and cur.y < _rows:
		img.set_pixel(cur.x, cur.y, Color(1.0, 0.9, 0.4))
	return ImageTexture.create_from_image(img)

# [BUGFIX 01.08.2026, §62] Графовая версия миникарты. Ключи _visited для
# графовых Пещер — Vector3i(f, node_idx, 0) (см. _mark_visited), а НЕ
# Vector3i(f, cx, cy) — общий код выше интерпретировал бы node_idx/0 как
# координаты клетки и рисовал бы бессмысленную линию, а не карту. Рисуем
# по позициям реальных узлов графа, нормализованным в пиксели изображения,
# с рёбрами между посещёнными соседями — не так детально, как клеточная
# миникарта, но честно отражает форму пройденного графа, а не мусор.
const CAVE_MINIMAP_SIZE := 64

func _build_cave_minimap_texture() -> ImageTexture:
	var img := Image.create_empty(CAVE_MINIMAP_SIZE, CAVE_MINIMAP_SIZE, false, Image.FORMAT_RGBA8)
	img.fill(Color(0.08, 0.08, 0.11, 1.0))
	var nodes: Array = _cave_graph.get("nodes", [])
	var edges: Array = _cave_graph.get("edges", [])
	if nodes.is_empty():
		return ImageTexture.create_from_image(img)

	var level_size := Vector2(float(_cols) * TILE * 1.7, float(_rows) * TILE * 1.7)

	var visited_idx := {}
	for key in _visited:
		if not (key is Vector3i):
			continue
		var k: Vector3i = key
		if k.x != 0 or k.z != 0:
			continue
		if k.y >= 0 and k.y < nodes.size():
			visited_idx[int(k.y)] = true

	var memory := Color(0.26, 0.34, 0.38)
	for e in edges:
		if not visited_idx.has(e.x) or not visited_idx.has(e.y):
			continue
		var pa := _cave_minimap_px(nodes[e.x], level_size)
		var pb := _cave_minimap_px(nodes[e.y], level_size)
		_cave_minimap_draw_line(img, pa, pb, memory)

	var mine := Color(0.5, 0.85, 0.7)
	for idx in visited_idx.keys():
		var st: float = claim_strength(Vector3i(0, idx, 0))
		var p := _cave_minimap_px(nodes[idx], level_size)
		img.set_pixel(p.x, p.y, memory.lerp(mine, st))

	if _exit_located and _cave_exit_node >= 0 and _cave_exit_node < nodes.size():
		var pe := _cave_minimap_px(nodes[_cave_exit_node], level_size)
		img.set_pixel(pe.x, pe.y, Color(1.0, 0.55, 0.95))

	if _player and is_instance_valid(_player):
		var pp := _cave_minimap_px(_player.global_position, level_size)
		img.set_pixel(pp.x, pp.y, Color(1.0, 0.9, 0.4))

	return ImageTexture.create_from_image(img)

func _cave_minimap_px(p: Vector2, level_size: Vector2) -> Vector2i:
	return Vector2i(
		clampi(int(p.x / level_size.x * float(CAVE_MINIMAP_SIZE)), 0, CAVE_MINIMAP_SIZE - 1),
		clampi(int(p.y / level_size.y * float(CAVE_MINIMAP_SIZE)), 0, CAVE_MINIMAP_SIZE - 1)
	)

# Линия Брезенхема — только для рёбер-«коридоров» миникарты, не для
# реальной геометрии.
func _cave_minimap_draw_line(img: Image, a: Vector2i, b: Vector2i, col: Color) -> void:
	var x0 := a.x
	var y0 := a.y
	var x1 := b.x
	var y1 := b.y
	var dx := absi(x1 - x0)
	var dy := -absi(y1 - y0)
	var sx := 1 if x0 < x1 else -1
	var sy := 1 if y0 < y1 else -1
	var err := dx + dy
	while true:
		if x0 >= 0 and x0 < CAVE_MINIMAP_SIZE and y0 >= 0 and y0 < CAVE_MINIMAP_SIZE:
			img.set_pixel(x0, y0, col)
		if x0 == x1 and y0 == y1:
			break
		var e2 := 2 * err
		if e2 >= dy:
			err += dy
			x0 += sx
		if e2 <= dx:
			err += dx
			y0 += sy

# --- Изменение структуры лабиринта ---

# [TILEMAP-1.8] Пересчитать маску соседней стены-клетки и перекрасить её тайл
# (если она ещё стена) — раньше правило текстуру/грань на существующей ноде,
# теперь это просто новый set_cell с тайлом под актуальную маску.
func _refresh_wall_tile(f: int, gx: int, gy: int) -> void:
	if gx < 0 or gx >= _gw or gy < 0 or gy >= _gh:
		return
	if not (_grids[f] as Array)[gy][gx]:
		return   # проход — обновлять нечего
	_paint_wall_tile(_floor_tilemaps[f], f, gx, gy)

func _set_wall(f: int, gx: int, gy: int, is_wall: bool) -> void:
	# «Крепкая» стена (супербосс §25) иммунна к разрушению — ни лазер (когда
	# появится), ни уже существующие Разлом/землетрясение её не берут.
	if not is_wall and _strong_cells.has(f) and (_strong_cells[f] as Dictionary).has(Vector2i(gx, gy)):
		return
	(_grids[f] as Array)[gy][gx] = is_wall
	var tile_map: TileMapLayer = _floor_tilemaps[f]
	if is_wall:
		_paint_wall_tile(tile_map, f, gx, gy)
	else:
		tile_map.erase_cell(Vector2i(gx, gy))
		_register_side_cell(f, gx, gy, 0)   # больше не стена — снять регистрацию боковых граней
	# Сторона у соседей изменилась — обновить их бевели (и свою, если осталась стеной).
	_refresh_wall_tile(f, gx, gy)
	_refresh_wall_tile(f, gx, gy - 1)
	_refresh_wall_tile(f, gx + 1, gy)
	_refresh_wall_tile(f, gx, gy + 1)
	_refresh_wall_tile(f, gx - 1, gy)
	# На органических уровнях перерисовать тоннели этого этажа.
	if _organic and f < _organic_floors.size() and is_instance_valid(_organic_floors[f]):
		_organic_floors[f].queue_redraw()

# Путь между двумя клетками-проходами по текущему дереву (в координатах сетки),
# возвращает список рёбер-стен на пути. Ребро exclude игнорируется.
func _path_edges(grid: Array, a: Vector2i, b: Vector2i, exclude: Vector2i) -> Array:
	var prev := {}
	var visited := {a: true}
	var queue: Array[Vector2i] = [a]
	while not queue.is_empty():
		var c: Vector2i = queue.pop_front()
		if c == b:
			break
		for d in [Vector2i(2, 0), Vector2i(-2, 0), Vector2i(0, 2), Vector2i(0, -2)]:
			var n: Vector2i = c + d
			if n.x < 1 or n.x >= _gw - 1 or n.y < 1 or n.y >= _gh - 1:
				continue
			var edge := Vector2i((c.x + n.x) / 2, (c.y + n.y) / 2)
			if edge == exclude or grid[edge.y][edge.x] or visited.has(n):
				continue
			visited[n] = true
			prev[n] = [c, edge]
			queue.append(n)
	if not visited.has(b):
		return []
	var edges: Array = []
	var cur: Vector2i = b
	while cur != a:
		var pe = prev[cur]
		edges.append(pe[1])
		cur = pe[0]
	return edges

# Случайное событие: открыть одно ребро и закрыть другое на образовавшемся
# цикле — лабиринт меняется, но остаётся проходимым (остаётся деревом).
func _maze_shift() -> void:
	if _player == null:
		return
	var f: int = _player.current_floor
	if f < 0 or f >= _grids.size():
		return
	var grid: Array = _grids[f]

	var closed: Array = []
	for gy in range(1, _gh - 1):
		for gx in range(1, _gw - 1):
			if not grid[gy][gx]:
				continue
			# ребро между двумя проходами: ровно одна координата чётная
			if (gx % 2 == 0) == (gy % 2 == 0):
				continue
			closed.append(Vector2i(gx, gy))
	if closed.is_empty():
		return
	closed.shuffle()
	var opened: Vector2i = closed[0]

	var a: Vector2i
	var b: Vector2i
	if opened.x % 2 == 0:
		a = Vector2i(opened.x - 1, opened.y)
		b = Vector2i(opened.x + 1, opened.y)
	else:
		a = Vector2i(opened.x, opened.y - 1)
		b = Vector2i(opened.x, opened.y + 1)

	var path := _path_edges(grid, a, b, opened)
	if path.is_empty():
		return

	_set_wall(f, opened.x, opened.y, false)  # открыли проход

	# закрыть ребро на пути, не вплотную к игроку
	path.shuffle()
	var to_close: Vector2i = path[0]
	for e in path:
		if _grid_to_world(e.x, e.y, f).distance_to(_player.global_position) > TILE * 2.0:
			to_close = e
			break
	_set_wall(f, to_close.x, to_close.y, true)

# Полная перегенерация этажа (для события у дверей).
# Постройка разбита на кадры, чтобы не было фриза на больших лабиринтах.
func regenerate_floor(f: int) -> void:
	if f < 0 or f >= _grids.size() or f >= _floor_tilemaps.size():
		return
	var tile_map: TileMapLayer = _floor_tilemaps[f]
	# [TILEMAP-1.8] Раньше здесь освобождались ноды каждой стены — теперь один
	# clear() на TileMapLayer этажа (сам TileMapLayer, как и _floor_containers[f],
	# переиспользуется, не пересоздаётся).
	tile_map.clear()
	if f < _side_cells.size():
		_side_cells[f] = {}
	var grid := _make_grid()
	_grids[f] = grid
	# Сбрасываем пройденный путь этого этажа — карта обнуляется
	for vk in _visited.keys():
		if vk.x == f:
			_visited.erase(vk)
	# [BUGFIX v3.8, §57] Владение (§41) — та же история, что раньше была со
	# станциями/осколками (см. ниже): запись держит СТАРЫЕ координаты
	# прохода, а новый рисунок стен может накрыть их стеной. Стоило бы
	# читаться как «моя земля» на клетке, которая теперь стена, и — что
	# хуже — Соглядатай (§57) мог бы там заспавниться (защита от этого
	# есть в _cell_is_passage, но неверные данные в принципе лучше не
	# копить). Свежий этаж — свежее владение, как и свежая память.
	for ck in _claim_time.keys():
		if ck.x == f:
			_claim_time.erase(ck)
	for cfk in _claim_first_time.keys():
		if cfk.x == f:
			_claim_first_time.erase(cfk)
	# На органических уровнях обновить тоннели под новую сетку
	if _organic and f < _organic_floors.size() and is_instance_valid(_organic_floors[f]):
		_organic_floors[f].grid = grid
		_organic_floors[f].queue_redraw()
	var built := 0
	for gy in _gh:
		for gx in _gw:
			if grid[gy][gx]:
				_paint_wall_tile(tile_map, f, gx, gy)
				built += 1
				if built % 500 == 0:
					await get_tree().process_frame
					if not is_instance_valid(tile_map):
						return

	# Старые станции/осколки стояли на клетках ПРЕЖНЕГО рисунка стен — новый
	# лабиринт запросто накрывает их стеной (объект есть, но зажат и
	# недостижим — баг на уровне 25, GAMEDESIGN.md). Убираем их и рассаживаем
	# заново по актуальным проходам новой сетки.
	if f < _shards_remaining.size():
		_shards_total -= _shards_remaining[f]
		_shards_remaining[f] = 0
	if f < _floor_containers.size() and is_instance_valid(_floor_containers[f]):
		var stale_container: Node2D = _floor_containers[f]
		for n in stale_container.get_children():
			if is_instance_valid(n) and (n.is_in_group("station") or n.is_in_group("shard")):
				n.queue_free()
		_spawn_floor_pickups(f, grid, stale_container)

# --- Игровые события ---

func set_checkpoint(floor_idx: int, pos: Vector2) -> void:
	_cp_floor = floor_idx
	_cp_pos = pos

# ── Дары боссов: исполнение эффектов (вызывает player.gd) ────────────────────

# Мираж: светящийся фантом в точке игрока; враги этажа в радиусе бегут проверять.
func mirage_decoy(pos: Vector2, f: int, radius: float) -> void:
	var b := Node2D.new()
	b.set_script(load("res://burst.gd"))
	b.color = Color(0.8, 0.7, 1.0, 1.0)
	b.max_scale = 6.0
	b.dur = 0.9
	b.light_energy = 2.0
	add_child(b)
	b.global_position = pos
	# Клетка приманки в координатах ячеек лабиринта (без смещения этажа)
	var local := pos - Vector2(0, f * _floor_gap)
	var cell := Vector2i(int(local.x / TILE / 2.0), int(local.y / TILE / 2.0))
	for e in get_tree().get_nodes_in_group("enemy"):
		if not is_instance_valid(e) or not e.has_method("distract_to"):
			continue
		if "_enemy_floor" in e and int(e._enemy_floor) != f:
			continue
		if e.global_position.distance_to(pos) > radius:
			continue
		e.distract_to(cell, 6.0)
	flash_message(GameConfig.tt("Мираж — тьма купилась", "Mirage — the dark took the bait"))

# Разлом: проламывает до count стен по доминирующей оси взгляда.
func breach_wall(pos: Vector2, facing: Vector2, f: int, count: int = 1) -> bool:
	if f < 0 or f >= _grids.size():
		return false
	var local := pos - Vector2(0, f * _floor_gap)
	var gx := int(local.x / TILE)
	var gy := int(local.y / TILE)
	var step := Vector2i(1, 0) if absf(facing.x) >= absf(facing.y) else Vector2i(0, 1)
	if (facing.x if step.x != 0 else facing.y) < 0.0:
		step = -step
	var broken := 0
	var cx := gx
	var cy := gy
	for i in 6:
		cx += step.x
		cy += step.y
		# Границы лабиринта не ломаем — только внутренние стены
		if cx <= 0 or cx >= _gw - 1 or cy <= 0 or cy >= _gh - 1:
			break
		if (_grids[f] as Array)[cy][cx]:
			_set_wall(f, cx, cy, false)
			var bb := Node2D.new()
			bb.set_script(load("res://burst.gd"))
			bb.color = Color(1.0, 0.6, 0.3, 1.0)
			bb.max_scale = 4.0
			bb.dur = 0.5
			add_child(bb)
			bb.global_position = Vector2(cx * TILE + TILE * 0.5, cy * TILE + TILE * 0.5 + f * _floor_gap)
			broken += 1
			if broken >= count:
				break
	if broken > 0:
		flash_message(GameConfig.tt("Разлом! Стена пала", "Breach! The wall fell"))
	return broken > 0

# Хронос: заморозка всех врагов этажа.
func chrono_freeze(dur: float, f: int) -> void:
	for e in get_tree().get_nodes_in_group("enemy"):
		if not is_instance_valid(e):
			continue
		if "_enemy_floor" in e and int(e._enemy_floor) != f:
			continue
		if "stun_time" in e:
			e.stun_time = maxf(e.stun_time, dur)
	if _fx:
		_fx.flash(Color(0.5, 0.95, 0.9), 0.18)
	flash_message(GameConfig.tt("Хронос — время замерло", "Chrono — time froze"))

func reveal(duration: float) -> void:
	_reveal_time = duration

# Сонар: временно раздвигает радиус видимости виньетки (не полностью её
# открывает, как Озарение, — просто расширяет «шар света» вокруг игрока).
# maxf с текущим — повторный сонар во время предыдущего только продлевает/
# усиливает эффект, а не сбрасывает его.
func sonar_reveal(mult: float, duration: float) -> void:
	_sonar_vision_time = maxf(_sonar_vision_time, duration)
	_sonar_vision_mult = maxf(_sonar_vision_mult, mult)

# Активно ли сейчас Озарение — player.gd читает для комбо «Всевидение».
func is_reveal_active() -> bool:
	return _reveal_time > 0.0

# Апекс-«Вспышка»: то, что реально отличает её от простого света или бесплатного
# события «Просвет» (который теперь лишь расширяет радиус, см. _trigger_event) —
# ослепляющий импульс глушит ВСЕХ врагов в радиусе на несколько секунд, как щит
# при контакте. Не «свет поярче», а панический выход из окружения. Актуальную
# угрозу (тех, кто гонится) добивает apex_overload — см. ниже.
func apex_flash_shock(radius: float, stun_dur: float = 3.0) -> void:
	if _player == null or not is_instance_valid(_player):
		return
	for e in get_tree().get_nodes_in_group("enemy"):
		if not is_instance_valid(e):
			continue
		if e.global_position.distance_to(_player.global_position) <= radius and "stun_time" in e:
			e.stun_time = maxf(e.stun_time, stun_dur)
	if _fx:
		_fx.flash(Color(1.0, 0.95, 0.8), 0.35)

# Условие активации Апекса: он не заменяет собой «зачистку этажа по кнопке» —
# срабатывает только когда есть реальная опасность (хотя бы один враг СЕЙЧАС
# гонится за игроком, т.е. в состоянии CHASE — см. pursuer.gd). В патруле или
# поиске враг не считается угрозой. Читается из player.gd:_try_apex перед тем,
# как тратить энергию и кулдаун — если условие не выполнено, навык просто не
# срабатывает (ничего не тратится).
func has_active_chaser() -> bool:
	if _player == null or not is_instance_valid(_player):
		return false
	for e in get_tree().get_nodes_in_group("enemy"):
		if is_instance_valid(e) and e.has_method("is_chasing") and e.is_chasing():
			if int(e.get("_enemy_floor")) == int(_player.current_floor):
				return true
	return false

# Апекс-«Испепеление»: уничтожает АКТИВНО ПРЕСЛЕДУЮЩИХ игрока врагов (state ==
# CHASE) на его этаже — не всех подряд, только реальную угрозу прямо сейчас.
# radius игнорируется, если floor_wide=true (формы Сонара/Озарения/Искры —
# «весь этаж», раз уж их эффект и так floor-wide по смыслу навыка).
func apex_overload(radius: float, floor_wide: bool = false) -> int:
	if _player == null or not is_instance_valid(_player):
		return 0
	var killed := 0
	for e in get_tree().get_nodes_in_group("enemy"):
		if not is_instance_valid(e):
			continue
		if not (e.has_method("is_chasing") and e.is_chasing()):
			continue
		if int(e.get("_enemy_floor")) != int(_player.current_floor):
			continue
		if not floor_wide and e.global_position.distance_to(_player.global_position) > radius:
			continue
		_destroy_chaser(e)
		killed += 1
	if killed > 0:
		flash_message(GameConfig.tt("Апекс поразил преследователей: %d", "Apex struck down pursuers: %d") % killed)
	return killed

func _destroy_chaser(e: Node2D) -> void:
	var b := Node2D.new()
	b.set_script(load("res://burst.gd"))
	b.color = Color(1.0, 0.92, 0.6, 1.0)
	b.max_scale = 5.0
	b.dur = 0.5
	b.light_energy = 2.2
	add_child(b)
	b.global_position = e.global_position
	if GameConfig.active_run >= 0:
		_ember += 6.0 * _ember_mult()
	GameConfig.add_xp(60)
	GameConfig.bump_stat("enemies_killed")
	if "enemy_type" in e:
		GameConfig.bump_stat("kill_t%d" % int(e.enemy_type))   # бестиарий
	_announce_milestones()
	_note_enemy_death(e)
	e.queue_free()

# ── Накал: набор, банк, «жар», алтарь ────────────────────────────────────────

func _apply_biome() -> void:
	_biome = _biome_of_level(_level)
	var b: Dictionary = BIOMES[_biome]
	_biome_name = str(b["name_en"]) if GameConfig.locale == "en" else str(b["name"])
	var cols: Array = b["colors"]
	_wall_color = cols[(_level - 1) % cols.size()]

# Номер биома для произвольного уровня — вынесено из _apply_biome, чтобы можно
# было сравнить биом текущего уровня с биомом предыдущего (см. _announce_biome).
func _biome_of_level(lvl: int) -> int:
	return int(maxi(lvl - 1, 0) / BIOME_SPAN) % BIOMES.size()

# [BUGFIX 02.08.2026, v4.3] Обёртка над _biome_of_level, которая знает про
# сжатую биом-полосу Пещер (см. _apply_biome/CAVES_MECH_LEVEL_OVERRIDE выше) —
# единственное место, кроме _apply_biome, которому нужен номер биома для
# ПРОИЗВОЛЬНОГО уровня (_announce_biome сравнивает текущий с предыдущим).
# Без этой обёртки сравнение шло бы разными формулами (кампанийский
# BIOME_SPAN=5 для "было", сжатая полоса Пещер для "стало") и тост о смене
# биома либо не появлялся бы там, где биом реально сменился, либо появлялся
# бы там, где нет.
func _biome_of_level_mode(lvl: int) -> int:
	if GameConfig.caves_mode:
		var caves_span: int = ceili(float(GameConfig.CAVES_LEVELS) / float(BIOMES.size()))
		return int(maxi(lvl - 1, 0) / caves_span) % BIOMES.size()
	return _biome_of_level(lvl)

# [GAMEDESIGN §29] Индикатор стойки: активный сегмент горит своим цветом,
# соседние приглушены. Подпись — имя стойки и во сколько раз идёт расход
# Света: игрок должен видеть цену решения, а не угадывать её.
func _update_stance_hud() -> void:
	if _stance_row == null or _player == null or not is_instance_valid(_player):
		return
	var idx: int = int(_player.light_stance)
	var col: Color = _player.stance_color()
	for i in _stance_segs.size():
		var seg: ColorRect = _stance_segs[i]
		if i == idx:
			seg.color = col
		else:
			seg.color = Color(col.r, col.g, col.b, 0.18)
	_stance_label.text = "%s  ×%.2f" % [_player.stance_name(), _player.stance_drain_mult()]
	_stance_label.add_theme_color_override("font_color", col)

# Хук смены стойки: короткая обратная связь, чтобы решение ощущалось, а не
# только менялось в цифрах. Без тоста — переключаться будут часто.
var _tut_stance_changed: bool = false   # обучение: игрок подвигал стойку

func on_light_stance_changed(idx: int) -> void:
	_tut_stance_changed = true
	_update_stance_hud()
	beep()
	if _stance_row:
		var t := create_tween()
		_stance_row.scale = Vector2(1.14, 1.14)
		t.tween_property(_stance_row, "scale", Vector2.ONE, 0.18)
	if _player and is_instance_valid(_player) and _player.has_method("add_shake") and idx == 2:
		_player.add_shake(2.0, 0.12)

# ══ ЛЕСТНИЦА ОТКРЫТИЙ (§38) ═════════════════════════════════════════════════
# Единственный способ спросить «доступна ли механика на этом уровне». Читает
# GameConfig.LADDER — россыпи *_FROM_LEVEL по файлу больше нет. В спецрежимах
# (Логово, супербосс, арена, обучение) лестница не действует: там своя
# режиссура, и «уровень» значит не то же самое, что в кампании.
#
# [BUGFIX 02.08.2026, v4.3] Пещеры — тоже НЕ кампания (своя 10-уровневая
# шкала, `_level` = caves_level), но в отличие от Логова/арены/обучения они
# ДО этой правки читали кампанийскую лестницу напрямую. Пороги dark_stations
# (11), mimics (16), watcher (14) лежат ЗА пределами шкалы 1-10 — недостижимы
# ни при каком caves_level, что обзорный харнесс подтвердил: 0 тёмных
# станций и 0 мимиков за все 10 уровней Пещер. herder (8) технически попадал
# в шкалу, но после правки биом-полосы Пещер (см. _apply_biome/caves_span
# выше) окно биома «Багровые недра» (загонщик/ямы) сузилось до 5-8 —
# дефолтный порог 8 оставлял загонщику всего один уровень пересечения с
# биомом вместо всех четырёх. Пороги ниже подобраны под НОВУЮ ширину
# биом-полосы Пещер, а не переиспользуют кампанийские числа: dark_stations
# попадает в окно Споровых пустот (9-10), mimics — в окно Лазурных шахт
# (1-4), herder — на весь диапазон Багровых недр (5-8). watcher никак не
# завязан на биом (голая эвристика заброшенной территории) — порог просто
# оставляет Пещерам пару спокойных вводных уровней перед стартом механики.
const CAVES_MECH_LEVEL_OVERRIDE := {
	"mimics": 3, "herder": 5, "watcher": 6, "dark_stations": 9,
}

func _mech_ready(id: String) -> bool:
	if _caves_graph_active and CAVES_MECH_LEVEL_OVERRIDE.has(id):
		return _level >= int(CAVES_MECH_LEVEL_OVERRIDE[id])
	return GameConfig.ladder_ready(id, _level)

# Карточка «Новое: …» — один раз за всё время на том уровне, где механика
# вводится. Причина существования: до 1.18 механика просто однажды появлялась
# в мире без единого слова, и игрок не понимал, откуда она взялась.
# Режимы (kind == "mode") пропускаются — про них уже говорит
# _announce_mode_unlocks, дублировать не нужно.
func _announce_ladder(delay: float = 0.0) -> void:
	if _boss_level or _lair_active or _superboss_level or GameConfig.tutorial_mode:
		return
	if GameConfig.active_run >= 0:
		return   # лестница — свойство кампании «Уровни»; в забеге глубина своя
	var fresh: Array = GameConfig.ladder_new_at(_level)
	if fresh.is_empty():
		return
	if delay > 0.0:
		await get_tree().create_timer(delay).timeout
		if not is_inside_tree() or _won or _dead:
			return
	for e in fresh:
		GameConfig.ladder_mark_seen(str(e["id"]))
		var nm: String = str(e["name_en"]) if GameConfig.locale == "en" else str(e["name"])
		var what: String = str(e["what_en"]) if GameConfig.locale == "en" else str(e["what"])
		flash_message(GameConfig.tt("🔓 Новое: %s\n%s", "🔓 New: %s\n%s") % [nm, what])
		if _fx:
			_fx.gold_pulse(1.8)
			_fx.flash(Color(e["color"]), 0.22)
		play_sfx(_sfx_key)
		if fresh.size() > 1:
			await get_tree().create_timer(5.5).timeout
			if not is_inside_tree() or _won or _dead:
				return
	if not GameConfig.test_mode:
		GameConfig.save_game()

# [§38] Строка темы биома собирается из механик, которые на этом уровне РЕАЛЬНО
# могут появиться (биом их разрешает И лестница уже открыла). Раньше тема была
# фиксированным текстом, и первые Шахты обещали порталы-срезки за пять уровней
# до их гейта, а первые Недра — провалы за девять. Обещание, которое игра не
# выполняет, читается как «механики берутся из ниоткуда» — это и был баг.
const BIOME_CLAUSES := {
	"shortcut":      ["ищи парные порталы — они срежут полпути", "look for portal pairs — they cut the route in half"],
	"pits":          ["провалы не обойти — только Рывком", "chasms can't be walked around — only dashed"],
	"dark_stations": ["тьма пьёт твой свет — гаси его сам", "the dark drinks your light — dim it yourself"],
	"mimics":        ["не каждая станция — станция", "not every station is a station"],
	"herder":        ["кто-то гонит тебя в тупик", "something is herding you into a dead end"],
}
# Порядок вывода — как в лестнице: сначала то, что открылось раньше.
const BIOME_CLAUSE_ORDER := ["shortcut", "pits", "dark_stations", "herder", "mimics"]

func _biome_theme_line() -> String:
	var parts: Array = []
	for id in BIOME_CLAUSE_ORDER:
		var key: String = "herders" if id == "herder" else id
		if _biome_chance(key) <= 0.0 or not _mech_ready(id):
			continue
		var c: Array = BIOME_CLAUSES[id]
		parts.append(str(c[1]) if GameConfig.locale == "en" else str(c[0]))
	if parts.is_empty():
		# Тем ещё нет (первые уровни) — говорим правду, а не обещание.
		return GameConfig.tt("здесь пока правит только тьма и твой свет", "for now only the dark and your light rule here")
	return "; ".join(parts)

# [GAMEDESIGN §26] Правила механик текущего биома. Спецуровни (арена босса,
# Логово, супербосс, обучение) тем не имеют — там своя насыщенная режиссура,
# и биомная лотерея им только мешала бы; возвращаем пустой словарь, а вызовы
# читают его через _biome_chance/_biome_weights с безопасными дефолтами.
func _biome_rules() -> Dictionary:
	if _boss_level or _lair_active or _superboss_level or GameConfig.tutorial_mode:
		return {}
	var b: Dictionary = BIOMES[_biome]
	return b.get("rules", {})

# Вероятность спавна тематической механики (shortcut/pits/dark_stations).
# Биом без ключа = механики в нём нет (0.0), а не «шанс по умолчанию».
func _biome_chance(key: String) -> float:
	var r := _biome_rules()
	if r.is_empty():
		return 0.0
	return float(r.get(key, 0.0))

# Веса выбора внутри пула (guests/events/rooms). Отсутствие ключа = вес 1.0,
# поэтому биому достаточно перечислить только то, что он реально сдвигает.
func _biome_weights(key: String) -> Dictionary:
	var r := _biome_rules()
	if r.is_empty():
		return {}
	return r.get(key, {})

# Какой по счёту раз игрок проходит эту тему: биомы циклятся каждые
# BIOME_SPAN * BIOMES.size() уровней (сейчас 15). Второй заход в тему должен
# быть плотнее первого — иначе уровни 16-30 читаются как повтор 1-15.
func _biome_cycle() -> int:
	return int(maxi(_level - 1, 0) / (BIOME_SPAN * BIOMES.size()))

# Взвешенный выбор ключа словаря {значение: вес}. Общий для гостей, событий и
# событийных комнат — три места раньше катали свою самописную лотерею.
func _weighted_pick(weights: Dictionary) -> String:
	var total := 0.0
	for k in weights:
		total += maxf(float(weights[k]), 0.0)
	if total <= 0.0:
		return ""
	var roll := randf() * total
	for k in weights:
		roll -= maxf(float(weights[k]), 0.0)
		if roll <= 0.0:
			return str(k)
	return str(weights.keys()[weights.size() - 1])

# Базовые веса пула, домноженные на биомные модификаторы (_biome_weights).
func _apply_biome_weights(base: Dictionary, key: String) -> Dictionary:
	var mods := _biome_weights(key)
	var out := {}
	for k in base:
		out[k] = float(base[k]) * float(mods.get(k, 1.0))
	return out

# Тост о теме биома в момент, когда биом СМЕНИЛСЯ относительно прошлого уровня
# (и на самом первом уровне). Без него перераспределение механик остаётся
# невидимым: игрок должен понимать, по каким правилам играет эти 5 уровней.
func _announce_biome(delay: float = 0.0) -> void:
	if _boss_level or _lair_active or _superboss_level or GameConfig.tutorial_mode:
		return
	if _level > 1 and _biome_of_level_mode(_level - 1) == _biome:
		return
	# Тост один на весь HUD: в Накале горизонт объявляется на тех же уровнях
	# (HORIZON_SPAN 5 == BIOME_SPAN 5), поэтому тему пускаем следом, а не поверх.
	if delay > 0.0:
		await get_tree().create_timer(delay).timeout
		if not is_inside_tree() or _won or _dead:
			return
	# [§38] Тема собирается из реально доступных механик, а не из фиксированного
	# текста: биом не имеет права обещать то, чего лестница ещё не открыла.
	flash_message("%s — %s" % [_biome_name, _biome_theme_line()])

func _ember_mult() -> float:
	# Серия чистых этажей × множитель сложности (награда за риск).
	var m := (1.0 + mini(_ember_streak, EMBER_STREAK_MAX) * EMBER_STREAK_STEP) * GameConfig.diff_reward_mult()
	# Контракты «Пепельный путь»/«Одно дыхание»: весь Накал ×1.5.
	var c := GameConfig.run_contract()
	if c == "ashes" or c == "onelife":
		m *= 1.5
	return m

# ══ §42 ОЦЕНКА УРОВНЯ ═══════════════════════════════════════════════════════
# Старая формула считала другую игру и после §39-§41 просто врала:
#   • ratio * 50 — половина шкалы за долю осколков. Она имела смысл, пока
#     собрать ВСЕ было обязательно (иначе не выйдешь), то есть всегда равнялась
#     1.0 и была бесплатной. Теперь осколки необязательны, и та же половина
#     штрафует ровно за то, ради чего §39 и делался: найти выход, не подметая
#     этаж.
#   • no_skills +15 — премия за ОТКАЗ от навыков. S требовал 95 очков, а без
#     этой премии максимум был 85: то есть S математически требовал не
#     пользоваться половиной игры. Оптимальная игра была скучной игрой.
#   • par = 20 + level*12 — время считалось под подметание сетки, а не под поиск.
#
# Новая шкала меряет то, чем игра стала: как быстро ты НАШЁЛ выход, выжил ли,
# держал ли землю (§41) и пользовался ли своим набором.
const RANK_W_SPEED := 30.0     # скорость относительно пар-времени
const RANK_W_CLEAN := 25.0     # ни одной потерянной жизни
const RANK_W_GROUND := 25.0    # доля времени на своей, ещё не отвоёванной земле
const RANK_W_SKILL := 20.0     # навыки применялись (а не «не применялись»)

# Пар-время: сколько уровень ЧЕСТНО занимает, если идти по делу. Считается от
# длины оптимального маршрута (_optimal_path_len, в клетках) плюс надбавка за
# площадь и этажи — поиск требует осмотреться, а не только пройти.
func _level_par() -> float:
	var area: float = float(maxi(_cols * _rows, 1))
	var floors: float = float(maxi(_floors, 1))
	var optimal: float = float(maxi(_optimal_path_len, 1))
	return 25.0 + optimal * 1.5 + sqrt(area) * 1.9 + (floors - 1.0) * 10.0

func _compute_rank() -> Dictionary:
	var par: float = _level_par()
	# Скорость: полный балл при укладывании в пар, ноль — при двойном пар-времени.
	var speed_frac: float = clampf(1.0 - (maxf(_elapsed - par, 0.0) / par), 0.0, 1.0)
	var clean: bool = _level_clean
	# Владение землёй: доля замеров, где игрок стоял на своей земле (§41).
	# Замеры идут в _sample_heat, раз в полсекунды.
	var ground_frac: float = 0.0
	if _ground_samples > 0:
		ground_frac = clampf(float(_own_ground_samples) / float(_ground_samples), 0.0, 1.0)
	# Мастерство: применения навыков за уровень с насыщением. Порог растёт с
	# глубиной, но не требует спама — это признак «пользовался набором», а не
	# счётчик нажатий.
	var used_now: int = 0
	for sk in ["flash", "dash", "sonar", "shield", "guide", "reveal", "pulse", "smother", "mark"]:
		used_now += int(GameConfig.skill_uses.get(sk, 0))
	var casts: int = maxi(used_now - _skill_uses_at_start, 0)
	var skill_target: float = 3.0 + float(_level) / 8.0
	var skill_frac: float = clampf(float(casts) / skill_target, 0.0, 1.0)

	var score: float = speed_frac * RANK_W_SPEED + ground_frac * RANK_W_GROUND + skill_frac * RANK_W_SKILL
	if clean:
		score += RANK_W_CLEAN
	var rank := "D"
	if score >= 90.0: rank = "S"
	elif score >= 75.0: rank = "A"
	elif score >= 58.0: rank = "B"
	elif score >= 40.0: rank = "C"
	# ratio оставлен в ответе: его показывает экран результатов и хранит история.
	var ratio: float = 1.0 if _shards_total <= 0 else float(_shards_collected) / float(_shards_total)
	return {"rank": rank, "score": int(round(score)), "ratio": ratio,
		"clean": clean, "fast": _elapsed <= par, "par": par,
		"speed": speed_frac, "ground": ground_frac, "skill": skill_frac, "casts": casts}

# 0..1: чем больше несомого Накала — тем агрессивнее враги (читают это значение).
func enemy_heat() -> float:
	if GameConfig.active_run < 0:
		return 0.0
	return clampf(_ember / EMBER_HEAT_FULL, 0.0, 1.0)

# Мягкий непрерывный рост агрессии врагов между «скачками» появления новых
# (см. _spawn_enemies) — растёт с уровнем, до +20% к 20 уровню, дальше не растёт.
func enemy_level_speed_mult() -> float:
	var m := (1.0 + minf(float(_level), 50.0) * 0.005) * GameConfig.diff_enemy_mult()
	if GameConfig.run_contract() == "swift":
		m *= 1.15   # контракт «Гон»: тьма быстрее
	return m

func _persist_ember() -> void:
	if GameConfig.active_run < 0:
		return
	var r: Dictionary = GameConfig.runs[GameConfig.active_run]
	r["ember_carried"] = _ember
	r["ember_banked"]  = _ember_banked
	r["ember_streak"]  = _ember_streak
	r["best_streak"]   = maxi(int(r.get("best_streak", 0)), _ember_streak)
	_check_vow()

# Обет слота выполнен? Разовое объявление + награда SP уйдёт в профиль «Уровней».
func _check_vow() -> void:
	var done := GameConfig.check_run_vow()
	if done != "":
		flash_message(GameConfig.tt("🕯 Обет исполнен: %s! Награда ждёт в профиле «Уровней»", "🕯 Vow fulfilled: %s! The reward awaits in your «Levels» profile") % done)
		if _fx:
			_fx.gold_pulse(2.0)

# Алтарь (станция в Накале) банкует несомый Накал в безопасность.
func bank_ember() -> int:
	if GameConfig.active_run < 0:
		return 0
	var amt := int(floor(_ember))
	if amt <= 0:
		return 0
	_ember_banked += amt
	_ember -= float(amt)
	_persist_ember()
	GameConfig.max_stat("best_ember", _ember_banked)
	GameConfig.save_game()
	# Подсказка про прокачку, если уже хватает на что-то непокупленное.
	var hint := ""
	for offer in ALTAR_OFFER:
		if not GameConfig.skills_unlocked.get(offer["id"], false) and _ember_banked >= int(offer["cost"]):
			hint = GameConfig.tt("  ·  прокачка: Пауза → Алтарь", "  ·  upgrade: Pause → Altar")
			break
	flash_message(GameConfig.tt("Алтарь · +%d Накала в банк (всего %d)%s", "Altar · +%d Ember banked (total %d)%s") % [amt, _ember_banked, hint])
	if _fx:
		_fx.gold_pulse(1.1)
	return amt

func _show_resume_banner() -> void:
	if _msg_label == null or not is_instance_valid(_msg_label):
		return
	var skills_n: int = 0
	for sk in ["sonar", "shield", "guide", "reveal", "pulse", "range", "legs", "capacity", "save", "charge", "magic"]:
		if GameConfig.skills_unlocked.get(sk, false):
			skills_n += 1
	_msg_label.text = GameConfig.tt("⟳ Забег продолжен\nГлубина %d   ·   банк %d Накала   ·   апгрейдов %d", "⟳ Run resumed\nDepth %d   ·   bank %d Ember   ·   %d upgrades") % [_level, _ember_banked, skills_n]
	_msg_label.visible = true
	await get_tree().create_timer(2.6).timeout
	if is_instance_valid(_msg_label) and not _dead and not _game_over and not _won:
		_msg_label.visible = false

func _open_altar_shop() -> void:
	if GameConfig.active_run < 0:
		return
	if is_instance_valid(_pause_overlay):
		_pause_overlay.visible = false
	_altar_layer = CanvasLayer.new()
	_altar_layer.layer = 4
	_altar_layer.process_mode = Node.PROCESS_MODE_ALWAYS
	add_child(_altar_layer)

	var dim := ColorRect.new()
	dim.set_anchors_preset(Control.PRESET_FULL_RECT)
	dim.color = Color(0.02, 0.03, 0.05, 0.9)
	_altar_layer.add_child(dim)

	var center := CenterContainer.new()
	center.set_anchors_preset(Control.PRESET_FULL_RECT)
	_altar_layer.add_child(center)

	var box := VBoxContainer.new()
	box.add_theme_constant_override("separation", 8)
	center.add_child(box)

	var title := Label.new()
	title.text = GameConfig.tt("АЛТАРЬ", "ALTAR")
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	title.add_theme_font_size_override("font_size", 28)
	title.add_theme_color_override("font_color", Color(1.0, 0.78, 0.4))
	box.add_child(title)

	var hint := Label.new()
	hint.text = GameConfig.tt("Трать Накал на улучшения. Эффект — со следующего этажа.", "Spend Ember on upgrades. The effect kicks in from the next floor.")
	hint.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	hint.add_theme_font_size_override("font_size", 14)
	hint.add_theme_color_override("font_color", Color(0.7, 0.66, 0.56))
	box.add_child(hint)

	_altar_bank_lbl = Label.new()
	_altar_bank_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_altar_bank_lbl.add_theme_font_size_override("font_size", 20)
	_altar_bank_lbl.add_theme_color_override("font_color", Color(0.95, 0.88, 0.6))
	box.add_child(_altar_bank_lbl)

	# Карточки товаров: сетка 5 колонок (иконка + имя + мастерство + цена).
	_altar_rows = GridContainer.new()
	_altar_rows.columns = 5
	_altar_rows.add_theme_constant_override("h_separation", 10)
	_altar_rows.add_theme_constant_override("v_separation", 10)
	box.add_child(_altar_rows)

	box.add_child(UIStyle.make_button(GameConfig.t("close_esc").split("  ")[0], _close_altar_shop, 200, 44, 20))

	_altar_refresh()

func _altar_refresh() -> void:
	if not is_instance_valid(_altar_rows):
		return
	_altar_bank_lbl.text = GameConfig.tt("Банк Накала: %d ⌀", "Ember bank: %d ⌀") % _ember_banked
	for c in _altar_rows.get_children():
		c.queue_free()
	for offer in ALTAR_OFFER:
		_altar_rows.add_child(_altar_card(offer))

# Карточка товара алтаря: иконка навыка, имя, мастерство (для активных) и
# кнопка-цена. Состояния: куплено (зелёная рамка) / доступно (тёплая) /
# не хватает (пригашена). Никакого «текстового квеста» — видно, что покупаешь.
func _altar_card(offer: Dictionary) -> Control:
	var id: String = offer["id"]
	var cost: int = int(offer["cost"])
	var owned: bool = GameConfig.skills_unlocked.get(id, false)
	var afford: bool = _ember_banked >= cost

	var panel := PanelContainer.new()
	var sb := StyleBoxFlat.new()
	sb.bg_color = Color(0.05, 0.06, 0.10, 0.95)
	sb.set_corner_radius_all(10)
	sb.set_border_width_all(2)
	if owned:
		sb.border_color = Color(0.35, 0.9, 0.5, 0.8)
	elif afford:
		sb.border_color = Color(1.0, 0.75, 0.3, 0.8)
	else:
		sb.border_color = Color(0.3, 0.34, 0.42, 0.6)
	sb.content_margin_left = 10
	sb.content_margin_right = 10
	sb.content_margin_top = 8
	sb.content_margin_bottom = 8
	panel.add_theme_stylebox_override("panel", sb)
	panel.custom_minimum_size = Vector2(148, 150)

	var v := VBoxContainer.new()
	v.add_theme_constant_override("separation", 4)
	v.alignment = BoxContainer.ALIGNMENT_CENTER
	panel.add_child(v)

	var icon := TextureRect.new()
	icon.texture = SkillIcons.make(id, 40)
	icon.stretch_mode = TextureRect.STRETCH_KEEP_CENTERED
	icon.custom_minimum_size = Vector2(44, 44)
	if not owned and not afford:
		icon.modulate = Color(0.55, 0.55, 0.6)
	v.add_child(icon)

	var nm := Label.new()
	nm.text = str(offer["name_en"]) if GameConfig.locale == "en" else str(offer["name"])
	nm.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	nm.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	nm.add_theme_font_size_override("font_size", 14)
	nm.add_theme_color_override("font_color", Color(0.88, 0.92, 1.0))
	v.add_child(nm)

	# Мастерство активных навыков: растёт от ПРИМЕНЕНИЙ (сила/длительность
	# +15% за уровень). Видно, что навык развивается и зачем им пользоваться.
	if GameConfig.skill_uses.has(id):
		var m := GameConfig.mastery(id)
		var ml := Label.new()
		ml.text = "★".repeat(m) + "☆".repeat(GameConfig.MASTERY_MAX - m)
		ml.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		ml.tooltip_text = GameConfig.tt("Мастерство: +15% силы за уровень.\nРастёт от применений навыка.", "Mastery: +15% power per star.\nGrows from using the skill.")
		ml.add_theme_font_size_override("font_size", 14)
		ml.add_theme_color_override("font_color", Color(1.0, 0.85, 0.3) if m > 0 else Color(0.45, 0.5, 0.6))
		v.add_child(ml)

	if owned:
		var ol := Label.new()
		ol.text = GameConfig.tt("✓ куплено", "✓ owned")
		ol.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		ol.add_theme_font_size_override("font_size", 14)
		ol.add_theme_color_override("font_color", Color(0.4, 0.95, 0.55))
		v.add_child(ol)
	else:
		var buy := UIStyle.make_button("%d ⌀" % cost, _on_altar_buy.bind(id), 90, 32, 16)
		buy.disabled = not afford
		buy.add_theme_color_override("font_color", Color(1.0, 0.85, 0.4) if afford else Color(0.5, 0.52, 0.58))
		v.add_child(buy)
	return panel

func _on_altar_buy(id: String) -> void:
	if _altar_buy(id):
		if _fx:
			_fx.gold_pulse(0.8)
		_altar_refresh()

func _altar_cost(id: String) -> int:
	for offer in ALTAR_OFFER:
		if offer["id"] == id:
			return int(offer["cost"])
	return 999999

func _altar_buy(id: String) -> bool:
	if GameConfig.skills_unlocked.get(id, false):
		return false
	var cost := _altar_cost(id)
	if _ember_banked < cost:
		return false
	_ember_banked -= cost
	GameConfig.skills_unlocked[id] = true
	if GameConfig.passives.has(id):
		GameConfig.passives[id] = true   # пассивки работают при unlocked И passive == true
	if GameConfig.all_active_skills_unlocked():
		GameConfig.skills_unlocked["apex"] = true
	_persist_ember()
	GameConfig.save_game()
	return true

func _close_altar_shop() -> void:
	if is_instance_valid(_altar_layer):
		_altar_layer.queue_free()
	_altar_layer = null   # queue_free отложен — снимаем ссылку сразу, чтобы Escape не «видел» магазин
	if is_instance_valid(_pause_overlay):
		_pause_overlay.visible = true

# Апекс (форма guide): телепортация игрока к выходу.
# Полная форма телепортирует прямо к выходу; эхо — на полпути.
func apex_teleport_to_exit(full: bool) -> void:
	if _player == null or not is_instance_valid(_player):
		return
	# [§39] Апекс-Искра переносила к выходу независимо от того, известен он или
	# нет — то есть молча обходила весь поиск. Теперь перенос СНАЧАЛА находит
	# выход: это законная награда за ★5 и активную погоню, но она проходит
	# через ту же дверь, что и все остальные способы узнать, где портал.
	if not exit_located():
		_locate_exit(GameConfig.tt("Апекс-прозрение", "Apex insight"))
	var target := _cell_to_world(_exit_cell) + Vector2(0, _exit_floor * _floor_gap)
	if full:
		_player.global_position = target
		_player.current_floor = _exit_floor
		# CLAUDE.md: КАЖДАЯ точка телепорта проходит через validate_arrival —
		# клетка выхода проходима, но правило не имеет исключений.
		validate_arrival(_player, _exit_floor)
	else:
		_player.global_position = _player.global_position.lerp(target, 0.5)
	_player.snap_camera()
	if _fx:
		_fx.flash(Color(1.0, 0.7, 0.3), 0.4)

func on_player_death() -> void:
	if _dead or _won or _game_over:
		return
	# Обучение проиграть нельзя: свет погас — подзаряжаем бесплатно, сколько
	# угодно раз, чтобы игрок гарантированно дошёл до конца уроков.
	if GameConfig.tutorial_mode:
		if _player and is_instance_valid(_player):
			_player.energy = _player.max_energy
		flash_message(GameConfig.tt("Свет погас — в игре это стоило бы жизни. Но это обучение: заряжаем бесплатно ✦", "Your Light ran out — in a real run that would cost a life. But this is the tutorial: recharging for free ✦"))
		if _fx:
			_fx.gold_pulse(1.2)
		return
	_lives -= 1
	_update_lives()
	_level_clean = false                   # этаж больше не «чистый» — серия прервётся
	if GameConfig.active_run >= 0:
		_ember *= 0.5                      # потеря жизни сжигает половину несомого Накала
		_ember_streak = 0
		_persist_ember()
		GameConfig.lives = _lives          # фиксируем убыль жизней в слоте
		GameConfig.save_game()

	# Резкий отклик на смерть: красная вспышка + сильная тряска
	if _fx:
		_fx.flash(Color(1.0, 0.2, 0.15), 0.55)
	if _player and is_instance_valid(_player):
		_player.add_shake(13.0, 0.5)

	if _lives <= 0:
		_game_over = true
		if GameConfig.active_run >= 0:
			GameConfig.runs[GameConfig.active_run]["ended"] = true
			GameConfig.save_game()
			_msg_label.text = GameConfig.tt("ЗАБЕГ ОКОНЧЕН\nГлубина: %d\n\nEsc — в меню", "RUN OVER\nDepth: %d\n\nEsc — to menu") % _level
		else:
			_msg_label.text = GameConfig.tt("ИГРА ОКОНЧЕНА\n\nEsc — в меню", "GAME OVER\n\nEsc — to menu")
		_msg_label.visible = true
		return

	_dead = true
	_msg_label.text = GameConfig.tt("Свет погас!  Осталось жизней: %d\nВозврат к последней станции…", "Your Light ran out!  Lives left: %d\nReturning to the last station…") % _lives
	_msg_label.visible = true
	await get_tree().create_timer(1.2).timeout
	if not is_instance_valid(_player):
		return
	_player.respawn(_cp_pos, _cp_floor)
	_msg_label.visible = false
	_dead = false

func _update_lives() -> void:
	if _lives_label:
		_lives_label.text = GameConfig.t("lives") % maxi(_lives, 0)
	# Иконка статична; на последней жизни — только краснее (без анимации).
	if _lives_icon and is_instance_valid(_lives_icon):
		_lives_icon.col = Color(1.0, 0.32, 0.38) if _lives <= 1 else Color(1.0, 0.5, 0.55)
		_lives_icon.queue_redraw()

func collect_shard(pos: Vector2 = Vector2.INF) -> void:
	_shards_collected += 1
	_keys += 1
	_clean_shard_streak += 1
	_grant_clue()   # [§39] осколок — не замок, а улика о выходе
	# [GAMEDESIGN §32] Серия чистых осколков теперь ВИДНА и ПЛАТИТ: каждый
	# следующий осколок без урона дороже предыдущего. Раньше эта же переменная
	# была скрытым триггером Резонанса — игрок не знал, что она существует,
	# и «аккуратно» играть было не за что.
	var mult: float = shard_streak_mult()
	var xp: int = int(round(75.0 * mult))
	GameConfig.add_xp(xp)
	_show_reward(pos, "+%d XP" % xp, Color(1.0, 0.88, 0.45))
	if _clean_shard_streak >= 2:
		_pulse_streak_hud()
	GameConfig.bump_stat("shards_total")
	_announce_milestones()
	if GameConfig.active_run >= 0:
		# [GAMEDESIGN §35] Серия чистых осколков (§32) теперь платит и Накалом, а
		# не только опытом: в забеге аккуратность — главная валюта, и странно было,
		# что она влияла на XP и не влияла на ставку. Ранг намеренно НЕ трогаем:
		# там четыре критерия, и пятый пересобрал бы всю шкалу S/A/B/C/D.
		_ember += EMBER_PER_SHARD * _ember_mult() * shard_streak_mult()
		_persist_ember()
	# Осколок кормит Волю — активный сбор поощряет использование навыков.
	if _player and is_instance_valid(_player) and _player.has_method("add_will"):
		_player.add_will(_player.WILL_PER_SHARD)
		# Прирост Воли тоже надо видеть: полоса растёт на глазах, но связь с
		# осколком без подписи не читается.
		_show_reward(pos, GameConfig.tt("+Воля", "+Will"), Color(0.4, 0.92, 0.98), 13, Vector2(44, 16))
		if GameConfig.run_contract() == "swift":
			_player.add_will(0.4)   # контракт «Гон»: осколки щедрее на Волю
	# Хард-режим: осколок — ЕДИНСТВЕННЫЙ источник света и заряда Озарения
	# (станций нет), поэтому глоток двойной + капля озарения.
	if _hard and _player and is_instance_valid(_player):
		_player.energy = minf(_player.max_energy, _player.energy + 0.25)
		if "reveal_charge" in _player:
			_player.reveal_charge = minf(1.0, _player.reveal_charge + 0.12)
	_update_shards()
	play_sfx(_sfx_shard)   # звук подбора осколка
	# Сочный отклик: золотой всплеск по краям + короткая вспышка + лёгкая тряска
	if _fx:
		_fx.gold_pulse(1.5)
		_fx.flash(Color(1.0, 0.9, 0.55), 0.16)
	if _player and is_instance_valid(_player):
		_player.add_shake(4.0, 0.18)
	# Надпись о прогрессе: сколько осколков ещё осталось на этом этаже
	var f: int = _player.current_floor if (_player and is_instance_valid(_player)) else 0
	if f >= 0 and f < _shards_remaining.size():
		_shards_remaining[f] = maxi(0, int(_shards_remaining[f]) - 1)
		var rem: int = _shards_remaining[f]
		var rem_total := 0
		for r in _shards_remaining:
			rem_total += int(r)
		_refresh_exit_lock()
		# [§39] Осколок больше не отпирает выход, поэтому и текст другой: он
		# даёт ключ от ДВЕРИ между этажами, а сверх того — улику (её объявляет
		# _grant_clue отдельным тостом, дублировать здесь незачем).
		if _clues < CLUE_MAX and not _exit_located:
			pass   # весь текст в этот момент — про улику
		elif rem > 0:
			flash_message(GameConfig.tt("✦ Осколок (+ключ) · на этаже ещё %d", "✦ Shard (+key) · %d left on this floor") % rem)
		else:
			flash_message(GameConfig.tt("✦ Осколок (+ключ) · этаж зачищен!", "✦ Shard (+key) · floor cleared!"))

	# --- РЕЗОНАНС (п.10.1): 3 осколка подряд без урона — лабиринт «благодарит»,
	# темнота ненадолго отступает. Заслуженно, но без объяснений: формирует
	# «если я аккуратен — случается хорошее». Раз за уровень.
	if not _resonance_done and not GameConfig.tutorial_mode and _clean_shard_streak >= 3:
		_resonance_done = true
		reveal(8.0)
		if _fx:
			_fx.gold_pulse(2.0)
		flash_message(GameConfig.tt("✧ Резонанс — тьма отступает", "✧ Resonance — the dark retreats"))

	# --- ЭХО ШАРДА (п.10.3): из точки сбора с задержкой «вываливается» второй.
	# Задержка обязательна — игрок уже ушёл и должен решить: вернуться или нет.
	# Первый осколок уровня — всегда (задаёт ожидание), дальше — редкий шанс.
	if not _echo_done and not GameConfig.tutorial_mode and pos != Vector2.INF:
		var chance := 1.0 if _shards_collected == 1 else 0.09
		if randf() < chance:
			_echo_done = true
			if randf() < ECHO_DARK_CHANCE:
				_spawn_echo_ambush(pos, f)
			else:
				_spawn_echo_shard(pos, f)

# Эхо шарда: через 1.7 сек в точке сбора поднимается второй осколок.
# Золотая вспышка-предвестник — игрок слышит/видит, что позади что-то появилось.
func _spawn_echo_shard(pos: Vector2, f: int) -> void:
	await get_tree().create_timer(1.7).timeout
	if _won or _dead or f < 0 or f >= _floor_containers.size():
		return
	var container: Node2D = _floor_containers[f]
	if container == null or not is_instance_valid(container):
		return
	var b := Node2D.new()
	b.set_script(load("res://burst.gd"))
	b.color = Color(1.0, 0.85, 0.42, 1.0)
	b.max_scale = 4.0
	b.dur = 0.5
	b.light_energy = 2.0
	add_child(b)
	b.global_position = pos
	var sh := Area2D.new()
	sh.set_script(load("res://shard.gd"))
	sh.game = self
	sh.position = pos - container.position
	container.add_child(sh)
	_shards_total += 1
	if f < _shards_remaining.size():
		_shards_remaining[f] = int(_shards_remaining[f]) + 1
	beep()
	flash_message(GameConfig.tt("✦ Эхо осколка — позади что-то блеснуло…", "✦ Shard echo — something glinted behind you…"))

# Тёмная сторона эха шарда (§10.3, ECHO_DARK_CHANCE): вместо второго осколка
# из той же точки выпрыгивает засада — FAST-враг, а все враги на этаже
# чуют, что что-то случилось, и на 5 секунд бегут быстрее (§10.3 «тёмная
# сторона»). Игрок не знает заранее, шард это будет или засада — риск жадности.
func _spawn_echo_ambush(pos: Vector2, f: int) -> void:
	await get_tree().create_timer(1.7).timeout
	if _won or _dead or f < 0 or f >= _grids.size():
		return
	var e := Node2D.new()
	e.set_script(load("res://pursuer.gd"))
	e.enemy_type = 1   # FAST — засада должна быть резкой, не медленной
	e.spawn_level = _level
	e._enemy_floor = f
	e.position = pos
	e.target = _player
	e._game = self
	e.process_mode = Node.PROCESS_MODE_PAUSABLE
	add_child(e)
	for other in get_tree().get_nodes_in_group("enemy"):
		if other == e or not is_instance_valid(other):
			continue
		if "_enemy_floor" in other and int(other._enemy_floor) == f and other.has_method("apply_ambush_alert"):
			other.apply_ambush_alert(5.0)
	var b := Node2D.new()
	b.set_script(load("res://burst.gd"))
	b.color = Color(1.0, 0.34, 0.08, 1.0)   # тревожный оранжевый — тон FAST-врага
	b.max_scale = 4.0
	b.dur = 0.5
	add_child(b)
	b.global_position = pos
	if _player and is_instance_valid(_player):
		_player.add_shake(6.0, 0.25)
	beep()
	flash_message(GameConfig.tt("⚠ Засада! Эхо было ловушкой — враги учуяли", "⚠ Ambush! The echo was a trap — enemies caught the scent"))

# Портал-выход (v1.9) заперт, пока на любом ПОСТРОЕННОМ этаже остаются
# несобранные осколки. Выход стоит на последнем этаже — к моменту, когда
# игрок туда доберётся, все промежуточные этажи уже построены (иначе он бы
# физически не прошёл через их двери), так что сумма _shards_remaining на
# тот момент — это честный общий итог по уровню, а не частичный срез.
# ══ §39 «ВЫХОД НАДО НАЙТИ» ══════════════════════════════════════════════════
# До 2.0 портал был заперт, пока не собран КАЖДЫЙ осколок уровня. Из-за этого
# ответ на вопрос «куда идти» всегда был один — «везде», и уровень сводился к
# подметанию сетки 60×48 на семи этажах. Поиска не существовало: поиск
# вознаграждает догадку, подметание — терпение.
#
# Теперь портал открыт всегда, но его МЕСТО неизвестно. Осколки перестают быть
# ключами от выхода и становятся УЛИКАМИ: каждый следующий сужает круг —
# этаж, сторона света, расстояние, точка. Осколок остаётся ключом от ДВЕРЕЙ
# между этажами (_keys), так что «сколько собрать» — это решение (сколько
# знания и сколько дверей я могу себе позволить), а не обязанность.
#
# Обучение играет по старым правилам: там ведут за руку, и «собери всё» — это
# нормальный первый урок.
const CLUE_MAX := 4                # столько улик полностью раскрывают выход
const CLUE_SIGHT_CELLS := 5.0      # с такого расстояния портал считается увиденным
var _clues: int = 0                # получено улик на этом уровне
var _exit_located: bool = false    # выход обнаружен: увиден глазами или вычислен
var _clue_label: Label             # строка HUD с последней уликой

# Знает ли игрок, ГДЕ выход. От этого зависят Искра, Пульс и метка на миникарте:
# они — инструменты следствия, а не ответ в конце учебника.
func exit_located() -> bool:
	return _exit_located

# Улика за осколок. Первые CLUE_MAX сужают круг, дальнейшие осколки просто
# остаются ключами/опытом — иначе поиск обесценился бы полностью.
func _grant_clue() -> void:
	# [§42] Обучение больше не исключение: улики — это и есть то, чему надо
	# научить, а не то, от чего надо уберечь.
	if _lair_active or _superboss_level or _boss_arena_mode:
		return
	if _exit_located or _clues >= CLUE_MAX:
		return
	_clues += 1
	# [§44] В забеге улика платит Накалом: §39 сделал поиск основным занятием,
	# а платила по-прежнему только зачистка осколков.
	if GameConfig.active_run >= 0:
		_ember += EMBER_PER_CLUE * _ember_mult()
		_persist_ember()
	var txt := _clue_text(_clues)
	if _clues >= CLUE_MAX:
		_locate_exit(GameConfig.tt("Улики сошлись", "The clues line up"))
		return
	flash_message(GameConfig.tt("🔍 Улика %d/%d: %s", "🔍 Clue %d/%d: %s") % [_clues, CLUE_MAX, txt])
	if _clue_label:
		_clue_label.text = txt
		_clue_label.visible = true
	if _fx:
		_fx.gold_pulse(1.2)

# Текст улики. Порядок сужения намеренно такой: сначала «где искать вообще»
# (этаж), потом «в какой стороне», потом «как далеко» — каждая следующая
# полезна только вместе с предыдущей, поэтому осколки хочется собирать подряд.
func _clue_text(n: int) -> String:
	match n:
		1:
			if _exit_floor == 0:
				return GameConfig.tt("выход на этом этаже", "the exit is on this floor")
			return GameConfig.tt("выход на этаже %d", "the exit is on floor %d") % (_exit_floor + 1)
		2:
			return GameConfig.tt("выход в %s части этажа", "the exit lies in the %s part of the floor") % _clue_side()
		3:
			# Расстояние огрублено до десятков: улика сужает круг, но не рисует
			# стрелку — иначе третий осколок уже отвечал бы на всё.
			var d: int = int(round(float(_exit_dist_cells()) / 10.0) * 10.0)
			return GameConfig.tt("до выхода около %d клеток", "roughly %d cells to the exit") % maxi(d, 5)
	return ""

# Сторона света, в которой лежит выход — относительно ЦЕНТРА этажа, а не
# игрока: улика должна быть свойством лабиринта, не зависящим от того, где
# игрок стоял в момент подбора.
func _clue_side() -> String:
	var dx: float = float(_exit_cell.x) - float(_cols) * 0.5
	var dy: float = float(_exit_cell.y) - float(_rows) * 0.5
	var ns := ""
	var we := ""
	if absf(dy) > float(_rows) * 0.15:
		ns = GameConfig.tt("север", "north") if dy < 0.0 else GameConfig.tt("юж", "south")
	if absf(dx) > float(_cols) * 0.15:
		we = GameConfig.tt("запад", "west") if dx < 0.0 else GameConfig.tt("восточ", "east")
	if ns.is_empty() and we.is_empty():
		return GameConfig.tt("центральной", "central")
	if GameConfig.locale == "en":
		return (ns + "-" + we) if (not ns.is_empty() and not we.is_empty()) else (ns + we)
	if ns.is_empty():
		return we + "ной"
	if we.is_empty():
		return ns + ("ной" if ns == "юж" else "ной")
	return ns + "о-" + we + "ной"

# Примерное расстояние до выхода в клетках (манхэттен по сетке этажей).
func _exit_dist_cells() -> int:
	if _player == null or not is_instance_valid(_player):
		return 10
	var f: int = _player.current_floor
	var px: int = int(round((_player.global_position.x / TILE - 1.5) / 2.0))
	var py: int = int(round(((_player.global_position.y - f * _floor_gap) / TILE - 1.5) / 2.0))
	return absi(px - _exit_cell.x) + absi(py - _exit_cell.y) + absi(f - _exit_floor) * 12

# Выход обнаружен: улики сошлись или игрок увидел портал своими глазами.
func _locate_exit(reason: String) -> void:
	if _exit_located:
		return
	_exit_located = true
	flash_message(GameConfig.tt("✦ %s — выход найден! Метка на карте.", "✦ %s — the exit is found! Marked on the map.") % reason)
	if _clue_label:
		_clue_label.text = GameConfig.tt("выход найден", "exit located")
	if _fx:
		_fx.gold_pulse(2.2)
		_fx.flash(Color(1.0, 0.86, 0.35), 0.25)
	play_sfx(_sfx_key)

# Увидел портал сам — улики больше не нужны. Дистанция намеренно небольшая:
# «увидел» должно значить «действительно набрёл», а не «прошёл по соседнему
# коридору в темноте».
func _check_exit_sighted() -> void:
	if _exit_located or _player == null or not is_instance_valid(_player):
		return
	if _lair_active or _superboss_level or _boss_arena_mode:
		return
	# В обучении лабиринт маленький, поэтому «набрёл сам» срабатывает почти
	# сразу — это и нужно: урок про поиск должен заканчиваться находкой.
	if _player.current_floor != _exit_floor:
		return
	# [§44] Радиус «увидел портал» растёт вместе с обзором. Раньше он был
	# константой в 5 клеток, и Озарение — навык «увидеть планировку» — не
	# помогало найти выход вообще: портал мог светиться на весь экран, а игра
	# считала, что игрок его не видел. Теперь Озарение и Сонар — настоящие
	# инструменты поиска, как Искра и Пульс после §39.1.
	var radius: float = CLUE_SIGHT_CELLS
	var how := GameConfig.tt("Ты сам набрёл на портал", "You stumbled onto the portal")
	if _reveal_time > 0.0:
		radius = CLUE_SIGHT_CELLS * 4.0
		how = GameConfig.tt("Озарение выхватило портал из тьмы", "Reveal caught the portal out of the dark")
	elif _sonar_vision_time > 0.0:
		radius = CLUE_SIGHT_CELLS * 2.2
		how = GameConfig.tt("Сонар нащупал портал", "Sonar felt out the portal")
	if float(_exit_dist_cells()) <= radius:
		_locate_exit(how)

func _refresh_exit_lock() -> void:
	if _exit_node == null or not is_instance_valid(_exit_node):
		return
	# [§42] Замок по осколкам снят ВЕЗДЕ, включая обучение. В §39 обучение
	# намеренно оставили на старых правилах — и это оказалось ошибкой: оно
	# учило собирать всё ради открытия портала, то есть готовило игрока к игре,
	# которой больше нет. Теперь портал открыт всегда и его надо найти.
	var should_lock := false
	if should_lock != _exit_node.locked:
		if should_lock:
			_exit_node.set_locked_silent(true)
		else:
			_exit_node.unlock()

func has_key() -> bool:
	return _keys > 0

func use_key() -> bool:
	if _keys > 0:
		_keys -= 1
		_update_shards()
		play_sfx(_sfx_key)   # ключ сработал, запертая дверь открывается
		flash_message(GameConfig.tt("🔑 Ключ потрачен · осталось %d", "🔑 Key spent · %d left") % _keys)
		return true
	return false

func _update_shards() -> void:
	if _shards_label:
		_shards_label.text = GameConfig.tt("Осколки: %d / %d", "Shards: %d / %d") % [_shards_collected, _shards_total]
	if _streak_label:
		# Со второго осколка подряд: показываем множитель. Цвет теплеет к потолку.
		var show: bool = _clean_shard_streak >= 2
		_streak_label.visible = show
		if show:
			var m: float = shard_streak_mult()
			var k: float = clampf((m - 1.0) / (STREAK_MULT_MAX - 1.0), 0.0, 1.0)
			_streak_label.text = GameConfig.tt("серия ×%d  ·  XP ×%.2f", "streak x%d  -  XP x%.2f") % [_clean_shard_streak, m]
			_streak_label.add_theme_color_override("font_color",
				Color(1.0, 0.72, 0.45).lerp(Color(1.0, 0.95, 0.45), k))
		if _shards_icon and is_instance_valid(_shards_icon) and _shards_shown >= 0 and _shards_collected != _shards_shown:
			_shards_icon.pop()
		_shards_shown = _shards_collected
	if _keys_label:
		_keys_label.text = GameConfig.tt("Ключи: %d", "Keys: %d") % _keys
		if _keys_icon and is_instance_valid(_keys_icon) and _keys_shown >= 0 and _keys != _keys_shown:
			_keys_icon.pop()
		_keys_shown = _keys

func flash_message(text: String) -> void:
	if _toast_label and _toast_panel:
		_toast_label.text = text
		_toast_panel.visible = true
		# Держится тем дольше, чем длиннее текст — короткую реплику не обязательно
		# читать 7 секунд, а длинную не обрежет раньше, чем её успеешь прочитать.
		# Крестик (см. _build_hud) закрывает раньше вручную, если не хочешь ждать.
		_toast_time = clampf(2.2 + text.length() * 0.045, 2.2, 7.0)
		# Появление: мягкое проявление (без выезда по Y — панель теперь внутри
		# общего VBoxContainer-стека _top_stack, который сам управляет позицией
		# каждый кадр; анимировать position там бессмысленно, container её тут же
		# перезапишет).
		var m := _toast_panel.modulate
		m.a = 0.0
		_toast_panel.modulate = m
		var t := create_tween()
		t.tween_property(_toast_panel, "modulate:a", 1.0, 0.18)

func on_player_win() -> void:
	if _won:
		return
	_won = true
	if _player:
		_player.active = false

	# «Эхо времени» (§7): запоминаем ЭТОТ забег как «прошлый раз» для этого же
	# номера уровня — перезаписывает предыдущий, не копится (см. GameConfig.echo_trails).
	if GameConfig.echo_time_enabled and not GameConfig.tutorial_mode and not _lair_active \
			and not _superboss_level and not _hard and not _organic:
		GameConfig.echo_trails[_level] = _echo_trail_now.duplicate()
		if not GameConfig.test_mode:
			GameConfig.save_game()

	if GameConfig.tutorial_mode:
		# Обучение не трогает прогресс «Уровней» (см. _tut_restore_skill_uses/
		# add_xp·bump_stat guard в config.gd) — просто помечает пройденным и
		# ведёт игрока на экран «Играть», где он сам выберет режим.
		if _tut_panel and is_instance_valid(_tut_panel):
			_tut_panel.visible = false
		if _tut_lesson_panel and is_instance_valid(_tut_lesson_panel):
			_tut_lesson_panel.visible = false
		if _toast_panel and is_instance_valid(_toast_panel):
			_toast_panel.visible = false
		play_sfx(_sfx_win)
		if _fx:
			_fx.flash(Color(1.0, 0.85, 0.4), 0.4)
			_fx.gold_pulse(2.2)
		# Несколько коротких этапов подряд (GameConfig.tutorial_stage), а не один
		# большой лабиринт разом — каждый этап заканчивается своим коротким
		# экраном-переходом, финальный (последний этап) — полным «Обучение пройдено!».
		if GameConfig.tutorial_stage < GameConfig.TUTORIAL_STAGE_COUNT - 1:
			await _show_tutorial_stage_screen(
				GameConfig.tt("Этап %d из %d пройден!", "Stage %d of %d complete!") % \
					[GameConfig.tutorial_stage + 1, GameConfig.TUTORIAL_STAGE_COUNT],
				GameConfig.tt("Переходим к следующему короткому этапу обучения.", "Moving on to the next short tutorial stage."),
				GameConfig.tt("Дальше", "Next"))
			GameConfig.tutorial_stage += 1
			_restart()
			return
		await _show_tutorial_complete_screen()
		GameConfig.tutorial_stage = 0
		GameConfig.open_mode_on_start = true   # меню сразу откроет экран «Играть»
		_goto_menu()
		return

	if _lair_active:
		_lair_victory()
		return

	if _caves_active:
		_caves_victory()
		return

	play_sfx(_sfx_win)   # фанфары завершения уровня

	# Праздничный отклик: золотая вспышка и всплеск по краям
	if _fx:
		_fx.flash(Color(1.0, 0.85, 0.4), 0.4)
		_fx.gold_pulse(2.2)

	# Салют на месте игрока: большое кольцо света + фонтан искр
	if _player and is_instance_valid(_player):
		var b := Node2D.new()
		b.set_script(load("res://burst.gd"))
		b.color = Color(1.0, 0.88, 0.5, 1.0)
		b.max_scale = 16.0
		b.dur = 0.9
		b.light_energy = 3.2
		add_child(b)
		b.global_position = _player.global_position
		var sp := CPUParticles2D.new()
		sp.set_script(load("res://sparkle.gd"))
		sp.spark_color = Color(1.0, 0.9, 0.55)
		sp.spark_amount = 44
		sp.spark_speed = 340.0
		add_child(sp)
		sp.global_position = _player.global_position
		_player.add_shake(7.0, 0.4)

	# Оценка прохождения уровня (ранг) — в обоих режимах.
	var rank_info := _compute_rank()
	var rk: String = rank_info["rank"]
	GameConfig.bump_stat("rank_" + rk)
	GameConfig.note_rank(rk)   # серии для благословения/снисхождения
	if GameConfig.active_run < 0:
		GameConfig.record_level_best_rank(_level, rk)   # витрина в выборе уровня
	var rmult: float = GameConfig.rank_reward_mult(rk)   # ранг множит награды уровня
	if GameConfig.active_run >= 0:
		var ranks: Array = GameConfig.runs[GameConfig.active_run]["ranks"]
		ranks.append({
			"lvl": _level, "rank": rk, "score": rank_info["score"],
			"shards": _shards_collected, "total": _shards_total,
			"clean": rank_info["clean"], "ground": rank_info["ground"],
			"time": _elapsed,
		})
	var rank_line := GameConfig.tt("Ранг %s   ·   осколки %d/%d   ·   %d очк.", "Rank %s   ·   shards %d/%d   ·   %d pts.") % [rk, _shards_collected, _shards_total, rank_info["score"]]
	# Расшифровка ранга: игроку видно, чего именно не хватило до S.
	var rank_detail := GameConfig.tt(
		"скорость %d%% · без потерь %s · своя земля %d%% · навыки %d%% (%d) · награда ×%.2f",
		"speed %d%% · no losses %s · held ground %d%% · skills %d%% (%d) · reward ×%.2f") % [
		int(round(float(rank_info["speed"]) * 100.0)),
		"✓" if rank_info["clean"] else "✗",
		int(round(float(rank_info["ground"]) * 100.0)),
		int(round(float(rank_info["skill"]) * 100.0)),
		int(rank_info["casts"]),
		rmult]

	GameConfig.push_level_history({
		"level": _level, "time": _elapsed, "par": rank_info["par"],
		"shards_pct": rank_info["ratio"], "rank": rk,
		"no_dmg": rank_info["clean"], "skills_used": int(rank_info["casts"]) > 0,
		"mode": "накал" if GameConfig.active_run >= 0 else "уровни",
		"diff": GameConfig.difficulty,
	})
	_announce_milestones()   # levels_cleared/прочее могли открыть навык
	_last_rank_line = rank_line
	_last_rank_detail = rank_detail

	if GameConfig.active_run >= 0:
		# Режим «Накал»: бесконечный спуск, прогресс пишется в слот забега.
		GameConfig.add_xp(int(400 * rmult))
		GameConfig.bump_stat("levels_cleared")
		_announce_milestones()
		# Награда Накалом за этаж + бонус и рост серии за «чистый» спуск.
		_ember += EMBER_LEVEL_BONUS * _ember_mult() * rmult
		if _level_clean:
			_ember += EMBER_CLEAN_BONUS * _ember_mult()
			_ember_streak = mini(_ember_streak + 1, EMBER_STREAK_MAX)
		else:
			_ember_streak = 0
		_persist_ember()
		GameConfig.level = _level + 1
		GameConfig.lives = _lives          # жизни переносятся в следующий этаж
		GameConfig.save_game()             # маршрутизируется в слот
		_check_vow()                       # глубина/серия могли исполнить обет
		var clean_tag := GameConfig.tt("  ·  чисто ×%d", "  ·  clean ×%d") % _ember_streak if _level_clean else ""
		_last_rank_line = GameConfig.tt("Глубина %d   ·   ранг %s\nНакал %d%s   ·   %d очк.", "Depth %d   ·   rank %s\nEmber %d%s   ·   %d pts.") % [_level, rk, int(_ember), clean_tag, rank_info["score"]]
		# Раньше здесь на 1 секунду мелькала нечитаемая жёлтая надпись с той же
		# расшифровкой ранга, а потом БЕЗВОЗВРАТНО пропадала — экран статов её
		# не повторял. Теперь расшифровка идёт прямо в постоянный (с кнопками,
		# без таймера) экран результатов — коротким салютом ждём только фейерверк.
		await get_tree().create_timer(0.6).timeout
		await _show_stats_screen()
		_apply_stats_choice()
	elif _level < MAX_LEVEL:
		GameConfig.add_xp(int(400 * rmult))   # 400 XP за уровень × множитель ранга
		GameConfig.bump_stat("levels_cleared")   # раньше считалось только в «Накале»
		_announce_milestones()
		var _old_unlocked := GameConfig.max_unlocked_level
		GameConfig.level = _level + 1
		GameConfig.max_unlocked_level = maxi(GameConfig.max_unlocked_level, _level + 1)
		_announce_mode_unlocks(_old_unlocked, GameConfig.max_unlocked_level)
		GameConfig.save_game()
		_last_rank_line = GameConfig.tt("Уровень %d пройден!", "Level %d cleared!") % _level
		await get_tree().create_timer(0.6).timeout
		await _show_stats_screen()
		_apply_stats_choice()
	else:
		GameConfig.save_game()
		_win_label.text = GameConfig.tt("ПОБЕДА!  Все %d уровней\n%s\nВремя: %.1f с\n\nEsc — в меню", "VICTORY!  All %d levels\n%s\nTime: %.1f s\n\nEsc — to menu") % [MAX_LEVEL, rank_line, _elapsed]
		_win_label.visible = true

# --- Логово: победа над владыкой тьмы центрального тронного зала ---

func _lair_victory() -> void:
	play_sfx(_sfx_win)
	if _fx:
		_fx.flash(Color(1.0, 0.3, 0.3), 0.45)
		_fx.gold_pulse(2.4)
	if _player and is_instance_valid(_player):
		var b := Node2D.new()
		b.set_script(load("res://burst.gd"))
		b.color = Color(1.0, 0.4, 0.35, 1.0)
		b.max_scale = 18.0
		b.dur = 0.9
		b.light_energy = 3.4
		add_child(b)
		b.global_position = _player.global_position
		var sp := CPUParticles2D.new()
		sp.set_script(load("res://sparkle.gd"))
		sp.spark_color = Color(1.0, 0.5, 0.4)
		sp.spark_amount = 44
		sp.spark_speed = 340.0
		add_child(sp)
		sp.global_position = _player.global_position

	GameConfig.add_xp(500 + _level * 60)
	var was_last: bool = _level >= GameConfig.LAIR_LEVELS
	GameConfig.lair_max_unlocked = maxi(GameConfig.lair_max_unlocked, mini(_level + 1, GameConfig.LAIR_LEVELS))
	GameConfig.save_game()

	if was_last:
		_win_label.text = GameConfig.tt("ЛОГОВО ПОКОРЕНО!\nВсе %d владык тьмы повержены.\nВремя: %.1f с\n\nEsc — в меню", "LAIR CONQUERED!\nAll %d dark lords have been defeated.\nTime: %.1f s\n\nEsc — to menu") % [GameConfig.LAIR_LEVELS, _elapsed]

		_win_label.visible = true
		return

	_win_label.text = GameConfig.tt("Логово %d/%d покорено!\nВладыка тьмы повержен.\nВремя: %.1f с", "Lair %d/%d conquered!\nThe dark lord is defeated.\nTime: %.1f s") % [_level, GameConfig.LAIR_LEVELS, _elapsed]
	_win_label.visible = true
	_show_lair_next_buttons()

# Кнопки под текстом победы: следующее Логово или в меню (без хоткеев рестарта —
# перезапуск только через меню, как и везде в игре).
func _show_lair_next_buttons() -> void:
	var wrap := CenterContainer.new()
	wrap.set_anchors_preset(Control.PRESET_BOTTOM_WIDE)
	wrap.offset_top = -170
	wrap.offset_bottom = -40
	wrap.mouse_filter = Control.MOUSE_FILTER_PASS
	_hud_layer.add_child(wrap)
	var box := VBoxContainer.new()
	box.alignment = BoxContainer.ALIGNMENT_CENTER
	box.add_theme_constant_override("separation", 14)
	wrap.add_child(box)
	box.add_child(_make_overlay_button(GameConfig.tt("Следующее логово →", "Next lair →"), func() -> void:
		GameConfig.lair_level = _level + 1
		get_tree().paused = false
		get_tree().reload_current_scene()))
	box.add_child(_make_overlay_button(GameConfig.t("pause_menu"), _goto_menu))

# --- Пещеры (v4.0, §60): обычный find-the-exit, отдельная прогрессия ---
# [v4.0] Клон _lair_victory() — та же форма (фейерверк → XP → прогресс своего
# режима → кнопка «дальше»), но триггер прежний: игрок НАШЁЛ ВЫХОД (обычная
# ветка on_player_win), а не убил босса. Ранг здесь намеренно не считается —
# как и у Логова: это лёгкий побочный режим, не претендующий на место в
# системе рангов кампании.
func _caves_victory() -> void:
	play_sfx(_sfx_win)
	if _fx:
		_fx.flash(Color(0.55, 0.75, 1.0), 0.45)
		_fx.gold_pulse(2.0)
	if _player and is_instance_valid(_player):
		var b := Node2D.new()
		b.set_script(load("res://burst.gd"))
		b.color = Color(0.55, 0.75, 1.0, 1.0)
		b.max_scale = 14.0
		b.dur = 0.9
		b.light_energy = 3.0
		add_child(b)
		b.global_position = _player.global_position
		var sp := CPUParticles2D.new()
		sp.set_script(load("res://sparkle.gd"))
		sp.spark_color = Color(0.6, 0.8, 1.0)
		sp.spark_amount = 40
		sp.spark_speed = 320.0
		add_child(sp)
		sp.global_position = _player.global_position

	GameConfig.add_xp(300 + _level * 40)
	var was_last: bool = _level >= GameConfig.CAVES_LEVELS
	GameConfig.caves_max_unlocked = maxi(GameConfig.caves_max_unlocked, mini(_level + 1, GameConfig.CAVES_LEVELS))
	GameConfig.save_game()

	if was_last:
		_win_label.text = GameConfig.tt("ПЕЩЕРЫ ПРОЙДЕНЫ!\nВсе %d пещер позади.\nВремя: %.1f с\n\nEsc — в меню", "THE CAVES ARE DONE!\nAll %d caves behind you.\nTime: %.1f s\n\nEsc — to menu") % [GameConfig.CAVES_LEVELS, _elapsed]
		_win_label.visible = true
		return

	_win_label.text = GameConfig.tt("Пещера %d/%d пройдена!\nВыход найден.\nВремя: %.1f с", "Cave %d/%d cleared!\nExit found.\nTime: %.1f s") % [_level, GameConfig.CAVES_LEVELS, _elapsed]
	_win_label.visible = true
	_show_caves_next_buttons()

func _show_caves_next_buttons() -> void:
	var wrap := CenterContainer.new()
	wrap.set_anchors_preset(Control.PRESET_BOTTOM_WIDE)
	wrap.offset_top = -170
	wrap.offset_bottom = -40
	wrap.mouse_filter = Control.MOUSE_FILTER_PASS
	_hud_layer.add_child(wrap)
	var box := VBoxContainer.new()
	box.alignment = BoxContainer.ALIGNMENT_CENTER
	box.add_theme_constant_override("separation", 14)
	wrap.add_child(box)
	box.add_child(_make_overlay_button(GameConfig.tt("Следующая пещера →", "Next cave →"), func() -> void:
		GameConfig.caves_level = _level + 1
		get_tree().paused = false
		get_tree().reload_current_scene()))
	box.add_child(_make_overlay_button(GameConfig.t("pause_menu"), _goto_menu))

# --- Интерфейс ---

func _label_outline(l: Label, sz: int = 4) -> void:
	# Тонкая тёмная обводка — читаемость текста поверх ярких неоновых стен.
	l.add_theme_constant_override("outline_size", sz)
	l.add_theme_color_override("font_outline_color", Color(0, 0, 0, 0.75))

# Тултип полосы Воли (GAMEDESIGN.md §11/бэклог v1.10 «прозрачность механики
# Воли») — что её заряжает и что тратит, коротко и по-русски. Статичный текст:
# источники/траты Воли фиксированы кодом, не зависят от прогресса игрока.
func _will_tooltip_text() -> String:
	return GameConfig.tt(
		"Воля — топливо активных навыков (Q/Shift/E/C/G/F/T/Y/V/H/N).\nКопится: осколки, глоток на станции, завершение уровня.\nТьма её не трогает — тратится только на навыки.",
		"Will fuels your active skills (Q/Shift/E/C/G/F/T/Y/V/H/N).\nBuilds up: shards, a sip at a station, finishing a level.\nThe dark never touches it — only skills spend it.")

# Неоновая HUD-иконка (см. hud_icons.gd): создаём, ставим размер/позицию, цвет.
func _add_icon(parent: Node, kind: String, color: Color, pos: Vector2, sz: float) -> HudIcon:
	var ic := HudIcon.new()
	ic.kind = kind
	ic.col = color
	ic.size = Vector2(sz, sz)
	ic.custom_minimum_size = ic.size
	ic.position = pos
	ic.mouse_filter = Control.MOUSE_FILTER_IGNORE
	parent.add_child(ic)
	return ic

# Бейдж-клавиша (keycap): скруглённый прямоугольник с тонкой неоновой рамкой и
# буквой по центру. Это маленький значок, а НЕ панель интерфейса.
func _make_keycap(txt: String, accent: Color) -> Panel:
	var p := Panel.new()
	p.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var sb := StyleBoxFlat.new()
	sb.bg_color = Color(0.09, 0.12, 0.19, 0.72)
	sb.set_corner_radius_all(6)
	sb.set_border_width_all(1)
	sb.border_color = Color(accent.r, accent.g, accent.b, 0.6)
	p.add_theme_stylebox_override("panel", sb)
	var w := 26.0 if txt.length() == 1 else 20.0 + float(txt.length()) * 8.5
	p.custom_minimum_size = Vector2(w, 24)
	p.size = Vector2(w, 24)
	p.pivot_offset = p.size * 0.5
	var l := Label.new()
	l.text = txt
	l.add_theme_font_size_override("font_size", 13)
	l.add_theme_color_override("font_color", Color(0.86, 0.95, 1.0))
	l.set_anchors_preset(Control.PRESET_FULL_RECT)
	l.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	l.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	l.mouse_filter = Control.MOUSE_FILTER_IGNORE
	p.add_child(l)
	return p

# Мягкая подсветка позади keycap (для пульса готового «Озарения»).
func _make_cap_glow(cap: Panel, accent: Color) -> Panel:
	var g := Panel.new()
	g.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var sb := StyleBoxFlat.new()
	sb.bg_color = Color(accent.r, accent.g, accent.b, 1.0)
	sb.set_corner_radius_all(10)
	g.add_theme_stylebox_override("panel", sb)
	g.custom_minimum_size = cap.size + Vector2(10, 10)
	g.size = cap.size + Vector2(10, 10)
	var m := g.modulate
	m.a = 0.0
	g.modulate = m
	return g

# Строка навыка: [keycap клавиши] [название]. Позиционируем абсолютно (как раньше),
# чтобы левый угол остался свободным макетом без панели.
# Иконка навыка в HUD: пиктограмма (как в меню навыков) + кольцо перезарядки
# вокруг неё (как шкала станции) + клавиша снизу.
func _make_skill_chip(parent: Control, d: Dictionary) -> void:
	var accent: Color = SkillIcons.color_of(d["id"])
	var icon := SkillHudIcon.new()
	icon.icon_tex = SkillIcons.make(d["id"], 28)
	icon.accent = accent
	parent.add_child(icon)
	icon.set_key(d["key"])

	_skills_ui[d["id"]] = {
		"icon": icon, "base": d["name"], "accent": accent, "ready": true,
	}

# Раскладывает ВИДИМЫЕ иконки навыков в ряд слева направо без пропусков.
func _layout_skills() -> void:
	var x := 14.0
	for d in SKILL_DEFS:
		var ui = _skills_ui.get(d["id"])
		if ui == null:
			continue
		var icon: SkillHudIcon = ui["icon"]
		if not icon.visible:
			continue
		icon.position = Vector2(x, 0)
		x += 38.0

# Обновление иконок навыков: видимость по разблокировке + состояние (готов/кд/мало света).
func _update_skills_hud() -> void:
	for d in SKILL_DEFS:
		var ui = _skills_ui.get(d["id"])
		if ui == null:
			continue
		var unlocked: bool = GameConfig.skills_unlocked.get(d["id"], false)
		ui["icon"].visible = unlocked
		if not unlocked:
			continue
		var m: float = _player._skill_cd_mult
		match d["id"]:
			"flash":  _update_skill("flash",  _player.flash_cd,  _player.will, _player.FLASH_COST,  _player.FLASH_COOLDOWN * m)
			"dash":   _update_skill("dash",   _player.dash_cd,   _player.will, _player.DASH_COST,   _player.DASH_COOLDOWN * m)
			"smother": _update_skill("smother", _player.smother_cd, _player.will, _player.SMOTHER_COST, _player.SMOTHER_COOLDOWN * m)
			"mirage":  _update_skill("mirage",  _player.mirage_cd,  _player.will, _player.MIRAGE_COST,  _player.MIRAGE_COOLDOWN * m)
			"breach":  _update_skill("breach",  _player.breach_cd,  _player.will, _player.BREACH_COST,  _player.BREACH_COOLDOWN * m)
			"chrono":  _update_skill("chrono",  _player.chrono_cd,  _player.will, _player.CHRONO_COST,  _player.CHRONO_COOLDOWN * m)
			"sonar":  _update_skill("sonar",  _player.sonar_cd,  _player.will, _player.SONAR_COST,  _player.SONAR_COOLDOWN * m)
			"shield": _update_skill("shield", _player.shield_cd, _player.will, _player.SHIELD_COST, _player.SHIELD_COOLDOWN * m)
			"guide":  _update_skill("guide",  _player.guide_cd,  _player.will, _player.GUIDE_COST,  _player.GUIDE_COOLDOWN * m)
			"reveal": _update_reveal(_player.reveal_charge)
			"pulse":  _update_skill("pulse",  _player.pulse_cd,  _player.will, _player.PULSE_COST,  _player.PULSE_COOLDOWN * m)
			"mark":   _update_skill("mark",   _player.mark_cd,   _player.energy, _player.MARK_COST,   _player.MARK_COOLDOWN * m)
			"apex":   _update_skill("apex",   _player.apex_cd,   _player.will, _player.APEX_COST,   _player.APEX_COOLDOWN * m)
	_layout_skills()

func _build_screen_fx() -> void:
	_fx = CanvasLayer.new()
	_fx.set_script(load("res://screenfx.gd"))
	add_child(_fx)

# [§45] Луч видимости: направление берём у игрока (_facing — то же, что у
# фонаря-конуса), дальность и ширину — у стойки света. Значения сглаживаются:
# резкий скачок при развороте читается как рывок камеры и укачивает.
var _beam_dir: Vector2 = Vector2.RIGHT
var _beam_reach: float = 0.0
var _beam_focus: float = 0.5

func _update_beam(delta: float) -> void:
	if _dark_mat == null:
		return
	var reach_t := 0.0
	var focus_t := 0.5
	if _player and is_instance_valid(_player) and _player.active:
		var st: int = clampi(int(_player.light_stance), 0, BEAM_BY_STANCE.size() - 1)
		var pair: Array = BEAM_BY_STANCE[st]
		reach_t = float(pair[0])
		focus_t = float(pair[1])
		# Тление гасит не только яркость, но и дальнобойность: крадёшься —
		# видишь только под ногами. Иначе Тление было бы бесплатной разведкой.
		if _player.has_method("is_smothering") and _player.is_smothering():
			reach_t = BEAM_SMOTHER
		# Озарение и Сонар раскрывают обзор кругом — на это время луч не нужен,
		# иначе «увидеть всё вокруг» превращалось бы в «увидеть всё впереди».
		if _reveal_time > 0.0 or _sonar_vision_time > 0.0:
			reach_t *= 0.35
		var f: Vector2 = _player.get("_facing")
		if f != null and f.length() > 0.01:
			_beam_dir = _beam_dir.slerp(f.normalized(), clampf(delta * 9.0, 0.0, 1.0))
	_beam_reach = lerpf(_beam_reach, reach_t, clampf(delta * 4.0, 0.0, 1.0))
	_beam_focus = lerpf(_beam_focus, focus_t, clampf(delta * 4.0, 0.0, 1.0))
	_dark_mat.set_shader_parameter("beam_dir", _beam_dir)
	_dark_mat.set_shader_parameter("beam_reach", _beam_reach)
	_dark_mat.set_shader_parameter("beam_focus", _beam_focus)

func _update_darkness_aspect() -> void:
	if _dark_mat:
		var s := get_viewport().get_visible_rect().size
		_dark_mat.set_shader_parameter("aspect", (s.x / s.y) if s.y > 0.0 else 1.777)

# Короткая полноэкранная засветка (навыки, переход между этажами).
func flash_screen(col: Color, strength: float) -> void:
	if _fx:
		_fx.flash(col, strength)

func _build_touch_controls() -> void:
	var layer := CanvasLayer.new()
	layer.layer = 2
	add_child(layer)

	# Виртуальный джойстик (реагирует на левую половину экрана)
	_joystick = Control.new()
	_joystick.set_script(load("res://touch_joystick.gd"))
	_joystick.process_mode = Node.PROCESS_MODE_PAUSABLE
	layer.add_child(_joystick)

	var vw: float = get_viewport().get_visible_rect().size.x
	var vh: float = get_viewport().get_visible_rect().size.y

	# Кнопки навыков (справа снизу): Вспышка/Рывок/Сонар/Щит/Искра/Озарение
	var grid := GridContainer.new()
	grid.columns = 3
	grid.add_theme_constant_override("h_separation", 10)
	grid.add_theme_constant_override("v_separation", 10)
	grid.position = Vector2(vw - 350, vh - 190)
	grid.process_mode = Node.PROCESS_MODE_PAUSABLE
	layer.add_child(grid)

	grid.add_child(_make_touch_button(GameConfig.tt("Вспышка", "Flash"), func(): _skill(0)))
	grid.add_child(_make_touch_button(GameConfig.tt("Рывок", "Dash"), func(): _skill(1)))
	grid.add_child(_make_touch_button(GameConfig.tt("Сонар", "Sonar"), func(): _skill(2)))
	grid.add_child(_make_touch_button(GameConfig.tt("Щит", "Shield"), func(): _skill(3)))
	grid.add_child(_make_touch_button(GameConfig.tt("Искра", "Guide"), func(): _skill(4)))
	grid.add_child(_make_touch_button(GameConfig.tt("Озарение", "Reveal"), func(): _skill(5)))

	# Кнопка паузы (вверху по центру)
	var pause_btn := _make_touch_button("II", _toggle_pause)
	pause_btn.custom_minimum_size = Vector2(70, 44)
	pause_btn.position = Vector2(vw * 0.5 - 35, 6)
	pause_btn.process_mode = Node.PROCESS_MODE_PAUSABLE
	layer.add_child(pause_btn)

func _make_touch_button(text: String, on_pressed: Callable) -> Button:
	var b := Button.new()
	b.text = text
	b.custom_minimum_size = Vector2(108, 56)
	b.focus_mode = Control.FOCUS_NONE
	b.add_theme_font_size_override("font_size", 17)
	b.modulate = Color(1, 1, 1, 0.85)
	b.pressed.connect(on_pressed)
	return b

func _skill(which: int) -> void:
	if not (_player and is_instance_valid(_player)):
		return
	match which:
		0: _player._try_flash()
		1: _player._try_dash()
		2: _player._try_sonar()
		3: _player._try_shield()
		4: _player._try_guide()
		5: _player._try_reveal()

# Музыка — два процедурных слоя (сгенерированы синтезом, см. коммит):
#  • ambient_dark.wav — тёмный ре-минорный дрон, бесшовный луп, играет всегда;
#  • chase_pulse.wav  — «сердце погони» (пульс + тревожное тремоло), громкость
#    подводится в _process: враг гонится → слой вплывает, отстал → тает.
# Старый 8-bit-луп оставлен в sounds/, но больше не используется.
func _start_music() -> void:
	var stream := _load_audio("res://sounds/ambient_dark.wav", true)
	if stream == null:
		stream = _load_audio("res://sounds/8-bit-music-1.mp3", true)   # запасной вариант
	if stream == null:
		return
	_music = AudioStreamPlayer.new()
	_music.stream = stream
	_music.volume_db = -8.0
	_music.bus = "Music"
	_music.process_mode = Node.PROCESS_MODE_ALWAYS   # играет и на паузе
	add_child(_music)
	_music.play()

	var chase := _load_audio("res://sounds/chase_pulse.wav", true)
	if chase != null:
		_music_chase = AudioStreamPlayer.new()
		_music_chase.stream = chase
		_music_chase.bus = "Music"
		_music_chase.volume_db = -60.0   # тишина; поднимет _update_music
		_music_chase.process_mode = Node.PROCESS_MODE_PAUSABLE   # на паузе сердце молчит
		add_child(_music_chase)
		_music_chase.play()

# Реактивный слой: цель громкости — по факту погони (+ жар Накала чуть
# приподнимает базу: чем ярче горишь, тем беспокойнее музыка).
func _update_music(delta: float) -> void:
	if _music_chase == null or not is_instance_valid(_music_chase):
		return
	var chasing: bool = has_active_chaser()
	var target: float = -10.0 if chasing else (-60.0 + enemy_heat() * 20.0)
	_music_chase.volume_db = move_toward(_music_chase.volume_db, target, delta * (30.0 if chasing else 10.0))

	# Тихий ориентир без чисел на экране: чем ближе игрок к выходу, тем чуть
	# светлее (выше) тон дрона эмбиента. Разница едва заметна сознательно, но
	# даёт телу подсказку «теплее/холоднее» даже в кромешной тьме.
	if _music != null and is_instance_valid(_music) and is_instance_valid(_player):
		var exit_pos := _cell_to_world(_exit_cell) + Vector2(0, _exit_floor * _floor_gap)
		var d := _player.position.distance_to(exit_pos)
		var closeness := clampf(1.0 - d / _start_exit_dist, 0.0, 1.0)
		var pitch_target := 1.0 + closeness * 0.035
		_music.pitch_scale = move_toward(_music.pitch_scale, pitch_target, delta * 0.15)

# Навык «Пульс» (B): пока активен player.pulse_time, раз в ~1.8с пересчитываем
# BFS-путь по коридору до выхода (тот же, что у «Искры») и играем «пик» — тем
# чаще и звонче, чем короче оставшийся путь. Редкий пересчёт вместо покадрового
# — сигнал ведёт по маршруту, но с инерцией, а не как точный компас.
func _update_pulse(delta: float) -> void:
	if not is_instance_valid(_player):
		return
	var active: bool = _player.pulse_time > 0.0
	if active and not _pulse_was_active:
		var path0: PackedVector2Array = pulse_path(_player.position, _player.current_floor)
		_pulse_steps_base = maxf(1.0, float(path0.size()))
		_pulse_steps = _pulse_steps_base
		_pulse_recalc_timer = 0.0
		_pulse_ping_timer = 0.0
	_pulse_was_active = active
	if not active:
		return

	_pulse_recalc_timer -= delta
	if _pulse_recalc_timer <= 0.0:
		_pulse_recalc_timer = 1.8
		var path: PackedVector2Array = pulse_path(_player.position, _player.current_floor)
		if path.size() >= 2:
			_pulse_steps = float(path.size())

	var closeness := clampf(1.0 - _pulse_steps / _pulse_steps_base, 0.0, 1.0)
	var interval := lerpf(1.6, 0.28, closeness)
	_pulse_ping_timer -= delta
	if _pulse_ping_timer <= 0.0:
		_pulse_ping_timer = interval
		play_sfx(_sfx_beep, -8.0 + closeness * 8.0)

func _load_sfx() -> void:
	# Эффекты лежат в sounds/. Если файл ещё не импортирован — будет null,
	# play_sfx это переживёт (просто без звука), как и музыка.
	_sfx_shard = _load_audio("res://sounds/shrapnel.mp3")
	_sfx_key   = _load_audio("res://sounds/key.mp3")
	_sfx_win   = _load_audio("res://sounds/win.mp3")
	_sfx_beep  = _load_audio("res://sounds/beep.mp3")
	_sfx_damage  = _load_audio("res://sounds/damage_hit.wav")   # механический удар/лязг, не голосовое "ай" (v1.9)
	_sfx_sonar   = _load_audio("res://sounds/sonar.mp3")
	_sfx_sparkle = _load_audio("res://sounds/sparkle.mp3")
	# Процедурные звуки навыков (sk_*.wav — синтез, см. коммит)
	_sfx_flash   = _load_audio("res://sounds/sk_flash.wav")
	_sfx_dash    = _load_audio("res://sounds/sk_dash.wav")
	_sfx_shield  = _load_audio("res://sounds/sk_shield.wav")
	_sfx_smother = _load_audio("res://sounds/sk_smother.wav")
	_sfx_reveal  = _load_audio("res://sounds/sk_reveal.wav")
	_sfx_apex    = _load_audio("res://sounds/sk_apex.wav")

# Звук глотка энергии с кристалла (вызывается из station.gd).
func beep() -> void:
	play_sfx(_sfx_beep)

# Звук активного навыка (вызывается из player.gd при успешном применении).
func play_skill_sfx(which: String) -> void:
	match which:
		"sonar":
			play_sfx(_sfx_sonar)
			if _boss and is_instance_valid(_boss) and _boss.has_method("reveal_weak_point"):
				_boss.reveal_weak_point()
		"guide":   play_sfx(_sfx_sparkle)
		"flash":   play_sfx(_sfx_flash)
		"dash":    play_sfx(_sfx_dash, -4.0)
		"shield":  play_sfx(_sfx_shield)
		"smother": play_sfx(_sfx_smother, -3.0)
		"reveal":  play_sfx(_sfx_reveal)
		"apex":    play_sfx(_sfx_apex, 2.0)
		"pulse":   play_sfx(_sfx_sparkle, -2.0)   # активация — сам «пик» звонче, см. _update_pulse

# Отклик на удар врага: красный всплеск по углам + короткая красная засветка.
func enemy_hit_fx() -> void:
	play_sfx(_sfx_damage)                            # звук удара врага
	if _fx:
		_fx.danger_pulse(1.1)                       # красные углы — основной отклик
		_fx.flash(Color(1.0, 0.2, 0.15), 0.12)      # лёгкая красная засветка для удара
	# [GAMEDESIGN §32] Урон рвёт серию — и об этом надо СКАЗАТЬ: молча
	# исчезнувший множитель игрок не связывает с полученным ударом.
	if _clean_shard_streak >= 3:
		_show_reward(Vector2.INF, GameConfig.tt("серия ×%d прервана", "streak x%d broken") % _clean_shard_streak,
			Color(1.0, 0.45, 0.4), 15)
	_clean_shard_streak = 0                          # урон рвёт «чистую» серию (Резонанс)
	_update_shards()
	_level_clean_hit()

# ЗАМОРОЗКА-ПЕРЕДЫШКА (п.10.5): два удара за короткое время — все враги
# застывают на 5 сек. Не награда за ошибку, а пауза для выдоха под давлением;
# контраст внезапной тишины — главная ценность. Раз за уровень.
func _level_clean_hit() -> void:
	var now := _elapsed
	if not _mercy_done and not GameConfig.tutorial_mode and now - _last_hit_time < 6.0:
		_mercy_done = true
		for e in get_tree().get_nodes_in_group("enemy"):
			if is_instance_valid(e) and "stun_time" in e:
				e.stun_time = maxf(e.stun_time, 5.0)
		flash_message(GameConfig.tt("❄ Тишина…", "❄ Silence…"))
	_last_hit_time = now

func _load_audio(path: String, looped: bool = false) -> AudioStream:
	var stream = load(path)
	if stream == null:
		return null
	if stream is AudioStreamMP3:
		stream.loop = looped   # музыку зацикливаем, эффекты — нет
	elif stream is AudioStreamWAV and looped:
		stream.loop_mode = AudioStreamWAV.LOOP_FORWARD
		stream.loop_begin = 0
		# 16 бит × 2 канала = 4 байта на кадр
		stream.loop_end = stream.data.size() / 4
	return stream

func play_sfx(stream: AudioStream, volume_db: float = 0.0) -> void:
	# Разовый плеер: создаём, играем, сам себя удаляет по окончании.
	# Так звуки не обрывают друг друга и могут накладываться.
	if stream == null:
		return
	var p := AudioStreamPlayer.new()
	p.stream = stream
	p.volume_db = volume_db
	p.bus = "SFX"   # громкость эффектов — ползунок в настройках
	p.process_mode = Node.PROCESS_MODE_ALWAYS   # звучит и во время паузы
	add_child(p)
	p.finished.connect(p.queue_free)
	p.play()

func _build_hud() -> void:
	# Слой тинта (под HUD, над миром)
	var fx := CanvasLayer.new()
	fx.layer = 1
	add_child(fx)

	_tint = ColorRect.new()
	_tint.set_anchors_preset(Control.PRESET_FULL_RECT)
	_tint.color = Color(0, 0, 0, 0)
	_tint.mouse_filter = Control.MOUSE_FILTER_IGNORE
	fx.add_child(_tint)

	# Виньетка темноты («туман войны») — шар видимости вокруг игрока (камера держит
	# его в центре экрана). Приоткрывается во время Озарения; max_dark<1 пропускает
	# яркий свет (сонар, выход), гася лишь тусклый ambient далёкого лабиринта.
	var dark_rect := ColorRect.new()
	dark_rect.set_anchors_preset(Control.PRESET_FULL_RECT)
	dark_rect.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_dark_mat = ShaderMaterial.new()
	_dark_mat.shader = load("res://darkness.gdshader")
	_dark_mat.set_shader_parameter("inner", DARK_INNER)
	_dark_mat.set_shader_parameter("outer", DARK_OUTER)
	_dark_mat.set_shader_parameter("max_dark", DARK_MAX)
	dark_rect.material = _dark_mat
	fx.add_child(dark_rect)
	_update_darkness_aspect()
	get_viewport().size_changed.connect(_update_darkness_aspect)

	var layer := CanvasLayer.new()
	layer.layer = 2
	add_child(layer)
	_hud_layer = layer

	var vpw: float = get_viewport().get_visible_rect().size.x

	# === Верхняя HUD-панель: всё в одной полосе сверху, лабиринт всегда ниже неё ===
	# Полупрозрачный фон полосы (мазе слегка просвечивает, но текст читаем).
	var band := ColorRect.new()
	band.set_anchors_preset(Control.PRESET_TOP_WIDE)
	band.offset_bottom = HUD_BAND
	band.color = Color(0.02, 0.03, 0.06, 0.62)
	band.mouse_filter = Control.MOUSE_FILTER_IGNORE
	layer.add_child(band)
	# Тонкая неоновая линия-подчёркивание снизу панели
	var band_line := ColorRect.new()
	band_line.set_anchors_preset(Control.PRESET_TOP_WIDE)
	band_line.offset_top = HUD_BAND - 2.0
	band_line.offset_bottom = HUD_BAND
	band_line.color = Color(0.3, 0.55, 0.9, 0.35)
	band_line.mouse_filter = Control.MOUSE_FILTER_IGNORE
	layer.add_child(band_line)

	# Тонкий XP-бар по самому верхнему краю
	_xp_bar = ProgressBar.new()
	_xp_bar.min_value = 0
	_xp_bar.max_value = GameConfig.XP_PER_SP
	_xp_bar.show_percentage = false
	_xp_bar.position = Vector2(0, 0)
	_xp_bar.custom_minimum_size = Vector2(vpw, 4)
	_xp_bar.size = Vector2(vpw, 4)
	var xb := StyleBoxFlat.new(); xb.bg_color = Color(0.06, 0.06, 0.12, 0.6)
	_xp_bar.add_theme_stylebox_override("background", xb)
	var xf := StyleBoxFlat.new(); xf.bg_color = Color(0.6, 0.45, 1.0)
	_xp_bar.add_theme_stylebox_override("fill", xf)
	layer.add_child(_xp_bar)

	# --- Строка 1 (слева): уровень · биом · этаж (SP добавляется в _update_hud) ---
	_level_label = Label.new()
	_level_label.text = GameConfig.tt("Уровень %d   ·   этаж 1 / %d", "Level %d   ·   floor 1 / %d") % [_level, _floors]
	_level_label.position = Vector2(14, 7)
	_level_label.add_theme_font_size_override("font_size", 17)
	_level_label.add_theme_color_override("font_color", Color(0.86, 0.93, 1.0))
	_label_outline(_level_label)
	layer.add_child(_level_label)

	# Индикатор Накала (только в забеге) — по центру панели
	if GameConfig.active_run >= 0:
		_ember_label = Label.new()
		_ember_label.position = Vector2(vpw * 0.5 - 180, 7)
		_ember_label.custom_minimum_size = Vector2(360, 0)
		_ember_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		_ember_label.add_theme_font_size_override("font_size", 17)
		_ember_label.add_theme_color_override("font_color", Color(1.0, 0.72, 0.3))
		_label_outline(_ember_label)
		layer.add_child(_ember_label)

	# --- Навыки: ряд маленьких пиктограмм слева (строка 2) ---
	_skill_bar = Control.new()
	_skill_bar.position = Vector2(0, 30)
	_skill_bar.mouse_filter = Control.MOUSE_FILTER_IGNORE
	layer.add_child(_skill_bar)
	for d in SKILL_DEFS:
		_make_skill_chip(_skill_bar, d)
	_layout_skills()

	# --- Строка 2 справа от навыков: время · свет · пассивки ---
	var sx := 250.0
	_add_icon(layer, "clock", Color(0.6, 0.85, 1.0), Vector2(sx, 38), 17)
	_time_label = Label.new()
	_time_label.text = GameConfig.tt("0.0 с", "0.0 s")
	_time_label.position = Vector2(sx + 22, 36)
	_time_label.add_theme_font_size_override("font_size", 15)
	_time_label.add_theme_color_override("font_color", Color(0.82, 0.9, 1.0))
	_label_outline(_time_label)
	layer.add_child(_time_label)

	var bar_label := Label.new()
	bar_label.text = GameConfig.tt("Свет", "Light")
	bar_label.position = Vector2(sx + 100, 38)
	bar_label.add_theme_font_size_override("font_size", 13)
	bar_label.add_theme_color_override("font_color", Color(0.85, 0.9, 1.0))
	_label_outline(bar_label, 3)
	bar_label.mouse_filter = Control.MOUSE_FILTER_STOP
	bar_label.tooltip_text = GameConfig.tt(
		"Свет — твоя жизнь. Тает от движения во тьме и ударов врагов, гаснет совсем — минус жизнь.\nВосполняется у станций/осколков; рядом со станцией не тает вовсе.",
		"Light is your life. Drains as you move in the dark and from enemy hits — fully out costs a life.\nRefills at stations/shards; doesn't drain at all right next to a station.")
	layer.add_child(bar_label)

	_energy_bar = ProgressBar.new()
	_energy_bar.min_value = 0.0
	_energy_bar.max_value = 1.0
	_energy_bar.step = 0.001
	_energy_bar.show_percentage = false
	_energy_bar.value = 1.0
	_energy_bar.position = Vector2(sx + 142, 39)
	_energy_bar.custom_minimum_size = Vector2(140, 12)
	_energy_bar.tooltip_text = bar_label.tooltip_text
	var bg := StyleBoxFlat.new()
	bg.bg_color = Color(0.08, 0.09, 0.13, 0.7)
	bg.set_corner_radius_all(6)
	bg.set_border_width_all(1)
	bg.border_color = Color(0.4, 0.55, 0.8, 0.35)
	_energy_bar.add_theme_stylebox_override("background", bg)
	_energy_fill = StyleBoxFlat.new()
	_energy_fill.bg_color = Color(1.0, 0.85, 0.3)
	_energy_fill.set_corner_radius_all(6)
	_energy_bar.add_theme_stylebox_override("fill", _energy_fill)
	layer.add_child(_energy_bar)

	# --- Воля: тонкая циан-бирюзовая полоса под полосой Света (ресурс навыков) ---
	# Была фиолетовой — сменена на циан, чтобы не конфликтовать с тёмно-фиолетовым
	# ореолом заряженных врагов у тёмных станций (см. dark_station.gd, GAMEDESIGN.md §22).
	var will_label := Label.new()
	will_label.text = GameConfig.tt("Воля", "Will")
	will_label.position = Vector2(sx + 100, 53)
	will_label.add_theme_font_size_override("font_size", 11)
	will_label.add_theme_color_override("font_color", Color(0.65, 0.95, 0.95))
	_label_outline(will_label, 3)
	will_label.mouse_filter = Control.MOUSE_FILTER_STOP
	will_label.tooltip_text = _will_tooltip_text()
	layer.add_child(will_label)

	_will_bar = ProgressBar.new()
	_will_bar.min_value = 0.0
	_will_bar.max_value = 1.0
	_will_bar.step = 0.001
	_will_bar.show_percentage = false
	_will_bar.value = 1.0
	_will_bar.position = Vector2(sx + 142, 56)
	_will_bar.custom_minimum_size = Vector2(140, 7)
	_will_bar.tooltip_text = will_label.tooltip_text
	var wbg := StyleBoxFlat.new()
	wbg.bg_color = Color(0.06, 0.11, 0.13, 0.7)
	wbg.set_corner_radius_all(4)
	wbg.set_border_width_all(1)
	wbg.border_color = Color(0.35, 0.75, 0.8, 0.35)
	_will_bar.add_theme_stylebox_override("background", wbg)
	_will_fill = StyleBoxFlat.new()
	_will_fill.bg_color = Color(0.3, 0.9, 0.95)
	_will_fill.set_corner_radius_all(4)
	_will_bar.add_theme_stylebox_override("fill", _will_fill)
	layer.add_child(_will_bar)

	# [GAMEDESIGN §29] Стойка света — три сегмента (Тусклый/Ровный/Яркий) плюс
	# подпись с текущим расходом. Стоит вплотную к полосам Света/Воли, потому
	# что управляет именно ими; пассивки за ней сдвинуты правее.
	_stance_row = Control.new()
	_stance_row.position = Vector2(sx + 300, 36)
	_stance_row.tooltip_text = GameConfig.tt(
		"Стойка света (Z / X или колесо мыши).\nЯркий — видишь дальше, но горишь быстрее и тебя видно издалека.\nТусклый — экономишь Свет и прячешься, но идёшь вслепую и медленнее.",
		"Light stance (Z / X or mouse wheel).\nBright — see farther, but burn faster and be seen from afar.\nDim — save Light and hide, but walk near-blind and slower.")
	layer.add_child(_stance_row)
	for i in 3:
		var seg := ColorRect.new()
		seg.position = Vector2(i * 14, 3)
		seg.size = Vector2(11, 11)
		seg.mouse_filter = Control.MOUSE_FILTER_IGNORE
		_stance_segs.append(seg)
		_stance_row.add_child(seg)
	_stance_label = Label.new()
	_stance_label.position = Vector2(48, 0)
	_stance_label.add_theme_font_size_override("font_size", 12)
	_label_outline(_stance_label, 3)
	_stance_row.add_child(_stance_label)

	# Пассивки — компактно справа от полосы света
	_boost_row = Control.new()
	_boost_row.position = Vector2(sx + 455, 36)
	_boost_row.mouse_filter = Control.MOUSE_FILTER_IGNORE
	layer.add_child(_boost_row)
	_add_icon(_boost_row, "boost", Color(0.5, 0.95, 0.6), Vector2(0, 0), 16)
	_boost_label = Label.new()
	_boost_label.position = Vector2(19, 0)
	_boost_label.add_theme_font_size_override("font_size", 12)
	_boost_label.add_theme_color_override("font_color", Color(0.6, 0.95, 0.7))
	_label_outline(_boost_label, 3)
	_boost_row.add_child(_boost_label)

	_adapt_row = Control.new()
	_adapt_row.position = Vector2(sx + 575, 36)
	_adapt_row.mouse_filter = Control.MOUSE_FILTER_IGNORE
	layer.add_child(_adapt_row)
	_add_icon(_adapt_row, "adapt", Color(0.5, 0.95, 0.6), Vector2(0, 0), 16)
	_adapt_label = Label.new()
	_adapt_label.position = Vector2(19, 0)
	_adapt_label.add_theme_font_size_override("font_size", 12)
	_adapt_label.add_theme_color_override("font_color", Color(0.6, 0.95, 0.7))
	_label_outline(_adapt_label, 3)
	_adapt_row.add_child(_adapt_label)

	# --- Правый край панели: жизни / осколки / ключи (компактно по вертикали) ---
	var right_x: float = vpw - 190.0
	_lives_icon = _add_icon(layer, "heart", Color(1.0, 0.5, 0.55), Vector2(right_x, 6), 18)
	_lives_label = Label.new()
	_lives_label.position = Vector2(right_x + 26, 4)
	_lives_label.add_theme_font_size_override("font_size", 17)
	_lives_label.add_theme_color_override("font_color", Color(1.0, 0.6, 0.6))
	_label_outline(_lives_label)
	layer.add_child(_lives_label)
	_update_lives()

	_shards_icon = _add_icon(layer, "shard", Color(1.0, 0.82, 0.4), Vector2(right_x, 30), 18)
	_shards_label = Label.new()
	_shards_label.position = Vector2(right_x + 26, 28)
	_shards_label.add_theme_font_size_override("font_size", 16)
	_shards_label.add_theme_color_override("font_color", Color(1.0, 0.92, 0.5))
	_label_outline(_shards_label)
	layer.add_child(_shards_label)

	# Серия: правее счётчика осколков, чтобы читаться одним движением глаз
	# вместе с «Осколки: 2 / 5», а не искаться по экрану.
	# [SAFETY 2026-07-29] Тест-флаг боссов работал МОЛЧА: он заменяет ареной
	# каждый уровень кампании, но на экране об этом ничего не говорило. Игрок
	# дважды приходил с вопросами — «уровень 49 чёрный» (§28) и «а где сами
	# лабиринты?». Пока флаг включён, он обязан быть виден.
	if GameConfig.boss_test_enabled:
		var warn := Label.new()
		warn.text = GameConfig.tt("⚔ ТЕСТ БОССОВ: все уровни — арены", "⚔ BOSS TEST: every level is an arena")
		warn.position = Vector2(sx + 22, 58)
		warn.add_theme_font_size_override("font_size", 13)
		warn.add_theme_color_override("font_color", Color(1.0, 0.62, 0.2))
		warn.mouse_filter = Control.MOUSE_FILTER_STOP
		warn.tooltip_text = GameConfig.tt(
			"Выключается в Настройках → Тестирование. Обычные лабиринты вернутся сразу.",
			"Turn it off in Settings → Testing. Normal mazes come back immediately.")
		_label_outline(warn, 3)
		layer.add_child(warn)

	_streak_label = Label.new()
	_streak_label.position = Vector2(right_x + 150, 28)
	_streak_label.add_theme_font_size_override("font_size", 15)
	_streak_label.pivot_offset = Vector2(30, 10)
	_streak_label.visible = false
	_streak_label.mouse_filter = Control.MOUSE_FILTER_STOP
	_streak_label.tooltip_text = GameConfig.tt(
		"Серия осколков без урона: каждый следующий осколок дороже (до ×2.5).\nЛюбой удар врага серию обрывает.",
		"Shard streak without damage: each next shard is worth more (up to x2.5).\nAny enemy hit breaks it.")
	_label_outline(_streak_label)
	layer.add_child(_streak_label)

	_keys_icon = _add_icon(layer, "key", Color(0.55, 0.85, 1.0), Vector2(right_x, 54), 18)
	_keys_label = Label.new()
	_keys_label.position = Vector2(right_x + 26, 52)
	_keys_label.add_theme_font_size_override("font_size", 16)
	_keys_label.add_theme_color_override("font_color", Color(0.7, 0.85, 1.0))
	_label_outline(_keys_label)
	layer.add_child(_keys_label)

	# [§39] Строка последней улики. Живёт под полосой HUD (HUD_BAND), чтобы не
	# лезть на шкалы, и появляется только когда улика есть: пустая строка на
	# экране читалась бы как «что-то сломалось».
	_clue_label = Label.new()
	_clue_label.position = Vector2(right_x - 250, HUD_BAND + 4)
	_clue_label.custom_minimum_size.x = 480
	_clue_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	_clue_label.add_theme_font_size_override("font_size", 15)
	_clue_label.add_theme_color_override("font_color", Color(1.0, 0.82, 0.45))
	_label_outline(_clue_label)
	_clue_label.visible = false
	layer.add_child(_clue_label)
	_update_shards()

	# --- Подсказка по паузе — мелко в нижнем-правом углу ---
	var hint := Label.new()
	hint.text = GameConfig.tt("P / Esc — пауза", "P / Esc — pause")
	hint.set_anchors_preset(Control.PRESET_BOTTOM_RIGHT)
	hint.offset_left = -150
	hint.offset_right = -12
	hint.offset_top = -26
	hint.offset_bottom = -8
	hint.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	hint.add_theme_font_size_override("font_size", 13)
	hint.add_theme_color_override("font_color", Color(0.5, 0.53, 0.6))
	_label_outline(hint, 3)
	hint.mouse_filter = Control.MOUSE_FILTER_IGNORE
	layer.add_child(hint)

	# --- Счётчик FPS (внизу слева, только если включён в настройках) ---
	if GameConfig.show_fps:
		_fps_label = Label.new()
		_fps_label.set_anchors_preset(Control.PRESET_BOTTOM_LEFT)
		_fps_label.offset_left = 16
		_fps_label.offset_right = 200
		_fps_label.offset_top = -30
		_fps_label.offset_bottom = -6
		_fps_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
		_fps_label.text = "FPS: 0"
		_fps_label.add_theme_font_size_override("font_size", 16)
		_fps_label.add_theme_color_override("font_color", Color(0.6, 0.95, 0.7))
		_label_outline(_fps_label, 3)
		_fps_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
		layer.add_child(_fps_label)

	# Сообщение (тост) — вверху по центру, под строкой события. Тёмная плашка
	# с рамкой + крестик-закрытие, а не голый жёлтый текст без фона (жалоба
	# «не просто жёлтое сообщение, а нормальное всплывающее, которое висит и
	# его можно выключить или просто смотреть»): держится дольше (см.
	# flash_message — время зависит от длины текста) и закрывается вручную.
	_top_stack = VBoxContainer.new()
	_top_stack.set_anchors_preset(Control.PRESET_TOP_WIDE)
	_top_stack.position = Vector2(0, HUD_BAND + 10.0)
	_top_stack.add_theme_constant_override("separation", 8)
	_top_stack.mouse_filter = Control.MOUSE_FILTER_IGNORE
	layer.add_child(_top_stack)

	_toast_panel = PanelContainer.new()
	_toast_panel.visible = false
	_toast_panel.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	_toast_panel.mouse_filter = Control.MOUSE_FILTER_STOP
	# Полупрозрачный фон — тост может встать над игроком (камера его центрирует),
	# сплошная плашка закрывала бы персонажа на всё время показа сообщения.
	var _toast_sb := UIStyle.panel_stylebox(Color(1.0, 0.82, 0.45, 0.6))
	_toast_sb.bg_color.a = 0.55
	_toast_panel.add_theme_stylebox_override("panel", _toast_sb)
	_top_stack.add_child(_toast_panel)

	var toast_row := HBoxContainer.new()
	toast_row.add_theme_constant_override("separation", 14)
	_toast_panel.add_child(toast_row)

	_toast_label = Label.new()
	_toast_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_toast_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_toast_label.custom_minimum_size = Vector2(560, 0)
	_toast_label.add_theme_font_size_override("font_size", 22)
	_toast_label.add_theme_color_override("font_color", Color(1.0, 0.82, 0.45))
	toast_row.add_child(_toast_label)

	var toast_close := Button.new()
	toast_close.text = "×"
	toast_close.focus_mode = Control.FOCUS_NONE
	toast_close.custom_minimum_size = Vector2(30, 30)
	toast_close.add_theme_font_size_override("font_size", 18)
	UIStyle.style_button(toast_close)
	toast_close.pressed.connect(func() -> void:
		_toast_time = 0.0
		_toast_panel.visible = false)
	toast_row.add_child(toast_close)

	# Сообщение о событии (вверху по центру) — тоже плашка с фоном, не голый
	# обведённый текст (тот же приём, что у тоста/эпизодов победы ниже).
	_event_label = _build_message_panel(layer, Control.PRESET_TOP_WIDE, Vector2(0, 24), 22,
		Color(0.6, 0.6, 0.72, 0.55))

	# Сообщение о смерти — раньше голый красный текст на весь экран без фона,
	# который то ли всплыл, то ли нет; теперь настоящая плашка по центру.
	_msg_label = _build_message_panel(layer, Control.PRESET_CENTER, Vector2.ZERO, 30,
		Color(1.0, 0.4, 0.4, 0.55))
	_msg_label.add_theme_color_override("font_color", Color(1.0, 0.55, 0.5))

	# Экран победы — та самая «жёлтая надпись в конце уровня» без фона и без
	# возможности спокойно прочитать (жалоба повторялась несколько раз).
	# Теперь плашка как везде; для обычного прохождения уровня/Накала она почти
	# сразу сменяется полным экраном результатов (_show_stats_screen), а для
	# терминальных экранов (обучение/финал кампании/Логово) держится, пока не
	# нажат Esc — и её наконец можно спокойно дочитать.
	_win_label = _build_message_panel(layer, Control.PRESET_CENTER, Vector2.ZERO, 32,
		Color(1.0, 0.85, 0.3, 0.6))
	_win_label.add_theme_color_override("font_color", Color(1.0, 0.85, 0.3))

	_build_pause_overlay(layer)

func _build_pause_overlay(layer: CanvasLayer) -> void:
	_pause_overlay = Control.new()
	_pause_overlay.set_anchors_preset(Control.PRESET_FULL_RECT)
	_pause_overlay.visible = false
	_pause_overlay.process_mode = Node.PROCESS_MODE_ALWAYS
	layer.add_child(_pause_overlay)

	var bg := ColorRect.new()
	bg.set_anchors_preset(Control.PRESET_FULL_RECT)
	bg.color = Color(0.03, 0.03, 0.06, 0.9)
	_pause_overlay.add_child(bg)

	var center := CenterContainer.new()
	center.set_anchors_preset(Control.PRESET_FULL_RECT)
	_pause_overlay.add_child(center)

	var root := VBoxContainer.new()
	root.add_theme_constant_override("separation", 22)
	root.alignment = BoxContainer.ALIGNMENT_CENTER
	center.add_child(root)

	var title := Label.new()
	title.text = GameConfig.t("pause_title")
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	title.add_theme_font_size_override("font_size", 48)
	title.add_theme_color_override("font_color", Color(1.0, 0.85, 0.3))
	root.add_child(title)

	# Две колонки: слева карта + кнопки, справа информация.
	var cols := HBoxContainer.new()
	cols.add_theme_constant_override("separation", 56)
	cols.alignment = BoxContainer.ALIGNMENT_CENTER
	root.add_child(cols)

	# --- Левая колонка: карта и кнопки ---
	var left := VBoxContainer.new()
	left.add_theme_constant_override("separation", 12)
	cols.add_child(left)

	var map_title := Label.new()
	map_title.text = GameConfig.tt("Карта (пройденный путь)", "Map (path traveled)")
	map_title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	map_title.add_theme_font_size_override("font_size", 16)
	map_title.add_theme_color_override("font_color", Color(0.7, 0.7, 0.8))
	left.add_child(map_title)

	_minimap = TextureRect.new()
	_minimap.custom_minimum_size = Vector2(320, 200)
	_minimap.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	_minimap.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	_minimap.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	left.add_child(_minimap)

	# небольшой отступ между картой и кнопками
	var spacer := Control.new()
	spacer.custom_minimum_size = Vector2(0, 8)
	left.add_child(spacer)

	# «Продолжить» отдельной кнопкой не дублируем — тот же жест уже делает
	# «← Назад» в углу (единый способ вернуться в игру, как и везде в меню).
	if GameConfig.tutorial_mode:
		pass   # обучение: без магазина/навыков — не отвлекать от шагов
	elif GameConfig.active_run >= 0:
		# В «Накале» прокачка — на алтаре за Накал; рестарт уровня запрещён.
		left.add_child(_make_overlay_button(GameConfig.t("pause_altar"), _open_altar_shop))
	else:
		left.add_child(_make_overlay_button(GameConfig.t("pause_skills"), _open_skills_menu))
		left.add_child(_make_overlay_button(GameConfig.t("pause_restart"), _restart))
	if not GameConfig.tutorial_mode:
		# «Эхо времени» (§7) — переключается и прямо из игры, не только в
		# настройках: тумблер тут же обновляет свой текст и сохраняет выбор.
		_echo_toggle_btn = _make_overlay_button(_echo_toggle_text(), _toggle_echo_time)
		left.add_child(_echo_toggle_btn)
	left.add_child(_make_overlay_button(GameConfig.t("pause_menu"), _goto_menu))

	# --- Правая колонка: информация ---
	var right := VBoxContainer.new()
	right.alignment = BoxContainer.ALIGNMENT_CENTER
	cols.add_child(right)

	_pause_info = Label.new()
	_pause_info.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_pause_info.add_theme_font_size_override("font_size", 18)
	right.add_child(_pause_info)

	# Постоянная «← Назад» сверху-слева (поверх всего; возобновляет игру, как Esc).
	var back_btn := _make_overlay_button(GameConfig.t("back_arrow"), _toggle_pause)
	back_btn.custom_minimum_size = Vector2(130, 44)
	back_btn.focus_mode = Control.FOCUS_NONE
	back_btn.set_anchors_preset(Control.PRESET_TOP_LEFT)
	back_btn.offset_left = 20
	back_btn.offset_top = 20
	_pause_overlay.add_child(back_btn)

# Сообщение-плашка (событие/смерть/победа): панель с рамкой вместо голого
# цветного текста, чтобы её было видно как настоящее сообщение, а не мерцающую
# надпись поверх мира. Видимость панели автоматически следует за видимостью
# лейбла (лейбл — единственное, что переключают все существующие места кода,
# т.е. `_win_label.visible = true/false` продолжает работать как раньше).
func _build_message_panel(layer: CanvasLayer, preset: int, pos: Vector2, font_size: int, border: Color) -> Label:
	var wrap := CenterContainer.new()
	wrap.set_anchors_preset(preset)
	wrap.position = pos
	wrap.mouse_filter = Control.MOUSE_FILTER_IGNORE
	layer.add_child(wrap)

	var panel := PanelContainer.new()
	panel.visible = false
	# Полупрозрачный фон (не общий непрозрачный UIStyle.panel_stylebox): эти
	# плашки всплывают ПРЯМО НАД игроком (камера всегда центрирует его), и
	# сплошной фон полностью закрывал бы персонажа на время сообщения.
	var sb := UIStyle.panel_stylebox(border)
	sb.bg_color.a = 0.55
	panel.add_theme_stylebox_override("panel", sb)
	wrap.add_child(panel)

	var lbl := Label.new()
	lbl.visible = false   # синхронизирован с panel.visible — иначе Label.visible
						   # по умолчанию true, и первое "lbl.visible = true" ничего
						   # не меняет: visibility_changed не срабатывает, панель
						   # так и остаётся скрытой навсегда (баг: экран победы не
						   # появляется после того, как игрок коснулся выхода).
	lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	lbl.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	lbl.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	lbl.custom_minimum_size = Vector2(520, 0)
	lbl.add_theme_font_size_override("font_size", font_size)
	panel.add_child(lbl)

	lbl.visibility_changed.connect(func() -> void: panel.visible = lbl.visible)
	return lbl

func _make_overlay_button(text: String, on_pressed: Callable) -> Button:
	return UIStyle.make_button(text, on_pressed, 240, 44, 22)

var _echo_toggle_btn: Button

func _echo_toggle_text() -> String:
	return GameConfig.tt("Эхо времени: %s", "Echo of Time: %s") % (
		GameConfig.tt("ВКЛ", "ON") if GameConfig.echo_time_enabled else GameConfig.tt("выкл", "off"))

func _toggle_echo_time() -> void:
	GameConfig.echo_time_enabled = not GameConfig.echo_time_enabled
	if not GameConfig.test_mode:
		GameConfig.save_game()
	if _echo_toggle_btn and is_instance_valid(_echo_toggle_btn):
		_echo_toggle_btn.text = _echo_toggle_text()

func _update_reveal(charge: float) -> void:
	var ui = _skills_ui.get("reveal")
	if ui == null:
		return
	var icon: SkillHudIcon = ui["icon"]
	icon.ready_frac = clampf(charge, 0.0, 1.0)
	icon.glow_pulse = charge >= 1.0
	icon.low_energy = false
	icon.queue_redraw()

func _update_skill(id: String, cd: float, energy: float, cost: float, cd_max: float) -> void:
	var ui = _skills_ui.get(id)
	if ui == null:
		return
	var icon: SkillHudIcon = ui["icon"]
	var ready := cd <= 0.05 and energy >= cost
	icon.ready_frac = 1.0 if cd <= 0.05 else clampf(1.0 - cd / maxf(cd_max, 0.01), 0.0, 1.0)
	icon.low_energy = energy < cost
	icon.queue_redraw()
	# Переход кулдаун → готов: короткий «пинок» иконки.
	if ready and not ui["ready"]:
		_icon_pop(icon)
	ui["ready"] = ready

func _icon_pop(icon: Control) -> void:
	icon.pivot_offset = icon.size * 0.5
	var t := create_tween()
	t.tween_property(icon, "scale", Vector2.ONE * 1.18, 0.08).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	t.tween_property(icon, "scale", Vector2.ONE, 0.16).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
