extends StaticBody2D

# Яма-провал (GAMEDESIGN.md §17.5) — новый тип клетки: не стена и не обычный
# проход. Физически блокирует игрока, как стена (тот же физ-слой), НО пока
# игрок в её радиусе и активно рывком (Shift) — коллизия временно снята,
# и рывок проносит его через дыру насквозь. Вне рывка — только обход.
# Враги (pursuer.gd) по сетке всё равно ходят «через» эту клетку логически
# (BFS не знает про ямы) — это осознанное упрощение первой версии, важен сам
# факт нового правила для игрока, а не полноценная физика для всех акторов.

const RADIUS := 30.0
const NEAR_RADIUS := 90.0   # снимаем коллизию чуть заранее — рывок быстрый, точный edge-frame ненадёжен

var game: Node = null
var floor_index: int = 0

var _col: CollisionShape2D
var _spr: Sprite2D
var _rim: Sprite2D
var _anim: float = 0.0
var _player: Node2D = null

func _ready() -> void:
	add_to_group("pit")
	collision_layer = 1   # тот же слой, что у стен — блокирует игрока по умолчанию
	collision_mask = 0

	var shape := CircleShape2D.new()
	shape.radius = RADIUS
	_col = CollisionShape2D.new()
	_col.shape = shape
	add_child(_col)

	_spr = Sprite2D.new()
	_spr.texture = MazeTextures.make_light(int(RADIUS * 2.6))
	_spr.modulate = Color(0.02, 0.01, 0.02, 0.92)   # тёмная воронка — «дыра» в полу
	add_child(_spr)

	_rim = Sprite2D.new()
	_rim.texture = MazeTextures.make_ring(int(RADIUS * 2.2))
	_rim.modulate = Color(1.0, 0.35, 0.25, 0.8)   # тревожный красный ободок — виден издалека
	add_child(_rim)

func _physics_process(_delta: float) -> void:
	if _player == null or not is_instance_valid(_player):
		var pl := get_tree().get_nodes_in_group("player")
		_player = pl[0] if pl.size() > 0 else null
	if _player == null:
		return
	var near: bool = global_position.distance_to(_player.global_position) <= NEAR_RADIUS
	var dashing: bool = near and _player.has_method("is_dashing") and _player.is_dashing()
	_col.disabled = dashing

func _process(delta: float) -> void:
	_anim += delta
	if _rim:
		_rim.rotation += delta * 0.5
		_rim.modulate.a = 0.6 + 0.2 * sin(_anim * 2.0)
