extends SceneTree

# ИГРОВОЙ БОТ (запрос автора, GAMEDESIGN §94): играет вместо человека в ТРЁХ
# стилях и собирает статистику проходимости/багов.
#
#   speedrun — кратчайший BFS-путь к выходу, ничего не собирает;
#   pro      — «опытный игрок»: собирает все осколки этажа, заряжается на
#              станции при Свете < 45%, вспыхивает врага вплотную;
#   noob     — «глупый игрок»: случайно блуждает 90 игровых секунд, потом
#              всё равно добирается кратчайшим путём (win_late при победе).
#
# Бот ходит по НАСТОЯЩЕЙ игровой логике: маршруты только по открытым клеткам
# (BFS по сетке этажа), спуск — через настоящую дверь (с ожиданием телепорта
# и обработкой запертости), осколки/станции/враги/смерть — как у человека.
#
# Запуск: tools\bot.bat  (или godot --headless --path . -s res://tools/bot.gd)
# Переменные окружения: BOT_LEVELS="1,5,45"  BOT_MODES="speedrun,noob"  BOT_DIFF=2
#
# Строка результата каждого прогона (парсится обёрткой):
#   BOTRESULT|стиль|уровень|итог|время_с|смертей|уколов|осколков|застреваний
# Итог: BOT DONE  (или BOT FAILED, если какой-то прогон не дал результата —
# это само по себе сигнал о баге).
#
# test_mode выставляется КАЖДЫЙ кадр (защита сейва — CLAUDE.md), profiles.cfg
# сверяется обёрткой до/после.

const WAIT_FRAMES := 20          # кадров на загрузку сцены
const STUCK_SECONDS := 2.0       # нет продвижения дольше — застряли
const STUCK_EPSILON := 8.0       # «продвижение» = сместиться минимум на столько px
const RUN_TIMEOUT := 240.0       # игровой лимит прогона (speedrun/pro), сек
const NOOB_WANDER := 90.0        # сколько «глупый» блуждает сам, сек
const DOOR_WAIT := 1.2           # сколько ждать срабатывания двери, сек
const STEP_SPEED := 420.0        # скорость шага бота, px/с (игрок 320)
const FLASH_RANGE := 240.0       # «опытный» вспыхивает врага ближе этого
const DIRS := [Vector2i(1, 0), Vector2i(-1, 0), Vector2i(0, 1), Vector2i(0, -1)]

var scenarios: Array = []
var idx := -1
var frames := 0
var phase := ""                  # "load" / "play"
var r := {}                      # состояние текущего прогона
var total := {"win": 0, "win_late": 0, "timeout": 0, "game_over": 0, "no_result": 0}
var run_timeout := float(240.0)
var dbg := false

func _init() -> void:
	var env_t := OS.get_environment("BOT_TIMEOUT")
	if env_t != "":
		run_timeout = float(env_t)
	dbg = OS.get_environment("BOT_DEBUG") != ""
	var modes: Array = ["speedrun", "pro", "noob"]
	var levels: Array = [1, 3, 5, 10, 20, 30, 45, 50]
	var env_modes := OS.get_environment("BOT_MODES")
	var env_levels := OS.get_environment("BOT_LEVELS")
	if env_modes != "":
		modes = env_modes.split(",", false)
	if env_levels != "":
		levels = []
		for s in env_levels.split(",", false):
			levels.append(int(s))
	for mode in modes:
		for l in levels:
			scenarios.append({"mode": str(mode), "level": int(l)})

func _process(_d: float) -> bool:
	var gc = root.get_node("GameConfig")
	gc.test_mode = true   # каждый кадр: это сохраняемая настройка (CLAUDE.md)
	if idx < 0:
		Engine.time_scale = 3.0   # ускорение прогонов; delta масштабируется сам
		_next()
		return false
	frames += 1
	if phase == "load":
		if frames >= WAIT_FRAMES:
			_begin_run()
		return false
	_drive(_d)
	return false

# ── Жизненный цикл прогона ───────────────────────────────────────────────────

func _next() -> void:
	frames = 0
	phase = "load"
	var gc = root.get_node("GameConfig")
	gc.tutorial_mode = false
	gc.lair_mode = false
	gc.caves_mode = false
	gc.boss_test_enabled = false
	gc.active_run = -1
	idx += 1
	if idx >= scenarios.size():
		_finish_all()
		return
	var env_diff := OS.get_environment("BOT_DIFF")
	gc.difficulty = int(env_diff) if env_diff != "" else 1
	gc.level = int(scenarios[idx]["level"])
	change_scene_to_file("res://main.tscn")

