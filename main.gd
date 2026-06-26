extends Node2D

const TILE := 48.0        # размер одной клетки сетки в пикселях
const MAX_LEVEL := 20     # всего уровней (11-20 — органические «корни»)
const ORGANIC_FROM := 11  # с этого уровня лабиринт ветвится как корни/ветки
const MAX_FLOORS := 4     # потолок числа этажей
const MAX_DIM := 36       # потолок размера лабиринта по стороне
const MAX_STATIONS := 40  # потолок станций на этаж (защита от мерцания света)
const SHARDS_PER_FLOOR := 5  # осколков света на этаж

const FLOOR_COLOR := Color(0.07, 0.08, 0.11)  # цвет пола (виден только при свете)

# Цвета стен по уровням (для визуального разнообразия)
const WALL_THEMES := [
	Color(0.20, 0.23, 0.34),  # синий
	Color(0.30, 0.22, 0.30),  # фиолетовый
	Color(0.20, 0.30, 0.26),  # зелёный
	Color(0.32, 0.26, 0.20),  # охра
	Color(0.30, 0.20, 0.22),  # красный
]
var _wall_color: Color = WALL_THEMES[0]

# Цвета органических тоннелей (уровни 11-20): корни/земля/мох
const ORGANIC_THEMES := [
	Color(0.42, 0.30, 0.18),  # тёплое дерево
	Color(0.30, 0.34, 0.20),  # мох
	Color(0.40, 0.26, 0.22),  # красная глина
	Color(0.26, 0.30, 0.34),  # сырой камень
	Color(0.38, 0.34, 0.20),  # охра
]
var _organic: bool = false
var _organic_color: Color = ORGANIC_THEMES[0]
var _wall_tex_cache: Dictionary = {}   # open_mask(int) -> CanvasTexture (на время постройки уровня)

var _level: int
var _floors: int
var _cols: int
var _rows: int
var _gw: int
var _gh: int
var _floor_gap: float
var _grids: Array = []
var _drain_mult: float = 1.0
var _floor_containers: Array = []      # Node2D на каждый этаж
var _organic_floors: Array = []        # organic_floor на каждый этаж (для перерисовки)
var _wall_nodes: Dictionary = {}       # Vector3i(f,gx,gy) -> StaticBody2D
var _door_links: Dictionary = {}       # Vector3i(f,cx,cy) -> Array[Vector3i] (переходы между этажами)
var _exit_cell: Vector2i = Vector2i.ZERO
var _exit_floor: int = 0

var _player: CharacterBody2D
var _cp_pos: Vector2
var _cp_floor: int = 0

var _lives: int = 3
var _shards_collected: int = 0
var _shards_total: int = 0
var _keys: int = 0
var _visited: Dictionary = {}    # Vector3i(floor,cx,cy) -> true (для миникарты)
var _toast_time: float = 0.0
var _elapsed: float = 0.0
var _won: bool = false
var _dead: bool = false
var _paused: bool = false
var _game_over: bool = false

# Случайные события
var _events_enabled: bool = true
var _event_cd: float = 0.0
var _event_active: float = 0.0

# Интерфейс
var _time_label: Label
var _level_label: Label
var _win_label: Label
var _msg_label: Label
var _event_label: Label
var _energy_bar: ProgressBar
var _energy_fill: StyleBoxFlat
var _skill_flash: Label
var _skill_dash: Label
var _skill_sonar: Label
var _skill_shield: Label
var _skill_reveal: Label
var _skill_guide: Label
var _lives_label: Label
var _shards_label: Label
var _keys_label: Label
var _prog_label: Label
var _toast_label: Label
var _minimap: TextureRect
var _joystick: Control
var _tint: ColorRect
var _tint_target: Color = Color(0, 0, 0, 0)
var _pause_overlay: Control
var _pause_info: Label
var _xp_bar: ProgressBar
var _sp_label: Label

var _dark: CanvasModulate
var _ambient: Color
var _reveal_time: float = 0.0

var _fx   # менеджер экранных эффектов (screenfx.gd)
var _music: AudioStreamPlayer

func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS   # чтобы ввод работал во время паузы
	get_tree().paused = false

	_level = clampi(GameConfig.level, 1, MAX_LEVEL)
	_floors = mini(_level, MAX_FLOORS)
	_cols = mini(GameConfig.cols + (_level - 1) * 6, MAX_DIM)
	_rows = mini(GameConfig.rows + (_level - 1) * 4, MAX_DIM - 12)
	_gw = _cols * 2 + 1
	_gh = _rows * 2 + 1
	_floor_gap = (_gh + 2) * TILE

	# Усложнение по уровням: быстрее разрядка и темнее фон
	_drain_mult = 1.0 + (_level - 1) * 0.07
	var dark_scale := maxf(0.45, 1.0 - (_level - 1) * 0.045)
	var a: float = GameConfig.darkness * dark_scale
	_ambient = Color(a, a, a + 0.02)

	_events_enabled = GameConfig.events_enabled
	_event_cd = randf_range(10.0, 16.0)
	_lives = maxi(1, GameConfig.lives)
	_wall_color = WALL_THEMES[(_level - 1) % WALL_THEMES.size()]
	_organic = false

	_build_world()
	_build_hud()
	_build_screen_fx()
	_start_music()
	if DisplayServer.is_touchscreen_available():
		_build_touch_controls()

