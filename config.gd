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
var show_hints: bool           = true   # мелкие подсказки-сообщения (prio 0)
var beacon_pulse: bool         = true   # пульс-указатель от игрока к маяку
# «Эхо времени» (GAMEDESIGN.md §7) — выключено по умолчанию, включается в
# настройках (и прямо во время игры — тумблер в меню паузы). echo_trails:
# level_number -> PackedVector2Array нормализованных координат (fx=cx/cols,
# fy=cy/rows), где игрок бывал на этом же номере уровня в ПРОШЛЫЙ раз — не
# сырые координаты клетки (лабиринт каждый раз другой), а доля пути по сетке,
# поэтому осмысленно накладывается даже на новую планировку другой формы.
# Перезаписывается заходом в уровень заново (последний забег, не накопление).
var echo_time_enabled: bool    = false
var echo_trails: Dictionary    = {}
var start_hint_shown: bool     = false  # искра-подсказка к выходу уже показана на 1-м уровне (один раз)
var help_intro_seen: bool      = false  # ЛЕГАСИ: гейт новичка у прежней Справки; Кодекс (§30) его не использует, ключ живёт ради совместимости сейвов
var music_volume: float        = 0.8    # громкость музыки 0..1 (шина "Music")
var sfx_volume: float          = 1.0    # громкость звуков 0..1 (шина "SFX")
var fullscreen: bool           = false
var vsync: bool                = true
# [v5.7] Качество графики (0 низкое / 1 среднее / 2 высокое) и лимит кадров.
# Замер на Intel Arc 140V, 1920×1200 (кадр 6.0 мс без лимита): свечение ≈0.9 мс,
# тени света игрока ≈0.95 мс, остальное — затемнение и сами огни. Высокая частота
# монитора без лимита заставляла GPU рисовать 140+ кадров/с — отсюда «GPU 79%».
var quality: int                = 2
var fps_cap: int                = 60      # 0 = без лимита
const FPS_CAPS := [60, 120, 144, 0]
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
	"menu_help":     {"ru": "Кодекс",     "en": "Codex"},
	"menu_quit":     {"ru": "Выход",      "en": "Quit"},
	"subtitle":      {"ru": "лабиринт во тьме", "en": "a maze in the dark"},

	"top_shop":      {"ru": "Магазин",    "en": "Shop"},
	"top_tutorial":  {"ru": "Обучение",   "en": "Tutorial"},
	"top_journal":   {"ru": "Дневник",    "en": "Journal"},
	"top_bestiary":  {"ru": "Бестиарий",  "en": "Bestiary"},

	"mode_levels_title": {"ru": "УРОВНИ", "en": "LEVELS"},
	"mode_levels_desc":  {"ru": "Кампания: 50 уровней, прогресс и навыки — навсегда.\n\nПродолжить: уровень %d", "en": "Campaign: 50 levels, progress and skills — forever.\n\nContinue: level %d"},
	"mode_ember_title":  {"ru": "НАКАЛ", "en": "EMBER"},
	"mode_ember_desc":   {"ru": "Спуск за огнём: чем глубже, тем злее тьма.\n\n3 жизни на весь спуск. Входишь со своими навыками; каждый забег даёт очки ковки для ★3-★5 в кампании.", "en": "Descend for fire: the deeper, the darker.\n\n3 lives for the whole run. You bring your skills; every run pays forge points for ★3-★5 in the campaign."},
	"mode_daily_title":  {"ru": "СПУСК ДНЯ", "en": "DAILY DIVE"},
	"mode_daily_desc":   {"ru": "Один лабиринт на всех, одна попытка в день.", "en": "One maze for everyone, one attempt per day."},
	"mode_lair_title":   {"ru": "ЛОГОВО", "en": "LAIR"},
	"mode_lair_desc":    {"ru": "10 логов: владыка тьмы — в центре лабиринта.\n\nДойди сквозь стражу. Прогресс: %d/%d", "en": "10 lairs: a dark lord waits at the maze's center.\n\nFight through the guard. Progress: %d/%d"},
	"mode_caves_title":  {"ru": "ПЕЩЕРЫ", "en": "CAVES"},
	# [v5.5] «20», не «10»: с v4.4 CAVES_LEVELS = 20 (см. комментарий у константы).
	"mode_caves_desc":   {"ru": "20 пещер: тот же поиск выхода, но лабиринт — сеть скруглённых тоннелей, не прямых стен.\n\nПрогресс: %d/%d", "en": "20 caves: the same search for the exit, but the maze is a web of rounded tunnels, not straight walls.\n\nProgress: %d/%d"},

	"pick_level":    {"ru": "выбор уровня (%d)", "en": "pick level (%d)"},
	"difficulty":    {"ru": "Сложность:", "en": "Difficulty:"},
	"diff_low":      {"ru": "◦ Тлеющий", "en": "◦ Ember"},
	"diff_mid":      {"ru": "● Горящий", "en": "● Blaze"},
	"diff_high":     {"ru": "☀ Пылающий", "en": "☀ Inferno"},

	# [v5.5] Ключ "back" удалён: его не читал никто. Он остался от эпохи нижних
	# дублирующих кнопок «Назад», которые вычистили в правке 2026-07 (одна точка
	# возврата на экран — угловая стрелка `back_arrow`). Живой ключ ниже.
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
	"quality":         {"ru": "Качество графики", "en": "Graphics quality"},
	"fps_cap":         {"ru": "Лимит кадров", "en": "Frame rate limit"},
	"hints_opt":{"ru": "Мелкие подсказки в игре", "en": "Small in-game hints"},
	"beacon_pulse_opt":{"ru": "Пульс-указатель к маяку", "en": "Beacon direction pulse"},
	"show_fps_opt":    {"ru": "Показывать счётчик FPS", "en": "Show FPS counter"},
	"language":        {"ru": "Язык", "en": "Language"},
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
	Engine.max_fps = maxi(fps_cap, 0)
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
# [§38] id механики из LADDER -> true, если карточка «Новое: …» уже показывалась.
# Персистентно и НЕ сбрасывается забегами: подпись к механике нужна один раз за
# всё время, а не в каждом новом Накале.
var ladder_seen: Dictionary = {}

# [v5.1] Кодекс: какие статьи уже прочитаны — ключ "sec|id". Нужен, чтобы
# навигация могла показать «что ты ещё не читал», а не ровный список из 88
# пунктов (жалоба: «свалка, непонятно что читать»). Персистентно, как
# ladder_seen: прочитанное остаётся прочитанным между сессиями.
var codex_read: Dictionary = {}

# [v6.0] Кодекс открывается по мере игры (codex.gd::UNLOCK). Почти всё выводится
# из уже сохраняемого состояния (ladder_seen, skills_unlocked, stats…); сюда
# пишутся только «встречи», у которых своего следа нет (например, уровень хоть
# раз потемнел от промедления). Персистентно, как ladder_seen.
var codex_met: Dictionary = {}

# [v6.1] Статьи, о которых игроку уже сказали «Кодекс пополнился» (ключ "sec|id").
# Без этого сообщение повторялось бы при каждом запуске уровня.
var codex_notified: Dictionary = {}

func codex_announce(keys: Array) -> void:
	if test_mode:
		return
	for k in keys:
		codex_notified[str(k)] = true
	save_game()

