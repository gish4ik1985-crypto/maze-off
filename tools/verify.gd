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
var _static_pending := false
var checked := 0

func _init() -> void:
	_static_pending = true
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
	# [v5.8] Накал: реликвия +1★ на глубинах, кратных 3, у навыка из кампании.
	for d in [3, 6, 9]:
		scenarios.append({"name": "Накал глубина %d: реликвия +1★" % d, "mode": "run_relic", "depth": d})
	scenarios.append({"name": "Накал глубина 4: реликвии нет", "mode": "run_relic", "depth": 4})
	# [v5.7] Реликвии: на каждом уровне расписания у «чистого» профиля лежит
	# ровно тот навык, что положен, и он достижим; пропущенный выдаётся у выхода.
	for l in [1, 2, 3, 4, 6, 9, 12, 16, 19, 22, 26]:
		scenarios.append({"name": "Реликвия L%d (новый профиль)" % l, "mode": "relic", "level": l})
	scenarios.append({"name": "Реликвия L9: пропущена -> выдача у выхода", "mode": "relic", "level": 9, "miss": true})

func _process(_d: float) -> bool:
	var gc = root.get_node("GameConfig")
	gc.test_mode = true
	if not started:
		started = true
		if _static_pending:
			_check_ladder_static()
			_check_mastery_model()
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
		"run_relic":
			# Кампанийный профиль: открыты Вспышка/Рывок/Тление/Сонар — забег входит с ними.
			for k in gc.skills_unlocked.keys():
				gc.skills_unlocked[k] = ["flash", "dash", "smother", "sonar"].has(k)
			gc.start_new_run(0)
			gc.level = int(s["depth"])
		"relic":
			gc.level = int(s["level"])
			# Профиль «с нуля»: открыто то, что положено ДО этого уровня.
			for k in gc.skills_unlocked.keys():
				gc.skills_unlocked[k] = gc.START_SKILLS.has(k)
			for id in gc.RELIC_ORDER:
				var rl: int = gc.relic_level(id)
				if rl >= 0 and rl < int(s["level"]):
					gc.skills_unlocked[id] = true
	change_scene_to_file("res://main.tscn")

func _fail(name: String, why: String) -> void:
	fails += 1
	print("FAIL [%s] %s" % [name, why])

func _check_relic(name: String, s: Dictionary, m) -> void:
	var gc = root.get_node("GameConfig")
	var lvl: int = int(s["level"])
	var expect: String = ""
	for id in gc.RELIC_ORDER:
		if gc.relic_level(id) == lvl:
			expect = id
	if expect == "":
		if m._relic_skill != "":
			_fail(name, "на уровне %d реликвии быть не должно, а лежит «%s»" % [lvl, m._relic_skill])
		return
	if m._relic_skill != expect:
		_fail(name, "ожидалась реликвия «%s», а _relic_skill=«%s»" % [expect, m._relic_skill])
		return
	if m._relic_cell.x < 0:
		_fail(name, "реликвия «%s» не размещена (нет клетки)" % expect)
		return
	var d: Dictionary = m._bfs_dist(m._grids[0], m._entry_cell)
	if not m._cell_is_open(m._grids[0], m._relic_cell) or not d.has(m._relic_cell):
		_fail(name, "реликвия в стене или недостижима от входа: %s" % str(m._relic_cell))
		return
	if m._exit_floor == 0 and m._relic_cell == m._exit_cell:
		_fail(name, "реликвия лежит на выходе")
		return
	if bool(s.get("miss", false)):
		m._grant_missed_relic()
	else:
		m.relic_claimed(expect, true)
	if not gc.skills_unlocked.get(expect, false):
		_fail(name, "навык «%s» не выдан" % expect)

func _check_run_relic(name: String, s: Dictionary, m) -> void:
	var gc = root.get_node("GameConfig")
	var depth: int = int(s["depth"])
	if not gc.skills_unlocked.get("sonar", false):
		_fail(name, "забег не унаследовал навыки кампании (Сонар закрыт)")
		return
	if depth % 3 != 0:
		if m._relic_skill != "":
			_fail(name, "на глубине %d реликвии быть не должно" % depth)
		return
	if m._relic_skill == "" or m._relic_cell.x < 0:
		_fail(name, "на глубине %d реликвия не размещена" % depth)
		return
	var d: Dictionary = m._bfs_dist(m._grids[0], m._entry_cell)
	if not d.has(m._relic_cell):
		_fail(name, "реликвия недостижима от входа")
		return
	var sk: String = m._relic_skill
	var before: int = gc.mastery(sk)
	m.relic_claimed(sk, true)
	if gc.mastery(sk) != before + 1:
		_fail(name, "реликвия не дала +1★ навыку «%s» (%d -> %d)" % [sk, before, gc.mastery(sk)])
	# Алтарь в забеге не продаёт сами навыки: только звёзды, свет, жизнь.
	for o in m._altar_offers():
		if not (str(o["kind"]) in ["star", "light", "life"]):
			_fail(name, "алтарь предлагает неожиданный товар: %s" % str(o["id"]))

