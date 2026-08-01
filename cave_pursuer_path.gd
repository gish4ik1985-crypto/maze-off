class_name CavePursuerPath
extends RefCounted

## §62 шаг 4, часть 2 (GAMEDESIGN.md): движение преследователя по графу
## кротовых нор — замена клеточного BFS-преследования из `pursuer.gd` для
## случая, когда этаж описан графом (CaveGraph), а не сеткой `_grids[f]`.
##
## ВАЖНО: этот файл НЕ подключён к `pursuer.gd` и не меняет поведение
## врагов ни в одном существующем режиме (Уровни/Накал/Спуск дня/обычные
## Пещеры на сетке) — `pursuer.gd` общий на все режимы, трогать его нельзя,
## пока графовая модель не станет реальным источником данных этажа (это
## случится только на шаге 5). Здесь только чистые функции, проверяемые
## отдельным харнессом, ровно тот же подход, что у шагов 1-3.
##
## Модель движения: враг стоит не в "клетке", а в позиции
## (текущий узел ИЛИ ребро с параметром t вдоль его ломаной, 0..1 от
## from-узла к to-узлу). Раз в решение (аналог "враг долетел до центра
## клетки" в старой модели) он выбирает следующий узел на кратчайшем пути
## к цели через CaveGraph.dijkstra/path_from_prev.

## Следующий узел на кратчайшем пути от current к target (не сам target,
## а следующий шаг). current, если current == target или путь не найден.
static func next_node_toward(nodes: Array[Vector2], edges: Array[Vector2i], current: int, target: int) -> int:
	if current == target:
		return current
	var result := CaveGraph.dijkstra(nodes, edges, current)
	var prev: Array = result["prev"]
	var dist: Array = result["dist"]
	if target < 0 or target >= dist.size() or dist[target] == INF:
		return current
	var path := CaveGraph.path_from_prev(prev, target)
	if path.size() < 2:
		return current
	return path[1]

## Мировая позиция на ребре with полилинией poly (poly[0]==позиция from-узла,
## poly[last]==позиция to-узла), параметр t — доля ДЛИНЫ ломаной (0..1),
## не доля числа точек — иначе сегменты разной длины двигали бы врага
## рывками. Возвращает {"pos": Vector2, "reached_end": bool}.
static func position_on_polyline(poly: PackedVector2Array, t: float) -> Vector2:
	if poly.size() < 2:
		return poly[0] if poly.size() == 1 else Vector2.ZERO
	t = clampf(t, 0.0, 1.0)
	var seg_lengths: Array[float] = []
	var total := 0.0
	for i in poly.size() - 1:
		var l := poly[i].distance_to(poly[i + 1])
		seg_lengths.append(l)
		total += l
	if total <= 0.0001:
		return poly[0]
	var target_dist := t * total
	var acc := 0.0
	for i in seg_lengths.size():
		var l: float = seg_lengths[i]
		if acc + l >= target_dist or i == seg_lengths.size() - 1:
			var local_t: float = 0.0 if l <= 0.0001 else clampf((target_dist - acc) / l, 0.0, 1.0)
			return poly[i].lerp(poly[i + 1], local_t)
		acc += l
	return poly[poly.size() - 1]

## Продвигает параметр t вдоль полилинии на distance мировых единиц (учитывая
## реальную длину ломаной, не число сегментов) — арк-лэнгз-корректное
## движение с постоянной скоростью, аналог "враг сдвинулся на speed*delta"
## в клеточной модели. Возвращает новый t (может стать 1.0, если distance
## больше оставшейся длины — вызывающий код решает, что делать по приходу).
static func advance_t(poly: PackedVector2Array, t: float, distance: float) -> float:
	var total := _polyline_length(poly)
	if total <= 0.0001:
		return 1.0
	return clampf(t + distance / total, 0.0, 1.0)

static func _polyline_length(poly: PackedVector2Array) -> float:
	var total := 0.0
	for i in poly.size() - 1:
		total += poly[i].distance_to(poly[i + 1])
	return total
