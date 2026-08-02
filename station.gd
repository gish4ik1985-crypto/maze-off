extends Area2D

# Энергокристалл: при заходе ПЕРЕДАЁТ заряд игроку не мгновенно, а каналом за
# TRANSFER_TIME секунд — сама тускнеет по мере отдачи, затем истощена и
# восстанавливается RECHARGE_TIME секунд. Пока восстанавливается — не
# действует (стоять и бесконечно фармить нельзя). Также служит чекпоинтом.
#
# [GAMEDESIGN §48] Кольцо-шкала вокруг кристалла убрано по просьбе игрока: это
# был отдельный UI-виджет поверх мира, а не часть станции. Вместо него —
# ЧИСТОЕ СВЕЧЕНИЕ: яркость и размер ореола/капсулы/точечного света идут ОДНИМ
# числом _charge (_apply_charge_visual) — заряжена = ярко и крупно, отдаёт или
# восстанавливается = тускло и мелко. Радиус света и ореола держится
# небольшим НАМЕРЕННО: станция должна читаться только вблизи, а не пробивать
# виньетку тьмы издалека (в отличие от столпов залов из §40, которые как раз
# ДОЛЖНЫ быть видны издалека — это разные роли, разная яркость). Когда игрок
# использует Озарение/Сонар, виньетка открывается сама и станция становится
# видна в общем радиусе обзора — специального кода для этого не нужно.
#
# [GAMEDESIGN §47] Раньше глоток был мгновенным щелчком в момент входа — вся
# передача укладывалась в один кадр, и «станция дала заряд» читалось как факт,
# а не как событие. Теперь это процесс: тонкий луч тянется от кристалла к
# игроку, кристалл гаснет по мере того, как в нём остаётся всё меньше, а
# игрок получает Свет постепенно, кадр за кадром.

const STATION_COLOR := Color(0.35, 0.78, 1.0)   # электрик-синяя энергия
const RECHARGE_TIME := 5.0                       # секунд на восстановление
const TRANSFER_TIME := 0.9                       # [§47] секунд на передачу заряда игроку
const ENERGY_SECONDS := 0.6                      # глоток = charge_per_sec * это
const XP_PER_DRAW := 20                          # XP за глоток
const REVEAL_PER_DRAW := 0.2                     # заряд озарения за глоток

var game: Node = null      # ссылка на главную сцену
var floor_index: int = 0   # на каком этаже расположена станция
var _visited: bool = false # за первое посещение начисляется бонус XP
var _charge: float = 1.0   # 0 — истощён, 1 — заряжен (во время передачи падает плавно)
var _player: Node2D = null
var _doused: float = 0.0   # > 0 — станция погашена боссом (не действует)

# [§47] Состояние передачи. Пока идёт — станция не реагирует на повторный
# вход (is_charged() уже лжёт), а отданное считается ДОЛЯМИ кадра, чтобы
# сумма за TRANSFER_TIME совпала с прежним разовым глотком.
var _transferring: bool = false
var _transfer_t: float = 0.0
var _transfer_body: Node2D = null

var _lt: PointLight2D
# [§43] Станция рисуется в 4x и ужимается спрайтом — иначе на клетке 48px
# видно лесенки (жалоба «пиксельная графика, какой-то жучок»).
const HD_SCALE := 4
const BASE_RADIUS := 10          # было 15: 4.5*R по высоте = 45 < клетки 48
const HD_RADIUS := BASE_RADIUS * HD_SCALE
# Базовый масштаб спрайта. ЛЮБАЯ анимация обязана домножать на него, а не
# присваивать scale целиком — ровно на этом станции раздулись вчетверо в §43.
const SPR_BASE := 1.0 / float(HD_SCALE)
var _halo: Sprite2D
var _spr: Sprite2D
var _beam: Line2D   # [§47] канал передачи — виден только во время _transferring
var _anim: float = 0.0

