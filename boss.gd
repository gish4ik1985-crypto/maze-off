extends Node2D

# Тёмное Ядро — босс режима «Накал».
# Фаза 1: медленно движется по арене, слабая точка видна только при активном Сонаре.
#          5 ударов Вспышкой (Q) вблизи — переход в фазу 2.
# Фаза 2: расщепляется на 3 фрагмента (pursuer.gd, тип FAST).
#          Фрагменты уничтожаются Щитом (заморозка) + Вспышкой.
#          Когда все фрагменты уничтожены — on_player_win().

const FLASH_HIT_RANGE  := 260.0   # дальность удара Вспышкой (≈5 клеток — щедро)
const SONAR_REVEAL_DUR := 3.0     # секунды видимости слабой точки после Сонара
const MAX_HP           := 5

var _game: Node
var _player: Node
var _hp: int = MAX_HP
var _sonar_reveal: float = 0.0   # убывает; > 0 — слабая точка видима (Сонар → ×2 урон)

# ── ИИ: машина состояний ──────────────────────────────────────────────────
# HUNT — преследует игрока; DOUSE — идёт гасить станцию; CHARGE — телеграф+рывок
# в игрока; RECOVER — уязвимая передышка после рывка.
enum St { HUNT, DOUSE, CHARGE, RECOVER }
const HUNT_SPEED    := 70.0    # скорость преследования
const DOUSE_SPEED   := 130.0   # быстро мчит к станции
const CHARGE_SPEED  := 430.0   # рывок-бросок в игрока (надо уворачиваться)
const DOUSE_DUR     := 7.0     # на сколько секунд гаснет станция
const CONTACT_DMG_CD := 1.2    # пауза между уронами при контакте
var _state: int = St.HUNT
var _state_t: float = 0.0      # сколько ещё в этом состоянии
var _target_pos: Vector2 = Vector2.ZERO
var _charge_dir: Vector2 = Vector2.ZERO
var _telegraph: float = 0.0    # > 0 — замах перед рывком
var _douse_target: Node = null
var _contact_cd: float = 0.0

# Визуал
var _body: Sprite2D
var _glow: PointLight2D
var _weak_ring: Node2D   # маркер слабой точки (виден только при Сонаре)
var _hp_bg: ColorRect    # фон HP-полоски
var _hp_fill: ColorRect  # заполнение HP-полоски
var _hit_flash: float = 0.0
var _stun_time: float = 0.0
var _anim: float = 0.0

func _ready() -> void:
	_game = get_meta("game")
	# Игрок хранится в _game как _player, достаём через метод или группу
	if _game and _game.has_method("get"):
		_player = _game.get("_player")
	if _player == null or not is_instance_valid(_player):
		var pl := get_tree().get_nodes_in_group("player")
		_player = pl[0] if pl.size() > 0 else null

	# Основное тело
	_body = Sprite2D.new()
	_body.texture = _make_boss_texture(64)
	add_child(_body)

	# Свечение — яркий пурпурный маяк, виден через всю арену
	_glow = PointLight2D.new()
	_glow.texture = MazeTextures.make_light(220)
	_glow.color = Color(0.7, 0.15, 1.0, 1.0)
	_glow.energy = 2.6
	_glow.texture_scale = 2.6
	add_child(_glow)

	# Маркер слабой точки (виден только при Сонаре)
	_weak_ring = Node2D.new()
	_weak_ring.visible = false
	add_child(_weak_ring)
	var ring := MeshInstance2D.new()
	var torus := TorusMesh.new()
	torus.inner_radius = 22.0
	torus.outer_radius = 30.0
	ring.mesh = torus
	ring.modulate = Color(1.0, 0.8, 0.0, 0.85)
	_weak_ring.add_child(ring)

	# HP-полоска над боссом (яркие цвета — читается даже в затемнённой арене)
	_hp_bg = ColorRect.new()
	_hp_bg.color = Color(0.15, 0.0, 0.0, 0.9)
	_hp_bg.size = Vector2(140, 16)
	_hp_bg.position = Vector2(-70, -78)
	add_child(_hp_bg)

	_hp_fill = ColorRect.new()
	_hp_fill.color = Color(1.0, 0.25, 0.15, 1.0)
	_hp_fill.size = Vector2(136, 12)
	_hp_fill.position = Vector2(-68, -76)
	add_child(_hp_fill)

	var hp_title := Label.new()
	hp_title.text = "ТЁМНОЕ ЯДРО"
	hp_title.add_theme_font_size_override("font_size", 14)
	hp_title.add_theme_color_override("font_color", Color(1.0, 0.6, 0.5))
	hp_title.position = Vector2(-70, -98)
	add_child(hp_title)

	_update_hp_bar()
	_enter_hunt(3.0)

