extends Area2D

# Выход из лабиринта: портал (v1.9, был золотой ромбик — терялся среди
# осколков/станций). Заперт, пока не собраны ВСЕ осколки уровня — main.gd
# дёргает locked/unlock() через _refresh_exit_lock(). Радиус свечения больше
# любого другого объекта — портал должен быть виден издалека.

const OPEN_COLOR := Color(1.0, 0.86, 0.30)     # открыт — тёплое золото
const LOCKED_COLOR := Color(0.30, 0.27, 0.42)  # заперт — тусклый, «спящий»
const RADIUS := 34

var game: Node = null
var locked: bool = false

var _lt: PointLight2D
var _spr: Sprite2D
var _lock_icon: Sprite2D
var _anim: float = 0.0

func _ready() -> void:
	add_to_group("exit")   # обучение целится в выход стрелкой-указателем
	var col := CollisionShape2D.new()
	var shape := CircleShape2D.new()
	shape.radius = 30.0
	col.shape = shape
	add_child(col)

	_spr = Sprite2D.new()
	add_child(_spr)

	_lock_icon = Sprite2D.new()
	_lock_icon.texture = MazeTextures.make_lock(22, Color(1.0, 0.7, 0.5))
	_lock_icon.position = Vector2(0, -6)
	add_child(_lock_icon)

	# Заметное свечение большего радиуса, чем у прочих объектов — портал
	# должен манить издалека.
	_lt = PointLight2D.new()
	_lt.texture = MazeTextures.make_light(320)
	_lt.shadow_enabled = true
	add_child(_lt)

	_refresh_visual()
	body_entered.connect(_on_body_entered)

func _process(delta: float) -> void:
	_anim += delta
	if _spr:
		_spr.rotation += delta * (0.15 if locked else 0.55)   # заперт — почти неподвижен
	if locked:
		if _lt:
			_lt.energy = 0.28 + 0.08 * sin(_anim * 1.1)
		if _spr:
			_spr.scale = Vector2.ONE * (0.97 + 0.02 * sin(_anim * 1.1))
	else:
		if _lt:
			_lt.energy = 1.25 + 0.35 * sin(_anim * 1.8)
		if _spr:
			_spr.scale = Vector2.ONE * (0.97 + 0.05 * sin(_anim * 1.8))

func _refresh_visual() -> void:
	var c := LOCKED_COLOR if locked else OPEN_COLOR
	_spr.texture = MazeTextures.make_portal(RADIUS, c)
	_lt.color = c
	if _lock_icon:
		_lock_icon.visible = locked

# Вызывается main.gd::_refresh_exit_lock() при первичной постройке уровня —
# без эффекта, просто выставляет исходное состояние.
func set_locked_silent(v: bool) -> void:
	locked = v
	_refresh_visual()

# Вызывается main.gd, когда собран последний осколок уровня — портал
# «просыпается» с явным эффектом.
func unlock() -> void:
	if not locked:
		return
	locked = false
	_refresh_visual()
	if game and game.has_method("flash_screen"):
		game.flash_screen(OPEN_COLOR, 0.3)
	_spawn_unlock_fx()

func _spawn_unlock_fx() -> void:
	var p := get_parent()
	if p == null:
		return
	var b := Node2D.new()
	b.set_script(load("res://burst.gd"))
	b.color = Color(OPEN_COLOR.r, OPEN_COLOR.g, OPEN_COLOR.b, 1.0)
	b.max_scale = 6.0
	b.dur = 0.55
	b.light_energy = 2.4
	p.add_child(b)
	b.global_position = global_position
	var sp := CPUParticles2D.new()
	sp.set_script(load("res://sparkle.gd"))
	sp.spark_color = OPEN_COLOR
	sp.spark_amount = 26
	sp.spark_speed = 210.0
	p.add_child(sp)
	sp.global_position = global_position

func _on_body_entered(body: Node2D) -> void:
	if not body.is_in_group("player"):
		return
	if locked:
		if game and game.has_method("flash_message"):
			game.flash_message(GameConfig.tt("Портал заперт — нужно собрать все осколки", "The portal is sealed — collect all the shards first"))
		return
	if game and game.has_method("on_player_win"):
		game.on_player_win()
