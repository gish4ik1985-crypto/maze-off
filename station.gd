extends Area2D

# Подзарядная станция: зелёный маячок, восстанавливает свечение
# и служит точкой сохранения (чекпоинтом).

const STATION_COLOR := Color(0.25, 1.0, 0.55)

var game: Node = null      # ссылка на главную сцену
var floor_index: int = 0   # на каком этаже расположена станция
var _visited: bool = false # за первое посещение начисляется бонус XP
var _xp_tick: float = 0.0  # счётчик XP-потока пока игрок на станции
var _player_on: Node2D = null

func _ready() -> void:
	add_to_group("station")

	var col := CollisionShape2D.new()
	var shape := CircleShape2D.new()
	shape.radius = 44.0
	col.shape = shape
	add_child(col)

	var spr := Sprite2D.new()
	spr.texture = MazeTextures.make_gem(15, STATION_COLOR)
	add_child(spr)

	var lt := PointLight2D.new()
	lt.texture = MazeTextures.make_light(110)
	lt.color = STATION_COLOR
	lt.energy = 0.5
	# Без теней: множество станций с тенями превышает лимит источников
	# в GL Compatibility и свет начинает мерцать/пропадать.
	lt.shadow_enabled = false
	add_child(lt)

	body_entered.connect(_on_body_entered)
	body_exited.connect(_on_body_exited)

func _on_body_entered(body: Node2D) -> void:
	if body.is_in_group("player"):
		body.charge_sources += 1
		_player_on = body
		if game and game.has_method("set_checkpoint"):
			game.set_checkpoint(floor_index, global_position)
		# Первое посещение этой станции в текущем уровне — бонус 50 XP
		if not _visited:
			_visited = true
			GameConfig.add_xp(50)

func _on_body_exited(body: Node2D) -> void:
	if body.is_in_group("player"):
		body.charge_sources = maxi(0, body.charge_sources - 1)
		if _player_on == body:
			_player_on = null

func _process(delta: float) -> void:
	# Поток XP пока игрок заряжается на станции: 5 XP в секунду
	if _player_on != null and is_instance_valid(_player_on):
		_xp_tick += delta
		if _xp_tick >= 0.2:
			GameConfig.add_xp(int(_xp_tick * 5.0))
			_xp_tick = 0.0