func _process(delta: float) -> void:
	if _paused:
		return

	if _toast_time > 0.0:
		_toast_time -= delta
		if _toast_time <= 0.0 and _toast_label:
			_toast_label.visible = false

	# Время и события идут только после первого движения игрока
	var has_started: bool = _player and is_instance_valid(_player) and _player.started
	if not _won and not _dead and has_started:
		_elapsed += delta
		_time_label.text = "Время: %.1f с" % _elapsed
		_update_events(delta)
		_mark_visited()

	if _player and is_instance_valid(_player):
		if _joystick:
			_player.touch_dir = _joystick.output
		var r: float = clampf(_player.energy / _player.max_energy, 0.0, 1.0)
		_energy_bar.value = r
		_energy_fill.bg_color = Color(0.9, 0.2, 0.2).lerp(Color(1.0, 0.85, 0.3), r)

		# Экранные эффекты: красная тревога ниже 40% света; золото при зарядке
		if _fx:
			_fx.set_danger(clampf((0.4 - r) / 0.4, 0.0, 1.0))
			_fx.set_charge(1.0 if _player.charge_sources > 0 else 0.0)

		# Скрываем заблокированные навыки в HUD, показываем разблокированные
		_skill_flash.visible  = GameConfig.skills_unlocked.get("flash", false)
		_skill_dash.visible   = GameConfig.skills_unlocked.get("dash", false)
		_skill_sonar.visible  = GameConfig.skills_unlocked.get("sonar", false)
		_skill_shield.visible = GameConfig.skills_unlocked.get("shield", false)
		_skill_guide.visible  = GameConfig.skills_unlocked.get("guide", false)
		_skill_reveal.visible = GameConfig.skills_unlocked.get("reveal", false)
		if _skill_flash.visible:
			_update_skill(_skill_flash, "Q  Вспышка", _player.flash_cd, _player.energy, _player.FLASH_COST)
		if _skill_dash.visible:
			_update_skill(_skill_dash, "Shift  Рывок", _player.dash_cd, _player.energy, _player.DASH_COST)
		if _skill_sonar.visible:
			_update_skill(_skill_sonar, "E  Сонар", _player.sonar_cd, _player.energy, _player.SONAR_COST)
		if _skill_shield.visible:
			_update_skill(_skill_shield, "C  Щит", _player.shield_cd, _player.energy, _player.SHIELD_COST)
		if _skill_guide.visible:
			_update_skill(_skill_guide, "G  Искра", _player.guide_cd, _player.energy, _player.GUIDE_COST)
		if _skill_reveal.visible:
			_update_reveal(_skill_reveal, _player.reveal_charge)

		if GameConfig.progressive_enabled:
			_prog_label.text = "Разгон +%d%%   Адаптация −%d%%" % [
				int(_player.momentum_bonus * 100.0), int(_player.adapt_bonus * 100.0)]
		else:
			_prog_label.text = ""

	# XP / SP в HUD
	if _sp_label:
		_sp_label.text = "SP: %d   XP: %d/%d" % [GameConfig.skill_points, GameConfig.xp, GameConfig.XP_PER_SP]
	if _xp_bar:
		_xp_bar.value = GameConfig.xp

	# Озарение
	if _dark:
		if _reveal_time > 0.0:
			_reveal_time -= delta
			_dark.color = _dark.color.lerp(Color(0.85, 0.85, 0.9), 0.12)
		else:
			_dark.color = _dark.color.lerp(_ambient, 0.06)

	# Цветовой тинт событий
	if _tint:
		_tint.color = _tint.color.lerp(_tint_target, 0.1)

# --- Случайные события ---

func _update_events(delta: float) -> void:
	if not _events_enabled or _level < 2:
		return

	if _event_active > 0.0:
		_event_active -= delta
		if _event_active <= 0.0:
			_end_event()
		return

	_event_cd -= delta
	if _event_cd <= 0.0:
		_trigger_event()

func _trigger_event() -> void:
	var roll := randf()
	var dur := randf_range(3.0, 5.0)
	var kind := ""
	if roll < 0.18:
		kind = "relief"
	elif roll < 0.40:
		kind = "fog"
	elif roll < 0.60:
		kind = "leak"
	elif roll < 0.80:
		kind = "flicker"
	else:
		kind = "shift"

	_event_active = dur

	match kind:
		"shift":
			_event_label.text = "▦ Лабиринт сдвигается"
			_event_label.add_theme_color_override("font_color", Color(0.8, 0.6, 1.0))
			_tint_target = Color(0.4, 0.25, 0.6, 0.14)
			_maze_shift()
		"relief":
			_event_label.text = "✦ Просвет"
			_event_label.add_theme_color_override("font_color", Color(0.5, 1.0, 0.6))
			_tint_target = Color(0.2, 0.6, 0.3, 0.10)
			_reveal_time = maxf(_reveal_time, 1.6)
			if _player:
				_player.energy = minf(_player.max_energy, _player.energy + 0.3)
		"fog":
			_event_label.text = "≈ Густой туман"
			_event_label.add_theme_color_override("font_color", Color(0.6, 0.8, 1.0))
			_tint_target = Color(0.25, 0.4, 0.7, 0.16)
			if _player:
				_player.apply_event("fog", dur)
		"leak":
			_event_label.text = "⚠ Утечка света"
			_event_label.add_theme_color_override("font_color", Color(1.0, 0.5, 0.4))
			_tint_target = Color(0.7, 0.2, 0.2, 0.16)
			if _player:
				_player.apply_event("leak", dur)
		"flicker":
			_event_label.text = "⚡ Перебой света"
			_event_label.add_theme_color_override("font_color", Color(1.0, 0.9, 0.4))
			_tint_target = Color(0.1, 0.1, 0.1, 0.12)
			if _player:
				_player.apply_event("flicker", dur)

	_event_label.visible = true

func _end_event() -> void:
	_event_label.visible = false
	_tint_target = Color(0, 0, 0, 0)
	# Следующее событие — реже на низких уровнях, чаще на высоких
	var lo := maxf(6.0, 16.0 - _level)
	_event_cd = randf_range(lo, lo + 8.0)

# --- Пауза ---

func _toggle_pause() -> void:
	_paused = not _paused
	get_tree().paused = _paused
	_pause_overlay.visible = _paused
	if _fx:
		_fx.visible = not _paused   # не показывать виньетки поверх меню паузы
	if _paused:
		_refresh_pause()

func _refresh_pause() -> void:
	var t := "[ Активные навыки ]\n"
	t += "Q — Вспышка     Shift — Рывок\n"
	t += "E — Сонар       C — Щит\n"
	t += "G — Искра (путь к выходу)\n"
	if _player:
		t += "F — Озарение (%d%%)\n\n" % int(_player.reveal_charge * 100.0)
	else:
		t += "F — Озарение\n\n"

	t += "[ Пассивные навыки ]\n"
	var names := {
		"save": "Энергосбережение", "capacity": "Ёмкость",
		"charge": "Быстрая зарядка", "range": "Дальний свет",
		"legs": "Лёгкие ноги", "magic": "Эффективная магия",
	}
	var any := false
	for k in names:
		if GameConfig.passives.get(k, false):
			t += "• %s\n" % names[k]
			any = true
	if not any:
		t += "— не выбраны —\n"

	if GameConfig.progressive_enabled and _player:
		t += "\n[ Накопительные ]\n"
		t += "Разгон: +%d%% скорости\n" % int(_player.momentum_bonus * 100.0)
		t += "Адаптация: −%d%% разрядки\n" % int(_player.adapt_bonus * 100.0)

	_pause_info.text = t

	if _minimap:
		_minimap.texture = _build_minimap_texture()

func _restart() -> void:
	get_tree().paused = false
	get_tree().reload_current_scene()

func _goto_menu() -> void:
	GameConfig.save_game()
	get_tree().paused = false
	get_tree().change_scene_to_file("res://menu.tscn")

func _open_skills_menu() -> void:
	_pause_overlay.visible = false
	var sm := CanvasLayer.new()
	sm.set_script(load("res://skills_menu.gd"))
	add_child(sm)
	sm.closed.connect(func():
		if is_instance_valid(_pause_overlay):
			_pause_overlay.visible = true)

func _unhandled_input(event: InputEvent) -> void:
	if not (event is InputEventKey and event.pressed and not event.echo):
		return
	var k: int = event.keycode

	if _won or _game_over:
		if k == KEY_R or k == KEY_SPACE:
			_restart()
		elif k == KEY_ESCAPE:
			_goto_menu()
		return

	if k == KEY_ESCAPE or k == KEY_P:
		_toggle_pause()
	elif k == KEY_R and not _paused:
		_restart()

# --- Генерация лабиринта (recursive backtracker) ---

