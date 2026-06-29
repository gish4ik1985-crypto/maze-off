extends Node

# Глобальные настройки и прогресс игры (autoload "GameConfig").
# Читается при генерации лабиринта и при открытии меню навыков.

# ── Параметры лабиринта ──────────────────────────────────────────────────────
var cols: int          = 16
var rows: int          = 10
var station_count: int = 8
var player_speed: float    = 320.0
var max_energy: float      = 1.7
var drain_per_sec: float   = 0.055
var darkness: float        = 0.05
var door_pairs: int        = 1
var lives: int             = 3
var events_enabled: bool       = true
var progressive_enabled: bool  = true
var door_regen_enabled: bool   = false
var door_regen_chance: float   = 0.3
var darkness_chaser: bool      = true
var boss_test_enabled: bool    = false  # тест: босс на выбранном уровне (не зависит от Накала)

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
var active_run: int = -1
var runs: Array = [null, null, null]   # снимок каждого слота (Dictionary | null)
var resumed: bool = false              # true один раз после resume_run (для баннера «продолжено»)

# ── Глобальная статистика (для раздела «Статистика») ─────────────────────────
var stats := {
	"runs_started":   0,
	"runs_ended":     0,
	"best_depth":     0,
	"best_ember":     0,
	"levels_cleared": 0,
	"shards_total":   0,
	"rank_S": 0, "rank_A": 0, "rank_B": 0, "rank_C": 0, "rank_D": 0,
}

# ── Пассивные навыки (true = включены на текущую партию) ────────────────────
# Влияют на параметры только если навык куплен (skills_unlocked[key] == true).
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
	"shield": 0, "guide": 0, "reveal": 0,
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

func all_active_skills_unlocked() -> bool:
	for k in ["flash", "dash", "sonar", "shield", "guide", "reveal"]:
		if not skills_unlocked.get(k, false):
			return false
	return true

# Топ-N навыков по мастерству. Возвращает массив ключей, отсортированный
# по убыванию мастерства. Используется Апексом для выбора формы.
func top_mastered(n: int = 2) -> Array:
	var keys := ["flash", "dash", "sonar", "shield", "guide", "reveal"]
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
	"flash": 0,  "dash": 0,
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
	_apply_ui_scale()
	var tree := get_tree()
	if tree:
		tree.root.size_changed.connect(_apply_ui_scale)

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
	xp += amount
	while xp >= XP_PER_SP:
		xp -= XP_PER_SP
		skill_points += 1

# Возвращает true если покупка прошла успешно.
func try_buy_skill(skill: String) -> bool:
	if skills_unlocked.get(skill, false):
		return false
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
		"flash": true, "dash": true,
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
		"uses": {"flash": 0, "dash": 0, "sonar": 0, "shield": 0, "guide": 0, "reveal": 0},
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
		skills_unlocked[k] = bool(rs.get(k, false))
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
	stats["runs_started"] = int(stats.get("runs_started", 0)) + 1
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
	stats["runs_ended"] = int(stats.get("runs_ended", 0)) + 1
	stats["best_depth"] = maxi(int(stats.get("best_depth", 0)), int(r.get("max_depth", 1)))
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
	for i in RUN_SLOTS:
		cfg.set_value("runs", "slot%d" % i, runs[i] if runs[i] != null else {})
	for k in stats:
		cfg.set_value("stats", k, stats[k])

func load_game() -> void:
	var cfg := ConfigFile.new()
	if cfg.load(SAVE_PATH) != OK:
		return
	_read_global(cfg)
	for i in RUN_SLOTS:
		var d = cfg.get_value("runs", "slot%d" % i, {})
		runs[i] = d if (d is Dictionary and d.has("level")) else null
	for k in stats.keys():
		stats[k] = cfg.get_value("stats", k, stats[k])
	active_run = -1

func _read_global(cfg: ConfigFile) -> void:
	level            = cfg.get_value("progress", "level",            1)
	max_unlocked_level = cfg.get_value("progress", "max_unlocked",   1)
	xp               = cfg.get_value("progress", "xp",               0)
	skill_points     = cfg.get_value("progress", "skill_points",     0)
	enemy_encounters = cfg.get_value("progress", "enemy_encounters", 0)
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
	runs = [null, null, null]
	for k in stats.keys():
		stats[k] = 0
	save_game()
