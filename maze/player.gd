extends CharacterBody2D

@export var speed: float = 320.0
@export var max_energy: float = 1.7
@export var drain_per_sec: float = 0.055
@export var charge_per_sec: float = 1.4
@export var boost_delay: float = 2.0
@export var boost_radius_mult: float = 2.0

# --- Навыки ---
const FLASH_COST := 0.28
const FLASH_COOLDOWN := 4.0
const FLASH_DUR := 0.55
const FLASH_EXTRA_SCALE := 6.0
const FLASH_EXTRA_ENERGY := 2.5

const DASH_COST := 0.15
const DASH_COOLDOWN := 1.8
const DASH_DUR := 0.18
const DASH_SPEED := 900.0

const SONAR_COST := 0.30
const SONAR_COOLDOWN := 5.0

const SHIELD_COST := 0.20
const SHIELD_COOLDOWN := 8.0
const SHIELD_DUR := 4.0

# «Искра» — путеводный огонёк к выходу
const GUIDE_COST := 0.35
const GUIDE_COOLDOWN := 10.0

const REVEAL_FILL_PER_SEC := 0.2
const REVEAL_DURATION := 4.0

# Нижний порог свечения: яркость и радиус света не падают ниже уровня,
# соответствующего этому запасу, — чтобы при низком свете не уходить в
# полную тьму. На саму механику не влияет (energy по-прежнему до 0).
const LIGHT_MIN := 0.9

# --- Накопительные пассивки ---
const DIST_FULL := 6000.0   # дистанция для полного разгона
const ADAPT_FULL := 90.0    # время для полной адаптации
const MOMENTUM_MAX := 0.30  # +30% скорости
const ADAPT_MAX := 0.30     # −30% разрядки

var energy: float
var charge_sources: int = 0       # сколько зон станций сейчас накрывают игрока
var active: bool = true
var current_floor: int = 0
var teleport_cooldown: float = 0.0
var _charge_block_time: float = 0.0  # тьма вблизи временно глушит зарядку

# Состояние навыков (читается интерфейсом)
var flash_cd: float = 0.0
var dash_cd: float = 0.0
var sonar_cd: float = 0.0
var shield_cd: float = 0.0
var guide_cd: float = 0.0
var reveal_charge: float = 0.0

# Накопительные бонусы (читаются интерфейсом)
var momentum_bonus: float = 0.0
var adapt_bonus: float = 0.0

var _light: PointLight2D
var _wall_light: PointLight2D
var _shield_vis: Sprite2D
var _cam: Camera2D
var _shake_amp: float = 0.0
var _shake_t: float = 0.0
var _shake_dur: float = 0.0
var _charge_time: float = 0.0
var _flash_time: float = 0.0
var _dash_time: float = 0.0
var _shield_time: float = 0.0
var _dash_dir: Vector2 = Vector2.RIGHT
var _facing: Vector2 = Vector2.RIGHT

var _distance: float = 0.0
var _survival: float = 0.0
var _fog_time: float = 0.0
var _leak_time: float = 0.0
var _flicker_time: float = 0.0

# Множители от выбранных пассивных навыков
var _radius_mult: float = 1.0
var _skill_cost_mult: float = 1.0
var _skill_cd_mult: float = 1.0

func _ready() -> void:
	add_to_group("player")
	_apply_passives()
	energy = max_energy

	var spr := Sprite2D.new()
	spr.texture = MazeTextures.make_ball(18)
	add_child(spr)

	var col := CollisionShape2D.new()
	var shape := CircleShape2D.new()
	shape.radius = 14.0
	col.shape = shape
	add_child(col)

	_light = PointLight2D.new()
	_light.texture = MazeTextures.make_light(256)
	_light.color = Color(1.0, 0.93, 0.80)   # тёплый белый факел
	_light.height = 0.4                      # умеренно: даёт стенам базовую подсветку, тени честные
	_light.energy = energy
	_light.texture_scale = 1.0
	_light.shadow_enabled = true
	add_child(_light)

	# Отдельный свет ТОЛЬКО для стен (light_mask=2): без теней и с низким height,
	# поэтому стены ловят свет всей поверхностью и грани вспыхивают, как у «Искры».
	# Пол и предметы он не трогает (range_item_cull_mask=2), значит коридоры за
	# стенами остаются честно тёмными. Растёт вместе с энергией и вспышкой.
	_wall_light = PointLight2D.new()
	_wall_light.texture = MazeTextures.make_light(256)
	_wall_light.color = Color(1.0, 0.93, 0.80)
	_wall_light.height = 0.12
	_wall_light.shadow_enabled = false
	_wall_light.range_item_cull_mask = 2
	_wall_light.energy = energy
	_wall_light.texture_scale = 1.0
	add_child(_wall_light)

	_shield_vis = Sprite2D.new()
	_shield_vis.texture = MazeTextures.make_ring(80)
	_shield_vis.modulate = Color(0.4, 0.7, 1.0, 0.9)
	_shield_vis.visible = false
	add_child(_shield_vis)

	_cam = Camera2D.new()
	_cam.position_smoothing_enabled = true
	add_child(_cam)