# [дизайн-референс Sprite/123.html, v.4.3] Живая 3D-визуализация станции
# (Three.js, кристалл + вращающиеся энергокольца + парящие частицы света) —
# не спрайт и не импортируется (игра рисует всё кодом, см. CLAUDE.md), поэтому
# идея переносится в те же средства, что уже использует станция: два тонких
# кольца (MazeTextures.make_ring), сплюснутые в эллипс и "кувыркающиеся"
# через scale.x = sin(t) — дешёвая имитация вращения тора в 3D без реальной
# перспективы, и CPUParticles2D с медленно всплывающими мотыльками света
# вокруг кристалла (аналог "Частиц Света" в референсе). Оба элемента дышат
# вместе с _charge, как halo/_lt — гаснут при разрядке/погашении боссом.
var _ring_a: Sprite2D
var _ring_b: Sprite2D
var _motes: CPUParticles2D

func _ready() -> void:
	add_to_group("station")

	var col := CollisionShape2D.new()
	var shape := CircleShape2D.new()
	shape.radius = 40.0
	col.shape = shape
	add_child(col)

	# ОРЕОЛ вокруг станции: мягкое свечение под самой капсулой (§43), дышит
	# вместе с зарядом (§47/§48). Радиус текстуры небольшой НАМЕРЕННО — §48:
	# станция должна читаться только вблизи, а не быть видна издалека.
	_halo = Sprite2D.new()
	_halo.texture = MazeTextures.make_light(110)
	_halo.modulate = Color(STATION_COLOR.r, STATION_COLOR.g, STATION_COLOR.b, 0.30)
	add_child(_halo)

	_spr = Sprite2D.new()
	# Рисуем в 4x и уменьшаем спрайт: make_charge_station(15) давала картинку
	# ~24x48 пикселей, растянутую на клетку 48px, — отсюда лесенки. Тот же
	# приём, что у SkillIcons.make_hd.
	_spr.texture = MazeTextures.make_charge_station(HD_RADIUS, STATION_COLOR)
	_spr.scale = Vector2.ONE * SPR_BASE
	_spr.texture_filter = CanvasItem.TEXTURE_FILTER_LINEAR_WITH_MIPMAPS
	add_child(_spr)

	# [§62.5 / v.4.3, референс Sprite/123.html] Два кольца энергии, разного
	# радиуса и цветового оттенка (электрик-синий + сиреневый — та же пара, что
	# в референсе), сплюснутые в эллипс так, чтобы читаться как кольцо вокруг
	# кристалла в ¾-виде игры, а не как обычный нимб (для этого уже есть halo).
	_ring_a = Sprite2D.new()
	_ring_a.texture = MazeTextures.make_ring(96)
	_ring_a.scale = Vector2(0.62, 0.62 * 0.34)   # ⌀ ~60px, сплюснуто в эллипс
	_ring_a.modulate = Color(STATION_COLOR.r, STATION_COLOR.g, STATION_COLOR.b, 0.0)
	add_child(_ring_a)

	_ring_b = Sprite2D.new()
	_ring_b.texture = MazeTextures.make_ring(126)
	_ring_b.scale = Vector2(0.68, 0.68 * 0.30)   # ⌀ ~86px, крупнее и площе первого
	_ring_b.modulate = Color(0.75, 0.55, 1.0, 0.0)   # сиреневый акцент, как в референсе
	add_child(_ring_b)

	# Мотыльки света: несколько частиц медленно всплывают и гаснут вокруг
	# кристалла по кругу — постоянная (не разовая, в отличие от burst.gd/
	# sparkle.gd) эмиссия небольшого объёма, чтобы не давить на GL Compatibility
	# даже при MAX_CAVES_STATIONS/MAX_STATIONS станций разом на этаже.
	_motes = CPUParticles2D.new()
	_motes.texture = MazeTextures.make_ball(3, Color(1, 1, 1))
	_motes.amount = 6
	_motes.lifetime = 2.2
	_motes.preprocess = 2.2   # без этого первые ~2с после спавна станции без частиц
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

	_lt = PointLight2D.new()
	# [§48] Радиус меньше, чем был: свет не должен пробивать виньетку тьмы на
	# расстоянии — только освещать вблизи. Столпы залов (§40) намеренно яркие
	# и дальнобойные, это их роль; станция — наоборот, интимный источник.
	_lt.texture = MazeTextures.make_light(130)
	_lt.color = STATION_COLOR
	_lt.energy = 0.85
	# Без теней: множество станций с тенями превышает лимит источников
	# в GL Compatibility и свет начинает мерцать/пропадать.
	_lt.shadow_enabled = false
	add_child(_lt)

	# [§47] Луч-канал: тонкая линия от кристалла к игроку, видна только пока
	# идёт передача.
	_beam = Line2D.new()
	_beam.width = 3.0
	_beam.visible = false
	_beam.default_color = Color(STATION_COLOR.r, STATION_COLOR.g, STATION_COLOR.b, 0.8)
	add_child(_beam)

	body_entered.connect(_on_body_entered)
	body_exited.connect(_on_body_exited)

