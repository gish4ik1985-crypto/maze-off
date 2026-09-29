extends Area2D

# Реликвия (GAMEDESIGN §77, v5.7): навык кампании лежит в лабиринте и
# открывается находкой, а не покупкой. Золотой столп света с иконкой навыка над
# пьедесталом — виден издалека сквозь тьму (тот же приём, что у залов-
# ориентиров, §40), а иконка говорит, ЧТО именно лежит. Подобрать может любой
# игрок, дошедший до тупика; пропустил — main.gd выдаст навык у выхода
# (`_grant_missed_relic`), так что застрять без навыка нельзя.

var game: Node = null
var skill: String = ""

var _t: float = 0.0
var _icon: Sprite2D
var _halo: Sprite2D
var _lt: PointLight2D
var _taken: bool = false

func _ready() -> void:
	add_to_group("relic")
	var col: Color = SkillIcons.color_of(skill)
	# Золото поверх цвета навыка: реликвию нельзя спутать с осколком/маяком.
	var gold := Color(1.0, 0.86, 0.45)
	var tint := gold.lerp(col, 0.35)

	var cs := CollisionShape2D.new()
	var shape := CircleShape2D.new()
	shape.radius = 30.0
	cs.shape = shape
	add_child(cs)

	_halo = Sprite2D.new()
	_halo.texture = MazeTextures.make_light(260)
	_halo.modulate = Color(tint.r, tint.g, tint.b, 0.55)
	add_child(_halo)

	# Вытянутый столп: силуэт, отличимый от круглых огней игрока и станций.
	var pillar := Sprite2D.new()
	pillar.texture = MazeTextures.make_light(110)
	pillar.scale = Vector2(0.45, 3.0)
	pillar.position = Vector2(0, -60)
	pillar.modulate = Color(tint.r, tint.g, tint.b, 0.35)
	add_child(pillar)

	_icon = Sprite2D.new()
	_icon.texture = SkillIcons.make_hd(skill, 56)
	_icon.scale = Vector2(0.9, 0.9)
	_icon.position = Vector2(0, -16)
	add_child(_icon)

	_lt = PointLight2D.new()
	_lt.texture = MazeTextures.make_light(240)
	_lt.color = tint
	_lt.energy = 1.8
	_lt.shadow_enabled = false
	add_child(_lt)

	body_entered.connect(_on_body_entered)

func _process(delta: float) -> void:
	_t += delta
	if _icon:
		_icon.position.y = -16.0 + sin(_t * 2.2) * 5.0
		_icon.rotation = sin(_t * 1.1) * 0.12
	if _halo:
		_halo.scale = Vector2.ONE * (1.0 + 0.06 * sin(_t * 2.6))
	if _lt:
		_lt.energy = 1.6 + 0.35 * sin(_t * 3.0)

func _on_body_entered(body: Node2D) -> void:
	if _taken or not body.is_in_group("player"):
		return
	_taken = true
	if game and game.has_method("relic_claimed"):
		game.relic_claimed(skill, true)
	queue_free()
