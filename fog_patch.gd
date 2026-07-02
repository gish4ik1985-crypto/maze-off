extends Node2D

# Локальное пятно тумана — «клякса»: появляется в случайном месте этажа,
# медленно клубится и спустя время рассасывается. Пока игрок ВНУТРИ пятна,
# его видимость падает (переиспользуем механику события «туман» игрока:
# короткие повторные apply_event("fog") — вышел из кляксы, и через долю
# секунды зрение возвращается само). Спавнится из main.gd:_trigger_event.

var radius: float = 170.0     # радиус действия пятна (мир. px)
var dur: float = 18.0         # время жизни (сек), включая проявление/рассасывание
var floor_index: int = 0      # этаж пятна (сравнивается с player.current_floor)

const FADE_IN := 1.6          # секунд на проявление
const FADE_OUT := 3.0         # секунд на рассасывание
const FOG_COLOR := Color(0.5, 0.6, 0.75)

var _t: float = 0.0
var _blobs: Array = []        # [{spr, base_pos, base_a, phase, spd}]
var _lt: PointLight2D
var _player: Node2D = null

func _ready() -> void:
	# Клубы: несколько мягких пятен-спрайтов со сдвигом — читается как облако,
	# а не идеальный круг. Дрейфуют в _process.
	var tex := MazeTextures.make_light(int(radius * 1.5))
	for i in 5:
		var s := Sprite2D.new()
		s.texture = tex
		var ang := randf() * TAU
		var off := Vector2(cos(ang), sin(ang)) * randf_range(0.0, radius * 0.45)
		s.position = off
		s.scale = Vector2.ONE * randf_range(0.7, 1.1)
		var a := randf_range(0.16, 0.26)
		s.modulate = Color(FOG_COLOR.r, FOG_COLOR.g, FOG_COLOR.b, 0.0)
		add_child(s)
		_blobs.append({spr = s, base_pos = off, base_a = a, phase = randf() * TAU, spd = randf_range(0.3, 0.7)})

	# Слабое серое свечение — туман виден и в полной темноте (как «муть», а не свет).
	_lt = PointLight2D.new()
	_lt.texture = tex
	_lt.color = FOG_COLOR
	_lt.energy = 0.0
	_lt.shadow_enabled = false
	add_child(_lt)

# Огибающая прозрачности: проявление -> плато -> рассасывание.
func _envelope() -> float:
	var rise: float = clampf(_t / FADE_IN, 0.0, 1.0)
	var fall: float = clampf((dur - _t) / FADE_OUT, 0.0, 1.0)
	return minf(rise, fall)

func _process(delta: float) -> void:
	_t += delta
	if _t >= dur:
		queue_free()
		return
	var env := _envelope()

	# Клубление: пятна медленно дрейфуют по кругу, alpha дышит.
	for b in _blobs:
		var spr: Sprite2D = b.spr
		var ph: float = b.phase + _t * b.spd
		spr.position = b.base_pos + Vector2(cos(ph), sin(ph * 0.7)) * radius * 0.08
		var breathe := 0.85 + 0.15 * sin(ph * 1.7)
		spr.modulate.a = b.base_a * env * breathe
	_lt.energy = 0.3 * env

	# Игрок внутри пятна → короткий «туман» (сам спадёт после выхода).
	if _player == null or not is_instance_valid(_player):
		var players := get_tree().get_nodes_in_group("player")
		_player = players[0] if players.size() > 0 else null
	if _player and env > 0.35 and int(_player.current_floor) == floor_index \
			and global_position.distance_to(_player.global_position) <= radius:
		_player.apply_event("fog", 0.35)
