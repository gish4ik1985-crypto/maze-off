extends Node2D

# Сонар: световое кольцо, расходящееся от игрока. Проходит сквозь стены
# (без теней) и кратко подсвечивает планировку лабиринта вокруг.

const DURATION := 1.1
const START_SCALE := 0.4
const MAX_SCALE := 9.0
const START_ENERGY := 1.5

var _t := 0.0
var _light: PointLight2D

func _ready() -> void:
	_light = PointLight2D.new()
	_light.texture = MazeTextures.make_ring(128)
	_light.color = Color(0.5, 0.8, 1.0)
	_light.energy = START_ENERGY
	_light.texture_scale = START_SCALE
	_light.shadow_enabled = false
	add_child(_light)

func _process(delta: float) -> void:
	_t += delta
	var k: float = _t / DURATION
	if k >= 1.0:
		queue_free()
		return
	_light.texture_scale = lerpf(START_SCALE, MAX_SCALE, k)
	_light.energy = lerpf(START_ENERGY, 0.0, k)