func snap_camera() -> void:
	# Мгновенно подтянуть камеру (после телепорта/возрождения),
	# иначе из-за сглаживания кажется, что появился вдали от точки.
	if _cam:
		_cam.reset_smoothing()

# Кратковременная тряска камеры (для «сочности»: смерть, рывок, подбор).
func add_shake(amp: float, dur: float) -> void:
	_shake_amp = maxf(_shake_amp, amp)
	_shake_dur = maxf(_shake_dur, dur)
	_shake_t = maxf(_shake_t, dur)

func _update_shake(delta: float) -> void:
	if _cam == null:
		return
	if _shake_t > 0.0:
		_shake_t -= delta
		var k: float = _shake_t / _shake_dur if _shake_dur > 0.0 else 0.0
		var a: float = _shake_amp * k
		_cam.offset = Vector2(randf_range(-a, a), randf_range(-a, a))
		if _shake_t <= 0.0:
			_shake_amp = 0.0
			_cam.offset = Vector2.ZERO
	elif _cam.offset != Vector2.ZERO:
		_cam.offset = Vector2.ZERO

func _apply_passives() -> void:
	var p: Dictionary = GameConfig.passives
	if p.get("save", false):
		drain_per_sec *= 0.7
	if p.get("capacity", false):
		max_energy *= 1.3
	if p.get("charge", false):
		charge_per_sec *= 1.5
	if p.get("range", false):
		_radius_mult = 1.25
	if p.get("legs", false):
		speed *= 1.15
	if p.get("magic", false):
		_skill_cost_mult = 0.7
		_skill_cd_mult = 0.75

func _input(event: InputEvent) -> void:
	if not active:
		return
	if event is InputEventKey and event.pressed and not event.echo:
		match event.keycode:
			KEY_Q:
				_try_flash()
			KEY_E:
				_try_sonar()
			KEY_SHIFT:
				_try_dash()
			KEY_C:
				_try_shield()
			KEY_F:
				_try_reveal()
			KEY_G:
				_try_guide()

func _physics_process(delta: float) -> void:
	if teleport_cooldown > 0.0:
		teleport_cooldown -= delta
	if not active:
		velocity = Vector2.ZERO
		return

	var dir := Input.get_vector("ui_left", "ui_right", "ui_up", "ui_down")
	if dir != Vector2.ZERO:
		_facing = dir

	if _dash_time > 0.0:
		_dash_time -= delta
		velocity = _dash_dir * DASH_SPEED
	else:
		velocity = dir * speed * (1.0 + momentum_bonus)

	if velocity != Vector2.ZERO:
		var hit := KinematicCollision2D.new()
		if test_move(global_transform, velocity * delta, hit):
			var along := velocity.slide(hit.get_normal())
			if along.length() > 0.01:
				velocity = along.normalized() * velocity.length()

	move_and_slide()

	if GameConfig.progressive_enabled:
		_distance += velocity.length() * delta

func _process(delta: float) -> void:
	_update_shake(delta)   # тряска работает и когда игрок «погас»

	if not active:
		return

	flash_cd = maxf(0.0, flash_cd - delta)
	dash_cd = maxf(0.0, dash_cd - delta)
	sonar_cd = maxf(0.0, sonar_cd - delta)
	shield_cd = maxf(0.0, shield_cd - delta)
	guide_cd = maxf(0.0, guide_cd - delta)

	# Накопительные пассивки
	if GameConfig.progressive_enabled:
		_survival += delta
		momentum_bonus = clampf(_distance / DIST_FULL, 0.0, MOMENTUM_MAX)
		adapt_bonus = clampf(_survival / ADAPT_FULL, 0.0, ADAPT_MAX)
	else:
		momentum_bonus = 0.0
		adapt_bonus = 0.0

	# Эффекты событий
	var fog := _fog_time > 0.0
	var leak := _leak_time > 0.0
	var flicker := _flicker_time > 0.0
	if fog:
		_fog_time -= delta
	if leak:
		_leak_time -= delta
	if flicker:
		_flicker_time -= delta

	if _shield_time > 0.0:
		_shield_time -= delta
	_shield_vis.visible = _shield_time > 0.0

	if _charge_block_time > 0.0:
		_charge_block_time -= delta

	# Заряжаемся, если есть станция рядом и тьма не глушит зарядку вплотную
	var is_charging := charge_sources > 0 and _charge_block_time <= 0.0

	if is_charging:
		energy = minf(max_energy, energy + charge_per_sec * delta)
		_charge_time += delta
		reveal_charge = minf(1.0, reveal_charge + REVEAL_FILL_PER_SEC * delta)
	elif _shield_time > 0.0:
		_charge_time = 0.0  # щит: разрядка остановлена
	else:
		var d := drain_per_sec * (1.0 - adapt_bonus)
		if leak:
			d *= 1.8
		energy = maxf(0.0, energy - d * delta)
		_charge_time = 0.0

	# Свет погас (и нет щита) — проигрыш
	if energy <= 0.0 and _shield_time <= 0.0:
		active = false
		var g := get_parent()
		if g and g.has_method("on_player_death"):
			g.on_player_death()
		return

	var radius_mult := boost_radius_mult if (is_charging and _charge_time >= boost_delay) else 1.0
	var fog_mult := 0.55 if fog else 1.0

	var flash_boost := 0.0
	if _flash_time > 0.0:
		_flash_time -= delta
		flash_boost = _flash_time / FLASH_DUR

	# Для света используем запас не ниже LIGHT_MIN — иначе при опустошении
	# свет гаснет почти полностью и становится «очень темно».
	var lit := maxf(energy, LIGHT_MIN)
	var base_scale := (0.68 + lit * 0.45) * _radius_mult * radius_mult * fog_mult
	var target_scale := base_scale + flash_boost * FLASH_EXTRA_SCALE
	var target_energy := lit * 1.35 + flash_boost * FLASH_EXTRA_ENERGY

	_light.texture_scale = lerpf(_light.texture_scale, target_scale, 0.2 if _flash_time > 0.0 else 0.12)
	if flicker:
		var flick: float = 0.4 + 0.55 * absf(sin(Time.get_ticks_msec() * 0.03))
		_light.energy = target_energy * flick
	else:
		_light.energy = lerpf(_light.energy, target_energy, 0.3 if _flash_time > 0.0 else 0.12)

	# Свет для стен — чуть меньше радиусом, та же яркость (включая мерцание и вспышку).
	_wall_light.texture_scale = lerpf(_wall_light.texture_scale, target_scale * 0.7, 0.2 if _flash_time > 0.0 else 0.12)
	_wall_light.energy = _light.energy