func codex_meet(topic: String) -> void:
	if test_mode or bool(codex_met.get(topic, false)):
		return
	codex_met[topic] = true
	save_game()

# Встретил ли игрок запись лестницы: показывалась карточка «Новое: …», либо он
# сам получил навык, либо дошёл до механики в забеге. В забеге карточек нет, а
# трогать ladder_seen оттуда нельзя (это сожгло бы вводную карточку кампании), —
# поэтому глубину забега сверяем со сжатой лестницей отдельно.
func ladder_met(id: String) -> bool:
	if bool(ladder_seen.get(id, false)):
		return true
	var e := ladder_entry(id)
	if e.is_empty():
		return false
	if str(e["kind"]) == "skill":
		return bool(skills_unlocked.get(id.trim_prefix("skill_"), false))
	if LADDER_RUN_LEVEL.has(id):
		return int(stats.get("best_depth", 0)) >= int(LADDER_RUN_LEVEL[id])
	return false

func codex_is_read(key: String) -> bool:
	return bool(codex_read.get(key, false))

# Возвращает true, если статья была НЕ прочитана (вызывающий код решает,
# перерисовывать ли навигацию — значки непрочитанного меняются только тогда).
func codex_mark_read(key: String) -> bool:
	if bool(codex_read.get(key, false)):
		return false
	codex_read[key] = true
	_codex_dirty = true
	return true

# [BUGFIX v5.1.1] Отметки «прочитано» копятся в памяти и пишутся ОДНОЙ пачкой
# при уходе с экрана Кодекса, а не на каждое открытие статьи. Причина: запись
# профиля на каждый клик — и лишние обращения к диску, и большая площадь
# поражения (харнесс, прошедший все 88 статей, дважды записал игроку весь
# Кодекс как прочитанный). Одна запись за визит вместо восьмидесяти восьми.
var _codex_dirty: bool = false

func codex_flush() -> void:
	if not _codex_dirty:
		return
	_codex_dirty = false
	if not test_mode:
		save_game()

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
const MODE_UNLOCK_CAVES := 16   # открыт после прохождения уровня 15 — между Накалом и Логовом

func is_daily_unlocked() -> bool:
	return max_unlocked_level >= MODE_UNLOCK_DAILY
func is_ember_unlocked() -> bool:
	return max_unlocked_level >= MODE_UNLOCK_EMBER
func is_lair_unlocked() -> bool:
	return max_unlocked_level >= MODE_UNLOCK_LAIR
func is_caves_unlocked() -> bool:
	return max_unlocked_level >= MODE_UNLOCK_CAVES

