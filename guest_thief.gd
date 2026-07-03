extends Area2D

# «Гость лабиринта»: ВОР. Быстрый и безвредный: подкрадывается к игроку,
# касанием крадёт часть несомого Накала (в «Уровнях» — глоток света) и
# убегает. Догони и ударь — вернёт украденное с процентами. Упустил — пропало.

const SPEED_HUNT := 250.0
const SPEED_FLEE := 300.0
const COLOR := Color(0.7, 0.4, 1.0)

var game: Node = null
var floor_index: int = 0
var life: float = 14.0        # после кражи — время на побег

var stun_time: float = 0.0
var _cell: Vector2i = Vector2i.ZERO
var _move_target: Vector2 = Vector2.ZERO
var _has_target: bool = false
var _fleeing: bool = false
var _loot: Dictionary = {}    # что украл: {"ember": float} или {"light": float}
var _anim: float = 0.0
var _spr: Sprite2D
var _lt: PointLight2D
var _dying: bool = false

func _ready() -> void:
	add_to_group("enemy")   # вспышка/сонар достают его
	add_to_group("guest")
	var col := CollisionShape2D.new()
	var shape := CircleShape2D.new()
	shape.radius = 30.0
	col.shape = shape
	add_child(col)
	_spr = Sprite2D.new()
	_spr.texture = MazeTextures.make_gem(15, COLOR)
	add_child(_spr)
	_lt = PointLight2D.new()
	_lt.texture = MazeTextures.make_light(160)
	_lt.color = COLOR
	_lt.energy = 0.9
	_lt.shadow_enabled = false
	add_child(_lt)
	body_entered.connect(_on_body_entered)
	_cell = _my_cell()

func is_chasing() -> bool:
	return false

func distract_to(_c: Vector2i, _d: float) -> void:
	pass

func _process(delta: float) -> void:
	_anim += delta
	if _fleeing:
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
		_spr.rotation = _anim * (6.0 if _fleeing else 2.5)
	if _lt:
		_lt.energy = 0.75 + 0.3 * sin(_anim * 6.0)
	_move(delta)

func _move(delta: float) -> void:
	if game == null or not is_instance_valid(game):
		return
	if not _has_target:
		var next := _pick_cell()
		if next == _cell:
			return
		_cell = next
		_move_target = _cell_center(_cell)
		_has_target = true
	var to: Vector2 = _move_target - global_position
	var step: float = (SPEED_FLEE if _fleeing else SPEED_HUNT) * delta
	if to.length() <= step:
		global_position = _move_target
		_has_target = false
	else:
		global_position += to.normalized() * step

# До кражи — к игроку (жадный шаг), после — от игрока.
func _pick_cell() -> Vector2i:
	var p := _player_cell()
	var best := _cell
	var best_d: float = -1.0 if _fleeing else 1e9
	for n in _open_neighbors(_cell):
		var d: float = Vector2(n - p).length() + randf() * 0.6
		if _fleeing:
			if d > best_d:
				best_d = d
				best = n
		else:
			if d < best_d:
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

func _on_body_entered(body: Node2D) -> void:
	if not body.is_in_group("player"):
		return
	# Таран рывком защищает: вор пойман до кражи.
	if body.has_method("is_dashing") and body.is_dashing():
		take_damage(1, "dash")
		return
	if _fleeing:
		return
	# Кража: часть несомого Накала (или глоток света в «Уровнях») — и дёру.
	if game and is_instance_valid(game) and game.has_method("guest_thief_steal"):
		_loot = game.guest_thief_steal()
	_fleeing = true
	_burst(COLOR, 2.4)

func take_damage(_dmg: int, _source: String = "") -> bool:
	if _dying:
		return false
	_dying = true
	_burst(COLOR, 4.0)
	if game and is_instance_valid(game) and game.has_method("guest_thief_killed"):
		game.guest_thief_killed(_loot, global_position)
	queue_free()
	return true

func _escape() -> void:
	if _dying:
		return
	_dying = true
	_burst(Color(COLOR.r, COLOR.g, COLOR.b, 0.4), 2.0)
	if game and is_instance_valid(game) and game.has_method("guest_thief_escaped"):
		game.guest_thief_escaped(_loot)
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