# --- Навыки ---

func _try_flash() -> void:
	if flash_cd > 0.0 or energy < FLASH_COST * _skill_cost_mult:
		return
	energy -= FLASH_COST * _skill_cost_mult
	flash_cd = FLASH_COOLDOWN * _skill_cd_mult
	_flash_time = FLASH_DUR

func _try_dash() -> void:
	if dash_cd > 0.0 or energy < DASH_COST * _skill_cost_mult:
		return
	energy -= DASH_COST * _skill_cost_mult
	dash_cd = DASH_COOLDOWN * _skill_cd_mult
	_dash_time = DASH_DUR
	_dash_dir = _facing
	add_shake(5.0, 0.12)

func _try_sonar() -> void:
	if sonar_cd > 0.0 or energy < SONAR_COST * _skill_cost_mult:
		return
	energy -= SONAR_COST * _skill_cost_mult
	sonar_cd = SONAR_COOLDOWN * _skill_cd_mult
	var s := Node2D.new()
	s.set_script(load("res://sonar.gd"))
	s.position = global_position
	get_parent().add_child(s)

func _try_guide() -> void:
	if guide_cd > 0.0 or energy < GUIDE_COST * _skill_cost_mult:
		return
	var g := get_parent()
	if g == null or not g.has_method("guide_path_to_exit"):
		return
	var path: PackedVector2Array = g.guide_path_to_exit(global_position, current_floor)
	if path.size() < 2:
		return  # путь не найден — навык не тратится
	energy -= GUIDE_COST * _skill_cost_mult
	guide_cd = GUIDE_COOLDOWN * _skill_cd_mult
	var spark := Node2D.new()
	spark.set_script(load("res://spark.gd"))
	spark.path_points = path
	g.add_child(spark)

func _try_shield() -> void:
	if shield_cd > 0.0 or energy < SHIELD_COST * _skill_cost_mult:
		return
	energy -= SHIELD_COST * _skill_cost_mult
	shield_cd = SHIELD_COOLDOWN * _skill_cd_mult
	_shield_time = SHIELD_DUR

func _try_reveal() -> void:
	if reveal_charge < 1.0:
		return
	reveal_charge = 0.0
	var g := get_parent()
	if g and g.has_method("reveal"):
		g.reveal(REVEAL_DURATION)

func block_charge(dur: float) -> void:
	_charge_block_time = maxf(_charge_block_time, dur)

func apply_event(kind: String, dur: float) -> void:
	match kind:
		"fog":
			_fog_time = maxf(_fog_time, dur)
		"leak":
			_leak_time = maxf(_leak_time, dur)
		"flicker":
			_flicker_time = maxf(_flicker_time, dur)

func respawn(pos: Vector2, floor_idx: int) -> void:
	global_position = pos
	current_floor = floor_idx
	energy = max_energy
	_light.energy = max_energy * 1.35
	_light.texture_scale = (0.68 + max_energy * 0.45) * _radius_mult
	_wall_light.energy = _light.energy
	_wall_light.texture_scale = _light.texture_scale * 0.7
	teleport_cooldown = 0.5
	charge_sources = 0
	_charge_block_time = 0.0
	_charge_time = 0.0
	_flash_time = 0.0
	_dash_time = 0.0
	_shield_time = 0.0
	_fog_time = 0.0
	_leak_time = 0.0
	_flicker_time = 0.0
	active = true
	snap_camera()