# ══ ЛЕСТНИЦА ОТКРЫТИЙ (GAMEDESIGN §38) ══════════════════════════════════════
# ЕДИНЫЙ реестр того, на каком уровне игра вводит очередную механику. До 1.18
# пороги жили россыпью констант *_FROM_LEVEL в main.gd плюс безымянные
# «_level >= 25» по коду: их порядок никто не держал в голове, они не совпадали
# с темами биомов (Шахты на уровнях 1-5 ОБЕЩАЛИ порталы-срезки, а гейт стоял на
# 8; Недра 6-10 обещали провалы при гейте 15), и ни одна механика не
# представлялась игроку — она просто однажды появлялась. Отсюда «непонятно,
# откуда что произрастает».
#
# Правила реестра:
#   • Порог механики лежит ВНУТРИ полосы того биома, который ею владеет
#     (BIOMES[..].rules в main.gd, BIOME_SPAN = 5): биом не может обещать то,
#     чего ещё нет. Проверяется харнессом — см. GAMEDESIGN §38.
#   • На уровне открытия игрок получает карточку «Новое: …» ОДИН раз за всё
#     время (ladder_seen), с одной строкой «что это» — не туториал, а подпись.
#   • kind: "core" — базис, "mech" — механика мира, "foe" — новый враг,
#     "mode" — режим (тост шлёт _announce_mode_unlocks, карточка не дублирует).
# Порядок массива = порядок показа в меню; поле level — единственный источник
# правды для гейтов в main.gd (см. _mech_from / _mech_ready).
const LADDER := [
	{"id": "core", "level": 1, "kind": "core", "color": Color(0.55, 0.90, 1.00),
	 "name": "Осколки и Выход", "name_en": "Shards and the Exit",
	 "what": "Найди выход и уйди в него. Ты видишь ДАЛЬШЕ ТУДА, КУДА ИДЁШЬ: свет вытянут лучом по направлению движения, а по бокам темнее. У этажа есть АРТЕРИЯ — сквозной коридор с тусклой разметкой, и ЗАЛЫ на ней: столпы света, видные издалека. Станции восполняют Свет и ставят точку возврата.",
	 "what_en": "Find the exit and step through. You see FURTHER WHERE YOU ARE HEADING: your light stretches into a beam along your movement, and the flanks stay darker. Every floor has an ARTERY — a through-corridor with dim floor marks — and HALLS along it: pillars of light visible from afar. Stations refill Light and set your checkpoint."},
	{"id": "draft", "level": 1, "kind": "mech", "color": Color(0.72, 0.88, 1.00),
	 "name": "Тяга воздуха", "name_en": "The Draft",
	 "what": "Выход открыт наружу, и к нему тянет сквозняк. ОСТАНОВИСЬ — и увидишь, как пылинки плывут по тяге. Чем ближе выход, тем сильнее и чётче поток; издалека он слабый и путаный. В Тусклой стойке чувствуешь лучше, в Яркой свет сбивает поток. Это бесплатная подсказка, но не ответ: точное место выхода по-прежнему дают осколки.",
	 "what_en": "The exit opens outward, and a draft pulls toward it. STAND STILL and you'll see motes drifting along the flow. The closer the exit, the stronger and sharper the current; from afar it's faint and confused. The Dim stance feels it best, a Bright one stirs the air. A free hint, not an answer: shards still give the exact spot."},
	{"id": "claim", "level": 2, "kind": "mech", "color": Color(1.00, 0.78, 0.42),
	 "name": "Захваченная земля", "name_en": "Held Ground",
	 "what": "Пройденные клетки остаются тлеть — это твоя земля, и на ней Свет тратится медленнее. Тьма отвоёвывает её обратно тем быстрее, чем ярче ты горишь. Тление держит тыл дольше всего.",
	 "what_en": "The cells you walk stay smouldering — that ground is yours, and Light drains slower on it. The dark takes it back faster the brighter you burn. Smother holds your rear the longest."},
	{"id": "stance", "level": 2, "kind": "mech", "color": Color(1.00, 0.85, 0.40),
	 "name": "Стойки света", "name_en": "Light Stances",
	 "what": "Свет можно держать ярче или тусклее — Z / X или колесо мыши. Яркий: видишь дальше, но горишь быстрее и тебя видно издалека. Тусклый: экономишь Свет и прячешься, но идёшь почти вслепую. Полоска рядом с Светом показывает текущую стойку.",
	 "what_en": "You can hold your light brighter or dimmer — Z / X or the mouse wheel. Bright: see farther, but burn faster and be seen from afar. Dim: save Light and hide, but walk near-blind. The strip next to Light shows your stance."},
	{"id": "skill_dash", "level": 3, "kind": "skill", "color": Color(1.00, 0.86, 0.45),
	 "name": "Реликвия: Рывок", "name_en": "Relic: Dash",
	 "what": "В лабиринте ждёт РЕЛИКВИЯ — навык «Рывок» (Shift или Пробел). Короткий бросок вперёд: уйти от погони или перескочить яму. Она лежит в тупике недалеко от пути. Не нашёл — получишь её у выхода.",
	 "what_en": "A RELIC waits in the maze — the skill «Dash» (Shift or Space). A short burst forward: shake a chaser or clear a pit. It lies in a dead end near your path. Miss it and you get it at the exit."},
	{"id": "shortcut", "level": 4, "kind": "mech", "color": Color(0.30, 0.80, 1.00),
	 "name": "Порталы-срезки", "name_en": "Shortcut Portals",
	 "what": "Парные порталы Лазурных шахт: вход выкидывает к далёкому выходу. Тема шахт — маршрут важнее скорости.",
	 "what_en": "Paired portals of the Azure Mines: step in, come out far away. The mines' theme — route beats speed."},
	{"id": "boss_door", "level": 5, "kind": "mech", "color": Color(1.00, 0.30, 0.35),
	 "name": "Дверь Ядра", "name_en": "The Core's Door",
	 "what": "Каждый 5-й уровень — багровый череп-портал. Входить необязательно, но победа над Ядром даёт ДАР: навык, который нельзя купить.",
	 "what_en": "Every 5th level shows a crimson skull portal. Entering is optional, but beating the Core grants a GIFT: a skill money can't buy."},
	{"id": "mode_daily", "level": MODE_UNLOCK_DAILY, "kind": "mode", "color": Color(1.00, 0.85, 0.35),
	 "name": "Режим «Спуск дня»", "name_en": "«Daily Dive» mode",
	 "what": "Один лабиринт на всех, одна попытка в день.",
	 "what_en": "One maze for everyone, one attempt a day."},
	{"id": "skill_smother", "level": 6, "kind": "skill", "color": Color(1.00, 0.86, 0.45),
	 "name": "Реликвия: Тление", "name_en": "Relic: Smother",
	 "what": "В лабиринте ждёт РЕЛИКВИЯ — навык «Тление» (R). Свет гаснет до искры, ты почти невидим для врагов — цена: медленнее шаг. Она лежит в тупике недалеко от пути. Не нашёл — получишь её у выхода.",
	 "what_en": "A RELIC waits in the maze — the skill «Smother» (R). Your light dims to a spark and enemies lose you — at the cost of a slower step. It lies in a dead end near your path. Miss it and you get it at the exit."},
	{"id": "pits", "level": 7, "kind": "mech", "color": Color(1.00, 0.45, 0.20),
	 "name": "Провалы", "name_en": "Chasms",
	 "what": "Тема Багровых недр: разлом не обойти и не перешагнуть — только Рывком. Рывок перестаёт быть кнопкой «убежать».",
	 "what_en": "The Crimson Depths' theme: a chasm can't be walked around — only dashed. Dash stops being the «run away» button."},
	{"id": "herder", "level": 8, "kind": "foe", "color": Color(1.00, 0.35, 0.45),
	 "name": "Загонщик", "name_en": "The Herder",
	 "what": "Один враг за уровень получает роль: он не бежит по кратчайшему пути, а перекрывает твой — гонит в тупик. Заметен по обходу.",
	 "what_en": "One enemy per level takes the role: it doesn't take the shortest path to you, it cuts off yours — herding you into a dead end."},
	{"id": "skill_sonar", "level": 9, "kind": "skill", "color": Color(1.00, 0.86, 0.45),
	 "name": "Реликвия: Сонар", "name_en": "Relic: Sonar",
	 "what": "В лабиринте ждёт РЕЛИКВИЯ — навык «Сонар» (E). Волна показывает стены и врагов вокруг, даже во тьме. Она лежит в тупике недалеко от пути. Не нашёл — получишь её у выхода.",
	 "what_en": "A RELIC waits in the maze — the skill «Sonar» (E). A wave shows walls and enemies around you, even in the dark. It lies in a dead end near your path. Miss it and you get it at the exit."},
	{"id": "events", "level": 10, "kind": "mech", "color": Color(0.70, 0.60, 1.00),
	 "name": "Дыхание лабиринта", "name_en": "The Maze Breathes",
	 "what": "Лабиринт вмешивается сам: толчки, туман, утечка света, мерцание. Перед событием всегда есть предвестник — успей среагировать.",
	 "what_en": "The maze intervenes on its own: quakes, fog, light leaks, flicker. Every event has a warning cue — react in time."},
	{"id": "mode_ember", "level": MODE_UNLOCK_EMBER, "kind": "mode", "color": Color(1.00, 0.55, 0.25),
	 "name": "Режим «Накал»", "name_en": "«Ember» mode",
	 "what": "Спуск за огнём: 3 жизни на весь забег, несомый Накал — ставка, которую можно потерять или забанкать.",
	 "what_en": "A descent for fire: 3 lives for the whole run, carried Ember is a stake you can lose or bank."},
	{"id": "dark_stations", "level": 11, "kind": "mech", "color": Color(0.55, 1.00, 0.30),
	 "name": "Тёмные станции", "name_en": "Dark Stations",
	 "what": "Тема Споровых пустот: воронка, внешне похожая на станцию, но пьющая твой Свет. Здесь Тление важнее скорости.",
	 "what_en": "The Spore Wastes' theme: a funnel that looks like a station but drinks your Light. Here dimming beats speed."},
	{"id": "skill_shield", "level": 12, "kind": "skill", "color": Color(1.00, 0.86, 0.45),
	 "name": "Реликвия: Щит", "name_en": "Relic: Shield",
	 "what": "В лабиринте ждёт РЕЛИКВИЯ — навык «Щит» (C). Щит гасит один удар. С Вспышкой — оглушённые враги получают урон. Она лежит в тупике недалеко от пути. Не нашёл — получишь её у выхода.",
	 "what_en": "A RELIC waits in the maze — the skill «Shield» (C). A shield absorbs one hit. Combined with Flash, stunned enemies take damage. It lies in a dead end near your path. Miss it and you get it at the exit."},
	{"id": "locked_doors", "level": 14, "kind": "mech", "color": Color(1.00, 0.55, 0.30),
	 "name": "Запертые двери", "name_en": "Locked Doors",
	 "what": "На этаже появляется вторая пара дверей — запертая, с замком. Она короче обычной, и открывает её собранный осколок-ключ. Обычная дверь остаётся открытой всегда: запертая — это выбор, а не преграда.",
	 "what_en": "A second door pair appears on the floor — locked, marked with a padlock. It is the shorter way down, and a collected shard-key opens it. The ordinary door always stays open: the locked one is a choice, not an obstacle."},
	{"id": "mode_caves", "level": MODE_UNLOCK_CAVES, "kind": "mode", "color": Color(0.55, 0.42, 0.30),
	 "name": "Режим «Пещеры»", "name_en": "«Caves» mode",
	 "what": "20 пещер: тот же поиск выхода, но лабиринт — сеть скруглённых тоннелей, а не прямых стен.",
	 "what_en": "20 caves: the same search for the exit, but the maze is a web of rounded tunnels, not straight walls."},
	{"id": "skill_mark", "level": 16, "kind": "skill", "color": Color(1.00, 0.86, 0.45),
	 "name": "Реликвия: Метка", "name_en": "Relic: Mark",
	 "what": "В лабиринте ждёт РЕЛИКВИЯ — навык «Метка» (M). Удерживает клетку под ногами 45 секунд: тьма не отвоюет её обратно. Она лежит в тупике недалеко от пути. Не нашёл — получишь её у выхода.",
	 "what_en": "A RELIC waits in the maze — the skill «Mark» (M). Pins the cell under you for 45 seconds: the dark cannot take it back. It lies in a dead end near your path. Miss it and you get it at the exit."},
	{"id": "mimics", "level": 17, "kind": "foe", "color": Color(0.30, 0.85, 1.00),
	 "name": "Мимики", "name_en": "Mimics",
	 "what": "Шахты научились подделывать станцию. Пятнадцать уровней ты доверял им не глядя — с этого момента проверяй.",
	 "what_en": "The mines learned to fake a station. For fifteen levels you trusted them blindly — from now on, check."},
	{"id": "guests", "level": 18, "kind": "mech", "color": Color(1.00, 0.85, 0.35),
	 "name": "Гости лабиринта", "name_en": "Maze Guests",
	 "what": "Не всё во тьме — враг: беглец даёт награду за поимку, огонёк отвлекает погоню, кроты роют под полом, вор крадёт твой свет.",
	 "what_en": "Not everything in the dark is a foe: a runner rewards the catch, a wisp distracts chasers, moles dig below, a thief steals your light."},
	{"id": "skill_guide", "level": 19, "kind": "skill", "color": Color(1.00, 0.86, 0.45),
	 "name": "Реликвия: Искра", "name_en": "Relic: Spark",
	 "what": "В лабиринте ждёт РЕЛИКВИЯ — навык «Искра» (G). Летящая искра ведёт к выходу — когда ты уже знаешь, где он. Она лежит в тупике недалеко от пути. Не нашёл — получишь её у выхода.",
	 "what_en": "A RELIC waits in the maze — the skill «Spark» (G). A spark drifts toward the exit — once you know where it is. It lies in a dead end near your path. Miss it and you get it at the exit."},
	{"id": "hearth", "level": 20, "kind": "mech", "color": Color(1.00, 0.72, 0.35),
	 "name": "Тлеющий очаг", "name_en": "The Smouldering Hearth",
	 "what": "Держи одну клетку своей подольше, не отпуская, — и она может отдариться каплей Воли. Симметрия Соглядатаю (появится позже): земля помнит и заботу, не только небрежность.",
	 "what_en": "Hold one cell as yours for a while without letting go, and it may gift you a drop of Will. The mirror of the Onlooker (comes later): the ground remembers care, not just carelessness."},
	{"id": "event_rooms", "level": 21, "kind": "mech", "color": Color(0.95, 0.75, 0.30),
	 "name": "Событийные комнаты", "name_en": "Event Rooms",
	 "what": "Комната с характером: алтарь осколков, ловушка тьмы, комната выбора, эхо, паразит. Предвестник — золотистое мерцание за несколько клеток.",
	 "what_en": "A room with a character: shard altar, dark trap, choice room, echo, parasite. The cue is a golden shimmer a few cells ahead."},
	{"id": "mode_lair", "level": MODE_UNLOCK_LAIR, "kind": "mode", "color": Color(1.00, 0.30, 0.35),
	 "name": "Режим «Логово»", "name_en": "«Lair» mode",
	 "what": "10 уровней, владыка тьмы в тронном зале в центре лабиринта.",
	 "what_en": "10 levels, a dark lord in the throne room at the maze's heart."},
	{"id": "skill_reveal", "level": 22, "kind": "skill", "color": Color(1.00, 0.86, 0.45),
	 "name": "Реликвия: Озарение", "name_en": "Relic: Revelation",
	 "what": "В лабиринте ждёт РЕЛИКВИЯ — навык «Озарение» (F). Копит заряд и одним разом открывает большой круг вокруг. Она лежит в тупике недалеко от пути. Не нашёл — получишь её у выхода.",
	 "what_en": "A RELIC waits in the maze — the skill «Revelation» (F). Builds a charge, then reveals a wide circle around you in one go. It lies in a dead end near your path. Miss it and you get it at the exit."},
	{"id": "watcher", "level": 23, "kind": "foe", "color": Color(0.55, 0.35, 0.78),
	 "name": "Соглядатай", "name_en": "The Onlooker",
	 "what": "Брось разом слишком много своей земли тьме — и на месте потери может остаться неподвижный наблюдатель. Он не бродит и не гонится, пока не увидит тебя напрямую. Метка (M) не даёт клетке вообще перейти в разряд потерянных.",
	 "what_en": "Abandon too much of your ground to the dark at once, and a motionless watcher may be left where it was lost. It doesn't wander or give chase until it sees you directly. A Mark (M) keeps a cell from ever entering the «lost» state at all."},
	{"id": "zone_markers", "level": 24, "kind": "mech", "color": Color(0.40, 1.00, 0.80),
	 "name": "Метки зон", "name_en": "Zone Markers",
	 "what": "Светящиеся отметки на полу делят этаж на зоны — по ним понятно, где ты уже был.",
	 "what_en": "Glowing floor marks split the floor into zones — they tell you where you've already been."},
	{"id": "skill_pulse", "level": 26, "kind": "skill", "color": Color(1.00, 0.86, 0.45),
	 "name": "Реликвия: Пульс", "name_en": "Relic: Pulse",
	 "what": "В лабиринте ждёт РЕЛИКВИЯ — навык «Пульс» (B). Волна показывает направление к выходу. Она лежит в тупике недалеко от пути. Не нашёл — получишь её у выхода.",
	 "what_en": "A RELIC waits in the maze — the skill «Pulse» (B). A wave shows the direction to the exit. It lies in a dead end near your path. Miss it and you get it at the exit."},
	{"id": "elite_guard", "level": 27, "kind": "foe", "color": Color(1.00, 0.80, 0.30),
	 "name": "СТРАЖ", "name_en": "SENTINEL",
	 "what": "Элита: 6 HP и обзор ×1.4. Не убивается наскоком — либо заморозить и добить, либо обойти вовсе.",
	 "what_en": "Elite: 6 HP, sight ×1.4. Won't fall to a rush — freeze it and finish it, or avoid it entirely."},
	{"id": "mega_maze", "level": 30, "kind": "mech", "color": Color(0.60, 0.70, 1.00),
	 "name": "Мега-лабиринт", "name_en": "Mega-maze",
	 "what": "Потолки размера и этажей подняты, вход больше не в углу — теперь ты начинаешь где угодно и ориентируешься сам.",
	 "what_en": "Size and floor caps rise, and the entry is no longer the corner — you start anywhere and orient yourself."},
	{"id": "elite_phantom", "level": 33, "kind": "foe", "color": Color(0.85, 0.55, 1.00),
	 "name": "ФАНТОМ", "name_en": "PHANTOM",
	 "what": "1 HP, но скорость 1.3 — обгоняет тебя. Умирает от чего угодно, если успеешь попасть.",
	 "what_en": "1 HP but speed 1.3 — it outruns you. Dies to anything, if you can land a hit."},
	{"id": "elite_leech", "level": 37, "kind": "foe", "color": Color(0.40, 1.00, 0.60),
	 "name": "ПИЯВКА", "name_en": "LEECH",
	 "what": "Касание тянет не Свет, а ВОЛЮ — ресурс навыков. Пиявка не убивает, она тебя обезоруживает.",
	 "what_en": "Its touch drains not Light but WILL — your skill resource. A leech doesn't kill you, it disarms you."},
]