func _make_grid() -> Array:
	var grid: Array = []
	grid.resize(_gh)
	for y in _gh:
		var row := []
		row.resize(_gw)
		for x in _gw:
			row[x] = true
		grid[y] = row

	# Growing-tree: чаще берём самую свежую клетку (длинные коридоры),
	# иногда — случайную из активных (ветвление). Для органических уровней
	# больше ветвлений — структура напоминает корни/ветви дерева.
	var newest_prob := 1.0
	var visited := {}
	var active: Array[Vector2i] = []
	var start := Vector2i(0, 0)
	visited[start] = true
	grid[1][1] = false
	active.append(start)

	while not active.is_empty():
		var idx: int = active.size() - 1 if randf() < newest_prob else randi() % active.size()
		var c: Vector2i = active[idx]
		var neighbors := _unvisited_neighbors(c, visited)
		if neighbors.is_empty():
			active.remove_at(idx)
		else:
			var n: Vector2i = neighbors[randi() % neighbors.size()]
			visited[n] = true
			grid[n.y * 2 + 1][n.x * 2 + 1] = false
			grid[c.y + n.y + 1][c.x + n.x + 1] = false
			active.append(n)

	return grid

func _unvisited_neighbors(c: Vector2i, visited: Dictionary) -> Array[Vector2i]:
	var res: Array[Vector2i] = []
	for d in [Vector2i(1, 0), Vector2i(-1, 0), Vector2i(0, 1), Vector2i(0, -1)]:
		var n: Vector2i = c + d
		if n.x >= 0 and n.x < _cols and n.y >= 0 and n.y < _rows and not visited.has(n):
			res.append(n)
	return res

# --- Построение мира ---

func _build_world() -> void:
	_dark = CanvasModulate.new()
	_dark.color = _ambient
	add_child(_dark)

	_wall_tex_cache.clear()
	_grids.clear()
	for f in _floors:
		var grid := _make_grid()
		_grids.append(grid)
		_build_floor(f, grid)

	_place_doors()
	_place_exit()
	_spawn_player()

	# Враги с уровня 4 (количество и типы нарастают с уровнем)
	if GameConfig.darkness_chaser and _level >= 4:
		_spawn_enemies()

func _spawn_enemies() -> void:
	# Количество врагов каждого типа в зависимости от уровня
	var n_slow   := 0
	var n_fast   := 0
	var n_cyclic := 0
	if _level >= 4:  n_slow   = 1
	if _level >= 6:  n_fast   = 1
	if _level >= 8:  n_cyclic = 1
	# С 11 уровня — каждый тип получает +1
	if _level >= 11:
		n_slow   += 1
		n_fast   += 1
		n_cyclic += 1
	# Дополнительная эскалация по отдельным типам
	if _level >= 12: n_slow   += 1
	if _level >= 15: n_fast   += 1
	if _level >= 18: n_cyclic += 1

	# Позиции — ячейки, отсортированные по убыванию BFS-расстояния от старта
	var spawn_cells := _far_spawn_cells(_grids[0], n_slow + n_fast + n_cyclic)
	var idx := 0

	for _i in n_slow:
		if idx < spawn_cells.size():
			_spawn_one_enemy(0, spawn_cells[idx])
			idx += 1
	for _i in n_fast:
		if idx < spawn_cells.size():
			_spawn_one_enemy(1, spawn_cells[idx])
			idx += 1
	for _i in n_cyclic:
		if idx < spawn_cells.size():
			_spawn_one_enemy(2, spawn_cells[idx])
			idx += 1

func _spawn_one_enemy(type: int, cell: Vector2i) -> void:
	var pur := Node2D.new()
	pur.set_script(load("res://pursuer.gd"))
	pur.enemy_type = type
	pur.spawn_level = _level
	pur.position = _cell_to_world(cell)
	pur.target = _player
	pur._game = self
	add_child(pur)

# BFS от (0,0) — возвращает до `count` ячеек из дальней половины лабиринта.
func _far_spawn_cells(grid: Array, count: int) -> Array[Vector2i]:
	var start := Vector2i(0, 0)
	var dist_map := {start: 0}
	var queue: Array[Vector2i] = [start]
	var max_d := 0
	while not queue.is_empty():
		var c: Vector2i = queue.pop_front()
		for d in [Vector2i(1,0), Vector2i(-1,0), Vector2i(0,1), Vector2i(0,-1)]:
			var n: Vector2i = c + d
			if n.x < 0 or n.x >= _cols or n.y < 0 or n.y >= _rows or dist_map.has(n):
				continue
			if not grid[c.y + n.y + 1][c.x + n.x + 1]:
				dist_map[n] = dist_map[c] + 1
				max_d = maxi(max_d, dist_map[n])
				queue.append(n)

	# Берём ячейки из дальней половины (BFS-расстояние > max/2)
	var threshold := max_d / 2
	var far: Array[Vector2i] = []
	for k: Vector2i in dist_map.keys():
		if dist_map[k] > threshold:
			far.append(k)
	far.shuffle()
	return far.slice(0, count)

func _build_floor(f: int, grid: Array) -> void:
	var container := Node2D.new()
	container.position = Vector2(0, f * _floor_gap)
	add_child(container)
	_floor_containers.resize(maxi(_floor_containers.size(), f + 1))
	_floor_containers[f] = container

	if _organic:
		# Органический пол: плавные скруглённые тоннели по форме лабиринта.
		var of := Node2D.new()
		of.set_script(load("res://organic_floor.gd"))
		of.tile = TILE
		of.cols = _cols
		of.rows = _rows
		of.gw = _gw
		of.gh = _gh
		of.col = _organic_color
		of.grid = grid
		container.add_child(of)
		_organic_floors.resize(maxi(_organic_floors.size(), f + 1))
		_organic_floors[f] = of
	else:
		var floor_node := Polygon2D.new()
		floor_node.color = FLOOR_COLOR
		floor_node.polygon = PackedVector2Array([
			Vector2(0, 0),
			Vector2(_gw * TILE, 0),
			Vector2(_gw * TILE, _gh * TILE),
			Vector2(0, _gh * TILE),
		])
		container.add_child(floor_node)

	for gy in _gh:
		for gx in _gw:
			if grid[gy][gx]:
				_add_wall(container, f, gx, gy)

	# Станции (они же чекпоинты)
	var cells := _passage_cells(f == 0)
	cells.shuffle()
	var area: int = _cols * _rows
	var density: float = float(GameConfig.station_count) / (16 * 10)
	var lvl_factor: float = 1.0 + (mini(_level, 6) - 1) * 0.25
	var scaled: int = max(GameConfig.station_count, int(area * density * lvl_factor))
	var count: int = mini(mini(scaled, MAX_STATIONS), cells.size())
	for i in count:
		var st := Area2D.new()
		st.set_script(load("res://station.gd"))
		st.game = self
		st.floor_index = f
		st.position = _cell_to_world(cells[i])
		container.add_child(st)

	# Осколки света (собираемые бонусы)
	var shard_cells := _passage_cells(f == 0)
	shard_cells.shuffle()
	var sc: int = mini(SHARDS_PER_FLOOR, shard_cells.size())
	for i in sc:
		var sh := Area2D.new()
		sh.set_script(load("res://shard.gd"))
		sh.game = self
		sh.position = _cell_to_world(shard_cells[i])
		container.add_child(sh)
		_shards_total += 1

