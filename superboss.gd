extends CharacterBody2D

# Супербосс (GAMEDESIGN.md §25) — шаг 2: AI (движение + лазер + фазы).
# Фундамент арены/стен — см. main.gd::_make_superboss_arena_grid,
# _strong_cells, STRONG_WALL_COLOR (шаг 1, уже реализован и проверен).
#
# CharacterBody2D + move_and_slide() — тот же приём защиты от прохождения
# сквозь стены, что у boss.gd (см. комментарий там про инцидент с рывком
# сквозь пилоны). collision_layer=0 — с игроком физически не сталкивается,
# контакт по-прежнему считается вручную по дистанции.
#
# ВАЖНО (согласовано в обсуждении §25): голая Вспышка почти не ранит —
# иначе спам одним навыком «раздевает» уникального босса тем же способом,
# что и рядового врага. Реальный урон даёт только КОМБО «Световое копьё»
# (рывок во время вспышки, уже существующий комбо — см. player.gd
# _try_dash), и то ТОЛЬКО в окне уязвимости, которое открывается после
# HITS_TO_VULNERABLE выстрелов лазера. Это не даёт закликать босса —
# нужно ждать ритма боя, а не спамить один навык.

const MOVE_SPEED := 42.0            # медленно — «большой и тяжёлый»
const MAX_HP := 24
const PHASE_2_HP := 16              # 66%
const PHASE_3_HP := 8               # 33%

const LASER_TELEGRAPH := 1.1        # прицел-предупреждение перед выстрелом
const LASER_COOLDOWN_BY_PHASE := [2.6, 2.1, 1.6]   # злее с каждой фазой
const LASER_MAX_CELLS := 16
const HITS_TO_VULNERABLE := 3       # столько выстрелов лазера — потом уязвимость
const VULNERABLE_DURATION := 5.0

const FLASH_RANGE := 300.0
const FLASH_DMG_VULNERABLE := 1     # голая Вспышка ранит, только если уязвим — и то мало
const SPEAR_DMG_VULNERABLE := 3     # «Световое копьё» в уязвимости — основной источник урона

var _game: Node
var _player: Node
var _hp: int = MAX_HP
var _phase: int = 1
var _floor_idx: int = 0

var _laser_cd: float = 1.5          # небольшая пауза на старте — время осмотреться
var _telegraph_t: float = 0.0
var _aim_dir: Vector2 = Vector2.RIGHT
var _hits_fired: int = 0
var _vulnerable_t: float = 0.0
var _wander_target: Vector2 = Vector2.ZERO
var _contact_cd: float = 0.0
var _dying: bool = false

var _body: Sprite2D
var _glow: PointLight2D
var _weak_marker: Node2D
var _aim_line: Line2D
var _hp_bg: ColorRect
var _hp_fill: ColorRect
var _anim: float = 0.0
var _hit_flash: float = 0.0

func _ready() -> void:
	add_to_group("superboss")
	collision_layer = 0
	collision_mask = 1
	var col := CollisionShape2D.new()
	var shape := CircleShape2D.new()
	shape.radius = 46.0
	col.shape = shape
	add_child(col)

	_body = Sprite2D.new()
	_body.texture = MazeTextures.make_superboss_body(46, Color(0.75, 0.2, 0.85))   # v1.9: механическое тело, не гем
	add_child(_body)

	_glow = PointLight2D.new()
	_glow.texture = MazeTextures.make_light(340)
	_glow.color = Color(0.75, 0.2, 0.9)
	_glow.energy = 1.8
	add_child(_glow)

	_weak_marker = Node2D.new()
	_weak_marker.visible = false
	add_child(_weak_marker)
	var wm_spr := Sprite2D.new()
	wm_spr.texture = MazeTextures.make_light(90)
	wm_spr.modulate = Color(1.0, 0.9, 0.2, 0.9)
	_weak_marker.add_child(wm_spr)

	_aim_line = Line2D.new()
	_aim_line.width = 5.0
	_aim_line.default_color = Color(1.0, 0.2, 0.15, 0.0)
	add_child(_aim_line)

	_hp_bg = ColorRect.new()
	_hp_bg.color = Color(0.12, 0.0, 0.15, 0.9)
	_hp_bg.size = Vector2(220, 18)
	_hp_bg.position = Vector2(-110, -110)
	add_child(_hp_bg)
	_hp_fill = ColorRect.new()
	_hp_fill.color = Color(0.85, 0.3, 1.0, 1.0)
	_hp_fill.size = Vector2(216, 14)
	_hp_fill.position = Vector2(-108, -108)
	add_child(_hp_fill)

	_wander_target = global_position
	_pick_wander_target()

