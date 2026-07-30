extends CharacterBody2D

# =============================================================================
# ЭКСПОРТИРУЕМЫЕ ПАРАМЕТРЫ
# Их можно менять прямо в инспекторе Godot, не трогая код.
# =============================================================================

@export var speed: float = 320.0          # базовая скорость передвижения (пикселей/с)
@export var max_energy: float = 2.0       # максимальный запас света (1.0 = полный)
@export var drain_per_sec: float = 0.04   # скорость расхода света в секунду (без станций)
@export var charge_per_sec: float = 1.4   # скорость зарядки на станции (единиц/с)
@export var boost_delay: float = 2.0      # через сколько секунд зарядки расширяется радиус
@export var boost_radius_mult: float = 2.0 # во сколько раз расширяется радиус при зарядке

# =============================================================================
# КОНСТАНТЫ НАВЫКОВ
# Каждый навык имеет стоимость (energy), перезарядку (cooldown) и длительность.
# =============================================================================

# Вспышка (Q) — кратковременно расширяет круг света
const FLASH_COST        := 0.28   # стоимость в единицах света
const FLASH_COOLDOWN    := 4.0    # перезарядка в секундах
const FLASH_DUR         := 0.55   # длительность вспышки
const FLASH_EXTRA_SCALE := 6.0    # насколько увеличивается масштаб текстуры света
const FLASH_EXTRA_ENERGY := 2.5   # насколько увеличивается яркость во время вспышки

# Рывок (Shift) — мгновенный импульс в сторону движения
const DASH_COST     := 0.15
const DASH_COOLDOWN := 1.8
const DASH_DUR      := 0.18    # длительность рывка (очень короткая)
const DASH_SPEED    := 900.0   # скорость во время рывка (в ~3 раза быстрее обычной)

# Сонар (E) — световое кольцо, раскрывает лабиринт вокруг. Дороже и куда
# реже, чем Вспышка (Q) — это осознанная разведка, а не тот же панический
# импульс подешевле (баланс: раньше кулдаун 5с был короче суммарной
# длительности эффекта в sonar.gd — обзор был расширен практически всё время).
const SONAR_COST     := 0.42
const SONAR_COOLDOWN := 11.0

# Щит (C) — останавливает разрядку света на несколько секунд
const SHIELD_COST     := 0.20
const SHIELD_COOLDOWN := 8.0
const SHIELD_DUR      := 4.0   # сколько секунд защищает щит

# Искра (G) — огонёк прокладывает путь к выходу
const GUIDE_COST     := 0.35
const GUIDE_COOLDOWN := 10.0

# Озарение (F) — заряжается пассивно, раскрывает весь этаж на несколько секунд
const REVEAL_FILL_PER_SEC := 0.2   # скорость накопления заряда озарения
const REVEAL_DURATION     := 4.0   # длительность эффекта озарения

# Тление (R) — «задержать дыхание»: добровольно пригаситься. Свет падает до
# искры, скорость проседает, ты почти слеп — но и враги ТЕРЯЮТ тебя (заметность
# ~20%, см. visibility_factor). Навык для умных пряток, а не для паники.
const SMOTHER_COST     := 0.12
const SMOTHER_COOLDOWN := 7.0
const SMOTHER_DUR      := 2.6
const SMOTHER_SPEED    := 0.55     # множитель скорости, пока тлеешь
const SMOTHER_VIS      := 0.20     # заметность для врагов, пока тлеешь

# ── Накал света: стойки (GAMEDESIGN §29, «Свет как рычаг») ──────────────────
# До этого Свет был чистым таймером: ровная утечка, на которую игрок не мог
# повлиять ничем, кроме «дойти до станции быстрее». Стойка делает Свет
# ВАЛЮТОЙ, которой платишь за информацию: раздул — видишь дальше и находишь
# осколки/выход быстрее, но горишь втрое быстрее и тебя видно издалека;
# пригасил — экономишь и прячешься, но идёшь почти вслепую и медленнее.
#
# Это НЕ дубль Тления (R): Тление — короткий рывок в невидимость за Волю с
# кулдауном (аварийный побег), стойка — бесплатный и постоянный режим, в
# котором ты живёшь между станциями. Тление перебивает стойку, пока активно.
#
# Индексы: 0 — Тусклый, 1 — Ровный (по умолчанию), 2 — Яркий.
const STANCE_DIM    := 0
const STANCE_EVEN   := 1
const STANCE_BRIGHT := 2
const STANCE_NAMES     := ["Тусклый", "Ровный", "Яркий"]
const STANCE_NAMES_EN  := ["Dim", "Even", "Bright"]
const STANCE_RADIUS := [0.52, 1.0, 1.62]   # множитель радиуса света
const STANCE_DRAIN  := [0.45, 1.0, 2.40]   # множитель расхода Света
const STANCE_VIS    := [0.55, 1.0, 1.75]   # множитель заметности для врагов
const STANCE_SPEED  := [0.88, 1.0, 1.0]    # тусклым идёшь осторожнее
const STANCE_COLORS := [
	Color(0.45, 0.60, 0.85), Color(1.0, 0.86, 0.35), Color(1.0, 0.72, 0.25),
]
var light_stance: int = STANCE_EVEN

# ── Шум навыков (GAMEDESIGN §31) ────────────────────────────────────────────
# Второй канал угрозы рядом с заметностью: заметность отвечает за «видно ли
# тебя», шум — за «слышно ли». Раньше навыки и враги ничего друг о друге не
# знали: применить Сонар было бесплатно, поэтому решения «кастовать или нет»
# не существовало. Теперь у каждого навыка своя громкость в мировых px, и
# враг в этом радиусе идёт ПРОВЕРЯТЬ источник (pursuer.hear), даже через стену.
#
# Ноль — намеренно у двух навыков: Тление это кнопка «спрятаться» (шум сделал
# бы её бессмысленной), а Мираж и так приманка со своей механикой отвлечения —
# шум в точке игрока перебивал бы двойника, ради которого его и ставят.
# Для сравнения: базовый радиус обнаружения врага VIEW_RADIUS = 330.
const SKILL_NOISE := {
	"sonar": 620.0,      # импульс сквозь стены — самый громкий по смыслу
	"breach": 700.0,     # проламывание стены
	"reveal": 560.0,
	"flash": 520.0,
	"chrono": 300.0,
	"pulse": 260.0,
	"mirror_ally": 240.0,
	"dash": 200.0,
	"shield": 150.0,
	"guide": 120.0,
	"smother": 0.0,      # кнопка «спрятаться» обязана быть бесшумной
	"mirage": 0.0,       # у миража своя приманка, шум её перебивает
}
const NOISE_SEARCH_DUR := 3.2   # сколько секунд враг ищет источник шума

# Сообщить миру о шуме успешного каста. Зовётся ПОСЛЕ add_skill_use, то есть
# только когда навык реально применился (не в кулдаун и не без Воли).
func _emit_noise(skill_id: String) -> void:
	var r: float = float(SKILL_NOISE.get(skill_id, 0.0))
	if r <= 0.0:
		return
	# Тление глушит и шум: пока тлеешь, ты крадёшься, а не топаешь.
	if _smother_time > 0.0:
		r *= 0.45
	# Стойка света влияет и на слышимость: раздутый свет гудит, притушенный —
	# нет. Так стойка становится решением не только про зрение (§29).
	r *= [0.7, 1.0, 1.35][light_stance]
	var g := get_parent()
	if g and g.has_method("make_noise"):
		g.make_noise(global_position, r, NOISE_SEARCH_DUR)


# ── Дары боссов (открываются победой над Тёмным Ядром за багровой дверью) ──
# Мираж (T) — ложная цель: враги поблизости бегут проверять её.
const MIRAGE_COST     := 0.25
const MIRAGE_COOLDOWN := 12.0
# Разлом (Y) — проламывает стену по направлению взгляда.
const BREACH_COST     := 0.35
const BREACH_COOLDOWN := 16.0
# Хронос (V) — замораживает врагов на этаже на несколько секунд.
const CHRONO_COST     := 0.40
const CHRONO_COOLDOWN := 20.0

# Апекс (H) — супернавык, открывается когда куплены все 7 активных навыков
const APEX_COST     := 0.5         # стоимость в энергии
const APEX_COOLDOWN := 30.0        # длинный кулдаун — это «ультимейт»

# Пульс (B) — на 10 секунд включает звуковой ориентир: тихие «пик» чаще и
# ближе к выходу этажа. Путь пересчитывается редко (см. main.gd:_update_pulse),
# поэтому сигнал ведёт по коридору, а не читерски насквозь стен.
const PULSE_COST     := 0.30
const PULSE_COOLDOWN := 22.0
const PULSE_DUR      := 10.0