# Битовая маска открытых сторон стены-клетки (gx,gy) на этаже f.
# Сторона «открыта», если соседняя клетка сетки — проход (grid==false).
# Выход за границы трактуем как стену (закрыто). N=1, E=2, S=4, W=8.
func _wall_open_mask(f: int, gx: int, gy: int) -> int:
	var grid: Array = _grids[f]
	var m := 0
	if gy - 1 >= 0 and not grid[gy - 1][gx]:
		m |= 1
	if gx + 1 < _gw and not grid[gy][gx + 1]:
		m |= 2
	if gy + 1 < _gh and not grid[gy + 1][gx]:
		m |= 4
	if gx - 1 >= 0 and not grid[gy][gx - 1]:
		m |= 8
	return m

# Текстура стены для маски (кэш на время постройки уровня; ~16 на этаж).
func _wall_texture(mask: int) -> Texture2D:
	if not _wall_tex_cache.has(mask):
		_wall_tex_cache[mask] = MazeTextures.make_wall_tile(int(TILE), mask, _wall_color)
	return _wall_tex_cache[mask]

func _add_wall(container: Node2D, f: int, gx: int, gy: int) -> void:
	var body := StaticBody2D.new()
	body.position = Vector2(gx * TILE + TILE * 0.5, gy * TILE + TILE * 0.5)

	var col := CollisionShape2D.new()
	var rect := RectangleShape2D.new()
	rect.size = Vector2(TILE, TILE)
	col.shape = rect
	body.add_child(col)

	var h := TILE * 0.5
	var square := PackedVector2Array([
		Vector2(-h, -h), Vector2(h, -h), Vector2(h, h), Vector2(-h, h),
	])

	# На органических уровнях стены не рисуем квадратами — форму тоннеля задаёт
	# скруглённый пол. Коллизия и окклюдер (тень) остаются.
	if not _organic:
		# Визуал: спрайт с beveled-текстурой (albedo+normal) по маске открытых сторон.
		# Ссылку храним в meta для быстрого обновления при изменениях лабиринта.
		var vis := Sprite2D.new()
		vis.texture = _wall_texture(_wall_open_mask(f, gx, gy))
		vis.light_mask = 3   # бит1: общий свет; бит2: отдельный «настенный» свет игрока
		body.add_child(vis)
		body.set_meta("vis", vis)

	var occ := LightOccluder2D.new()
	var occ_poly := OccluderPolygon2D.new()
	occ_poly.polygon = square
	occ_poly.closed = true
	occ.occluder = occ_poly
	body.add_child(occ)

	container.add_child(body)
	_wall_nodes[Vector3i(f, gx, gy)] = body

func _place_doors() -> void:
	var pairs: int = clampi(GameConfig.door_pairs, 1, 4)
	for f in range(_floors - 1):
		var cells := _passage_cells(true)
		cells.shuffle()
		for p in mini(pairs, cells.size()):
			var c: Vector2i = cells[p]
			var local := _cell_to_world(c)
			# Первая пара (p == 0) всегда открыта — гарантированный путь.
			# Остальные заперты и требуют осколок-ключ.
			var lock := p > 0
			var d_a := _make_door(local + Vector2(0, f * _floor_gap), _floor_gap, f + 1, lock)
			var d_b := _make_door(local + Vector2(0, (f + 1) * _floor_gap), -_floor_gap, f, lock)
			d_a.partner = d_b
			d_b.partner = d_a
			# Запоминаем переход между этажами для поиска пути «Искрой»
			var na := Vector3i(f, c.x, c.y)
			var nb := Vector3i(f + 1, c.x, c.y)
			if not _door_links.has(na):
				_door_links[na] = []
			_door_links[na].append(nb)
			if not _door_links.has(nb):
				_door_links[nb] = []
			_door_links[nb].append(na)

func _make_door(pos: Vector2, dy: float, target_floor: int, locked: bool) -> Area2D:
	var d := Area2D.new()
	d.set_script(load("res://door.gd"))
	d.delta_y = dy
	d.target_floor = target_floor
	d.game = self
	d.locked = locked
	# Перегенерация — только если дверей не меньше 4 (иначе искать проход слишком тяжело)
	var regen_ok: bool = GameConfig.door_regen_enabled and GameConfig.door_pairs >= 4
	d.regen_chance = GameConfig.door_regen_chance if regen_ok else 0.0
	d.position = pos
	add_child(d)
	return d

func _place_exit() -> void:
	var lf := _floors - 1
	var c := _farthest_cell(_grids[lf])
	_exit_cell = c
	_exit_floor = lf
	var exit := Area2D.new()
	exit.set_script(load("res://exit.gd"))
	exit.game = self
	exit.position = _cell_to_world(c) + Vector2(0, lf * _floor_gap)
	add_child(exit)

func _spawn_player() -> void:
	_player = preload("res://player.tscn").instantiate()
	_player.speed = GameConfig.player_speed
	_player.drain_per_sec = GameConfig.drain_per_sec * _drain_mult
	_player.max_energy = GameConfig.max_energy
	_player.position = _cell_to_world(Vector2i(0, 0))
	add_child(_player)

	_cp_floor = 0
	_cp_pos = _player.position

func _farthest_cell(grid: Array) -> Vector2i:
	var start := Vector2i(0, 0)
	var dist := {start: 0}
	var queue: Array[Vector2i] = [start]
	var best := start
	var best_d := 0
	while not queue.is_empty():
		var c: Vector2i = queue.pop_front()
		if dist[c] > best_d:
			best_d = dist[c]
			best = c
		for d in [Vector2i(1, 0), Vector2i(-1, 0), Vector2i(0, 1), Vector2i(0, -1)]:
			var n: Vector2i = c + d
			if n.x < 0 or n.x >= _cols or n.y < 0 or n.y >= _rows or dist.has(n):
				continue
			var mx := c.x + n.x + 1
			var my := c.y + n.y + 1
			if not grid[my][mx]:
				dist[n] = dist[c] + 1
				queue.append(n)
	return best

func _passage_cells(exclude_start: bool) -> Array[Vector2i]:
	var arr: Array[Vector2i] = []
	for cy in _rows:
		for cx in _cols:
			if exclude_start and cx == 0 and cy == 0:
				continue
			arr.append(Vector2i(cx, cy))
	return arr

func _cell_to_world(cell: Vector2i) -> Vector2:
	var gx := cell.x * 2 + 1
	var gy := cell.y * 2 + 1
	return Vector2(gx * TILE + TILE * 0.5, gy * TILE + TILE * 0.5)

func _grid_to_world(gx: int, gy: int, f: int) -> Vector2:
	return Vector2(gx * TILE + TILE * 0.5, gy * TILE + TILE * 0.5) + Vector2(0, f * _floor_gap)