# [v5.7, §77] Накал и Спуск дня начинаются «с нуля» и идут по СЖАТОЙ лестнице
# (уровни кампании до v5.7). Растянутая лестница кампании (LADDER выше) нужна,
# чтобы новичок узнавал по одному понятию за раз; забег же открывают те, кто
# кампанию уже прошёл до 10-го уровня, и пустые первые глубины им ни к чему.
const LADDER_RUN_LEVEL := {
	"draft": 1,
	"events": 2,
	"claim": 2,
	"zone_markers": 3,
	"shortcut": 3,
	"locked_doors": 4,
	"guests": 4,
	"boss_door": 5,
	"pits": 6,
	"hearth": 7,
	"herder": 8,
	"event_rooms": 9,
	"dark_stations": 11,
	"watcher": 14,
	"mimics": 16,
	"elite_guard": 25,
	"mega_maze": 30,
	"elite_phantom": 30,
	"elite_leech": 35,
}

# Уровень открытия записи с учётом режима: в забеге — сжатая лестница, а
# записи-реликвии (kind "skill") в забеге не существуют вовсе (-1).
func _ladder_lvl(e: Dictionary) -> int:
	if active_run >= 0:
		if str(e["kind"]) == "skill":
			return -1
		return int(LADDER_RUN_LEVEL.get(str(e["id"]), int(e["level"])))
	return int(e["level"])

