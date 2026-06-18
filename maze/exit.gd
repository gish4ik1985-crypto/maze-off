extends Area2D

# Выход из лабиринта: золотой маяк. При достижении игроком — победа.

const EXIT_COLOR := Color(1.0, 0.82, 0.25)

var game: Node = null

func _ready() -> void:
	var col := CollisionShape2D.new()
	var shape := CircleShape2D.new()
	shape.radius = 30.0
	col.shape = shape
	add_child(col)

	var spr := Sprite2D.new()
	spr.texture = MazeTextures.make_gem(20, EXIT_COLOR)
	add_child(spr)

	# Заметное золотое свечение, чтобы выход было видно издалека
	var lt := PointLight2D.new()
	lt.texture = MazeTextures.make_light(220)
	lt.color = EXIT_COLOR
	lt.energy = 1.25
	lt.shadow_enabled = true
	add_child(lt)

	body_entered.connect(_on_body_entered)

func _on_body_entered(body: Node2D) -> void:
	if body.is_in_group("player"):
		if game and game.has_method("on_player_win"):
			game.on_player_win()