# Соседние клетки-проходы для поиска пути «Искрой»: открытые проходы текущего
# этажа + переходы через двери на соседние этажи. node = Vector3i(этаж, cx, cy).
func _cell_neighbors(node: Vector3i) -> Array:
	var res: Array = []
	var f: int = node.x
	var cx: int = node.y
	var cy: int = node.z
	var grid: Array = _grids[f]
	for d in [Vector2i(1, 0), Vector2i(-1, 0), Vector2i(0, 1), Vector2i(0, -1)]:
		var nx: int = cx + d.x
		var ny: int = cy + d.y
		if nx < 0 or nx >= _cols or ny < 0 or ny >= _rows:
			continue
		# стена между клетками — на серединной координате сетки; false = проход
		if not grid[cy + ny + 1][cx + nx + 1]:
			res.append(Vector3i(f, nx, ny))
	if _door_links.has(node):
		for nb in _door_links[node]:
			res.append(nb)
	return res

# Кратчайший путь (мировые точки) от позиции игрока к выходу — для «Искры».
# BFS по клеткам всех этажей; путь обрезается по первому переходу на другой
# этаж, чтобы огонёк вёл по текущему этажу к нужной двери (или к выходу).
func guide_path_to_exit(from_pos: Vector2, from_floor: int) -> PackedVector2Array:
	if from_floor < 0 or from_floor >= _grids.size():
		return PackedVector2Array()
	var sx: int = clampi(int(round((from_pos.x / TILE - 1.5) / 2.0)), 0, _cols - 1)
	var sy: int = clampi(int(round(((from_pos.y - from_floor * _floor_gap) / TILE - 1.5) / 2.0)), 0, _rows - 1)
	var start := Vector3i(from_floor, sx, sy)
	var goal := Vector3i(_exit_floor, _exit_cell.x, _exit_cell.y)

	var prev := {}
	var visited := {start: true}
	var queue: Array[Vector3i] = [start]
	var found := false
	while not queue.is_empty():
		var cur: Vector3i = queue.pop_front()
		if cur == goal:
			found = true
			break
		for nb in _cell_neighbors(cur):
			if not visited.has(nb):
				visited[nb] = true
				prev[nb] = cur
				queue.append(nb)
	if not found:
		return PackedVector2Array()

	# Восстановить последовательность клеток start -> goal
	var cells: Array[Vector3i] = []
	var c: Vector3i = goal
	while c != start:
		cells.append(c)
		c = prev[c]
	cells.append(start)
	cells.reverse()

	# Мировые точки, обрезая по первому переходу на другой этаж
	var out := PackedVector2Array()
	out.append(from_pos)
	for cell in cells:
		if cell.x != from_floor:
			break
		out.append(_grid_to_world(cell.y * 2 + 1, cell.z * 2 + 1, from_floor))
	return out

func _mark_visited() -> void:
	if _player == null or not is_instance_valid(_player):
		return
	var f: int = _player.current_floor
	var px: float = _player.global_position.x
	var py: float = _player.global_position.y - f * _floor_gap
	var cx: int = int(round((px / TILE - 1.5) / 2.0))
	var cy: int = int(round((py / TILE - 1.5) / 2.0))
	if cx >= 0 and cx < _cols and cy >= 0 and cy < _rows:
		_visited[Vector3i(f, cx, cy)] = true

func _build_minimap_texture() -> ImageTexture:
	var img := Image.create_empty(_cols, _rows, false, Image.FORMAT_RGBA8)
	img.fill(Color(0.08, 0.08, 0.11, 1.0))
	var f: int = _player.current_floor if (_player and is_instance_valid(_player)) else 0
	var cur := Vector2i(-1, -1)
	if _player and is_instance_valid(_player):
		var px: float = _player.global_position.x
		var py: float = _player.global_position.y - f * _floor_gap
		cur = Vector2i(int(round((px / TILE - 1.5) / 2.0)), int(round((py / TILE - 1.5) / 2.0)))
	for key in _visited:
		if key.x == f and key.y >= 0 and key.y < _cols and key.z >= 0 and key.z < _rows:
			img.set_pixel(key.y, key.z, Color(0.5, 0.85, 0.7))
	if cur.x >= 0 and cur.x < _cols and cur.y >= 0 and cur.y < _rows:
		img.set_pixel(cur.x, cur.y, Color(1.0, 0.9, 0.4))
	return ImageTexture.create_from_image(img)

# --- Изменение структуры лабиринта ---

# Пересчитать маску и обновить текстуру стены-клетки (если она ещё стена).
func _refresh_wall_tile(f: int, gx: int, gy: int) -> void:
	if gx < 0 or gx >= _gw or gy < 0 or gy >= _gh:
		return
	var key := Vector3i(f, gx, gy)
	if not _wall_nodes.has(key):
		return   # проход — обновлять нечего
	var body: StaticBody2D = _wall_nodes[key]
	var vis = body.get_meta("vis", null)
	if vis:
		vis.texture = _wall_texture(_wall_open_mask(f, gx, gy))

func _set_wall(f: int, gx: int, gy: int, is_wall: bool) -> void:
	(_grids[f] as Array)[gy][gx] = is_wall
	var key := Vector3i(f, gx, gy)
	if is_wall:
		if not _wall_nodes.has(key):
			_add_wall(_floor_containers[f], f, gx, gy)
	else:
		if _wall_nodes.has(key):
			_wall_nodes[key].queue_free()
			_wall_nodes.erase(key)
	# Сторона у соседей изменилась — обновить их бевели (и свою, если осталась стеной).
	_refresh_wall_tile(f, gx, gy)
	_refresh_wall_tile(f, gx, gy - 1)
	_refresh_wall_tile(f, gx + 1, gy)
	_refresh_wall_tile(f, gx, gy + 1)
	_refresh_wall_tile(f, gx - 1, gy)
	# На органических уровнях перерисовать тоннели этого этажа.
	if _organic and f < _organic_floors.size() and is_instance_valid(_organic_floors[f]):
		_organic_floors[f].queue_redraw()

# Путь между двумя клетками-проходами по текущему дереву (в координатах сетки),
# возвращает список рёбер-стен на пути. Ребро exclude игнорируется.
func _path_edges(grid: Array, a: Vector2i, b: Vector2i, exclude: Vector2i) -> Array:
	var prev := {}
	var visited := {a: true}
	var queue: Array[Vector2i] = [a]
	while not queue.is_empty():
		var c: Vector2i = queue.pop_front()
		if c == b:
			break
		for d in [Vector2i(2, 0), Vector2i(-2, 0), Vector2i(0, 2), Vector2i(0, -2)]:
			var n: Vector2i = c + d
			if n.x < 1 or n.x >= _gw - 1 or n.y < 1 or n.y >= _gh - 1:
				continue
			var edge := Vector2i((c.x + n.x) / 2, (c.y + n.y) / 2)
			if edge == exclude or grid[edge.y][edge.x] or visited.has(n):
				continue
			visited[n] = true
			prev[n] = [c, edge]
			queue.append(n)
	if not visited.has(b):
		return []
	var edges: Array = []
	var cur: Vector2i = b
	while cur != a:
		var pe = prev[cur]
		edges.append(pe[1])
		cur = pe[0]
	return edges

