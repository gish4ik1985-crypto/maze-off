extends Area2D

# Портал между этажами. Открытый — фиолетовый крутящийся портал; запертый —
# тревожный янтарь (нужен собранный осколок-ключ). Переход ОДНОСТОРОННИЙ: после
# спуска на новый этаж порталы назад (на пройденные этажи) запечатываются.

const OPEN_COLOR := Color(0.66, 0.45, 1.0)    # открытый портал — фиолетовый
const LOCKED_COLOR := Color(1.0, 0.55, 0.30)  # запертый — тот же цвет, что у осколка-ключа (shard.gd:SHARD_COLOR)

var delta_y: float = 0.0
var target_floor: int = 0
var game: Node = null
var regen_chance: float = 0.0
var locked: bool = false
var unlocked: bool = false
var partner: Area2D = null

var _spr: Sprite2D
var _lock_spr: Sprite2D
var _lt: PointLight2D
var _anim: float = 0.0

func _ready() -> void:
	# [§43] Группа нужна не игре, а проверяемости: без неё харнесс «показывает
	# ли запертая дверь замок» молча проходил вхолостую — искать двери было не
	# по чему. Станции и осколки в группах с самого начала.
	add_to_group("door")
	var col := CollisionShape2D.new()
	var shape := CircleShape2D.new()
	shape.radius = 26.0
	col.shape = shape
	add_child(col)

	_spr = Sprite2D.new()
	add_child(_spr)

	# [§43] Глиф замка поверх портала. До этого запертая дверь была просто
	# янтарным кружком — того же цвета, что осколок-ключ, — и игрок принимал её
	# за предмет, который почему-то нельзя подобрать (жалоба со скриншотом).
	# Замок мгновенно говорит «это дверь, и она закрыта».
	_lock_spr = Sprite2D.new()
	_lock_spr.texture = MazeTextures.make_lock(40, Color(1.0, 0.86, 0.55))
	_lock_spr.scale = Vector2.ONE * 0.55
	_lock_spr.position = Vector2(0, -2)
	_lock_spr.visible = false
	add_child(_lock_spr)

	_lt = PointLight2D.new()
	_lt.texture = MazeTextures.make_light(150)
	_lt.energy = 0.5
	_lt.shadow_enabled = false
	add_child(_lt)

	_refresh_visual()
	body_entered.connect(_on_body_entered)

func _process(delta: float) -> void:
	# [DOOR-RETRIGGER 2026-07-30] Area2D шлёт body_entered ТОЛЬКО в момент входа.
	# Если игрок вошёл в портал, пока тикал teleport_cooldown (или был заперт и
	# без ключа, или стоит на портале с самого спавна), сигнала больше не будет —
	# портал «не срабатывает», пока не отойдёшь и не вернёшься (жалоба 30.07.2026
	# «иногда не срабатывает этот кружок»). Дожимаем перекрытием.
	if monitoring:
		for b in get_overlapping_bodies():
			if b.is_in_group("player") and b.teleport_cooldown <= 0.0:
				_on_body_entered(b)
				break
	# Медленное вращение + лёгкая пульсация — «живой» крутящийся портал.
	_anim += delta
	if _spr:
		_spr.rotation += delta * 0.9
	if _lock_spr and _lock_spr.visible:
		# Замок НЕ крутится вместе с порталом: вращающийся символ читается как
		# часть вихря. Только лёгкое «дыхание», чтобы не выглядел наклейкой.
		_lock_spr.scale = Vector2.ONE * (0.55 + 0.04 * sin(_anim * 2.0))
		_spr.scale = Vector2.ONE * (0.95 + 0.05 * sin(_anim * 2.4))
	if _lt:
		var e := 0.5 + 0.18 * sin(_anim * 2.4)
		# Заперта и есть осколок-ключ наготове — дверь «зовёт» ярче.
		if locked and not unlocked and game and game.has_method("has_key"):
			e *= 1.6 if game.has_key() else 0.5
		_lt.energy = e

func _refresh_visual() -> void:
	var is_locked: bool = locked and not unlocked
	var c := LOCKED_COLOR if is_locked else OPEN_COLOR
	_spr.texture = MazeTextures.make_portal(18, c)
	_lt.color = c
	if _lock_spr:
		_lock_spr.visible = is_locked

func unlock() -> void:
	unlocked = true
	_refresh_visual()

func _on_body_entered(body: Node2D) -> void:
	if not (body.is_in_group("player") and body.teleport_cooldown <= 0.0):
		return
	# [v5.7, Godot 4.7] Этаж назначения строится лениво (создаёт Area2D-станции и
	# осколки), а body_entered приходит из физического запроса — в 4.7 нельзя
	# менять состояние физики «пока идёт сброс запросов». Поэтому сам переход
	# откладываем на конец кадра; кулдаун ставим сразу, чтобы не сработать дважды.
	body.teleport_cooldown = 0.5
	_enter.call_deferred(body)

func _enter(body: Node2D) -> void:
	if not is_instance_valid(body):
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

	if game and game.has_method("_ensure_floor_built"):
		game._ensure_floor_built(target_floor)
	body.global_position += Vector2(0, delta_y)
	body.current_floor = target_floor
	# [SPAWN-SAFETY 2026-07-30] Перенос «на ту же клетку этажом ниже» верен,
	# только если у этажей одна планировка. На уровне 50 этаж-арена меньше
	# овального этажа 0 и добит стенами — без проверки игрок оказывался внутри
	# монолита (чернота, ни стен, ни выхода).
	if game and game.has_method("validate_arrival"):
		game.validate_arrival(body, target_floor)
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
