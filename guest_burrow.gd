extends Node2D

# «Гость лабиринта»: НОРА КРОТА. Живёт на клетке-проходе. Цикл: затишье →
# крот высовывается (предупреждение, свечение) → клетка блокируется земляной
# кучей на несколько секунд (настоящая стена через game._set_wall) → снова
# открыта. Стоишь над норой в момент выхода — получаешь урон по свету.
# Превращает участок лабиринта в мини-игру на тайминг.

const WARN_TIME := 1.1
const BLOCK_TIME := 6.0
const POP_DAMAGE := 0.16
const COLOR := Color(0.85, 0.6, 0.3)

var game: Node = null
var floor_index: int = 0
var cell: Vector2i = Vector2i.ZERO
var life: float = 30.0

# Фазы: 0 затишье / 1 крот высунулся / 2 клетка заблокирована
var _phase: int = 0
var _t: float = 0.0
var _anim: float = 0.0
var _spr: Sprite2D
var _lt: PointLight2D
var _blocked: bool = false

func _ready() -> void:
	add_to_group("guest")
	_t = randf_range(1.0, 4.0)   # норы просыпаются вразнобой
	_spr = Sprite2D.new()
	_spr.texture = MazeTextures.make_gem(13, COLOR)
	_spr.modulate = Color(COLOR.r, COLOR.g, COLOR.b, 0.45)   # едва заметный холмик
	add_child(_spr)
	_lt = PointLight2D.new()
	_lt.texture = MazeTextures.make_light(150)
	_lt.color = COLOR
	_lt.energy = 0.0
	_lt.shadow_enabled = false
	add_child(_lt)
	tree_exiting.connect(_unblock)   # никогда не оставляем стену после себя

func _process(delta: float) -> void:
	_anim += delta
	life -= delta
	if life <= 0.0 and _phase != 2:
		_burst(Color(COLOR.r, COLOR.g, COLOR.b, 0.4), 1.8)
		queue_free()
		return
	_t -= delta
	match _phase:
		0:   # затишье: холмик еле дышит
			if _spr:
				_spr.scale = Vector2.ONE * (0.8 + 0.06 * sin(_anim * 2.0))
			if _t <= 0.0:
				_phase = 1
				_t = WARN_TIME
		1:   # крот высунулся: тревожное свечение — уйди с клетки!
			if _spr:
				_spr.scale = Vector2.ONE * (1.1 + 0.2 * sin(_anim * 14.0))
				_spr.modulate = COLOR
			if _lt:
				_lt.energy = 0.9 + 0.5 * sin(_anim * 14.0)
			if _t <= 0.0:
				_pop()
		2:   # клетка заблокирована земляной кучей
			if _lt:
				_lt.energy = maxf(0.0, _lt.energy - delta)
			if _t <= 0.0:
				_unblock()
				_phase = 0
				_t = randf_range(3.5, 7.0)
				if _spr:
					_spr.modulate = Color(COLOR.r, COLOR.g, COLOR.b, 0.45)

# Момент выхода крота: удар по стоящему на клетке + блок (если клетка свободна).
func _pop() -> void:
	_burst(COLOR, 2.6)
	var on_cell := _node_on_cell()
	if on_cell != null and on_cell.is_in_group("player"):
		if on_cell.has_method("hit_by_enemy"):
			on_cell.hit_by_enemy(POP_DAMAGE)
		# Игрока не замуровываем — крот укусил и спрятался.
		_phase = 0
		_t = randf_range(3.5, 7.0)
		return
	if on_cell != null:
		# На клетке враг — не замуровываем его в стене, крот пережидает.
		_phase = 0
		_t = randf_range(2.0, 4.0)
		return
	if game and is_instance_valid(game):
		game._set_wall(floor_index, cell.x * 2 + 1, cell.y * 2 + 1, true)
		_blocked = true
	_phase = 2
	_t = BLOCK_TIME

func _unblock() -> void:
	if _blocked and game and is_instance_valid(game):
		game._set_wall(floor_index, cell.x * 2 + 1, cell.y * 2 + 1, false)
	_blocked = false

# Кто стоит на клетке норы (игрок или враг этого этажа)?
func _node_on_cell() -> Node2D:
	var r: float = game.TILE * 0.75 if game else 90.0
	for grp in ["player", "enemy"]:
		for n in get_tree().get_nodes_in_group(grp):
			if is_instance_valid(n) and n.global_position.distance_to(global_position) < r:
				return n
	return null

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
