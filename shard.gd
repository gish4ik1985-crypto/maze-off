extends Area2D

# Осколок света: собираемый бонус. Даёт немного заряда и идёт в счётчик —
# поощряет исследование лабиринта.

const SHARD_COLOR := Color(1.0, 0.95, 0.55)
const ENERGY_BONUS := 0.25

var game: Node = null

func _ready() -> void:
	add_to_group("shard")

	var col := CollisionShape2D.new()
	var shape := CircleShape2D.new()
	shape.radius = 20.0
	col.shape = shape
	add_child(col)

	var spr := Sprite2D.new()
	spr.texture = MazeTextures.make_gem(11, SHARD_COLOR)
	add_child(spr)

	var lt := PointLight2D.new()
	lt.texture = MazeTextures.make_light(90)
	lt.color = SHARD_COLOR
	lt.energy = 0.5
	lt.shadow_enabled = false
	add_child(lt)

	body_entered.connect(_on_body_entered)

func _on_body_entered(body: Node2D) -> void:
	if body.is_in_group("player"):
		body.energy = minf(body.max_energy, body.energy + ENERGY_BONUS)
		if game and game.has_method("collect_shard"):
			game.collect_shard()
		queue_free()