func _begin_run() -> void:
	var m = current_scene
	if m == null or not m.has_method("_cell_neighbors") or m._player == null \
			or not is_instance_valid(m._player):
		_finish_run("no_result")
		return
	r = {
		"mode": str(scenarios[idx]["mode"]),
		"level": int(scenarios[idx]["level"]),
		"time": 0.0, "deaths": 0, "hits": 0, "stuck": 0,
		"was_active": true, "prev_energy": m._player.energy,
		"stuck_t": 0.0, "last_pos": m._player.global_position,
		"door_wait": 0.0, "path": [], "path_goal": Vector2i(-9, -9),
		"path_floor": -1, "wander": false, "detour": Vector2i(-1, -1),
		"wait_station": 0.0, "shards0": int(m._shards_collected),
		"boss_cells": {}, "limit": 0.0,
	}
	# Клетки дверей-боссов — табу для маршрутов: бот ходит «не глядя» и зайдя
	# на скрытую арену никак из неё не выходит (это не путь, а ловушка).
	var boss_script = load("res://boss_door.gd")
	for child in m.get_children():
		if is_instance_valid(child) and child.get_script() == boss_script:
			var bf: int = int(round(child.global_position.y / m._floor_gap))
			var bc := _cell_of(m, child.global_position, bf)
			r["boss_cells"][Vector3i(bf, bc.x, bc.y)] = true
	# Клетки ям (StaticBody2D, LADDER pits с 7-го уровня): физика выталкивает
	# из них, бот в них вязнет. Маршруты идут вокруг; яму в «коридоре без
	# обхода» бот перепрыгивает (vault в блоке застревания) — как игрок Рывком.
	r["pit_cells"] = {}
	for pit in get_nodes_in_group("pit"):
		if is_instance_valid(pit):
			var pf: int = _floor_of_pos(m, pit.global_position)
			var pc := _cell_of(m, pit.global_position, pf)
			r["pit_cells"][Vector3i(pf, pc.x, pc.y)] = true
	# Лимит — от размера уровня, если не задан BOT_TIMEOUT: мега 45+ не
	# прогнать за бюджет маленького L1.
	if OS.get_environment("BOT_TIMEOUT") != "":
		r["limit"] = run_timeout
	else:
		# L5-урок: даже «маленький» уровень бывает 4-этажным, а мега-этажи несут
		# маршруты по 50+ клеток (L20: этаж 1, (22,17)->(40,0)). Бюджет с запасом.
		r["limit"] = 200.0 + 8.0 * float(r["level"])
	# Бот «сделал первый шаг»: без этого started=false и игра молча не тикает
	# (расход Света, враги, события, таймер) — статистика была бы фальшивой.
	m._player.started = true
	phase = "play"
	frames = 0

func _finish_run(result: String) -> void:
	total[result] = int(total.get(result, 0)) + 1
	var m = current_scene
	var shards := 0
	if m != null and is_instance_valid(m) and not r.is_empty():
		shards = int(m._shards_collected) - int(r.get("shards0", 0))
	if result == "no_result" and r.get("why", "") != "":
		print("BOTWHY|%s|%d|%s" % [str(r.get("mode", "?")), int(r.get("level", 0)), str(r["why"])])
	print("BOTRESULT|%s|%d|%s|%.1f|%d|%d|%d|%d" % [
		str(r.get("mode", "?")), int(r.get("level", 0)), result,
		float(r.get("time", 0.0)), int(r.get("deaths", 0)),
		int(r.get("hits", 0)), shards, int(r.get("stuck", 0))])
	_next()

func _finish_all() -> void:
	print("BOT: прогонов %d | win %d | win_late %d | timeout %d | game_over %d | no_result %d" % [
		scenarios.size(), total["win"], total["win_late"],
		total["timeout"], total["game_over"], total["no_result"]])
	print("BOT DONE" if int(total["no_result"]) == 0 else "BOT FAILED")
	quit(0 if int(total["no_result"]) == 0 else 1)

# ── Управление игроком (каждый кадр фазы play) ──────────────────────────────

