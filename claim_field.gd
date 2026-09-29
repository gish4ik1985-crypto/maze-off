extends Node2D

# [GAMEDESIGN §41] Поле захваченной земли: клетки, по которым ты прошёл,
# остаются тлеть — это твоя территория. Тьма отвоёвывает их обратно, и
# свечение гаснет тем быстрее, чем ярче и заметнее игрок.
#
# ОДИН узел с собственным _draw() на этаж, а не спрайт на клетку. Причина в
# ARCHITECTURE §3 и в CLAUDE.md прямым текстом: ~8k даже невидимых CanvasItem
# стоили ~35 FPS на GL Compatibility. Здесь весь след — один CanvasItem с
# пачкой прямоугольников, и рисуются только клетки рядом с игроком.

var game: Node = null
var floor_index: int = 0
# Размер клетки передаётся при создании, а НЕ читается через game.get("TILE"):
# Object.get() возвращает свойства, а TILE — константа, то есть получали null,
# половина клетки считалась нулём и след не рисовался вовсе. Поймано скриншот-
# харнессом: данные говорили «14 клеток следа», а на экране не было ничего.
var tile: float = 48.0

const REDRAW_HZ := 8.0            # перерисовка следа — 8 раз в секунду, не в кадр
const DRAW_RADIUS_CELLS := 14     # рисуем только окрестность игрока (экран + запас)

var _t: float = 0.0
var _glow_tex: Texture2D

func _ready() -> void:
	z_index = -5   # под игроком, стенами и объектами: это подсветка ПОЛА
	_glow_tex = MazeTextures.make_light(128)
	var mat := CanvasItemMaterial.new()
	mat.blend_mode = CanvasItemMaterial.BLEND_MODE_ADD
	material = mat
	set_process(true)

func _process(delta: float) -> void:
	_t += delta
	if _t < 1.0 / REDRAW_HZ:
		return
	_t = 0.0
	queue_redraw()

func _draw() -> void:
	if game == null or not is_instance_valid(game):
		return
	if not game.has_method("claim_cells_near"):
		return
	var cells: Array = game.call("claim_cells_near", floor_index, DRAW_RADIUS_CELLS)
	# Клетку под самим игроком не рисуем: слой лежит над миром, и плитка
	# заслоняла бы его собственный свет.
	var pp := Vector2(-1e9, -1e9)
	if game.get("_player") != null and is_instance_valid(game.get("_player")):
		pp = game.get("_player").global_position
	for entry in cells:
		# entry: [Vector2i клетка, float сила 0..1]
		var cell: Vector2i = entry[0]
		var s: float = float(entry[1])
		if s <= 0.0:
			continue
		var p: Vector2 = game.call("_cell_to_world", cell)
		if p.distance_to(pp) < tile * 0.9:
			continue
		var col: Color = game.call("claim_color", s)
		# [v5.7] Было: плитки-«шашки» с контуром (жалоба: «выглядит убого»). Стало:
		# мягкое тёплое свечение угольков. Круги соседних клеток перекрываются и
		# сливаются в непрерывную ленту твоего пути; аддитивное смешивание не
		# заслоняет ни стены, ни объекты, а угасание видно как остывание цвета —
		# от янтарного к холодному синему — и как потухание самого пятна.
		var r: float = tile * 1.45
		var glow := Color(col.r, col.g, col.b, 0.14 + 0.36 * s)
		draw_texture_rect(_glow_tex, Rect2(p - Vector2(r, r), Vector2(r * 2.0, r * 2.0)), false, glow)
		if s > 0.35:
			draw_circle(p, tile * 0.09, Color(1.0, 0.85, 0.55, 0.20 + 0.45 * s))