# =============================================================================
# ВОЛЯ — отдельный ресурс для активных навыков (GAMEDESIGN п.3/11).
# Свет (energy) = выживание: тратится на пребывание во тьме и урон врагов.
# Воля (will) = действия: тратится ТОЛЬКО на навыки, копится за активную игру
# (осколки, глотки станций) + медленный пассивный тик. Активный стиль больше
# не приближает смерть — наоборот, кормит сам себя.
# =============================================================================
const WILL_REGEN_PER_SEC := 0.035  # пассивный тик Воли (пустой пул → полный ~36 сек)
const WILL_PER_SHARD     := 0.25   # Воля за подобранный осколок (даёт main.gd)
const WILL_PER_STATION   := 0.40   # Воля за глоток станции (даёт station.gd)

# Нижний порог яркости: визуальный свет никогда не гаснет полностью,
# даже если energy = 0. Это только визуал — механика смерти происходит при energy = 0.
const LIGHT_MIN := 0.9

# =============================================================================
# КОНСТАНТЫ НАКОПИТЕЛЬНЫХ ПАССИВОК
# Работают только если включены в настройках (GameConfig.progressive_enabled).
# =============================================================================

const DIST_FULL    := 6000.0  # пробежать 6000 пикселей → полный бонус к скорости
const ADAPT_FULL   := 90.0    # прожить 90 секунд → полный бонус к адаптации
const MOMENTUM_MAX := 0.30    # максимум: +30% к скорости
const ADAPT_MAX    := 0.30    # максимум: −30% к расходу света

# =============================================================================
# ПЕРЕМЕННЫЕ СОСТОЯНИЯ
# =============================================================================

var energy: float                          # текущий запас света (0.0 … max_energy)
var will: float = 1.25                     # запас Воли для навыков (0.0 … max_will)
var max_will: float = 1.25                 # потолок Воли (~5-8 применений подряд)
var charge_sources: int = 0                # сколько зон станций одновременно перекрывают игрока
var active: bool = true                    # false = игрок погас (нет управления, нет обработки)
var current_floor: int = 0                 # номер этажа, на котором находится игрок
var teleport_cooldown: float = 0.0         # блокировка повторного телепорта сразу после перехода
var touch_dir: Vector2 = Vector2.ZERO      # направление с виртуального джойстика (мобильное управление)
var _charge_block_time: float = 0.0        # враг типа SLOW на некоторое время лишает зарядки через станцию

# --- Кулдауны навыков (читаются HUD-ом для отображения) ---
var flash_cd: float    = 0.0
var flash_boost: float = 0.0   # 1→0 за время вспышки (масштаб/яркость света)

# Камера: сглаживание следования (см. _update_camera). Скорости занижены —
# камера проходит ступенчатые коридоры по сглаженной диагонали, а не повторяет
# зигзаг игрока вдоль стен. Упреждение чуть увеличено, чтобы при мягкой привязке
# камера не отставала визуально.
const CAM_FOLLOW      := 4.5    # скорость подтягивания камеры к цели (больше = туже)
const CAM_VEL_SMOOTH  := 2.4    # скорость усреднения вектора скорости (меньше = плавнее)
const CAM_LOOKAHEAD   := 0.13   # упреждение: доля усреднённой скорости (сек)
var _cam_vel_avg: Vector2 = Vector2.ZERO   # низкочастотно усреднённая скорость игрока
var dash_cd: float     = 0.0
var sonar_cd: float  = 0.0
var shield_cd: float = 0.0
var guide_cd: float  = 0.0
var apex_cd: float   = 0.0
var smother_cd: float = 0.0
var _smother_time: float = 0.0   # сколько секунд ещё «тлеем» (пригашены)
var mirage_cd: float = 0.0
var breach_cd: float = 0.0
var chrono_cd: float = 0.0
var reveal_charge: float = 0.0   # заряд озарения (0.0 … 1.0); при 1.0 можно активировать
var pulse_cd: float   = 0.0
var pulse_time: float = 0.0      # >0, пока активен звуковой ориентир «Пульс»
var summon_cd: float  = 0.0      # §25 — навык призыва (ally.gd), отдельная витрина в skills_menu.gd

# ── Старт уровня ───────────────────────────────────────────────────────────
# Все процессы (разрядка, события, таймер) запускаются только после первого
# движения игрока. Это даёт возможность спокойно осмотреться.
var started: bool = false

# --- Накопительные бонусы (читаются HUD-ом) ---
var momentum_bonus: float = 0.0   # текущий бонус к скорости от пройденного расстояния
var adapt_bonus: float    = 0.0   # текущий бонус к экономии света от времени выживания

# --- Ссылки на дочерние узлы ---
var _light: PointLight2D       # основной свет игрока (бросает тени)
var _wall_light: PointLight2D  # вспомогательный свет для подсветки граней стен (без теней)
var _cone: PointLight2D        # прожектор-фонарь по направлению движения (бросает тени)
var _orb: Sprite2D             # энергетическое «тело» игрока
var _shield_vis: Sprite2D      # визуальное кольцо щита вокруг игрока
var _cam: Camera2D             # камера, следящая за игроком

# --- Тряска камеры ---
var _shake_amp: float  = 0.0   # максимальная амплитуда смещения при тряске
var _shake_t: float    = 0.0   # сколько секунд тряска ещё длится
var _shake_dur: float  = 0.0   # исходная длительность тряски (для плавного затухания)

# --- Таймеры навыков ---
var _charge_time: float  = 0.0   # как долго непрерывно заряжаемся (для активации буста радиуса)
var _flash_time: float   = 0.0   # сколько секунд ещё длится вспышка
var _dash_time: float    = 0.0   # сколько секунд ещё длится рывок
var _shield_time: float  = 0.0   # сколько секунд ещё активен щит
var _dash_dir: Vector2   = Vector2.RIGHT   # направление рывка (фиксируется в момент нажатия)
var _facing: Vector2     = Vector2.RIGHT   # последнее направление движения (для рывка на месте)

# --- Накопительные переменные ---
var _distance: float = 0.0   # суммарная пройденная дистанция (для momentum_bonus)
var _survival: float = 0.0   # суммарное время выживания в секундах (для adapt_bonus)
var _xp_dist: float  = 0.0   # счётчик пути для XP: каждые 300 px → 1 XP

# --- Таймеры случайных событий лабиринта ---
var _fog_time: float     = 0.0   # туман: уменьшает радиус света до 55%
var _leak_time: float    = 0.0   # утечка: увеличивает расход света в 1.8 раза
var _flicker_time: float = 0.0   # мерцание: свет случайно пульсирует

# --- Эффекты от врагов ---
var _enemy_block_time: float      = 0.0   # SLOW-враг: полностью блокирует зарядку на станции
var _enemy_slow_charge_time: float = 0.0  # FAST-враг: зарядка замедляется
var _enemy_slow_charge_mult: float = 1.0  # множитель замедления зарядки (1.0 = нет)
var _enemy_slow_move_time: float  = 0.0   # CYCLIC-враг: замедление движения
var _enemy_slow_move_mult: float  = 1.0   # множитель замедления движения (1.0 = нет)

# --- Состояния Апекса ---
var _apex_invuln_time: float = 0.0  # бессмертие от Апекса (форма shield)
var _apex_speed_time: float  = 0.0  # ускорение от Апекса (форма flash/reveal-echo)
var _apex_speed_mult: float  = 1.0
var _apex_dash_chain: int    = 0    # сколько рывков ещё запланировано (форма dash)
var _apex_chain_cd: float    = 0.0  # пауза между рывками в цепочке

# --- Множители от выбранных пассивных навыков (применяются один раз в _apply_passives) ---
var _radius_mult: float    = 1.0   # множитель радиуса света
var ember_glow: float      = 0.0   # 0..1, «Накал» забега: ярче свечение (ставит main)
var _skill_cost_mult: float = 1.0  # множитель стоимости навыков (пассивка «Эффективная магия»)
var _skill_cd_mult: float  = 1.0   # множитель перезарядки навыков

# =============================================================================
# ИНИЦИАЛИЗАЦИЯ
# =============================================================================

