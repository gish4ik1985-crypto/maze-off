extends RefCounted

# Вынесено из main.gd механически (tools/extract_fn.py, v6.8): код функций
# тот же, что был в main.gd; `g` — главный узел, все его члены с префиксом `g.`.
# Состояние остаётся в main.gd (переменные `_hud_layer`, `_vitals`, …).

static func _make_oval_grid(g, cols: int, rows: int) -> Dictionary:
	var gw = cols * 2 + 1
	var gh = rows * 2 + 1
	var grid: Array = []
	grid.resize(gh)
	for y in gh:
		var row = []
		row.resize(gw)
		for x in gw:
			row[x] = true
		grid[y] = row

	var cx0: float = (cols - 1) * 0.5
	var cy0: float = (rows - 1) * 0.5
	var rx_outer: float = maxf(2.0, cx0 * 0.92)
	var ry_outer: float = maxf(2.0, cy0 * 0.92)
	var rx_inner: float = rx_outer * 0.55
	var ry_inner: float = ry_outer * 0.55

	var ring_cells: Array[Vector2i] = []
	var ring_set: Dictionary = {}
	for cy in rows:
		for cx in cols:
			var dxo: float = (float(cx) - cx0) / rx_outer
			var dyo: float = (float(cy) - cy0) / ry_outer
			if dxo * dxo + dyo * dyo > 1.0:
				continue
			var dxi: float = (float(cx) - cx0) / maxf(0.01, rx_inner)
			var dyi: float = (float(cy) - cy0) / maxf(0.01, ry_inner)
			if dxi * dxi + dyi * dyi < 1.0:
				continue
			var c = Vector2i(cx, cy)
			ring_cells.append(c)
			ring_set[c] = true

	if ring_cells.is_empty():
		# Слишком маленькая сетка для кольца — откатываемся на обычное дерево.
		return {"grid": g._make_grid(), "entry": Vector2i(0, 0), "exit": Vector2i(cols - 1, rows - 1)}

	# Случайная точка кольца — иначе вход/выход всегда оказывались бы в одном
	# и том же месте (ring_cells[0] всегда первая клетка в порядке сканирования
	# сетки, а не что-то зависящее от randi/randf).
	var start: Vector2i = ring_cells[randi() % ring_cells.size()]
	var visited: Dictionary = {start: true}
	var active: Array[Vector2i] = [start]
	grid[start.y * 2 + 1][start.x * 2 + 1] = false

	while not active.is_empty():
		var idx: int = active.size() - 1
		var c: Vector2i = active[idx]
		var neighbors: Array[Vector2i] = []
		for d in [Vector2i(1, 0), Vector2i(-1, 0), Vector2i(0, 1), Vector2i(0, -1)]:
			var n: Vector2i = c + d
			if ring_set.has(n) and not visited.has(n):
				neighbors.append(n)
		if neighbors.is_empty():
			active.remove_at(idx)
		else:
			var n: Vector2i = neighbors[randi() % neighbors.size()]
			visited[n] = true
			grid[n.y * 2 + 1][n.x * 2 + 1] = false
			grid[c.y + n.y + 1][c.x + n.x + 1] = false
			active.append(n)

	# Выход — самая дальняя (по числу шагов от входа) достигнутая клетка
	# кольца: почти всегда «на другой стороне круга».
	var best: Vector2i = start
	var best_d = -1
	for c in ring_cells:
		if not visited.has(c):
			continue
		var d: int = absi(c.x - start.x) + absi(c.y - start.y)
		if d > best_d:
			best_d = d
			best = c
	return {"grid": grid, "entry": start, "exit": best}

static func _make_superboss_arena_grid(_g, cols: int, rows: int) -> Array:
	var gw = cols * 2 + 1
	var gh = rows * 2 + 1
	var grid: Array = []
	grid.resize(gh)
	for gy in gh:
		var row = []
		row.resize(gw)
		for gx in gw:
			row[gx] = (gx == 0 or gx == gw - 1 or gy == 0 or gy == gh - 1)
		grid[gy] = row
	# Пилоны-укрытия регулярной сеткой; каждый второй — «крепкий» (см.
	# STRONG_WALL_COLOR), остальные обычные (разрушаемые). Чередование, а не
	# случайность — расстановка должна быть предсказуемой и читаемой игроком
	# ДО столкновения с разницей (урок §22 «непонятные объекты»).
	var strong: Dictionary = {}
	var idx = 0
	var cy = 3
	while cy < rows - 3:
		var cx = 3
		while cx < cols - 3:
			var gx = cx * 2 + 1
			var gy = cy * 2 + 1
			grid[gy][gx] = true
			if idx % 2 == 0:
				strong[Vector2i(gx, gy)] = true
			idx += 1
			cx += 4
		cy += 4
	return [grid, strong]
