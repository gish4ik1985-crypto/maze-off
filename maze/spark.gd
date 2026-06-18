extends Node2D

# «Искра» — путеводный огонёк к выходу. Маленький светящийся шарик с хвостом
# света, летит по кратчайшему маршруту к выходу и гаснет через LIFETIME секунд.
# Докуда успел долететь — настолько и подсказал путь (на больших уровнях до
# выхода намеренно не долетает). Маршрут (мировые точки) задаётся снаружи.

const LIFETIME := 5.0
const SPEED := 360.0
const TRAIL_POINTS := 16     # длина хвоста-кометы в точках
const TRAIL_STEP := 10.0     # минимальная дистанция между точками хвоста
const COLOR := Color(1.0, 0.85, 0.35)

var path_points: PackedVector2Array = PackedVector2Array()

var _idx: int = 1
var _t: float = 0.0
var _done: bool = false
var _trail: Line2D
var _light: PointLight2D
var _core: Sprite2D

func _ready() -> void:
	if path_points.size() > 0:
		global_position = path_points[0]

	# Свечение — освещает коридор по ходу движения (и делает огонёк видимым во тьме)
	_light = PointLight2D.new()
	_light.texture = MazeTextures.make_light(200)
	_light.color = COLOR
	_light.energy = 1.1
	_light.texture_scale = 1.0
	_light.shadow_enabled = false
	add_child(_light)

	# Хвост-комета. top_level — чтобы точки задавались в мировых координатах
	# и хвост «оставался позади», пока голова летит вперёд.
	_trail = Line2D.new()
	_trail.top_level = true
	_trail.width = 8.0
	_trail.z_index = 1
	_trail.joint_mode = Line2D.LINE_JOINT_ROUND
	_trail.begin_cap_mode = Line2D.LINE_CAP_ROUND
	_trail.end_cap_mode = Line2D.LINE_CAP_ROUND
	var grad := Gradient.new()
	grad.offsets = PackedFloat32Array([0.0, 1.0])
	grad.colors = PackedColorArray([
		Color(COLOR.r, COLOR.g, COLOR.b, 0.0),    # хвост — прозрачный
		Color(COLOR.r, COLOR.g, COLOR.b, 0.95),   # голова — яркая
	])
	_trail.gradient = grad
	var wcurve := Curve.new()
	wcurve.add_point(Vector2(0.0, 0.2))   # хвост тоньше
	wcurve.add_point(Vector2(1.0, 1.0))   # голова шире
	_trail.width_curve = wcurve
	add_child(_trail)
	_trail.add_point(global_position)

	# Сам шарик — меньше игрока (у игрока радиус 18)
	_core = Sprite2D.new()
	_core.texture = MazeTextures.make_ball(8, Color(1, 1, 1))
	_core.z_index = 2
	add_child(_core)

	if path_points.size() < 2:
		_done = true

func _process(delta: float) -> void:
	_t += delta
	var k: float = _t / LIFETIME
	if k >= 1.0:
		queue_free()
		return

	# Движение вдоль маршрута: проходим столько точек, на сколько хватает шага
	if not _done:
		var step := SPEED * delta
		while step > 0.0 and _idx < path_points.size():
			var to: Vector2 = path_points[_idx]
			var d := global_position.distance_to(to)
			if d <= step:
				global_position = to
				step -= d
				_idx += 1
			else:
				global_position = global_position.move_toward(to, step)
				step = 0.0
		if _idx >= path_points.size():
			_done = true  # дошёл до конца известного отрезка пути

	# Хвост: добавляем новую точку, когда отошли достаточно далеко
	var n := _trail.get_point_count()
	if n == 0 or global_position.distance_to(_trail.get_point_position(n - 1)) >= TRAIL_STEP:
		_trail.add_point(global_position)
		while _trail.get_point_count() > TRAIL_POINTS:
			_trail.remove_point(0)

	# Затухание в последней трети жизни + лёгкая пульсация
	var fade := 1.0
	if k > 0.65:
		fade = clampf(1.0 - (k - 0.65) / 0.35, 0.0, 1.0)
	_light.energy = 1.1 * fade
	_light.texture_scale = 0.9 + 0.12 * sin(_t * 14.0)
	_core.modulate = Color(1, 1, 1, fade)
	_trail.modulate = Color(1, 1, 1, fade)