func _on_body_entered(body: Node2D) -> void:
	if not body.is_in_group("player"):
		return
	_player = body
	# Чекпоинт ставится при любом заходе — не завязан на то, есть ли заряд.
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
	_begin_transfer(body)

# Босс гасит станцию на dur секунд — лишает игрока подзарядки в бою.
func douse(dur: float) -> void:
	_doused = maxf(_doused, dur)
	_transferring = false
	_beam.visible = false
	_charge = 0.0

func is_charged() -> bool:
	return _doused <= 0.0 and not _transferring and _charge >= 1.0

# [§47] Начать передачу заряда: только если кристалл полон и не занят другой
# передачей/не погашен. Сам глоток размазывается по TRANSFER_TIME в _process.
func _begin_transfer(body: Node2D) -> void:
	if _doused > 0.0 or _transferring or _charge < 1.0:
		return
	_transferring = true
	_transfer_t = 0.0
	_transfer_body = body
	_beam.visible = true

func _on_body_exited(body: Node2D) -> void:
	if body == _player:
		_player = null
	if body.is_in_group("player") and "charge_sources" in body:
		body.charge_sources = maxi(0, int(body.charge_sources) - 1)
	# [§47] Игрок ушёл раньше конца передачи — канал рвётся, станция оставляет
	# себе то, что уже отдала (не откатывается к полному заряду: нельзя вернуться
	# и дожать бесплатно — уже начатая передача тратится честно).
	if body == _transfer_body:
		_transferring = false
		_transfer_body = null
		_beam.visible = false

