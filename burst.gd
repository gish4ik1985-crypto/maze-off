extends Node2D

# Расходящееся световое кольцо + вспышка света. Само анимируется и удаляется.
# Используется для Вспышки и для перехода между этажами. Параметры задаются
# снаружи до add_child.

var color: Color      = Color(1, 1, 1, 1)
var max_scale: float  = 6.0
var dur: float        = 0.45
var start_scale: float = 0.35
var light_energy: float = 1.6

var _t: float = 0.0
var _spr: Sprite2D
var _light: PointLight2D

func _ready() -> void:
	_spr = Sprite2D.new()
	_spr.texture = MazeTextures.make_ring(96)
	_spr.modulate = color
	_spr.scale = Vector2.ONE * start_scale
	_spr.z_index = 4
	add_child(_spr)

	_light = PointLight2D.new()
	_light.texture = MazeTextures.make_light(180)
	_light.color = color
	_light.energy = light_energy
	_light.shadow_enabled = false
	add_child(_light)

func _process(delta: float) -> void:
	_t += delta
	var k: float = _t / dur
	if k >= 1.0:
		queue_free()
		return
	var ease_k: float = 1.0 - pow(1.0 - k, 2.0)   # быстрый старт, мягкое замедление
	_spr.scale = Vector2.ONE * lerpf(start_scale, max_scale, ease_k)
	_spr.modulate.a = (1.0 - k) * color.a
	_light.energy = light_energy * (1.0 - k)
	_light.texture_scale = 0.5 + ease_k * 1.6
