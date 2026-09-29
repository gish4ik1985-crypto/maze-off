extends SceneTree
# Постоянная проверка играбельности (план: аудит v5.5, пункт 2).
# Запуск: tools/verify.sh (он же делает бэкап/сверку сохранений и смоук).
# Проверяет не «объекты созданы», а играбельность: вход внутри сетки и не в
# стене, выход достижим BFS-ом. Каждый режим, обе сложности, boss_test_enabled.
# test_mode выставляется КАЖДЫЙ кадр — это сохраняемая настройка, и автолоад
# перезаписывает её при загрузке профиля (см. CLAUDE.md).

const WAIT_FRAMES := 10
var scenarios: Array = []
var idx := -1
var frames := 0
var started := false
var fails := 0
var checked := 0

func _init() -> void:
	for l in [1, 5, 10, 15, 20, 25, 30, 35, 40, 45, 49, 50]:
		scenarios.append({"name": "Уровни L%d Горящий" % l, "mode": "levels", "level": l, "diff": 1})
	for l in [1, 20, 30, 45, 50]:
		scenarios.append({"name": "Уровни L%d Пылающий" % l, "mode": "levels", "level": l, "diff": 2})
	for l in [5, 10, 30, 45, 50]:
		scenarios.append({"name": "Уровни L%d boss_test" % l, "mode": "levels", "level": l, "diff": 1, "boss_test": true})
	for l in range(1, 11):
		scenarios.append({"name": "Логово %d" % l, "mode": "lair", "level": l})
	for l in [1, 4, 7, 10, 13, 16, 19, 20]:
		scenarios.append({"name": "Пещеры %d" % l, "mode": "caves", "level": l})
	scenarios.append({"name": "Уровни L20 + тест-арена супербосса", "mode": "levels", "level": 20, "diff": 1, "sb_test": true})
	scenarios.append({"name": "Накал слот 0", "mode": "run"})

func _process(_d: float) -> bool:
	var gc = root.get_node("GameConfig")
	gc.test_mode = true
	if not started:
		started = true
		_next()
		return false
	frames += 1
	if frames == WAIT_FRAMES:
		if scenarios[idx].get("sb_test", false) and current_scene != null and current_scene.has_method("spawn_superboss_test"):
			current_scene.spawn_superboss_test()
		_check(scenarios[idx])
		_next()
	return false

func _next() -> void:
	frames = 0
	idx += 1
	if idx >= scenarios.size():
		print("VERIFY: проверено %d, провалов %d" % [checked, fails])
		quit(1 if fails > 0 else 0)
		return
	var s: Dictionary = scenarios[idx]
	var gc = root.get_node("GameConfig")
	gc.tutorial_mode = false
	gc.lair_mode = false
	gc.caves_mode = false
	gc.boss_test_enabled = bool(s.get("boss_test", false))
	gc.active_run = -1
	gc.difficulty = int(s.get("diff", 1))
	match s["mode"]:
		"levels":
			gc.level = int(s["level"])
		"lair":
			gc.lair_mode = true
			gc.lair_level = int(s["level"])
		"caves":
			gc.caves_mode = true
			gc.caves_level = int(s["level"])
		"run":
			gc.start_new_run(0)
	change_scene_to_file("res://main.tscn")

func _fail(name: String, why: String) -> void:
	fails += 1
	print("FAIL [%s] %s" % [name, why])

func _check(s: Dictionary) -> void:
	checked += 1
	var name: String = s["name"]
	var m = current_scene
	if m == null or not m.has_method("_cell_neighbors"):
		_fail(name, "сцена main не загрузилась")
		return
	if m._caves_graph_active:
		# Графовые Пещеры: клеточной сетки нет — достижимость = путь по графу.
		if m._cave_entry_node < 0 or m._cave_exit_node < 0:
			_fail(name, "нет входного/выходного узла графа")
		elif m._optimal_path_len <= 0:
			_fail(name, "выход недостижим по графу (optimal_path_len=%d)" % m._optimal_path_len)
		return
	if m._grids.is_empty():
		_fail(name, "сетка этажей пуста")
		return
	# Инвариант поля: четыре размера двигаются вместе (§27/§28/§37/§75 — все
	# четыре спавн-бага начинались с того, что они разошлись).
	if m._gw != m._cols * 2 + 1 or m._gh != m._rows * 2 + 1:
		_fail(name, "размеры поля разошлись: cols=%d rows=%d gw=%d gh=%d" % [m._cols, m._rows, m._gw, m._gh])
		return
	var e: Vector2i = m._entry_cell
	if not m._cell_is_open(m._grids[0], e):
		_fail(name, "вход %s вне сетки %dx%d или в стене" % [str(e), m._cols, m._rows])
		return
	var ex: Vector2i = m._exit_cell
	var ef: int = m._exit_floor
	if ef < 0 or ef >= m._grids.size() or not m._cell_is_open(m._grids[ef], ex):
		_fail(name, "выход %s (этаж %d) вне сетки или в стене" % [str(ex), ef])
		return
	var start := Vector3i(0, e.x, e.y)
	var goal := Vector3i(ef, ex.x, ex.y)
	var seen := {start: true}
	var q: Array = [start]
	while not q.is_empty():
		var c: Vector3i = q.pop_front()
		if c == goal:
			return
		for nb in m._cell_neighbors(c):
			if not seen.has(nb):
				seen[nb] = true
				q.append(nb)
	_fail(name, "выход %s этаж %d недостижим от входа %s" % [str(ex), ef, str(e)])
