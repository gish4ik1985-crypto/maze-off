extends Node2D

# Три типа врагов:
#   SLOW   (0) — медленный,  блокирует зарядку на 3 с
#   FAST   (1) — быстрый,    замедляет зарядку до 30% на 3 с
#   CYCLIC (2) — цикличный,  двигается 10 с / стоит 10 с;
#                             при столкновении стоит 10 с + замедляет игрока 50% на 3 с
#
# Враги НЕ имеют собственного источника света — видны только в свете игрока
# (свет сонара тоже их раскрывает автоматически).

enum Type { SLOW, FAST, CYCLIC }

const CONTACT_RANGE       := 58.0
const PATH_UPDATE_INTERVAL := 0.45

const TYPE_SPEEDS := [58.0, 145.0, 88.0]

const TYPE_COLORS := [
	Color(0.55, 0.05, 0.80),   # SLOW:   глубокий фиолет
	Color(1.00, 0.48, 0.10),   # FAST:   яркий оранжевый
	Color(0.12, 0.88, 0.76),   # CYCLIC: бирюза
]

var enemy_type: int = Type.SLOW
var target: Node2D = null
var _game: Node = null
var spawn_level: int = 4   # уровень, на котором появился враг (влияет на силу эффекта)

var _path: PackedVector2Array = []
var _path_timer: float = 0.0

# Cyclic phase
var _moving: bool = true
var _phase_timer: float = 10.0

# Флаг контакта: предотвращает повторное срабатывание, пока игрок не вышел из зоны
var _contact_active: bool = false

func _ready() -> void:
	var col: Color = TYPE_COLORS[enemy_type]

	var core := Sprite2D.new()
	core.texture = MazeTextures.make_ball(15, col)
	add_child(core)

func _physics_process(delta: float) -> void:
	if target == null or not is_instance_valid(target):
		return

	var dist := global_position.distance_to(target.global_position)
	_handle_contact(dist)

	match enemy_type:
		Type.SLOW, Type.FAST:
			_update_path_follow(delta)
		Type.CYCLIC:
			_update_cyclic(delta)

# ---------- Контакт ----------

func _handle_contact(dist: float) -> void:
	if dist < CONTACT_RANGE:
		if not _contact_active:
			_contact_active = true
			_apply_contact_effect()
			# Цикличный враг останавливается на 10 с при столкновении
			if enemy_type == Type.CYCLIC:
				_moving = false
				_phase_timer = 10.0
	else:
		_contact_active = false

func _apply_contact_effect() -> void:
	if target == null or not is_instance_valid(target):
		return
	if not target.has_method("apply_enemy_effect"):
		return
	# steps = сколько раз сработал «шаг усложнения» (раз в 2 уровня от 4-го)
	var steps: int = maxi(0, (spawn_level - 4) / 2)
	match enemy_type:
		Type.SLOW:
			# 3с @ ур.4, +1с каждые 2 уровня → 11с @ ур.20
			var dur: float = 3.0 + float(steps)
			target.apply_enemy_effect("block_charge", dur)
		Type.FAST:
			# 3с @ ур.4, +0.5с каждые 2 уровня → 7с @ ур.20
			# Множитель зарядки: 0.30 @ ур.4 → 0.14 @ ур.20 (хуже игроку)
			var dur: float = 3.0 + 0.5 * float(steps)
			var mult: float = maxf(0.14, 0.30 - 0.02 * float(steps))
			target.apply_enemy_effect("slow_charge", dur, mult)
		Type.CYCLIC:
			# 3с @ ур.4, +0.5с каждые 2 уровня → 7с @ ур.20
			# Множитель скорости: 0.50 @ ур.4 → 0.35 @ ур.20
			var dur: float = 3.0 + 0.5 * float(steps)
			var mult: float = maxf(0.35, 0.50 - 0.02 * float(steps))
			target.apply_enemy_effect("slow_move", dur, mult)

# ---------- Движение ----------

func _update_path_follow(delta: float) -> void:
	_path_timer -= delta
	if _path_timer <= 0.0:
		_path_timer = PATH_UPDATE_INTERVAL
		_recalc_path()
	_follow_path(delta)

func _update_cyclic(delta: float) -> void:
	# Во время паузы (в т.ч. от контакта) только тикаем таймер
	if not _moving:
		_phase_timer -= delta
		if _phase_timer <= 0.0:
			_moving = true
			_phase_timer = 10.0
		return

	# Фаза движения
	_phase_timer -= delta
	if _phase_timer <= 0.0:
		_moving = false
		_phase_timer = 10.0
		return

	_path_timer -= delta
	if _path_timer <= 0.0:
		_path_timer = PATH_UPDATE_INTERVAL
		_recalc_path()
	_follow_path(delta)

func _follow_path(delta: float) -> void:
	if _path.is_empty():
		return
	var spd: float = TYPE_SPEEDS[enemy_type]
	var next: Vector2 = _path[0]
	var step := spd * delta
	if global_position.distance_to(next) <= step:
		global_position = next
		_path.remove_at(0)
	else:
		global_position = global_position.move_toward(next, step)

# ---------- BFS-навигация ----------

func _recalc_path() -> void:
	if _game == null or not is_instance_valid(_game):
		_game = _find_game()
	if _game == null or target == null or not is_instance_valid(target):
		return

	var floor_idx: int = target.current_floor
	var grids = _game._grids
	if floor_idx < 0 or floor_idx >= grids.size():
		return

	var grid: Array  = grids[floor_idx]
	var tile: float  = _game.TILE
	var gap: float   = _game._floor_gap
	var cols: int    = _game._cols
	var rows: int    = _game._rows

	var my_w := global_position - Vector2(0, floor_idx * gap)
	var ty_w := target.global_position - Vector2(0, floor_idx * gap)

	var sx := clampi(int(round((my_w.x / tile - 1.5) / 2.0)), 0, cols - 1)
	var sy := clampi(int(round((my_w.y / tile - 1.5) / 2.0)), 0, rows - 1)
	var ex := clampi(int(round((ty_w.x / tile - 1.5) / 2.0)), 0, cols - 1)
	var ey := clampi(int(round((ty_w.y / tile - 1.5) / 2.0)), 0, rows - 1)

	var start := Vector2i(sx, sy)
	var goal  := Vector2i(ex, ey)
	if start == goal:
		_path = PackedVector2Array()
		return

	var prev := {}
	var visited := {start: true}
	var queue: Array[Vector2i] = [start]
	var found := false

	while not queue.is_empty():
		var c: Vector2i = queue.pop_front()
		if c == goal:
			found = true
			break
		for d in [Vector2i(1,0), Vector2i(-1,0), Vector2i(0,1), Vector2i(0,-1)]:
			var n: Vector2i = c + d
			if n.x < 0 or n.x >= cols or n.y < 0 or n.y >= rows:
				continue
			if grid[c.y + n.y + 1][c.x + n.x + 1]:   # true = стена
				continue
			if not visited.has(n):
				visited[n] = true
				prev[n] = c
				queue.append(n)

	if not found:
		return

	var cells: Array[Vector2i] = []
	var cur := goal
	while cur != start:
		cells.append(cur)
		cur = prev[cur]
	cells.reverse()

	var out := PackedVector2Array()
	for cell in cells:
		out.append(Vector2(
			(cell.x * 2 + 1) * tile + tile * 0.5,
			(cell.y * 2 + 1) * tile + tile * 0.5
		) + Vector2(0, floor_idx * gap))
	_path = out

func _find_game() -> Node:
	var n := get_parent()
	while n != null:
		if n.has_method("guide_path_to_exit"):
			return n
		n = n.get_parent()
	return null
