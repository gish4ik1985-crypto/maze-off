extends Node2D

# [GAMEDESIGN §41] Поле захваченной земли: клетки, по которым ты прошёл,
# остаются тлеть — это твоя территория. Тьма отвоёвывает их обратно, и
# свечение гаснет тем быстрее, чем ярче и заметнее игрок.
#
# ОДИН узел с собственным _draw() на этаж, а не спрайт на клетку. Причина в
# ARCHITECTURE §3 и в CLAUDE.md прямым текстом: ~8k даже невидимых CanvasItem
# стоили ~35 FPS на GL Compatibility. Здесь весь след — один CanvasItem с
# пачкой квадов одной и той же текстуры, и рисуются только клетки рядом с игроком.
#
# [v6.0] Визуал третий раз: плитки-«шашки» (v4) → крупные янтарные пятна с
# точкой в центре каждой клетки (v5.7; жалоба «тление выглядит плохо, огоньки
# слишком заметные, лучше крошки энергии») → россыпь КРОШЕК ЭНЕРГИИ. В клетке
# лежат две-три крошечные искры; пока земля твоя — они тёплые и мерцают, по
# мере остывания гаснут по одной и синеют, в конце не остаётся ничего.

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
var _clock: float = 0.0
var _glow_tex: Texture2D
var _dot_tex: Texture2D

func _ready() -> void:
	z_index = -5   # под игроком, стенами и объектами: это подсветка ПОЛА
	_glow_tex = MazeTextures.make_light(128)
	_dot_tex = MazeTextures.make_light(32)
	var mat := CanvasItemMaterial.new()
	mat.blend_mode = CanvasItemMaterial.BLEND_MODE_ADD
	material = mat
	set_process(true)

func _process(delta: float) -> void:
	_clock += delta
	_t += delta
	if _t < 1.0 / REDRAW_HZ:
		return
	_t = 0.0
	queue_redraw()

# Целочисленный хэш: положение и «характер» крошек зависят только от клетки,
# поэтому след не дрожит и не перетасовывается при каждой перерисовке.
static func _hash(v: int) -> int:
	v = ((v ^ 61) ^ (v >> 16)) & 0xffffffff
	v = (v * 9) & 0xffffffff
	v = (v ^ (v >> 4)) & 0xffffffff
	v = (v * 0x27d4eb2d) & 0xffffffff
	v = (v ^ (v >> 15)) & 0xffffffff
	return v

func _draw() -> void:
	if game == null or not is_instance_valid(game):
		return
	if not game.has_method("claim_cells_near"):
		return
	var cells: Array = game.call("claim_cells_near", floor_index, DRAW_RADIUS_CELLS)
	# Клетку под самим игроком не рисуем: слой лежит над миром, и россыпь
	# заслоняла бы его собственный свет.
	var pp := Vector2(-1e9, -1e9)
	if game.get("_player") != null and is_instance_valid(game.get("_player")):
		pp = game.get("_player").global_position
	var q: int = GameConfig.quality
	var crumbs: int = 4 if q >= 2 else (3 if q == 1 else 2)
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
		# Едва заметная общая подсветка пола — только чтобы россыпь читалась как
		# один путь, а не как случайные искры. На «низком» качестве её нет.
		if q >= 1:
			var r: float = tile * 1.25
			draw_texture_rect(_glow_tex, Rect2(p - Vector2(r, r), Vector2(r * 2.0, r * 2.0)), false,
				Color(col.r, col.g, col.b, 0.02 + 0.05 * s))
		var seed_i: int = cell.x * 73856093 + cell.y * 19349663
		for k in crumbs:
			# Крошка k живёт, пока сила клетки выше своего порога: остывая, земля
			# теряет искры по одной, а не гаснет вся разом.
			var thr: float = float(k) * 0.2
			if s <= thr:
				continue
			var life: float = clampf((s - thr) / 0.28, 0.0, 1.0)
			var h: int = _hash(seed_i + k * 9176 + 17)
			var rx: float = float(h & 255) / 255.0 - 0.5
			var ry: float = float((h >> 8) & 255) / 255.0 - 0.5
			var ph: float = float((h >> 16) & 255) / 255.0 * TAU
			var sz: float = 0.6 + float((h >> 24) & 127) / 127.0 * 0.9
			var drift := Vector2(sin(_clock * 0.8 + ph), cos(_clock * 0.6 + ph * 1.3)) * 2.2
			var pos: Vector2 = p + Vector2(rx, ry) * tile * 0.95 + drift
			var tw: float = 0.55 + 0.45 * sin(_clock * 2.6 + ph)
			var a: float = (0.26 + 0.6 * s) * life * tw
			var d: float = (6.0 + 5.0 * sz) * (0.75 + 0.25 * s)
			draw_texture_rect(_dot_tex, Rect2(pos - Vector2(d, d) * 0.5, Vector2(d, d)), false,
				Color(col.r, col.g, col.b, a))
			# Светлая точка-сердцевина — только у свежих искр.
			if s > 0.45:
				var dc: float = d * 0.34
				draw_texture_rect(_dot_tex, Rect2(pos - Vector2(dc, dc) * 0.5, Vector2(dc, dc)), false,
					Color(1.0, 0.92, 0.72, a * 1.1))