func _drive(delta: float) -> void:
	var m = current_scene
	if m == null or not is_instance_valid(m) or m._player == null \
			or not is_instance_valid(m._player):
		return
	var p = m._player
	# delta главного цикла SceneTree — РЕАЛЬНЫЙ (time_scale его не масштабирует),
	# а лимиты ниже — в ИГРОВЫХ секундах: нормализуем, иначе таймауты срабатывают
	# втрое позже (батарея 24 прогонов ползла 40+ минут вместо ~20).
	r["time"] = float(r["time"]) + delta * Engine.time_scale

	# Победа/конец забега — ДО учёта смертей: победа тоже гасит active, и без
	# этого порядка она считалась бы «смертью» в строке результата.
	if m._game_over:
		_finish_run("game_over")
		return
	if m._won:
		_finish_run("win_late" if bool(r["wander"]) else "win")
		return
	# Смерть/возрождение: считаем падения active.
	if bool(r["was_active"]) and not p.active:
		r["deaths"] = int(r["deaths"]) + 1
	r["was_active"] = p.active
	# Урон: заметное падение Света за кадр (разрядка меньше порога).
	var e_drop: float = float(r["prev_energy"]) - p.energy
	if e_drop > 0.04:
		r["hits"] = int(r["hits"]) + 1
	r["prev_energy"] = p.energy
	# Мёртв/возрождается (пауза 1.2 с в main.on_player_death) — не двигаем.
	if not p.active:
		return
	# Страховка: бот не должен попасть в арену босса (двери блокированы в
	# маршрутах); если попал — из арены нет выхода, фиксируем сразу.
	if bool(m._boss_arena_mode):
		r["why"] = "зашёл в арену босса"
		_finish_run("no_result")
		return

	# Лимит времени; «глупый» после блуждания добирается кратчайшим путём.
	var limit := NOOB_WANDER if (r["mode"] == "noob" and not bool(r["wander"])) else float(r["limit"])
	if float(r["time"]) > limit:
		if r["mode"] == "noob":
			r["wander"] = true
			r["path"] = []
		else:
			_finish_run("timeout")
			return

	var f: int = int(p.current_floor)
	var here := _cell_of(m, p.global_position, f)

	# Ожидание срабатывания двери: стоим на клетке двери до смены этажа.
	if float(r["door_wait"]) > 0.0:
		r["door_wait"] = float(r["door_wait"]) - delta
		if f != int(r["path_floor"]):
			r["door_wait"] = 0.0
			r["path"] = []
			r["detour"] = Vector2i(-1, -1)
		return

	# Цель по стилю.
	var goal := Vector2i(-1, -1)
	match r["mode"]:
		"speedrun":
			goal = _descend_goal(m, f, here)
		"pro":
			goal = _pro_goal(m, p, f, here)
		"noob":
			goal = _noob_goal(m, p, f, here)
	if goal.x < 0:
		r["why"] = "нет цели на этаже %d (выход/дверь не найдены)" % f
		_finish_run("no_result")
		return

	# Маршрут: BFS по открытым клеткам СВОЕГО этажа; пересчёт при смене цели/
	# этажа или после застревания. Спуск через дверь — waypoint'ы ведут к ней.
	if r["detour"].x >= 0:
		goal = r["detour"]   # обходная клетка после застревания (1 шаг)
	if int(r["path_floor"]) != f or Vector2i(r["path_goal"]) != goal \
			or (r["path"].is_empty() and here != goal):
		r["path"] = _bfs_path(m, f, here, goal)
		r["path_goal"] = goal
		r["path_floor"] = f

	# Шаг к первому waypoint'у маршрута. Сосед по BFS отличается ровно по ОДНОЙ
	# оси, поэтому движение по его центру — уже осевое (линия клетки к клетке).
	# Подправка к центру своей клетки — только при РЕАЛЬНОМ заносе (>4 px от
	# линии, толкали враги/физика): условие «>1 px» тянуло игрока ОБРАТНО к
	# центру текущей клетки каждый кадр, и тот осциллировал у поворотов.
	var target: Vector2
	if r["path"].is_empty():
		target = _cell_world(m, goal, f)   # стоим в цели (станция/дверь)
	else:
		var wp: Vector2i = r["path"][0]
		var cur_c := _cell_world(m, here, f)
		var wp_w := _cell_world(m, wp, f)
		if wp.x != here.x:
			if absf(p.global_position.y - cur_c.y) > 4.0:
				target = Vector2(p.global_position.x, cur_c.y)   # вернуться на линию ряда
			else:
				target = wp_w
		else:
			if absf(p.global_position.x - cur_c.x) > 4.0:
				target = Vector2(cur_c.x, p.global_position.y)   # вернуться на линию колонны
			else:
				target = wp_w
	# Скорость бота — в ИГРОВОМ времени (×time_scale): иначе при ускорении ×3
	# игровые часы (свет, враги, таймаут) обгоняют ходьбу втрое и лимиты
	# сгорают на середине маршрута. Кап 40 px — меньше полуклетки, чтобы
	# скачок delta на первом кадре не перебрасывал через стену.
	var step: float = minf(STEP_SPEED * delta * Engine.time_scale, 40.0)
	if p.global_position.distance_to(target) <= maxf(step, 6.0):
		p.global_position = target
		if not r["path"].is_empty():
			r["path"].pop_front()
		if _is_door_cell(m, f, _cell_of(m, p.global_position, f)) \
				and int(p.current_floor) == f:
			r["door_wait"] = DOOR_WAIT
			r["path_floor"] = f
			return
		r["detour"] = Vector2i(-1, -1)
	else:
		p.global_position = p.global_position.move_toward(target, step)

	# Застревание: нет продвижения — сначала vault через яму (если следующий
	# waypoint — яма: игрок так же перепрыгивает Рывком), затем рывок и
	# обходная клетка.
	if p.global_position.distance_to(r["last_pos"]) < STUCK_EPSILON:
		r["stuck_t"] = float(r["stuck_t"]) + delta
		if float(r["stuck_t"]) >= STUCK_SECONDS:
			r["stuck"] = int(r["stuck"]) + 1
			r["stuck_t"] = 0.0
			var cf2: int = int(p.current_floor)
			# vault через яму: следующий waypoint за ямой — переносим себя туда.
			if not (r["path"] as Array).is_empty():
				var nxt: Vector2i = (r["path"] as Array)[0]
				if _is_pit(m, cf2, nxt):
					p.global_position = _cell_world(m, nxt, cf2)
					(r["path"] as Array).pop_front()
					r["last_pos"] = p.global_position
					return
			r["path"] = []
			p._facing = (target - p.global_position).normalized()
			p._try_dash()
			if r["detour"].x < 0:
				var cf: int = int(p.current_floor)
				var grid: Array = m._grids[cf]
				var hc := _cell_of(m, p.global_position, cf)
				for d in DIRS:
					var n: Vector2i = hc + d
					if _can_step(m, cf, grid, hc, n):
						r["detour"] = n
						break
	else:
		r["stuck_t"] = 0.0
	r["last_pos"] = p.global_position

	if dbg and frames % 30 == 0:
		print("BOTDBG|f%d|fps=%d|pos=%s|loc=%s|vel=%s|floor=%d|here=%s|goal=%s|path=%d|won=%s|over=%s" % [
			frames, Engine.get_frames_per_second(), str(p.global_position), str(p.position),
			str(p.velocity), f, str(here), str(goal),
			(r["path"] as Array).size(), str(m._won), str(m._game_over)])

	# «Опытный» вспыхивает врага вплотную (урон + отгон).
	if r["mode"] == "pro" and p.has_method("_try_flash"):
		for e in get_nodes_in_group("enemy"):
			if is_instance_valid(e) and e.global_position.distance_to(p.global_position) < FLASH_RANGE:
				p._try_flash()
				break

