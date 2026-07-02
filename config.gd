extends Node

# Глобальные настройки и прогресс игры (autoload "GameConfig").
# Читается при генерации лабиринта и при открытии меню навыков.

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
var music_volume: float        = 0.8    # громкость музыки 0..1 (шина "Music")
var sfx_volume: float          = 1.0    # громкость звуков 0..1 (шина "SFX")
var fullscreen: bool           = false
var vsync: bool                = true
var resolution_idx: int        = 1
const RESOLUTIONS := [Vector2i(1280, 720), Vector2i(1600, 900), Vector2i(1920, 1080), Vector2i(2560, 1440)]

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
}

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
}

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
	"shield": 0, "guide": 0, "reveal": 0, "smother": 0,
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
	if skill_uses.has(skill):
		skill_uses[skill] += 1
	bump_stat("skills_cast")   # питает пассивку «Эффективная магия»

func all_active_skills_unlocked() -> bool:
	for k in ["flash", "dash", "sonar", "shield", "guide", "reveal"]:
		if not skills_unlocked.get(k, false):
			return false
	return true

# Топ-N навыков по мастерству. Возвращает массив ключей, отсортированный
# по убыванию мастерства. Используется Апексом для выбора формы.
func top_mastered(n: int = 2) -> Array:
	# Дары боссов участвуют: Апекс может принять и их форму.
	var keys := ["flash", "dash", "sonar", "shield", "guide", "reveal", "mirage", "breach", "chrono"]
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
	"save":     false,
	"capacity": false,
	"charge":   false,
	"range":    false,
	"legs":     false,
	"magic":    false,
	"apex":     false,  # супернавык — открывается автоматически
}

# Стоимость открытия (SP). Бесплатные навыки открыты с начала.
const SKILL_COSTS := {
	"flash": 0,  "dash": 0, "smother": 0,
	"sonar": 2,  "shield": 2,
	"guide": 3,  "reveal": 3,
	"save": 2,   "capacity": 2,
	"charge": 2, "range": 1,
	"legs": 1,   "magic": 3,
	"apex": 0,   # открывается автоматически — за SP не купить
}

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
	if test_mode:
		return   # тест-режим автора: прогресс не фармится
	xp += int(round(amount * diff_reward_mult()))
	while xp >= XP_PER_SP:
		xp -= XP_PER_SP
		skill_points += 1

# ── Майлстоуны навыков: ЦЕЛЬ ИГРЫ в «Уровнях» ────────────────────────────────
# Закрытый навык открывается ЛИБО за SP (меню навыков), ЛИБО сам — за игровое
# достижение. Игрок всегда видит, к чему идёт (панель «Путь к навыкам» в
# Дневнике + сообщение при открытии). В «Накале» не действует — там алтарь.
const SKILL_MILESTONES := {
	"sonar":  {"stat": "shards_total",   "need": 25, "text": "собери 25 осколков"},
	"shield": {"stat": "enemies_killed", "need": 8,  "text": "победи 8 врагов"},
	"guide":  {"stat": "stations_used",  "need": 20, "text": "испей 20 кристаллов"},
	"reveal": {"stat": "levels_cleared", "need": 6,  "text": "пройди 6 уровней"},
}

# Проверяет майлстоуны; возвращает массив только что открытых id (для баннера).
func check_skill_milestones() -> Array:
	if active_run >= 0 or test_mode:
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
		if all_active_skills_unlocked():
			skills_unlocked["apex"] = true
		save_game()
	return newly

# Единая точка изменения глобальной статистики: в тест-режиме автора ничего
# не записывается (ни счётчики, ни рекорды) — тестовые прогоны не искажают
# Дневник и Спуск дня.
func bump_stat(key: String, delta: int = 1) -> void:
	if test_mode:
		return
	stats[key] = int(stats.get(key, 0)) + delta

func max_stat(key: String, value: int) -> void:
	if test_mode:
		return
	stats[key] = maxi(int(stats.get(key, 0)), value)

# Возвращает true если покупка прошла успешно.
func try_buy_skill(skill: String) -> bool:
	# Уже открытый активный навык покупается ПОВТОРНО как усиление:
	# +1★ мастерства (эквивалент MASTERY_PER_LEVEL применений), до 5★.
	if skills_unlocked.get(skill, false):
		if not skill_uses.has(skill) or mastery(skill) >= MASTERY_MAX:
			return false
		var up_cost: int = maxi(int(SKILL_COSTS.get(skill, 999)), 2)
		if skill_points < up_cost:
			return false
		skill_points -= up_cost
		skill_uses[skill] += MASTERY_PER_LEVEL
		save_game()
		return true
	var cost: int = SKILL_COSTS.get(skill, 999)
	if skill_points < cost:
		return false
	skill_points -= cost
	skills_unlocked[skill] = true
	# Если куплены все 6 активных навыков — автоматически открываем Апекс
	if all_active_skills_unlocked():
		skills_unlocked["apex"] = true
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

func start_new_run(slot: int) -> void:
	runs[slot] = _new_run_dict()
	if slot != DAILY_SLOT:
		bump_stat("runs_started")
	_load_run_into_live(slot)
	save_game()

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
	cfg.set_value("settings", "show_fps", show_fps)
	cfg.set_value("settings", "test_mode", test_mode)
	cfg.set_value("settings", "difficulty", difficulty)
	cfg.set_value("settings", "beacon_pulse", beacon_pulse)
	cfg.set_value("settings", "music_volume", music_volume)
	cfg.set_value("settings", "sfx_volume", sfx_volume)
	cfg.set_value("settings", "fullscreen", fullscreen)
	cfg.set_value("settings", "vsync", vsync)
	cfg.set_value("settings", "resolution_idx", resolution_idx)
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
	active_run = -1

func _read_global(cfg: ConfigFile) -> void:
	level            = cfg.get_value("progress", "level",            1)
	max_unlocked_level = cfg.get_value("progress", "max_unlocked",   1)
	xp               = cfg.get_value("progress", "xp",               0)
	skill_points     = cfg.get_value("progress", "skill_points",     0)
	enemy_encounters = cfg.get_value("progress", "enemy_encounters", 0)
	show_fps         = cfg.get_value("settings", "show_fps", false)
	test_mode        = cfg.get_value("settings", "test_mode", false)
	beacon_pulse     = cfg.get_value("settings", "beacon_pulse", true)
	music_volume     = clampf(float(cfg.get_value("settings", "music_volume", 0.8)), 0.0, 1.0)
	sfx_volume       = clampf(float(cfg.get_value("settings", "sfx_volume", 1.0)), 0.0, 1.0)
	fullscreen       = cfg.get_value("settings", "fullscreen", false)
	vsync            = cfg.get_value("settings", "vsync", true)
	resolution_idx   = clampi(int(cfg.get_value("settings", "resolution_idx", 1)), 0, RESOLUTIONS.size() - 1)
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

func reset_progress() -> void:
	xp = 0
	skill_points = 0
	enemy_encounters = 0
	level = 1
	max_unlocked_level = 1
	for k in skill_uses.keys():
		skill_uses[k] = 0
	for k in skills_unlocked.keys():
		skills_unlocked[k] = (SKILL_COSTS.get(k, 1) == 0)
	for k in passives.keys():
		passives[k] = false
	active_run = -1
	runs = [null, null, null, null]
	for k in stats.keys():
		stats[k] = 0
	level_history = []
	daily_history = []
	_save_level_history()
	save_game()
