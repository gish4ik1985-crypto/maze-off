extends Node

# Глобальные настройки и прогресс игры (autoload "GameConfig").
# Читается при генерации лабиринта и при открытии меню навыков.

# Апекс открылся (только что). main.gd слушает и показывает баннер + звук —
# раньше открытие происходило молча где-то внутри магазина/статов, и игрок
# не понимал, включился навык или нет (в HUD у него даже не было иконки).
signal apex_unlocked

# ── Параметры лабиринта ──────────────────────────────────────────────────────
var cols: int          = 16
var rows: int          = 10
var station_count: int = 8
var player_speed: float    = 320.0
var max_energy: float      = 2.0
var drain_per_sec: float   = 0.04
var darkness: float        = 0.05
var door_pairs: int        = 1
var lives: int             = 3
var events_enabled: bool       = true
var progressive_enabled: bool  = true
var door_regen_enabled: bool   = false
var door_regen_chance: float   = 0.3
var darkness_chaser: bool      = true
var boss_test_enabled: bool    = false  # тест: босс на выбранном уровне (не зависит от Накала)
var show_fps: bool             = false  # показывать счётчик FPS внизу слева
var test_mode: bool            = false  # тест ранней версии: все уровни открыты + Спуск дня без лимита
var hard_mode: bool            = false  # legacy-флаг (мигрирует в difficulty=2 при загрузке)
var beacon_pulse: bool         = true   # пульс-указатель от игрока к маяку
var start_hint_shown: bool     = false  # искра-подсказка к выходу уже показана на 1-м уровне (один раз)
var help_intro_seen: bool      = false  # игрок открыл полный список тем Справки (иначе — только 3 базовые)
var music_volume: float        = 0.8    # громкость музыки 0..1 (шина "Music")
var sfx_volume: float          = 1.0    # громкость звуков 0..1 (шина "SFX")
var fullscreen: bool           = false
var vsync: bool                = true
var resolution_idx: int        = 1
const RESOLUTIONS := [Vector2i(1280, 720), Vector2i(1600, 900), Vector2i(1920, 1080), Vector2i(2560, 1440)]

# ── Язык интерфейса ("ru"/"en") ───────────────────────────────────────────────
# Лёгкий словарь вместо стандартного TranslationServer/.po — проще править и
# гонять в одном PR. Покрывает основной UI (меню, HUD, настройки, справка);
# лор/голос лабиринта/сообщения событий пока только на русском (см. LANG.md).
var locale: String = "ru"

func t(key: String) -> String:
	var entry: Dictionary = LANG.get(key, {})
	return str(entry.get(locale, entry.get("ru", key)))

# Билингвальная пара для одноразовых игровых строк (флейвор, flash_message,
# лор и т.п.) — проще, чем заводить ключ в LANG для каждой фразы.
func tt(ru: String, en: String) -> String:
	return en if locale == "en" else ru

const LANG := {
	"menu_play":     {"ru": "Играть",     "en": "Play"},
	"menu_settings": {"ru": "Настройки",  "en": "Settings"},
	"menu_help":     {"ru": "Справка",    "en": "Help"},
	"menu_quit":     {"ru": "Выход",      "en": "Quit"},
	"subtitle":      {"ru": "лабиринт во тьме", "en": "a maze in the dark"},

	"top_shop":      {"ru": "Магазин",    "en": "Shop"},
	"top_tutorial":  {"ru": "Обучение",   "en": "Tutorial"},
	"top_journal":   {"ru": "Дневник",    "en": "Journal"},
	"top_bestiary":  {"ru": "Бестиарий",  "en": "Bestiary"},

	"mode_levels_title": {"ru": "УРОВНИ", "en": "LEVELS"},
	"mode_levels_desc":  {"ru": "Кампания: 50 уровней, прогресс и навыки — навсегда.\n\nПродолжить: уровень %d", "en": "Campaign: 50 levels, progress and skills — forever.\n\nContinue: level %d"},
	"mode_ember_title":  {"ru": "НАКАЛ", "en": "EMBER"},
	"mode_ember_desc":   {"ru": "Спуск за огнём: чем глубже, тем злее тьма.\n\n3 жизни на весь спуск. Банкуй Накал на алтарях.", "en": "Descend for fire: the deeper, the darker.\n\n3 lives for the whole run. Bank Ember at altars."},
	"mode_daily_title":  {"ru": "СПУСК ДНЯ", "en": "DAILY DIVE"},
	"mode_daily_desc":   {"ru": "Один лабиринт на всех, одна попытка в день.", "en": "One maze for everyone, one attempt per day."},
	"mode_lair_title":   {"ru": "ЛОГОВО", "en": "LAIR"},
	"mode_lair_desc":    {"ru": "10 логов: владыка тьмы — в центре лабиринта.\n\nДойди сквозь стражу. Прогресс: %d/%d", "en": "10 lairs: a dark lord waits at the maze's center.\n\nFight through the guard. Progress: %d/%d"},

	"pick_level":    {"ru": "выбор уровня (%d)", "en": "pick level (%d)"},
	"difficulty":    {"ru": "Сложность:", "en": "Difficulty:"},
	"diff_low":      {"ru": "◦ Тлеющий", "en": "◦ Ember"},
	"diff_mid":      {"ru": "● Горящий", "en": "● Blaze"},
	"diff_high":     {"ru": "☀ Пылающий", "en": "☀ Inferno"},

	"back":          {"ru": "Назад", "en": "Back"},
	"back_arrow":    {"ru": "← Назад", "en": "← Back"},
	"close_esc":     {"ru": "Закрыть  (Esc)", "en": "Close  (Esc)"},

	"settings_sound":  {"ru": "Звук", "en": "Sound"},
	"settings_screen": {"ru": "Экран", "en": "Display"},
	"settings_game":   {"ru": "Игра", "en": "Game"},
	"settings_test":   {"ru": "🔧 Тестирование (для автора)", "en": "🔧 Testing (developer)"},
	"vol_music":       {"ru": "Громкость музыки", "en": "Music volume"},
	"vol_sfx":         {"ru": "Громкость звуков", "en": "SFX volume"},
	"fullscreen":      {"ru": "Полноэкранный режим", "en": "Fullscreen"},
	"resolution":      {"ru": "Разрешение (в окне)", "en": "Resolution (windowed)"},
	"vsync":           {"ru": "Вертикальная синхронизация (VSync)", "en": "Vertical sync (VSync)"},
	"beacon_pulse_opt":{"ru": "Пульс-указатель к маяку", "en": "Beacon direction pulse"},
	"show_fps_opt":    {"ru": "Показывать счётчик FPS", "en": "Show FPS counter"},
	"language":        {"ru": "Язык", "en": "Language"},
	"about_versions":  {"ru": "О версиях", "en": "About versions"},
	"reset_progress":  {"ru": "Сбросить прогресс", "en": "Reset progress"},
	"reset_confirm":   {"ru": "Точно сбросить ВСЁ? Нажми ещё раз", "en": "Really reset EVERYTHING? Press again"},

	"lives":         {"ru": "Жизни: %d", "en": "Lives: %d"},
	"sp_xp":         {"ru": "SP: %d   XP: %d/%d", "en": "SP: %d   XP: %d/%d"},
	"pause_title":   {"ru": "ПАУЗА", "en": "PAUSED"},
	"pause_continue":{"ru": "Продолжить", "en": "Resume"},
	"pause_skills":  {"ru": "Навыки", "en": "Skills"},
	"pause_restart": {"ru": "Заново", "en": "Restart"},
	"pause_altar":   {"ru": "Алтарь — магазин", "en": "Altar — shop"},
	"pause_menu":    {"ru": "В меню", "en": "To menu"},
}

