extends Node2D

# Органический пол для уровней-«корней»: рисует лабиринт как сеть плавных
# скруглённых тоннелей (узел в каждой клетке-проходе + ветвь к открытым
# соседям). Освещается светом игрока (как обычный пол), поэтому виден только
# вблизи. Перерисовывается при изменении лабиринта (queue_redraw).

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
	var node_r := tile * 0.46    # радиус узла тоннеля
	var branch_w := tile * 0.78  # ширина ветви между узлами

	for cy in rows:
		for cx in cols:
			var gx := cx * 2 + 1
			var gy := cy * 2 + 1
			if grid[gy][gx]:
				continue  # не проход
			var center := Vector2(gx * tile + tile * 0.5, gy * tile + tile * 0.5)
			# Ветви к восточному и южному соседям (чтобы не дублировать)
			if cx + 1 < cols and not grid[gy][gx + 1]:
				var e := center + Vector2(2.0 * tile, 0.0)
				draw_line(center, e, col, branch_w)
			if cy + 1 < rows and not grid[gy + 1][gx]:
				var s := center + Vector2(0.0, 2.0 * tile)
				draw_line(center, s, col, branch_w)
			draw_circle(center, node_r, col)
