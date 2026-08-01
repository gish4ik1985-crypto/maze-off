class_name CaveGraph
extends RefCounted

## §62 (GAMEDESIGN.md): генератор графа для настоящих кротовых нор — узлы
## (комнаты-пузыри) + минимальное остовное дерево (гарантия связности) +
## немного лишних рёбер сверх дерева (петли-развилки). Чистая функция без
## побочных эффектов — не трогает сцену/рендер, только данные графа.
##
## Возвращает Dictionary:
##   "nodes": Array[Vector2]  — позиции узлов в прямоугольнике [0,size]
##   "radii": Array[float]    — радиус камеры каждого узла
##   "edges": Array[Vector2i] — рёбра (индексы узлов), включает MST + лишние
##   "mst_edges": Array[Vector2i] — только рёбра дерева (для отладки/харнесса)
##   "polylines": Array[PackedVector2Array] — ломаная каждого ребра (§62 шаг 2:
##       midpoint displacement, откуда берутся неровные углы), тот же порядок,
##       что и "edges"
static func generate(
	size: Vector2,
	node_count: int,
	min_node_dist: float,
	extra_loop_ratio: float,
	room_radius_min: float,
	room_radius_max: float,
	rng: RandomNumberGenerator
) -> Dictionary:
	var nodes := _sample_nodes(size, node_count, min_node_dist, rng)
	var radii: Array[float] = []
	for i in nodes.size():
		radii.append(rng.randf_range(room_radius_min, room_radius_max))

	var mst_edges := _build_mst(nodes)
	var extra_edges := _extra_loop_edges(nodes, mst_edges, extra_loop_ratio, rng)

	var all_edges: Array[Vector2i] = []
	all_edges.append_array(mst_edges)
	all_edges.append_array(extra_edges)

	var polylines: Array[PackedVector2Array] = []
	for e in all_edges:
		polylines.append(edge_polyline(nodes[e.x], nodes[e.y], rng))

	return {
		"nodes": nodes,
		"radii": radii,
		"edges": all_edges,
		"mst_edges": mst_edges,
		"polylines": polylines,
	}

## §62 шаг 2: ломаная между двумя узлами вместо прямой линии — источник
## неровных углов поворота. 2-4 промежуточные точки вдоль прямой a→b,
## каждая сдвинута случайно перпендикулярно прямой (midpoint displacement,
## amplitude ~18% от длины ребра, но не больше max_offset_cap чтобы длинные
## рёбра не сворачивались петлёй на себя).
static func edge_polyline(a: Vector2, b: Vector2, rng: RandomNumberGenerator) -> PackedVector2Array:
	var pts := PackedVector2Array()
	pts.append(a)
	var seg := b - a
	var length := seg.length()
	if length < 0.001:
		pts.append(b)
		return pts
	var dir := seg / length
	var normal := Vector2(-dir.y, dir.x)
	var mid_count := rng.randi_range(2, 4)
	var max_offset: float = minf(length * 0.18, length * 0.5)
	for i in mid_count:
		var t := float(i + 1) / float(mid_count + 1)
		var base := a + seg * t
		var offset := rng.randf_range(-max_offset, max_offset)
		pts.append(base + normal * offset)
	pts.append(b)
	return pts

## Poisson-disk-подобная выборка с отбраковкой: случайная точка внутри
## прямоугольника принимается, только если она не ближе min_dist к уже
## принятым узлам. Ограничение по попыткам — на случай, если node_count
## слишком велико для площади/min_dist (тогда возвращаем сколько влезло).
static func _sample_nodes(size: Vector2, node_count: int, min_dist: float, rng: RandomNumberGenerator) -> Array[Vector2]:
	var nodes: Array[Vector2] = []
	var max_attempts := node_count * 60
	var attempts := 0
	while nodes.size() < node_count and attempts < max_attempts:
		attempts += 1
		var p := Vector2(rng.randf_range(0.0, size.x), rng.randf_range(0.0, size.y))
		var ok := true
		for n in nodes:
			if n.distance_to(p) < min_dist:
				ok = false
				break
		if ok:
			nodes.append(p)
	return nodes

