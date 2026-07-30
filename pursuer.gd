extends Node2D

# Преследователь. Три типа: SLOW / FAST / CYCLIC.
#
# Навигация — СТРОГО по сетке (как у игрока): враг идёт от центра клетки к центру
# соседней по BFS-пути и физически не может срезать угол или пройти сквозь стену.
#
# Состояния — PATROL / CHASE / SEARCH:
#   PATROL — враг живёт своей жизнью: бродит к случайным достижимым клеткам своего
#            этажа (CYCLIC вместо этого сохраняет свой родной ритм движение/пауза).
#   CHASE  — сработало обнаружение (дистанция < VIEW_RADIUS И прямая видимость по
#            сетке, стены её блокируют) — враг идёт к клетке игрока по BFS.
#   SEARCH — видимость потеряна: враг ещё несколько секунд идёт к последней
#            замеченной клетke и «оглядывается», затем возвращается в PATROL.
#            Новое обнаружение в любой момент сразу возвращает в CHASE.
#
# Скорость в CHASE вблизи игрока уже не прощает (NEAR_MULT поднят с 0.6 до 0.92) —
# давление вблизи ощущается, но чистая игра всё ещё позволяет оторваться.
#
# БОЙ — враги не только убегают/догоняют, у них есть HP (take_damage). Разные
# навыки бьют по-разному, так что стиль игры сам выбирает, каким мастерством
# прокачивается Апекс (main.gd:skill_hit_enemies + этот файл):
#   • Рывок (Shift) — «таран»: контакт во время рывка наносит врагу урон вместо
#     урона по игроку (см. is_dashing в _on_hit) — риск/награда для мобильного стиля.
#   • Вспышка (Q) — урон в упор при активации (main.gd:on_player_flash).
#   • Сонар (E) — расходящееся кольцо наносит урон всем, кого задевает (sonar.gd).
#   • Щит (C) — чисто оборонительный: замораживает контакт, урона не наносит.
# Добито до 0 HP — враг уничтожается (_die), как и раньше при Апексе, но с
# меньшей наградой (обычный бой vs апекс-«испепеление»).

enum Type { SLOW, FAST, CYCLIC }
enum State { PATROL, CHASE, SEARCH, RETURN, FLEE }   # RETURN — эскорт к боссу; FLEE — «Зеркало» (§10.2), испуганный враг убегает

const CONTACT_RANGE := 58.0

const LIGHT_COSTS := [0.24, 0.13, 0.19, 0.30, 0.10, 0.12]

const VIEW_RADIUS := 330.0    # радиус «видимости» игрока (мир. px)
const FAR_MULT    := 1.5      # множитель скорости вне поля зрения (только CHASE)
const NEAR_MULT   := 0.92     # множитель скорости у самого игрока в CHASE (было 0.6 — прощало)
const TYPE_MULT   := [0.9, 1.15, 1.0, 0.7, 1.3, 0.95]
const VIEW_MULT   := [1.0, 1.0, 1.0, 1.4, 1.0, 1.1]   # Страж видит дальше
const RECOIL_DIST := 20.0     # визуальная отдача врага при ударе (px)

const PATROL_MULT := 0.55     # скорость бесцельного блуждания
const SEARCH_MULT := 0.85     # скорость движения к последней замеченной клетке

const LOS_CHECK_INTERVAL := 0.15   # как часто проверяем видимость (не каждый кадр)
const SEARCH_MIN := 2.0
const SEARCH_MAX := 4.0
const PATROL_PICK_ATTEMPTS := 6    # сколько случайных клеток пробуем на предмет достижимости

const STUN_SHIELD := 4.0      # заморозка врага, когда игрок «переезжает» его со щитом
const STUN_HIT    := 1.0      # стаз врага после обычного удара (без щита)

# Эскорт супербосса (leash_node != null, см. main.gd::_spawn_superboss_escort):
# «недалёкий агр» — реагирует только если цель рядом с боссом, а не с самим
# эскортом, иначе догонит игрока через полкарты. Отогнали за пределы радиуса
# (или потеряли из виду) — идёт назад к боссу вместо обычного SEARCH/PATROL.
const ESCORT_AGGRO_RADIUS := 260.0
const ESCORT_RETURN_DIST  := 48.0

# «Зеркало» (GAMEDESIGN.md §10.2) — только SLOW-тип (FAST/CYCLIC не убегают,
# это часть их характера, см. дизайн-заметку в разделе). Срабатывает после
# нескольких подряд неудачных погонь за этим конкретным врагом (игрок
# «загонял его в тупик» и уходил — враг «напуган») либо изредка случайно.
const FLEE_EVADE_THRESHOLD := 3     # столько CHASE подряд без поимки — и враг бежит
const FLEE_RANDOM_CHANCE := 0.003   # шанс за LOS-проверку (~раз в LOS_CHECK_INTERVAL) в PATROL
const FLEE_DUR_MIN := 8.0
const FLEE_DUR_MAX := 12.0
const FLEE_SPEED_MULT := 1.05

