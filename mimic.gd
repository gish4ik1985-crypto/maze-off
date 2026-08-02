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

# [BUGFIX 02.08.2026, v.4.3] Станция получила вращающиеся кольца энергии и
# частицы (station.gd, референс Sprite/123.html) — те же узлы нужны и здесь,
# иначе мимик выдавал бы себя ИМЕННО отсутствием того, чем и должен быть
# неотличим на первый взгляд («та же текстура» выше перестала быть всей
# правдой в тот момент, когда у станции появились новые ПОДВИЖНЫЕ элементы
# сверх текстуры). Параметры и анимация — 1:1 со station.gd.
var _ring_a: Sprite2D
var _ring_b: Sprite2D
var _motes: CPUParticles2D
const STATION_COLOR := Color(0.35, 0.78, 1.0)

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

	_ring_a = Sprite2D.new()
	_ring_a.texture = MazeTextures.make_ring(96)
	_ring_a.scale = Vector2(0.62, 0.62 * 0.34)
	_ring_a.modulate = Color(STATION_COLOR.r, STATION_COLOR.g, STATION_COLOR.b, 0.42)
	add_child(_ring_a)

	_ring_b = Sprite2D.new()
	_ring_b.texture = MazeTextures.make_ring(126)
	_ring_b.scale = Vector2(0.68, 0.68 * 0.30)
	_ring_b.modulate = Color(0.75, 0.55, 1.0, 0.28)
	add_child(_ring_b)

	_motes = CPUParticles2D.new()
	_motes.texture = MazeTextures.make_ball(3, Color(1, 1, 1))
	_motes.amount = 6
	_motes.lifetime = 2.2
	_motes.preprocess = 2.2
	_motes.emission_shape = CPUParticles2D.EMISSION_SHAPE_SPHERE_SURFACE
	_motes.emission_sphere_radius = 22.0
	_motes.direction = Vector2(0, -1)
	_motes.spread = 25.0
	_motes.gravity = Vector2(0, -14.0)
	_motes.initial_velocity_min = 4.0
	_motes.initial_velocity_max = 10.0
	_motes.scale_amount_min = 0.6
	_motes.scale_amount_max = 1.2
	var motes_ramp := Gradient.new()
	motes_ramp.offsets = PackedFloat32Array([0.0, 0.25, 1.0])
	motes_ramp.colors = PackedColorArray([
		Color(STATION_COLOR.r, STATION_COLOR.g, STATION_COLOR.b, 0.0),
		Color(STATION_COLOR.r, STATION_COLOR.g, STATION_COLOR.b, 0.85),
		Color(1.0, 1.0, 1.0, 0.0),
	])
	_motes.color_ramp = motes_ramp
	_motes.z_index = 3
	_motes.emitting = true
	add_child(_motes)

func _process(delta: float) -> void:
	_anim += delta
	if _spr:
		# Дыхание — как у настоящей станции, чтобы не выдавать себя статикой.
		_spr.scale = Vector2.ONE * (1.0 + 0.05 * sin(_anim * 2.2))
	if not _woken:
		# Та же анимация колец, что и в station.gd::_animate_rings().
		if _ring_a:
			_ring_a.rotation = _anim * 0.6
			_ring_a.scale.x = 0.62 * (0.55 + 0.45 * absf(sin(_anim * 0.9)))
		if _ring_b:
			_ring_b.rotation = -_anim * 0.4
			_ring_b.scale.x = 0.68 * (0.55 + 0.45 * absf(sin(_anim * 0.7 + 1.4)))
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
	# Кольца/частицы гаснут вместе со сменой цвета — станция погашенная боссом
	# (station.gd::douse) точно так же теряет их, а не оставляет крутиться.
	if _ring_a:
		_ring_a.modulate.a = 0.0
	if _ring_b:
		_ring_b.modulate.a = 0.0
	if _motes:
		_motes.emitting = false
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
