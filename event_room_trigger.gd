extends Area2D

# Контент событийных комнат (GAMEDESIGN.md §5). Сама комната-геометрия уже
# вырезана в сетке заранее (main.gd::_carve_event_room) — этот узел просто
# держит логику того, что случится при входе игрока в конкретную точку. kind:
#   "dark_trap"                  — свет гасится на 2 сек (можно переждать у
#                                   порога, не входя в саму зону триггера).
#   "choice_station"/"choice_exit" — два визуально одинаковых портала: один
#                                   ведёт к ближайшей станции, другой — к
#                                   порталу-выходу. Игрок не знает, какой есть какой.
#   "echo"                       — безопасно; разовый пинг-стрелка к выходу.
#   "parasite"                   — полный глоток Света, но враги этажа
#                                   ускоряются на время (главная сцена решает).

var game: Node = null
var kind: String = ""
var floor_index: int = 0
var _triggered: bool = false

var _spr: Sprite2D
var _lt: PointLight2D
var _anim: float = 0.0

func _ready() -> void:
	var col := CollisionShape2D.new()
	var shape := CircleShape2D.new()
	shape.radius = 34.0
	col.shape = shape
	add_child(col)

	var col_tint := _color_for(kind)
	_spr = Sprite2D.new()
	_spr.texture = MazeTextures.make_portal(18, col_tint)
	add_child(_spr)

	_lt = PointLight2D.new()
	_lt.texture = MazeTextures.make_light(140)
	_lt.color = col_tint
	_lt.energy = 0.8
	_lt.shadow_enabled = false
	add_child(_lt)

	body_entered.connect(_on_body_entered)

func _color_for(k: String) -> Color:
	match k:
		"dark_trap":
			return Color(0.85, 0.2, 0.2)
		"choice_station", "choice_exit":
			return Color(0.35, 0.6, 1.0)
		"echo":
			return Color(0.85, 0.85, 0.9)
		"parasite":
			return Color(0.65, 0.2, 0.85)
		_:
			return Color.WHITE

func _process(delta: float) -> void:
	_anim += delta
	if _spr:
		_spr.rotation += delta * 0.7
		_spr.scale = Vector2.ONE * (0.95 + 0.05 * sin(_anim * 2.2))
	if _lt:
		_lt.energy = 0.65 + 0.25 * sin(_anim * 2.2)

func _on_body_entered(body: Node) -> void:
	if _triggered or not body.is_in_group("player"):
		return
	_triggered = true
	match kind:
		"dark_trap":
			if body.has_method("apply_event"):
				body.apply_event("leak", 2.0)
		"choice_station":
			if game and game.has_method("event_room_teleport"):
				game.event_room_teleport(body, "station")
		"choice_exit":
			if game and game.has_method("event_room_teleport"):
				game.event_room_teleport(body, "exit")
		"echo":
			if game and game.has_method("event_room_echo_ping"):
				game.event_room_echo_ping(body)
		"parasite":
			if "energy" in body and "max_energy" in body:
				body.energy = body.max_energy
			if game and game.has_method("event_room_parasite_buff"):
				game.event_room_parasite_buff(floor_index)