# Случайное событие: открыть одно ребро и закрыть другое на образовавшемся
# цикле — лабиринт меняется, но остаётся проходимым (остаётся деревом).
func _maze_shift() -> void:
	if _player == null:
		return
	var f: int = _player.current_floor
	if f < 0 or f >= _grids.size():
		return
	var grid: Array = _grids[f]

	var closed: Array = []
	for gy in range(1, _gh - 1):
		for gx in range(1, _gw - 1):
			if not grid[gy][gx]:
				continue
			# ребро между двумя проходами: ровно одна координата чётная
			if (gx % 2 == 0) == (gy % 2 == 0):
				continue
			closed.append(Vector2i(gx, gy))
	if closed.is_empty():
		return
	closed.shuffle()
	var opened: Vector2i = closed[0]

	var a: Vector2i
	var b: Vector2i
	if opened.x % 2 == 0:
		a = Vector2i(opened.x - 1, opened.y)
		b = Vector2i(opened.x + 1, opened.y)
	else:
		a = Vector2i(opened.x, opened.y - 1)
		b = Vector2i(opened.x, opened.y + 1)

	var path := _path_edges(grid, a, b, opened)
	if path.is_empty():
		return

	_set_wall(f, opened.x, opened.y, false)  # открыли проход

	# закрыть ребро на пути, не вплотную к игроку
	path.shuffle()
	var to_close: Vector2i = path[0]
	for e in path:
		if _grid_to_world(e.x, e.y, f).distance_to(_player.global_position) > TILE * 2.0:
			to_close = e
			break
	_set_wall(f, to_close.x, to_close.y, true)

# Полная перегенерация этажа (для события у дверей).
# Постройка разбита на кадры, чтобы не было фриза на больших лабиринтах.
func regenerate_floor(f: int) -> void:
	if f < 0 or f >= _grids.size() or f >= _floor_containers.size():
		return
	for key in _wall_nodes.keys():
		if key.x == f:
			_wall_nodes[key].queue_free()
			_wall_nodes.erase(key)
	var grid := _make_grid()
	_grids[f] = grid
	# Сбрасываем пройденный путь этого этажа — карта обнуляется
	for vk in _visited.keys():
		if vk.x == f:
			_visited.erase(vk)
	# На органических уровнях обновить тоннели под новую сетку
	if _organic and f < _organic_floors.size() and is_instance_valid(_organic_floors[f]):
		_organic_floors[f].grid = grid
		_organic_floors[f].queue_redraw()
	var container: Node2D = _floor_containers[f]
	var built := 0
	for gy in _gh:
		for gx in _gw:
			if grid[gy][gx]:
				_add_wall(container, f, gx, gy)
				built += 1
				if built % 100 == 0:
					await get_tree().process_frame
					if not is_instance_valid(container):
						return

# --- Игровые события ---

func set_checkpoint(floor_idx: int, pos: Vector2) -> void:
	_cp_floor = floor_idx
	_cp_pos = pos

func reveal(duration: float) -> void:
	_reveal_time = duration

# Апекс (форма guide): телепортация игрока к выходу.
# Полная форма телепортирует прямо к выходу; эхо — на полпути.
func apex_teleport_to_exit(full: bool) -> void:
	if _player == null or not is_instance_valid(_player):
		return
	var target := _cell_to_world(_exit_cell) + Vector2(0, _exit_floor * _floor_gap)
	if full:
		_player.global_position = target
		_player.current_floor = _exit_floor
	else:
		_player.global_position = _player.global_position.lerp(target, 0.5)
	_player.snap_camera()
	if _fx:
		_fx.flash(Color(1.0, 0.7, 0.3), 0.4)

func on_player_death() -> void:
	if _dead or _won or _game_over:
		return
	_lives -= 1
	_update_lives()

	# Резкий отклик на смерть: красная вспышка + сильная тряска
	if _fx:
		_fx.flash(Color(1.0, 0.2, 0.15), 0.55)
	if _player and is_instance_valid(_player):
		_player.add_shake(13.0, 0.5)

	if _lives <= 0:
		_game_over = true
		_msg_label.text = "ИГРА ОКОНЧЕНА\n\nR — заново   Esc — в меню"
		_msg_label.visible = true
		return

	_dead = true
	_msg_label.text = "Свет погас!  Осталось жизней: %d\nВозврат к последней станции…" % _lives
	_msg_label.visible = true
	await get_tree().create_timer(1.2).timeout
	if not is_instance_valid(_player):
		return
	_player.respawn(_cp_pos, _cp_floor)
	_msg_label.visible = false
	_dead = false

func _update_lives() -> void:
	if _lives_label:
		_lives_label.text = "Жизни: %d" % maxi(_lives, 0)

func collect_shard() -> void:
	_shards_collected += 1
	_keys += 1
	GameConfig.add_xp(75)   # 75 XP за каждый осколок
	_update_shards()
	# Сочный отклик: золотой всплеск по краям + короткая вспышка + лёгкая тряска
	if _fx:
		_fx.gold_pulse(1.5)
		_fx.flash(Color(1.0, 0.9, 0.55), 0.16)
	if _player and is_instance_valid(_player):
		_player.add_shake(4.0, 0.18)

func use_key() -> bool:
	if _keys > 0:
		_keys -= 1
		_update_shards()
		return true
	return false

func _update_shards() -> void:
	if _shards_label:
		_shards_label.text = "Осколки: %d / %d" % [_shards_collected, _shards_total]
	if _keys_label:
		_keys_label.text = "Ключи: %d" % _keys

func flash_message(text: String) -> void:
	if _toast_label:
		_toast_label.text = text
		_toast_label.visible = true
		_toast_time = 1.6

func on_player_win() -> void:
	if _won:
		return
	_won = true
	if _player:
		_player.active = false

	# Праздничный отклик: золотая вспышка и всплеск по краям
	if _fx:
		_fx.flash(Color(1.0, 0.85, 0.4), 0.4)
		_fx.gold_pulse(2.2)

	if _level < MAX_LEVEL:
		GameConfig.add_xp(400)   # 400 XP за завершение уровня
		GameConfig.level = _level + 1
		GameConfig.max_unlocked_level = maxi(GameConfig.max_unlocked_level, _level + 1)
		GameConfig.save_game()
		_win_label.text = "Уровень %d пройден!\nВремя: %.1f с" % [_level, _elapsed]
		_win_label.visible = true
		await get_tree().create_timer(1.6).timeout
		_restart()
	else:
		_win_label.text = "ПОБЕДА!\nВсе %d уровней пройдены\nВремя: %.1f с\n\nR — заново   Esc — в меню" % [MAX_LEVEL, _elapsed]
		_win_label.visible = true

# --- Интерфейс ---

func _make_skill_label(layer: CanvasLayer, y: int) -> Label:
	var lbl := Label.new()
	lbl.position = Vector2(28, y)
	lbl.add_theme_font_size_override("font_size", 17)
	layer.add_child(lbl)
	return lbl

