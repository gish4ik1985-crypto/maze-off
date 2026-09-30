extends RefCounted

# Вынесено из main.gd механически (tools/extract_fn.py, v6.8): код функций
# тот же, что был в main.gd; `g` — главный узел, все его члены с префиксом `g.`.
# Состояние остаётся в main.gd (переменные `_hud_layer`, `_vitals`, …).

static func _build_cave_floor_graph(g) -> void:
	g._caves_graph_active = true
	var level_size = Vector2(float(g._cols) * g.TILE * 1.7, float(g._rows) * g.TILE * 1.7)
	var node_count: int = clampi(int(float(g._cols * g._rows) / 9.0), 8, 160)
	# [BUGFIX 01.08.2026, §62] Расширено с TILE*0.95 — на резких неровных
	# поворотах у игрока (радиус 14) было мало запаса, из-за чего он
	# застревал при диагональном вводе (см. заметку у CaveGraph.edge_polyline
	# про причину — скольжение вдоль стен в player.gd рассчитано на прямые
	# углы). Более широкий тоннель прощает угол поворота, даже когда сама
	# ломаная всё ещё неровная (см. правку amplitude/mid_count там же).
	var branch_width: float = g.TILE * 1.2
	var rng = RandomNumberGenerator.new()
	rng.seed = randi()   # наследует seed()-детерминизм Спуска дня, выставленный выше в _build_world

	# [BUGFIX 01.08.2026, §62] CaveGraph.generate сэмплирует узлы РАВНОМЕРНО
	# по всему [0,size] прямоугольнику, включая сам край, — не глядя на
	# border_margin/рамку коллизии ниже. Живой харнесс поймал ровно это:
	# случайный вход оказался с координатой, СОВПАДАЮЩЕЙ с level_size.y
	# (буквально на границе уровня) — игрок заспавнился внутри защитной
	# рамки. Резервируем отступ ЗДЕСЬ, генерируя граф в урезанном
	# прямоугольнике и сдвигая все узлы/ломаные внутрь на edge_margin —
	# ни один узел физически не может оказаться ближе edge_margin к краю.
	var edge_margin: float = g.TILE * 2.0
	var gen_size = Vector2(maxf(200.0, level_size.x - edge_margin * 2.0), maxf(200.0, level_size.y - edge_margin * 2.0))
	var offset = Vector2(edge_margin, edge_margin)
	var nodes: Array = []
	var polylines: Array = []
	# [BUGFIX 01.08.2026, §62] Даже с запасом между радиусами узлов
	# (CaveGraph.generate) извилистые рёбра иногда проходят достаточно
	# близко к чужому несвязанному узлу/ребру, чтобы физически соприкоснуться
	# в растровой маске — между формально несвязанными частями графа тогда
	# нет стены вообще (баг «игрок проходит сквозь стены», репродуцирован
	# живой игрой). Полная гарантия на этапе генерации была бы геометрической
	# маршрутизацией с учётом препятствий — вместо этого перегенерируем с
	# новым сидом до CAVE_GEN_MAX_ATTEMPTS раз, если утечка обнаружена
	# постфактум (CaveCollision.has_leak). На проверенных сериях сидов
	# несколько попыток почти всегда достаточно.
	const CAVE_GEN_MAX_ATTEMPTS = 6
	# [BUGFIX 02.08.2026, §62] Станция/тёмная станция/мимик ставятся на узел
	# графа с CircleShape2D радиусом 40 (station.gd/dark_station.gd/mimic.gd).
	# Старый room_radius_min = TILE*0.75 = 36 иногда давал узлы МЕНЬШЕ этого
	# радиуса — пикап физически торчал своим кругом за пределы проходимой
	# комнаты, прямо в стену (репродуцировано харнессом cave_station_bug_hunt,
	# см. GAMEDESIGN.md §62: L1 попытка 0, узел радиусом 36.01 против пикапа
	# 40 — выступ ~4 юнита). Минимум поднят так, чтобы ЛЮБОЙ узел графа был
	# больше самого крупного пикапа с запасом.
	var CAVE_ROOM_RADIUS_MIN = g.TILE * 0.95   # 45.6, > 40 (макс. радиус пикапа)
	# [BUGFIX 04.08.2026, v4.4] Было 0.15 — жалоба «лабиринты слишком
	# предсказуемы»: харнесс-замер (§69, GAMEDESIGN) показал граф почти без
	# циклов (средняя степень узла ~2.0-2.3, тупики 20-29%) — по сути дерево
	# с редкими короткими развилками, один верный путь почти всегда. Поднято
	# до 0.4 вместе с EXTRA_LOOP_REACH (cave_graph.gd) — вместе дают заметно
	# больше настоящих петель без изменения плотности узлов/размера этажа.
	const CAVE_EXTRA_LOOP_RATIO = 0.25
	for attempt in CAVE_GEN_MAX_ATTEMPTS:
		g._cave_graph = CaveGraph.generate(gen_size, node_count, branch_width * 1.6, CAVE_EXTRA_LOOP_RATIO, CAVE_ROOM_RADIUS_MIN, g.TILE * 1.35, rng)
		nodes = g._cave_graph["nodes"]
		for i in nodes.size():
			nodes[i] = nodes[i] + offset
		polylines = g._cave_graph["polylines"]
		for pi in polylines.size():
			var pts: PackedVector2Array = polylines[pi]
			for i in pts.size():
				pts[i] = pts[i] + offset
			polylines[pi] = pts
		# Явная перезапись — не полагаемся на то, что Array-значение внутри
		# Dictionary всегда мутируется "через" локальную переменную-ссылку.
		g._cave_graph["nodes"] = nodes
		g._cave_graph["polylines"] = polylines
		if not CaveCollision.has_leak(g._cave_graph, level_size, g.CAVE_MASK_RESOLUTION, branch_width, g.TILE * 0.4):
			break
		rng.seed = randi()

	var edges: Array = g._cave_graph["edges"]
	var pick = CaveGraph.pick_entry_exit(nodes, edges, rng)
	var entry_node: int = pick["entry"]
	var exit_node: int = pick["exit"]
	g._cave_entry_node = entry_node
	g._cave_exit_node = exit_node

	var dummy_grid: Array = []
	dummy_grid.resize(g._gh)
	for y in g._gh:
		var row = []
		row.resize(g._gw)
		for x in g._gw:
			row[x] = false
		dummy_grid[y] = row
	g._grids.append(dummy_grid)

	var container = Node2D.new()
	container.name = "CaveFloor0"
	g.add_child(container)
	# [BUGFIX 01.08.2026, §62] border_margin в маске — лёгкий запас (не
	# основная защита от побега за карту, для этого есть отдельная жёсткая
	# рамка в CaveFloorBuild._add_boundary_frame). Держим МАЛЕНЬКИМ намеренно:
	# первая версия использовала TILE*1.5=72 — этого хватало, чтобы съесть
	# ЦЕЛУЮ комнату у края, если туда случайно попадал вход/выход (проверено
	# живым харнессом: игрок заспавнился прямо в стене). Margin должен только
	# закрывать щели контура у самого края маски, не откусывать игровое
	# пространство.
	CaveFloorBuild.build(container, g._cave_graph, level_size, g.CAVE_MASK_RESOLUTION, branch_width, g.TILE, g._wall_color, g.TILE * 0.4)
	g._floor_containers.resize(maxi(g._floor_containers.size(), 1))
	g._floor_containers[0] = container
	g._floor_built[0] = true

	var entry_pos: Vector2 = nodes[entry_node]
	var exit_pos: Vector2 = nodes[exit_node]
	# Приближённые клетки заглушки-сетки — нужны только для generic-кода
	# (минимап/Искра/оптимальный путь), реальную позицию игрока/выхода ниже
	# выставляем напрямую из графа, не через эти клетки.
	g._entry_cell = g._world_to_cell(entry_pos, 0)
	g._exit_cell = g._world_to_cell(exit_pos, 0)
	g._exit_floor = 0
	g._draft_dirty = true   # [§72] выход переехал — поле тяги пересчитать

	g._spawn_player()
	g._player.position = entry_pos
	g._start_exit_dist = maxf(1.0, entry_pos.distance_to(exit_pos))

	var exit = Area2D.new()
	exit.set_script(load("res://exit.gd"))
	exit.game = g
	exit.position = exit_pos
	g.add_child(exit)
	g._exit_node = exit
	g._refresh_exit_lock()

	g._spawn_cave_pickups(nodes, entry_node, container)
	g._spawn_cave_hazards(nodes, edges, entry_node, exit_node, container)
	if GameConfig.darkness_chaser and g._level >= 4:
		g._spawn_cave_enemies(nodes, edges, entry_node)

	g._compute_optimal_path_len()
	# [§62, v.4.2] _events_enabled НЕ трогаем (остаётся тем, что уже задал
	# общий код выше в _build_world) — _roll_event_kind() сама исключает
	# quake/shift/fog для графовых Пещер (см. ветвление там), общий
	# рубильник больше не нужен.