func _check_mastery_model() -> void:
	# Модель мастерства (§79): кампания до ★2, выше — ковка; звёзды забега временные.
	var gc = root.get_node("GameConfig")
	var saved_uses = gc.skill_uses.duplicate()
	var saved_forge = gc.forge_stars.duplicate()
	var saved_pts = gc.forge_pts
	var saved_unlocked = gc.skills_unlocked.duplicate()
	gc.active_run = -1
	gc.skills_unlocked["flash"] = true
	gc.skill_uses["flash"] = 1000
	gc.forge_stars = {}
	gc.forge_pts = 0
	if gc.mastery("flash") != 2:
		_fail("Мастерство", "в кампании базовое мастерство должно упираться в ★2, а не %d" % gc.mastery("flash"))
	if gc.try_buy_skill("flash"):
		_fail("Мастерство", "SP не должны усиливать кампанию выше ★2")
	gc.forge_pts = 100
	for i in 3:
		if not gc.forge_skill("flash"):
			_fail("Мастерство", "ковка ★%d не прошла" % (3 + i))
	if gc.mastery("flash") != 5:
		_fail("Мастерство", "после трёх ковок ожидалось ★5, а %d" % gc.mastery("flash"))
	if gc.forge_skill("flash"):
		_fail("Мастерство", "ковка выше ★5 не должна проходить")
	# Забег: старт ★0 от навыков забега + временная звезда, потом сброс.
	gc.forge_stars = {}
	gc.skill_uses["flash"] = 0
	gc.active_run = 0
	gc.relic_stars = {}
	if not gc.add_relic_star("flash") or gc.mastery("flash") != 1:
		_fail("Мастерство", "временная звезда забега не работает")
	gc.active_run = -1
	gc.relic_stars = {}
	gc.skill_uses = saved_uses
	gc.forge_stars = saved_forge
	gc.forge_pts = saved_pts
	gc.skills_unlocked = saved_unlocked
	checked += 1

func _check_ladder_static() -> void:
	# Порядок и шаг реликвий + правило §38 (механика внутри полосы владеющего биома).
	var gc = root.get_node("GameConfig")
	var prev := 0
	for id in gc.RELIC_ORDER:
		var l: int = gc.relic_level(id)
		if l <= prev:
			_fail("Лестница", "реликвии идут не по возрастанию: %s на %d после %d" % [id, l, prev])
		if l - prev < 3 and prev > 0:
			_fail("Лестница", "шаг между реликвиями меньше 3: %s на %d после %d" % [id, l, prev])
		if l in [5, 10, 15]:
			_fail("Лестница", "реликвия %s на уровне %d совпадает с первыми дарами боссов (5/10/15)" % [id, l])
		prev = l
	var biomes: Array = load("res://main.gd").BIOMES
	var span: int = load("res://main.gd").BIOME_SPAN
	var owner_key := {"shortcut": "shortcut", "pits": "pits", "dark_stations": "dark_stations", "mimics": "mimics", "herder": "herders"}
	for id in owner_key:
		var l2: int = gc.ladder_level(id)
		var ok := false
		var bi: int = int(maxi(l2 - 1, 0) / span) % biomes.size()
		if float(biomes[bi]["rules"].get(owner_key[id], 0.0)) > 0.0:
			ok = true
		if not ok:
			_fail("Лестница", "механика «%s» на уровне %d лежит в биоме, который ею не владеет" % [id, l2])
	checked += 1

func _check(s: Dictionary) -> void:
	checked += 1
	var name: String = s["name"]
	var m = current_scene
	if s["mode"] == "relic" and m != null and m.has_method("_bfs_dist"):
		_check_relic(name, s, m)
	elif s["mode"] == "run_relic" and m != null and m.has_method("_bfs_dist"):
		_check_run_relic(name, s, m)
		root.get_node("GameConfig").active_run = -1
		root.get_node("GameConfig").relic_stars = {}
		return
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
