extends Node2D

# Преследователь. Три типа: SLOW / FAST / CYCLIC.
#
# Навигация — СТРОГО по сетке (как у игрока): враг идёт от центра клетки к центру
# соседней по BFS-пути и физически не может срезать угол или пройти сквозь стену.
#
# Динамическая скорость: вне поля зрения игрока враг идёт FAR_MULT (150%) от его
# скорости и точно наводится — чтобы реально дойти даже с другого конца карты;
# войдя в зону видимости, замедляется к скорости игрока, а у самого игрока —
# ещё медленнее (честно и читаемо).

enum Type { SLOW, FAST, CYCLIC }

const CONTACT_RANGE := 58.0

const LIGHT_COSTS := [0.30, 0.16, 0.24]   # урон по свету за удар (SLOW/FAST/CYCLIC)

const VIEW_RADIUS := 330.0    # радиус «видимости» игрока (мир. px)
const FAR_MULT    := 1.5      # множитель скорости вне поля зрения
const NEAR_MULT   := 0.6      # множитель скорости у самого игрока
const TYPE_MULT   := [0.9, 1.15, 1.0]   # доп. множитель скорости по типам
const RECOIL_DIST := 20.0     # визуальная отдача врага при ударе (px)

const STUN_SHIELD := 4.0      # заморозка врага, когда игрок «переезжает» его со щитом
const STUN_HIT    := 1.0      # стаз врага после обычного удара (без щита)

# Должны совпадать с палитрой MazeTextures.make_enemy (это цвет свечения-ауры).
const TYPE_COLORS := [
	Color(0.80, 0.18, 1.00),   # SLOW:   фиолет
	Color(1.00, 0.34, 0.08),   # FAST:   жгучий оранжевый
	Color(0.10, 1.00, 0.80),   # CYCLIC: ядовитая бирюза
]

# Соседи по сетке (4-связность). Вынесено в const, чтобы BFS не аллоцировал
# этот массив на каждую посещённую клетку.
const DIRS: Array[Vector2i] = [Vector2i(1, 0), Vector2i(-1, 0), Vector2i(0, 1), Vector2i(0, -1)]

var enemy_type: int = Type.SLOW
var target: Node2D = null
var _game: Node = null
var spawn_level: int = 4
var _enemy_floor: int = 0   # этаж, на котором живёт враг (двери не использует)

# Навигация по сетке
var _move_target: Vector2 = Vector2.ZERO
var _has_target: bool = false
# Кэш маршрута: путь BFS считается не на каждый шаг, а только когда сменилась
# клетка игрока или истёк страховочный таймер (на случай сдвига/перегенерации
# лабиринта). Между пересчётами враг просто снимает клетки с готового маршрута.
var _path: Array[Vector2i] = []
var _path_goal: Vector2i = Vector2i(-9999, -9999)
var _repath_cd: float = 0.0
const REPATH_INTERVAL := 0.4

# Cyclic phase
var _moving: bool = true
var _phase_timer: float = 10.0

var _contact_active: bool = false

# Визуал
var _core: Sprite2D
var _glow: PointLight2D
var _anim: float = 0.0
var _hit_flash: float = 0.0
var _recoil: Vector2 = Vector2.ZERO   # визуальное смещение-отдача (затухает)
var _stun_time: float = 0.0           # пока > 0 — враг заморожен и не двигается
var _base_color: Color = Color.WHITE  # цвет свечения в обычном состоянии

func _ready() -> void:
	add_to_group("enemy")
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
	if _stun_time > 0.0:
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

	# Обычное состояние
	var punch: float = 1.0 + 0.55 * _hit_flash
	if _core:
		_core.modulate = Color(1, 1, 1)
		var spin: float = 2.4 if enemy_type == Type.FAST else 0.7
		_core.rotation = _anim * spin
		_core.scale = Vector2.ONE * (0.94 + 0.08 * sin(_anim * 3.0)) * punch
		_core.position = _recoil
	if _glow:
		_glow.color = _base_color
		_glow.energy = (0.62 + 0.22 * sin(_anim * 3.0 + 1.0)) + 1.4 * _hit_flash
		_glow.position = _recoil