# Применить экранные настройки (при старте и из меню настроек).
func apply_display() -> void:
	DisplayServer.window_set_vsync_mode(DisplayServer.VSYNC_ENABLED if vsync else DisplayServer.VSYNC_DISABLED)
	if fullscreen:
		DisplayServer.window_set_mode(DisplayServer.WINDOW_MODE_FULLSCREEN)
	else:
		DisplayServer.window_set_mode(DisplayServer.WINDOW_MODE_WINDOWED)
		var r: Vector2i = RESOLUTIONS[clampi(resolution_idx, 0, RESOLUTIONS.size() - 1)]
		DisplayServer.window_set_size(r)

# ── Сложность ────────────────────────────────────────────────────────────────
# 0 Тлеющий  — мягче: свет тает медленнее, враги ленивее, +2 жизни; награды ×0.75.
# 1 Горящий  — базовый баланс; награды ×1.
# 2 Пылающий — хард: в «Уровнях» НЕТ станций (свет только из осколков, запас ×2);
#              в «Накале» станции-алтари остаются (иначе некуда банковать), но
#              враги злее; награды ×1.5. Прохождение отмечается в Дневнике.
var difficulty: int = 1

const DIFF_NAMES := ["Тлеющий", "Горящий", "Пылающий"]
const DIFF_DESC := [
	"Мягкое пламя: свет тает на треть медленнее, враги ленивее, +2 жизни.\nНаграды (XP и Накал) ×0.75. Чтобы освоиться.",
	"Ровное пламя: базовый баланс игры. Награды ×1.",
	"Пылающий: в «Уровнях» нет станций зарядки — свет только из осколков (запас ×2).\nВраги злее. Награды ×1.5, прохождение отмечается в Дневнике.",
]
const DIFF_NAMES_EN := ["Ember", "Blaze", "Inferno"]
const DIFF_DESC_EN := [
	"Gentle flame: light fades a third slower, enemies are lazier, +2 lives.\nRewards (XP and Ember) ×0.75. A good place to start.",
	"Steady flame: the game's base balance. Rewards ×1.",
	"Inferno: in «Levels» there are no charging stations — light comes only from shards (double capacity).\nEnemies are fiercer. Rewards ×1.5, completion is marked in the Journal.",
]

func diff_name(i: int) -> String:
	return (DIFF_NAMES_EN if locale == "en" else DIFF_NAMES)[clampi(i, 0, 2)]

func diff_desc(i: int) -> String:
	return (DIFF_DESC_EN if locale == "en" else DIFF_DESC)[clampi(i, 0, 2)]

func diff_drain_mult() -> float:
	return [0.7, 1.0, 1.0][clampi(difficulty, 0, 2)]

func diff_enemy_mult() -> float:
	return [0.85, 1.0, 1.1][clampi(difficulty, 0, 2)]

func diff_reward_mult() -> float:
	return [0.75, 1.0, 1.5][clampi(difficulty, 0, 2)]

func diff_extra_lives() -> int:
	return 2 if difficulty == 0 else 0

# ── Текущий уровень и иммунитет ──────────────────────────────────────────────
var level: int            = 1
var max_unlocked_level: int = 1   # самый высокий уровень, доступный для выбора
var enemy_encounters: int = 0

# [GAMEDESIGN §18] Последовательное открытие режимов — экран «Играть» новичку
# не вываливает все 4 режима сразу (перегружает выбором до того, как игрок
# освоил базовый цикл «Уровней»). Условие — чисто по max_unlocked_level, без
# отдельных персистентных флагов: просто и работает корректно для уже
# существующих сохранений (порог уже пройден → режим сразу открыт, без
# лишнего тоста задним числом — см. main.gd::_announce_mode_unlocks, тост
# стреляет только на самом пересечении порога).
const MODE_UNLOCK_DAILY := 6    # открыт после прохождения уровня 5
const MODE_UNLOCK_EMBER := 11   # открыт после прохождения уровня 10
const MODE_UNLOCK_LAIR := 21    # открыт после прохождения уровня 20

func is_daily_unlocked() -> bool:
	return max_unlocked_level >= MODE_UNLOCK_DAILY
func is_ember_unlocked() -> bool:
	return max_unlocked_level >= MODE_UNLOCK_EMBER
func is_lair_unlocked() -> bool:
	return max_unlocked_level >= MODE_UNLOCK_LAIR

# ── Режим игры: «Уровни» vs «Накал» (рогалик-забег) ──────────────────────────
# active_run == -1 → режим «Уровни» (глобальный профиль, классический).
# active_run 0..2  → идёт забег «Накал» в этом слоте: прогресс отдельный и
#                    начинается «с нуля» в каждом новом забеге.
const RUN_SLOTS := 3
const RUN_LIVES := 3            # жизни на ВЕСЬ забег (не на уровень)
# 4-й скрытый слот — «Спуск дня»: тот же механизм забега, но с сидом от даты и
# одной попыткой в день. В UI слотов Накала не показывается (циклы по RUN_SLOTS).
const DAILY_SLOT := 3
var active_run: int = -1
var runs: Array = [null, null, null, null]   # снимок каждого слота (Dictionary | null)

# ── Накал: горизонты, контракты, обеты (GAMEDESIGN.md п.15) ──────────────────
# Нарративная рамка режима: «спуск за огнём» — ты несёшь уголёк из глубин;
# чем глубже, тем жарче добыча и тем злее тьма.

# Горизонты — именованные вехи глубины (каждые 5 этажей). Лестница целей
# вместо безликого счётчика: «дошёл до Кузни тьмы» запоминается.
const HORIZONS := [
	"Пепелище", "Тлеющие залы", "Костяная галерея", "Кузня тьмы",
	"Озеро пепла", "Горло бездны", "Сердце жара",
]
const HORIZONS_EN := [
	"The Ashfield", "Smoldering Halls", "Bone Gallery", "Forge of Dark",
	"Ash Lake", "Throat of the Abyss", "Heart of the Blaze",
]
const HORIZON_SPAN := 5

func horizon_index(depth: int) -> int:
	return mini((maxi(depth, 1) - 1) / HORIZON_SPAN, HORIZONS.size() - 1)

func horizon_name(depth: int) -> String:
	return (HORIZONS_EN if locale == "en" else HORIZONS)[horizon_index(depth)]

# Контракты забега: необязательный модификатор, выбирается на брифинге,
# живёт в снимке слота ("contract"). Риск ↔ награда, реиграбельность выбором.
const RUN_CONTRACTS := {
	"ashes":   {"name": "Пепельный путь", "desc": "Алтарей вдвое меньше, но весь Накал ×1.5.\nБанковать сложнее — нести страшнее."},
	"swift":   {"name": "Гон",            "desc": "Тьма быстрее (+15% скорости врагов),\nно каждый осколок восполняет Волю."},
	"onelife": {"name": "Одно дыхание",   "desc": "ОДНА жизнь на весь спуск. Взамен — случайный\nнавык уже открыт на старте и Накал ×1.5."},
}
const RUN_CONTRACTS_EN := {
	"ashes":   {"name": "Ashen Path",   "desc": "Half as many altars, but all Ember ×1.5.\nBanking is harder — carrying is scarier."},
	"swift":   {"name": "The Chase",    "desc": "The dark is faster (+15% enemy speed),\nbut every shard refills Will."},
	"onelife": {"name": "One Breath",   "desc": "ONE life for the whole run. In exchange — a random\nskill is already unlocked at start and Ember ×1.5."},
}

func contract_name(id: String) -> String:
	var d: Dictionary = (RUN_CONTRACTS_EN if locale == "en" else RUN_CONTRACTS).get(id, {})
	return str(d.get("name", id))

func contract_desc(id: String) -> String:
	var d: Dictionary = (RUN_CONTRACTS_EN if locale == "en" else RUN_CONTRACTS).get(id, {})
	return str(d.get("desc", ""))

