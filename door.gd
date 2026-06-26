extends Area2D

# Серая двусторонняя дверь между этажами. Может быть заперта — тогда нужен
# собранный осколок-ключ. С шансом перегенерирует этаж, в который ведёт.

const DOOR_COLOR := Color(0.6, 0.6, 0.66)
const LOCKED_COLOR := Color(0.85, 0.45, 0.35)

var delta_y: float = 0.0
var target_floor: int = 0
var game: Node = null
var regen_chance: float = 0.0
var locked: bool = false
var unlocked: bool = false
var partner: Area2D = null

var _spr: Sprite2D
var _lt: PointLight2D

func _ready() -> void:
	var col := CollisionShape2D.new()
	var shape := CircleShape2D.new()
	shape.radius = 26.0
	col.shape = shape
	add_child(col)

	_spr = Sprite2D.new()
	add_child(_spr)

	_lt = PointLight2D.new()
	_lt.texture = MazeTextures.make_light(120)
	_lt.energy = 0.45
	_lt.shadow_enabled = false
	add_child(_lt)

	_refresh_visual()
	body_entered.connect(_on_body_entered)

func _refresh_visual() -> void:
	var c := LOCKED_COLOR if (locked and not unlocked) else DOOR_COLOR
	_spr.texture = MazeTextures.make_gem(16, c)
	_lt.color = c

func unlock() -> void:
	unlocked = true
	_refresh_visual()

func _on_body_entered(body: Node2D) -> void:
	if not (body.is_in_group("player") and body.teleport_cooldown <= 0.0):
		return

	if locked and not unlocked:
		if game and game.has_method("use_key") and game.use_key():
			unlock()
			if partner:
				partner.unlock()
		else:
			if game and game.has_method("flash_message"):
				game.flash_message("Заперто — нужен осколок-ключ")
			return

	body.global_position += Vector2(0, delta_y)
	body.current_floor = target_floor
	body.teleport_cooldown = 0.5
	if body.has_method("snap_camera"):
		body.snap_camera()

	# Эффект перехода между этажами: засветка экрана + портал в точке прибытия
	if game:
		if game.has_method("flash_screen"):
			game.flash_screen(Color(0.62, 0.82, 1.0), 0.32)
		_spawn_warp(body.global_position)

	if game and regen_chance > 0.0 and randf() < regen_chance:
		if game.has_method("regenerate_floor"):
			game.call_deferred("regenerate_floor", target_floor)

func _spawn_warp(pos: Vector2) -> void:
	if game == null:
		return
	var b := Node2D.new()
	b.set_script(load("res://burst.gd"))
	b.color = Color(0.6, 0.82, 1.0, 1.0)
	b.max_scale = 5.5
	b.light_energy = 2.2
	game.add_child(b)
	b.global_position = pos
