extends Area2D

# Выход из лабиринта: золотой маяк. При достижении игроком — победа.

const EXIT_COLOR := Color(1.0, 0.86, 0.30)

var game: Node = null

var _lt: PointLight2D
var _spr: Sprite2D
var _anim: float = 0.0

func _ready() -> void:
	var col := CollisionShape2D.new()
	var shape := CircleShape2D.new()
	shape.radius = 30.0
	col.shape = shape
	add_child(col)

	_spr = Sprite2D.new()
	_spr.texture = MazeTextures.make_gem(20, EXIT_COLOR)
	add_child(_spr)

	# Заметное золотое свечение, чтобы выход было видно издалека
	_lt = PointLight2D.new()
	_lt.texture = MazeTextures.make_light(240)
	_lt.color = EXIT_COLOR
	_lt.energy = 1.4
	_lt.shadow_enabled = true
	add_child(_lt)

	body_entered.connect(_on_body_entered)

func _process(delta: float) -> void:
	# Медленный «маяковый» пульс — выход манит издалека
	_anim += delta
	if _lt:
		_lt.energy = 1.25 + 0.35 * sin(_anim * 1.8)
	if _spr:
		_spr.scale = Vector2.ONE * (0.97 + 0.05 * sin(_anim * 1.8))

func _on_body_entered(body: Node2D) -> void:
	if body.is_in_group("player"):
		if game and game.has_method("on_player_win"):
			game.on_player_win()