# Типы 3-5 — элита глубоких уровней (25+/30+/35+):
#   3 СТРАЖ  — броня 6 HP, медленный, видит в 1.4 раза дальше. Контрплей: заморозь
#              (Щит/Хронос — замороженный ловит +1 урона) и бей, или просто обойди.
#   4 ФАНТОМ — 1 HP, но очень быстрый. Контрплей: один любой удар — или Тление,
#              чтобы он потерял след.
#   5 ПИЯВКА — при касании ВЫСАСЫВАЕТ ВОЛЮ (не только свет). Контрплей: держи
#              дистанцию, добивай Сонаром издалека.
const MAX_HP := [3, 2, 3, 6, 1, 3]

# Должны совпадать с палитрой MazeTextures.make_enemy (это цвет свечения-ауры).
const TYPE_COLORS := [
	Color(0.80, 0.18, 1.00),   # SLOW:   фиолет
	Color(1.00, 0.34, 0.08),   # FAST:   жгучий оранжевый
	Color(0.10, 1.00, 0.80),   # CYCLIC: ядовитая бирюза
	Color(0.75, 0.15, 0.25),   # СТРАЖ: тёмный багрянец
	Color(0.75, 0.85, 1.00),   # ФАНТОМ: бледная сталь
	Color(0.45, 0.95, 0.25),   # ПИЯВКА: кислотная зелень
]

# Соседи по сетке (4-связность). Вынесено в const, чтобы BFS не аллоцировал
# этот массив на каждую посещённую клетку.
const DIRS: Array[Vector2i] = [Vector2i(1, 0), Vector2i(-1, 0), Vector2i(0, 1), Vector2i(0, -1)]

var enemy_type: int = Type.SLOW
var target: Node2D = null
var _game: Node = null
var spawn_level: int = 4
var _enemy_floor: int = 0   # этаж, на котором живёт враг (двери не использует)

# Состояние: PATROL / CHASE / SEARCH
var _state: int = State.PATROL
var _patrol_cell: Vector2i = Vector2i(-1, -1)
var _last_seen_cell: Vector2i = Vector2i(-1, -1)
var _search_timer: float = 0.0
var _los_cd: float = 0.0
var _evade_count: int = 0   # «Зеркало» (§10.2): подряд неудачных погонь за этим врагом
var _flee_timer: float = 0.0
var _flee_cell: Vector2i = Vector2i(-1, -1)

var hp: int = 3
var _dying: bool = false   # защита от повторного _die() в тот же кадр
var _seen_noted: bool = false   # бестиарий: seen_tN засчитывается один раз на врага

# Навигация по сетке
var _move_target: Vector2 = Vector2.ZERO
var _has_target: bool = false
# Кэш маршрута: путь BFS считается не на каждый шаг, а только когда сменилась
# целевая клетка или истёк страховочный таймер (на случай сдвига/перегенерации
# лабиринта). Между пересчётами враг просто снимает клетки с готового маршрута.
var _path: Array[Vector2i] = []
var _path_goal: Vector2i = Vector2i(-9999, -9999)
var _repath_cd: float = 0.0
const REPATH_INTERVAL := 0.4

# Cyclic phase (используется только как форма PATROL для этого типа)
var _moving: bool = true
var _phase_timer: float = 10.0

var _contact_active: bool = false
var _ally_contact: Node2D = null   # союзник, с которым сейчас в контакте (дебаунс урона)
var _chase_target: Node2D = null   # кого враг сейчас преследует в CHASE — игрок или ближайший видимый союзник
var leash_node: Node2D = null      # эскорт супербосса: точка, которую враг охраняет и к которой возвращается

# Накал-синергия «огненный след» (GAMEDESIGN.md §4, fire_trail.gd) — временное
# замедление, независимое от stun_time (тот означает полную заморозку щитом/
# ударом). Не сбрасывается досрочно, если наступить в след повторно, — только
# продлевается (maxf), как и у stun_time.
const BURN_SLOW_MULT := 0.5
var _burn_slow_time: float = 0.0

func apply_burn_slow(dur: float) -> void:
	_burn_slow_time = maxf(_burn_slow_time, dur)

# Тёмная сторона эха шарда (§10.3, main.gd::_spawn_echo_ambush) — засада
# всполошила всех врагов этажа: на dur секунд бегут быстрее, «чуя» что-то
# случилось. Тот же принцип продления (maxf), что и у _burn_slow_time.
const AMBUSH_ALERT_MULT := 1.3
var _ambush_alert_time: float = 0.0

func apply_ambush_alert(dur: float) -> void:
	_ambush_alert_time = maxf(_ambush_alert_time, dur)

# Визуал
var _core: Sprite2D
var _glow: PointLight2D
var _anim: float = 0.0
var _hit_flash: float = 0.0
var _recoil: Vector2 = Vector2.ZERO   # визуальное смещение-отдача (затухает)
var stun_time: float = 0.0            # пока > 0 — враг заморожен и не двигается
var _base_color: Color = Color.WHITE  # цвет свечения в обычном состоянии

func _ready() -> void:
	add_to_group("enemy")
	hp = MAX_HP[enemy_type]
	var col: Color = TYPE_COLORS[enemy_type]
	_base_color = col
	_core = Sprite2D.new()
	_core.texture = MazeTextures.make_enemy(enemy_type, 16)
	add_child(_core)

	_glow = PointLight2D.new()
	_glow.texture = MazeTextures.make_light(150)
	_glow.color = col
	_glow.energy = 0.75
	_glow.texture_scale = 0.85
	_glow.shadow_enabled = false
	add_child(_glow)

