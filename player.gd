extends CharacterBody2D

# =============================================================================
# ЭКСПОРТИРУЕМЫЕ ПАРАМЕТРЫ
# Их можно менять прямо в инспекторе Godot, не трогая код.
# =============================================================================

@export var speed: float = 320.0          # базовая скорость передвижения (пикселей/с)
@export var max_energy: float = 1.7       # максимальный запас света (1.0 = полный)
@export var drain_per_sec: float = 0.055  # скорость расхода света в секунду (без станций)
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

# Сонар (E) — световое кольцо, раскрывает лабиринт вокруг
const SONAR_COST     := 0.30
const SONAR_COOLDOWN := 5.0

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

# Апекс (H) — супернавык, открывается когда куплены все 6 активных навыков
const APEX_COST     := 0.5         # стоимость в энергии
const APEX_COOLDOWN := 30.0        # длинный кулдаун — это «ультимейт»

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
var charge_sources: int = 0                # сколько зон станций одновременно перекрывают игрока
var active: bool = true                    # false = игрок погас (нет управления, нет обработки)
var current_floor: int = 0                 # номер этажа, на котором находится игрок
var teleport_cooldown: float = 0.0         # блокировка повторного телепорта сразу после перехода
var touch_dir: Vector2 = Vector2.ZERO      # направление с виртуального джойстика (мобильное управление)
var _charge_block_time: float = 0.0        # враг типа SLOW на некоторое время лишает зарядки через станцию

# --- Кулдауны навыков (читаются HUD-ом для отображения) ---
var flash_cd: float  = 0.0
var dash_cd: float   = 0.0
var sonar_cd: float  = 0.0
var shield_cd: float = 0.0
var guide_cd: float  = 0.0
var apex_cd: float   = 0.0
var reveal_charge: float = 0.0   # заряд озарения (0.0 … 1.0); при 1.0 можно активировать

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
	# Бросает тени — луч честно упирается в стены, как настоящий фонарь.
	const CONE_SIZE := 384
	_cone = PointLight2D.new()
	_cone.texture = MazeTextures.make_cone_light(CONE_SIZE, 40.0)
	_cone.offset = Vector2(CONE_SIZE * 0.5, 0.0)
	_cone.color = Color(0.92, 0.97, 1.0)
	_cone.height = 0.35
	_cone.energy = energy
	_cone.texture_scale = 1.0
	_cone.shadow_enabled = true
	add_child(_cone)

	# Кольцо щита (скрыто до активации)
	_shield_vis = Sprite2D.new()
	_shield_vis.texture = MazeTextures.make_ring(80)
	_shield_vis.modulate = Color(0.4, 0.7, 1.0, 0.9)
	_shield_vis.visible = false
	add_child(_shield_vis)

	# Камера со сглаживанием
	_cam = Camera2D.new()
	_cam.position_smoothing_enabled = true
	add_child(_cam)

# Мгновенно подтянуть камеру к игроку (вызывается после телепорта/возрождения,
# чтобы не было «поездки» камеры из старой позиции).
func snap_camera() -> void:
	if _cam:
		_cam.reset_smoothing()

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
	var p: Dictionary = GameConfig.passives
	if p.get("save", false):
		drain_per_sec *= 0.7       # «Энергосбережение»: расход света −30%
	if p.get("capacity", false):
		max_energy *= 1.3          # «Ёмкость»: максимальный заряд +30%
	if p.get("charge", false):
		charge_per_sec *= 1.5      # «Быстрая зарядка»: скорость зарядки +50%
	if p.get("range", false):
		_radius_mult = 1.25        # «Дальний свет»: радиус свечения +25%
	if p.get("legs", false):
		speed *= 1.15              # «Лёгкие ноги»: скорость +15%
	if p.get("magic", false):
		_skill_cost_mult = 0.7     # «Эффективная магия»: навыки дешевле на 30%
		_skill_cd_mult   = 0.75    #   и перезаряжаются быстрее на 25%

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
			KEY_C:     _try_shield()
			KEY_F:     _try_reveal()
			KEY_G:     _try_guide()
			KEY_H:     _try_apex()

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
		velocity = dir * speed * (1.0 + momentum_bonus) * move_mult * apex_mult

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
			if along.length() > 0.01:
				velocity = along.normalized() * velocity.length()

	move_and_slide()

	var moved := velocity.length() * delta
	# Накапливаем пройденное расстояние для бонуса «Разгон»
	if GameConfig.progressive_enabled:
		_distance += moved
	# Накапливаем XP за движение (1 XP за каждые 300 пикселей)
	_xp_dist += moved
	if _xp_dist >= 300.0:
		GameConfig.add_xp(int(_xp_dist / 300.0))
		_xp_dist = fmod(_xp_dist, 300.0)

