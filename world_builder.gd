extends RefCounted

# Вынесено из main.gd механически (tools/extract_fn.py, v6.8): код функций
# тот же, что был в main.gd; `g` — главный узел, все его члены с префиксом `g.`.
# Состояние остаётся в main.gd (переменные `_hud_layer`, `_vitals`, …).

static func _build_world(g) -> void:
	g._dark = CanvasModulate.new()
	g._dark.color = g._ambient
	g.add_child(g._dark)

	# Bloom: мягкий неоновый ореол вокруг ярких граней, кристаллов и света игрока.
	var env = Environment.new()
	env.background_mode = Environment.BG_CANVAS
	env.glow_enabled = GameConfig.quality >= 2   # [v5.7] высокое качество; иначе ≈0.9 мс/кадр экономии
	env.glow_intensity = 1.15
	env.glow_strength = 1.2
	env.glow_bloom = 0.32
	env.glow_blend_mode = Environment.GLOW_BLEND_MODE_ADDITIVE
	env.glow_hdr_threshold = 0.62
	env.glow_hdr_scale = 2.2
	for i in 7:
		env.set_glow_level(i, 1.0 if i >= 1 and i <= 3 else 0.0)
	var we = WorldEnvironment.new()
	we.environment = env
	g.add_child(we)

	# Босс-этаж: каждые BOSS_EVERY_N уровней в режиме Накал, или принудительно при тест-флаге.
	# Логово (свой центральный тронный зал) исключает оба этих случая.
	g._boss_level = not GameConfig.lair_mode and (
		(g._level > 0 and g._level % g.BOSS_EVERY_N == 0 and GameConfig.active_run >= 0)
		or GameConfig.boss_test_enabled)
	if g._boss_level:
		g._floors = 1
		g._adopt_field_size(g.BOSS_ARENA_COLS, g.BOSS_ARENA_ROWS)
		# [SPAWN-SAFETY 2026-07-29] Тот же баг, что уже чинили для арены
		# супербосса (GAMEDESIGN §27, баг 1): на мега-лабиринте (уровни 30+)
		# _entry_cell выбирается СЛУЧАЙНО по всему полю (до 60×48) задолго до
		# этой подмены размеров на арену 12×10 — и остаётся указывать наружу.
		# Игрок появлялся в пустоте: ни стен, ни станций, экран просто чёрный
		# (жалоба «открыл 49 уровень — темнота», тест-флаг боссов был включён).
		# Угол (1,1) свободен: рамка идёт по краю, ближайший пилон — в (3,2).
		g._entry_cell = Vector2i(1, 1)

	# Супербосс (§25): финал кампании «Уровни» (MAX_LEVEL), только там — не в
	# Накале/Спуске дня/Логове/обучении. Раньше был только тестовый вызов
	# spawn_superboss_test() — теперь это уровень 50 по-настоящему.
	g._superboss_level = (g._level == g.MAX_LEVEL and GameConfig.active_run < 0
		and not GameConfig.tutorial_mode and not GameConfig.lair_mode)
	# Деформация формы (обсуждалось 26.07.2026, до решения сделать ур.50
	# супербоссом): двойной овал — вместо обычного дерева проходов кольцевой
	# коридор почти по всему кругу до выхода. Примирено с супербоссом так:
	# 48-49 — целиком овальные уровни (single-floor, как и другие особые
	# уровни); 50 — овал на этаже 0 (крупнее, чем 49), а в конце кольца —
	# единственная дверь на отдельный этаж 1 с самой ареной супербосса.
	g._oval_level = g._level in g.OVAL_LEVELS and GameConfig.active_run < 0 \
		and not GameConfig.tutorial_mode and not GameConfig.lair_mode and not g._boss_level
	if g._oval_level:
		g._floors = 1
	if g._superboss_level:
		g._boss_level = false
		g._floors = 2
		g._adopt_field_size(g.SUPERBOSS_OVAL_COLS, g.SUPERBOSS_OVAL_ROWS)
		# _entry_cell переопределится после генерации овального этажа 0 ниже
		# (см. цикл построения сетки) — овал сам решает, где его «вход».

	g._wall_tex_cache.clear()
	g._side_cells.clear()
	g._side_pool.clear()          # спрайты пула умирают вместе с контейнерами этажей
	g._side_pool_parent = null
	# [TILEMAP-1.8] Новый TileSet на уровень (цвет стен/размеры не переживают
	# смену уровня — проще пересоздать, чем вычищать источники старого).
	g._wall_tileset = TileSet.new()
	g._wall_tileset.tile_size = Vector2i(int(g.TILE), int(g.TILE))
	g._wall_tileset.add_physics_layer()
	g._wall_tileset.add_occlusion_layer()
	g._wall_tile_source_id.clear()
	g._wall_invisible_source_id = -1
	g._floor_tilemaps.clear()
	g._grids.clear()
	g._floor_built.clear()

	# [§62, v.4.2] Пещеры: первая версия настоящих кротовых нор — граф
	# комнат-узлов (CaveGraph) вместо growing-tree сетки, см. GAMEDESIGN.md
	# §62. Полностью отдельная ветка, не общий код с сеточными режимами
	# ниже — нулевой риск для Уровней/Накала/Логова/арен/оврала: они
	# продолжают идти через клеточный путь без единой правки.
	if GameConfig.caves_mode:
		g._build_cave_floor_graph()
		return

	for f in g._floors:
		var grid: Array
		var is_oval_floor = false
		if g._superboss_level and f == 0:
			# Этаж 0 финала — овал (крупнее 48/49), с его дальнего конца дверь
			# ведёт на этаж 1 (см. _place_superboss_door).
			var oval: Dictionary = g._make_oval_grid(g._cols, g._rows)
			grid = oval["grid"]
			g._oval_entry = oval["entry"]
			g._oval_exit = oval["exit"]
			g._entry_cell = g._oval_entry
			is_oval_floor = true
		elif g._superboss_level and f == 1:
			# Этаж 1 финала — сама арена супербосса, размер которой меньше, чем
			# у овального этажа 0 (тот же приём паддинга, что и у обычной
			# дверь-боссовской арены в _setup_boss_door: BFS/маски стен требуют
			# единый формат координат для всех этажей уровня).
			var ares: Array = g._make_superboss_arena_grid(g.SUPERBOSS_ARENA_COLS, g.SUPERBOSS_ARENA_ROWS)
			grid = ares[0]
			g._strong_cells[f] = ares[1]
			while grid.size() < g._gh:
				var prow = []
				prow.resize(g._gw)
				for x in g._gw:
					prow[x] = true
				grid.append(prow)
			for y in grid.size():
				while (grid[y] as Array).size() < g._gw:
					(grid[y] as Array).append(true)
		elif g._boss_level:
			grid = g._make_arena_grid()
		elif f == 0 and g._oval_level:
			var oval2: Dictionary = g._make_oval_grid(g._cols, g._rows)
			grid = oval2["grid"]
			g._oval_entry = oval2["entry"]
			g._oval_exit = oval2["exit"]
			g._entry_cell = g._oval_entry
			is_oval_floor = true
		else:
			grid = g._make_grid()
		if g._lair_active:
			g._carve_boss_room(grid)
		# [GAMEDESIGN §17] Структурное разнообразие внутри уровня — не трогает
		# арену босса/Логово/супербосса (у них своя расчистка), обучение
		# (лабиринт и так маленький и должен быть предсказуемым для первого шага)
		# и овальные этажи (§1 — доп. карвинг сломал бы «почти по всему кругу»,
		# открыв срезки через кольцо).
		if not g._boss_level and not g._lair_active and not g._superboss_level and not GameConfig.tutorial_mode and not g._organic and not is_oval_floor:
			if g._cols >= 10 and g._rows >= 8:
				g._carve_rooms(grid)
			g._carve_zonal_density(grid)
			# [GAMEDESIGN §17.2] Биом-зависимая топология — поверх дерева-основы
			# (гарантия проходимости не портится, эти проходы только ДОБАВЛЯЮТ
			# связи, а не убирают их).
			g._apply_biome_topology(grid)
			# [§40] Скелет режем ПОСЛЕДНИМ: zonal density и топология биома
			# правят стены, и артерия, вырезанная до них, местами заросла бы.
			g._carve_spine(f, grid)
			# §5: только этаж входа, не хард-режим (там и так изменена экономика
			# света — лишний риск/сюрприз ни к чему) — после zonal density,
			# чтобы та не «съела» уже вырезанную комнату.
			if f == 0 and not g._hard:
				g._event_room_cell = g._carve_event_room(grid)
				if g._event_room_cell.x >= 0:
					# [GAMEDESIGN §26] Тип комнаты — по весам биома, а не ровной
					# лотереей из пяти: тема полосы уровней должна звучать и здесь.
					var room_base = {}
					for k in g.EVENT_ROOM_KINDS:
						room_base[k] = 1.0
					g._event_room_kind = g._weighted_pick(g._apply_biome_weights(room_base, "rooms"))
		g._grids.append(grid)
	# ВАЖНО: арену супербосса НЕЛЬЗЯ помечать _floor_is_arena — этот флаг
	# отключает и станции, и осколки разом (так сделано для арены дверь-босса).
	# По §25 станции зарядки на арене супербосса нужны (жалоба «не смог найти
	# станций зарядки»): бой длинный, а осколков тут нет. Осколки же наоборот
	# не нужны — они открывают портал-выход, которого на этом уровне нет
	# (победа = смерть босса). Разделение — в _spawn_floor_pickups.
	# Стены/станции/осколки строятся только для этажа входа сразу — остальные
	# этажи мега-лабиринта (до 6 этажей × 60×60 клеток) откладываются до первого
	# фактического спуска через дверь (ensure_floor_built), иначе уровень 30+
	# создаёт под сотню тысяч нод разом — и постройка, и выход в меню (freeing
	# всего этого дерева) занимают многие секунды. Данные сетки (_grids) для
	# путей/выхода/BFS считаются заранее и не требуют построенных нод.
	g._validate_entry_cell()
	g._ensure_floor_built(0)
	g._spawn_time_echoes()

	if g._boss_level:
		g._spawn_player()
		g._spawn_boss(0)
	elif g._superboss_level:
		g._spawn_player()
		# §1/§25: победа = смерть босса на этаже 1, как раньше — просто теперь
		# перед ней есть овальный этаж 0 (см. _place_superboss_door). Центр
		# арены на этаже 1 — условная цель для Искры/минимапы/BFS-путей.
		g._place_superboss_door()
		g._exit_cell = Vector2i(g.SUPERBOSS_ARENA_COLS / 2, g.SUPERBOSS_ARENA_ROWS / 2)
		g._exit_floor = 1
		g._draft_dirty = true   # [§72] выход переехал — поле тяги пересчитать
		g._compute_optimal_path_len()
		g.flash_message(GameConfig.tt(
			"☠ Кольцевой путь к финалу — иди по кольцу почти до конца, там дверь к стражу лабиринта",
			"☠ A ring path to the finale — follow the loop nearly all the way around, a door to the maze's guardian waits at the end"), 2)
	elif g._lair_active:
		g._spawn_player()
		# Тронный зал — геометрический центр лабиринта; Искра/Озарение/минимап
		# нацеливаются на него так же, как на обычный выход (тот же _exit_cell).
		g._exit_cell = Vector2i(g._cols / 2, g._rows / 2)
		g._exit_floor = 0
		g._draft_dirty = true   # [§72] выход переехал — поле тяги пересчитать
		g._compute_optimal_path_len()
		g._spawn_boss(0)
		g._lair_populate_enemies()
	else:
		g._place_doors()
		g._place_exit()
		g._spawn_player()
		g._place_relic()
		if g._level % 5 == 0 and g._level >= 5 and not GameConfig.tutorial_mode and not GameConfig.lair_mode and not GameConfig.caves_mode:
			g._setup_boss_door()
		g._compute_optimal_path_len()
		if GameConfig.darkness_chaser and g._level >= 4:
			g._spawn_enemies()
		# §5: контент событийной комнаты кладём ЗДЕСЬ, не сразу после
		# _ensure_floor_built(0) — _exit_cell/_exit_floor ещё не установлены
		# до _place_exit() (тот же класс проблемы с «протухшими» координатами,
		# что и с _entry_cell/_exit_cell в других местах, см. CLAUDE.md).
		g._populate_event_room()