# Обеты слотов: долгосрочная цель каждого слота Накала. Выполнение — разовая
# награда SP в глобальный профиль «Уровней» (мост между режимами).
const RUN_VOWS := [
	{"text": "Забанкуй 400 Накала за один забег", "kind": "banked", "need": 400, "sp": 3},
	{"text": "Дойди до глубины 15 (Озеро пепла)", "kind": "depth",  "need": 15,  "sp": 3},
	{"text": "Собери серию из 6 чистых этажей",   "kind": "streak", "need": 6,   "sp": 3},
]
const RUN_VOWS_TEXT_EN := [
	"Bank 400 Ember in a single run",
	"Reach depth 15 (Ash Lake)",
	"Get a streak of 6 clean floors",
]

func vow_text(i: int) -> String:
	return RUN_VOWS_TEXT_EN[i] if locale == "en" else str(RUN_VOWS[i]["text"])
var vows_done: Array = [false, false, false]
var vow_reward_pending: int = 0   # SP, ждущие возврата в глобальный профиль

# Проверить обет активного слота (зовётся из main при банке/серии/спуске).
# Возвращает текст выполненного обета или "".
func check_run_vow() -> String:
	if active_run < 0 or active_run >= RUN_VOWS.size():
		return ""
	if vows_done[active_run]:
		return ""
	var r: Dictionary = runs[active_run]
	if r == null:
		return ""
	var vow: Dictionary = RUN_VOWS[active_run]
	var val := 0
	match str(vow["kind"]):
		"banked": val = int(r.get("ember_banked", 0))
		"depth":  val = int(r.get("max_depth", 1))
		"streak": val = int(r.get("best_streak", 0))
	if val < int(vow["need"]):
		return ""
	vows_done[active_run] = true
	vow_reward_pending += int(vow["sp"])
	save_game()
	return vow_text(active_run)

# ── Спуск дня ────────────────────────────────────────────────────────────────
# История результатов по датам: [{date, depth, ember}]. Одна запись = один день.
var daily_history: Array = []

func today_str() -> String:
	return Time.get_date_string_from_system()

func is_daily() -> bool:
	return active_run == DAILY_SLOT

# Сегодняшний спуск уже завершён (запись в истории за сегодня)?
func daily_played_today() -> bool:
	var today := today_str()
	for e in daily_history:
		if str(e.get("date", "")) == today:
			return true
	return false

# Есть ли незавершённый сегодняшний спуск (можно продолжить)?
func daily_resumable() -> bool:
	var r = runs[DAILY_SLOT]
	return r != null and not bool(r.get("ended", false)) and str(r.get("date", "")) == today_str()

func start_daily_run() -> void:
	runs[DAILY_SLOT] = _new_run_dict()
	runs[DAILY_SLOT]["date"] = today_str()
	_load_run_into_live(DAILY_SLOT)
	save_game()

func resume_daily_run() -> void:
	_load_run_into_live(DAILY_SLOT)
	resumed = true

# Серия дней подряд (включая сегодня либо вчера как последний сыгранный).
func daily_streak() -> int:
	if daily_history.is_empty():
		return 0
	var dates := {}
	for e in daily_history:
		dates[str(e.get("date", ""))] = true
	var day := Time.get_unix_time_from_system()
	# Если сегодня ещё не играл — серия может кончаться вчера.
	if not dates.has(Time.get_date_string_from_unix_time(int(day))):
		day -= 86400.0
	var streak := 0
	while dates.has(Time.get_date_string_from_unix_time(int(day))):
		streak += 1
		day -= 86400.0
	return streak

# ── Обучение ─────────────────────────────────────────────────────────────────
# Транзиентный флаг (не сохраняется): пока true, main.gd строит маленький
# безопасный лабиринт с пошаговым степ-трекером вместо обычного уровня.
var tutorial_mode: bool = false
var resumed: bool = false              # true один раз после resume_run (для баннера «продолжено»)
var open_mode_on_start: bool = false    # true один раз: меню сразу откроет экран «Играть» (после обучения)

# ── Логово: 10 больших уровней с боссом в центре лабиринта ──────────────────
# tutorial_mode/lair_mode взаимоисключающие транзиентные флаги (не сохраняются).
# lair_level выбирается в меню перед стартом; lair_max_unlocked — прогресс,
# персистентный, как max_unlocked_level у «Уровней».
var lair_mode: bool = false
var lair_level: int = 1
var lair_max_unlocked: int = 1
const LAIR_LEVELS := 10

# ── Глобальная статистика (для раздела «Статистика») ─────────────────────────
var stats := {
	"runs_started":   0,
	"runs_ended":     0,
	"best_depth":     0,
	"best_ember":     0,
	"levels_cleared": 0,
	"shards_total":   0,
	"enemies_killed": 0,
	"stations_used":  0,
	"dist_total":     0,   # пиксели пути — пассивка «Лёгкие ноги»
	"time_survived":  0,   # секунды во тьме — «Энергосбережение»
	"skills_cast":    0,   # применения навыков — «Эффективная магия»
	"rank_S": 0, "rank_A": 0, "rank_B": 0, "rank_C": 0, "rank_D": 0,
	# Бестиарий: счётчики по типам врагов 0..5 (см. BESTIARY ниже).
	# seen — впервые заметил тебя (открывает карточку), kill — убито, hit — ударов по тебе.
	"seen_t0": 0, "seen_t1": 0, "seen_t2": 0, "seen_t3": 0, "seen_t4": 0, "seen_t5": 0,
	"kill_t0": 0, "kill_t1": 0, "kill_t2": 0, "kill_t3": 0, "kill_t4": 0, "kill_t5": 0,
	"hit_t0": 0,  "hit_t1": 0,  "hit_t2": 0,  "hit_t3": 0,  "hit_t4": 0,  "hit_t5": 0,
}

