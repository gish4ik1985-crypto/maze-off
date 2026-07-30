extends Node2D

# [GAMEDESIGN §31 «Шум»] Кольцо-волна на месте применения навыка: показывает
# игроку РАДИУС, в котором враги услышали каст. Без него механика невидима —
# враг «ни с того ни с сего» пошёл в твою сторону, и это читается как баг AI,
# а не как последствие твоего решения.
#
# Сам по себе узел ничего не делает с игрой: слушают враги (pursuer.hear),
# зовёт main.gd::make_noise. Это только визуализация.
#
# Самоудаляющийся эффект в стиле проекта: параметры выставляются ДО add_child,
# дальше узел живёт сам и убирает себя.

var radius: float = 300.0            # мировой радиус слышимости
var color: Color = Color(1.0, 0.85, 0.45)
var dur: float = 0.55

var _t: float = 0.0
var _spr: Sprite2D

func _ready() -> void:
	z_index = 40
	_spr = Sprite2D.new()
	_spr.texture = MazeTextures.make_ring(96)
	_spr.modulate = Color(color.r, color.g, color.b, 0.0)
	add_child(_spr)

func _process(delta: float) -> void:
	_t += delta
	var k: float = clampf(_t / dur, 0.0, 1.0)
	if _spr:
		# Кольцо расходится от точки каста до радиуса слышимости и гаснет:
		# 96px текстура -> нужный диаметр (radius * 2).
		var target_scale: float = (radius * 2.0) / 96.0
		_spr.scale = Vector2.ONE * lerpf(0.12, target_scale, ease(k, 0.35))
		# Яркость: быстрый всплеск и плавное затухание, чтобы волна читалась
		# даже поверх светлого пола рядом с игроком.
		var a: float = (1.0 - k) * (1.0 - k) * 0.75
		_spr.modulate = Color(color.r, color.g, color.b, a)
	if _t >= dur:
		queue_free()
