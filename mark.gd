extends Node2D

# [GAMEDESIGN §45, часть 2] Горящая метка — узел-визуал одной приколотой
# клетки. Сам не решает, сколько держится владение: раз в секунду зовёт
# game.place_mark's key через _claim(key) (main.gd), чтобы claim_strength
# для этой клетки не начинала стареть, пока метка жива. Сама гаснет в
# последней трети жизни, как маяк (beacon.gd) — тот же принцип effect-ноды,
# которая сама себя убирает.

const MARK_LIFE := 45.0
const MARK_COLOR := Color(1.0, 0.55, 0.15)

var game: Node = null
var mark_key: Vector3i = Vector3i.ZERO

var _life: float = MARK_LIFE
var _anim: float = 0.0
var _refresh_t: float = 0.0
var _lt: PointLight2D
var _spr: Sprite2D

func _ready() -> void:
	z_index = -4   # над следом захвата (-5), под игроком и объектами
	_spr = Sprite2D.new()
	_spr.texture = MazeTextures.make_beacon(10, MARK_COLOR)
	add_child(_spr)

	_lt = PointLight2D.new()
	_lt.texture = MazeTextures.make_light(110)
	_lt.color = MARK_COLOR
	_lt.energy = 0.9
	_lt.shadow_enabled = false
	add_child(_lt)

func _process(delta: float) -> void:
	_anim += delta
	_life -= delta
	if _life <= 0.0:
		queue_free()
		return

	_refresh_t -= delta
	if _refresh_t <= 0.0:
		_refresh_t = 1.0
		if game and is_instance_valid(game) and game.has_method("_claim"):
			game.call("_claim", mark_key)

	# Последняя треть жизни — тревожное затухание, как у маяка: игрок видит,
	# что метка вот-вот погаснет, а не узнаёт об этом постфактум.
	var fade: float = clampf(_life / (MARK_LIFE * 0.34), 0.0, 1.0)
	var pulse: float = 0.85 + 0.15 * sin(_anim * 2.4)
	if _lt:
		_lt.energy = 0.9 * pulse * fade
	if _spr:
		_spr.modulate.a = fade
		_spr.scale = Vector2.ONE * (0.95 + 0.06 * sin(_anim * 2.4))