func _process(delta: float) -> void:
	_anim += delta
	if _hit_flash > 0.0:
		_hit_flash = maxf(0.0, _hit_flash - delta * 4.0)
	# Затухание визуальной отдачи (двигаем только спрайт/свечение, не позицию)
	_recoil = _recoil.lerp(Vector2.ZERO, clampf(12.0 * delta, 0.0, 1.0))

	# Заморожен: ледяной цвет + быстрая пульсация, корона не вращается
	if stun_time > 0.0:
		var fp: float = 0.78 + 0.22 * sin(_anim * 13.0)
		if _core:
			_core.modulate = Color(0.55, 0.8, 1.0)
			_core.scale = Vector2.ONE * (0.86 + 0.14 * sin(_anim * 13.0))
			_core.position = _recoil
		if _glow:
			_glow.color = Color(0.5, 0.8, 1.0)
			_glow.energy = 0.9 * fp
			_glow.position = _recoil
		return

	# «Зеркало» (§10.2): напуган — бледнеет и мелко дрожит, читается сразу как
	# «сейчас не опасен», в отличие от ледяной заморозки щитом (другой цвет/темп).
	if _state == State.FLEE:
		var fp2: float = 0.7 + 0.3 * sin(_anim * 10.0)
		if _core:
			_core.modulate = _base_color.lerp(Color.WHITE, 0.65)
			_core.scale = Vector2.ONE * (0.9 + 0.05 * sin(_anim * 10.0))
			_core.position = _recoil
		if _glow:
			_glow.color = _base_color.lerp(Color.WHITE, 0.65)
			_glow.energy = 0.5 * fp2
			_glow.position = _recoil
		return

	# Обычное состояние. В CHASE — тревожная более быстрая пульсация.
	var punch: float = 1.0 + 0.55 * _hit_flash
	if _core:
		_core.modulate = Color(1, 1, 1)
		var spin: float = 2.4 if enemy_type == Type.FAST else 0.7
		if _state == State.CHASE:
			spin *= 1.6
		_core.rotation = _anim * spin
		_core.scale = Vector2.ONE * (0.94 + 0.08 * sin(_anim * 3.0)) * punch
		_core.position = _recoil
	if _glow:
		# Тёмная станция рядом (§22) подмешивает фиолетовый ореол в обычный
		# цвет свечения — читаемый сигнал «этот враг подпитан воронкой».
		var glow_col := _base_color
		if _dark_station_mult() > 1.0:
			glow_col = _base_color.lerp(Color(0.55, 0.05, 0.68), 0.55)
		_glow.color = glow_col
		var pulse_speed: float = 3.0 if _state != State.CHASE else 6.0
		_glow.energy = (0.62 + 0.22 * sin(_anim * pulse_speed + 1.0)) + 1.4 * _hit_flash
		_glow.position = _recoil

func _physics_process(delta: float) -> void:
	if target == null or not is_instance_valid(target):
		return
	# Заморозка до первого хода игрока: пока игрок не двинулся (начало уровня или
	# после возрождения), враги стоят — «время заморожено», как и таймер уровня.
	if "started" in target and not target.started:
		return
	# Обучение: попап-урок ставит игру на паузу для отдельного, не боевого шага —
	# враг тоже должен замереть, иначе за время чтения текста он может догнать
	# игрока (см. main.gd::is_tutorial_frozen/_tut_freeze).
	if _game == null or not is_instance_valid(_game):
		_game = _find_game()
	if _game and is_instance_valid(_game) and _game.has_method("is_tutorial_frozen") and _game.is_tutorial_frozen():
		return
	_handle_contact(global_position.distance_to(target.global_position))
	_handle_ally_contact()
	if _repath_cd > 0.0:
		_repath_cd -= delta
	if _los_cd > 0.0:
		_los_cd -= delta
	if _burn_slow_time > 0.0:
		_burn_slow_time -= delta
	if _ambush_alert_time > 0.0:
		_ambush_alert_time -= delta
	# Заморожен — не двигается, только тикает таймер стаза
	if stun_time > 0.0:
		stun_time -= delta
		return
	_update_state(delta)
	match _state:
		State.PATROL:
			if enemy_type == Type.CYCLIC:
				_update_cyclic(delta)
			else:
				_grid_move(delta)
		State.CHASE, State.SEARCH, State.RETURN, State.FLEE:
			_grid_move(delta)

# Использует Апекс (см. main.gd:apex_overload/has_active_chaser): «реальная
# угроза» — это враг, который прямо сейчас гонится, а не дремлет в патруле.
func is_chasing() -> bool:
	return _state == State.CHASE

# «Зеркало» (§10.2): счётчик неудачных погонь подряд (потерял игрока из виду,
# так и не поймав) — на FLEE_EVADE_THRESHOLD-й раз враг «понимает», что его
# дурят, и сам обращается в бегство. Возвращает true, если решение принято
# (состояние уже выставлено в _enter_flee).
func _try_enter_flee_from_evade() -> bool:
	_evade_count += 1
	if _evade_count >= FLEE_EVADE_THRESHOLD:
		_evade_count = 0
		_enter_flee()
		return true
	return false

func _enter_flee() -> void:
	_state = State.FLEE
	_flee_timer = randf_range(FLEE_DUR_MIN, FLEE_DUR_MAX)
	_flee_cell = Vector2i(-1, -1)
	_path.clear()