## Прим: строим минимальное остовное дерево по евклидовым расстояниям между
## узлами. Гарантирует связность всего графа — та же роль, что growing-tree
## играло для прямоугольной сетки.
static func _build_mst(nodes: Array[Vector2]) -> Array[Vector2i]:
	var edges: Array[Vector2i] = []
	var n := nodes.size()
	if n < 2:
		return edges

	var in_tree := []
	in_tree.resize(n)
	for i in n:
		in_tree[i] = false
	in_tree[0] = true
	var in_count := 1

	while in_count < n:
		var best_dist := INF
		var best_from := -1
		var best_to := -1
		for i in n:
			if not in_tree[i]:
				continue
			for j in n:
				if in_tree[j]:
					continue
				var d: float = nodes[i].distance_squared_to(nodes[j])
				if d < best_dist:
					best_dist = d
					best_from = i
					best_to = j
		if best_to == -1:
			break
		in_tree[best_to] = true
		in_count += 1
		edges.append(Vector2i(best_from, best_to))

	return edges

## Лишние рёбра сверх дерева — для петель-развилок (аналог EXTRA_LOOPS в
## обычной сетке). Кандидаты — пары узлов не длиннее average MST edge length
## × 1.5, ещё не соединённые напрямую; часть из них добавляется по шансу
## extra_loop_ratio.
static func _extra_loop_edges(nodes: Array[Vector2], mst_edges: Array[Vector2i], extra_loop_ratio: float, rng: RandomNumberGenerator) -> Array[Vector2i]:
	var extra: Array[Vector2i] = []
	var n := nodes.size()
	if n < 3 or extra_loop_ratio <= 0.0:
		return extra

	var existing := {}
	for e in mst_edges:
		existing[_edge_key(e.x, e.y)] = true

	var avg_len := 0.0
	for e in mst_edges:
		avg_len += nodes[e.x].distance_to(nodes[e.y])
	if mst_edges.size() > 0:
		avg_len /= mst_edges.size()
	var max_extra_len: float = avg_len * 1.5

	for i in n:
		for j in range(i + 1, n):
			var key := _edge_key(i, j)
			if existing.has(key):
				continue
			var d := nodes[i].distance_to(nodes[j])
			if d > max_extra_len:
				continue
			if rng.randf() < extra_loop_ratio:
				existing[key] = true
				extra.append(Vector2i(i, j))

	return extra

static func _edge_key(a: int, b: int) -> String:
	return "%d_%d" % [mini(a, b), maxi(a, b)]

## Проверка связности графа (узлы + все рёбра, включая лишние) — BFS от
## узла 0. Используется харнессом; должна всегда возвращать true, т.к. MST
## сам по себе уже связен и лишние рёбра только добавляют пути.
static func graph_is_connected(nodes: Array[Vector2], edges: Array[Vector2i]) -> bool:
	var n := nodes.size()
	if n <= 1:
		return true
	var adj := {}
	for i in n:
		adj[i] = []
	for e in edges:
		adj[e.x].append(e.y)
		adj[e.y].append(e.x)

	var visited := {}
	var queue: Array[int] = [0]
	visited[0] = true
	while not queue.is_empty():
		var cur: int = queue.pop_front()
		for nb in adj[cur]:
			if not visited.has(nb):
				visited[nb] = true
				queue.append(nb)

	return visited.size() == n

## §62 шаг 4 (первая часть — путевые примитивы): взвешенный список смежности
## по РЕАЛЬНОМУ евклидову расстоянию между узлами (вдоль прямой узел-узел;
## длина ломаной чуть больше из-за midpoint displacement, но для
## пути/дистанции важен порядок величины, не точность до пикселя — так же,
## как старый `_compute_optimal_path_len` считал по центрам клеток, не по
## физическому пути игрока). Общий helper для дальнейших функций ниже.
static func _adjacency(nodes: Array[Vector2], edges: Array[Vector2i]) -> Dictionary:
	var adj := {}
	for i in nodes.size():
		adj[i] = []
	for e in edges:
		var d: float = nodes[e.x].distance_to(nodes[e.y])
		adj[e.x].append(Vector2(e.y, d))
		adj[e.y].append(Vector2(e.x, d))
	return adj

## Дейкстра от start — кратчайшие расстояния до всех узлов и дерево
## предков (для восстановления пути). Замена BFS по `_grids[f]` из
## `_compute_optimal_path_len`/`guide_path_to_exit` — та же роль
## (расстояние и путь к цели), но по графу узлов вместо сетки клеток.
## Возвращает {"dist": Array[float], "prev": Array[int]} (prev[i] == -1
## для start и для недостижимых узлов).
static func dijkstra(nodes: Array[Vector2], edges: Array[Vector2i], start: int) -> Dictionary:
	var n := nodes.size()
	var dist: Array[float] = []
	var prev: Array[int] = []
	dist.resize(n)
	prev.resize(n)
	for i in n:
		dist[i] = INF
		prev[i] = -1
	if n == 0:
		return {"dist": dist, "prev": prev}
	dist[start] = 0.0

	var adj := _adjacency(nodes, edges)
	var visited := {}
	while visited.size() < n:
		var u := -1
		var best := INF
		for i in n:
			if not visited.has(i) and dist[i] < best:
				best = dist[i]
				u = i
		if u == -1:
			break  # остаток недостижим (граф не связен — не должно случаться после MST)
		visited[u] = true
		for pair in adj[u]:
			var v := int(pair.x)
			var w: float = pair.y
			if dist[u] + w < dist[v]:
				dist[v] = dist[u] + w
				prev[v] = u

	return {"dist": dist, "prev": prev}