# ── Бестиарий «Досье лабиринта» ──────────────────────────────────────────────
# Карточки врагов для экрана в меню. Портрет — MazeTextures.make_enemy(type),
# позже заменяемый на рисованный (карточка читает текстуру по типу, не по имени).
# Карточка скрыта («???») пока seen_tN == 0; полное досье — после первого убийства.
const BESTIARY := [
	{"name": "Блуждающий", "color": Color(0.80, 0.18, 1.00),
	 "lore": "Первый из тьмы. Медленный сгусток, что бродит по коридорам, как забытая мысль. Не ищет тебя — но найдя, не отпустит.",
	 "tactic": "3 HP, медлителен. Любой навык урона добивает его: вспышка в упор, сонар, таран рывком. Или просто уйди — он не догонит.",
	 "name_en": "Wanderer",
	 "lore_en": "The first born of darkness. A slow blob that drifts the corridors like a forgotten thought. It doesn't hunt you — but once it finds you, it won't let go.",
	 "tactic_en": "3 HP, slow. Any damage skill finishes it: flash point-blank, sonar, a dash tackle. Or just walk away — it won't catch up."},
	{"name": "Гончий", "color": Color(1.00, 0.34, 0.08),
	 "lore": "Жгучая искра, сорвавшаяся с цепи. Когда лабиринт злится — он посылает гончих. Их шаги слышны раньше, чем виден свет.",
	 "tactic": "2 HP, но быстр. Не тягайся в скорости — рывок сквозь него (таран) или вспышка в упор. Тление сбрасывает погоню.",
	 "name_en": "Hound",
	 "lore_en": "A burning spark off the leash. When the maze grows angry, it sends hounds. Their footsteps are heard before their light is seen.",
	 "tactic_en": "2 HP, but fast. Don't race it — dash straight through it (tackle) or flash point-blank. Smother breaks its pursuit."},
	{"name": "Циклит", "color": Color(0.10, 1.00, 0.80),
	 "lore": "Существо ритма: движется и замирает, как дыхание лабиринта. Его касание вяжет ноги — тьма учится держать добычу.",
	 "tactic": "Удар замедляет тебя — не дай зажать в углу. Бей в фазе покоя: он беззащитен, пока «выдыхает».",
	 "name_en": "Cyclite",
	 "lore_en": "A creature of rhythm: it moves and freezes like the maze's own breath. Its touch binds your legs — the dark is learning to hold its prey.",
	 "tactic_en": "Its hit slows you — don't get cornered. Strike during its resting phase: it's defenseless while it \"exhales\"."},
	{"name": "Страж", "color": Color(0.75, 0.15, 0.25),
	 "lore": "Багровая глыба древней воли. Стражи не бродят — они охраняют. Видят дальше всех и не знают усталости.",
	 "tactic": "6 HP брони, видит в 1.4 раза дальше. Ключ — заморозка: щит или Хронос (замороженный ловит +1 урона), затем бей. Или обойди стороной.",
	 "name_en": "Guardian",
	 "lore_en": "A crimson slab of ancient will. Guardians don't wander — they watch. They see farther than any other and never tire.",
	 "tactic_en": "6 HP of armor, sees 1.4x farther. Key: freeze it — Shield or Chrono (a frozen enemy takes +1 damage), then hit. Or just go around."},
	{"name": "Фантом", "color": Color(0.75, 0.85, 1.00),
	 "lore": "Бледный след того, кто не выбрался. Почти нет плоти — только скорость и голод. Появляется там, где свет дрогнул.",
	 "tactic": "Всего 1 HP — любой удар развеивает. Но он очень быстр: не беги, а бей навстречу. Тление — и он потеряет след.",
	 "name_en": "Phantom",
	 "lore_en": "The pale trace of someone who never made it out. Almost no flesh left — just speed and hunger. It appears wherever the light flickers.",
	 "tactic_en": "Only 1 HP — any hit dispels it. But it's very fast: don't run, strike as it comes. Smother, and it loses your trail."},
	{"name": "Пиявка", "color": Color(0.45, 0.95, 0.25),
	 "lore": "Кислотная тварь глубин, что пьёт не свет — волю. После её касания руки помнят навыки, но сердце не может их зажечь.",
	 "tactic": "Контакт высасывает Волю — топливо навыков. Держи дистанцию, добивай Сонаром издалека. Не подпускай, когда Воля на нуле.",
	 "name_en": "Leech",
	 "lore_en": "An acid creature of the depths that drinks not light, but Will. After its touch, your hands still remember the skills — but your heart can't light them.",
	 "tactic_en": "Contact drains Will — the fuel for your skills. Keep your distance, finish it off with Sonar from afar. Don't let it close in when Will is at zero."},
]

func bestiary_name(i: int) -> String:
	var d: Dictionary = BESTIARY[i]
	return str(d.get("name_en", d["name"])) if locale == "en" else str(d["name"])

func bestiary_lore(i: int) -> String:
	var d: Dictionary = BESTIARY[i]
	return str(d.get("lore_en", d["lore"])) if locale == "en" else str(d["lore"])

func bestiary_tactic(i: int) -> String:
	var d: Dictionary = BESTIARY[i]
	return str(d.get("tactic_en", d["tactic"])) if locale == "en" else str(d["tactic"])

# ── Ранги как механика ───────────────────────────────────────────────────────
# Ранг уровня (S/A/B/C/D) множит награды за прохождение (XP/Накал): чистая
# игра ощутимо ускоряет прокачку. Серия хороших рангов (S/A) даёт «Благословение
# лабиринта» (ярче стартовый свет), серия D — «Снисхождение» (кристалл у старта).
const RANK_REWARD_MULT := {"S": 1.5, "A": 1.25, "B": 1.0, "C": 0.85, "D": 0.7}
const RANK_STREAK_NEED := 2   # длина серии для благословения/снисхождения

var rank_good_streak: int = 0   # подряд S/A
var rank_bad_streak: int = 0    # подряд D
var level_best_ranks: Dictionary = {}   # уровень (int) → лучший ранг (String), только «Уровни»

func rank_reward_mult(rk: String) -> float:
	return float(RANK_REWARD_MULT.get(rk, 1.0))

# Обновить серии рангов после завершения уровня (оба режима).
func note_rank(rk: String) -> void:
	if rk == "S" or rk == "A":
		rank_good_streak += 1
		rank_bad_streak = 0
	elif rk == "D":
		rank_bad_streak += 1
		rank_good_streak = 0
	else:
		rank_good_streak = 0
		rank_bad_streak = 0

const RANK_ORDER := ["D", "C", "B", "A", "S"]

# Лучший ранг уровня для витрины в выборе уровня (только режим «Уровни»).
func record_level_best_rank(lvl: int, rk: String) -> void:
	if test_mode:
		return
	var old: String = str(level_best_ranks.get(lvl, ""))
	if old == "" or RANK_ORDER.find(rk) > RANK_ORDER.find(old):
		level_best_ranks[lvl] = rk

func rank_blessing_active() -> bool:
	return rank_good_streak >= RANK_STREAK_NEED

func rank_pity_active() -> bool:
	return rank_bad_streak >= RANK_STREAK_NEED

# ── История уровней (для экрана «Результаты») ───────────────────────────────
# Кольцевой буфер последних LEVEL_HISTORY_MAX завершённых уровней (оба режима),
# используется для анализа "как я играю" — см. menu.gd, экран «Результаты».
var level_history: Array = []
const LEVEL_HISTORY_MAX := 50

# entry: {level, time, par, shards_pct, rank, no_dmg, skills_used, mode}
func push_level_history(entry: Dictionary) -> void:
	if test_mode:
		return   # тест-режим автора: история уровней не пишется
	level_history.append(entry)
	if level_history.size() > LEVEL_HISTORY_MAX:
		level_history = level_history.slice(level_history.size() - LEVEL_HISTORY_MAX)
	_save_level_history()

func _save_level_history() -> void:
	var cfg := ConfigFile.new()
	cfg.load(SAVE_PATH)
	cfg.set_value("history", "entries", level_history)
	cfg.save(SAVE_PATH)

# ── Пассивки: ВСЕГДА включены и растут САМИ от действий игрока ──────────────
# Уровень 0..5 по накопленной статистике (шаг step на уровень). Сбрасываются
# вместе со статистикой (reset_progress зануляет stats). Старый словарь
# passives оставлен для совместимости сейвов, но геймплеем не читается.
const PASSIVE_DEFS := {
	"legs":     {"stat": "dist_total",    "step": 30000, "name": "Лёгкие ноги",      "act": "двигайся", "per": "+3% скорости/ур."},
	"charge":   {"stat": "stations_used", "step": 12,    "name": "Быстрая зарядка",  "act": "пей из кристаллов", "per": "+10% зарядки/ур."},
	"save":     {"stat": "time_survived", "step": 600,   "name": "Энергосбережение", "act": "выживай во тьме", "per": "−6% расхода света/ур."},
	"capacity": {"stat": "shards_total",  "step": 20,    "name": "Ёмкость",          "act": "собирай осколки", "per": "+6% запаса света/ур."},
	"range":    {"stat": "levels_cleared","step": 5,     "name": "Дальний свет",     "act": "проходи уровни", "per": "+5% радиуса/ур."},
	"magic":    {"stat": "skills_cast",   "step": 40,    "name": "Эффективная магия","act": "применяй навыки", "per": "−6% цены, −5% КД/ур."},
	# Ветви даров Ядра: растут от той же глобальной статистики, что и остальные.
	"deceit":   {"stat": "enemies_killed","step": 6,     "name": "Обман",            "act": "побеждай врагов", "per": "+10% радиуса приманки/ур."},
	"crush":    {"stat": "levels_cleared","step": 4,     "name": "Сокрушение",       "act": "проходи уровни", "per": "Разлом перезаряжается на 7% быстрее/ур."},
	"stasis":   {"stat": "time_survived", "step": 400,   "name": "Стазис",           "act": "выживай во тьме", "per": "+7% длительности заморозки/ур."},
	"echo":     {"stat": "levels_cleared","step": 7,     "name": "Эхо-память",      "act": "проходи уровни", "per": "+8% длительности пульса/ур."},
}
const PASSIVE_DEFS_EN := {
	"legs":     {"name": "Light Legs",      "act": "move", "per": "+3% speed/star"},
	"charge":   {"name": "Fast Charge",     "act": "drink from crystals", "per": "+10% charge/star"},
	"save":     {"name": "Energy Saving",   "act": "survive in the dark", "per": "-6% light drain/star"},
	"capacity": {"name": "Capacity",        "act": "collect shards", "per": "+6% light capacity/star"},
	"range":    {"name": "Long Light",      "act": "clear levels", "per": "+5% radius/star"},
	"magic":    {"name": "Efficient Magic", "act": "use skills", "per": "-6% cost, -5% cooldown/star"},
	"deceit":   {"name": "Deception",       "act": "defeat enemies", "per": "+10% lure radius/star"},
	"crush":    {"name": "Crush",           "act": "clear levels", "per": "Breach recharges 7% faster/star"},
	"stasis":   {"name": "Stasis",          "act": "survive in the dark", "per": "+7% freeze duration/star"},
	"echo":     {"name": "Echo Memory",     "act": "clear levels", "per": "+8% pulse duration/star"},
}

