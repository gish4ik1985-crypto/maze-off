extends Area2D

# Маяк (GAMEDESIGN.md п.10.6): временная плюшка-цель в лабиринте. Появляется
# один раз за уровень в случайной точке подальше от игрока, звучит тихим
# «пинг» и держится 20-30 секунд. Кто добежал — получает случайный бонус.
# Не успел — гаснет без следа. Создаёт срочность и выбор «жадность vs
# осторожность», не меняя правил игры (в отличие от игровых событий-тинтов).

const BEACON_KINDS := ["gold", "azure", "crimson", "silver", "emerald"]
const KIND_COLORS := {
	"gold":    Color(1.0, 0.85, 0.25),
	"azure":   Color(0.35, 0.78, 1.0),
	"crimson": Color(1.0, 0.25, 0.25),
	"silver":  Color(0.92, 0.94, 0.99),
	"emerald": Color(0.25, 1.0, 0.55),
}

var game: Node = null
var kind: String = ""
var life: float = 0.0   # если не задано снаружи — выбирается случайно в _ready

var _lt: PointLight2D
var _spr: Sprite2D
var _anim: float = 0.0
var _col: Color = Color.WHITE
var _pulse_t: float = 1.0   # таймер пульса-указателя (первый — через секунду)
var _player: Node2D = null

func _ready() -> void:
	add_to_group("beacon")
	if kind == "":
		kind = BEACON_KINDS[randi() % BEACON_KINDS.size()]
	if life <= 0.0:
		life = randf_range(20.0, 30.0)
	_col = KIND_COLORS.get(kind, Color.WHITE)

	var col := CollisionShape2D.new()
	var shape := CircleShape2D.new()
	shape.radius = 24.0
	col.shape = shape
	add_child(col)

	_spr = Sprite2D.new()
	_spr.texture = MazeTextures.make_beacon(18, _col)   # v1.9: вышка-шпиль, не путать с осколком/выходом
	add_child(_spr)

	_lt = PointLight2D.new()
	_lt.texture = MazeTextures.make_light(200)
	_lt.color = _col
	_lt.energy = 1.1
	_lt.shadow_enabled = false
	add_child(_lt)

	body_entered.connect(_on_body_entered)

func _process(delta: float) -> void:
	_anim += delta
	life -= delta
	if life <= 0.0:
		_spawn_fade_fx()
		queue_free()
		return
	# Мерцает быстрее и тревожнее по мере истечения времени — «спеши».
	var urgency: float = clampf(1.0 - life / 6.0, 0.0, 1.0)
	var pulse_speed: float = 3.0 + urgency * 6.0
	if _lt:
		_lt.energy = 0.85 + 0.35 * sin(_anim * pulse_speed)
	if _spr:
		_spr.rotation = _anim * 1.1
		_spr.scale = Vector2.ONE * (0.95 + 0.09 * sin(_anim * pulse_speed))

	# Пульс-указатель (отключается в настройках): раз в 2 сек от игрока улетает
	# полупрозрачная искра в сторону маяка — направление без точной навигации.
	if GameConfig.beacon_pulse:
		_pulse_t -= delta
		if _pulse_t <= 0.0:
			_pulse_t = 2.0
			_emit_direction_pulse()

func _emit_direction_pulse() -> void:
	if _player == null or not is_instance_valid(_player):
		var pl := get_tree().get_nodes_in_group("player")
		_player = pl[0] if pl.size() > 0 else null
	if _player == null:
		return
	var from: Vector2 = _player.global_position
	var dir: Vector2 = (global_position - from)
	if dir.length() < 120.0:
		return   # маяк уже рядом/на экране — подсказка не нужна
	dir = dir.normalized()
	var s := Sprite2D.new()
	s.texture = MazeTextures.make_light(46)
	s.modulate = Color(_col.r, _col.g, _col.b, 0.55)
	s.top_level = false
	var p := get_parent()
	if p == null:
		return
	p.add_child(s)
	s.global_position = from + dir * 40.0
	var tw := s.create_tween()
	tw.tween_property(s, "global_position", from + dir * 190.0, 1.0) \
		.set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	tw.parallel().tween_property(s, "modulate:a", 0.0, 1.0)
	tw.tween_callback(s.queue_free)

func _on_body_entered(body: Node2D) -> void:
	if not body.is_in_group("player"):
		return
	if game and game.has_method("beacon_reward"):
		game.beacon_reward(kind)
	_spawn_reach_fx()
	queue_free()

func _spawn_reach_fx() -> void:
	var p := get_parent()
	if p == null:
		return
	var b := Node2D.new()
	b.set_script(load("res://burst.gd"))
	b.color = _col
	b.max_scale = 4.0
	b.dur = 0.5
	b.light_energy = 1.8
	p.add_child(b)
	b.global_position = global_position
	var sp := CPUParticles2D.new()
	sp.set_script(load("res://sparkle.gd"))
	sp.spark_color = _col
	sp.spark_amount = 24
	sp.spark_speed = 200.0
	p.add_child(sp)
	sp.global_position = global_position

func _spawn_fade_fx() -> void:
	var p := get_parent()
	if p == null:
		return
	var b := Node2D.new()
	b.set_script(load("res://burst.gd"))
	b.color = Color(_col.r, _col.g, _col.b, 0.4)
	b.max_scale = 2.2
	b.dur = 0.5
	p.add_child(b)
	b.global_position = global_position
