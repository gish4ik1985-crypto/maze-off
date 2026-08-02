class_name CaveCollision
extends RefCounted

## §62 шаг 3 (GAMEDESIGN.md): стены Пещер как полигоны, построенные по
## РЕАЛЬНОЙ форме тоннеля (не по прямоугольной тайловой физике, которая не
## годится для произвольных углов графа-норы). Чистые функции, не трогают
## сцену/сцену-дерево напрямую — только строят данные, которые потом вешают
## на StaticBody2D/LightOccluder2D при интеграции (шаг 5).
##
## Идея: растровая маска уровня в пониженном разрешении ("физическое
## разрешение", НЕ мировые пиксели) — 1 = проходимо (внутри капсулы вдоль
## ребра-ломаной или круга-узла), 0 = стена. BitMap.opaque_to_polygons()
## по ИНВЕРСИИ этой маски (opaque = стена) даёт контуры стен готовыми
## Vector2[]-полигонами.

## Строит BitMap стен (true = стена, false = проход) в пиксельных
## координатах маски (world = pixel * resolution).
##
## [BUGFIX 01.08.2026, §62] Маска покрывает ТОЛЬКО прямоугольник
## `level_size` — за его пределами нет ни стен, ни какой-либо коллизии
## вообще (там просто ничего не сгенерировано). Если капсула/круг узла у
## самого края уровня рисует проход вплотную к границе маски,
## `BitMap.opaque_to_polygons()` замыкает контур ПО КРАЮ прямоугольника —
## получившийся полигон может не до конца перекрывать этот край, и игрок
## физически проходит наружу, в пустоту без коллизии (репродуцировано
## живым скриншотом: игрок оказался за пределами всей отрисованной
## области). Фикс: гарантированная рамка толщиной `border_margin` по
## периметру ВСЕГДА стена, независимо от того, что говорят капсулы/круги —
## тогда открытый пиксель никогда не касается края маски, и контур полигона
## всегда замкнут изнутри прямоугольника.
static func build_wall_bitmap(graph: Dictionary, level_size: Vector2, resolution: float, branch_width: float = -1.0, border_margin: float = -1.0) -> BitMap:
	var mask_w := maxi(1, ceili(level_size.x / resolution))
	var mask_h := maxi(1, ceili(level_size.y / resolution))

	var nodes: Array = graph.get("nodes", [])
	var radii: Array = graph.get("radii", [])
	var polylines: Array = graph.get("polylines", [])
	var branch_w: float = branch_width if branch_width > 0.0 else resolution * 3.0

	# passable[y][x] — считаем один раз плотным массивом bool, чтобы не звать
	# is_bit_set по нескольку раз на пиксель.
	var passable := []
	passable.resize(mask_h)
	for y in mask_h:
		var row := []
		row.resize(mask_w)
		for x in mask_w:
			row[x] = false
		passable[y] = row

	for i in nodes.size():
		var center: Vector2 = nodes[i]
		var r: float = (radii[i] if i < radii.size() else resolution * 2.0)
		_stamp_circle(passable, mask_w, mask_h, center, r, resolution)

	for poly in polylines:
		var pts: PackedVector2Array = poly
		for i in pts.size() - 1:
			_stamp_capsule(passable, mask_w, mask_h, pts[i], pts[i + 1], branch_w * 0.5, resolution)

	var margin_px: int = maxi(1, ceili((border_margin if border_margin > 0.0 else resolution * 3.0) / resolution))
	for y in mask_h:
		for x in mask_w:
			if x < margin_px or x >= mask_w - margin_px or y < margin_px or y >= mask_h - margin_px:
				passable[y][x] = false

	var bitmap := BitMap.new()
	bitmap.create(Vector2i(mask_w, mask_h))
	for y in mask_h:
		for x in mask_w:
			bitmap.set_bit(x, y, not passable[y][x])

	return bitmap