# ---------- Состояние: обнаружение и переходы ----------

# [GAMEDESIGN §33] «Ловчий» — враг эскалации: НЕ теряет след. Обычный враг,
# потеряв прямую видимость, уходит в SEARCH и через несколько секунд забывает
# игрока; Ловчий знает, где ты, всегда. Взамен он медленный — от него можно
# уйти, но нельзя спрятаться, и это единственный источник давления «пора
# заканчивать уровень», а не «успею/не успею до станции».
@export var relentless: bool = false

# Личный множитель скорости врага. Нужен Ловчему (§33): он неотвратим, и это
# уравновешивается ровно одним — он медленнее. Обычные враги оставляют 1.0.
@export var speed_mult: float = 1.0

func _update_state(delta: float) -> void:
	# Неотвратимость проверяется ДО обычной логики обнаружения: заморозку и
	# «Зеркало» она не отменяет (это общие правила боя), но зрение/стены —
	# отменяет полностью.
	if relentless and _state != State.FLEE and target != null and is_instance_valid(target):
		if _state != State.CHASE:
			_path.clear()
			if not _seen_noted:
				_seen_noted = true
				GameConfig.bump_stat("seen_t%d" % enemy_type)
		_chase_target = target
		_state = State.CHASE
		_last_seen_cell = _cell_of(target)
		return

	# «Зеркало» (§10.2): пока враг напуган, не проверяем обнаружение вовсе —
	# он не может снова начать погоню, пока не отбегается свой срок.
	if _state == State.FLEE:
		_flee_timer -= delta
		if _flee_timer <= 0.0:
			_state = State.PATROL
			_patrol_cell = Vector2i(-1, -1)
			_path.clear()
		return

	if _los_cd <= 0.0:
		_los_cd = LOS_CHECK_INTERVAL
		var vis: Node2D = _find_visible_target()
		if vis != null and leash_node != null and is_instance_valid(leash_node):
			# Эскорт: «недалёкий агр» — реагирует, только если цель рядом с
			# боссом (не с самим эскортом), иначе Страж утащится за игроком
			# через полкарты и оставит босса без прикрытия.
			if leash_node.global_position.distance_to(vis.global_position) > ESCORT_AGGRO_RADIUS:
				vis = null
		if vis != null:
			if _state != State.CHASE or _chase_target != vis:
				_path.clear()   # форсируем пересчёт маршрута к новой цели
				# Бестиарий: первая погоня этого врага открывает его карточку
				# (засчитывается только за игрока, не за союзника-приманку).
				if not _seen_noted and vis == target:
					_seen_noted = true
					GameConfig.bump_stat("seen_t%d" % enemy_type)
			_chase_target = vis
			_state = State.CHASE
			_last_seen_cell = _cell_of(vis)
			_evade_count = 0   # снова гонится — счётчик неудачных погонь сбрасывается
		elif _state == State.CHASE:
			if leash_node != null and is_instance_valid(leash_node):
				_state = State.RETURN   # отогнали/потеряли цель — назад к боссу, не в вольный SEARCH
			elif enemy_type == Type.SLOW and _try_enter_flee_from_evade():
				pass   # состояние уже выставлено внутри (FLEE)
			else:
				_state = State.SEARCH
				_search_timer = randf_range(SEARCH_MIN, SEARCH_MAX)
			_path.clear()
		elif _state == State.PATROL and enemy_type == Type.SLOW and leash_node == null \
				and randf() < FLEE_RANDOM_CHANCE:
			# «Редкий сюрприз» — пугается без всякой причины, лабиринт живёт своей жизнью.
			_enter_flee()
	if _state == State.SEARCH:
		_search_timer -= delta
		if _search_timer <= 0.0:
			_state = State.PATROL
			_patrol_cell = Vector2i(-1, -1)
			_path.clear()
	elif _state == State.RETURN:
		if leash_node == null or not is_instance_valid(leash_node) \
				or global_position.distance_to(leash_node.global_position) <= ESCORT_RETURN_DIST:
			_state = State.PATROL
			_patrol_cell = Vector2i(-1, -1)
			_path.clear()

# Видимость: дистанция в пределах VIEW_RADIUS И прямая линия до игрока не
# пересекает стену (проверяется по той же сеточной модели, что и BFS-навигация,
# без физического raycast — стены здесь спрайты, а не физтела).
func _can_see_player() -> bool:
	if _game == null or not is_instance_valid(_game):
		_game = _find_game()
	if _game == null or target == null or not is_instance_valid(target):
		return false
	if int(target.current_floor) != _enemy_floor:
		return false
	return _can_see_node(target)

