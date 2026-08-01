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
static func build_wall_bitmap(graph: Dictionary, level_size: Vector2, resolution: float, branch_width: float = -1.0) -> BitMap:
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

	var bitmap := BitMap.new()
	bitmap.create(Vector2i(mask_w, mask_h))
	for y in mask_h:
		for x in mask_w:
			bitmap.set_bit(x, y, not passable[y][x])

	return bitmap

## Полигоны стен (world-координаты) — контуры из BitMap.opaque_to_polygons(),
## масштабированные обратно на resolution. epsilon — упрощение контура
## (в пикселях маски); 0 = без упрощения.
static func build_wall_polygons(graph: Dictionary, level_size: Vector2, resolution: float, branch_width: float = -1.0, epsilon: float = 1.5) -> Array[PackedVector2Array]:
	var bitmap := build_wall_bitmap(graph, level_size, resolution, branch_width)
	var mask_w := bitmap.get_size().x
	var mask_h := bitmap.get_size().y
	var raw := bitmap.opaque_to_polygons(Rect2(0, 0, mask_w, mask_h), epsilon)

	var scaled: Array[PackedVector2Array] = []
	for poly in raw:
		var out := PackedVector2Array()
		for p in poly:
			out.append(p * resolution)
		scaled.append(out)
	return scaled

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