func _ready() -> void:
	add_to_group("player")   # группа используется для поиска игрока другими узлами
	_apply_passives()        # применить пассивные навыки из меню ДО установки energy
	energy = max_energy      # начинаем с полным светом

	# Визуальное «тело» игрока — энергетический шар (бело-горячее ядро + ободок)
	_orb = Sprite2D.new()
	_orb.texture = MazeTextures.make_player_orb(16)
	add_child(_orb)

	# Коллизия — круг радиусом 14 пикселей (чуть меньше спрайта, чтобы не застревать)
	var col := CollisionShape2D.new()
	var shape := CircleShape2D.new()
	shape.radius = 14.0
	col.shape = shape
	add_child(col)

	# Основной свет (бросает тени от стен). Холодно-белый под неоновую тему.
	_light = PointLight2D.new()
	_light.texture = MazeTextures.make_light(256)
	_light.color = Color(0.90, 0.96, 1.0)    # холодный белый (Tron)
	_light.height = 0.4                       # умеренно: даёт стенам базовую подсветку, тени честные
	_light.energy = energy
	_light.texture_scale = 1.0
	_light.shadow_enabled = true
	add_child(_light)

	# Вспомогательный свет ТОЛЬКО для стен (light_mask=2).
	# Без теней и с низким height, поэтому стены ловят свет всей поверхностью
	# и грани вспыхивают. Пол и предметы он не трогает (range_item_cull_mask=2),
	# значит коридоры за стенами остаются честно тёмными.
	_wall_light = PointLight2D.new()
	_wall_light.texture = MazeTextures.make_light(256)
	_wall_light.color = Color(0.90, 0.96, 1.0)
	_wall_light.height = 0.12
	_wall_light.shadow_enabled = false
	_wall_light.range_item_cull_mask = 2
	_wall_light.energy = energy
	_wall_light.texture_scale = 1.0
	add_child(_wall_light)

	# Прожектор-фонарь: яркий конус по направлению движения, бьёт дальше радиуса.
	# Апекс совпадает с игроком (offset = size/2 по X), узел поворачивается к _facing.
	# Без теней: он масштабируется как target_scale×1.8 (см. _physics_process) —
	# при вспышке (даже обычной Q на высоком мастерстве, не только Апексе) это
	# огромный источник, и с shadow_enabled=true он один давал большую часть
	# фриза (тени пересчитываются для каждой стены в этом радиусе каждый кадр).
	# Оптическую окклюзию «сквозь стены не видно» и так честно даёт _light.
	const CONE_SIZE := 384
	_cone = PointLight2D.new()
	_cone.texture = MazeTextures.make_cone_light(CONE_SIZE, 40.0)
	_cone.offset = Vector2(CONE_SIZE * 0.5, 0.0)
	_cone.color = Color(0.92, 0.97, 1.0)
	_cone.height = 0.35
	_cone.energy = energy
	_cone.texture_scale = 1.0
	_cone.shadow_enabled = false
	add_child(_cone)

	# Кольцо щита (скрыто до активации)
	_shield_vis = Sprite2D.new()
	_shield_vis.texture = MazeTextures.make_ring(80)
	_shield_vis.modulate = Color(0.4, 0.7, 1.0, 0.9)
	_shield_vis.visible = false
	add_child(_shield_vis)

	# Камера. Ведётся ВРУЧНУЮ (top_level) в кадровом цикле — _update_camera():
	# экспоненциальное сглаживание к игроку + упреждение по УСРЕДНЁННОЙ скорости.
	# Благодаря этому камера не повторяет рваный путь игрока вдоль стен (катеты), а
	# идёт по сглаженной траектории («гипотенуза») и мягко тормозит у стен — без
	# резких рывков, от которых укачивает. Встроенное сглаживание выключено, чтобы
	# не конфликтовало с ручным.
	_cam = Camera2D.new()
	_cam.top_level = true
	_cam.position_smoothing_enabled = false
	add_child(_cam)
	snap_camera()   # ставим камеру сразу в клампнутую позицию (без «наезда» на старте)

# Мгновенно подтянуть камеру к игроку (вызывается после телепорта/возрождения,
# чтобы не было «поездки»/смазывания камеры из старой позиции).
func snap_camera() -> void:
	_cam_vel_avg = Vector2.ZERO
	if _cam and is_instance_valid(_cam):
		_cam.global_position = _clamp_to_bounds(global_position)
		_cam.reset_smoothing()

# Плавное следование камеры. Кадронезависимое экспоненциальное сглаживание:
# k = 1 - e^(-delta·rate). Сначала низкочастотно усредняем скорость игрока
# (_cam_vel_avg), затем ведём камеру к точке «игрок + упреждение по усреднённому
# вектору». При резкой смене направления (слайд вдоль стены) усреднённый вектор
# меняется плавно → камера срезает угол и мягко останавливается.
func _update_camera(delta: float) -> void:
	if _cam == null or not is_instance_valid(_cam):
		return
	_cam_vel_avg = _cam_vel_avg.lerp(velocity, 1.0 - exp(-delta * CAM_VEL_SMOOTH))
	var lead: Vector2 = _cam_vel_avg * CAM_LOOKAHEAD
	var target: Vector2 = global_position + lead
	# Ограничение по краям лабиринта: камера не выходит за границы этажа, поэтому
	# у края игрок съезжает к краю экрана — видно, что ты у стены лабиринта.
	target = _clamp_to_bounds(target)
	_cam.global_position = _cam.global_position.lerp(target, 1.0 - exp(-delta * CAM_FOLLOW))

# Зажимает точку-цель камеры так, чтобы видимая область не вышла за границы
# текущего этажа лабиринта. Если лабиринт по оси уже экрана — центрируем по ней.
func _clamp_to_bounds(target: Vector2) -> Vector2:
	var game := get_parent()
	if game == null or not game.has_method("floor_world_bounds"):
		return target
	var r: Rect2 = game.floor_world_bounds(current_floor)
	# Видимая мировая область. Проект использует stretch keep_height: камера видит
	# РОВНО viewport_height мировых единиц по высоте, а ширину = высота × соотношение
	# сторон окна. Считаем из настроек (детерминированно, не зависит от физ. размера
	# окна и работает в headless, где canvas-трансформ не масштабируется).
	var phys: Vector2 = get_viewport_rect().size
	if phys.y <= 0.0:
		return target
	var base_h: float = float(ProjectSettings.get_setting("display/window/size/viewport_height", 720))
	var vis: Vector2 = Vector2(base_h * (phys.x / phys.y), base_h) / _cam.zoom
	var half: Vector2 = vis * 0.5
	# Верхний резерв под HUD-панель: камера может подняться выше, чтобы у верхнего
	# края лабиринта его граница (и игрок) опускались НИЖЕ панели, а не под неё.
	var inset := 0.0
	if game.has_method("hud_top_inset"):
		inset = game.hud_top_inset()
	var min_p: Vector2 = r.position + half
	var max_p: Vector2 = r.position + r.size - half
	min_p.y -= inset
	if min_p.x <= max_p.x:
		target.x = clampf(target.x, min_p.x, max_p.x)
	else:
		target.x = r.position.x + r.size.x * 0.5   # лабиринт уже экрана — центр
	if min_p.y <= max_p.y:
		target.y = clampf(target.y, min_p.y, max_p.y)
	else:
		target.y = r.position.y + r.size.y * 0.5 - inset * 0.5
	return target

# =============================================================================
# ТРЯСКА КАМЕРЫ
# Вызывается извне при событиях: смерть, рывок, подбор осколка.
# amp — сила смещения в пикселях, dur — длительность в секундах.
# =============================================================================

func add_shake(amp: float, dur: float) -> void:
	# Берём максимум, чтобы новая тряска не перебивала более сильную старую
	_shake_amp = maxf(_shake_amp, amp)
	_shake_dur = maxf(_shake_dur, dur)
	_shake_t   = maxf(_shake_t,   dur)

func _update_shake(delta: float) -> void:
	if _cam == null:
		return
	if _shake_t > 0.0:
		_shake_t -= delta
		# k плавно убывает от 1 до 0 — тряска затухает
		var k: float = _shake_t / _shake_dur if _shake_dur > 0.0 else 0.0
		var a: float = _shake_amp * k
		_cam.offset = Vector2(randf_range(-a, a), randf_range(-a, a))
		if _shake_t <= 0.0:
			_shake_amp = 0.0
			_cam.offset = Vector2.ZERO
	elif _cam.offset != Vector2.ZERO:
		_cam.offset = Vector2.ZERO

# =============================================================================
# ПРИМЕНЕНИЕ ПАССИВНЫХ НАВЫКОВ
# Вызывается один раз при старте. Читает выбранные навыки из GameConfig
# и корректирует базовые параметры игрока.
# =============================================================================

func _apply_passives() -> void:
	# Пассивки всегда включены и растут сами (см. GameConfig.PASSIVE_DEFS):
	# уровень 0..5 из накопленной статистики действий игрока.
	drain_per_sec  *= 1.0 - 0.06 * GameConfig.passive_level("save")
	max_energy     *= 1.0 + 0.06 * GameConfig.passive_level("capacity")
	charge_per_sec *= 1.0 + 0.10 * GameConfig.passive_level("charge")
	_radius_mult    = 1.0 + 0.05 * GameConfig.passive_level("range")
	speed          *= 1.0 + 0.03 * GameConfig.passive_level("legs")
	_skill_cost_mult = 1.0 - 0.06 * GameConfig.passive_level("magic")
	_skill_cd_mult   = 1.0 - 0.05 * GameConfig.passive_level("magic")

var _passive_time_acc: float = 0.0   # копилка секунд для «Энергосбережения»

# =============================================================================
# ВВОД (нажатия клавиш)
# Активные навыки обрабатываются здесь.
# Движение — в _physics_process, чтобы работать синхронно с физикой.
# =============================================================================