# ── Цели по стилям ───────────────────────────────────────────────────────────

func _descend_goal(m: Node, f: int, from: Vector2i) -> Vector2i:
	if f == m._exit_floor:
		return m._exit_cell
	# Первая в _door_links дверь вниз создана первой парой (p == 0, всегда
	# открыта — main.gd::_place_doors). Словарь хранит порядок вставки.
	for k in m._door_links.keys():
		if int(k.x) != f:
			continue
		for nb in m._door_links[k]:
			if int(nb.x) == f + 1:
				return Vector2i(int(k.y), int(k.z))
	return Vector2i(-1, -1)

func _pro_goal(m: Node, p, f: int, here: Vector2i) -> Vector2i:
	# 1) Станция при низком Свете. 2) Осколки этажа. 3) Спуск.
	if p.energy < p.max_energy * 0.45:
		var st = _nearest_of_floor(m, "station", f)
		if st != null:
			if p.global_position.distance_to(st.global_position) < 70.0:
				r["wait_station"] = float(r["wait_station"]) + 0.016
				if p.energy >= p.max_energy * 0.95 or float(r["wait_station"]) > 6.0:
					r["wait_station"] = 0.0
				return here   # стоим в зоне и заряжаемся
			return _cell_of(m, st.global_position, f)
	var sh = _nearest_shard(m, f)
	if sh != null:
		return _cell_of(m, sh.global_position, f)
	return _descend_goal(m, f, here)