# Обобщение _can_see_player: та же проверка (радиус, заметность, LOS по сетке)
# для произвольного узла — используется, чтобы враг мог заметить и погнаться
# за союзником-петом (ally.gd), не только за игроком. Заметность узла без
# собственного visibility_factor() (пет её не считает) берём у игрока — пет
# «светится» тем же светом, что и он.
func _can_see_node(node: Node2D) -> bool:
	if _game == null or not is_instance_valid(_game):
		_game = _find_game()
	if _game == null or node == null or not is_instance_valid(node):
		return false
	var dist: float = global_position.distance_to(node.global_position)
	var vis_r := VIEW_RADIUS * float(VIEW_MULT[enemy_type])
	if node.has_method("visibility_factor"):
		vis_r *= clampf(float(node.visibility_factor()), 0.15, 1.6)
	elif target != null and is_instance_valid(target) and target.has_method("visibility_factor"):
		vis_r *= clampf(float(target.visibility_factor()), 0.15, 1.6)
	if dist > vis_r:
		return false
	var grids = _game._grids
	if _enemy_floor < 0 or _enemy_floor >= grids.size():
		return false
	var grid: Array = grids[_enemy_floor]
	var tile: float = _game.TILE
	var gap: float = _game._floor_gap
	var my_local: Vector2 = global_position - Vector2(0, _enemy_floor * gap)
	var n_local: Vector2 = node.global_position - Vector2(0, _enemy_floor * gap)
	return _has_line_of_sight(my_local, n_local, grid, tile)

# Ищет ближайшую видимую цель для перехода в CHASE: игрока или союзника-пета
# (ally.gd, группа "ally") — какая ближе, за той и гонится. Пет всегда на
# этаже игрока (следует физически за его global_position), отдельной проверки
# этажа для него не нужно.
func _find_visible_target() -> Node2D:
	var best: Node2D = null
	var best_d := INF
	if _can_see_player():
		best = target
		best_d = global_position.distance_to(target.global_position)
	for a in get_tree().get_nodes_in_group("ally"):
		if not is_instance_valid(a):
			continue
		if not _can_see_node(a):
			continue
		var d: float = global_position.distance_to(a.global_position)
		if d < best_d:
			best_d = d
			best = a
	return best

func _has_line_of_sight(from_local: Vector2, to_local: Vector2, grid: Array, tile: float) -> bool:
	var gh: int = grid.size()
	if gh == 0:
		return false
	var gw: int = grid[0].size()
	var dist: float = from_local.distance_to(to_local)
	var steps: int = maxi(1, int(dist / (tile * 0.35)))
	for i in range(1, steps):
		var t: float = float(i) / float(steps)
		var p: Vector2 = from_local.lerp(to_local, t)
		var gx: int = clampi(int(round(p.x / tile - 0.5)), 0, gw - 1)
		var gy: int = clampi(int(round(p.y / tile - 0.5)), 0, gh - 1)
		if grid[gy][gx]:   # true = стена в этой точке линии
			return false
	return true

# Клетка игрока, спроецированная на этаж врага (см. комментарий в _pick_next).
func _player_cell() -> Vector2i:
	return _cell_of(target)

# Обобщение _player_cell на произвольный узел (игрок или союзник-пет — у пета
# нет current_floor, считаем его на этаже врага, он и так следует за игроком).
func _cell_of(node: Node2D) -> Vector2i:
	var tile: float = _game.TILE
	var gap: float  = _game._floor_gap
	var cols: int   = _game._cols
	var rows: int   = _game._rows
	var pf: int = _enemy_floor
	if "current_floor" in node:
		pf = int(node.current_floor)
	var p_local: Vector2 = node.global_position - Vector2(0, pf * gap)
	var ex: int = clampi(int(round((p_local.x / tile - 1.5) / 2.0)), 0, cols - 1)
	var ey: int = clampi(int(round((p_local.y / tile - 1.5) / 2.0)), 0, rows - 1)
	return Vector2i(ex, ey)

# Кого враг сейчас реально преследует/атакует в CHASE (игрок или союзник) —
# с фолбэком на игрока, если по какой-то причине _chase_target не выставлен
# (например, состояние выставлено извне через distract_to()).
func _effective_chase_target() -> Node2D:
	if _chase_target != null and is_instance_valid(_chase_target):
		return _chase_target
	return target

# ---------- Контакт ----------

func _handle_contact(dist: float) -> void:
	if dist < CONTACT_RANGE:
		if not _contact_active:
			_contact_active = true
			_on_hit()
	else:
		_contact_active = false

# Контакт с союзником-петом (ally.gd) — независим от контакта с игроком: враг
# бьёт пета, если тот в CONTACT_RANGE, будь то по пути погони за игроком или
# просто наткнувшись в патруле. Раньше этой проверки не было вовсе — пет мог
# гаснуть только по таймеру жизни (GAMEDESIGN.md §25 «остаётся решить»).
func _handle_ally_contact() -> void:
	var near: Node2D = null
	for a in get_tree().get_nodes_in_group("ally"):
		if is_instance_valid(a) and global_position.distance_to(a.global_position) < CONTACT_RANGE:
			near = a
			break
	if near != null:
		if _ally_contact != near:
			_ally_contact = near
			if near.has_method("take_hit"):
				near.take_hit()
			var away: Vector2 = global_position - near.global_position
			if away.length() > 0.01:
				_recoil = away.normalized() * RECOIL_DIST
			_hit_flash = 1.0
	else:
		_ally_contact = null