func _process(delta: float) -> void:
	_anim += delta
	if _stun_time > 0.0:
		_stun_time -= delta
		_body.modulate = Color(1.0, 0.5, 0.5, 1.0)
		return
	_body.modulate = Color(1.0, 1.0, 1.0, 1.0)

	if _hit_flash > 0.0:
		_hit_flash -= delta
		_body.modulate = Color(1.0, 0.3, 0.1, 1.0)

	# Пульс масштаба
	var pulse: float = 1.0 + sin(_anim * 1.8) * 0.06
	_body.scale = Vector2.ONE * pulse
	_glow.energy = 1.8 + sin(_anim * 2.2) * 0.4

	# Таймер видимости слабой точки (от Сонара)
	if _sonar_reveal > 0.0:
		_sonar_reveal -= delta
		_weak_ring.visible = true
	else:
		_weak_ring.visible = false

	# Босс замирает, пока игрок не сделал первый ход — как «заморозка времени»
	# в начале уровня. Иначе он атакует ещё до того, как игрок взял управление.
	if _player and is_instance_valid(_player) and not _player.started:
		return

	_update_ai(delta)
	_check_contact()

func reveal_weak_point() -> void:
	_sonar_reveal = SONAR_REVEAL_DUR
	_weak_ring.visible = true

func try_flash_hit(player_pos: Vector2) -> void:
	if _stun_time > 0.3:
		return   # короткая неуязвимость сразу после попадания
	if player_pos.distance_to(global_position) > FLASH_HIT_RANGE:
		if _game and _game.has_method("flash_message"):
			_game.flash_message("Подойди ближе к Ядру и жми Q")
		return

	# Сонар активен → двойной урон. Без него — обычный (босс всё равно проходим).
	var dmg: int = 2 if _sonar_reveal > 0.0 else 1
	_hp = maxi(0, _hp - dmg)
	_hit_flash = 0.4
	_stun_time = 0.4
	_update_hp_bar()

	# Эффект попадания
	var bst := Node2D.new()
	bst.set_script(load("res://burst.gd"))
	bst.color = Color(1.0, 0.7, 0.1, 1.0)
	bst.max_scale = 7.0
	bst.dur = 0.5
	get_parent().add_child(bst)
	bst.global_position = global_position

	if _game and _game.has_method("flash_message"):
		var tip := "  (Сонар ×2!)" if dmg == 2 else "  ·  Сонар (E) усилит удар"
		_game.flash_message("Попадание! HP Ядра: %d/%d%s" % [_hp, MAX_HP, tip])

	if _hp <= 0:
		_die()

func _die() -> void:
	# Большой взрыв
	for i in 5:
		var bst := Node2D.new()
		bst.set_script(load("res://burst.gd"))
		bst.color = Color(0.6, 0.1, 1.0, 1.0)
		bst.max_scale = float(i + 3) * 3.0
		bst.dur = 0.6 + float(i) * 0.1
		get_parent().add_child(bst)
		bst.global_position = global_position + Vector2(randf_range(-40, 40), randf_range(-40, 40))

	var death_pos := global_position
	queue_free()

	if _game and _game.has_method("on_boss_phase2"):
		_game.on_boss_phase2(death_pos)

# ── ИИ ────────────────────────────────────────────────────────────────────
func _update_ai(delta: float) -> void:
	if _player == null or not is_instance_valid(_player):
		return
	if _contact_cd > 0.0:
		_contact_cd -= delta

	_state_t -= delta
	match _state:
		St.HUNT:
			# Преследование игрока
			_move_toward(_player.global_position, HUNT_SPEED, delta)
			if _state_t <= 0.0:
				_choose_next_state()
		St.DOUSE:
			# Мчимся к выбранной станции и гасим её при достижении
			if _douse_target == null or not is_instance_valid(_douse_target) \
					or _douse_target.is_charged() == false:
				_enter_hunt(2.0)
			else:
				var sp: Vector2 = _douse_target.global_position
				_move_toward(sp, DOUSE_SPEED, delta)
				if global_position.distance_to(sp) < 50.0:
					_douse_target.douse(DOUSE_DUR)
					if _game and _game.has_method("flash_message"):
						_game.flash_message("⚠ Ядро гасит станцию! Беги к боссу, не к свету")
					_spawn_ring(Color(1.0, 0.2, 0.15))
					_enter_hunt(3.0)
			if _state_t <= 0.0:
				_enter_hunt(2.0)
		St.CHARGE:
			if _telegraph > 0.0:
				# Замах: стоим, трясёмся, целимся в игрока
				_telegraph -= delta
				_charge_dir = (_player.global_position - global_position).normalized()
				_body.position = Vector2(randf_range(-4, 4), randf_range(-4, 4))
				_glow.color = Color(1.0, 0.3, 0.1)
				if _telegraph <= 0.0:
					_body.position = Vector2.ZERO
					_glow.color = Color(0.7, 0.15, 1.0)
					_state_t = 0.55   # длительность рывка
			else:
				# Рывок по прямой
				global_position += _charge_dir * CHARGE_SPEED * delta
				if _state_t <= 0.0:
					_state = St.RECOVER
					_state_t = 1.6
		St.RECOVER:
			# Уязвимая передышка — почти не двигается, удобно бить
			_move_toward(_player.global_position, HUNT_SPEED * 0.3, delta)
			if _state_t <= 0.0:
				_enter_hunt(3.0)