func passive_name(id: String) -> String:
	var d: Dictionary = PASSIVE_DEFS.get(id, {})
	if locale == "en":
		return str(PASSIVE_DEFS_EN.get(id, {}).get("name", d.get("name", id)))
	return str(d.get("name", id))

func passive_act(id: String) -> String:
	var d: Dictionary = PASSIVE_DEFS.get(id, {})
	if locale == "en":
		return str(PASSIVE_DEFS_EN.get(id, {}).get("act", d.get("act", "")))
	return str(d.get("act", ""))

func passive_per(id: String) -> String:
	var d: Dictionary = PASSIVE_DEFS.get(id, {})
	if locale == "en":
		return str(PASSIVE_DEFS_EN.get(id, {}).get("per", d.get("per", "")))
	return str(d.get("per", ""))

# ── Дерево от колеса Апекса: у каждого навыка своя ветвь-пассивка ────────────
# Уровень пассивки усиливает СВЯЗАННЫЙ навык (+PASSIVE_SKILL_BONUS за уровень)
# и, через него, форму Апекса: Апекс масштабируется силой навыка-формы
# (см. apex_power). Так игроку видно, чем именно качать Апекс.
const SKILL_PASSIVE := {
	"flash":  "range",     # ярче/шире свет — сильнее вспышка
	"dash":   "legs",      # лёгкие ноги — дальше рывок
	"sonar":  "magic",     # эффективная магия — мощнее сонар
	"shield": "capacity",  # ёмкость — крепче щит
	"guide":  "charge",    # быстрая зарядка — вернее искра
	"reveal": "save",      # энергосбережение — дольше озарение
	"pulse":  "echo",      # эхо-память — дольше окно пульса
	"mirage": "deceit",
	"breach": "crush",
	"chrono": "stasis",
}
# Бонус силы навыка за уровень его ветви-пассивки. У базовых навыков — общие
# +4%/ур; у даров Ядра ветвь и есть их главный эффект, проценты выше.
const PASSIVE_SKILL_BONUS := {
	"flash": 0.04, "dash": 0.04, "sonar": 0.04,
	"shield": 0.04, "guide": 0.04, "reveal": 0.04, "pulse": 0.04,
	"mirage": 0.10, "breach": 0.07, "chrono": 0.07,
}

# Множитель силы навыка от его ветви-пассивки (1.0, если ветви нет).
func skill_passive_mult(skill: String) -> float:
	var pid: String = SKILL_PASSIVE.get(skill, "")
	if pid == "":
		return 1.0
	return 1.0 + passive_level(pid) * float(PASSIVE_SKILL_BONUS.get(skill, 0.04))

# Полная сила навыка: мастерство × ветвь-пассивка. Читается геймплеем
# вместо голого mastery_bonus.
func skill_power(skill: String) -> float:
	return mastery_bonus(skill) * skill_passive_mult(skill)

# Сила Апекса в форме навыка form: наследует силу навыка-источника.
func apex_power(form: String) -> float:
	return skill_power(form)

func passive_level(id: String) -> int:
	var d: Dictionary = PASSIVE_DEFS.get(id, {})
	if d.is_empty():
		return 0
	return mini(5, int(stats.get(d["stat"], 0)) / int(d["step"]))

# Прогресс к следующему уровню пассивки: [текущее, нужно] (для карточек).
func passive_progress(id: String) -> Array:
	var d: Dictionary = PASSIVE_DEFS.get(id, {})
	if d.is_empty():
		return [0, 1]
	var v := int(stats.get(d["stat"], 0))
	var step := int(d["step"])
	if v >= step * 5:
		return [step, step]
	return [v % step, step]

var passives := {
	"save":     false,
	"capacity": false,
	"charge":   false,
	"range":    false,
	"legs":     false,
	"magic":    false,
}

# ── Прогресс: XP и очки навыков ─────────────────────────────────────────────
var xp: int           = 0   # текущий прогресс к следующему SP
var skill_points: int = 0   # накопленные незатраченные SP

const XP_PER_SP := 500      # XP, необходимый для получения 1 SP

# ── Мастерство навыков ──────────────────────────────────────────────────────
# Каждое применение активного навыка увеличивает счётчик. Уровень мастерства
# = min(uses / 10, 5). Чем выше — тем сильнее эффект. Мастерство также
# определяет «форму» Апекса (см. ниже).
var skill_uses := {
	"flash": 0, "dash": 0, "sonar": 0,
	"shield": 0, "guide": 0, "reveal": 0, "smother": 0, "pulse": 0,
	"mirage": 0, "breach": 0, "chrono": 0,
}

const MASTERY_PER_LEVEL := 10
const MASTERY_MAX := 5

func mastery(skill: String) -> int:
	return mini(skill_uses.get(skill, 0) / MASTERY_PER_LEVEL, MASTERY_MAX)

# Множитель к длительности/радиусу от мастерства: +15% за уровень
func mastery_bonus(skill: String) -> float:
	return 1.0 + mastery(skill) * 0.15

func add_skill_use(skill: String) -> void:
	# ВАЖНО: обучение читает live skill_uses для отслеживания своих шагов
	# (нажал Q/Shift/R), поэтому здесь его нельзя просто пропускать — вместо
	# этого main.gd делает снимок skill_uses перед обучением и восстанавливает
	# его после (см. _tut_skill_uses_snapshot), чтобы прогресс не закрепился.
	if skill_uses.has(skill):
		skill_uses[skill] += 1
	bump_stat("skills_cast")   # питает пассивку «Эффективная магия»
	# Мастерство растёт от применений — если это только что дотянуло до
	# досрочного условия Апекса (см. apex_ready), открываем его сразу же,
	# а не только в момент покупки навыка в магазине.
	if _try_unlock_apex():
		save_game()

# Единая точка открытия Апекса (вызывается из всех мест, где меняются купленные
# навыки/мастерство): если условие выполнено и Апекс ещё не открыт — открывает
# и шлёт сигнал apex_unlocked (main.gd показывает баннер+звук). Возвращает true,
# если открытие произошло ИМЕННО сейчас (вызывающий код решает, звать ли save_game).
func _try_unlock_apex() -> bool:
	if skills_unlocked.get("apex", false) or not apex_ready():
		return false
	skills_unlocked["apex"] = true
	apex_unlocked.emit()
	return true

func all_active_skills_unlocked() -> bool:
	for k in ["flash", "dash", "sonar", "shield", "guide", "reveal", "pulse"]:
		if not skills_unlocked.get(k, false):
			return false
	return true

