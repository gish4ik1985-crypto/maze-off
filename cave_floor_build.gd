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
static func build(parent: Node2D, graph: Dictionary, level_size: Vector2, resolution: float, branch_width: float, tile: float, col: Color, border_margin: float = -1.0) -> Dictionary:
	var wall_polygons := CaveCollision.build_wall_polygons(graph, level_size, resolution, branch_width, 1.5, border_margin)

	var body := StaticBody2D.new()
	parent.add_child(body)
	for poly in wall_polygons:
		if poly.size() < 3:
			continue
		var shape := CollisionPolygon2D.new()
		shape.polygon = poly
		body.add_child(shape)

	# [BUGFIX 01.08.2026, §62] Растровые полигоны стен обрываются РОВНО на
	# границе level_size — с внешней стороны нет ни клочка коллизии вообще.
	# Депенетрация физики у самого края выталкивала игрока НАРУЖУ, а не
	# обратно внутрь: путь "наружу, за пределы полигона" короче, чем "внутрь,
	# через всю толщину стены" (воспроизведено живым скриншотом — игрок
	# оказался в пустоте за пределами уровня). border_margin в
	# CaveCollision уменьшает шанс, что комната у самого края останется
	# незамкнутой, но НЕ решает саму геометрию — нужен отдельный жёсткий
	# ограничитель. Толстая рамка СНАРУЖИ level_size, гарантированно
	# сплошная независимо от формы кавовых стен.
	_add_boundary_frame(body, level_size)

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

# Рамка из 4 прямоугольников СНАРУЖИ [0,level_size] толщиной THICKNESS —
# внутренний край строго совпадает с границей уровня, так что любая попытка
# продавиться сквозь дырявый растровый полигон у края упирается в это
# перекрытие раньше, чем окажется в пустоте без коллизии вообще.
const BOUNDARY_FRAME_THICKNESS := 300.0

static func _add_boundary_frame(body: StaticBody2D, level_size: Vector2) -> void:
	var t := BOUNDARY_FRAME_THICKNESS
	var rects := [
		Rect2(Vector2(-t, -t), Vector2(level_size.x + 2.0 * t, t)),               # верх
		Rect2(Vector2(-t, level_size.y), Vector2(level_size.x + 2.0 * t, t)),      # низ
		Rect2(Vector2(-t, 0.0), Vector2(t, level_size.y)),                        # лево
		Rect2(Vector2(level_size.x, 0.0), Vector2(t, level_size.y)),              # право
	]
	for r in rects:
		var shape := CollisionPolygon2D.new()
		shape.polygon = PackedVector2Array([
			r.position,
			Vector2(r.position.x + r.size.x, r.position.y),
			r.position + r.size,
			Vector2(r.position.x, r.position.y + r.size.y),
		])
		body.add_child(shape)