## Путь узел-за-узлом от start до end (включительно), используя "prev" из
## dijkstra(). Пустой массив, если end недостижим.
static func path_from_prev(prev: Array, end: int) -> Array[int]:
	var path: Array[int] = []
	if end < 0 or end >= prev.size():
		return path
	var cur := end
	var guard := prev.size() + 1  # защита от цикла на испорченных данных
	while cur != -1 and guard > 0:
		path.push_front(cur)
		cur = prev[cur]
		guard -= 1
	return path

## Самый удалённый (по кратчайшему пути) узел от start — аналог поиска
## "дальней клетки" для установки входа/выхода на прямоугольной сетке
## (см. CLAUDE.md: farthest-cell BFS исторически строилось от `Vector2i(0,0)`
## / `_entry_cell`). Возвращает -1, если граф пуст.
## §62 шаг 4, часть 4: графовый аналог `_passage_cells(exclude_start)`
## (main.gd) — там это все клетки-проходы кроме входа; здесь каждый узел
## УЖЕ является «комнатой» (нет разделения проход/стена внутри графа), так
## что это просто индексы узлов без exclude_index. Станции/осколки/мимики/
## двери на графовом этаже будут спавниться в узлах из этого списка — сама
## плотность/фильтрация (мимики, тёмные станции, occupied-клетки и т.д.)
## остаётся в main.gd поверх этого списка, как сейчас остаётся поверх
## `_passage_cells` (см. GAMEDESIGN.md §62, шаг 5 — интеграция).
static func spawnable_nodes(nodes: Array[Vector2], exclude_index: int = -1) -> Array[int]:
	var res: Array[int] = []
	for i in nodes.size():
		if i == exclude_index:
			continue
		res.append(i)
	return res

## Графовый аналог `_dead_end_cells` (main.gd) — там тупик это проход с
## РОВНО одной открытой стороной; в графе прямой эквивалент — узел степени 1
## (ровно одно ребро). Используется для порталов/срезок так же, как тупики
## сейчас.
static func dead_end_nodes(nodes: Array[Vector2], edges: Array[Vector2i], exclude_index: int = -1) -> Array[int]:
	var degree := {}
	for i in nodes.size():
		degree[i] = 0
	for e in edges:
		degree[e.x] += 1
		degree[e.y] += 1
	var res: Array[int] = []
	for i in nodes.size():
		if i == exclude_index:
			continue
		if degree[i] == 1:
			res.append(i)
	return res

## §62 шаг 5: выбор входа/выхода для графового этажа — аналог
## `_entry_cell`/фиксированного (0,0) или рандомного входа мега-лабиринта
## (см. CLAUDE.md, «Мега-лабиринт») + `_place_exit`, который на клеточной
## сетке искал самую дальнюю клетку от входа. Здесь: случайный узел —
## вход, `farthest_node` от него — выход (та же гарантия «выход далеко»,
## что раньше давал farthest-cell BFS).
## Возвращает {"entry": int, "exit": int}, оба -1 при пустом графе.
static func pick_entry_exit(nodes: Array[Vector2], edges: Array[Vector2i], rng: RandomNumberGenerator) -> Dictionary:
	if nodes.is_empty():
		return {"entry": -1, "exit": -1}
	var entry := rng.randi_range(0, nodes.size() - 1)
	var exit := farthest_node(nodes, edges, entry)
	if exit == -1:
		exit = entry  # граф из 1 узла — вход и выход совпадают, край. случай
	return {"entry": entry, "exit": exit}

static func farthest_node(nodes: Array[Vector2], edges: Array[Vector2i], start: int) -> int:
	var result := dijkstra(nodes, edges, start)
	var dist: Array = result["dist"]
	var best_idx := -1
	var best_dist := -1.0
	for i in dist.size():
		if i == start:
			continue
		var d: float = dist[i]
		if d < INF and d > best_dist:
			best_dist = d
			best_idx = i
	return best_idx
