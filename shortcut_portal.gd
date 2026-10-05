extends Area2D

# Внутриэтажный портал-срезка (GAMEDESIGN.md §17.4) — редкая пара телепортов
# НА ОДНОМ этаже (не между этажами, как обычные двери — door.gd). Всегда
# открыт, без ключей: секрет, который нужно найти. Переносит к парному
# порталу и обратно — симметрично, в отличие от одностороннего door.gd.

var game: Node = null
var floor_index: int = 0
var partner: Area2D = null

const PORTAL_COLOR := Color(0.3, 0.95, 0.75)   # бирюза — не путать с дверьми (фиолет) и станциями (синий)
const COOLDOWN_AFTER_ARRIVE := 0.5

var _spr: Sprite2D
var _lt: PointLight2D
var _anim: float = 0.0
var _cooldown: float = 0.0

func _ready() -> void:
	var col := CollisionShape2D.new()
	var shape := CircleShape2D.new()
	shape.radius = 26.0
	col.shape = shape
	add_child(col)

	_spr = Sprite2D.new()
	_spr.texture = MazeTextures.make_portal(18, PORTAL_COLOR)
	add_child(_spr)

	_lt = PointLight2D.new()
	_lt.texture = MazeTextures.make_light(140)
	_lt.color = PORTAL_COLOR
	_lt.energy = 0.6
	_lt.shadow_enabled = false
	add_child(_lt)

	body_entered.connect(_on_body_entered)

func _process(delta: float) -> void:
	_anim += delta
	if _cooldown > 0.0:
		_cooldown -= delta
	if _spr:
		_spr.rotation += delta * 1.1
		_spr.scale = Vector2.ONE * (0.95 + 0.05 * sin(_anim * 2.6))
	if _lt:
		_lt.energy = 0.55 + 0.2 * sin(_anim * 2.6)

func _on_body_entered(body: Node2D) -> void:
	if _cooldown > 0.0 or not body.is_in_group("player"):
		return
	if partner == null or not is_instance_valid(partner):
		return
	# Кулдауны СРАЗУ (синхронно): между колбэком и отложенным телепортом
	# повторный body_entered не должен сработать.
	_cooldown = COOLDOWN_AFTER_ARRIVE
	partner._cooldown = COOLDOWN_AFTER_ARRIVE
	# [AUDIT 05.10.2026 №6] Телепорт тела и спавн эффект-ноды — не в физическом
	# колбэке (правило CLAUDE.md «flushing queries», образец — door.gd::_enter).
	_teleport.call_deferred(body)

func _teleport(body: Node2D) -> void:
	if not is_instance_valid(body) or not is_instance_valid(partner):
		return
	body.global_position = partner.global_position
	if "current_floor" in body:
		body.current_floor = floor_index
	if body.has_method("snap_camera"):
		body.snap_camera()
	if game and game.has_method("flash_screen"):
		game.flash_screen(PORTAL_COLOR, 0.28)
	_spawn_warp(partner.global_position)

func _spawn_warp(pos: Vector2) -> void:
	if game == null:
		return
	var b := Node2D.new()
	b.set_script(load("res://burst.gd"))
	b.color = Color(PORTAL_COLOR.r, PORTAL_COLOR.g, PORTAL_COLOR.b, 1.0)
	b.max_scale = 4.5
	b.light_energy = 2.0
	game.add_child(b)
	b.global_position = pos