func _input(event: InputEvent) -> void:
	if not active:
		return
	if event is InputEventKey and event.pressed and not event.echo:
		match event.keycode:
			KEY_Q:     _try_flash()
			KEY_E:     _try_sonar()
			KEY_SHIFT: _try_dash()
			KEY_SPACE: _try_dash()   # дублёр рывка: паническая клавиша под большим пальцем
			KEY_C:     _try_shield()
			KEY_F:     _try_reveal()
			KEY_G:     _try_guide()
			KEY_H:     _try_apex()
			KEY_R:     _try_smother()
			KEY_B:     _try_pulse()
			KEY_T:     _try_mirage()
			KEY_Y:     _try_breach()
			KEY_V:     _try_chrono()
			KEY_N:     _try_summon()
			# Стойка света: соседние клавиши, «влево тусклее — вправо ярче».
			KEY_Z:     set_light_stance(light_stance - 1)
			KEY_X:     set_light_stance(light_stance + 1)
	# Колесо мыши — та же ручка: крутить интуитивнее, чем помнить две клавиши.
	elif event is InputEventMouseButton and event.pressed:
		if event.button_index == MOUSE_BUTTON_WHEEL_UP:
			set_light_stance(light_stance + 1)
		elif event.button_index == MOUSE_BUTTON_WHEEL_DOWN:
			set_light_stance(light_stance - 1)

# =============================================================================
# ФИЗИКА И ДВИЖЕНИЕ (_physics_process вызывается каждый кадр синхронно с физикой)
# =============================================================================

func _physics_process(delta: float) -> void:
	# Если телепорт только что произошёл — игнорируем следующие срабатывания
	# зоны двери, пока не истечёт задержка
	if teleport_cooldown > 0.0:
		teleport_cooldown -= delta

	if not active:
		velocity = Vector2.ZERO
		return

	# Читаем направление с клавиатуры; если клавиатура молчит — берём с джойстика
	var dir := Input.get_vector("ui_left", "ui_right", "ui_up", "ui_down")
	if dir == Vector2.ZERO and touch_dir.length() > 0.15:
		dir = touch_dir.limit_length(1.0)

	# Запоминаем последнее ненулевое направление (нужно для рывка без движения)
	if dir != Vector2.ZERO:
		_facing = dir
		# Первое движение запускает все игровые процессы (разрядка, события, таймер)
		if not started:
			started = true

	if _fire_trail_cd > 0.0:
		_fire_trail_cd -= delta

	if _dash_time > 0.0:
		# Во время рывка скорость фиксирована и направление не меняется
		_dash_time -= delta
		velocity = _dash_dir * DASH_SPEED
		_spawn_dash_ghost()
	else:
		# Обычное движение. CYCLIC-враг может наложить замедление 50%.
		# Апекс «mega-flash»/«mega-reveal» даёт временное ускорение.
		var move_mult := _enemy_slow_move_mult if _enemy_slow_move_time > 0.0 else 1.0
		var apex_mult := _apex_speed_mult if _apex_speed_time > 0.0 else 1.0
		var smother_mult := SMOTHER_SPEED if _smother_time > 0.0 else 1.0
		var stance_mult := float(STANCE_SPEED[light_stance])
		velocity = dir * speed * (1.0 + momentum_bonus) * move_mult * apex_mult * smother_mult * stance_mult

	# Цепной рывок Апекса (форма dash): автоматически дёргает игрока несколько раз
	if _apex_dash_chain > 0:
		_apex_chain_cd -= delta
		if _apex_chain_cd <= 0.0 and _dash_time <= 0.0:
			_dash_time = DASH_DUR
			_dash_dir = _facing
			_apex_dash_chain -= 1
			_apex_chain_cd = DASH_DUR + 0.05
			add_shake(4.0, 0.1)

	# Скольжение вдоль стен: если по прямой упёрлись — проверяем можно ли
	# скользить вбок. Это убирает «прилипание» в углах.
	if velocity != Vector2.ZERO:
		var hit := KinematicCollision2D.new()
		if test_move(global_transform, velocity * delta, hit):
			var along := velocity.slide(hit.get_normal())
			# В углу скольжение вдоль нормали тоже упирается в стену (диагональ
			# «влево+вниз» в внутренний угол) — игрок зависал. Проверяем, что
			# скольжение реально проходимо; иначе пробуем оси по отдельности.
			if along.length() > 0.01 and not test_move(global_transform, along.normalized() * velocity.length() * delta):
				velocity = along.normalized() * velocity.length()
			else:
				var vx := Vector2(velocity.x, 0.0)
				var vy := Vector2(0.0, velocity.y)
				if absf(vx.x) > 0.01 and not test_move(global_transform, vx * delta):
					velocity = vx
				elif absf(vy.y) > 0.01 and not test_move(global_transform, vy * delta):
					velocity = vy

	move_and_slide()

	var moved := velocity.length() * delta
	# Накапливаем пройденное расстояние для бонуса «Разгон»
	if GameConfig.progressive_enabled:
		_distance += moved
	# Накапливаем XP за движение (1 XP за каждые 300 пикселей)
	_xp_dist += moved
	if _xp_dist >= 300.0:
		GameConfig.add_xp(int(_xp_dist / 300.0))
		GameConfig.bump_stat("dist_total", 300 * int(_xp_dist / 300.0))   # «Лёгкие ноги»
		_xp_dist = fmod(_xp_dist, 300.0)

# =============================================================================
# ИГРОВАЯ ЛОГИКА (_process вызывается каждый кадр, не привязан к физике)
# =============================================================================