func _noob_goal(m: Node, p, f: int, here: Vector2i) -> Vector2i:
	# Случайное блуждание; после NOOB_WANDER — как speedrun (win_late при победе).
	if not bool(r["wander"]):
		if r["detour"].x >= 0:
			return r["detour"]
		var grid: Array = m._grids[f]
		var options: Array = []
		for d in DIRS:
			var n: Vector2i = here + d
			if _can_step(m, f, grid, here, n):
				options.append(n)
		if not options.is_empty():
			var pick: Vector2i = options[randi() % options.size()]
			r["detour"] = pick
			return pick
	return _descend_goal(m, f, here)

# ── Помощники навигации ──────────────────────────────────────────────────────

# Шаг из c в n легален: обе клетки открыты И нет стены МЕЖДУ ними (маска
# лабиринта: grid[c.y+n.y+1][c.x+n.x+1] — как в pursuer._bfs_path). Без
# проверки стены бот планировал маршруты СКВОЗЬ стены и вяз в физике.
func _can_step(m: Node, f: int, grid: Array, c: Vector2i, n: Vector2i) -> bool:
	if n.x < 0 or n.x >= m._cols or n.y < 0 or n.y >= m._rows:
		return false
	if grid[n.y * 2 + 1][n.x * 2 + 1]:
		return false
	if r.get("boss_cells", {}).has(Vector3i(f, n.x, n.y)):
		return false   # дверь-босса: в скрытую арену боту хода нет
	return not grid[c.y + n.y + 1][c.x + n.x + 1]

# Яма на клетке? Маршруты обходят ямы (физика выталкивает из StaticBody2D),
# но если яма перегораживает единственный проход — бот «перепрыгивает» её
# (vault) прямым переносом за яму: игрок делает то же самое Рывком.
func _is_pit(m: Node, f: int, c: Vector2i) -> bool:
	return r.get("pit_cells", {}).has(Vector3i(f, c.x, c.y))

func _bfs_path(m: Node, f: int, from: Vector2i, to: Vector2i) -> Array:
	if from == to:
		return [to]
	var grid: Array = m._grids[f]
	var prev := {from: from}
	var q: Array = [from]
	while not q.is_empty():
		var c: Vector2i = q.pop_front()
		if c == to:
			break
		for d in DIRS:
			var n: Vector2i = c + d
			if prev.has(n):
				continue
			if not _can_step(m, f, grid, c, n):
				continue
			prev[n] = c
			q.append(n)
	if not prev.has(to):
		return []
	var path: Array = []
	var cur: Vector2i = to
	while cur != from:
		path.append(cur)
		cur = prev[cur]
	path.reverse()
	return path

func _is_door_cell(m: Node, f: int, c: Vector2i) -> bool:
	for k in m._door_links.keys():
		if int(k.x) == f and int(k.y) == c.x and int(k.z) == c.y:
			return true
	return false

func _cell_world(m: Node, c: Vector2i, f: int) -> Vector2:
	return m._cell_to_world(c) + Vector2(0, f * m._floor_gap)

func _cell_of(m: Node, world_pos: Vector2, f: int) -> Vector2i:
	var tile: float = m.TILE
	var local: Vector2 = world_pos - Vector2(0, f * m._floor_gap)
	return Vector2i(clampi(int(round((local.x / tile - 1.5) / 2.0)), 0, m._cols - 1),
		clampi(int(round((local.y / tile - 1.5) / 2.0)), 0, m._rows - 1))

func _floor_of_pos(m: Node, pos: Vector2) -> int:
	return int(round(pos.y / m._floor_gap))

func _nearest_shard(m: Node, f: int):
	var best = null
	var best_d := INF
	var p = m._player
	for s in get_nodes_in_group("shard"):
		if not is_instance_valid(s) or _floor_of_pos(m, s.global_position) != f:
			continue
		var d: float = s.global_position.distance_to(p.global_position)
		if d < best_d:
			best_d = d
			best = s
	return best

func _nearest_of_floor(m: Node, group: String, f: int):
	var best = null
	var best_d := INF
	var p = m._player
	for n in get_nodes_in_group(group):
		if not is_instance_valid(n) or _floor_of_pos(m, n.global_position) != f:
			continue
		var d: float = n.global_position.distance_to(p.global_position)
		if d < best_d:
			best_d = d
			best = n
	return best