# =============================================================================
# ИГРОВАЯ ЛОГИКА (_process вызывается каждый кадр, не привязан к физике)
# =============================================================================

func _process(delta: float) -> void:
	# Тряска работает даже когда игрок погас (эффект смерти)
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

	# --- Расход света ---
	# Пополнение света даёт РАЗОВЫЙ «глоток» от энергокристалла (station.gd) —
	# раз в цикл восстановления. Стоять и бесконечно заряжаться больше нельзя.
	# Здесь — только расход.
	if _shield_time > 0.0 or _apex_invuln_time > 0.0:
		pass   # Щит или Апекс-неуязвимость: разрядки нет
	else:
		# Разрядка. adapt_bonus снижает её (накопительная пассивка).
		# При утечке расход вырастает в 1.8 раза.
		var d := drain_per_sec * (1.0 - adapt_bonus)
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

	# Вспышка: flash_boost плавно убывает от 1 до 0 за FLASH_DUR секунд
	var flash_boost := 0.0
	if _flash_time > 0.0:
		_flash_time -= delta
		flash_boost = _flash_time / FLASH_DUR

	# lit — эффективная яркость для расчёта света; не ниже LIGHT_MIN (визуальный минимум)
	var lit := maxf(energy, LIGHT_MIN)
	var base_scale    := (0.68 + lit * 0.45) * _radius_mult * radius_mult * fog_mult
	var target_scale  := base_scale + flash_boost * FLASH_EXTRA_SCALE
	var target_energy := lit * 1.35 + flash_boost * FLASH_EXTRA_ENERGY

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

	# Лёгкое «дыхание» энергетического тела игрока
	if _orb:
		_orb.scale = Vector2.ONE * (1.0 + 0.05 * sin(Time.get_ticks_msec() * 0.005))

# =============================================================================
# НАВЫКИ
# Каждый _try_* проверяет кулдаун и наличие света, затем применяет эффект.
# =============================================================================

func _try_flash() -> void:
	if flash_cd > 0.0 or energy < FLASH_COST * _skill_cost_mult:
		return
	energy   -= FLASH_COST    * _skill_cost_mult
	flash_cd  = FLASH_COOLDOWN * _skill_cd_mult
	# Мастерство удлиняет вспышку (запускает расширение света в _process)
	_flash_time = FLASH_DUR * GameConfig.mastery_bonus("flash")
	GameConfig.add_skill_use("flash")
	# Визуал: ударная волна-кольцо + короткая засветка экрана
	_spawn_burst(Color(0.78, 0.92, 1.0, 1.0), 8.5)
	_flash_screen(Color(0.8, 0.92, 1.0), 0.16)
	add_shake(3.0, 0.12)

# --- Визуальные помощники навыков ---

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
	if dash_cd > 0.0 or energy < DASH_COST * _skill_cost_mult:
		return
	energy  -= DASH_COST    * _skill_cost_mult
	dash_cd  = DASH_COOLDOWN * _skill_cd_mult
	# Мастерство удлиняет рывок
	_dash_time = DASH_DUR * GameConfig.mastery_bonus("dash")
	_dash_dir  = _facing     # летим туда, куда смотрели последний раз
	add_shake(5.0, 0.12)
	GameConfig.add_skill_use("dash")

func _try_sonar() -> void:
	if not GameConfig.skills_unlocked.get("sonar", false): return
	if sonar_cd > 0.0 or energy < SONAR_COST * _skill_cost_mult:
		return
	energy  -= SONAR_COST    * _skill_cost_mult
	sonar_cd  = SONAR_COOLDOWN * _skill_cd_mult
	# Создаём узел сонара прямо в сцене (он сам знает, как расширяться и умереть)
	var s := Node2D.new()
	s.set_script(load("res://sonar.gd"))
	s.position = global_position
	# Мастерство масштабирует послесвечение
	s.set_meta("mastery_mult", GameConfig.mastery_bonus("sonar"))
	get_parent().add_child(s)
	GameConfig.add_skill_use("sonar")
	_play_skill_sfx("sonar")