# Уровень открытия механики. -1 = такого id в реестре нет (опечатка в вызове).
func ladder_level(id: String) -> int:
	for e in LADDER:
		if str(e["id"]) == id:
			return _ladder_lvl(e)
	push_warning("ladder_level: неизвестный id «%s»" % id)
	return -1

func ladder_entry(id: String) -> Dictionary:
	for e in LADDER:
		if str(e["id"]) == id:
			return e
	return {}

# Механики, которые открываются ИМЕННО на этом уровне и ещё не показывались.
func ladder_new_at(lvl: int) -> Array:
	var out: Array = []
	for e in LADDER:
		if _ladder_lvl(e) == lvl and str(e["kind"]) != "mode" \
				and not bool(ladder_seen.get(str(e["id"]), false)):
			out.append(e)
	return out

func ladder_mark_seen(id: String) -> void:
	if test_mode:
		return
	ladder_seen[id] = true

# Открыта ли механика к уровню lvl (для гейтов в main.gd и списка в меню).
func ladder_ready(id: String, lvl: int) -> bool:
	var l := ladder_level(id)
	return l >= 0 and lvl >= l

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
# [v6.3, §84] Обучение — УРОКИ по одному понятию (tutorial_lessons.gd): каждый —
# короткий мини-лабиринт со своим выходом. tutorial_lesson — какой урок идёт
# сейчас (транзиентно, как и tutorial_mode; main.gd::_restart() перечитывает его
# на каждом переходе между уроками), tutorial_done — какие пройдены ("0".."11" ->
# true, персистентно: список уроков в меню ставит галочки).
var tutorial_lesson: int = 0
var tutorial_done: Dictionary = {}
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

# ── Пещеры (v4.0, §60): обычный find-the-exit, пол organic_floor.gd ──────────
# Отдельный режим, а не правка «Уровней» — те же транзиентные/персистентные
# правила, что у Логова выше: caves_mode/caves_level не сохраняются, прогресс
# (caves_max_unlocked) сохраняется.
var caves_mode: bool = false
var caves_level: int = 1
var caves_max_unlocked: int = 1
# [v4.4] Было 10. Расширено вдвое по просьбе игрока («больше уровней в
# Пещерах»). Число НЕ автономно: от него считаются ширина биом-полосы Пещер
# (main.gd::_biome_of_level_mode — ceili(CAVES_LEVELS / BIOMES.size())) и,
# следом за ней, пороги механик CAVES_MECH_LEVEL_OVERRIDE. Меняя это число,
# проверь оба места — иначе биом снова начнёт обещать механику, которой в
# нём нет (та же поломка, что чинилась в v4.3).
#
# [v5.5] И ТРЕТЬЕ место — ПРОЗА. Число повторено словами там, где подставить
# константу нельзя (константное выражение GDScript не умеет "%d" % CONST):
# ключ локализации `mode_caves_desc` и запись `mode_caves` в LADDER. В v4.4
# их забыли, и полтора месяца карточка режима обещала «10 пещер», когда их
# было 20. Правило §38 «числа, повторённые в прозе, обновляются вместе с
# реестром» — при следующей смене грепни строку «пещер»/«caves» целиком.
const CAVES_LEVELS := 20

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
	cfg.load(_save_path())
	cfg.set_value("history", "entries", level_history)
	cfg.save(_save_path())

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
	"mirror_ally": 0,   # мастерство навыка призыва (§25) — та же 0..5★ шкала, что у остальных
	# [BUGFIX v3.6] "mark" (§52, v3.3) не был здесь предобъявлен — add_skill_use()
	# молча не срабатывает на неизвестном ключе (`if skill_uses.has(skill): ...`,
	# ниже), так что применения Метки никогда не считались, мастерство не росло,
	# и шаг обучения про неё (§56) не мог бы завершиться в принципе.
	"mark": 0,
}

const MASTERY_PER_LEVEL := 10
const MASTERY_MAX := 5

# ── Мастерство: три источника (v5.8, §79) ─────────────────────────────────────
# ★ = базовые (от применений и SP; в кампании потолок CAMPAIGN_MASTERY_CAP) +
# КОВКА (постоянная, только из Накала) + звёзды забега (временные, реликвии и
# алтарь Накала). Итог не выше MASTERY_MAX. Смысл: кампания даёт ★1-★2, а
# упёршийся в её сложность идёт в Накал за ★3-★5 — Накал стал необходимой
# частью прогрессии, а не ещё одним режимом рядом.
const CAMPAIGN_MASTERY_CAP := 2
const FORGE_COST := {3: 4, 4: 6, 5: 9}   # очков ковки, чтобы получить ★N
var forge_pts: int = 0                   # очки ковки: даёт Накал по глубине
var forge_stars: Dictionary = {}         # навык -> 0..3 постоянных звезды
var relic_stars: Dictionary = {}         # навык -> временные звёзды ЭТОГО забега
var last_forge_gain: int = 0             # сколько очков дал последний забег (для экрана)

func base_mastery(skill: String) -> int:
	var m: int = mini(skill_uses.get(skill, 0) / MASTERY_PER_LEVEL, MASTERY_MAX)
	if active_run < 0:
		m = mini(m, CAMPAIGN_MASTERY_CAP)
	return m

func mastery(skill: String) -> int:
	return mini(base_mastery(skill) + int(forge_stars.get(skill, 0)) + int(relic_stars.get(skill, 0)), MASTERY_MAX)

# Очки ковки за забег: глубина минус вводные два этажа. Глубина 10 ≈ 8 очков ≈
# одна-две звезды; полная ковка одного навыка (4+6+9=19) — два-три хороших забега.
func forge_gain_for_depth(depth: int) -> int:
	return maxi(depth - 2, 0)

func forge_next_cost(skill: String) -> int:
	var nxt: int = CAMPAIGN_MASTERY_CAP + 1 + int(forge_stars.get(skill, 0))
	return int(FORGE_COST.get(nxt, -1))   # -1: навык уже на пределе