func _process(delta: float) -> void:
	# Пока игрок не сделал первый ход — босс замер (тот же приём, что у
	# boss.gd): иначе лазер начинает бить, пока игрок ещё читает вступительное
	# сообщение и не тронулся с места.
	if _player != null and is_instance_valid(_player) and "started" in _player and not _player.started:
		return
	_anim += delta
	if _hit_flash > 0.0:
		_hit_flash -= delta
	_body.modulate = Color(1.0, 0.5, 0.5) if _hit_flash > 0.0 else Color.WHITE
	_body.scale = Vector2.ONE * (1.0 + 0.05 * sin(_anim * 1.4))
	_glow.energy = 1.6 + 0.3 * sin(_anim * 1.8)

	if _vulnerable_t > 0.0:
		_vulnerable_t -= delta
		_weak_marker.visible = true
		_weak_marker.scale = Vector2.ONE * (1.0 + 0.15 * sin(_anim * 6.0))
		_glow.color = Color(1.0, 0.85, 0.2)
		if _vulnerable_t <= 0.0:
			_hits_fired = 0
			_glow.color = Color(0.75, 0.2, 0.9)
	else:
		_weak_marker.visible = false

	_update_laser(delta)

func _physics_process(delta: float) -> void:
	if _player == null or not is_instance_valid(_player):
		velocity = Vector2.ZERO
		move_and_slide()
		return
	if "started" in _player and not _player.started:
		velocity = Vector2.ZERO
		move_and_slide()
		return
	_move_toward(_wander_target, MOVE_SPEED)
	if global_position.distance_to(_wander_target) < 30.0:
		_pick_wander_target()
	move_and_slide()
	_check_contact(delta)

func _move_toward(pos: Vector2, speed: float) -> void:
	var dir: Vector2 = pos - global_position
	velocity = dir.normalized() * speed if dir.length() > 4.0 else Vector2.ZERO

func _pick_wander_target() -> void:
	if _game == null or not ("_gw" in _game):
		return
	var margin := 3.0 * float(_game.TILE)
	var w: float = float(_game._gw) * float(_game.TILE) - margin * 2.0
	var h: float = float(_game._gh) * float(_game.TILE) - margin * 2.0
	_wander_target = Vector2(margin + randf() * w, margin + randf() * h) + Vector2(0, _floor_idx * _game._floor_gap)

# ── Лазер ────────────────────────────────────────────────────────────────
func _update_laser(delta: float) -> void:
	if _player == null or not is_instance_valid(_player):
		return
	if _telegraph_t > 0.0:
		_telegraph_t -= delta
		_aim_dir = (_player.global_position - global_position).normalized()
		_aim_line.default_color.a = 0.55 + 0.35 * sin(_anim * 20.0)
		_aim_line.points = PackedVector2Array([Vector2.ZERO, _aim_dir * 900.0])
		if _telegraph_t <= 0.0:
			_fire_laser()
		return
	_aim_line.default_color.a = 0.0
	_laser_cd -= delta
	if _laser_cd <= 0.0:
		_telegraph_t = LASER_TELEGRAPH