## Полигоны стен (world-координаты), готовые для CollisionPolygon2D.
##
## [BUGFIX 01.08.2026, §62, ВТОРАЯ ПОПЫТКА] Первая версия использовала
## `BitMap.opaque_to_polygons()` (внешний контур сплошной породы + контуры
## комнат-«дырок» внутри неё) и вычитала дырки через `Geometry2D.
## clip_polygons()`. На бумаге корректно (см. предыдущий BUGFIX-комментарий
## в истории), но живой харнесс с РЕАЛЬНЫМ движением (толкать игрока в 8
## направлений по 4 секунды, не просто проверять статичные точки) поймал
## тяжёлый пробой: игрок проваливался на 100-450 мировых юниц ВНУТРЬ стены
## по маске в 6-7 направлениях из 8. Гипотеза: `clip_polygons`,
## последовательно вычитая ДЕСЯТКИ дырок (по числу узлов графа, до 150) из
## одного огромного внешнего контура, на некоторых сочетаниях/масштабах
## выдаёт вырожденный или самопересекающийся результирующий полигон —
## Godot либо не может его корректно триангулировать под физику, либо
## триангулирует иначе, чем рисует, и коллизия перестаёт совпадать с
## визуальной/растровой формой именно там.
##
## Фикс: убрана булева геометрия целиком. Вместо «внешний контур минус
## дырки» — прямое построение осевыровненных прямоугольников из растровой
## маски (grid-meshing/greedy rectangle merge, тот же принцип, которым
## TileMap-физика уже надёжно работала в этой игре до §60 — см. CLAUDE.md).
## Каждый прямоугольник тривиально прост (4 угла, оси совпадают с X/Y) —
## самопересечения физически невозможны, вопрос триангуляции не встаёт
## вообще. Проверено тем же живым харнессом (движение в 8 направлений) —
## 0 пробоев вместо 6-7 из 8.
static func build_wall_polygons(graph: Dictionary, level_size: Vector2, resolution: float, branch_width: float = -1.0, epsilon: float = 1.5, border_margin: float = -1.0) -> Array[PackedVector2Array]:
	var bitmap := build_wall_bitmap(graph, level_size, resolution, branch_width, border_margin)
	var mask_w := bitmap.get_size().x
	var mask_h := bitmap.get_size().y

	var visited := []
	visited.resize(mask_h)
	for y in mask_h:
		var row := []
		row.resize(mask_w)
		for x in mask_w:
			row[x] = false
		visited[y] = row

	var rects: Array[PackedVector2Array] = []
	for y in mask_h:
		for x in mask_w:
			if visited[y][x] or not bitmap.get_bit(x, y):
				continue
			# Расширяем вправо, пока пиксели — стена и ещё не посещены.
			var w := 1
			while x + w < mask_w and not visited[y][x + w] and bitmap.get_bit(x + w, y):
				w += 1
			# Расширяем вниз, пока ВЕСЬ ряд [x, x+w) — тоже стена и не посещён.
			var h := 1
			while y + h < mask_h:
				var row_ok := true
				for xx in range(x, x + w):
					if visited[y + h][xx] or not bitmap.get_bit(xx, y + h):
						row_ok = false
						break
				if not row_ok:
					break
				h += 1
			for yy in range(y, y + h):
				for xx in range(x, x + w):
					visited[yy][xx] = true
			var wx0 := float(x) * resolution
			var wy0 := float(y) * resolution
			var wx1 := float(x + w) * resolution
			var wy1 := float(y + h) * resolution
			rects.append(PackedVector2Array([
				Vector2(wx0, wy0), Vector2(wx1, wy0), Vector2(wx1, wy1), Vector2(wx0, wy1)
			]))

	return rects

static func _stamp_circle(passable: Array, mask_w: int, mask_h: int, center: Vector2, radius: float, resolution: float) -> void:
	var cx := center.x / resolution
	var cy := center.y / resolution
	var r := radius / resolution
	var x0 := maxi(0, floori(cx - r))
	var x1 := mini(mask_w - 1, ceili(cx + r))
	var y0 := maxi(0, floori(cy - r))
	var y1 := mini(mask_h - 1, ceili(cy + r))
	var r2 := r * r
	for y in range(y0, y1 + 1):
		for x in range(x0, x1 + 1):
			var dx := float(x) + 0.5 - cx
			var dy := float(y) + 0.5 - cy
			if dx * dx + dy * dy <= r2:
				passable[y][x] = true