func _choose_next_state() -> void:
	# Вариативность: есть заряженные станции — иногда идём гасить; иначе рывок/охота
	var st := _nearest_charged_station()
	var r := randf()
	if st != null and r < 0.45:
		_state = St.DOUSE
		_douse_target = st
		_state_t = 6.0
	elif r < 0.8:
		_state = St.CHARGE
		_telegraph = 0.8
		_state_t = 0.8
		if _game and _game.has_method("flash_message"):
			_game.flash_message("Ядро готовит рывок — уворачивайся!")
	else:
		_enter_hunt(3.5)

func _enter_hunt(dur: float) -> void:
	_state = St.HUNT
	_state_t = dur
	_telegraph = 0.0
	_body.position = Vector2.ZERO

func _move_toward(pos: Vector2, speed: float, delta: float) -> void:
	var dir: Vector2 = pos - global_position
	if dir.length() > 4.0:
		global_position += dir.normalized() * speed * delta

func _nearest_charged_station() -> Node:
	var best: Node = null
	var best_d: float = INF
	for s in get_tree().get_nodes_in_group("station"):
		if not is_instance_valid(s) or not s.has_method("is_charged"):
			continue
		if not s.is_charged():
			continue
		var d: float = global_position.distance_to(s.global_position)
		if d < best_d:
			best_d = d
			best = s
	return best

# Контакт с игроком: урон по свету + отбрасывание; если игрок со щитом — стан боссу.
func _check_contact() -> void:
	if _player == null or not is_instance_valid(_player):
		return
	if global_position.distance_to(_player.global_position) > 70.0:
		return
	if _player.has_method("is_shielded") and _player.is_shielded():
		_stun_time = maxf(_stun_time, 2.0)
		_spawn_ring(Color(0.6, 0.86, 1.0))
		return
	if _contact_cd > 0.0:
		return
	_contact_cd = CONTACT_DMG_CD
	if _player.has_method("hit_by_enemy"):
		_player.hit_by_enemy(0.35)
	if _player.has_method("add_shake"):
		_player.add_shake(8.0, 0.3)

func _spawn_ring(col: Color) -> void:
	var b := Node2D.new()
	b.set_script(load("res://burst.gd"))
	b.color = col
	b.max_scale = 4.0
	b.dur = 0.4
	get_parent().add_child(b)
	b.global_position = global_position

func _update_hp_bar() -> void:
	if _hp_fill:
		var frac: float = float(_hp) / float(MAX_HP)
		_hp_fill.size.x = 136.0 * frac
		# Цвет от красного к жёлтому по мере добивания
		_hp_fill.color = Color(1.0, 0.25, 0.15).lerp(Color(1.0, 0.85, 0.2), 1.0 - frac)

func _make_boss_texture(size: int) -> ImageTexture:
	var img := Image.create_empty(size, size, false, Image.FORMAT_RGBA8)
	img.fill(Color(0, 0, 0, 0))
	var cx: float = size * 0.5
	var cy: float = size * 0.5
	var r: float  = size * 0.42
	for py in size:
		for px in size:
			var dx: float = px - cx
			var dy: float = py - cy
			var dist: float = sqrt(dx * dx + dy * dy)
			if dist <= r:
				var t: float = 1.0 - dist / r
				var alpha: float = clampf(t * 2.0, 0.0, 1.0)
				# Тёмное ядро с ярким пурпурным ободом по краю
				var rim: float = smoothstep(0.0, 0.35, t) * (1.0 - smoothstep(0.55, 1.0, t))
				var core: float = t * 0.2
				img.set_pixel(px, py, Color(
					core * 0.8 + rim * 0.9,
					core * 0.1 + rim * 0.2,
					core + rim * 1.0,
					alpha))
	return ImageTexture.create_from_image(img)
