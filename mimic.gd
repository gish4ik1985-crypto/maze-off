extends Area2D

# [GAMEDESIGN §34 «Роль вместо статов»] МИМИК — подделка под станцию зарядки.
#
# Выглядит ровно как синий кристалл-станция (та же текстура, тот же генератор —
# иначе подделку было бы видно по силуэту, и весь смысл пропал бы). Стоит в
# проходе среди настоящих станций. Когда игрок подходит достаточно близко,
# мимик «просыпается»: превращается в быстрого врага там же, где стоял.
#
# Зачем: станция — самый безопасный объект в игре (укрытие, где Свет не тает).
# Мимик — единственная механика, которая ставит под сомнение чтение мира: теперь
# «вижу станцию» не равно «спасён», и к кристаллу на низком Свете идёшь с
# оглядкой. Это роль, а не статы: сам враг после превращения — обычный FAST.
#
# Честность: мимик не наносит урона в момент превращения и оставляет игроку
# кадр на реакцию (WAKE_DELAY) — иначе это была бы не ловушка, а наказание за
# то, что игрок вообще подошёл к станции.

const TRIGGER_RADIUS := 86.0     # дистанция пробуждения (чуть больше зоны станции)
const WAKE_DELAY := 0.35         # пауза между «дрожью» и превращением
const ENEMY_TYPE_FAST := 1

var game: Node = null
var floor_index: int = 0
var cell: Vector2i = Vector2i.ZERO
var is_graph_mode: bool = false   # [§62] графовые Пещеры — превращение спавнит врага по мировой позиции, не по клетке

var _woken: bool = false
var _wake_t: float = 0.0
var _spr: Sprite2D
var _glow: PointLight2D
var _anim: float = 0.0

func _ready() -> void:
	add_to_group("mimic")
	process_mode = Node.PROCESS_MODE_PAUSABLE
	z_index = 4
	# ТА ЖЕ текстура, что у настоящей станции (station.gd) — подделка должна быть
	# неотличима на глаз до пробуждения.
	_spr = Sprite2D.new()
	_spr.texture = MazeTextures.make_charge_station(18, Color(0.35, 0.8, 1.0))
	add_child(_spr)
	_glow = PointLight2D.new()
	_glow.texture = MazeTextures.make_light(128)
	_glow.color = Color(0.4, 0.8, 1.0)
	_glow.energy = 0.7
	_glow.texture_scale = 0.6
	_glow.shadow_enabled = false
	add_child(_glow)

func _process(delta: float) -> void:
	_anim += delta
	if _spr:
		# Дыхание — как у настоящей станции, чтобы не выдавать себя статикой.
		_spr.scale = Vector2.ONE * (1.0 + 0.05 * sin(_anim * 2.2))
	if _woken:
		_wake_t -= delta
		if _wake_t <= 0.0:
			_transform()
		return
	if game == null or not is_instance_valid(game):
		return
	var pl = game.get("_player")
	if pl == null or not is_instance_valid(pl):
		return
	if int(pl.current_floor) != floor_index:
		return
	if pl.global_position.distance_to(global_position) <= TRIGGER_RADIUS:
		_wake()

func _wake() -> void:
	if _woken:
		return
	_woken = true
	_wake_t = WAKE_DELAY
	# Предупреждение за мгновение до превращения: цвет уходит в багрянец, свет
	# дёргается. Игрок должен успеть понять, что происходит, а не просто
	# обнаружить врага на своём месте.
	if _spr:
		_spr.modulate = Color(1.0, 0.35, 0.35)
	if _glow:
		_glow.color = Color(1.0, 0.3, 0.25)
		_glow.energy = 1.6
	if game.has_method("beep"):
		game.beep()
	if game.has_method("flash_message"):
		game.flash_message(GameConfig.tt(
			"◈ Это была не станция — МИМИК!",
			"◈ That was no station — a MIMIC!"))

func _transform() -> void:
	var g := game
	var f := floor_index
	var c := cell
	# Всплеск на месте подделки, чтобы превращение читалось как событие.
	if g != null and is_instance_valid(g):
		var b := Node2D.new()
		b.set_script(load("res://burst.gd"))
		b.color = Color(1.0, 0.4, 0.35, 1.0)
		b.global_position = global_position
		g.add_child(b)
		if is_graph_mode and g.has_method("spawn_mimic_enemy_graph"):
			g.spawn_mimic_enemy_graph(global_position, f)
		elif g.has_method("spawn_mimic_enemy"):
			g.spawn_mimic_enemy(c, f)
	queue_free()
