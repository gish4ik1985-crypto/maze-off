extends Area2D

# Дверь к боссу: НЕОБЯЗАТЕЛЬНЫЙ багровый портал с черепом. Появляется на
# уровнях, кратных 5. Хочешь испытание и дар босса — заходи; нет — проходи
# уровень как обычно. Ведёт на отдельную арену (скрытый этаж, см. main.gd).

var game: Node = null

var _spr: Sprite2D
var _lt: PointLight2D
var _anim: float = 0.0

func _ready() -> void:
	var col := CollisionShape2D.new()
	var shape := CircleShape2D.new()
	shape.radius = 26.0
	col.shape = shape
	add_child(col)

	# Багровый портал — отличается от синих межэтажных дверей и цветом, и черепом.
	_spr = Sprite2D.new()
	_spr.texture = MazeTextures.make_portal(20, Color(1.0, 0.22, 0.2))
	add_child(_spr)

	var skull := Label.new()
	skull.text = "☠"
	skull.add_theme_font_size_override("font_size", 26)
	skull.add_theme_color_override("font_color", Color(1.0, 0.75, 0.7))
	skull.position = Vector2(-13, -60)
	add_child(skull)

	_lt = PointLight2D.new()
	_lt.texture = MazeTextures.make_light(170)
	_lt.color = Color(1.0, 0.25, 0.2)
	_lt.energy = 0.9
	_lt.shadow_enabled = false
	add_child(_lt)

	body_entered.connect(_on_body_entered)

func _process(delta: float) -> void:
	_anim += delta
	if _spr:
		_spr.rotation = _anim * 0.9
	if _lt:
		_lt.energy = 0.75 + 0.3 * sin(_anim * 3.0)

func _on_body_entered(body: Node2D) -> void:
	if not body.is_in_group("player"):
		return
	if body.teleport_cooldown > 0.0:
		return
	if game and game.has_method("enter_boss_arena"):
		# [v5.7, Godot 4.7] арена строится (Area2D, коллизии) — не из физического колбэка
		game.call_deferred("enter_boss_arena")