# Удар по игроку: урон по свету + (для CYCLIC) замедление, плюс отдача и вспышка.
func _on_hit() -> void:
	if target == null or not is_instance_valid(target):
		return
	var shielded: bool = target.has_method("is_shielded") and target.is_shielded()
	var dashing: bool = target.has_method("is_dashing") and target.is_dashing()
	if shielded:
		# Апекс-форма Щита: контакт не просто замораживает, а уничтожает врага —
		# «пока горит — касание смертельно». Обычный щит — как раньше, заморозка.
		if target.has_method("is_apex_shielded") and target.is_apex_shielded():
			_spawn_freeze_fx()
			queue_free()
			return
		# Игрок со щитом «переезжает» врага → заморозка на 4с, урона по свету нет.
		stun_time = STUN_SHIELD
		_spawn_freeze_fx()
		# Комбо «Щит + Рывок» (GAMEDESIGN.md §4): рывок с активным щитом не
		# просто замораживает контакт впустую, как голый щит, а таранит —
		# урон засчитывается ПОВЕРХ заморозки. take_damage уже даёт +1 к урону
		# замороженному врагу (см. ниже, stun_time >= 0.5) — тот же общий
		# принцип «Щит + Вспышка», здесь он же срабатывает естественно, потому
		# что stun_time уже выставлен до вызова.
		if dashing:
			if take_damage(1, "dash_shield"):
				return
	elif dashing:
		# Таран рывком: контакт во время рывка наносит урон ВРАГУ вместо урона
		# по игроку — timing-навык для мобильного стиля («сражаться на бегу»).
		if take_damage(1, "dash"):
			return   # уже уничтожен внутри take_damage → _die → queue_free
	else:
		# Обычный удар: урон по свету + (CYCLIC) замедление + стаз врага на 1с
		var steps: int = maxi(0, (spawn_level - 4) / 2)
		var cost: float = LIGHT_COSTS[enemy_type] + 0.02 * float(steps)
		if target.has_method("hit_by_enemy"):
			target.hit_by_enemy(cost)
		GameConfig.bump_stat("hit_t%d" % enemy_type)   # бестиарий: удары по тебе
		# ПИЯВКА высасывает и Волю — топливо навыков (контрплей: не подпускать)
		if enemy_type == 5 and "will" in target:
			target.will = maxf(0.0, target.will - 0.3)
		if enemy_type == Type.CYCLIC and target.has_method("apply_enemy_effect"):
			var dur: float = 3.0 + 0.5 * float(steps)
			var mult: float = maxf(0.35, 0.50 - 0.02 * float(steps))
			target.apply_enemy_effect("slow_move", dur, mult)
		stun_time = STUN_HIT
	# Отдача-вспышка в обоих случаях
	var away: Vector2 = global_position - target.global_position
	if away.length() > 0.01:
		_recoil = away.normalized() * RECOIL_DIST
	_hit_flash = 1.0

# Ледяная вспышка при заморозке щитом.
func _spawn_freeze_fx() -> void:
	var p := get_parent()
	if p == null:
		return
	var b := Node2D.new()
	b.set_script(load("res://burst.gd"))
	b.color = Color(0.6, 0.86, 1.0, 1.0)
	b.max_scale = 2.6
	b.dur = 0.5
	p.add_child(b)
	b.global_position = global_position

# ---------- Бой: HP ----------

# Наносит врагу урон (Рывок-таран/Вспышка/Сонар — см. комментарий в шапке файла).
# Возвращает true, если враг уничтожен этим попаданием.
# «Мираж» (дар босса): врага отвлекают к ложной цели — он идёт искать туда.
# [GAMEDESIGN §31] Враг УСЛЫШАЛ шум в клетке cell и идёт проверять. В отличие
# от distract_to (мираж — сознательная приманка), шум это побочный эффект
# любого громкого навыка игрока, поэтому здесь есть фильтры:
#   • CHASE — уже видит тебя, шум ничего не добавляет;
#   • FLEE — напуган, ему не до проверок;
#   • RETURN — эскорт босса, он не бросает пост;
#   • заморожен — физически не может пойти.
# Возвращает true, если враг реально сменил поведение: main.gd считает по
# этому, стоит ли вообще рисовать кольцо (и не спамить эффектом впустую).
func hear(cell: Vector2i, dur: float) -> bool:
	if stun_time > 0.0:
		return false
	if _state == State.CHASE or _state == State.FLEE or _state == State.RETURN:
		return false
	# Шум не «прилипает» сильнее уже идущего поиска: если враг и так копает в
	# этом направлении, только освежаем таймер, а не сбрасываем маршрут.
	if _state == State.SEARCH and _last_seen_cell == cell:
		_search_timer = maxf(_search_timer, dur)
		return true
	distract_to(cell, dur)
	return true

func distract_to(cell: Vector2i, dur: float) -> void:
	_state = State.SEARCH
	_last_seen_cell = cell
	_search_timer = dur
	_path.clear()

func take_damage(dmg: int, source: String = "") -> bool:
	if _dying or not is_instance_valid(self):
		return false
	# Замороженный (щит/лёд) враг уязвим: +1 урона. Это и есть комбо
	# «Щит + Вспышка» — раньше жило только в отдельной ветке боссовых
	# фрагментов, теперь общее правило боя.
	if stun_time >= 0.5:
		dmg += 1
	hp -= maxi(1, dmg)
	_hit_flash = 1.0
	if target and is_instance_valid(target):
		var away: Vector2 = global_position - target.global_position
		if away.length() > 0.01:
			_recoil = away.normalized() * RECOIL_DIST
	if hp <= 0:
		_die(source)
		return true
	stun_time = maxf(stun_time, STUN_HIT)
	return false

