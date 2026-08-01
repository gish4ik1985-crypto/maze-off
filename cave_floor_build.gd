class_name CaveFloorBuild
extends RefCounted

## §62 шаг 5 (GAMEDESIGN.md): сборка ОДНОГО графового этажа Пещер —
## коллизия (CaveCollision) + occlusion + рендер (organic_floor.gd) как
## единый атомарный пакет. Собирать их по отдельности бессмысленно и
## опасно: рисунок и хитбокс должны появляться из ОДНОГО и того же графа
## одновременно, иначе на экране будет одно, а физика — другое (ровно риск,
## отмеченный в шаге 3).
##
## ВАЖНО: этот файл НЕ подключён к `main.gd`/режиму «Пещеры» — вызывающий
## код (`main.gd`) на шаге 5 будет решать, когда вызвать `build()` вместо
## текущего `_make_grid()`+сеточного `organic_floor.gd`. До этого решения
## живой режим «Пещеры» работает как раньше (сетка).

## Строит этаж внутри parent (Node2D, уже добавленный в дерево сцены —
## StaticBody2D физике нужен активный World2D). Возвращает узлы для
## тестирования/дальнейшей настройки (occluder-слой, свет и т.д. вызывающий
## код добавляет отдельно, как и для существующих этажей).
static func build(parent: Node2D, graph: Dictionary, level_size: Vector2, resolution: float, branch_width: float, tile: float, col: Color) -> Dictionary:
	var wall_polygons := CaveCollision.build_wall_polygons(graph, level_size, resolution, branch_width)

	var body := StaticBody2D.new()
	parent.add_child(body)
	for poly in wall_polygons:
		if poly.size() < 3:
			continue
		var shape := CollisionPolygon2D.new()
		shape.polygon = poly
		body.add_child(shape)

	var occluder_root := Node2D.new()
	parent.add_child(occluder_root)
	for poly in wall_polygons:
		if poly.size() < 3:
			continue
		var occ := LightOccluder2D.new()
		var occ_poly := OccluderPolygon2D.new()
		occ_poly.polygon = poly
		occ_poly.closed = true
		occ.occluder = occ_poly
		occluder_root.add_child(occ)

	var floor_node := Node2D.new()
	floor_node.set_script(load("res://organic_floor.gd"))
	floor_node.tile = tile
	floor_node.col = col
	floor_node.graph_nodes = graph.get("nodes", [])
	floor_node.graph_radii = graph.get("radii", [])
	floor_node.graph_polylines = graph.get("polylines", [])
	parent.add_child(floor_node)

	return {
		"body": body,
		"occluder_root": occluder_root,
		"floor_node": floor_node,
		"wall_polygons": wall_polygons,
	}