# Апекс не обязан ждать все 7 активных навыков: игрок, который явно
# специализируется (купил больше половины и довёл один навык до предела
# мастерства ★5), тоже заслужил супернавык раньше срока. «Придумай сам»
# условие — выбрано так, чтобы требовать реальной вложенности (не просто
# 1 навык на 1★), но не блокировать до полного комплекта.
const APEX_EARLY_MIN_SKILLS := 4
func apex_ready() -> bool:
	if all_active_skills_unlocked():
		return true
	var bought := 0
	var best_mastery := 0
	for k in ["flash", "dash", "sonar", "shield", "guide", "reveal", "pulse"]:
		if skills_unlocked.get(k, false):
			bought += 1
			best_mastery = maxi(best_mastery, mastery(k))
	return bought >= APEX_EARLY_MIN_SKILLS and best_mastery >= MASTERY_MAX

# Топ-N навыков по мастерству. Возвращает массив ключей, отсортированный
# по убыванию мастерства. Используется Апексом для выбора формы.
func top_mastered(n: int = 2) -> Array:
	# Дары боссов участвуют: Апекс может принять и их форму.
	var keys := ["flash", "dash", "sonar", "shield", "guide", "reveal", "pulse", "mirage", "breach", "chrono"]
	keys.sort_custom(func(a, b): return skill_uses.get(a, 0) > skill_uses.get(b, 0))
	return keys.slice(0, n)

# Откуда берётся XP:
#   • движение:        1 XP за каждые 300 пикселей пути  (≈1 XP/с при обычной скорости)
#   • подбор осколка:  75 XP
#   • завершение ур.:  400 XP

# ── Открытые навыки ──────────────────────────────────────────────────────────
# true = навык куплен. Flash и Dash открыты с самого начала (cost 0).
var skills_unlocked := {
	"flash":    true,
	"dash":     true,
	"smother":  true,   # «Тление» (R) — базовый, как Вспышка и Рывок
	"mirage":   false,  # дары боссов (не покупаются — только за победу над Ядром)
	"breach":   false,
	"chrono":   false,
	"sonar":    false,
	"shield":   false,
	"guide":    false,
	"reveal":   false,
	"pulse":    false,
	"save":     false,
	"capacity": false,
	"charge":   false,
	"range":    false,
	"legs":     false,
	"magic":    false,
	"apex":     false,  # супернавык — открывается автоматически
}

# Стоимость открытия (SP). Бесплатные навыки открыты с начала.
# Цены РАЗНЫЕ: лесенка sonar→reveal — чем сильнее навык, тем дороже вход.
const SKILL_COSTS := {
	"flash": 0,  "dash": 0, "smother": 0,
	"sonar": 2,  "shield": 3,
	"guide": 4,  "reveal": 5, "pulse": 4,
	"save": 2,   "capacity": 2,
	"charge": 2, "range": 1,
	"legs": 1,   "magic": 3,
	"apex": 0,   # открывается автоматически — за SP не купить
}

# Цена усиления (+1★): база навыка + текущие звёзды — каждая следующая
# звезда дороже. Дары Ядра (нет в SKILL_COSTS) усиляются от базы 4.
func upgrade_cost(skill: String) -> int:
	var base: int = maxi(int(SKILL_COSTS.get(skill, 4)), 2)
	return base + mastery(skill)

# ── Lifecycle ────────────────────────────────────────────────────────────────

func _ready() -> void:
	load_game()
	_ensure_audio_buses()
	apply_volumes()
	apply_display()
	_apply_ui_scale()
	var tree := get_tree()
	if tree:
		tree.root.size_changed.connect(_apply_ui_scale)

# Аудио-шины "Music"/"SFX" создаются на старте (в project.godot их нет — всё
# процедурно, как и остальной проект). Все плееры указывают bus по имени.
# Свернули окно / ушли в другое приложение — глушим весь звук (Master),
# вернулись — возвращаем. Autoload живёт всегда, поэтому работает и в меню.
func _notification(what: int) -> void:
	if what == NOTIFICATION_APPLICATION_FOCUS_OUT:
		AudioServer.set_bus_mute(AudioServer.get_bus_index("Master"), true)
	elif what == NOTIFICATION_APPLICATION_FOCUS_IN:
		AudioServer.set_bus_mute(AudioServer.get_bus_index("Master"), false)

func _ensure_audio_buses() -> void:
	for bus_name in ["Music", "SFX"]:
		if AudioServer.get_bus_index(bus_name) == -1:
			var idx := AudioServer.bus_count
			AudioServer.add_bus(idx)
			AudioServer.set_bus_name(idx, bus_name)
			AudioServer.set_bus_send(idx, "Master")

# Применить громкости из настроек к шинам (0 → полная тишина).
func apply_volumes() -> void:
	var mi := AudioServer.get_bus_index("Music")
	var si := AudioServer.get_bus_index("SFX")
	if mi != -1:
		AudioServer.set_bus_volume_db(mi, linear_to_db(maxf(music_volume, 0.0001)))
		AudioServer.set_bus_mute(mi, music_volume <= 0.001)
	if si != -1:
		AudioServer.set_bus_volume_db(si, linear_to_db(maxf(sfx_volume, 0.0001)))
		AudioServer.set_bus_mute(si, sfx_volume <= 0.001)

# Глобальный масштаб UI. Высоту окна держит stretch=keep_height (UI всегда
# пропорционален высоте), поэтому проблемной остаётся узкая ширина: на ней
# интерфейс, рассчитанный на ~1280 логических px, обрезается. Ужимаем по
# логической ширине; на стандартном 16:9 множитель = 1.0 (поведение не меняется).
func _apply_ui_scale() -> void:
	var tree := get_tree()
	if tree == null:
		return
	var win := tree.root
	var sz: Vector2i = win.size
	if sz.y <= 0:
		return
	var logical_width: float = 720.0 * float(sz.x) / float(sz.y)
	win.content_scale_factor = clampf(logical_width / 1280.0, 0.6, 1.0)

# ── Методы прогресса ─────────────────────────────────────────────────────────

func add_xp(amount: int) -> void:
	if test_mode or tutorial_mode:
		return   # тест-режим автора / обучение: прогресс не фармится
	xp += int(round(amount * diff_reward_mult()))
	while xp >= XP_PER_SP:
		xp -= XP_PER_SP
		skill_points += 1

# ── Майлстоуны навыков: ЦЕЛЬ ИГРЫ в «Уровнях» ────────────────────────────────
# Закрытый навык открывается ЛИБО за SP (меню навыков), ЛИБО сам — за игровое
# достижение. Игрок всегда видит, к чему идёт (панель «Путь к навыкам» в
# Дневнике + сообщение при открытии). В «Накале» не действует — там алтарь.
const SKILL_MILESTONES := {
	"sonar":  {"stat": "shards_total",   "need": 25, "text": "собери 25 осколков",   "text_en": "collect 25 shards"},
	"shield": {"stat": "enemies_killed", "need": 8,  "text": "победи 8 врагов",      "text_en": "defeat 8 enemies"},
	"guide":  {"stat": "stations_used",  "need": 20, "text": "испей 20 кристаллов",  "text_en": "drink from 20 crystals"},
	"reveal": {"stat": "levels_cleared", "need": 6,  "text": "пройди 6 уровней",     "text_en": "clear 6 levels"},
	"pulse":  {"stat": "skills_cast",    "need": 30, "text": "примени 30 навыков",  "text_en": "use skills 30 times"},
}

func milestone_text(id: String) -> String:
	var ms: Dictionary = SKILL_MILESTONES.get(id, {})
	return str(ms.get("text_en", "")) if locale == "en" else str(ms.get("text", ""))

# Проверяет майлстоуны; возвращает массив только что открытых id (для баннера).
func check_skill_milestones() -> Array:
	if active_run >= 0 or test_mode or tutorial_mode:
		return []
	var newly: Array = []
	for id in SKILL_MILESTONES:
		if skills_unlocked.get(id, false):
			continue
		var ms: Dictionary = SKILL_MILESTONES[id]
		if int(stats.get(ms["stat"], 0)) >= int(ms["need"]):
			skills_unlocked[id] = true
			newly.append(id)
	if not newly.is_empty():
		_try_unlock_apex()
		save_game()
	return newly