func _fire_laser() -> void:
	_laser_cd = LASER_COOLDOWN_BY_PHASE[_phase - 1]
	_aim_line.default_color.a = 0.0
	if _game and _game.has_method("superboss_laser_break"):
		_game.superboss_laser_break(global_position, _aim_dir, _floor_idx, LASER_MAX_CELLS)
	if _game and _game.has_method("play_sfx") and "_sfx_damage" in _game:
		_game.play_sfx(_game._sfx_damage)
	_hits_fired += 1
	if _hits_fired >= HITS_TO_VULNERABLE and _vulnerable_t <= 0.0:
		_vulnerable_t = VULNERABLE_DURATION
		if _game and _game.has_method("flash_message"):
			_game.flash_message(GameConfig.tt("⚡ Ядро супербосса открыто! Рывок+Вспышка — сейчас или никогда", "⚡ The superboss core is exposed! Dash+Flash — now or never"))

# ── Урон ─────────────────────────────────────────────────────────────────
# is_combo: true для «Светового копья» (рывок во время вспышки), false для
# голой Вспышки. Реальный урон — только в окне уязвимости; вне его —
# сообщение-подсказка вместо тихого нуля (чтобы игрок понимал ПОЧЕМУ не
# берёт урон, а не решил что комбо сломано).
func try_hit(player_pos: Vector2, is_combo: bool) -> void:
	if _dying:
		return
	if player_pos.distance_to(global_position) > FLASH_RANGE:
		return
	if _vulnerable_t <= 0.0:
		if _game and _game.has_method("flash_message"):
			_game.flash_message(GameConfig.tt("Обычный удар почти не ранит Ядро — дождись, пока лазер откроет уязвимость", "A plain hit barely scratches the Core — wait for the laser to expose its weak point"), 0)
		return
	var dmg: int = SPEAR_DMG_VULNERABLE if is_combo else FLASH_DMG_VULNERABLE
	_hp = maxi(0, _hp - dmg)
	_hit_flash = 0.35
	_update_hp_bar()
	var bst := Node2D.new()
	bst.set_script(load("res://burst.gd"))
	bst.color = Color(1.0, 0.9, 0.3, 1.0)
	bst.max_scale = 6.0
	bst.dur = 0.45
	get_parent().add_child(bst)
	bst.global_position = global_position
	if _game and _game.has_method("flash_message"):
		_game.flash_message(GameConfig.tt("Попадание в уязвимость! HP: %d/%d", "Hit on the weak point! HP: %d/%d") % [_hp, MAX_HP], 0)

	if _hp <= PHASE_3_HP and _phase < 3:
		_phase = 3
		_announce_phase()
	elif _hp <= PHASE_2_HP and _phase < 2:
		_phase = 2
		_announce_phase()

	if _hp <= 0:
		_die()

func _announce_phase() -> void:
	_vulnerable_t = 0.0
	_hits_fired = 0
	if _game and _game.has_method("flash_message"):
		_game.flash_message(GameConfig.tt("Фаза %d — лазер бьёт чаще", "Phase %d — the laser fires faster") % _phase, 0)
	if _game and _game.has_method("flash_screen"):
		_game.flash_screen(Color(0.8, 0.3, 0.9), 0.3)

func _check_contact(delta: float) -> void:
	if _contact_cd > 0.0:
		_contact_cd -= delta
	if _player == null or not is_instance_valid(_player):
		return
	if global_position.distance_to(_player.global_position) > 80.0 or _contact_cd > 0.0:
		return
	_contact_cd = 1.2
	if _player.has_method("hit_by_enemy"):
		_player.hit_by_enemy(0.3)

func _update_hp_bar() -> void:
	if _hp_fill:
		var frac: float = float(_hp) / float(MAX_HP)
		_hp_fill.size.x = 216.0 * frac

func _die() -> void:
	_dying = true
	for i in 6:
		var bst := Node2D.new()
		bst.set_script(load("res://burst.gd"))
		bst.color = Color(0.8, 0.3, 1.0, 1.0)
		bst.max_scale = float(i + 3) * 3.5
		bst.dur = 0.6 + float(i) * 0.1
		get_parent().add_child(bst)
		bst.global_position = global_position + Vector2(randf_range(-50, 50), randf_range(-50, 50))
	var pos := global_position
	queue_free()
	if _game and _game.has_method("on_superboss_defeated"):
		_game.on_superboss_defeated(pos)
