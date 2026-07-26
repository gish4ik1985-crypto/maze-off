extends Area2D

# Осколок света: собираемый бонус (v1.9 — «кристалл-ключ»). Даёт немного
# заряда и идёт в счётчик; цвет намеренно совпадает с цветом запертых дверей
# (door.gd:LOCKED_COLOR) — осколок И ЕСТЬ ключ, а не просто бонус, поэтому
# кристалл несёт «ушко»-кольцо сверху, как у настоящего ключа.

const SHARD_COLOR := Color(1.0, 0.55, 0.30)   # резонирует с door.gd:LOCKED_COLOR
const ENERGY_BONUS := 0.25

var game: Node = null

var _lt: PointLight2D
var _spr: Sprite2D
var _anim: float = 0.0

func _ready() -> void:
	add_to_group("shard")

	var col := CollisionShape2D.new()
	var shape := CircleShape2D.new()
	shape.radius = 20.0
	col.shape = shape
	add_child(col)

	_spr = Sprite2D.new()
	_spr.texture = MazeTextures.make_key_crystal(11, SHARD_COLOR)
	add_child(_spr)

	_lt = PointLight2D.new()
	_lt.texture = MazeTextures.make_light(110)
	_lt.color = SHARD_COLOR
	_lt.energy = 0.65
	_lt.shadow_enabled = false
	add_child(_lt)

	body_entered.connect(_on_body_entered)

func _process(delta: float) -> void:
	# Мягкое мерцание + лёгкое вращение — осколок «живой»
	_anim += delta
	if _lt:
		_lt.energy = 0.55 + 0.2 * sin(_anim * 3.2)
	if _spr:
		_spr.scale = Vector2.ONE * (0.94 + 0.07 * sin(_anim * 3.2))

func _on_body_entered(body: Node2D) -> void:
	if body.is_in_group("player"):
		body.energy = minf(body.max_energy, body.energy + ENERGY_BONUS)
		if game and game.has_method("collect_shard"):
			game.collect_shard(global_position)   # позиция нужна для «эха» осколка
		_spawn_pickup_fx()
		queue_free()

# Сочный отклик на месте осколка: золотое кольцо + фонтанчик искр.
func _spawn_pickup_fx() -> void:
	var p := get_parent()
	if p == null:
		return
	var b := Node2D.new()
	b.set_script(load("res://burst.gd"))
	b.color = Color(1.0, 0.85, 0.42, 1.0)
	b.max_scale = 3.2
	b.dur = 0.4
	b.light_energy = 1.5
	p.add_child(b)
	b.global_position = global_position
	var sp := CPUParticles2D.new()
	sp.set_script(load("res://sparkle.gd"))
	sp.spark_color = Color(1.0, 0.88, 0.5)
	sp.spark_amount = 18
	sp.spark_speed = 175.0
	p.add_child(sp)
	sp.global_position = global_position