func _die(source: String) -> void:
	if _dying:
		return
	_dying = true
	_spawn_defeat_fx()
	if _game == null or not is_instance_valid(_game):
		_game = _find_game()
	if _game and is_instance_valid(_game) and _game.has_method("on_enemy_defeated"):
		_game.on_enemy_defeated(self, source)
	queue_free()

# Вспышка при уничтожении в обычном бою — цвет типа врага (не ледяной, тот
# означает заморозку, а не смерть).
func _spawn_defeat_fx() -> void:
	var p := get_parent()
	if p == null:
		return
	var b := Node2D.new()
	b.set_script(load("res://burst.gd"))
	b.color = _base_color
	b.max_scale = 3.2
	b.dur = 0.5
	p.add_child(b)
	b.global_position = global_position

# ---------- Движение по сетке ----------

func _update_cyclic(delta: float) -> void:
	if not _moving:
		_phase_timer -= delta
		if _phase_timer <= 0.0:
			_moving = true
			_phase_timer = 10.0
		return
	_phase_timer -= delta
	if _phase_timer <= 0.0:
		_moving = false
		_phase_timer = 10.0
		return
	_grid_move(delta)

# Скорость зависит от состояния: PATROL/SEARCH — фиксированные множители своей
# «повседневной» скорости; CHASE — как раньше: дальше игрока — быстрее (догоняет
# из-за пределов видимости), у самого игрока — NEAR_MULT (давление, не прощение).
func _current_speed() -> float:
	var ps := 320.0
	if "speed" in target:
		ps = float(target.speed)
	var heat := 0.0
	if _game and is_instance_valid(_game) and _game.has_method("enemy_heat"):
		heat = _game.enemy_heat()
	var escort_mult := _escort_buff_mult() * _dark_station_mult()
	if _burn_slow_time > 0.0:
		escort_mult *= BURN_SLOW_MULT
	if _ambush_alert_time > 0.0:
		escort_mult *= AMBUSH_ALERT_MULT
	match _state:
		State.PATROL:
			return ps * PATROL_MULT * float(TYPE_MULT[enemy_type]) * escort_mult
		State.SEARCH:
			return ps * SEARCH_MULT * float(TYPE_MULT[enemy_type]) * (1.0 + heat * 0.3) * escort_mult
		State.RETURN:
			return ps * SEARCH_MULT * float(TYPE_MULT[enemy_type]) * escort_mult
		State.FLEE:
			return ps * FLEE_SPEED_MULT * float(TYPE_MULT[enemy_type]) * escort_mult * speed_mult
		_:
			var dist := global_position.distance_to(target.global_position)
			var spd: float
			if dist >= VIEW_RADIUS:
				spd = ps * FAR_MULT
			else:
				var t := clampf(dist / VIEW_RADIUS, 0.0, 1.0)
				spd = lerpf(ps * NEAR_MULT, ps, t)
			var lvl_mult := 1.0
			if _game and is_instance_valid(_game) and _game.has_method("enemy_level_speed_mult"):
				lvl_mult = _game.enemy_level_speed_mult()
			return spd * float(TYPE_MULT[enemy_type]) * (1.0 + heat * 0.6) * lvl_mult * escort_mult * speed_mult

# Супербосс §25: миньоны-эскорт (помечены meta "boss_escort" при спавне)
# ускоряются, пока рядом активна антистанция — читаемая тактика «сначала
# погаси антистанцию, потом разбирайся с эскортом». На обычных врагов не
# влияет (meta отсутствует — функция сразу возвращает 1.0).
func _escort_buff_mult() -> float:
	if not has_meta("boss_escort"):
		return 1.0
	for a in get_tree().get_nodes_in_group("antistation"):
		if is_instance_valid(a) and a.has_method("is_active") and a.is_active():
			if a.global_position.distance_to(global_position) <= 220.0:
				return 1.35
	return 1.0

# Тёмные станции (§22, dark_station.gd) — общедоступный аналог антистанции,
# встречается в обычных уровнях. Любой враг в радиусе действующей (не
# подавленной светом) воронки получает бафф скорости и тёмно-фиолетовый
# ореол (см. _process — подмешивается в цвет свечения).
func _dark_station_mult() -> float:
	for d in get_tree().get_nodes_in_group("dark_station"):
		if is_instance_valid(d) and d.has_method("is_energized") and d.is_energized():
			if d.global_position.distance_to(global_position) <= d.BUFF_RADIUS:
				return d.BUFF_MULT
	return 1.0

func _grid_move(delta: float) -> void:
	if not _has_target:
		_pick_next()
		if not _has_target:
			return
	var step := _current_speed() * delta
	if global_position.distance_to(_move_target) <= step:
		global_position = _move_target
		_has_target = false
		_pick_next()   # сразу берём следующую клетку — движение непрерывно
	else:
		global_position = global_position.move_toward(_move_target, step)

