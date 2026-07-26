extends Area2D

# Тёмная станция (GAMEDESIGN.md §22, самое крупное отложенное из бэклога
# v1.10) — воронка, всасывающая свет: пока игрок в её радиусе, Свет ТЕЧЁТ
# ИЗ него (обратный эффект обычной станции), а враги в радиусе получают
# тёмно-фиолетовый ореол и бафф скорости («чуют» подпитку из воронки).
#
# Взаимное подавление со станциями света: если рядом (SUPPRESS_RADIUS) есть
# активная станция света (station.gd, заряжена и не погашена), тёмная станция
# подавлена — не тянет свет и не баффает врагов, тускнеет. Понятный игроку
# сигнал/тактика: «отвоюй территорию у света». Как и антистанция супербосса
# (antistation.gd — тот же прием, здесь общедоступный, не только на арене),
# игрок может её погасить активным навыком (Вспышка/Сонар) насовсем.

const HP := 3
const COLOR := Color(0.55, 0.05, 0.68)   # глубокий тёмный фиолет — не путать со SLOW-врагом (ярче) или Волей (циан)
const DRAIN_RADIUS := 90.0
const DRAIN_RATE := 0.09       # света в секунду, пока игрок внутри и воронка активна
const BUFF_RADIUS := 220.0     # враги внутри получают ореол + бафф скорости
const BUFF_MULT := 1.25
const SUPPRESS_RADIUS := 260.0 # ближайшая активная станция света в этом радиусе — воронка подавлена

var game: Node = null
var floor_index: int = 0
var _hp: int = HP
var active: bool = true
var _suppressed: bool = false
var _player: Node2D = null

var _spr: Sprite2D
var _lt: PointLight2D
var _anim: float = 0.0
var _suppress_check_cd: float = 0.0
const SUPPRESS_CHECK_INTERVAL := 0.5   # не считать дистанции до всех станций каждый кадр

func _ready() -> void:
	add_to_group("enemy")          # Вспышка/Сонар/пет достают её как обычную цель
	add_to_group("dark_station")   # враги ищут подпитку (см. pursuer.gd::_dark_station_mult)
	var col := CollisionShape2D.new()
	var shape := CircleShape2D.new()
	shape.radius = DRAIN_RADIUS
	col.shape = shape
	add_child(col)

	_spr = Sprite2D.new()
	_spr.texture = MazeTextures.make_portal(20, COLOR)
	add_child(_spr)

	_lt = PointLight2D.new()
	_lt.texture = MazeTextures.make_light(170)
	_lt.color = COLOR
	_lt.energy = 0.85
	_lt.shadow_enabled = false
	add_child(_lt)

	body_entered.connect(_on_body_entered)
	body_exited.connect(_on_body_exited)

func _on_body_entered(body: Node2D) -> void:
	if body.is_in_group("player"):
		_player = body

func _on_body_exited(body: Node2D) -> void:
	if body == _player:
		_player = null

func is_energized() -> bool:
	return active and not _suppressed

func _process(delta: float) -> void:
	_anim += delta
	if not active:
		return

	_suppress_check_cd -= delta
	if _suppress_check_cd <= 0.0:
		_suppress_check_cd = SUPPRESS_CHECK_INTERVAL
		_suppressed = _has_nearby_light_station()

	if _suppressed:
		if _spr:
			_spr.modulate = Color(0.5, 0.5, 0.55, 0.4)
			_spr.scale = Vector2.ONE * 0.85
		if _lt:
			_lt.energy = 0.15
		return

	if _spr:
		# Крутится «неправильно» — засасывающий портал, а не открывающий.
		_spr.rotation -= delta * 0.9
		_spr.scale = Vector2.ONE * (0.95 + 0.06 * sin(_anim * 2.4))
		_spr.modulate = Color(1, 1, 1, 1)
	if _lt:
		_lt.energy = 0.65 + 0.3 * sin(_anim * 2.4)

	if _player != null and is_instance_valid(_player) and "energy" in _player:
		_player.energy = maxf(0.0, _player.energy - DRAIN_RATE * delta)

func _has_nearby_light_station() -> bool:
	for s in get_tree().get_nodes_in_group("station"):
		if not is_instance_valid(s):
			continue
		if not s.has_method("is_charged") or not s.is_charged():
			continue
		if global_position.distance_to(s.global_position) <= SUPPRESS_RADIUS:
			return true
	return false

# Интерфейс, ожидаемый main.gd::skill_hit_enemies (как у antistation.gd) —
# возвращает true, когда воронка гаснет этим попаданием; статистику/бестиарий
# не трогаем — это не враг, а объект окружения.
func take_damage(dmg: int, _source: String) -> bool:
	if not active:
		return false
	_hp -= dmg
	if _spr:
		_spr.modulate = Color(1.6, 1.3, 1.3)
		var tw := create_tween()
		tw.tween_property(_spr, "modulate", Color.WHITE, 0.2)
	if _hp <= 0:
		_deactivate()
		return true
	return false

func _deactivate() -> void:
	active = false
	# Выходим из групп — как antistation.gd: погашенная воронка не должна
	# оставаться «валидной целью» (пет/Вспышка/Сонар) и не должна баффать
	# врагов (is_energized проверяется, но группа лишней быть не должна).
	remove_from_group("enemy")
	remove_from_group("dark_station")
	if _lt:
		_lt.energy = 0.0
	if _spr:
		_spr.modulate = Color(0.35, 0.35, 0.4, 0.55)
		_spr.rotation = 0.0
	if game and game.has_method("flash_message"):
		game.flash_message(GameConfig.tt("Тёмная станция погашена", "Dark station doused"))