func _process(delta: float) -> void:
	# Камера и тряска работают всегда (в т.ч. когда игрок погас/до первого хода)
	_update_camera(delta)
	_update_shake(delta)

	if not active:
		return

	# --- Отсчёт перезарядок навыков ---
	flash_cd  = maxf(0.0, flash_cd  - delta)
	dash_cd   = maxf(0.0, dash_cd   - delta)
	sonar_cd  = maxf(0.0, sonar_cd  - delta)
	shield_cd = maxf(0.0, shield_cd - delta)
	guide_cd  = maxf(0.0, guide_cd  - delta)
	apex_cd   = maxf(0.0, apex_cd   - delta)
	smother_cd = maxf(0.0, smother_cd - delta)
	mirage_cd = maxf(0.0, mirage_cd - delta)
	breach_cd = maxf(0.0, breach_cd - delta)
	chrono_cd = maxf(0.0, chrono_cd - delta)
	pulse_cd  = maxf(0.0, pulse_cd  - delta)
	pulse_time = maxf(0.0, pulse_time - delta)
	summon_cd  = maxf(0.0, summon_cd  - delta)
	if _smother_time > 0.0:
		_smother_time -= delta
		if _smother_time <= 0.0 and _orb:
			_orb.modulate = Color(1, 1, 1, 1)   # разгорелись обратно

	# --- Отсчёт состояний Апекса ---
	if _apex_invuln_time > 0.0:
		_apex_invuln_time -= delta
	if _apex_speed_time > 0.0:
		_apex_speed_time -= delta

	# --- Пока игрок не сделал первое движение — игра «на паузе» ---
	# Свет не гаснет, события не идут. Камера/кулдауны/тряска работают.
	if not started:
		return

	# --- Накопительные пассивки ---
	# momentum_bonus растёт с пробегом; adapt_bonus — со временем выживания.
	# Обе обнуляются при старте нового уровня (через reload_current_scene).
	if GameConfig.progressive_enabled:
		_survival += delta
		momentum_bonus = clampf(_distance / DIST_FULL, 0.0, MOMENTUM_MAX)
		adapt_bonus    = clampf(_survival / ADAPT_FULL, 0.0, ADAPT_MAX)
	else:
		momentum_bonus = 0.0
		adapt_bonus    = 0.0

	# --- Отсчёт случайных событий лабиринта ---
	var fog     := _fog_time     > 0.0   # туман активен?
	var leak    := _leak_time    > 0.0   # утечка активна?
	var flicker := _flicker_time > 0.0   # мерцание активно?
	if fog:     _fog_time     -= delta
	if leak:    _leak_time    -= delta
	if flicker: _flicker_time -= delta

	# --- Щит ---
	if _shield_time > 0.0:
		_shield_time -= delta
		# Вращающееся пульсирующее кольцо; на исходе (≤1с) учащённо мигает
		_shield_vis.visible = true
		_shield_vis.rotation += delta * 1.8
		_shield_vis.scale = Vector2.ONE * (1.0 + 0.08 * sin(Time.get_ticks_msec() * 0.012))
		var blink: float = 1.0
		if _shield_time < 1.0:
			blink = 0.5 + 0.5 * absf(sin(Time.get_ticks_msec() * 0.02))
		_shield_vis.modulate.a = 0.9 * blink
	else:
		_shield_vis.visible = false

	# --- Отсчёт эффектов от врагов ---
	if _charge_block_time      > 0.0: _charge_block_time      -= delta
	if _enemy_block_time       > 0.0: _enemy_block_time       -= delta
	if _enemy_slow_charge_time > 0.0:
		_enemy_slow_charge_time -= delta
		if _enemy_slow_charge_time <= 0.0:
			_enemy_slow_charge_mult = 1.0
	if _enemy_slow_move_time   > 0.0:
		_enemy_slow_move_time -= delta
		if _enemy_slow_move_time <= 0.0:
			_enemy_slow_move_mult = 1.0

	# Копилка выживания — питает пассивку «Энергосбережение»
	_passive_time_acc += delta
	if _passive_time_acc >= 10.0:
		GameConfig.bump_stat("time_survived", 10)
		_passive_time_acc -= 10.0

	# --- Пассивный тик Воли ---
	will = minf(max_will, will + WILL_REGEN_PER_SEC * delta)

	# --- Расход света ---
	# Пополнение света даёт РАЗОВЫЙ «глоток» от энергокристалла (station.gd) —
	# раз в цикл восстановления. Стоять и бесконечно заряжаться больше нельзя.
	# Здесь — только расход.
	if _shield_time > 0.0 or _apex_invuln_time > 0.0:
		pass   # Щит или Апекс-неуязвимость: разрядки нет
	elif charge_sources > 0:
		pass   # Станция-убежище: пока стоишь в зоне кристалла, Свет не течёт
	else:
		# Разрядка. adapt_bonus снижает её (накопительная пассивка).
		# При утечке расход вырастает в 1.8 раза.
		var d := drain_per_sec * (1.0 - adapt_bonus) * stance_drain_mult()
		if leak:
			d *= 1.8
		energy = maxf(0.0, energy - d * delta)

	# Свет погас — смерть (если нет щита и нет неуязвимости от Апекса)
	if energy <= 0.0 and _shield_time <= 0.0 and _apex_invuln_time <= 0.0:
		active = false
		var g := get_parent()
		if g and g.has_method("on_player_death"):
			g.on_player_death()
		return

	# --- Вычисление параметров света ---

	# Буст радиуса от «кемпинга» на станции убран вместе с бесконечной зарядкой
	var radius_mult := 1.0
	# Туман сжимает радиус до 55%
	var fog_mult := 0.55 if fog else 1.0

	# Вспышка: flash_boost плавно убывает от максимума до 0 за FLASH_DUR секунд.
	# Ограничен потолком мастерства (1 + MASTERY_MAX*0.15 = 1.75) — Апекс задаёт
	# _flash_time с запасом ×4 ради ДЛИТЕЛЬНОСТИ (дольше держится на этом потолке,
	# затем гаснет как обычно), а не ради ещё большего радиуса.
	const FLASH_BOOST_CAP := 1.75
	if _flash_time > 0.0:
		_flash_time -= delta
		flash_boost = minf(_flash_time / FLASH_DUR, FLASH_BOOST_CAP)
	else:
		flash_boost = 0.0

	# lit — эффективная яркость для расчёта света; не ниже LIGHT_MIN (визуальный минимум)
	var lit := maxf(energy, LIGHT_MIN)
	# Стойка масштабирует радиус — это и есть «плата за информацию»: ярче видно
	# дальше. Тление ниже всё равно ужимает свет до искры поверх любой стойки.
	var base_scale    := (0.68 + lit * 0.45) * _radius_mult * radius_mult * fog_mult \
		* float(STANCE_RADIUS[light_stance])
	# ember_glow (0..1) — «Накал» в режиме забега: чем больше несёшь, тем ярче горишь
	# (и тем дальше тебя видят враги). В режиме «Уровни» всегда 0 — поведение не меняется.
	# ВАЖНО: жёсткий потолок на итоговый масштаб — НЕЗАВИСИМО от того, что именно
	# его раздувает (вспышка, Накал-жар, будущие пассивки). _light — единственный
	# оставшийся тенеотбрасывающий свет игрока (см. _cone выше), и именно рост
	# ЭТОГО масштаба выше ~9 на большом лабиринте роняет FPS до 2-3: тени
	# пересчитываются для каждой стены в радиусе каждый кадр. Даже обычная
	# вспышка (Q) на высоком мастерстве вспышки — без всякого Апекса — этот
	# потолок задевала, отсюда фриз и на простом Q.
	const MAX_LIGHT_SCALE := 9.0
	# _cone принципиально без теней (см. коммент у add_child(_cone) выше) — но
	# из-за этого в тесных нишах/дверных проёмах он подсвечивает то, что за
	# углом уже не видно через _light, и это читается как "светящийся шар
	# сквозь стену". Компромисс: включаем тени коню, только пока его масштаб
	# скромный (обычная ходьба) — при вспышке/Апексе (масштаб большой) тени
	# снова выключаются, чтобы не вернуть фриз, из-за которого их убрали.
	# Порог поднят 5.0 -> 7.0 вместе с появлением стоек (§29): Яркая стойка даёт
	# конусу масштаб ~5.9, то есть со старым порогом она молча отключала тени и
	# возвращала тот самый артефакт «шар сквозь стену». Вспышка (flash_boost до
	# 1.75 × FLASH_EXTRA_SCALE 6.0) всё равно уходит далеко за 7 — ради чего
	# порог и вводился, тот случай не изменился.
	const CONE_SHADOW_SCALE_LIMIT := 7.0
	var target_scale  := minf(base_scale + flash_boost * FLASH_EXTRA_SCALE + ember_glow * 0.5, MAX_LIGHT_SCALE)
	var target_energy := lit * 1.35 + flash_boost * FLASH_EXTRA_ENERGY + ember_glow * 0.6
	# Тление: свет сжимается до искры — ты почти слеп, но и тебя почти не видно.
	if _smother_time > 0.0:
		target_scale *= 0.18
		target_energy *= 0.25

	# Плавная интерполяция scale и energy — без резких скачков.
	# При активной вспышке интерполяция быстрее (0.2 вместо 0.12).
	_light.texture_scale = lerpf(_light.texture_scale, target_scale,  0.2 if _flash_time > 0.0 else 0.12)

	if flicker:
		# Мерцание: синусоидальное мигание со случайным смещением
		var flick: float = 0.4 + 0.55 * absf(sin(Time.get_ticks_msec() * 0.03))
		_light.energy = target_energy * flick
	else:
		_light.energy = lerpf(_light.energy, target_energy, 0.3 if _flash_time > 0.0 else 0.12)

	# Свет стен — чуть меньше радиусом, ярче основного, чтобы грани вспыхивали
	_wall_light.texture_scale = lerpf(_wall_light.texture_scale, target_scale * 0.72, 0.2 if _flash_time > 0.0 else 0.12)
	_wall_light.energy = _light.energy * 1.2

	# Прожектор — смотрит по направлению движения и бьёт заметно дальше радиуса
	_cone.rotation = _facing.angle()
	_cone.texture_scale = lerpf(_cone.texture_scale, target_scale * 1.8, 0.2 if _flash_time > 0.0 else 0.12)
	_cone.energy = _light.energy * 0.9
	_cone.shadow_enabled = _cone.texture_scale < CONE_SHADOW_SCALE_LIMIT

	# Лёгкое «дыхание» энергетического тела игрока
	if _orb:
		_orb.scale = Vector2.ONE * (1.0 + 0.05 * sin(Time.get_ticks_msec() * 0.005))

# =============================================================================
# НАВЫКИ
# Каждый _try_* проверяет кулдаун и наличие света, затем применяет эффект.
# =============================================================================

func _try_smother() -> void:
	if smother_cd > 0.0 or will < SMOTHER_COST * _skill_cost_mult:
		return
	will       -= SMOTHER_COST    * _skill_cost_mult
	smother_cd  = SMOTHER_COOLDOWN * _skill_cd_mult
	# Мастерство удлиняет тление
	_smother_time = SMOTHER_DUR * GameConfig.skill_power("smother")
	GameConfig.add_skill_use("smother")
	_emit_noise("smother")
	_play_skill_sfx("smother")
	if _orb:
		_orb.modulate = Color(0.55, 0.6, 0.75, 0.55)   # тело гаснет до уголька
	var g := get_parent()
	if g and g.has_method("flash_message"):
		g.flash_message(GameConfig.tt("… тлеешь — тьма не видит тебя", "… smothered — the dark can't see you"))

# ── Дары боссов ──────────────────────────────────────────────────────────────
func _try_mirage() -> void:
	if not GameConfig.skills_unlocked.get("mirage", false): return
	if mirage_cd > 0.0 or will < MIRAGE_COST * _skill_cost_mult:
		return
	var g := get_parent()
	if g == null or not g.has_method("mirage_decoy"):
		return
	will      -= MIRAGE_COST    * _skill_cost_mult
	mirage_cd  = MIRAGE_COOLDOWN * _skill_cd_mult
	# Мастерство расширяет радиус приманки
	g.mirage_decoy(global_position, current_floor, 600.0 * GameConfig.skill_power("mirage"))
	GameConfig.add_skill_use("mirage")
	_emit_noise("mirage")
	_play_skill_sfx("smother")