func _build_screen_fx() -> void:
	_fx = CanvasLayer.new()
	_fx.set_script(load("res://screenfx.gd"))
	add_child(_fx)

func _build_touch_controls() -> void:
	var layer := CanvasLayer.new()
	layer.layer = 2
	add_child(layer)

	# Виртуальный джойстик (реагирует на левую половину экрана)
	_joystick = Control.new()
	_joystick.set_script(load("res://touch_joystick.gd"))
	_joystick.process_mode = Node.PROCESS_MODE_PAUSABLE
	layer.add_child(_joystick)

	var vw: float = get_viewport().get_visible_rect().size.x
	var vh: float = get_viewport().get_visible_rect().size.y

	# Кнопки навыков (справа снизу): Вспышка/Рывок/Сонар/Щит/Искра/Озарение
	var grid := GridContainer.new()
	grid.columns = 3
	grid.add_theme_constant_override("h_separation", 10)
	grid.add_theme_constant_override("v_separation", 10)
	grid.position = Vector2(vw - 350, vh - 190)
	grid.process_mode = Node.PROCESS_MODE_PAUSABLE
	layer.add_child(grid)

	grid.add_child(_make_touch_button("Вспышка", func(): _skill(0)))
	grid.add_child(_make_touch_button("Рывок", func(): _skill(1)))
	grid.add_child(_make_touch_button("Сонар", func(): _skill(2)))
	grid.add_child(_make_touch_button("Щит", func(): _skill(3)))
	grid.add_child(_make_touch_button("Искра", func(): _skill(4)))
	grid.add_child(_make_touch_button("Озарение", func(): _skill(5)))

	# Кнопка паузы (вверху по центру)
	var pause_btn := _make_touch_button("II", _toggle_pause)
	pause_btn.custom_minimum_size = Vector2(70, 44)
	pause_btn.position = Vector2(vw * 0.5 - 35, 6)
	pause_btn.process_mode = Node.PROCESS_MODE_PAUSABLE
	layer.add_child(pause_btn)

func _make_touch_button(text: String, on_pressed: Callable) -> Button:
	var b := Button.new()
	b.text = text
	b.custom_minimum_size = Vector2(108, 56)
	b.focus_mode = Control.FOCUS_NONE
	b.add_theme_font_size_override("font_size", 17)
	b.modulate = Color(1, 1, 1, 0.85)
	b.pressed.connect(on_pressed)
	return b

func _skill(which: int) -> void:
	if not (_player and is_instance_valid(_player)):
		return
	match which:
		0: _player._try_flash()
		1: _player._try_dash()
		2: _player._try_sonar()
		3: _player._try_shield()
		4: _player._try_guide()
		5: _player._try_reveal()

func _start_music() -> void:
	var stream = load("res://8-bit-music-1.mp3")
	if stream == null:
		return  # mp3 ещё не импортирован редактором — просто без музыки
	if stream is AudioStreamMP3:
		stream.loop = true   # зацикливаем трек
	_music = AudioStreamPlayer.new()
	_music.stream = stream
	_music.volume_db = -9.0   # фон, чтобы не перебивал эффекты
	_music.process_mode = Node.PROCESS_MODE_ALWAYS   # играет и на паузе
	add_child(_music)
	_music.play()

func _build_hud() -> void:
	# Слой тинта (под HUD, над миром)
	var fx := CanvasLayer.new()
	fx.layer = 1
	add_child(fx)

	_tint = ColorRect.new()
	_tint.set_anchors_preset(Control.PRESET_FULL_RECT)
	_tint.color = Color(0, 0, 0, 0)
	_tint.mouse_filter = Control.MOUSE_FILTER_IGNORE
	fx.add_child(_tint)

	var layer := CanvasLayer.new()
	layer.layer = 2
	add_child(layer)

	_level_label = Label.new()
	_level_label.text = "Уровень %d  (этажей: %d)" % [_level, _floors]
	_level_label.position = Vector2(16, 10)
	_level_label.add_theme_font_size_override("font_size", 20)
	layer.add_child(_level_label)

	_time_label = Label.new()
	_time_label.position = Vector2(16, 38)
	_time_label.add_theme_font_size_override("font_size", 20)
	layer.add_child(_time_label)

	var right_x: float = get_viewport().get_visible_rect().size.x - 190

	_lives_label = Label.new()
	_lives_label.position = Vector2(right_x, 12)
	_lives_label.add_theme_font_size_override("font_size", 22)
	_lives_label.add_theme_color_override("font_color", Color(1.0, 0.5, 0.5))
	layer.add_child(_lives_label)
	_update_lives()

	_shards_label = Label.new()
	_shards_label.position = Vector2(right_x, 42)
	_shards_label.add_theme_font_size_override("font_size", 20)
	_shards_label.add_theme_color_override("font_color", Color(1.0, 0.92, 0.5))
	layer.add_child(_shards_label)

	_keys_label = Label.new()
	_keys_label.position = Vector2(right_x, 68)
	_keys_label.add_theme_font_size_override("font_size", 20)
	_keys_label.add_theme_color_override("font_color", Color(0.9, 0.75, 0.4))
	layer.add_child(_keys_label)
	_update_shards()

	var bar_label := Label.new()
	bar_label.text = "Свет"
	bar_label.position = Vector2(16, 70)
	bar_label.add_theme_font_size_override("font_size", 16)
	layer.add_child(bar_label)

	_energy_bar = ProgressBar.new()
	_energy_bar.min_value = 0.0
	_energy_bar.max_value = 1.0
	_energy_bar.step = 0.001
	_energy_bar.show_percentage = false
	_energy_bar.value = 1.0
	_energy_bar.position = Vector2(70, 70)
	_energy_bar.custom_minimum_size = Vector2(280, 22)

	var bg := StyleBoxFlat.new()
	bg.bg_color = Color(0.12, 0.12, 0.16)
	bg.set_corner_radius_all(4)
	_energy_bar.add_theme_stylebox_override("background", bg)

	_energy_fill = StyleBoxFlat.new()
	_energy_fill.bg_color = Color(1.0, 0.85, 0.3)
	_energy_fill.set_corner_radius_all(4)
	_energy_bar.add_theme_stylebox_override("fill", _energy_fill)
	layer.add_child(_energy_bar)

	var skills_title := Label.new()
	skills_title.text = "Навыки:"
	skills_title.position = Vector2(16, 104)
	skills_title.add_theme_font_size_override("font_size", 16)
	skills_title.add_theme_color_override("font_color", Color(0.7, 0.7, 0.75))
	layer.add_child(skills_title)

	_skill_flash = _make_skill_label(layer, 128)
	_skill_dash = _make_skill_label(layer, 152)
	_skill_sonar = _make_skill_label(layer, 176)
	_skill_shield = _make_skill_label(layer, 200)
	_skill_guide = _make_skill_label(layer, 224)
	_skill_reveal = _make_skill_label(layer, 248)

	_prog_label = Label.new()
	_prog_label.position = Vector2(16, 280)
	_prog_label.add_theme_font_size_override("font_size", 15)
	_prog_label.add_theme_color_override("font_color", Color(0.6, 0.85, 0.7))
	layer.add_child(_prog_label)

	var hint := Label.new()
	hint.text = "P / Esc — пауза"
	hint.position = Vector2(16, 310)
	hint.add_theme_font_size_override("font_size", 14)
	hint.add_theme_color_override("font_color", Color(0.5, 0.5, 0.55))
	layer.add_child(hint)

	# XP / SP — строчка под подсказкой
	_sp_label = Label.new()
	_sp_label.position = Vector2(16, 332)
	_sp_label.add_theme_font_size_override("font_size", 13)
	_sp_label.add_theme_color_override("font_color", Color(1.0, 0.82, 0.3))
	layer.add_child(_sp_label)

	_xp_bar = ProgressBar.new()
	_xp_bar.min_value = 0
	_xp_bar.max_value = GameConfig.XP_PER_SP
	_xp_bar.show_percentage = false
	_xp_bar.position = Vector2(16, 352)
	_xp_bar.custom_minimum_size = Vector2(200, 10)
	var xb := StyleBoxFlat.new(); xb.bg_color = Color(0.08, 0.08, 0.15); xb.set_corner_radius_all(3)
	_xp_bar.add_theme_stylebox_override("background", xb)
	var xf := StyleBoxFlat.new(); xf.bg_color = Color(0.55, 0.42, 1.0); xf.set_corner_radius_all(3)
	_xp_bar.add_theme_stylebox_override("fill", xf)
	layer.add_child(_xp_bar)

	# Короткое сообщение (тост) — снизу по центру
	_toast_label = Label.new()
	_toast_label.visible = false
	_toast_label.set_anchors_preset(Control.PRESET_BOTTOM_WIDE)
	_toast_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_toast_label.position = Vector2(0, -80)
	_toast_label.add_theme_font_size_override("font_size", 24)
	_toast_label.add_theme_color_override("font_color", Color(1.0, 0.7, 0.4))
	layer.add_child(_toast_label)

	# Сообщение о событии (вверху по центру)
	_event_label = Label.new()
	_event_label.visible = false
	_event_label.set_anchors_preset(Control.PRESET_TOP_WIDE)
	_event_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_event_label.position = Vector2(0, 24)
	_event_label.add_theme_font_size_override("font_size", 28)
	layer.add_child(_event_label)

	# Сообщение о смерти
	_msg_label = Label.new()
	_msg_label.visible = false
	_msg_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_msg_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	_msg_label.add_theme_font_size_override("font_size", 36)
	_msg_label.add_theme_color_override("font_color", Color(1.0, 0.4, 0.4))
	_msg_label.set_anchors_preset(Control.PRESET_FULL_RECT)
	layer.add_child(_msg_label)

	# Экран победы
	_win_label = Label.new()
	_win_label.visible = false
	_win_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_win_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	_win_label.add_theme_font_size_override("font_size", 44)
	_win_label.add_theme_color_override("font_color", Color(1.0, 0.85, 0.3))
	_win_label.set_anchors_preset(Control.PRESET_FULL_RECT)
	layer.add_child(_win_label)

	_build_pause_overlay(layer)

