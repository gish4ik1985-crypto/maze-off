extends Area2D

# Портал между этажами. Открытый — фиолетовый крутящийся портал; запертый —
# тревожный янтарь (нужен собранный осколок-ключ). Переход ОДНОСТОРОННИЙ: после
# спуска на новый этаж порталы назад (на пройденные этажи) запечатываются.

const OPEN_COLOR := Color(0.66, 0.45, 1.0)    # открытый портал — фиолетовый
const LOCKED_COLOR := Color(1.0, 0.52, 0.32)  # запертый — янтарь

var delta_y: float = 0.0
var target_floor: int = 0
var game: Node = null
var regen_chance: float = 0.0
var locked: bool = false
var unlocked: bool = false
var partner: Area2D = null

var _spr: Sprite2D
var _lt: PointLight2D
var _anim: float = 0.0

func _ready() -> void:
	var col := CollisionShape2D.new()
	var shape := CircleShape2D.new()
	shape.radius = 26.0
	col.shape = shape
	add_child(col)

	_spr = Sprite2D.new()
	add_child(_spr)

	_lt = PointLight2D.new()
	_lt.texture = MazeTextures.make_light(150)
	_lt.energy = 0.5
	_lt.shadow_enabled = false
	add_child(_lt)

	_refresh_visual()
	body_entered.connect(_on_body_entered)

func _process(delta: float) -> void:
	# Медленное вращение + лёгкая пульсация — «живой» крутящийся портал.
	_anim += delta
	if _spr:
		_spr.rotation += delta * 0.9
		_spr.scale = Vector2.ONE * (0.95 + 0.05 * sin(_anim * 2.4))
	if _lt:
		_lt.energy = 0.5 + 0.18 * sin(_anim * 2.4)

func _refresh_visual() -> void:
	var c := LOCKED_COLOR if (locked and not unlocked) else OPEN_COLOR
	_spr.texture = MazeTextures.make_portal(18, c)
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
			if partner and is_instance_valid(partner):
				partner.unlock()
		else:
			if game and game.has_method("flash_message"):
				game.flash_message(GameConfig.tt("Заперто — нужен осколок-ключ", "Locked — a shard-key is needed"))
			return

	body.global_position += Vector2(0, delta_y)
	body.current_floor = target_floor
	body.teleport_cooldown = 0.5
	if body.has_method("snap_camera"):
		body.snap_camera()

	# Эффект перехода между этажами: засветка экрана + портал в точке прибытия
	if game:
		if game.has_method("flash_screen"):
			game.flash_screen(Color(0.72, 0.6, 1.0), 0.32)
		_spawn_warp(body.global_position)
		# Односторонний переход: запечатать порталы на пройденные (верхние) этажи.
		if game.has_method("seal_below"):
			game.call_deferred("seal_below", target_floor)

	if game and regen_chance > 0.0 and randf() < regen_chance:
		if game.has_method("regenerate_floor"):
			game.call_deferred("regenerate_floor", target_floor)

func _spawn_warp(pos: Vector2) -> void:
	if game == null:
		return
	var b := Node2D.new()
	b.set_script(load("res://burst.gd"))
	b.color = Color(0.72, 0.6, 1.0, 1.0)
	b.max_scale = 5.5
	b.light_energy = 2.2
	game.add_child(b)
	b.global_position = pos

# Плавно убрать портал — обратного пути на пройденный этаж больше нет.
func vanish() -> void:
	set_process(false)
	set_deferred("monitoring", false)
	if _spr == null:
		queue_free()
		return
	var t := create_tween()
	t.set_parallel(true)
	t.tween_property(_spr, "scale", Vector2.ZERO, 0.28).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_IN)
	if _lt:
		t.tween_property(_lt, "energy", 0.0, 0.28)
	t.set_parallel(false)
	t.tween_callback(queue_free)