func _physics_process(delta: float) -> void:
	if target == null or not is_instance_valid(target):
		return
	_handle_contact(global_position.distance_to(target.global_position))
	if _repath_cd > 0.0:
		_repath_cd -= delta
	# Заморожен — не двигается, только тикает таймер стаза
	if _stun_time > 0.0:
		_stun_time -= delta
		return
	match enemy_type:
		Type.SLOW, Type.FAST:
			_grid_move(delta)
		Type.CYCLIC:
			_update_cyclic(delta)

# ---------- Контакт ----------

func _handle_contact(dist: float) -> void:
	if dist < CONTACT_RANGE:
		if not _contact_active:
			_contact_active = true
			_on_hit()
	else:
		_contact_active = false

# Удар по игроку: урон по свету + (для CYCLIC) замедление, плюс отдача и вспышка.
func _on_hit() -> void:
	if target == null or not is_instance_valid(target):
		return
	var shielded: bool = target.has_method("is_shielded") and target.is_shielded()
	if shielded:
		# Игрок со щитом «переезжает» врага → заморозка на 4с, урона по свету нет
		_stun_time = STUN_SHIELD
		_spawn_freeze_fx()
	else:
		# Обычный удар: урон по свету + (CYCLIC) замедление + стаз врага на 1с
		var steps: int = maxi(0, (spawn_level - 4) / 2)
		var cost: float = LIGHT_COSTS[enemy_type] + 0.02 * float(steps)
		if target.has_method("hit_by_enemy"):
			target.hit_by_enemy(cost)
		if enemy_type == Type.CYCLIC and target.has_method("apply_enemy_effect"):
			var dur: float = 3.0 + 0.5 * float(steps)
			var mult: float = maxf(0.35, 0.50 - 0.02 * float(steps))
			target.apply_enemy_effect("slow_move", dur, mult)
		_stun_time = STUN_HIT
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

# Скорость зависит от дистанции до игрока: вне зоны видимости — FAR_MULT от
# скорости игрока; в зоне — от скорости игрока (на краю) до NEAR_MULT (вплотную).
func _current_speed() -> float:
	var ps := 320.0
	if "speed" in target:
		ps = float(target.speed)
	var dist := global_position.distance_to(target.global_position)
	var spd: float
	if dist >= VIEW_RADIUS:
		spd = ps * FAR_MULT
	else:
		var t := clampf(dist / VIEW_RADIUS, 0.0, 1.0)
		spd = lerpf(ps * NEAR_MULT, ps, t)
	# «Накал»: чем ярче горит игрок, тем агрессивнее (быстрее) преследователь.
	var heat := 0.0
	if _game and is_instance_valid(_game) and _game.has_method("enemy_heat"):
		heat = _game.enemy_heat()
	return spd * float(TYPE_MULT[enemy_type]) * (1.0 + heat * 0.6)

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

# Выбирает следующую клетку-цель. Путь к клетке игрока кэшируется (_path) и
# пересчитывается только при смене клетки игрока или по таймеру (страховка от
# изменения лабиринта); между пересчётами враг просто снимает клетки с маршрута.
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

	# Клетку игрока проецируем на этаж врага: если игрок на другом этаже — враг
	# держится «под/над» ним, оставаясь рядом к моменту его возвращения.
	var pf: int = int(target.current_floor)
	var p_local := target.global_position - Vector2(0, pf * gap)
	var ex := clampi(int(round((p_local.x / tile - 1.5) / 2.0)), 0, cols - 1)
	var ey := clampi(int(round((p_local.y / tile - 1.5) / 2.0)), 0, rows - 1)
	var goal := Vector2i(ex, ey)

	if start == goal:
		_path.clear()
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

# BFS: полный маршрут — список клеток ПОСЛЕ start до goal включительно; [] если
# пути нет. Раньше считался только первый шаг и заново на каждую клетку — теперь
# путь считается разом и кэшируется в _pick_next.
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
