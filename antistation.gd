extends Area2D

# Антистанция (GAMEDESIGN.md §25, шаг 3): тёмный анти-аналог станции — не
# заряжает игрока, а подпитывает миньонов-эскорт супербосса (ускоряет их,
# см. pursuer.gd::_escort_buff_mult). Игрок может её погасить — она в
# группе "enemy", поэтому её берёт уже существующая area-система урона от
# активных навыков (main.gd::skill_hit_enemies, Вспышка/Сонар), но она НЕ
# считается «убийством врага» для статистики/бестиария — take_damage не
# трогает GameConfig.bump_stat/on_enemy_defeated, только свою активность.
#
# Тактика, ради которой всё это сделано: сначала погасить антистанцию —
# эскорт лишается подпитки — потом уже разбираться с миньонами/боссом.

const HP := 3
const COLOR := Color(0.42, 0.12, 0.55)

var game: Node = null
var floor_index: int = 0
var _hp: int = HP
var active: bool = true

var _spr: Sprite2D
var _lt: PointLight2D
var _anim: float = 0.0

func _ready() -> void:
	add_to_group("enemy")        # чтобы Вспышка/Сонар доставали её как обычную цель
	add_to_group("antistation")  # чтобы эскорт-миньоны находили её для баффа
	var col := CollisionShape2D.new()
	var shape := CircleShape2D.new()
	shape.radius = 24.0
	col.shape = shape
	add_child(col)

	_spr = Sprite2D.new()
	_spr.texture = MazeTextures.make_portal(20, COLOR)
	add_child(_spr)

	_lt = PointLight2D.new()
	_lt.texture = MazeTextures.make_light(170)
	_lt.color = COLOR
	_lt.energy = 0.85
	add_child(_lt)

func _process(delta: float) -> void:
	_anim += delta
	if not active:
		return
	if _spr:
		# Крутится в обратную сторону от обычных дверей-порталов — «неправильный»,
		# засасывающий портал, а не открывающий.
		_spr.rotation -= delta * 0.8
		_spr.scale = Vector2.ONE * (0.95 + 0.05 * sin(_anim * 2.6))
	if _lt:
		_lt.energy = 0.65 + 0.25 * sin(_anim * 2.6)

func is_active() -> bool:
	return active

# Интерфейс, ожидаемый main.gd::skill_hit_enemies (как у pursuer.gd::take_damage) —
# возвращает true, когда антистанция гаснет этим попаданием (аналог «убийства»
# для отклика урона, статистику при этом не трогаем).
func take_damage(dmg: int, _source: String) -> bool:
	if not active:
		return false
	_hp -= dmg
	if _spr:
		_spr.modulate = Color(1.6, 1.3, 1.3)
		var tw := create_tween()
		tw.tween_property(_spr, "modulate", Color.WHITE, 0.2)
	if _hp <= 0:
		_deactivate()
		return true
	return false

func _deactivate() -> void:
	active = false
	# Выходим из группы "enemy": иначе погашенная антистанция остаётся
	# «валидной целью» навсегда — союзник-пет (ally.gd::_nearest_enemy)
	# продолжал бы бить по ней вместо живых врагов, а Вспышка/Сонар — тратить
	# на неё попадания. Из "antistation" тоже выходим, чтобы эскорт не искал
	# подпитку у мёртвого источника (там есть и проверка is_active(), но
	# держать группу чистой дешевле, чем полагаться на неё).
	remove_from_group("enemy")
	remove_from_group("antistation")
	if _lt:
		_lt.energy = 0.0
	if _spr:
		_spr.modulate = Color(0.35, 0.35, 0.4, 0.55)
		_spr.rotation = 0.0
	if game and game.has_method("flash_message"):
		game.flash_message(GameConfig.tt("Антистанция погашена — эскорт лишён подпитки", "Anti-station doused — the escort lost its power source"))