static func _spawn_cave_pickups(g, nodes: Array, entry_node: int, container: Node2D) -> void:
	var spawnable: Array = CaveGraph.spawnable_nodes(nodes, entry_node)
	spawnable.shuffle()

	var station_target: int = clampi(int(float(nodes.size()) * 0.22), GameConfig.station_count, g.MAX_CAVES_STATIONS)
	var station_n: int = mini(station_target, spawnable.size())
	var used = {}
	for i in station_n:
		var idx: int = spawnable[i]
		used[idx] = true
		var st = Area2D.new()
		st.set_script(load("res://station.gd"))
		st.game = g
		st.floor_index = 0
		st.position = nodes[idx]
		container.add_child(st)

	var cave_gate: bool = not (g._boss_level or g._lair_active or g._superboss_level or GameConfig.tutorial_mode or g._hard)
	var extra_cursor: int = station_n
	if cave_gate and g._mech_ready("dark_stations") and randf() <= g._biome_chance("dark_stations"):
		var n: int = mini(1 + g._caves_density_step(), 3)
		var count: int = mini(n, spawnable.size() - extra_cursor)
		for i in count:
			var idx: int = spawnable[extra_cursor + i]
			used[idx] = true
			var ds = Area2D.new()
			ds.set_script(load("res://dark_station.gd"))
			ds.game = g
			ds.floor_index = 0
			ds.position = nodes[idx]
			container.add_child(ds)
		extra_cursor += count

	if cave_gate and g._mech_ready("mimics") and randf() <= g._biome_chance("mimics"):
		var n: int = mini(1 + g._caves_density_step(), 2)
		var count: int = mini(n, spawnable.size() - extra_cursor)
		for i in count:
			var idx: int = spawnable[extra_cursor + i]
			used[idx] = true
			var m = Area2D.new()
			m.set_script(load("res://mimic.gd"))
			m.game = g
			m.floor_index = 0
			m.is_graph_mode = true
			m.position = nodes[idx]
			container.add_child(m)
		extra_cursor += count

	var shard_candidates: Array = []
	for idx in spawnable:
		if not used.has(idx):
			shard_candidates.append(idx)
	if shard_candidates.is_empty():
		shard_candidates = spawnable   # запасной путь: лучше рядом со станцией, чем нигде
	var sc: int = mini(g.SHARDS_PER_FLOOR, shard_candidates.size())
	for i in sc:
		var sh = Area2D.new()
		sh.set_script(load("res://shard.gd"))
		sh.game = g
		sh.position = nodes[shard_candidates[i]]
		container.add_child(sh)
		g._shards_total += 1
	g._shards_remaining.resize(1)
	g._shards_remaining[0] = sc