func _try_breach() -> void:
	if not GameConfig.skills_unlocked.get("breach", false): return
	if breach_cd > 0.0 or will < BREACH_COST * _skill_cost_mult:
		return
	var g := get_parent()
	if g == null or not g.has_method("breach_wall"):
		return
	# Ломается только если впереди реально стена — иначе ничего не тратим
	if not g.breach_wall(global_position, _facing, current_floor, 1):
		return
	will      -= BREACH_COST    * _skill_cost_mult
	# Ветвь «Сокрушение» ускоряет перезарядку Разлома
	breach_cd  = BREACH_COOLDOWN * _skill_cd_mult / GameConfig.skill_passive_mult("breach")
	GameConfig.add_skill_use("breach")
	_emit_noise("breach")
	add_shake(7.0, 0.25)
	_play_skill_sfx("apex")

func _try_chrono() -> void:
	if not GameConfig.skills_unlocked.get("chrono", false): return
	if chrono_cd > 0.0 or will < CHRONO_COST * _skill_cost_mult:
		return
	var g := get_parent()
	if g == null or not g.has_method("chrono_freeze"):
		return
	will      -= CHRONO_COST    * _skill_cost_mult
	chrono_cd  = CHRONO_COOLDOWN * _skill_cd_mult
	g.chrono_freeze(3.5 * GameConfig.skill_power("chrono"), current_floor)
	GameConfig.add_skill_use("chrono")
	_emit_noise("chrono")
	_play_skill_sfx("shield")

func _try_flash() -> void:
	if flash_cd > 0.0 or will < FLASH_COST * _skill_cost_mult:
		return
	will     -= FLASH_COST    * _skill_cost_mult
	flash_cd  = FLASH_COOLDOWN * _skill_cd_mult
	# Мастерство удлиняет вспышку (запускает расширение света в _process)
	_flash_time = FLASH_DUR * GameConfig.skill_power("flash")
	GameConfig.add_skill_use("flash")
	_emit_noise("flash")
	# Визуал: ударная волна-кольцо + короткая засветка экрана
	_spawn_burst(Color(0.78, 0.92, 1.0, 1.0), 8.5)
	_flash_screen(Color(0.8, 0.92, 1.0), 0.16)
	_play_skill_sfx("flash")
	add_shake(3.0, 0.12)
	# Прямое уведомление игры — для урона по боссу (надёжнее опроса по кадрам)
	var g := get_parent()
	if g and g.has_method("on_player_flash"):
		g.on_player_flash(global_position)

# --- Визуальные помощники навыков ---

const FIRE_TRAIL_HEAT_THRESHOLD := 0.6   # накал-синергия (§4): жар выше — рывок жжёт
const FIRE_TRAIL_SPAWN_INTERVAL := 0.18  # не на каждом кадре рывка — пятна не должны сливаться в одно
var _fire_trail_cd: float = 0.0

func _spawn_dash_ghost() -> void:
	if _orb == null or get_parent() == null:
		return
	var g := Sprite2D.new()
	g.texture = _orb.texture
	g.position = position
	g.modulate = Color(0.5, 0.85, 1.0, 0.7)
	g.z_index = -1
	get_parent().add_child(g)
	var tw := g.create_tween()
	tw.tween_property(g, "modulate:a", 0.0, 0.4)
	tw.parallel().tween_property(g, "scale", Vector2(0.4, 0.4), 0.4)
	tw.tween_callback(g.queue_free)
	_maybe_spawn_fire_trail()

# Накал-синергия «огненный след» (GAMEDESIGN.md §4) — высокий жар несомого
# Накала (режим «Накал»; вне его enemy_heat() всегда 0, ем — не сработает)
# оставляет за рывком короткоживущие огненные пятна, замедляющие врагов.
func _maybe_spawn_fire_trail() -> void:
	var g := get_parent()
	if g == null or not g.has_method("enemy_heat") or g.enemy_heat() < FIRE_TRAIL_HEAT_THRESHOLD:
		return
	if _fire_trail_cd > 0.0:
		return
	_fire_trail_cd = FIRE_TRAIL_SPAWN_INTERVAL
	var ft := Node2D.new()
	ft.set_script(load("res://fire_trail.gd"))
	ft.position = position
	g.add_child(ft)

func _spawn_burst(col: Color, max_scale: float) -> void:
	if get_parent() == null:
		return
	var b := Node2D.new()
	b.set_script(load("res://burst.gd"))
	b.color = col
	b.max_scale = max_scale
	b.position = position
	get_parent().add_child(b)

func _flash_screen(col: Color, strength: float) -> void:
	var g := get_parent()
	if g and g.has_method("flash_screen"):
		g.flash_screen(col, strength)

# Звук активного навыка — проигрывает главная сцена (она владеет аудиоплеерами).
func _play_skill_sfx(which: String) -> void:
	var g := get_parent()
	if g and g.has_method("play_skill_sfx"):
		g.play_skill_sfx(which)

func _try_dash() -> void:
	if dash_cd > 0.0 or will < DASH_COST * _skill_cost_mult:
		return
	will    -= DASH_COST    * _skill_cost_mult
	dash_cd  = DASH_COOLDOWN * _skill_cd_mult
	# Мастерство удлиняет рывок
	_dash_time = DASH_DUR * GameConfig.skill_power("dash")
	_dash_dir  = _facing     # летим туда, куда смотрели последний раз
	# КОМБО «Световое копьё» (GAMEDESIGN п.4): рывок во время вспышки —
	# дальность ×1.5. Награда за осознанное сочетание, а не за спам кнопок.
	if _flash_time > 0.0:
		_dash_time *= 1.5
		_spawn_burst(Color(0.85, 0.95, 1.0, 1.0), 5.0)
		var gl := get_parent()
		if gl and gl.has_method("flash_message"):
			gl.flash_message(GameConfig.tt("Световое копьё!", "Spear of Light!"))
		# Отдельный хук от голой Вспышки — супербоссу (§25) важно различать
		# комбо и обычный навык (см. main.gd::on_player_light_spear).
		if gl and gl.has_method("on_player_light_spear"):
			gl.on_player_light_spear(global_position)
	_play_skill_sfx("dash")
	add_shake(5.0, 0.12)
	GameConfig.add_skill_use("dash")
	_emit_noise("dash")

func _try_sonar() -> void:
	if not GameConfig.skills_unlocked.get("sonar", false): return
	if sonar_cd > 0.0 or will < SONAR_COST * _skill_cost_mult:
		return
	will    -= SONAR_COST    * _skill_cost_mult
	sonar_cd  = SONAR_COOLDOWN * _skill_cd_mult
	# Создаём узел сонара прямо в сцене (он сам знает, как расширяться и умереть)
	var s := Node2D.new()
	s.set_script(load("res://sonar.gd"))
	s.position = global_position
	# Мастерство масштабирует послесвечение
	var s_mult := GameConfig.skill_power("sonar")
	# КОМБО «Всевидение» (п.4): сонар во время Озарения — волна вдвое шире и
	# глушит всех врагов на пару секунд (весь этаж открыт + враги обезврежены).
	var g_par := get_parent()
	if g_par and g_par.has_method("is_reveal_active") and g_par.is_reveal_active():
		s_mult *= 2.5
		for e in get_tree().get_nodes_in_group("enemy"):
			if is_instance_valid(e) and "stun_time" in e:
				e.stun_time = maxf(e.stun_time, 2.0)
		if g_par.has_method("flash_message"):
			g_par.flash_message(GameConfig.tt("Всевидение!", "All-Seeing!"))
	s.set_meta("mastery_mult", s_mult)
	get_parent().add_child(s)
	GameConfig.add_skill_use("sonar")
	_emit_noise("sonar")
	_play_skill_sfx("sonar")

func _try_guide() -> void:
	if not GameConfig.skills_unlocked.get("guide", false): return
	if guide_cd > 0.0 or will < GUIDE_COST * _skill_cost_mult:
		return
	var g := get_parent()
	if g == null or not g.has_method("guide_path_to_exit"):
		return
	# Запрашиваем путь у лабиринта; если выход недостижим — навык не тратится
	var path: PackedVector2Array = g.guide_path_to_exit(global_position, current_floor)
	if path.size() < 2:
		return
	will    -= GUIDE_COST    * _skill_cost_mult
	guide_cd  = GUIDE_COOLDOWN * _skill_cd_mult
	# Spark — летящий огонёк, который сам двигается по path
	var spark := Node2D.new()
	spark.set_script(load("res://spark.gd"))
	spark.path_points = path
	g.add_child(spark)
	GameConfig.add_skill_use("guide")
	_emit_noise("guide")
	_play_skill_sfx("guide")

const SUMMON_COST     := 0.5
const SUMMON_COOLDOWN := 20.0