# Единая точка изменения глобальной статистики: в тест-режиме автора ничего
# не записывается (ни счётчики, ни рекорды) — тестовые прогоны не искажают
# Дневник и Спуск дня.
func bump_stat(key: String, delta: int = 1) -> void:
	if test_mode or tutorial_mode:
		return
	stats[key] = int(stats.get(key, 0)) + delta

func max_stat(key: String, value: int) -> void:
	if test_mode or tutorial_mode:
		return
	stats[key] = maxi(int(stats.get(key, 0)), value)

# Возвращает true если покупка прошла успешно.
func try_buy_skill(skill: String) -> bool:
	# Уже открытый активный навык покупается ПОВТОРНО как усиление:
	# +1★ мастерства (эквивалент MASTERY_PER_LEVEL применений), до 5★.
	if skills_unlocked.get(skill, false):
		if not skill_uses.has(skill) or mastery(skill) >= MASTERY_MAX:
			return false
		var up_cost: int = upgrade_cost(skill)
		if skill_points < up_cost:
			return false
		skill_points -= up_cost
		skill_uses[skill] += MASTERY_PER_LEVEL
		# Усиление за SP тоже может сразу довести навык до ★5 — тот самый
		# досрочный путь к Апексу (см. apex_ready), а не только «купи все 7».
		_try_unlock_apex()
		save_game()
		return true
	var cost: int = SKILL_COSTS.get(skill, 999)
	if skill_points < cost:
		return false
	skill_points -= cost
	skills_unlocked[skill] = true
	# Все 7 активных навыков (или досрочное условие апекса) — открываем Апекс.
	_try_unlock_apex()
	save_game()
	return true

# ── Забеги «Накал» ───────────────────────────────────────────────────────────

func _default_unlocked() -> Dictionary:
	# Свежий забег: открыты только Вспышка и Рывок, остальное добывается по ходу.
	return {
		"flash": true, "dash": true, "smother": true,
		"mirage": false, "breach": false, "chrono": false,
		"sonar": false, "shield": false, "guide": false, "reveal": false,
		"save": false, "capacity": false, "charge": false,
		"range": false, "legs": false, "magic": false, "apex": false,
	}

func _new_run_dict() -> Dictionary:
	return {
		"level": 1,
		"max_depth": 1,
		"lives": RUN_LIVES,
		"ember_banked": 0,    # внутризабеговая валюта (на алтаре)
		"ember_carried": 0,   # незабанканный Накал (под угрозой при гибели)
		"ember_streak": 0,    # серия чистых этажей (множитель набора Накала)
		"xp": 0,
		"skill_points": 0,
		"skills": _default_unlocked(),
		"uses": {"flash": 0, "dash": 0, "sonar": 0, "shield": 0, "guide": 0, "reveal": 0, "smother": 0, "mirage": 0, "breach": 0, "chrono": 0},
		"passives": {"save": false, "capacity": false, "charge": false, "range": false, "legs": false, "magic": false},
		"ranks": [],          # история рангов: [{lvl, rank, shards, total, no_dmg, no_skill, time}]
		"rank_good_streak": 0,
		"rank_bad_streak": 0,
		"contract": "",       # контракт забега (ключ RUN_CONTRACTS или "")
		"best_streak": 0,     # лучшая серия чистых этажей (для обета)
		"ended": false,
	}

# Копируем снимок слота в «живые» переменные, которые читает геймплей.
func _load_run_into_live(slot: int) -> void:
	var r: Dictionary = runs[slot]
	active_run   = slot
	level        = int(r.get("level", 1))
	lives        = int(r.get("lives", RUN_LIVES))
	xp           = int(r.get("xp", 0))
	skill_points = int(r.get("skill_points", 0))
	var rs: Dictionary = r.get("skills", {})
	for k in skills_unlocked.keys():
		# smother — базовый навык: включён и в старых снимках забегов, где его нет.
		skills_unlocked[k] = bool(rs.get(k, k == "smother"))
	var ru: Dictionary = r.get("uses", {})
	for k in skill_uses.keys():
		skill_uses[k] = int(ru.get(k, 0))
	var rp: Dictionary = r.get("passives", {})
	for k in passives.keys():
		passives[k] = bool(rp.get(k, false))
	rank_good_streak = int(r.get("rank_good_streak", 0))
	rank_bad_streak  = int(r.get("rank_bad_streak", 0))

# Обратная синхронизация: «живые» переменные → снимок активного слота.
func _sync_live_into_run() -> void:
	if active_run < 0 or runs[active_run] == null:
		return
	var r: Dictionary = runs[active_run]
	r["level"]        = level
	r["max_depth"]    = maxi(int(r.get("max_depth", 1)), level)
	r["lives"]        = lives
	r["xp"]           = xp
	r["skill_points"] = skill_points
	for k in skills_unlocked.keys():
		r["skills"][k] = skills_unlocked[k]
	for k in skill_uses.keys():
		r["uses"][k] = skill_uses[k]
	for k in passives.keys():
		r["passives"][k] = passives[k]
	r["rank_good_streak"] = rank_good_streak
	r["rank_bad_streak"]  = rank_bad_streak

func start_new_run(slot: int, contract: String = "") -> void:
	runs[slot] = _new_run_dict()
	if contract != "" and RUN_CONTRACTS.has(contract):
		runs[slot]["contract"] = contract
		if contract == "onelife":
			runs[slot]["lives"] = 1
			# Взамен — случайный покупной навык уже открыт.
			var opts := ["sonar", "shield", "guide", "reveal"]
			runs[slot]["skills"][opts[randi() % opts.size()]] = true
	if slot != DAILY_SLOT:
		bump_stat("runs_started")
	_load_run_into_live(slot)
	save_game()

# Контракт активного забега ("" — без контракта).
func run_contract() -> String:
	if active_run < 0 or runs[active_run] == null:
		return ""
	return str(runs[active_run].get("contract", ""))

func resume_run(slot: int) -> void:
	var r = runs[slot]
	if r == null or bool(r.get("ended", false)):
		# Банк Накала не сгорает между забегами — переносим в новый слот.
		var saved_bank: int = 0 if r == null else int(r.get("ember_banked", 0))
		start_new_run(slot)
		if saved_bank > 0:
			runs[slot]["ember_banked"] = saved_bank
	else:
		_load_run_into_live(slot)
		resumed = true

# Выход в меню без гибели — забег сохраняется в слоте, можно продолжить.
func leave_run() -> void:
	if active_run < 0:
		return
	_sync_live_into_run()
	save_game()
	active_run = -1
	load_levels_profile()

# Гибель — забег завершён; обновляем глобальную статистику.
func end_run() -> void:
	if active_run < 0:
		return
	_sync_live_into_run()
	var r: Dictionary = runs[active_run]
	r["ended"] = true
	var was_daily := active_run == DAILY_SLOT
	if was_daily:
		# Спуск дня: результат — в дневную историю; счётчики забегов Накала не
		# трогаем. В тест-режиме автора история дней не пишется (иначе серии врут).
		if not test_mode:
			daily_history.append({
				"date": str(r.get("date", today_str())),
				"depth": int(r.get("max_depth", 1)),
				"ember": int(r.get("ember_banked", 0)),
			})
			if daily_history.size() > 60:
				daily_history = daily_history.slice(daily_history.size() - 60)
	else:
		bump_stat("runs_ended")
	max_stat("best_depth", int(r.get("max_depth", 1)))
	save_game()          # пока active_run>=0 — пишем в слот+статистику, НЕ в глобал
	active_run = -1
	load_levels_profile()