func can_forge(skill: String) -> bool:
	if active_run >= 0 or not skills_unlocked.get(skill, false) or not skill_uses.has(skill):
		return false
	if base_mastery(skill) < CAMPAIGN_MASTERY_CAP:
		return false   # сперва доведи базу до ★2 применением или за SP
	var c := forge_next_cost(skill)
	return c > 0 and forge_pts >= c

func forge_skill(skill: String) -> bool:
	if not can_forge(skill):
		return false
	forge_pts -= forge_next_cost(skill)
	forge_stars[skill] = int(forge_stars.get(skill, 0)) + 1
	_try_unlock_apex()
	if not test_mode:
		save_game()
	return true

# Временная звезда забега (реликвия глубины или алтарь). false — уже ★5.
func add_relic_star(skill: String) -> bool:
	if active_run < 0 or mastery(skill) >= MASTERY_MAX:
		return false
	relic_stars[skill] = int(relic_stars.get(skill, 0)) + 1
	return true

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
	if _try_unlock_apex() and not test_mode:
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
const APEX_CAMPAIGN_MIN_SKILLS := 5
func _owned_active_count() -> int:
	var n := 0
	for k in ["flash", "dash", "sonar", "shield", "guide", "reveal", "pulse"]:
		if skills_unlocked.get(k, false):
			n += 1
	return n