# Выбирает следующую клетку-цель в зависимости от состояния (CHASE → клетка
# игрока, SEARCH → последняя замеченная клетка, PATROL → случайная достижимая
# клетка). Путь BFS кэшируется (_path) и пересчитывается только при смене цели
# или по таймеру-страховке; между пересчётами враг снимает клетки с маршрута.
func _pick_next() -> void:
	_has_target = false
	if _game == null or not is_instance_valid(_game):
		_game = _find_game()
	if _game == null or target == null or not is_instance_valid(target):
		return
	var grids = _game._grids
	if _enemy_floor < 0 or _enemy_floor >= grids.size():
		return
	var grid: Array = grids[_enemy_floor]
	var tile: float = _game.TILE
	var gap: float  = _game._floor_gap
	var cols: int   = _game._cols
	var rows: int   = _game._rows

	var my_local := global_position - Vector2(0, _enemy_floor * gap)
	var sx := clampi(int(round((my_local.x / tile - 1.5) / 2.0)), 0, cols - 1)
	var sy := clampi(int(round((my_local.y / tile - 1.5) / 2.0)), 0, rows - 1)
	var start := Vector2i(sx, sy)

	var goal: Vector2i
	match _state:
		State.CHASE:
			goal = _cell_of(_effective_chase_target())
		State.SEARCH:
			goal = _last_seen_cell
		State.RETURN:
			goal = _cell_of(leash_node) if (leash_node != null and is_instance_valid(leash_node)) else start
		State.FLEE:
			goal = _ensure_flee_cell(start, grid, cols, rows)
		_:
			goal = _ensure_patrol_cell(start, grid, cols, rows)

	if goal.x < 0:
		return   # патрулю/беглецу пока некуда идти — попробуем на следующем кадре

	if start == goal:
		_path.clear()
		if _state == State.PATROL:
			_patrol_cell = Vector2i(-1, -1)   # дошли — новую цель выберем в следующем кадре
		elif _state == State.FLEE:
			_flee_cell = Vector2i(-1, -1)   # добежал — выберем следующую точку подальше
		return

	# Пересчёт маршрута только при смене цели или по таймеру-страховке; иначе
	# идём по уже посчитанному пути.
	if _path.is_empty() or goal != _path_goal or _repath_cd <= 0.0:
		_path = _bfs_path(grid, start, goal, cols, rows)
		_path_goal = goal
		_repath_cd = REPATH_INTERVAL

	# Снимаем уже пройденные клетки и берём следующую как цель.
	while not _path.is_empty() and _path[0] == start:
		_path.remove_at(0)
	if _path.is_empty():
		return
	var nc: Vector2i = _path[0]
	_path.remove_at(0)
	_move_target = Vector2((nc.x * 2 + 1) * tile + tile * 0.5,
		(nc.y * 2 + 1) * tile + tile * 0.5) + Vector2(0, _enemy_floor * gap)
	_has_target = true

# Подбирает случайную достижимую клетку для блуждания (PATROL). Кэшируется в
# _patrol_cell, пока не достигнута — сбрасывается на Vector2i(-1,-1) в _pick_next.
func _ensure_patrol_cell(start: Vector2i, grid: Array, cols: int, rows: int) -> Vector2i:
	if _patrol_cell.x >= 0:
		return _patrol_cell
	for i in PATROL_PICK_ATTEMPTS:
		var c := Vector2i(randi() % cols, randi() % rows)
		if c == start:
			continue
		var path := _bfs_path(grid, start, c, cols, rows)
		if not path.is_empty():
			_patrol_cell = c
			return c
	return Vector2i(-1, -1)

# «Зеркало» (§10.2): подбирает достижимую клетку ДАЛЬШЕ от игрока среди
# нескольких случайных кандидатов — тот же приём, что и обычный патруль
# (_ensure_patrol_cell), но с отбором по дистанции от цели, а не первой
# попавшейся. Кэшируется в _flee_cell, пока не достигнута.
func _ensure_flee_cell(start: Vector2i, grid: Array, cols: int, rows: int) -> Vector2i:
	if _flee_cell.x >= 0:
		return _flee_cell
	if target == null or not is_instance_valid(target):
		return Vector2i(-1, -1)
	var player_cell := _player_cell()
	var best := Vector2i(-1, -1)
	var best_d := -1
	for i in PATROL_PICK_ATTEMPTS:
		var c := Vector2i(randi() % cols, randi() % rows)
		if c == start:
			continue
		var d: int = absi(c.x - player_cell.x) + absi(c.y - player_cell.y)
		if d <= best_d:
			continue
		if _bfs_path(grid, start, c, cols, rows).is_empty():
			continue
		best_d = d
		best = c
	_flee_cell = best
	return best

# BFS: полный маршрут — список клеток ПОСЛЕ start до goal включительно; [] если
# пути нет.
func _bfs_path(grid: Array, start: Vector2i, goal: Vector2i, cols: int, rows: int) -> Array[Vector2i]:
	var prev := {}
	var visited := {start: true}
	var queue: Array[Vector2i] = [start]
	var found := false
	while not queue.is_empty():
		var c: Vector2i = queue.pop_front()
		if c == goal:
			found = true
			break
		for d in DIRS:
			var n: Vector2i = c + d
			if n.x < 0 or n.x >= cols or n.y < 0 or n.y >= rows:
				continue
			if grid[c.y + n.y + 1][c.x + n.x + 1]:   # true = стена между c и n
				continue
			if not visited.has(n):
				visited[n] = true
				prev[n] = c
				queue.append(n)
	if not found:
		return []
	var path: Array[Vector2i] = []
	var cur := goal
	while cur != start:
		path.append(cur)
		cur = prev[cur]
	path.reverse()
	return path

func _find_game() -> Node:
	var n := get_parent()
	while n != null:
		if n.has_method("guide_path_to_exit"):
			return n
		n = n.get_parent()
	return null