# Краткое описание слота для меню. status: "empty" | "active" | "ended".
func run_summary(slot: int) -> Dictionary:
	var r = runs[slot]
	if r == null:
		return {"status": "empty"}
	return {
		"status": "ended" if bool(r.get("ended", false)) else "active",
		"level": int(r.get("level", 1)),
		"max_depth": int(r.get("max_depth", 1)),
		"lives": int(r.get("lives", RUN_LIVES)),
	}

# ── Сохранение / загрузка ────────────────────────────────────────────────────

const SAVE_PATH := "user://maze_off.cfg"

func save_game() -> void:
	# В забеге «Накал» сохраняем ТОЛЬКО слот + статистику, не трогая глобальный
	# профиль «Уровней».
	if active_run >= 0:
		_sync_live_into_run()
		_save_runs_and_stats()
		return
	var cfg := ConfigFile.new()
	cfg.load(SAVE_PATH)   # сохранить чужие секции (слоты забегов)
	cfg.set_value("progress", "level",            level)
	cfg.set_value("progress", "max_unlocked",     max_unlocked_level)
	cfg.set_value("progress", "xp",               xp)
	cfg.set_value("progress", "skill_points",     skill_points)
	cfg.set_value("progress", "enemy_encounters", enemy_encounters)
	cfg.set_value("progress", "rank_good_streak", rank_good_streak)
	cfg.set_value("progress", "rank_bad_streak",  rank_bad_streak)
	cfg.set_value("progress", "best_ranks",       level_best_ranks)
	cfg.set_value("progress", "lair_max_unlocked", lair_max_unlocked)
	cfg.set_value("settings", "show_fps", show_fps)
	cfg.set_value("settings", "test_mode", test_mode)
	cfg.set_value("settings", "difficulty", difficulty)
	cfg.set_value("settings", "beacon_pulse", beacon_pulse)
	cfg.set_value("settings", "start_hint_shown", start_hint_shown)
	cfg.set_value("settings", "help_intro_seen", help_intro_seen)
	cfg.set_value("settings", "music_volume", music_volume)
	cfg.set_value("settings", "sfx_volume", sfx_volume)
	cfg.set_value("settings", "fullscreen", fullscreen)
	cfg.set_value("settings", "vsync", vsync)
	cfg.set_value("settings", "resolution_idx", resolution_idx)
	cfg.set_value("settings", "locale", locale)
	for k in skill_uses:
		cfg.set_value("uses", k, skill_uses[k])
	for k in skills_unlocked:
		cfg.set_value("unlocked", k, skills_unlocked[k])
	for k in passives:
		cfg.set_value("passives", k, passives[k])
	_write_runs_and_stats(cfg)
	cfg.save(SAVE_PATH)

func _save_runs_and_stats() -> void:
	var cfg := ConfigFile.new()
	cfg.load(SAVE_PATH)
	_write_runs_and_stats(cfg)
	cfg.save(SAVE_PATH)

func _write_runs_and_stats(cfg: ConfigFile) -> void:
	for i in runs.size():   # включая DAILY_SLOT
		cfg.set_value("runs", "slot%d" % i, runs[i] if runs[i] != null else {})
	for k in stats:
		cfg.set_value("stats", k, stats[k])
	cfg.set_value("daily", "history", daily_history)
	cfg.set_value("vows", "done", vows_done)
	cfg.set_value("vows", "pending", vow_reward_pending)

func load_game() -> void:
	var cfg := ConfigFile.new()
	if cfg.load(SAVE_PATH) != OK:
		return
	_read_global(cfg)
	for i in runs.size():   # включая DAILY_SLOT
		var d = cfg.get_value("runs", "slot%d" % i, {})
		runs[i] = d if (d is Dictionary and d.has("level")) else null
	for k in stats.keys():
		stats[k] = cfg.get_value("stats", k, stats[k])
	level_history = cfg.get_value("history", "entries", [])
	daily_history = cfg.get_value("daily", "history", [])
	var vd = cfg.get_value("vows", "done", [false, false, false])
	vows_done = vd if (vd is Array and vd.size() == RUN_VOWS.size()) else [false, false, false]
	vow_reward_pending = int(cfg.get_value("vows", "pending", 0))
	active_run = -1

func _read_global(cfg: ConfigFile) -> void:
	level            = cfg.get_value("progress", "level",            1)
	max_unlocked_level = cfg.get_value("progress", "max_unlocked",   1)
	xp               = cfg.get_value("progress", "xp",               0)
	skill_points     = cfg.get_value("progress", "skill_points",     0)
	enemy_encounters = cfg.get_value("progress", "enemy_encounters", 0)
	rank_good_streak = int(cfg.get_value("progress", "rank_good_streak", 0))
	rank_bad_streak  = int(cfg.get_value("progress", "rank_bad_streak", 0))
	var br = cfg.get_value("progress", "best_ranks", {})
	level_best_ranks = br if br is Dictionary else {}
	lair_max_unlocked = clampi(int(cfg.get_value("progress", "lair_max_unlocked", 1)), 1, LAIR_LEVELS)
	show_fps         = cfg.get_value("settings", "show_fps", false)
	test_mode        = cfg.get_value("settings", "test_mode", false)
	beacon_pulse     = cfg.get_value("settings", "beacon_pulse", true)
	start_hint_shown = cfg.get_value("settings", "start_hint_shown", false)
	help_intro_seen  = cfg.get_value("settings", "help_intro_seen", false)
	music_volume     = clampf(float(cfg.get_value("settings", "music_volume", 0.8)), 0.0, 1.0)
	sfx_volume       = clampf(float(cfg.get_value("settings", "sfx_volume", 1.0)), 0.0, 1.0)
	fullscreen       = cfg.get_value("settings", "fullscreen", false)
	vsync            = cfg.get_value("settings", "vsync", true)
	resolution_idx   = clampi(int(cfg.get_value("settings", "resolution_idx", 1)), 0, RESOLUTIONS.size() - 1)
	var loc: String = str(cfg.get_value("settings", "locale", "ru"))
	locale = loc if loc in ["ru", "en"] else "ru"
	# Миграция старого hard_mode → difficulty=2 (однократно, при отсутствии ключа).
	var legacy_hard: bool = cfg.get_value("settings", "hard_mode", false)
	difficulty       = clampi(int(cfg.get_value("settings", "difficulty", 2 if legacy_hard else 1)), 0, 2)
	for k in skill_uses.keys():
		skill_uses[k] = cfg.get_value("uses", k, 0)
	for k in skills_unlocked.keys():
		skills_unlocked[k] = cfg.get_value("unlocked", k, skills_unlocked[k])
	for k in passives.keys():
		passives[k] = cfg.get_value("passives", k, false)

# Перечитать глобальный профиль «Уровней» в живые переменные (после забега).
func load_levels_profile() -> void:
	var cfg := ConfigFile.new()
	if cfg.load(SAVE_PATH) == OK:
		_read_global(cfg)
	# Награда за выполненный обет Накала возвращается в глобальный профиль.
	if vow_reward_pending > 0 and active_run < 0:
		skill_points += vow_reward_pending
		vow_reward_pending = 0
		save_game()

func reset_progress() -> void:
	xp = 0
	skill_points = 0
	enemy_encounters = 0
	level = 1
	max_unlocked_level = 1
	rank_good_streak = 0
	rank_bad_streak = 0
	level_best_ranks = {}
	lair_max_unlocked = 1
	for k in skill_uses.keys():
		skill_uses[k] = 0
	for k in skills_unlocked.keys():
		skills_unlocked[k] = (SKILL_COSTS.get(k, 1) == 0)
	for k in passives.keys():
		passives[k] = false
	active_run = -1
	runs = [null, null, null, null]
	vows_done = [false, false, false]
	vow_reward_pending = 0
	for k in stats.keys():
		stats[k] = 0
	level_history = []
	daily_history = []
	_save_level_history()
	save_game()
