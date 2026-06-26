extends Node2D

# Сонар работает в двух фазах:
#   1. Кольцо (DURATION секунд) — расходится от игрока, проходит сквозь стены.
#   2. Послесвечение (GLOW_DURATION секунд) — мягкий заполняющий свет большого
#      радиуса остаётся на месте и плавно угасает, позволяя видеть лабиринт.

const DURATION      := 1.1    # длительность фазы кольца
const START_SCALE   := 0.4
const MAX_SCALE     := 27.0
const START_ENERGY  := 3.5

const GLOW_DURATION := 5.0    # длительность послесвечения
const GLOW_ENERGY   := 1.8    # начальная яркость заполняющего света
const GLOW_SCALE    := 22.0   # масштаб текстуры заполняющего света

var _t: float = 0.0
var _phase: int = 0            # 0 = кольцо, 1 = послесвечение

var _light: PointLight2D       # кольцо
var _glow: PointLight2D        # заполняющий свет

var _glow_dur: float = GLOW_DURATION
var _glow_energy: float = GLOW_ENERGY
var _glow_scale: float = GLOW_SCALE

func _ready() -> void:
	# Мастерство (или Апекс) масштабирует послесвечение
	var m: float = float(get_meta("mastery_mult", 1.0))
	_glow_dur = GLOW_DURATION * m
	_glow_energy = GLOW_ENERGY * minf(m, 2.0)   # яркость не более x2
	_glow_scale = GLOW_SCALE * sqrt(m)          # радиус растёт мягче

	_light = PointLight2D.new()
	_light.texture = MazeTextures.make_ring(128)
	_light.color = Color(0.45, 0.92, 1.0)   # яркий неоновый циан
	_light.energy = START_ENERGY
	_light.texture_scale = START_SCALE
	_light.shadow_enabled = false
	add_child(_light)

	# Заполняющий свет — круглое пятно, изначально скрыто
	_glow = PointLight2D.new()
	_glow.texture = MazeTextures.make_light(256)
	_glow.color = Color(0.4, 0.7, 1.0)
	_glow.energy = 0.0
	_glow.texture_scale = _glow_scale
	_glow.shadow_enabled = false
	add_child(_glow)

func _process(delta: float) -> void:
	_t += delta

	if _phase == 0:
		var k: float = _t / DURATION
		if k >= 1.0:
			# Кольцо исчезло — переходим к послесвечению
			_light.visible = false
			_glow.energy = _glow_energy
			_phase = 1
			_t = 0.0
			return
		_light.texture_scale = lerpf(START_SCALE, MAX_SCALE, k)
		_light.energy = lerpf(START_ENERGY, 0.0, k)

	else:
		var k: float = _t / _glow_dur
		if k >= 1.0:
			queue_free()
			return
		# Плавное угасание послесвечения
		_glow.energy = lerpf(_glow_energy, 0.0, k)
