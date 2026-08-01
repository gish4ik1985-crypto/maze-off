extends Node2D

# Органический пол для уровней-«корней»: рисует лабиринт как сеть плавных
# скруглённых тоннелей (узел в каждой клетке-проходе + ветвь к открытым
# соседям). Освещается светом игрока (как обычный пол), поэтому виден только
# вблизи. Перерисовывается при изменении лабиринта (queue_redraw).
#
# [BUGFIX v4.1, §61] Раньше тоннель заливался ОДНИМ сплошным ярким цветом на
# всю ширину — в отличие от обычных стен, у которых тёмная середина и светится
# только фаска по краю. Итог на живой игре (жалоба со скриншотом): осколки
# (мелкие голубые иконки) тонут в сплошной жёлтой заливке, а луч фонаря/
# световой конус, упав на уже яркий тоннель, выжигается в чистый белый —
# не отдельный баг, а следствие нулевого запаса яркости. Теперь то же самое
# рисуется в два прохода: широкий светящийся «ободок» (rim) тем же приёмом,
# что фаска стены, и заметно более тёмная заливка (fill) поверх него того же
# тона — тоннель читается как тёмный проход со светящимся краем, а не как
# сплошное пятно.

var tile: float = 48.0
var cols: int = 0
var rows: int = 0
var gw: int = 0
var gh: int = 0
var col: Color = Color(0.4, 0.3, 0.2)
var grid: Array = []

func _ready() -> void:
	queue_redraw()

func _draw() -> void:
	if grid.is_empty():
		return
	var node_r := tile * 0.46    # радиус узла тоннеля (ободок)
	var branch_w := tile * 0.78  # ширина ветви между узлами (ободок)
	var rim_col := col
	# Заливка темнее и чуть менее насыщена — тот же тон, но не спорит с
	# предметами/светом. 0.30 подобрано по контрасту на превью-рендере: 0.5
	# всё ещё читалось почти таким же ярким, 0.2 съедало сам ободок.
	var fill_col := Color(col.r * 0.30, col.g * 0.30, col.b * 0.30, col.a)
	var fill_r := node_r * 0.68
	var fill_w := branch_w * 0.56

	for cy in rows:
		for cx in cols:
			var gx := cx * 2 + 1
			var gy := cy * 2 + 1
			if grid[gy][gx]:
				continue  # не проход
			var center := Vector2(gx * tile + tile * 0.5, gy * tile + tile * 0.5)
			var has_e: bool = cx + 1 < cols and not grid[gy][gx + 1]
			var has_s: bool = cy + 1 < rows and not grid[gy + 1][gx]
			var e := center + Vector2(2.0 * tile, 0.0)
			var s := center + Vector2(0.0, 2.0 * tile)
			# Проход №1 — светящийся ободок (широкий, тон биома/темы).
			if has_e:
				draw_line(center, e, rim_col, branch_w)
			if has_s:
				draw_line(center, s, rim_col, branch_w)
			draw_circle(center, node_r, rim_col)
			# Проход №2 — тёмная заливка поверх, тоньше ободка с обеих сторон.
			if has_e:
				draw_line(center, e, fill_col, fill_w)
			if has_s:
				draw_line(center, s, fill_col, fill_w)
			draw_circle(center, fill_r, fill_col)
