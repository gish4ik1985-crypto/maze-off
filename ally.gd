extends CharacterBody2D

# Союзник-«отражение» (GAMEDESIGN.md §25, шаг 4 — ФУНДАМЕНТ, БЕЗ окна
# навыков призыва ещё). Призывается временно, следует за игроком и сам
# атакует ближайшего врага в радиусе короткими импульсами урона (та же
# area-система, что у активных навыков — main.gd::skill_hit_enemies).
# Хрупкий: несколько попаданий от врагов — и гаснет раньше срока.
#
# Визуал — тот же спрайт, что у игрока (make_player_orb), но тонирован в
# отличимый цвет + тонкое кольцо-ореол сверху (make_ring) — читается как
# «зеркало игрока», не как случайный новый объект.

const FOLLOW_DIST := 70.0
const FOLLOW_SPEED := 260.0
const ATTACK_RANGE := 160.0
const ATTACK_RADIUS := 60.0
const ATTACK_DMG := 1
const ATTACK_COOLDOWN := 1.1
const MAX_HP := 3
const LIFE := 25.0
const TINT := Color(0.55, 1.0, 0.65)   # зелёно-золотой — не спутать с самим игроком (бело-голубой)

var game: Node = null
var player: Node = null

var _hp: int = MAX_HP
var _life: float = LIFE
var _attack_cd: float = 0.0
var _anim: float = 0.0

var _spr: Sprite2D
var _ring: Sprite2D
var _lt: PointLight2D

func _ready() -> void:
	add_to_group("ally")
	collision_layer = 0
	collision_mask = 1   # только стены — с игроком/врагами физически не толкается
	var col := CollisionShape2D.new()
	var shape := CircleShape2D.new()
	shape.radius = 16.0
	col.shape = shape
	add_child(col)

	_spr = Sprite2D.new()
	_spr.texture = MazeTextures.make_player_orb(14)
	_spr.modulate = TINT
	add_child(_spr)

	_ring = Sprite2D.new()
	_ring.texture = MazeTextures.make_ring(50)
	_ring.modulate = Color(TINT.r, TINT.g, TINT.b, 0.7)
	add_child(_ring)

	_lt = PointLight2D.new()
	_lt.texture = MazeTextures.make_light(140)
	_lt.color = TINT
	_lt.energy = 0.9
	_lt.shadow_enabled = false
	add_child(_lt)

func _process(delta: float) -> void:
	_anim += delta
	_life -= delta
	if _life <= 0.0:
		_fade_out()
		return
	if _attack_cd > 0.0:
		_attack_cd -= delta
	_ring.rotation += delta * 1.6
	var urgency: float = clampf(1.0 - _life / 4.0, 0.0, 1.0)   # мигает чаще перед исчезновением
	_lt.energy = (0.75 + 0.25 * sin(_anim * (3.0 + urgency * 6.0)))
	_spr.scale = Vector2.ONE * (1.0 + 0.06 * sin(_anim * 3.0))
	_try_attack()

func _physics_process(_delta: float) -> void:
	if player == null or not is_instance_valid(player):
		velocity = Vector2.ZERO
		move_and_slide()
		return
	var to_player: Vector2 = player.global_position - global_position
	if to_player.length() > FOLLOW_DIST:
		velocity = to_player.normalized() * FOLLOW_SPEED
	else:
		velocity = Vector2.ZERO
	move_and_slide()

func _try_attack() -> void:
	if _attack_cd > 0.0 or game == null or not is_instance_valid(game):
		return
	var target := _nearest_enemy()
	if target == null:
		return
	_attack_cd = ATTACK_COOLDOWN
	if game.has_method("skill_hit_enemies"):
		game.skill_hit_enemies(global_position, ATTACK_RADIUS, ATTACK_DMG, "ally")
	var b := Node2D.new()
	b.set_script(load("res://burst.gd"))
	b.color = Color(TINT.r, TINT.g, TINT.b, 1.0)
	b.max_scale = 4.0
	b.dur = 0.3
	get_parent().add_child(b)
	b.global_position = global_position

func _nearest_enemy() -> Node:
	var best: Node = null
	var best_d := ATTACK_RANGE
	for e in get_tree().get_nodes_in_group("enemy"):
		if not is_instance_valid(e):
			continue
		var d: float = global_position.distance_to(e.global_position)
		if d < best_d:
			best_d = d
			best = e
	return best

# Враг задел союзника контактом — сам союзник не считает урон по себе через
# HP-полосу (мелкая деталь, петы одноразовые/временные), просто теряет
# «жизнь» быстрее. Вызывается из pursuer.gd при обычном контактном уроне,
# если тот находит цель в группе "ally" (см. соответствующий хук).
func take_hit() -> void:
	_hp -= 1
	if _spr:
		_spr.modulate = Color(1.0, 0.4, 0.4)
		var tw := create_tween()
		tw.tween_property(_spr, "modulate", TINT, 0.25)
	if _hp <= 0:
		_fade_out()

func _fade_out() -> void:
	set_process(false)
	set_physics_process(false)
	var t := create_tween()
	t.set_parallel(true)
	t.tween_property(_spr, "modulate:a", 0.0, 0.4)
	t.tween_property(_ring, "modulate:a", 0.0, 0.4)
	t.tween_property(_lt, "energy", 0.0, 0.4)
	t.set_parallel(false)
	t.tween_callback(queue_free)