# §25 GAMEDESIGN.md — навык призыва (ОТДЕЛЬНАЯ витрина от обычного магазина/
# Апекса, см. GameConfig.summon_unlocked/skills_menu.gd::_build_summon_section).
func _try_summon() -> void:
	if not GameConfig.summon_unlocked.get("mirror_ally", false):
		return
	if summon_cd > 0.0 or will < SUMMON_COST * _skill_cost_mult:
		return
	var g := get_parent()
	if g == null or not g.has_method("summon_ally"):
		return
	if not g.summon_ally():
		return   # лимит союзников — навык не тратится
	will      -= SUMMON_COST * _skill_cost_mult
	summon_cd  = SUMMON_COOLDOWN * _skill_cd_mult
	GameConfig.add_skill_use("mirror_ally")   # мастерство призыва — сила/живучесть союзника
	_emit_noise("mirror_ally")
	_play_skill_sfx("guide")   # переиспользуем звук искры — отдельного пока нет
	add_shake(3.0, 0.12)

func _try_shield() -> void:
	if not GameConfig.skills_unlocked.get("shield", false): return
	if shield_cd > 0.0 or will < SHIELD_COST * _skill_cost_mult:
		return
	will     -= SHIELD_COST    * _skill_cost_mult
	shield_cd  = SHIELD_COOLDOWN * _skill_cd_mult
	# Мастерство удлиняет щит
	_shield_time = SHIELD_DUR * GameConfig.skill_power("shield")
	GameConfig.add_skill_use("shield")
	_emit_noise("shield")
	_play_skill_sfx("shield")
	_spawn_burst(Color(0.45, 0.72, 1.0, 1.0), 3.6)   # вспышка постановки щита

func _try_reveal() -> void:
	if not GameConfig.skills_unlocked.get("reveal", false): return
	# Озарение доступно только при полном заряде (накапливается на станциях)
	if reveal_charge < 1.0:
		return
	reveal_charge = 0.0
	var g := get_parent()
	if g and g.has_method("reveal"):
		# Мастерство удлиняет озарение
		g.reveal(REVEAL_DURATION * GameConfig.skill_power("reveal"))
	_play_skill_sfx("reveal")
	GameConfig.add_skill_use("reveal")
	_emit_noise("reveal")

# Пульс (B) — на 10 секунд (дольше с мастерством) включает звуковой ориентир:
# main.gd раз в несколько секунд считает путь по коридору до выхода и играет
# «пик» — чаще и звонче, чем ближе. Сам навык не светит и не движется —
# вся логика пингов в main.gd:_update_pulse (там же выход и BFS-путь).
func _try_pulse() -> void:
	if not GameConfig.skills_unlocked.get("pulse", false): return
	if pulse_cd > 0.0 or will < PULSE_COST * _skill_cost_mult:
		return
	will      -= PULSE_COST     * _skill_cost_mult
	pulse_cd   = PULSE_COOLDOWN * _skill_cd_mult
	pulse_time = PULSE_DUR * GameConfig.skill_power("pulse")
	GameConfig.add_skill_use("pulse")
	_emit_noise("pulse")
	_play_skill_sfx("pulse")

# =============================================================================
# ВНЕШНИЕ ВОЗДЕЙСТВИЯ (вызываются другими узлами)
# =============================================================================

# Тьма-преследователь глушит зарядку на станции на короткое время (обновляется каждый кадр).
# ── АПЕКС ────────────────────────────────────────────────────────────────────
# Супернавык. Открывается, когда куплены все 7 активных навыков.
# Принимает форму того навыка, у которого выше всего мастерство.
# Второй по мастерству даёт «эхо» — слабую добавку.
# Условие активации: срабатывает ТОЛЬКО если рядом есть реальная угроза — хотя
# бы один враг сейчас активно гонится (см. main.gd:has_active_chaser). Иначе
# это была бы кнопка «зачистить этаж» на кулдауне — вместо этого Апекс работает
# только как экстренный ответ на реальную опасность; энергия и кулдаун не
# тратятся, если условие не выполнено — можно сразу попробовать снова, когда
# станет по-настоящему горячо.
func _try_apex() -> void:
	if not GameConfig.skills_unlocked.get("apex", false):
		return
	if apex_cd > 0.0 or will < APEX_COST * _skill_cost_mult:
		return
	var g0 := get_parent()
	if g0 == null or not g0.has_method("has_active_chaser") or not g0.has_active_chaser():
		if g0 and g0.has_method("flash_message"):
			g0.flash_message(GameConfig.tt("Апекс молчит — нет реальной погони", "Apex stays silent — no real chase"))
		return
	will   -= APEX_COST * _skill_cost_mult
	apex_cd = APEX_COOLDOWN * _skill_cd_mult

	var top := GameConfig.top_mastered(2)
	if top.is_empty():
		return
	var main_form: String = top[0]
	var echo_form: String = top[1] if top.size() > 1 else ""

	_apply_apex_form(main_form, true)
	if echo_form != "" and echo_form != main_form:
		_apply_apex_form(echo_form, false)

	_play_skill_sfx("apex")
	add_shake(8.0, 0.3)

func _apply_apex_form(form: String, is_main: bool) -> void:
	# main = полный эффект, echo = ослабленный.
	# amp — сила Апекса, унаследованная от навыка-формы: мастерство навыка и
	# уровень его ветви-пассивки напрямую усиливают форму (см. GameConfig.apex_power).
	var pwr := 1.0 if is_main else 0.4
	var amp := GameConfig.apex_power(form)
	match form:
		"flash":
			# СВЕТОВОЙ УДАР: свет держится дольше (радиус ограничен тем же потолком,
			# что и у мастер-вспышки — см. flash_boost cap в _physics_process/этот
			# файл), плюс ускорение, и ГЛАВНОЕ — глушит всех врагов рядом на
			# несколько секунд. Отличает Апекс от простого света и от бесплатного
			# события «Просвет» (то теперь лишь расширяет радиус видимости).
			_flash_time = FLASH_DUR * (4.0 if is_main else 1.5) * amp
			if is_main:
				_apex_speed_time = 3.0 * amp
				_apex_speed_mult = 1.5
			var gf := get_parent()
			var flash_r := (420.0 if is_main else 260.0) * amp
			if gf and gf.has_method("apex_flash_shock"):
				gf.apex_flash_shock(flash_r, 3.0 if is_main else 1.5)
			if gf and gf.has_method("apex_overload"):
				gf.apex_overload(flash_r)
		"dash":
			# ТАРАННЫЙ РЫВОК: серия рывков подряд, уничтожает гонящихся вблизи
			# в момент активации — «прошёл сквозь погоню».
			_apex_dash_chain = 3 if is_main else 1
			_apex_chain_cd = 0.0
			var gd_ := get_parent()
			if gd_ and gd_.has_method("apex_overload"):
				gd_.apex_overload((150.0 if is_main else 90.0) * amp)
		"sonar":
			# МЕГА-СОНАР: огромный долгий сонар, «выжигает» всех гонящихся на этаже
			var s := Node2D.new()
			s.set_script(load("res://sonar.gd"))
			s.position = global_position
			s.set_meta("mastery_mult", (3.0 if is_main else 1.5) * amp)
			get_parent().add_child(s)
			var gs := get_parent()
			if gs and gs.has_method("apex_overload"):
				gs.apex_overload(500.0 * amp, is_main)   # эхо — только в большом, но не всём радиусе
		"shield":
			# БЕССМЕРТИЕ: длительная неуязвимость + восполнение света. Пока активна —
			# контакт с врагом не просто замораживает его, а уничтожает (см.
			# pursuer.gd:_on_hit — читает is_apex_shielded()).
			_apex_invuln_time = maxf(_apex_invuln_time, 10.0 * pwr * amp)
			if is_main:
				energy = max_energy
		"guide":
			# ТЕЛЕПОРТ К ВЫХОДУ: сначала «выжигаем» тех, кто гнался за тобой здесь —
			# затем переносим игрока к выходу на текущем этаже.
			var g := get_parent()
			if g and g.has_method("apex_overload"):
				g.apex_overload(0.0, true)
			if g and g.has_method("apex_teleport_to_exit"):
				g.apex_teleport_to_exit(is_main)
		"mirage":
			# ВЕЛИКИЙ ОБМАН: приманки по всему этажу + сам игрок тлеет (невидим)
			var gm := get_parent()
			if gm and gm.has_method("mirage_decoy"):
				gm.mirage_decoy(global_position, current_floor, 99999.0)
			_smother_time = maxf(_smother_time, (4.0 if is_main else 2.0) * amp)
			if _orb:
				_orb.modulate = Color(0.55, 0.6, 0.75, 0.55)
		"breach":
			# ЗЕМЛЕТРЯСЕНИЕ: пролом нескольких стен по направлению взгляда
			var gb := get_parent()
			if gb and gb.has_method("breach_wall"):
				gb.breach_wall(global_position, _facing, current_floor, 3 if is_main else 1)
			if gb and gb.has_method("apex_overload"):
				gb.apex_overload((160.0 if is_main else 90.0) * amp)
		"chrono":
			# ОСТАНОВКА ВРЕМЕНИ: долгая заморозка всего этажа + глоток Воли
			var gc_ := get_parent()
			if gc_ and gc_.has_method("chrono_freeze"):
				gc_.chrono_freeze((8.0 if is_main else 4.0) * amp, current_floor)
			if is_main:
				will = minf(max_will, will + 0.5)
		"reveal":
			# ДОЛГОЕ ОЗАРЕНИЕ: заметно дольше обычного, но не на целую минуту —
			# тьма должна вернуться раньше, чем закончится перезарядка Апекса,
			# иначе давление тьмы пропадает слишком надолго. Полная видимость —
			# гонящихся за тобой некуда спрятать, поэтому этаж чистится от них.
			var g := get_parent()
			if g and g.has_method("reveal"):
				g.reveal((12.0 if is_main else 6.0) * amp)
			if g and g.has_method("apex_overload"):
				g.apex_overload(0.0, true)
		"pulse":
			# НЕЗАТУХАЮЩИЙ ПУЛЬС: звуковой ориентир не смолкает почти до конца
			# этажа + выжигает тех, кто гонится за тобой прямо сейчас — по духу
			# похоже на Апекс-Искру, только держит слух, а не зрение.
			pulse_time = maxf(pulse_time, (60.0 if is_main else 20.0) * amp)
			var gp := get_parent()
			if gp and gp.has_method("apex_overload"):
				gp.apex_overload(0.0, true)