## Капсула = объединение кругов радиуса half_w вдоль отрезка a-b, с шагом
## в полрадиуса — простое и надёжное решение для низкого разрешения маски.
static func _stamp_capsule(passable: Array, mask_w: int, mask_h: int, a: Vector2, b: Vector2, half_w: float, resolution: float) -> void:
	var length := a.distance_to(b)
	var step: float = maxf(resolution * 0.5, half_w * 0.5)
	var steps := maxi(1, ceili(length / step))
	for i in steps + 1:
		var t := float(i) / float(steps)
		var p := a.lerp(b, t)
		_stamp_circle(passable, mask_w, mask_h, p, half_w, resolution)

## [BUGFIX 01.08.2026, §62] Даже с запасом между радиусами узлов (см.
## CaveGraph.generate) извилистые рёбра (midpoint displacement) иногда
## проходят достаточно близко к ЧУЖОМУ несвязанному узлу/ребру, чтобы их
## капсулы/круги физически соприкоснулись в растровой маске — тогда между
## двумя формально несвязанными частями графа физически нет стены (баг
## «игрок проходит сквозь стены», репродуцирован живой игрой). Полностью
## гарантировать отсутствие такого пересечения на этапе генерации сложно
## (это была бы задача геометрической маршрутизации с учётом препятствий);
## вместо этого — проверка ПОСТ-ФАКТУМ: флуд-заливка по проходимым пикселям
## маски от каждого узла находит, какие ДРУГИЕ узлы физически достижимы
## НАПРЯМУЮ (не через 1-2 хопа по графу, для которых это ожидаемо — длинный
## путь по тоннелям всё равно "физически достижим" рано или поздно) —
## если среди них есть узел на явно короткой (не многохоповой) дистанции,
## это утечка. Вызывающий код (main.gd) должен перегенерировать граф с
## другим сидом, если это вернуло true.
static func has_leak(graph: Dictionary, level_size: Vector2, resolution: float, branch_width: float, border_margin: float = -1.0) -> bool:
	var nodes: Array = graph.get("nodes", [])
	var edges: Array = graph.get("edges", [])
	if nodes.size() < 3:
		return false

	var adj := {}
	for i in nodes.size():
		adj[i] = {}
	for e in edges:
		adj[e.x][e.y] = true
		adj[e.y][e.x] = true

	var bitmap := build_wall_bitmap(graph, level_size, resolution, branch_width, border_margin)
	var mask_w := bitmap.get_size().x
	var mask_h := bitmap.get_size().y

	var node_px: Array = []
	for n in nodes:
		node_px.append(Vector2i(int((n as Vector2).x / resolution), int((n as Vector2).y / resolution)))

	# Порог "подозрительно близко напрямую" — в пикселях маски. Многохоповый
	# путь по реальным тоннелям почти всегда длиннее нескольких радиусов
	# комнаты; короткая прямая физическая связь между формально далёкими по
	# графу узлами — верный признак утечки, а не длинного коридора.
	var leak_threshold_px: float = 15.0

	for i in nodes.size():
		var start: Vector2i = node_px[i]
		if start.x < 0 or start.x >= mask_w or start.y < 0 or start.y >= mask_h:
			continue
		if bitmap.get_bit(start.x, start.y):
			continue
		var visited := {start: true}
		var queue: Array = [start]
		var steps := 0
		while not queue.is_empty() and steps < 200000:
			steps += 1
			var c: Vector2i = queue.pop_front()
			for d in [Vector2i(1, 0), Vector2i(-1, 0), Vector2i(0, 1), Vector2i(0, -1)]:
				var nb: Vector2i = c + d
				if nb.x < 0 or nb.x >= mask_w or nb.y < 0 or nb.y >= mask_h:
					continue
				if visited.has(nb):
					continue
				if bitmap.get_bit(nb.x, nb.y):
					continue
				visited[nb] = true
				queue.append(nb)

		for j in nodes.size():
			if j == i or not visited.has(node_px[j]):
				continue
			if adj[i].has(j):
				continue
			var two_hop := false
			for k in adj[i].keys():
				if adj[k].has(j):
					two_hop = true
					break
			if two_hop:
				continue
			if Vector2(node_px[i]).distance_to(Vector2(node_px[j])) < leak_threshold_px:
				return true

	return false
