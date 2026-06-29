extends Node2D

# Тёмное Ядро — босс режима «Накал».
# Фаза 1: медленно движется по арене, слабая точка видна только при активном Сонаре.
#          5 ударов Вспышкой (Q) вблизи — переход в фазу 2.
# Фаза 2: расщепляется на 3 фрагмента (pursuer.gd, тип FAST).
#          Фрагменты уничтожаются Щитом (заморозка) + Вспышкой.
#          Когда все фрагменты уничтожены — on_player_win().

const FLASH_HIT_RANGE  := 220.0   # дальность удара Вспышкой
const SONAR_REVEAL_DUR := 3.0     # секунды видимости слабой точки после Сонара
const MOVE_SPEED       := 55.0    # скорость в фазе 1
const REPATH_INTERVAL  := 1.8
const MAX_HP           := 5

var _game: Node
var _player: Node
var _hp: int = MAX_HP
var _sonar_reveal: float = 0.0   # убывает; > 0 — слабая точка видима
var _blind_hit_count: int = 0    # счётчик ударов без Сонара (каждый 2-й засчитывается)

# Навигация (прямое движение, не по BFS — арена открытая)
var _target_pos: Vector2 = Vector2.ZERO
var _repath_cd: float = 0.0

# Визуал
var _body: Sprite2D
var _glow: PointLight2D
var _weak_ring: Node2D   # маркер слабой точки (виден только при Сонаре)
var _hp_label: Label
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

	# Свечение
	_glow = PointLight2D.new()
	_glow.texture = MazeTextures.make_light(220)
	_glow.color = Color(0.3, 0.0, 0.5, 1.0)
	_glow.energy = 1.8
	_glow.texture_scale = 2.2
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

	# HP-счётчик
	_hp_label = Label.new()
	_hp_label.add_theme_font_size_override("font_size", 22)
	_hp_label.add_theme_color_override("font_color", Color(1.0, 0.4, 0.2))
	_hp_label.position = Vector2(-40, -80)
	add_child(_hp_label)
	_update_hp_label()

	_pick_new_target()

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

	# Движение
	_repath_cd -= delta
	if _repath_cd <= 0.0:
		_pick_new_target()
		_repath_cd = REPATH_INTERVAL

	if _target_pos != Vector2.ZERO:
		var dir: Vector2 = (_target_pos - global_position)
		if dir.length() > 8.0:
			global_position += dir.normalized() * MOVE_SPEED * delta
		else:
			_pick_new_target()

func reveal_weak_point() -> void:
	_sonar_reveal = SONAR_REVEAL_DUR
	_weak_ring.visible = true

func try_flash_hit(player_pos: Vector2) -> void:
	if _stun_time > 0.0:
		return
	if player_pos.distance_to(global_position) > FLASH_HIT_RANGE:
		if _game and _game.has_method("flash_message"):
			_game.flash_message("Подойди ближе!")
		return
	# Без Сонара урон наносится, но двойная стоимость (нужно 2 удара вместо 1)
	if _sonar_reveal <= 0.0:
		if _game and _game.has_method("flash_message"):
			_game.flash_message("Используй Сонар (E) чтобы найти слабую точку!")
		# Засчитываем только каждый второй удар без Сонара
		_blind_hit_count = _blind_hit_count + 1 if _blind_hit_count >= 0 else 0
		if _blind_hit_count % 2 != 0:
			return

	_hp -= 1
	_hit_flash = 0.35
	_stun_time = 0.5
	_update_hp_label()

	# Эффект попадания
	var bst := Node2D.new()
	bst.set_script(load("res://burst.gd"))
	bst.color = Color(1.0, 0.7, 0.1, 1.0)
	bst.max_scale = 7.0
	bst.dur = 0.5
	get_parent().add_child(bst)
	bst.global_position = global_position

	if _game and _game.has_method("flash_message"):
		_game.flash_message("Попадание! Осталось: %d" % _hp)

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

func _pick_new_target() -> void:
	if _game == null:
		return
	# Чередуем: преследуем игрока, затем идём в случайную точку
	if _player and is_instance_valid(_player) and randf() < 0.6:
		_target_pos = _player.global_position
	else:
		var game_cols: int = _game.get("_cols") if _game.get("_cols") else 12
		var game_rows: int = _game.get("_rows") if _game.get("_rows") else 10
		var tile: float = _game.get("TILE") if _game.get("TILE") else 48.0
		var rx: float = randf_range(2.0, float(game_cols - 2)) * tile * 2
		var ry: float = randf_range(2.0, float(game_rows - 2)) * tile * 2
		_target_pos = Vector2(rx, ry)

func _update_hp_label() -> void:
	if _hp_label:
		_hp_label.text = "❤ ".repeat(_hp)

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
				var alpha: float = t * t
				var brightness: float = t * 0.25
				img.set_pixel(px, py, Color(brightness * 0.6, brightness * 0.05, brightness, alpha))
	return ImageTexture.create_from_image(img)