func _build_pause_overlay(layer: CanvasLayer) -> void:
	_pause_overlay = Control.new()
	_pause_overlay.set_anchors_preset(Control.PRESET_FULL_RECT)
	_pause_overlay.visible = false
	_pause_overlay.process_mode = Node.PROCESS_MODE_ALWAYS
	layer.add_child(_pause_overlay)

	var bg := ColorRect.new()
	bg.set_anchors_preset(Control.PRESET_FULL_RECT)
	bg.color = Color(0.03, 0.03, 0.06, 0.9)
	_pause_overlay.add_child(bg)

	var center := CenterContainer.new()
	center.set_anchors_preset(Control.PRESET_FULL_RECT)
	_pause_overlay.add_child(center)

	var root := VBoxContainer.new()
	root.add_theme_constant_override("separation", 22)
	root.alignment = BoxContainer.ALIGNMENT_CENTER
	center.add_child(root)

	var title := Label.new()
	title.text = "ПАУЗА"
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	title.add_theme_font_size_override("font_size", 48)
	title.add_theme_color_override("font_color", Color(1.0, 0.85, 0.3))
	root.add_child(title)

	# Две колонки: слева карта + кнопки, справа информация.
	var cols := HBoxContainer.new()
	cols.add_theme_constant_override("separation", 56)
	cols.alignment = BoxContainer.ALIGNMENT_CENTER
	root.add_child(cols)

	# --- Левая колонка: карта и кнопки ---
	var left := VBoxContainer.new()
	left.add_theme_constant_override("separation", 12)
	cols.add_child(left)

	var map_title := Label.new()
	map_title.text = "Карта (пройденный путь)"
	map_title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	map_title.add_theme_font_size_override("font_size", 16)
	map_title.add_theme_color_override("font_color", Color(0.7, 0.7, 0.8))
	left.add_child(map_title)

	_minimap = TextureRect.new()
	_minimap.custom_minimum_size = Vector2(320, 200)
	_minimap.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	_minimap.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	_minimap.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	left.add_child(_minimap)

	# небольшой отступ между картой и кнопками
	var spacer := Control.new()
	spacer.custom_minimum_size = Vector2(0, 8)
	left.add_child(spacer)

	left.add_child(_make_overlay_button("Продолжить", _toggle_pause))
	left.add_child(_make_overlay_button("Навыки", _open_skills_menu))
	left.add_child(_make_overlay_button("Заново", _restart))
	left.add_child(_make_overlay_button("В меню", _goto_menu))

	# --- Правая колонка: информация ---
	var right := VBoxContainer.new()
	right.alignment = BoxContainer.ALIGNMENT_CENTER
	cols.add_child(right)

	_pause_info = Label.new()
	_pause_info.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_pause_info.add_theme_font_size_override("font_size", 18)
	right.add_child(_pause_info)

func _make_overlay_button(text: String, on_pressed: Callable) -> Button:
	var b := Button.new()
	b.text = text
	b.custom_minimum_size = Vector2(240, 44)
	b.add_theme_font_size_override("font_size", 22)
	b.pressed.connect(on_pressed)
	return b

func _update_reveal(lbl: Label, charge: float) -> void:
	if charge >= 1.0:
		lbl.text = "F  Озарение  [готово]"
		lbl.modulate = Color(1.0, 0.85, 0.3)
	else:
		lbl.text = "F  Озарение  %d%%" % int(charge * 100.0)
		lbl.modulate = Color(0.45, 0.45, 0.5)

func _update_skill(lbl: Label, name_text: String, cd: float, energy: float, cost: float) -> void:
	if cd > 0.05:
		lbl.text = "%s  (%.1f)" % [name_text, cd]
		lbl.modulate = Color(0.45, 0.45, 0.5)
	elif energy < cost:
		lbl.text = name_text
		lbl.modulate = Color(0.6, 0.4, 0.4)
	else:
		lbl.text = name_text
		lbl.modulate = Color(0.75, 0.9, 1.0)