func block_charge(dur: float) -> void:
	_charge_block_time = maxf(_charge_block_time, dur)

# Активен ли защитный щит (или неуязвимость Апекса).
func is_shielded() -> bool:
	return _shield_time > 0.0 or _apex_invuln_time > 0.0

# Именно Апекс-форма Щита (не обычный щит) — pursuer.gd читает это, чтобы
# решить: заморозить врага при контакте (обычный щит) или уничтожить (Апекс).
func is_apex_shielded() -> bool:
	return _apex_invuln_time > 0.0

# Идёт ли сейчас рывок — pursuer.gd читает это для «таранного» урона при
# контакте во время рывка (вместо урона по игроку).
func is_dashing() -> bool:
	return _dash_time > 0.0

# Тлеем ли сейчас (пригашены).
func is_smothered() -> bool:
	return _smother_time > 0.0

# В тумане ли сейчас (локальная клякса или событие) — main ужимает виньетку.
func is_fogged() -> bool:
	return _fog_time > 0.0

# ЗАМЕТНОСТЬ для врагов (множитель их радиуса обнаружения, pursuer.gd).
# Ты — свет: чем ярче горишь, тем дальше тебя видно. Вспышка и несомый Накал
# демаскируют; Тление прячет почти полностью.
func visibility_factor() -> float:
	# Тление — сильнее любой стойки: это и есть его смысл как аварийной кнопки.
	if _smother_time > 0.0:
		return SMOTHER_VIS
	# Потолок поднят с 1.6 до 2.2: без этого Яркая стойка упиралась в тот же
	# предел, что и обычная вспышка, и «тебя видно издалека» не работало.
	var v := (1.0 + flash_boost * 0.35 + ember_glow * 0.45) * float(STANCE_VIS[light_stance])
	return clampf(v, 0.4, 2.2)

# Множитель расхода Света от стойки. Отдельной функцией, а не чтением массива
# по месту: HUD показывает эту же цифру игроку (см. _update_stance_hud).
# [GAMEDESIGN §36] Насколько далеко игрок СЛЫШИТ врагов. Замыкает треугольник
# со стойкой света (§29) и шумом навыков (§31): раздутый свет гудит и глушит
# тебя самого, притушенный — наоборот, ты крадёшься и слушаешь. Тление —
# буквально «задержать дыхание», поэтому слышно лучше всего.
const STANCE_HEARING := [1.35, 1.0, 0.8]
const SMOTHER_HEARING := 1.5

func hearing_mult() -> float:
	var m: float = float(STANCE_HEARING[light_stance])
	if _smother_time > 0.0:
		m = maxf(m, SMOTHER_HEARING)
	return m

func stance_drain_mult() -> float:
	return float(STANCE_DRAIN[light_stance])

func stance_name() -> String:
	var names: Array = STANCE_NAMES_EN if GameConfig.locale == "en" else STANCE_NAMES
	return str(names[light_stance])

func stance_color() -> Color:
	return STANCE_COLORS[light_stance]

# Смена стойки. Публичная — её зовут и клавиши, и колесо мыши, и HUD.
func set_light_stance(idx: int) -> void:
	var next: int = clampi(idx, STANCE_DIM, STANCE_BRIGHT)
	if next == light_stance or not active:
		return
	light_stance = next
	var g := get_parent()
	if g and g.has_method("on_light_stance_changed"):
		g.on_light_stance_changed(light_stance)

# Удар врага: прямой урон по свету + тряска + красный отклик по углам.
# Щит и неуязвимость Апекса полностью гасят удар.
func hit_by_enemy(light_cost: float) -> void:
	if is_shielded():
		return
	energy = maxf(0.0, energy - light_cost)
	add_shake(9.0, 0.32)
	var g := get_parent()
	if g and g.has_method("enemy_hit_fx"):
		g.enemy_hit_fx()

# Применяет эффект от врага с учётом накопленного иммунитета.
# Каждый контакт увеличивает счётчик GameConfig.enemy_encounters на 1,
# иммунитет растёт: +1% за встречу, максимум 50%.
# Например, при 30 встречах длительность эффектов сокращается на 30%.
func apply_enemy_effect(kind: String, base_dur: float, strength: float = 0.0) -> void:
	GameConfig.enemy_encounters += 1
	var immunity := clampf(GameConfig.enemy_encounters * 0.01, 0.0, 0.50)
	var dur := base_dur * (1.0 - immunity)
	match kind:
		"block_charge":
			_enemy_block_time = maxf(_enemy_block_time, dur)
		"slow_charge":
			# strength = множитель зарядки (например 0.3 = до 30%)
			_enemy_slow_charge_time = maxf(_enemy_slow_charge_time, dur)
			_enemy_slow_charge_mult = minf(_enemy_slow_charge_mult, strength) if _enemy_slow_charge_time > 0.0 else strength
		"slow_move":
			# strength = множитель скорости (например 0.5 = до 50%)
			_enemy_slow_move_time = maxf(_enemy_slow_move_time, dur)
			_enemy_slow_move_mult = minf(_enemy_slow_move_mult, strength) if _enemy_slow_move_time > 0.0 else strength

# Пополнение Воли извне (осколки — main.gd, глоток станции — station.gd).
func add_will(amount: float) -> void:
	will = minf(max_will, will + amount)

# Случайные события лабиринта (туман, утечка, мерцание) — применяются из main.gd.
# maxf гарантирует, что новый вызов не сократит уже идущий эффект.
func apply_event(kind: String, dur: float) -> void:
	match kind:
		"fog":     _fog_time     = maxf(_fog_time,     dur)
		"leak":    _leak_time    = maxf(_leak_time,    dur)
		"flicker": _flicker_time = maxf(_flicker_time, dur)

# =============================================================================
# ВОЗРОЖДЕНИЕ
# Вызывается main.gd после потери жизни. Переносит игрока на последний чекпоинт,
# восстанавливает свет и сбрасывает все активные эффекты.
# =============================================================================

func respawn(pos: Vector2, floor_idx: int) -> void:
	global_position = pos
	current_floor   = floor_idx
	energy          = max_energy
	will            = max_will

	# Мгновенно восстанавливаем визуальный свет (иначе была бы «поездка» из темноты)
	_light.energy          = max_energy * 1.35
	_light.texture_scale   = (0.68 + max_energy * 0.45) * _radius_mult
	_wall_light.energy     = _light.energy
	_wall_light.texture_scale = _light.texture_scale * 0.7
	_cone.energy           = _light.energy * 0.9
	_cone.texture_scale    = _light.texture_scale * 1.8

	# Небольшая задержка — предотвращает мгновенное повторное использование двери
	teleport_cooldown = 0.5
	charge_sources    = 0

	# Сброс всех таймеров эффектов
	_charge_block_time     = 0.0
	_charge_time           = 0.0
	_flash_time            = 0.0
	_dash_time             = 0.0
	_shield_time           = 0.0
	_fog_time              = 0.0
	_leak_time             = 0.0
	_flicker_time          = 0.0
	_enemy_block_time      = 0.0
	_enemy_slow_charge_time = 0.0
	_enemy_slow_charge_mult = 1.0
	_enemy_slow_move_time  = 0.0
	_enemy_slow_move_mult   = 1.0
	_apex_invuln_time = 0.0
	_apex_speed_time  = 0.0
	_apex_dash_chain  = 0
	_smother_time     = 0.0
	smother_cd        = 0.0
	if _orb:
		_orb.modulate = Color(1, 1, 1, 1)
	started = false   # после возрождения снова ждём первого движения

	active = true
	snap_camera()
