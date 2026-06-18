extends Area2D

# Подзарядная станция: зелёный маячок, восстанавливает свечение
# и служит точкой сохранения (чекпоинтом).

const STATION_COLOR := Color(0.25, 1.0, 0.55)

var game: Node = null      # ссылка на главную сцену
var floor_index: int = 0   # на каком этаже расположена станция

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
		if game and game.has_method("set_checkpoint"):
			game.set_checkpoint(floor_index, global_position)

func _on_body_exited(body: Node2D) -> void:
	if body.is_in_group("player"):
		body.charge_sources = maxi(0, body.charge_sources - 1)