func _try_guide() -> void:
	if not GameConfig.skills_unlocked.get("guide", false): return
	if guide_cd > 0.0 or energy < GUIDE_COST * _skill_cost_mult:
		return
	var g := get_parent()
	if g == null or not g.has_method("guide_path_to_exit"):
		return
	# Запрашиваем путь у лабиринта; если выход недостижим — навык не тратится
	var path: PackedVector2Array = g.guide_path_to_exit(global_position, current_floor)
	if path.size() < 2:
		return
	energy  -= GUIDE_COST    * _skill_cost_mult
	guide_cd  = GUIDE_COOLDOWN * _skill_cd_mult
	# Spark — летящий огонёк, который сам двигается по path
	var spark := Node2D.new()
	spark.set_script(load("res://spark.gd"))
	spark.path_points = path
	g.add_child(spark)
	GameConfig.add_skill_use("guide")
	_play_skill_sfx("guide")

func _try_shield() -> void:
	if not GameConfig.skills_unlocked.get("shield", false): return
	if shield_cd > 0.0 or energy < SHIELD_COST * _skill_cost_mult:
		return
	energy   -= SHIELD_COST    * _skill_cost_mult
	shield_cd  = SHIELD_COOLDOWN * _skill_cd_mult
	# Мастерство удлиняет щит
	_shield_time = SHIELD_DUR * GameConfig.mastery_bonus("shield")
	GameConfig.add_skill_use("shield")
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
		g.reveal(REVEAL_DURATION * GameConfig.mastery_bonus("reveal"))
	GameConfig.add_skill_use("reveal")

# =============================================================================
# ВНЕШНИЕ ВОЗДЕЙСТВИЯ (вызываются другими узлами)
# =============================================================================

# Тьма-преследователь глушит зарядку на станции на короткое время (обновляется каждый кадр).
# ── АПЕКС ────────────────────────────────────────────────────────────────────
# Супернавык. Открывается, когда куплены все 6 активных навыков.
# Принимает форму того навыка, у которого выше всего мастерство.
# Второй по мастерству даёт «эхо» — слабую добавку.
func _try_apex() -> void:
	if not GameConfig.skills_unlocked.get("apex", false):
		return
	if apex_cd > 0.0 or energy < APEX_COST * _skill_cost_mult:
		return
	energy -= APEX_COST * _skill_cost_mult
	apex_cd = APEX_COOLDOWN * _skill_cd_mult

	var top := GameConfig.top_mastered(2)
	if top.is_empty():
		return
	var main_form: String = top[0]
	var echo_form: String = top[1] if top.size() > 1 else ""

	_apply_apex_form(main_form, true)
	if echo_form != "" and echo_form != main_form:
		_apply_apex_form(echo_form, false)

	add_shake(8.0, 0.3)

func _apply_apex_form(form: String, is_main: bool) -> void:
	# main = полный эффект, echo = ослабленный
	var pwr := 1.0 if is_main else 0.4
	match form:
		"flash":
			# СВЕРХВСПЫШКА: огромный круг света на несколько секунд + ускорение
			_flash_time = FLASH_DUR * (4.0 if is_main else 1.5)
			if is_main:
				_apex_speed_time = 3.0
				_apex_speed_mult = 1.5
		"dash":
			# ЦЕПНОЙ РЫВОК: серия рывков подряд
			_apex_dash_chain = 3 if is_main else 1
			_apex_chain_cd = 0.0
		"sonar":
			# МЕГА-СОНАР: огромный долгий сонар
			var s := Node2D.new()
			s.set_script(load("res://sonar.gd"))
			s.position = global_position
			s.set_meta("mastery_mult", 3.0 if is_main else 1.5)
			get_parent().add_child(s)
		"shield":
			# БЕССМЕРТИЕ: длительная неуязвимость + восполнение света
			_apex_invuln_time = maxf(_apex_invuln_time, 10.0 * pwr)
			if is_main:
				energy = max_energy
		"guide":
			# ТЕЛЕПОРТ К ВЫХОДУ: переносим игрока к выходу на текущем этаже
			var g := get_parent()
			if g and g.has_method("apex_teleport_to_exit"):
				g.apex_teleport_to_exit(is_main)
		"reveal":
			# ВЕЧНОЕ ОЗАРЕНИЕ: очень долгое озарение
			var g := get_parent()
			if g and g.has_method("reveal"):
				g.reveal(20.0 if is_main else 8.0)

func block_charge(dur: float) -> void:
	_charge_block_time = maxf(_charge_block_time, dur)

# Активен ли защитный щит (или неуязвимость Апекса).
func is_shielded() -> bool:
	return _shield_time > 0.0 or _apex_invuln_time > 0.0

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
	started = false   # после возрождения снова ждём первого движения

	active = true
	snap_camera()