func _process(delta: float) -> void:
	_anim += delta

	_animate_rings()

	if _doused > 0.0:
		_doused -= delta
		# Тёмно-красное мерцание «погашенной» станции
		if _lt:
			_lt.color = Color(1.0, 0.2, 0.15)
			_lt.energy = 0.12 + 0.08 * sin(_anim * 9.0)
		if _spr:
			_spr.modulate = Color(0.7, 0.3, 0.3, 0.3)
			_spr.scale = Vector2.ONE * SPR_BASE * 0.85
		if _halo:
			_halo.modulate.a = 0.08
		if _ring_a:
			_ring_a.modulate.a = 0.0
		if _ring_b:
			_ring_b.modulate.a = 0.0
		if _motes:
			_motes.emitting = false
		return
	elif _motes and not _motes.emitting:
		_motes.emitting = true

	if _transferring:
		_transfer_t += delta
		var frac: float = clampf(_transfer_t / TRANSFER_TIME, 0.0, 1.0)
		_charge = 1.0 - frac   # кристалл тускнеет по мере отдачи — это и есть отклик
		if is_instance_valid(_transfer_body):
			var d_frac: float = delta / TRANSFER_TIME
			var body: Node2D = _transfer_body
			var gulp: float = float(body.charge_per_sec) * ENERGY_SECONDS * d_frac
			body.energy = minf(body.max_energy, body.energy + gulp)
			if body.has_method("add_will"):
				body.add_will(body.WILL_PER_STATION * d_frac)
			if "reveal_charge" in body:
				body.reveal_charge = minf(1.0, body.reveal_charge + REVEAL_PER_DRAW * d_frac)
			_beam.points = PackedVector2Array([Vector2.ZERO, to_local(body.global_position)])
			_beam.default_color = Color(STATION_COLOR.r, STATION_COLOR.g, STATION_COLOR.b,
				0.85 * (1.0 - frac * 0.4))   # луч тоже слабеет к концу передачи
		else:
			_beam.visible = false
		if frac >= 1.0:
			_transferring = false
			_transfer_body = null
			_beam.visible = false
			_charge = 0.0
			GameConfig.add_xp(XP_PER_DRAW)
			GameConfig.bump_stat("stations_used")
			if game and game.has_method("_announce_milestones"):
				game._announce_milestones()
			if game:
				if game.has_method("beep"):
					game.beep()
				if game.get("_fx"):
					game._fx.gold_pulse(0.6)
				if game.has_method("tutorial_station_used"):
					game.tutorial_station_used()
			_spawn_burst()
		_apply_charge_visual()
		return

	# Восстановление кристалла (передача даётся только при ЗАХОДЕ, не стоя —
	# чтобы нельзя было фармить кемпингом: нужно выйти из зоны и вернуться)
	if _charge < 1.0:
		_charge = minf(1.0, _charge + delta / RECHARGE_TIME)

	_apply_charge_visual()

# [§47] Единая точка, где заряд превращается в яркость/размер/ореол — читается
# и во время передачи (тускнеет), и во время восстановления (разгорается),
# и в покое (дышит). Раньше логика была продублирована по месту.
func _apply_charge_visual() -> void:
	var pulse: float = 1.0 + 0.07 * sin(_anim * 2.4) * _charge
	if _lt:
		_lt.color = STATION_COLOR
		_lt.energy = (0.35 + 0.65 * _charge) * pulse
	if _spr:
		_spr.modulate = Color(1, 1, 1, 0.4 + 0.6 * _charge)
		_spr.scale = Vector2.ONE * SPR_BASE * (0.9 + 0.08 * _charge) * pulse
	if _halo:
		# [§48] Контраст между «заряжена» и «тускнеет/восстанавливается» несёт
		# вся ответственность за читаемость — раньше это дублировало кольцо.
		# 0.05 в минимуме почти не видно вблизи, 0.34 на полном заряде заметно.
		_halo.modulate = Color(STATION_COLOR.r, STATION_COLOR.g, STATION_COLOR.b,
			(0.05 + 0.29 * _charge) * pulse)
		_halo.scale = Vector2.ONE * (0.82 + 0.22 * _charge)
	if _ring_a:
		_ring_a.modulate.a = (0.10 + 0.32 * _charge) * pulse
	if _ring_b:
		_ring_b.modulate.a = (0.06 + 0.22 * _charge) * pulse
	if _motes:
		_motes.amount = maxi(1, int(round(6 * (0.3 + 0.7 * _charge))))

# [референс Sprite/123.html] Кольца "вращаются вокруг колонны" в 3D — здесь,
# в 2D, тот же образ читается дешевле: scale.x кольца качается через синус
# независимо от scale.y (эллипс то раскрывается в кольцо, то схлопывается в
# линию) — глаз читает это как тор, наклоняющийся при вращении. Две скорости
# и фазы у ring_a/ring_b, чтобы они не двигались синхронно (иначе выглядело
# бы как одно кольцо, не два).
func _animate_rings() -> void:
	if _ring_a:
		_ring_a.rotation = _anim * 0.6
		_ring_a.scale.x = 0.62 * (0.55 + 0.45 * absf(sin(_anim * 0.9)))
	if _ring_b:
		_ring_b.rotation = -_anim * 0.4
		_ring_b.scale.x = 0.68 * (0.55 + 0.45 * absf(sin(_anim * 0.7 + 1.4)))

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
