extends Area2D

# [GAMEDESIGN §59, П7] Тлеющий очаг — симметричная награда к Соглядатаю
# (§57): появляется на клетке, которую игрок держит своей необычно долго,
# не отпуская (main.gd::ground_devotion). Разовый подарок — капля Воли —
# и исчезает. Тот же вид effect-ноды, что маяк (beacon.gd), только тёплый
# и благосклонный, а не срочный.

const HEARTH_LIFE := 60.0       # щедрое окно — клетка и так рядом с игроком
const HEARTH_WILL_GIFT := 0.20  # капля Воли, сравнимая с ценой одного каста
const COLOR := Color(1.0, 0.72, 0.35)

var game: Node = null
var floor_index: int = 0

var _lt: PointLight2D
var _spr: Sprite2D
var _anim: float = 0.0
var _life: float = HEARTH_LIFE

func _ready() -> void:
	add_to_group("hearth")

	var col := CollisionShape2D.new()
	var shape := CircleShape2D.new()
	shape.radius = 22.0
	col.shape = shape
	add_child(col)

	_spr = Sprite2D.new()
	_spr.texture = MazeTextures.make_beacon(14, COLOR)
	add_child(_spr)

	_lt = PointLight2D.new()
	_lt.texture = MazeTextures.make_light(150)
	_lt.color = COLOR
	_lt.energy = 1.0
	_lt.shadow_enabled = false
	add_child(_lt)

	body_entered.connect(_on_body_entered)

func _process(delta: float) -> void:
	_anim += delta
	_life -= delta
	if _life <= 0.0:
		_spawn_fade_fx()
		queue_free()
		return
	# Дыхание — медленное и ровное, не тревожное: это подарок, не таймер.
	var pulse: float = 0.85 + 0.15 * sin(_anim * 1.6)
	if _lt:
		_lt.energy = pulse
	if _spr:
		_spr.scale = Vector2.ONE * (0.95 + 0.05 * sin(_anim * 1.6))

func _on_body_entered(body: Node2D) -> void:
	if not body.is_in_group("player"):
		return
	if body.has_method("add_will"):
		body.add_will(HEARTH_WILL_GIFT)
	if game and game.has_method("hearth_reward"):
		game.hearth_reward()
	_spawn_reach_fx()
	queue_free()

func _spawn_reach_fx() -> void:
	var p := get_parent()
	if p == null:
		return
	var b := Node2D.new()
	b.set_script(load("res://burst.gd"))
	b.color = COLOR
	b.max_scale = 3.6
	b.dur = 0.5
	b.light_energy = 1.6
	p.add_child(b)
	b.global_position = global_position
	var sp := CPUParticles2D.new()
	sp.set_script(load("res://sparkle.gd"))
	sp.spark_color = COLOR
	sp.spark_amount = 18
	sp.spark_speed = 160.0
	p.add_child(sp)
	sp.global_position = global_position

func _spawn_fade_fx() -> void:
	var p := get_parent()
	if p == null:
		return
	var b := Node2D.new()
	b.set_script(load("res://burst.gd"))
	b.color = Color(COLOR.r, COLOR.g, COLOR.b, 0.35)
	b.max_scale = 2.0
	b.dur = 0.5
	p.add_child(b)
	b.global_position = global_position