func apex_ready() -> bool:
	# [v5.7] В кампании Апекс растёт вместе с реликвиями: открывается на
	# пятом из семи активных навыков (Искра, уровень 19) — и с этого момента
	# каждая следующая реликвия добавляет в колесо новую форму. Условие
	# «★5 + четыре навыка» осталось только забегам, где навыки покупают.
	if active_run < 0:
		return _owned_active_count() >= APEX_CAMPAIGN_MIN_SKILLS
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
# true = навык открыт. С v5.7 в «Уровнях» с самого начала открыта ТОЛЬКО
# Вспышка: остальные приходят реликвиями по SKILL_RELICS (см. ниже). Старые
# профили хранят все ключи в сейве, так что они ничего не теряют.
var skills_unlocked := {
	"flash":    true,
	"dash":     false,  # реликвия, уровень 3 (LADDER «skill_dash»)
	"smother":  false,  # реликвия, уровень 6
	"mark":     false,  # реликвия, уровень 16 («Метка» M, платит Светом, не Волей)
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

# ── Реликвии (v5.7, §77) ───────────────────────────────────────────────────
# Навыки кампании открываются НАХОДКОЙ, а не покупкой и не вехой: на уровне
# из LADDER (`skill_<id>`) в лабиринте лежит реликвия, а если игрок прошёл
# уровень мимо неё — навык выдаётся у выхода. Порядок и шаг (≈3 уровня)
# записаны в LADDER; здесь только «что выдаётся первым».
const START_SKILLS := ["flash"]
const RELIC_ORDER := ["dash", "smother", "sonar", "shield", "mark", "guide", "reveal", "pulse"]

func relic_level(skill: String) -> int:
	return ladder_level("skill_" + skill)

# Навык, положенный игроку на уровне lvl: самый ранний ещё не открытый из тех,
# чей уровень уже наступил. Так пропущенная реликвия не теряется — она ждёт
# на следующем уровне (гарантия «нельзя застрять без навыка»).
func relic_due(lvl: int) -> String:
	if active_run >= 0 or tutorial_mode:
		return ""
	for id in RELIC_ORDER:
		var l := relic_level(id)
		if l >= 0 and lvl >= l and not skills_unlocked.get(id, false):
			return id
	return ""

# Навык кампании, который нельзя купить за SP — только найти.
func is_relic_skill(skill: String) -> bool:
	return RELIC_ORDER.has(skill)

# Стоимость открытия (SP). Бесплатные навыки открыты с начала.
# Цены РАЗНЫЕ: лесенка sonar→reveal — чем сильнее навык, тем дороже вход.
const SKILL_COSTS := {
	"flash": 0,  "dash": 0, "smother": 0, "mark": 0,
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

# ── Навыки призыва (GAMEDESIGN.md §25) — ОТДЕЛЬНАЯ система от обычных
# активных навыков/Апекса (решено в обсуждении: «не трогает уже
# сбалансированное колесо Апекса»). Открывается только после победы над
# супербоссом (superboss_defeated), своя маленькая витрина в skills_menu.gd,
# свой список — не смешивается с skills_unlocked/SKILL_COSTS выше.
var superboss_defeated: bool = false
# Открывает витрину «Навыки призыва» — решили открывать раньше, чем супербосс
# (уровень 50), после первой победы над ОБЫЧНОЙ дверь-боссом (☠, уровни кратные
# 5, main.gd::_boss_victory) — раньше открытие висело на superboss_defeated,
# а значит навык был почти бесполезен: доступен только на переигровке
# финального уровня (GAMEDESIGN.md §25 «остаётся решить»).
var door_boss_defeated: bool = false
var summon_unlocked := {
	"mirror_ally": false,   # призыв зеркального союзника (ally.gd) — N
}
const SUMMON_COSTS := {
	"mirror_ally": 3,
}

func summon_upgrade_cost(id: String) -> int:
	return maxi(int(SUMMON_COSTS.get(id, 4)), 2) + mastery(id)

# Усиление уже открытого навыка призыва — тот же принцип, что у try_buy_skill
# для обычных навыков (+1★ мастерства за SP, до потолка), но отдельной веткой,
# т.к. навыки призыва живут в своём словаре summon_unlocked, не skills_unlocked.
func try_upgrade_summon(id: String) -> bool:
	if not summon_unlocked.get(id, false):
		return false
	if not skill_uses.has(id) or mastery(id) >= MASTERY_MAX:
		return false
	var cost: int = summon_upgrade_cost(id)
	if skill_points < cost:
		return false
	skill_points -= cost
	skill_uses[id] += MASTERY_PER_LEVEL
	# [SAVE-SAFETY] см. CLAUDE.md, инцидент 2026-07-06 / try_buy_skill выше.
	if not test_mode:
		save_game()
	return true

# ── Lifecycle ────────────────────────────────────────────────────────────────

func _ready() -> void:
	_ensure_profiles()
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
# [v5.7] Вехи-достижения больше НЕ открывают навыки кампании: их место занял
# понятный порядок реликвий (RELIC_ORDER, LADDER «skill_*»). Словарь оставлен
# пустым, а не удалён, — на него смотрят Дневник и меню навыков, и пустой он
# ничего не показывает. Сюда можно вернуть веху для НЕ-реликвийного навыка.
const SKILL_MILESTONES := {}

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
		# [v5.8] В кампании SP усиливают только до ★2; выше — ковка из Накала.
		if active_run < 0 and base_mastery(skill) >= CAMPAIGN_MASTERY_CAP:
			return false
		var up_cost: int = upgrade_cost(skill)
		if skill_points < up_cost:
			return false
		skill_points -= up_cost
		skill_uses[skill] += MASTERY_PER_LEVEL
		# Усиление за SP тоже может сразу довести навык до ★5 — тот самый
		# досрочный путь к Апексу (см. apex_ready), а не только «купи все 7».
		_try_unlock_apex()
		# [SAVE-SAFETY] см. CLAUDE.md, инцидент 2026-07-06 — save_game() писал
		# безусловно даже с test_mode включённым (реальный инцидент: harness с
		# test_mode=true всё равно затирал настоящий сейв через эту функцию).
		if not test_mode:
			save_game()
		return true
	# [v5.7] В кампании навык из реликвий за SP не открывается — только усиление.
	if active_run < 0 and is_relic_skill(skill):
		return false
	var cost: int = SKILL_COSTS.get(skill, 999)
	if skill_points < cost:
		return false
	skill_points -= cost
	skills_unlocked[skill] = true
	# Все 7 активных навыков (или досрочное условие апекса) — открываем Апекс.
	_try_unlock_apex()
	if not test_mode:
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
		"relic_stars": {},    # временные звёзды навыков ЭТОГО забега (реликвии, алтарь)
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
	relic_stars = (r.get("relic_stars", {}) as Dictionary).duplicate()
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
	r["relic_stars"] = relic_stars.duplicate()
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
		# [v5.8] Накал входит с навыками, открытыми в кампании (на ★0 своего
		# забега). «Спуск дня» остаётся «с нуля»: лабиринт у всех один, и старт
		# обязан быть равным.
		for k in skills_unlocked.keys():
			if bool(skills_unlocked[k]):
				runs[slot]["skills"][k] = true
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
	# [v5.8] Ковка: забег платит очками по глубине — постоянная валюта ★3-★5.
	last_forge_gain = 0
	if not was_daily and not test_mode:
		last_forge_gain = forge_gain_for_depth(int(r.get("max_depth", 1)))
		forge_pts += last_forge_gain
		save_game()

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

# ── Профили игроков (v1.9) ───────────────────────────────────────────────────
# Несколько игроков на одной машине, каждый — полностью отдельный сейв-файл
# (прогресс И настройки — как отдельная «учётка», не общий профиль с разными
# табличками очков). Список профилей и путь к файлу каждого лежат в отдельном
# маленьком файле PROFILES_META_PATH, сам прогресс — как и раньше, в
# ConfigFile по адресу _save_path().
#
# МИГРАЦИЯ УЖЕ СУЩЕСТВУЮЩЕГО СОХРАНЕНИЯ: первый профиль ("Игрок 1") получает
# путь = СТАРЫЙ LEGACY_SAVE_PATH напрямую, без копирования файла — так
# реальный прогресс игрока, накопленный до v1.9, не может быть потерян или
# рассинхронизирован при миграции (см. CLAUDE.md — инцидент 2026-07-06 с
# потерей сейва, здесь та же осторожность).
const PROFILES_META_PATH := "user://profiles.cfg"
const LEGACY_SAVE_PATH := "user://maze_off.cfg"

var profile_name: String = ""
var profile_list: Array = []
var _profile_paths: Dictionary = {}   # имя профиля -> путь к его save-файлу

func _save_path() -> String:
	return str(_profile_paths.get(profile_name, LEGACY_SAVE_PATH))

func _ensure_profiles() -> void:
	var meta := ConfigFile.new()
	if meta.load(PROFILES_META_PATH) == OK:
		var lst = meta.get_value("meta", "list", [])
		profile_list = lst if lst is Array else []
		var paths = meta.get_value("paths", "map", {})
		_profile_paths = paths if paths is Dictionary else {}
		profile_name = str(meta.get_value("meta", "active", ""))
		if profile_name == "" or not (profile_name in profile_list):
			profile_name = profile_list[0] if profile_list.size() > 0 else ""
	if profile_list.is_empty():
		var default_name := "Игрок 1"
		profile_list = [default_name]
		_profile_paths = {default_name: LEGACY_SAVE_PATH}
		profile_name = default_name
		_save_profiles_meta()

func _save_profiles_meta() -> void:
	var meta := ConfigFile.new()
	meta.set_value("meta", "list", profile_list)
	meta.set_value("meta", "active", profile_name)
	meta.set_value("paths", "map", _profile_paths)
	meta.save(PROFILES_META_PATH)

# Новый игрок — полностью чистая «учётка» (прогресс И настройки), не только
# обнулённая статистика. Переключает активный профиль на новый.
func create_profile(pname: String) -> bool:
	pname = pname.strip_edges()
	if pname == "" or pname in profile_list or active_run >= 0:
		return false
	save_game()   # сохранить прежнего игрока перед уходом с профиля
	DirAccess.make_dir_recursive_absolute("user://profiles")
	# Имя может содержать любые символы (эмодзи, слэши) — для имени ФАЙЛА
	# используем хеш, само читаемое имя живёт только в profiles.cfg.
	var fname := "user://profiles/p_%s.cfg" % pname.sha256_text().substr(0, 16)
	profile_list.append(pname)
	_profile_paths[pname] = fname
	profile_name = pname
	_save_profiles_meta()
	_reset_progress_fields()
	_reset_settings_fields()
	save_game()
	return true

# Переключиться на уже существующий профиль (сохраняет текущий перед уходом).
func switch_profile(pname: String) -> bool:
	if not (pname in profile_list) or pname == profile_name or active_run >= 0:
		return false
	save_game()
	profile_name = pname
	_save_profiles_meta()
	load_game()
	return true

# Удалить профиль (файл прогресса и запись в списке). Нельзя удалить
# активный или последний оставшийся профиль — переключаться уже не на что.
func delete_profile(pname: String) -> bool:
	if not (pname in profile_list) or pname == profile_name or profile_list.size() <= 1:
		return false
	var path: String = str(_profile_paths.get(pname, ""))
	if path != "" and path != LEGACY_SAVE_PATH and FileAccess.file_exists(path):
		DirAccess.remove_absolute(path)
	profile_list.erase(pname)
	_profile_paths.erase(pname)
	_save_profiles_meta()
	return true

func _reset_settings_fields() -> void:
	show_fps = false
	test_mode = false
	difficulty = 1
	beacon_pulse = true
	show_hints = true
	start_hint_shown = false
	help_intro_seen = false
	music_volume = 0.8
	sfx_volume = 1.0
	fullscreen = false
	vsync = true
	quality = 2
	fps_cap = 60
	resolution_idx = 1
	locale = "ru"

# ── Сохранение / загрузка ────────────────────────────────────────────────────

func save_game() -> void:
	# [SAVE-SAFETY] Единая точка отсечения: test_mode обещает игроку (см. текст
	# в настройках) «статистика/XP/прогресс не пишутся» — но save_game()
	# вызывается БЕЗУСЛОВНО из множества мест по всему проекту (завершение
	# уровня, забег Накала, Логово и т.д.), а не только из горстки функций,
	# что уже проверяют test_mode сами. Раньше локальные проверки в паре
	# функций магазина навыков создавали иллюзию защиты, но test_mode всё
	# равно тёк наружу через все остальные вызовы (реальный инцидент: harness
	# с test_mode=true всё равно переписал реальный сейв игрока). Проверка
	# здесь, в одном месте, надёжнее, чем гоняться за каждым вызовом отдельно.
	if test_mode:
		return
	# В забеге «Накал» сохраняем ТОЛЬКО слот + статистику, не трогая глобальный
	# профиль «Уровней».
	if active_run >= 0:
		_sync_live_into_run()
		_save_runs_and_stats()
		return
	var cfg := ConfigFile.new()
	cfg.load(_save_path())   # сохранить чужие секции (слоты забегов)
	cfg.set_value("progress", "level",            level)
	cfg.set_value("progress", "max_unlocked",     max_unlocked_level)
	cfg.set_value("progress", "xp",               xp)
	cfg.set_value("progress", "skill_points",     skill_points)
	cfg.set_value("progress", "enemy_encounters", enemy_encounters)
	cfg.set_value("progress", "rank_good_streak", rank_good_streak)
	cfg.set_value("progress", "rank_bad_streak",  rank_bad_streak)
	cfg.set_value("progress", "best_ranks",       level_best_ranks)
	cfg.set_value("progress", "lair_max_unlocked", lair_max_unlocked)
	cfg.set_value("progress", "caves_max_unlocked", caves_max_unlocked)
	cfg.set_value("progress", "ladder_seen",      ladder_seen)
	cfg.set_value("progress", "codex_read",       codex_read)
	cfg.set_value("progress", "codex_met",        codex_met)
	cfg.set_value("progress", "codex_notified",   codex_notified)
	cfg.set_value("progress", "tutorial_done",    tutorial_done)
	cfg.set_value("settings", "show_fps", show_fps)
	cfg.set_value("settings", "test_mode", test_mode)
	cfg.set_value("settings", "difficulty", difficulty)
	cfg.set_value("settings", "beacon_pulse", beacon_pulse)
	cfg.set_value("settings", "show_hints", show_hints)
	cfg.set_value("settings", "echo_time_enabled", echo_time_enabled)
	cfg.set_value("progress", "echo_trails", echo_trails)
	cfg.set_value("settings", "start_hint_shown", start_hint_shown)
	cfg.set_value("settings", "help_intro_seen", help_intro_seen)
	cfg.set_value("settings", "music_volume", music_volume)
	cfg.set_value("settings", "sfx_volume", sfx_volume)
	cfg.set_value("settings", "fullscreen", fullscreen)
	cfg.set_value("settings", "vsync", vsync)
	cfg.set_value("settings", "quality", quality)
	cfg.set_value("settings", "fps_cap", fps_cap)
	cfg.set_value("settings", "resolution_idx", resolution_idx)
	cfg.set_value("settings", "locale", locale)
	for k in skill_uses:
		cfg.set_value("uses", k, skill_uses[k])
	for k in skills_unlocked:
		cfg.set_value("unlocked", k, skills_unlocked[k])
	cfg.set_value("progress", "superboss_defeated", superboss_defeated)
	cfg.set_value("progress", "door_boss_defeated", door_boss_defeated)
	cfg.set_value("progress", "forge_pts", forge_pts)
	for k in forge_stars:
		cfg.set_value("forge", k, int(forge_stars[k]))
	for k in summon_unlocked:
		cfg.set_value("summon_unlocked", k, summon_unlocked[k])
	for k in passives:
		cfg.set_value("passives", k, passives[k])
	_write_runs_and_stats(cfg)
	cfg.save(_save_path())

func _save_runs_and_stats() -> void:
	var cfg := ConfigFile.new()
	cfg.load(_save_path())
	_write_runs_and_stats(cfg)
	cfg.save(_save_path())

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
	if cfg.load(_save_path()) != OK:
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
	caves_max_unlocked = clampi(int(cfg.get_value("progress", "caves_max_unlocked", 1)), 1, CAVES_LEVELS)
	var ls = cfg.get_value("progress", "ladder_seen", {})
	ladder_seen = ls if ls is Dictionary else {}
	var cr = cfg.get_value("progress", "codex_read", {})
	codex_read = cr if cr is Dictionary else {}
	var cm = cfg.get_value("progress", "codex_met", {})
	codex_met = cm if cm is Dictionary else {}
	var cn = cfg.get_value("progress", "codex_notified", {})
	codex_notified = cn if cn is Dictionary else {}
	var td = cfg.get_value("progress", "tutorial_done", {})
	tutorial_done = td if td is Dictionary else {}
	show_fps         = cfg.get_value("settings", "show_fps", false)
	test_mode        = cfg.get_value("settings", "test_mode", false)
	beacon_pulse     = cfg.get_value("settings", "beacon_pulse", true)
	show_hints       = cfg.get_value("settings", "show_hints", true)
	echo_time_enabled = cfg.get_value("settings", "echo_time_enabled", false)
	var et = cfg.get_value("progress", "echo_trails", {})
	echo_trails = et if et is Dictionary else {}
	start_hint_shown = cfg.get_value("settings", "start_hint_shown", false)
	help_intro_seen  = cfg.get_value("settings", "help_intro_seen", false)
	music_volume     = clampf(float(cfg.get_value("settings", "music_volume", 0.8)), 0.0, 1.0)
	sfx_volume       = clampf(float(cfg.get_value("settings", "sfx_volume", 1.0)), 0.0, 1.0)
	fullscreen       = cfg.get_value("settings", "fullscreen", false)
	vsync            = cfg.get_value("settings", "vsync", true)
	quality          = clampi(int(cfg.get_value("settings", "quality", 2)), 0, 2)
	fps_cap          = int(cfg.get_value("settings", "fps_cap", 60))
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
	superboss_defeated = cfg.get_value("progress", "superboss_defeated", false)
	door_boss_defeated = cfg.get_value("progress", "door_boss_defeated", false)
	forge_pts = int(cfg.get_value("progress", "forge_pts", 0))
	forge_stars = {}
	if cfg.has_section("forge"):
		for k in cfg.get_section_keys("forge"):
			forge_stars[k] = clampi(int(cfg.get_value("forge", k, 0)), 0, 3)
	for k in summon_unlocked.keys():
		summon_unlocked[k] = cfg.get_value("summon_unlocked", k, summon_unlocked[k])
	for k in passives.keys():
		passives[k] = cfg.get_value("passives", k, false)

# Перечитать глобальный профиль «Уровней» в живые переменные (после забега).
func load_levels_profile() -> void:
	relic_stars = {}
	var cfg := ConfigFile.new()
	if cfg.load(_save_path()) == OK:
		_read_global(cfg)
	# Награда за выполненный обет Накала возвращается в глобальный профиль.
	if vow_reward_pending > 0 and active_run < 0:
		skill_points += vow_reward_pending
		vow_reward_pending = 0
		save_game()

# Сброс прогресса ТЕКУЩЕГО профиля (см. `_save_path()`) — другие профили не
# трогает, т.к. каждый профиль это отдельный save-файл (v1.9: несколько
# игроков на машине).
func reset_progress() -> void:
	_reset_progress_fields()
	_save_level_history()
	save_game()

func _reset_progress_fields() -> void:
	xp = 0
	skill_points = 0
	enemy_encounters = 0
	level = 1
	max_unlocked_level = 1
	rank_good_streak = 0
	rank_bad_streak = 0
	level_best_ranks = {}
	lair_max_unlocked = 1
	caves_max_unlocked = 1
	ladder_seen = {}
	codex_read = {}
	codex_met = {}
	codex_notified = {}
	tutorial_done = {}
	echo_trails = {}
	for k in skill_uses.keys():
		skill_uses[k] = 0
	for k in skills_unlocked.keys():
		skills_unlocked[k] = START_SKILLS.has(k)
	superboss_defeated = false
	door_boss_defeated = false
	forge_pts = 0
	forge_stars = {}
	relic_stars = {}
	for k in summon_unlocked.keys():
		summon_unlocked[k] = false
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
