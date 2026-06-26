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

# ── Текущий уровень и иммунитет ──────────────────────────────────────────────
var level: int            = 1
var max_unlocked_level: int = 1   # самый высокий уровень, доступный для выбора
var enemy_encounters: int = 0

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

# ── Сохранение / загрузка ────────────────────────────────────────────────────

const SAVE_PATH := "user://maze_off.cfg"

func save_game() -> void:
	var cfg := ConfigFile.new()
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
	cfg.save(SAVE_PATH)

func load_game() -> void:
	var cfg := ConfigFile.new()
	if cfg.load(SAVE_PATH) != OK:
		return
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
	save_game()
