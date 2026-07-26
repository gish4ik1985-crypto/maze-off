extends Area2D

# «Гость лабиринта»: БЕГЛЕЦ (охота). Появляется на время, убегает от игрока
# по клеткам; не нападает. Успел догнать и ударить (вспышка/сонар/таран) —
# щедрая награда через game.guest_runner_caught(). Не успел — ускользает.

const SPEED := 235.0
const HINT_COLOR := Color(1.0, 0.8, 0.2)

var game: Node = null
var floor_index: int = 0
var life: float = 20.0

var stun_time: float = 0.0     # хронос/щит могут заморозить — честная добыча
var _cell: Vector2i = Vector2i.ZERO
var _move_target: Vector2 = Vector2.ZERO
var _has_target: bool = false
var _anim: float = 0.0
var _spr: Sprite2D
var _lt: PointLight2D
var _dying: bool = false

func _ready() -> void:
	add_to_group("enemy")   # чтобы вспышка/сонар (skill_hit_enemies) доставали его
	add_to_group("guest")
	var col := CollisionShape2D.new()
	var shape := CircleShape2D.new()
	shape.radius = 26.0
	col.shape = shape
	add_child(col)
	_spr = Sprite2D.new()
	_spr.texture = MazeTextures.make_runner_spark(15, HINT_COLOR)   # v1.9: комета-искра вместо гема — «бежит», не самоцвет
	add_child(_spr)
	_lt = PointLight2D.new()
	_lt.texture = MazeTextures.make_light(170)
	_lt.color = HINT_COLOR
	_lt.energy = 1.0
	_lt.shadow_enabled = false
	add_child(_lt)
	body_entered.connect(_on_body_entered)
	_cell = _my_cell()

func is_chasing() -> bool:
	return false   # не угроза: не поднимает музыку погони и Апекс

func distract_to(_c: Vector2i, _d: float) -> void:
	pass   # мираж на беглеца не действует

func _process(delta: float) -> void:
	_anim += delta
	life -= delta
	if life <= 0.0:
		_escape()
		return
	if stun_time > 0.0:
		stun_time -= delta
		if _spr:
			_spr.modulate = Color(0.6, 0.85, 1.0)
		return
	if _spr:
		_spr.modulate = Color.WHITE
		# Комета-искра (make_runner_spark) читается как «бежит» только если
		# голова смотрит по направлению движения — крутить её по кругу, как
		# раньше вращали гем, здесь смысла не имеет.
		var to_target: Vector2 = _move_target - global_position
		if to_target.length() > 1.0:
			_spr.rotation = to_target.angle()
		_spr.scale = Vector2.ONE * (1.0 + 0.1 * sin(_anim * 8.0))
	if _lt:
		var urgency: float = clampf(1.0 - life / 5.0, 0.0, 1.0)
		_lt.energy = 0.8 + 0.4 * sin(_anim * (4.0 + urgency * 6.0))
	_flee(delta)

# Побег: на каждом «перекрёстке» выбираем открытого соседа подальше от игрока.
func _flee(delta: float) -> void:
	if game == null or not is_instance_valid(game):
		return
	if not _has_target:
		var next := _pick_flee_cell()
		if next == _cell:
			return
		_cell = next
		_move_target = _cell_center(_cell)
		_has_target = true
	var to: Vector2 = _move_target - global_position
	var step: float = SPEED * delta
	if to.length() <= step:
		global_position = _move_target
		_has_target = false
	else:
		global_position += to.normalized() * step

func _pick_flee_cell() -> Vector2i:
	var p := _player_cell()
	var best := _cell
	var best_d := -1.0
	for n in _open_neighbors(_cell):
		var d: float = Vector2(n - p).length() + randf() * 0.8
		if d > best_d:
			best_d = d
			best = n
	return best

func _open_neighbors(c: Vector2i) -> Array:
	var out: Array = []
	var grid: Array = game._grids[floor_index]
	var cols: int = game._cols
	var rows: int = game._rows
	for d in [Vector2i(1, 0), Vector2i(-1, 0), Vector2i(0, 1), Vector2i(0, -1)]:
		var n: Vector2i = c + d
		if n.x < 0 or n.x >= cols or n.y < 0 or n.y >= rows:
			continue
		if not grid[c.y + n.y + 1][c.x + n.x + 1]:
			out.append(n)
	return out

func _cell_center(c: Vector2i) -> Vector2:
	var tile: float = game.TILE
	return Vector2((c.x * 2 + 1) * tile + tile * 0.5, (c.y * 2 + 1) * tile + tile * 0.5 + floor_index * game._floor_gap)

func _my_cell() -> Vector2i:
	var tile: float = game.TILE
	var local: Vector2 = global_position - Vector2(0, floor_index * game._floor_gap)
	return Vector2i(clampi(int(round((local.x / tile - 1.5) / 2.0)), 0, game._cols - 1),
		clampi(int(round((local.y / tile - 1.5) / 2.0)), 0, game._rows - 1))

func _player_cell() -> Vector2i:
	var pl := get_tree().get_nodes_in_group("player")
	if pl.is_empty():
		return _cell
	var tile: float = game.TILE
	var local: Vector2 = pl[0].global_position - Vector2(0, floor_index * game._floor_gap)
	return Vector2i(clampi(int(round((local.x / tile - 1.5) / 2.0)), 0, game._cols - 1),
		clampi(int(round((local.y / tile - 1.5) / 2.0)), 0, game._rows - 1))

# Любой урон = пойман (1 HP): вспышка, сонар, таран рывком.
func take_damage(_dmg: int, _source: String = "") -> bool:
	if _dying:
		return false
	_dying = true
	_burst(HINT_COLOR, 4.0)
	if game and is_instance_valid(game) and game.has_method("guest_runner_caught"):
		game.guest_runner_caught(global_position)
	queue_free()
	return true

func _on_body_entered(body: Node2D) -> void:
	# Таран рывком: контакт во время рывка = пойман.
	if body.is_in_group("player") and body.has_method("is_dashing") and body.is_dashing():
		take_damage(1, "dash")

func _escape() -> void:
	if _dying:
		return
	_dying = true
	_burst(Color(HINT_COLOR.r, HINT_COLOR.g, HINT_COLOR.b, 0.4), 2.2)
	if game and is_instance_valid(game) and game.has_method("guest_runner_escaped"):
		game.guest_runner_escaped()
	queue_free()

func _burst(col: Color, sc: float) -> void:
	var p := get_parent()
	if p == null:
		return
	var b := Node2D.new()
	b.set_script(load("res://burst.gd"))
	b.color = col
	b.max_scale = sc
	b.dur = 0.5
	p.add_child(b)
	b.global_position = global_position
