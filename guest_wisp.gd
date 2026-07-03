extends Node2D

# «Гость лабиринта»: ОГОНЁК-СОЮЗНИК. Дружественный дух на время: летит за
# игроком, слегка подсвечивает путь и раз в несколько секунд отвлекает
# ближайшего преследователя на ложную цель (та же механика, что «Мираж»).

const FOLLOW_LERP := 3.0
const DISTRACT_CD := 4.0
const DISTRACT_RANGE := 900.0
const COLOR := Color(0.5, 1.0, 0.75)

var game: Node = null
var life: float = 25.0

var _anim: float = 0.0
var _cd: float = 1.5
var _spr: Sprite2D
var _lt: PointLight2D
var _player: Node2D = null

func _ready() -> void:
	add_to_group("guest")
	_spr = Sprite2D.new()
	_spr.texture = MazeTextures.make_light(42)
	_spr.modulate = COLOR
	add_child(_spr)
	_lt = PointLight2D.new()
	_lt.texture = MazeTextures.make_light(230)
	_lt.color = COLOR
	_lt.energy = 0.9
	_lt.shadow_enabled = false
	add_child(_lt)

func _process(delta: float) -> void:
	_anim += delta
	life -= delta
	if life <= 0.0:
		_fade_out()
		return
	if _player == null or not is_instance_valid(_player):
		var pl := get_tree().get_nodes_in_group("player")
		_player = pl[0] if pl.size() > 0 else null
	if _player:
		# Летит рядом с игроком, слегка кружа (не закрывает обзор по центру).
		var orbit := Vector2(cos(_anim * 1.7), sin(_anim * 1.3)) * 46.0
		var target: Vector2 = _player.global_position + orbit + Vector2(0, -30)
		global_position = global_position.lerp(target, minf(1.0, FOLLOW_LERP * delta))
	if _spr:
		_spr.scale = Vector2.ONE * (0.9 + 0.15 * sin(_anim * 5.0))
		# Последние секунды — тает.
		_spr.modulate.a = minf(1.0, life / 3.0)
	if _lt:
		_lt.energy = (0.7 + 0.25 * sin(_anim * 4.0)) * minf(1.0, life / 3.0)

	_cd -= delta
	if _cd <= 0.0:
		_cd = DISTRACT_CD
		_distract_nearest()

# Отвлечь ближайшего гонящегося врага на ложную клетку (механика Миража).
func _distract_nearest() -> void:
	if _player == null or game == null or not is_instance_valid(game):
		return
	var best: Node2D = null
	var best_d := DISTRACT_RANGE
	for e in get_tree().get_nodes_in_group("enemy"):
		if not is_instance_valid(e) or e.is_in_group("guest"):
			continue
		if not (e.has_method("is_chasing") and e.is_chasing()):
			continue
		var d: float = e.global_position.distance_to(_player.global_position)
		if d < best_d:
			best_d = d
			best = e
	if best == null or not best.has_method("distract_to"):
		return
	# Ложная цель: случайная клетка в стороне от игрока.
	var cols: int = game._cols
	var rows: int = game._rows
	var c := Vector2i(randi_range(0, cols - 1), randi_range(0, rows - 1))
	best.distract_to(c, 3.5)
	# Искра от огонька к обманутому врагу — видно, кто спас.
	var s := Sprite2D.new()
	s.texture = MazeTextures.make_light(40)
	s.modulate = Color(COLOR.r, COLOR.g, COLOR.b, 0.7)
	var p := get_parent()
	if p == null:
		return
	p.add_child(s)
	s.global_position = global_position
	var tw := s.create_tween()
	tw.tween_property(s, "global_position", best.global_position, 0.4) \
		.set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	tw.parallel().tween_property(s, "modulate:a", 0.0, 0.4)
	tw.tween_callback(s.queue_free)

func _fade_out() -> void:
	var p := get_parent()
	if p:
		var b := Node2D.new()
		b.set_script(load("res://burst.gd"))
		b.color = Color(COLOR.r, COLOR.g, COLOR.b, 0.5)
		b.max_scale = 2.0
		b.dur = 0.5
		p.add_child(b)
		b.global_position = global_position
	queue_free()