static func _spawn_cave_hazards(g, nodes: Array, edges: Array, entry_node: int, exit_node: int, container: Node2D) -> void:
	var cave_gate: bool = not (g._boss_level or g._lair_active or g._superboss_level or GameConfig.tutorial_mode)

	# Ямы (§17.5) — не гейтятся _hard (преграда, не расход света).
	if cave_gate and g._mech_ready("pits") and randf() <= g._biome_chance("pits"):
		var want: int = mini(1 + g._caves_density_step(), 3)
		var candidates: Array = CaveGraph.spawnable_nodes(nodes, entry_node)
		candidates.shuffle()
		var placed_pos: Array[Vector2] = []
		var placed = 0
		for idx in candidates:
			if idx == exit_node:
				continue
			var pos: Vector2 = nodes[idx]
			var too_close = false
			for p in placed_pos:
				if p.distance_to(pos) < g.TILE * 8.0:
					too_close = true
					break
			if too_close:
				continue
			var pit = StaticBody2D.new()
			pit.set_script(load("res://pit.gd"))
			pit.game = g
			pit.floor_index = 0
			pit.position = pos
			container.add_child(pit)
			placed_pos.append(pos)
			placed += 1
			if placed >= want:
				break

	# Срезки (§17.4) — пара узлов, достаточно далёких по КРАТЧАЙШЕМУ ПУТИ
	# графа (не по прямой — иначе «срезка» ничего не срезала бы).
	if cave_gate and g._mech_ready("shortcut") and randf() <= g._biome_chance("shortcut"):
		var want_pairs: int = mini(1 + g._caves_density_step() / 2, 2)
		var used_nodes = {}
		for _pair in want_pairs:
			var cand: Array = []
			for idx in CaveGraph.spawnable_nodes(nodes, entry_node):
				if not used_nodes.has(idx):
					cand.append(idx)
			cand.shuffle()
			if cand.is_empty():
				break
			var a: int = cand[0]
			var result = CaveGraph.dijkstra(nodes, edges, a)
			var dist: Array = result["dist"]
			var far: Array = []
			for idx in cand:
				if idx != a and dist[idx] != INF and dist[idx] >= g.SHORTCUT_MIN_DIST_WORLD:
					far.append(idx)
			if far.is_empty():
				break
			var b: int = far[randi() % far.size()]
			used_nodes[a] = true
			used_nodes[b] = true
			var pa = Area2D.new()
			pa.set_script(load("res://shortcut_portal.gd"))
			pa.game = g
			pa.floor_index = 0
			pa.position = nodes[a]
			container.add_child(pa)
			var pb = Area2D.new()
			pb.set_script(load("res://shortcut_portal.gd"))
			pb.game = g
			pb.floor_index = 0
			pb.position = nodes[b]
			container.add_child(pb)
			pa.partner = pb
			pb.partner = pa

