extends Area2D

# Энергокристалл: при заходе ДАЁТ РАЗОВЫЙ глоток света + XP + заряд озарения,
# затем истощается и восстанавливается RECHARGE_TIME секунд. Пока восстанавливается
# — не действует (стоять и бесконечно фармить нельзя). Также служит чекпоинтом.
# Шкала восстановления рисуется кольцом вокруг кристалла (_draw).

const STATION_COLOR := Color(0.35, 0.78, 1.0)   # электрик-синяя энергия
const RECHARGE_TIME := 5.0                       # секунд на восстановление
const ENERGY_SECONDS := 0.6                      # глоток = charge_per_sec * это
const XP_PER_DRAW := 20                          # XP за глоток
const REVEAL_PER_DRAW := 0.2                     # заряд озарения за глоток
const GAUGE_R := 26.0                            # радиус кольца-шкалы

var game: Node = null      # ссылка на главную сцену
var floor_index: int = 0   # на каком этаже расположена станция
var _visited: bool = false # за первое посещение начисляется бонус XP
var _charge: float = 1.0   # 0 — истощён, 1 — заряжен
var _player: Node2D = null
var _doused: float = 0.0   # > 0 — станция погашена боссом (не действует)

var _lt: PointLight2D
var _spr: Sprite2D
var _anim: float = 0.0

func _ready() -> void:
	add_to_group("station")

	var col := CollisionShape2D.new()
	var shape := CircleShape2D.new()
	shape.radius = 40.0
	col.shape = shape
	add_child(col)

	_spr = Sprite2D.new()
	_spr.texture = MazeTextures.make_charge_station(15, STATION_COLOR)   # v1.9: энергокапсула, не гем
	add_child(_spr)

	_lt = PointLight2D.new()
	_lt.texture = MazeTextures.make_light(130)
	_lt.color = STATION_COLOR
	_lt.energy = 0.7
	# Без теней: множество станций с тенями превышает лимит источников
	# в GL Compatibility и свет начинает мерцать/пропадать.
	_lt.shadow_enabled = false
	add_child(_lt)

	body_entered.connect(_on_body_entered)
	body_exited.connect(_on_body_exited)

func _on_body_entered(body: Node2D) -> void:
	if not body.is_in_group("player"):
		return
	_player = body
	# Чекпоинт ставится при любом заходе
	if game and game.has_method("set_checkpoint"):
		game.set_checkpoint(floor_index, global_position)
	# В режиме «Накал» станция — ещё и алтарь: банкует несомый Накал в безопасность.
	if game and game.has_method("bank_ember"):
		game.bank_ember()
	# Бонус 50 XP за первое посещение этой станции в текущем уровне
	if not _visited:
		_visited = true
		GameConfig.add_xp(50)
	# Станция-убежище: пока игрок в зоне кристалла, расход Света остановлен
	# (player.gd читает charge_sources в блоке разрядки).
	if "charge_sources" in body:
		body.charge_sources += 1
	_draw_energy(body)

# Босс гасит станцию на dur секунд — лишает игрока подзарядки в бою.
func douse(dur: float) -> void:
	_doused = maxf(_doused, dur)
	_charge = 0.0
	queue_redraw()

func is_charged() -> bool:
	return _doused <= 0.0 and _charge >= 1.0

# Разовый глоток: только если кристалл полностью заряжен и не погашен.
func _draw_energy(body: Node2D) -> void:
	if _doused > 0.0 or _charge < 1.0:
		return   # погашена боссом или ещё восстанавливается — не действует
	var gulp: float = float(body.charge_per_sec) * ENERGY_SECONDS
	body.energy = minf(body.max_energy, body.energy + gulp)
	# Глоток даёт и Волю — активная навигация между станциями кормит навыки.
	if body.has_method("add_will"):
		body.add_will(body.WILL_PER_STATION)
	GameConfig.add_xp(XP_PER_DRAW)
	GameConfig.bump_stat("stations_used")
	if game and game.has_method("_announce_milestones"):
		game._announce_milestones()
	if "reveal_charge" in body:
		body.reveal_charge = minf(1.0, body.reveal_charge + REVEAL_PER_DRAW)
	_charge = 0.0
	queue_redraw()
	# Звук + вспышка-отклик
	if game:
		if game.has_method("beep"):
			game.beep()
		if game.get("_fx"):
			game._fx.gold_pulse(0.6)
		if game.has_method("tutorial_station_used"):
			game.tutorial_station_used()
	_spawn_burst()

func _on_body_exited(body: Node2D) -> void:
	if body == _player:
		_player = null
	if body.is_in_group("player") and "charge_sources" in body:
		body.charge_sources = maxi(0, int(body.charge_sources) - 1)

func _process(delta: float) -> void:
	_anim += delta

	# Погашена боссом: не восстанавливается, пока таймер не истёк.
	if _doused > 0.0:
		_doused -= delta
		if _doused <= 0.0:
			queue_redraw()
		# Тёмно-красное мерцание «погашенной» станции
		if _lt:
			_lt.color = Color(1.0, 0.2, 0.15)
			_lt.energy = 0.12 + 0.08 * sin(_anim * 9.0)
		if _spr:
			_spr.modulate = Color(0.7, 0.3, 0.3, 0.3)
			_spr.scale = Vector2.ONE * 0.85
		return

	# Восстановление кристалла (глоток даётся только при ЗАХОДЕ, не стоя — чтобы
	# нельзя было фармить камПингом: нужно выйти из зоны и вернуться)
	if _charge < 1.0:
		_charge = minf(1.0, _charge + delta / RECHARGE_TIME)
		queue_redraw()

	# Яркость/размер кристалла = уровень заряда (плавный градиент истощения)
	var pulse: float = 1.0 + 0.07 * sin(_anim * 2.4) * _charge
	if _lt:
		_lt.color = STATION_COLOR
		_lt.energy = (0.28 + 0.5 * _charge) * pulse
	if _spr:
		_spr.modulate = Color(1, 1, 1, 0.4 + 0.6 * _charge)
		_spr.scale = Vector2.ONE * (0.9 + 0.08 * _charge) * pulse

# Кольцо-шкала восстановления вокруг кристалла.
func _draw() -> void:
	if _charge >= 0.999:
		return   # заряжен — шкалу не показываем, просто горит
	# Фон-кольцо (тускло)
	draw_arc(Vector2.ZERO, GAUGE_R, 0.0, TAU, 48, Color(0.12, 0.22, 0.38, 0.4), 2.0, true)
	# Заполнение по часовой от верха; цвет плавно ярчает по мере восстановления
	var col := Color(0.25, 0.45, 0.75, 0.7).lerp(Color(0.6, 0.95, 1.0, 1.0), _charge)
	draw_arc(Vector2.ZERO, GAUGE_R, -PI * 0.5, -PI * 0.5 + TAU * _charge, 48, col, 3.5, true)

func _spawn_burst() -> void:
	var p := get_parent()
	if p == null:
		return
	var b := Node2D.new()
	b.set_script(load("res://burst.gd"))
	b.color = Color(0.5, 0.85, 1.0, 1.0)
	b.max_scale = 3.0
	b.dur = 0.45
	p.add_child(b)
	b.global_position = global_position