static func _spawn_cave_enemies(g, nodes: Array, edges: Array, entry_node: int) -> void:
	# [BUGFIX 02.08.2026, v4.4] Раньше количество росло фиксированным шагом
	# — +1 враг каждые 4 уровня, потолок 6 на тип — под старую 10-уровневую
	# шкалу Пещер и её потолок ~44 узла. После расширения до 20 уровней
	# (максимум графа — 156 узлов, §64) тот же шаг давал всего 5 врагов на
	# крупнейшей Пещере: то, что раньше было почти пределом режима, осталось
	# почти пределом и на графе в 3.5 раза крупнее — пусто и неопасно на
	# позднем этапе. ПОРЯДОК введения типов (степень: SLOW с 4-го уровня,
	# FAST с 8-го, CYCLIC с 12-го) не трогаем — знакомство с новым типом уже
	# откалибровано верно. Меняем только КОЛИЧЕСТВО: масштабируем числом
	# узлов графа, тем же принципом, что уже держит плотность станций
	# (_spawn_cave_pickups, 0.22 * nodes.size()) — растёт вместе с картой, а
	# не шагом раз в 4 уровня.
	var unlocked: Array[int] = []
	var step = 4
	while step <= g._level:
		var idx: int = int((step - 4) / 4) % 3
		if not unlocked.has(idx):
			unlocked.append(idx)
		step += 4
	if unlocked.is_empty():
		return
	var total: int = clampi(int(nodes.size() * 0.075), unlocked.size(), 18)
	var types: Array = []
	for i in total:
		types.append(unlocked[i % unlocked.size()])
	if types.is_empty():
		return
	types.shuffle()

	var result = CaveGraph.dijkstra(nodes, edges, entry_node)
	var dist: Array = result["dist"]
	var far_nodes: Array = []
	var max_d = 0.0
	for d in dist:
		if d != INF:
			max_d = maxf(max_d, d)
	for i in nodes.size():
		if i != entry_node and dist[i] != INF and dist[i] > max_d * 0.4:
			far_nodes.append(i)
	if far_nodes.is_empty():
		far_nodes = CaveGraph.spawnable_nodes(nodes, entry_node)
	far_nodes.shuffle()

	for i in types.size():
		if far_nodes.is_empty():
			break
		var node_idx: int = far_nodes[i % far_nodes.size()]
		var pur = Node2D.new()
		pur.set_script(load("res://pursuer.gd"))
		pur.enemy_type = int(types[i])
		pur.spawn_level = g._level
		pur._enemy_floor = 0
		pur.position = nodes[node_idx]
		pur.target = g._player
		pur._game = g
		pur.process_mode = Node.PROCESS_MODE_PAUSABLE
		g.add_child(pur)
