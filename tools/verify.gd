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
var _saved_uses: Dictionary = {}
var checked := 0

func _init() -> void:
	_static_pending = true
	for l in [1, 5, 10, 15, 20, 25, 30, 35, 40, 45, 49, 50]:
		scenarios.append({"name": "Уровни L%d Горящий" % l, "mode": "levels", "level": l, "diff": 1})
	for l in [1, 20, 30, 45, 50]:
		scenarios.append({"name": "Уровни L%d Пылающий" % l, "mode": "levels", "level": l, "diff": 2})
	for l in [5, 10, 30, 45, 50]:
		scenarios.append({"name": "Уровни L%d boss_test" % l, "mode": "levels", "level": l, "diff": 1, "boss_test": true})
	# [AUDIT 05.10.2026 №1] Арена двери-босса: скрытый этаж обязан быть карманом
	# BOSS_ARENA_* (12×10), дополненным стенами до полного размера поля, а не
	# открытой комнатой размером с этаж. Регрессия-ловушка: _make_arena_grid
	# строит по _gw/_gh, поэтому подмена только _cols/_rows ломает форму.
	scenarios.append({"name": "Арена двери-босса: L20", "mode": "levels", "level": 20, "diff": 1, "boss_door": true})
	scenarios.append({"name": "Арена двери-босса: L45 мега", "mode": "levels", "level": 45, "diff": 1, "boss_door": true})
	# [AUDIT 05.10.2026 №3] «Подальше от старта» меряется от _entry_cell, не от
	# угла (0,0): на мега-уровнях вход случайный, дальняя-от-угла половина могла
	# содержать сам вход. Якорь проверяется функционально — по контракту самого
	# _far_spawn_cells (дальняя половина ИМЕННО от входа).
	scenarios.append({"name": "Спавн от входа: L45 мега", "mode": "levels", "level": 45, "diff": 1, "spawn_dist": true})
	for l in range(1, 11):
		scenarios.append({"name": "Логово %d" % l, "mode": "lair", "level": l})
	for l in [1, 4, 7, 10, 13, 16, 19, 20]:
		scenarios.append({"name": "Пещеры %d" % l, "mode": "caves", "level": l})
	scenarios.append({"name": "Уровни L20 + тест-арена супербосса", "mode": "levels", "level": 20, "diff": 1, "sb_test": true})
	scenarios.append({"name": "Накал слот 0", "mode": "run"})
	# [AUDIT 05.10.2026 №5] Спуск дня раньше не прогонялся вовсе (DAILY_SLOT=3:
	# дневной сид, жизнь/Накал собственного слота). test_mode снимает суточный
	# лимит, save_game подавлен — профиль не трогается.
	scenarios.append({"name": "Спуск дня", "mode": "daily"})
	# [v5.8] Накал: реликвия +1★ на глубинах, кратных 3, у навыка из кампании.
	for d in [3, 6, 9]:
		scenarios.append({"name": "Накал глубина %d: реликвия +1★" % d, "mode": "run_relic", "depth": d})
	scenarios.append({"name": "Накал глубина 4: реликвии нет", "mode": "run_relic", "depth": 4})
	# [v5.7] Реликвии: на каждом уровне расписания у «чистого» профиля лежит
	# ровно тот навык, что положен, и он достижим; пропущенный выдаётся у выхода.
	for l in [1, 2, 3, 4, 6, 9, 12, 16, 19, 22, 26]:
		scenarios.append({"name": "Реликвия L%d (новый профиль)" % l, "mode": "relic", "level": l})
	scenarios.append({"name": "Реликвия L9: пропущена -> выдача у выхода", "mode": "relic", "level": 9, "miss": true})
	# [v6.3, §84] Обучение: каждый урок строится играбельным (вход, выход, декорации),
	# а его шаги ВЫПОЛНИМЫ по порядку. Указатель кампании нарочно на 45.
	for i in 12:
		scenarios.append({"name": "Обучение: урок %d" % (i + 1), "mode": "tutorial", "lesson": i})
	# [v6.4, §85] Сообщения: очередь с приоритетами, угол экрана, отключаемые подсказки.
	scenarios.append({"name": "Сообщения: очередь и приоритеты", "mode": "levels", "level": 3, "diff": 1, "toast": true})
	# [v6.5, §86] Набор навыков: слоты, авто-взятие, гейт в игроке, Апекс из набора.
	scenarios.append({"name": "Набор навыков", "mode": "levels", "level": 3, "diff": 1, "loadout": true})
	# [v6.2, §83] Цена смерти: земля вне пятачка у станции теряется и 30 с не возвращается.
	scenarios.append({"name": "Цена смерти: L20 Горящий", "mode": "levels", "level": 20, "diff": 1, "death_price": true})
	# [v6.0] HUD «Фонарь»: с открытыми навыками ничего не вылезает за экран и не
	# налезает на панель навыков (баг v5.9: на 30-м уровне иконки лезли на шкалы).
	# Узкий экран (4:3 при высоте 720 = 960 px) headless не эмулирует: там visible
	# rect не подчиняется root.size, — поэтому ширина панели проверяется бюджетом.
	scenarios.append({"name": "HUD: все навыки открыты", "mode": "hud", "level": 30})

func _process(_d: float) -> bool:
	var gc = root.get_node("GameConfig")
	gc.test_mode = true
	if not started:
		started = true
		if _static_pending:
			_check_ladder_static()
			_check_mastery_model()
			_check_codex_unlock()
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
		"daily":
			gc.start_daily_run()
		"run_relic":
			# Кампанийный профиль: открыты Вспышка/Рывок/Тление/Сонар — забег входит с ними.
			for k in gc.skills_unlocked.keys():
				gc.skills_unlocked[k] = ["flash", "dash", "smother", "sonar"].has(k)
			gc.start_new_run(0)
			gc.level = int(s["depth"])
		"tutorial":
			gc.tutorial_mode = true
			gc.tutorial_lesson = int(s["lesson"])
			gc.level = 45
			_saved_uses = gc.skill_uses.duplicate()
		"hud":
			gc.level = int(s["level"])
			for k in gc.skills_unlocked.keys():
				gc.skills_unlocked[k] = true
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

# [v6.0] Кодекс открывается по мере игры (Codex.UNLOCK): таблица не должна ссылаться
# на несуществующее, «чистый» профиль видит только базовый набор, а «прошедший
# всё» — каждую статью (недостижимое условие = статья, которую не прочтут никогда).
func _check_codex_unlock() -> void:
	var gc = root.get_node("GameConfig")
	# Codex грузим ВО ВРЕМЯ работы, а не по class_name: его статические функции
	# читают автолоад GameConfig, а тот при компиляции этого скрипта ещё не
	# зарегистрирован («Identifier not found: GameConfig»).
	var cx = load("res://codex.gd")
	var known := {}
	for a in cx.ARTICLES:
		known["%s|%s" % [a["sec"], a["id"]]] = true
	known["progress|ladder"] = true   # собирается в menu.gd из LADDER
	var ladder_ids := {}
	for e in gc.LADDER:
		ladder_ids[str(e["id"])] = true
	for key in cx.UNLOCK.keys():
		if not known.has(key):
			_fail("Кодекс", "в UNLOCK статья «%s» не существует" % key)
		for tok in cx.UNLOCK[key]:
			var p: PackedStringArray = str(tok).split(":")
			var ok := false
			match p[0]:
				"ladder": ok = p.size() == 2 and ladder_ids.has(p[1])
				"enemy": ok = p.size() == 2 and (p[1] == "any" or (p[1].is_valid_int() and int(p[1]) >= 0 and int(p[1]) <= 5))
				"level": ok = p.size() == 2 and p[1].is_valid_int() and int(p[1]) >= 1 and int(p[1]) <= 50
				"mode": ok = p.size() == 2 and ["ember", "daily", "lair", "caves"].has(p[1])
				"stat": ok = p.size() == 3 and gc.stats.has(p[1]) and p[2].is_valid_int()
				"flag": ok = p.size() == 2 and ["apex", "superboss", "escalation"].has(p[1])
			if not ok:
				_fail("Кодекс", "«%s»: непонятное условие «%s»" % [key, tok])
	var saved_test = gc.test_mode
	var saved_seen = gc.ladder_seen.duplicate()
	var saved_skills = gc.skills_unlocked.duplicate()
	var saved_stats = gc.stats.duplicate()
	var saved_lvl = gc.max_unlocked_level
	var saved_met = gc.codex_met.duplicate()
	var saved_notified = gc.codex_notified.duplicate()
	gc.codex_notified = {}
	var saved_sb = gc.superboss_defeated
	gc.test_mode = false
	# «Чистый» профиль: открыты только статьи без правила.
	gc.ladder_seen = {}
	gc.codex_met = {}
	gc.superboss_defeated = false
	gc.max_unlocked_level = 1
	for k in gc.skills_unlocked.keys():
		gc.skills_unlocked[k] = gc.START_SKILLS.has(k)
	for k in gc.stats.keys():
		if str(k).begins_with("seen_t") or str(k) in ["levels_cleared", "shards_total", "best_depth"]:
			gc.stats[k] = 0
	if not cx.new_articles().is_empty():
		_fail("Кодекс", "чистый профиль: уже есть «новые» статьи (%d) — объявлять нечего" % cx.new_articles().size())
	var open_now := 0
	for a in cx.ARTICLES:
		var key2 := "%s|%s" % [a["sec"], a["id"]]
		var unlocked: bool = cx.is_unlocked(str(a["sec"]), str(a["id"]))
		if unlocked != (not cx.UNLOCK.has(key2)):
			_fail("Кодекс", "чистый профиль: «%s» %s" % [key2, "открыта, хотя у неё есть правило" if unlocked else "закрыта без правила"])
		if unlocked:
			open_now += 1
	if open_now < 6 or open_now > 14:
		_fail("Кодекс", "чистый профиль видит %d статей — ожидалось 6-14 (базовый набор)" % open_now)
	# Встреча в забеге: механика открывается по глубине, ladder_seen не трогается.
	for id in gc.LADDER_RUN_LEVEL.keys():
		gc.stats["best_depth"] = int(gc.LADDER_RUN_LEVEL[id])
		if not gc.ladder_met(str(id)):
			_fail("Кодекс", "«%s» не считается встреченной на глубине %d" % [id, gc.LADDER_RUN_LEVEL[id]])
		gc.stats["best_depth"] = 0
	# «Прошёл всё»: каждая статья достижима.
	gc.max_unlocked_level = 50
	for e in gc.LADDER:
		gc.ladder_seen[str(e["id"])] = true
	for k in gc.skills_unlocked.keys():
		gc.skills_unlocked[k] = true
	for t in 6:
		gc.stats["seen_t%d" % t] = 1
	gc.stats["levels_cleared"] = 99
	gc.stats["shards_total"] = 99
	gc.codex_met["escalation"] = true
	gc.superboss_defeated = true
	for a in cx.ARTICLES:
		if not cx.is_unlocked(str(a["sec"]), str(a["id"])):
			_fail("Кодекс", "после «прохождения всего» статья «%s|%s» всё равно закрыта" % [a["sec"], a["id"]])
	# Объявление: после «прохождения всего» новыми считаются все статьи с правилом,
	# после codex_announce (test_mode выключен, save_game не зовём: подменяем словарь) — ни одной.
	var ruled := 0
	for a in cx.ARTICLES:
		if cx.UNLOCK.has("%s|%s" % [a["sec"], a["id"]]):
			ruled += 1
	if cx.new_articles().size() != ruled:
		_fail("Кодекс", "новых статей %d, а с правилом %d" % [cx.new_articles().size(), ruled])
	for a in cx.ARTICLES:
		gc.codex_notified["%s|%s" % [a["sec"], a["id"]]] = true
	if not cx.new_articles().is_empty():
		_fail("Кодекс", "после объявления новые статьи всё ещё есть")
	gc.test_mode = saved_test
	gc.codex_notified = saved_notified
	gc.ladder_seen = saved_seen
	gc.skills_unlocked = saved_skills
	gc.stats = saved_stats
	gc.max_unlocked_level = saved_lvl
	gc.codex_met = saved_met
	gc.superboss_defeated = saved_sb
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

# HUD «Фонарь»: все видимые элементы внутри экрана, панель навыков ни на что
# не налезает и сама уместилась по ширине.
func _check_hud(name: String, m) -> void:
	var vp: Vector2 = root.get_visible_rect().size
	if m._hud_layer == null or m._skill_bar == null:
		_fail(name, "HUD не построен")
		return
	for c in m._hud_layer.find_children("*", "Control", true, false):
		var ctl := c as Control
		if not ctl.is_visible_in_tree():
			continue
		var r := ctl.get_global_rect()
		if r.size.x <= 0.0 or r.size.y <= 0.0:
			continue
		if r.position.x < -1.0 or r.position.y < -1.0 or r.end.x > vp.x + 1.0 or r.end.y > vp.y + 1.0:
			_fail(name, "элемент HUD %s (%s) вылез за экран %s: %s" % [ctl.name, ctl.get_class(), str(vp), str(r)])
	var dock := Rect2()
	var have := false
	for d in m.SKILL_DEFS:
		var ic: Control = m._skills_ui[d["id"]]["icon"]
		if not ic.visible:
			continue
		var ir := ic.get_global_rect()
		dock = ir if not have else dock.merge(ir)
		have = true
	if not have:
		_fail(name, "в панели навыков нет ни одной иконки")
		return
	# Бюджет ширины: с полным набором панель обязана влезть в экран 4:3 (960 px)
	# с полями по 16 — иначе на узком мониторе она вылезет за край.
	if dock.size.x > 928.0:
		_fail(name, "панель навыков шире бюджета 4:3: %.0f > 928" % dock.size.x)
	var others := {
		"орб": m._vitals, "уровень": m._level_label, "биом/этаж": m._sub_label,
		"сердца": m._lives_box, "осколки": m._shards_label, "ключи": m._keys_label,
		"время": m._time_label,
	}
	for k in others.keys():
		var oc: Control = others[k]
		if oc != null and oc.is_visible_in_tree() and dock.intersects(oc.get_global_rect()):
			_fail(name, "панель навыков %s налезает на «%s» %s" % [str(dock), k, str(oc.get_global_rect())])

# [§83] Смерть отдаёт тьме землю: вне пятачка у станции возврата клетки теряются
# (сила 0, «свежая потеря»), 30 секунд _claim их не возвращает, потом — возвращает.
# [v6.4, §85] Очередь сообщений: обычное ждёт, карточка прерывает и возвращает
# прерванное в очередь, подсказка при выключенных подсказках не показывается,
# очередь не длиннее TOAST_QUEUE_MAX, колонка стоит в левом углу под HUD.
func _check_toast(name: String, m) -> void:
	var gc = root.get_node("GameConfig")
	var was_hints: bool = gc.show_hints
	gc.show_hints = true
	m._toast_queue.clear()
	m._toast_show("первое", 1)
	m.flash_message("второе", 1)
	if m._toast_queue.size() != 1 or m._toast_label.text != "первое":
		_fail(name, "обычное сообщение должно ждать в очереди, а не затирать показанное")
	m.flash_message("карточка", 2)
	if m._toast_label.text != "карточка":
		_fail(name, "карточка должна прерывать показанное")
	if m._toast_queue.is_empty() or m._toast_queue[0]["text"] != "первое":
		_fail(name, "прерванное обычное сообщение должно вернуться в начало очереди")
	m.flash_message("карточка", 2)
	m.flash_message("второе", 1)
	if m._toast_queue.size() > m.TOAST_QUEUE_MAX:
		_fail(name, "очередь длиннее %d" % m.TOAST_QUEUE_MAX)
	for i in 8:
		m.flash_message("мусор %d" % i, 0)
	if m._toast_queue.size() > m.TOAST_QUEUE_MAX:
		_fail(name, "очередь подсказок не ограничена")
	m._toast_time = 0.01
	m._toast_next()
	if m._toast_cur_prio < 1:
		_fail(name, "после карточки должно идти обычное, а не подсказка")
	gc.show_hints = false
	m._toast_queue.clear()
	m._toast_panel.visible = false
	m.flash_message("подсказка", 0)
	if m._toast_panel.visible:
		_fail(name, "подсказка показана при выключенных подсказках")
	gc.show_hints = was_hints
	var pos: Vector2 = m._toast_col.position
	if pos.x > 40.0 or pos.y < m.HUD_BAND:
		_fail(name, "колонка сообщений не в левом углу под HUD: %s" % str(pos))
	m._toast_queue.clear()
	m._toast_panel.visible = false

# [v6.5, §86] Набор навыков.
func _check_loadout(name: String, m) -> void:
	var gc = root.get_node("GameConfig")
	var keep := {
		"lo": gc.loadout.duplicate(), "seen": gc.loadout_seen.duplicate(),
		"sk": gc.skills_unlocked.duplicate(), "mx": gc.max_unlocked_level,
		"uses": gc.skill_uses.duplicate(), "run": gc.active_run, "tut": gc.tutorial_mode,
	}
	# Слоты растут по кампании 2 -> 3 -> 4; в забеге 4; в обучении — всё.
	gc.active_run = -1
	gc.tutorial_mode = false
	for pair in [[1, 2], [7, 2], [gc.LOADOUT_SLOT3_LEVEL, 3], [gc.LOADOUT_SLOT4_LEVEL - 1, 3], [gc.LOADOUT_SLOT4_LEVEL, 4], [50, 4]]:
		gc.max_unlocked_level = int(pair[0])
		if gc.loadout_slots() != int(pair[1]):
			_fail(name, "слотов на уровне %d: %d, ожидалось %d" % [pair[0], gc.loadout_slots(), pair[1]])
	gc.active_run = 0
	if gc.loadout_slots() != 4:
		_fail(name, "в забеге слотов %d, ожидалось 4" % gc.loadout_slots())
	gc.active_run = -1
	# Авто-взятие: открытые навыки встают в свободные слоты, лишние — в запас.
	gc.max_unlocked_level = 1
	for k in gc.skills_unlocked.keys():
		gc.skills_unlocked[k] = false
	gc.skills_unlocked["flash"] = true
	gc.loadout = []
	gc.loadout_seen = []
	gc.loadout_auto()
	if gc.loadout != ["flash"]:
		_fail(name, "старт: в наборе %s, ожидалась одна Вспышка" % str(gc.loadout))
	gc.skills_unlocked["dash"] = true
	gc.skills_unlocked["smother"] = true
	gc.loadout_auto()
	if gc.loadout.size() != 2 or not gc.loadout.has("dash") or gc.loadout.has("smother"):
		_fail(name, "два слота: набор %s, ожидалось flash+dash, Тление в запасе" % str(gc.loadout))
	# Осознанно снятый навык сам не возвращается.
	gc.loadout_toggle("dash")
	gc.loadout_auto()
	if gc.loadout.has("dash"):
		_fail(name, "снятый навык вернулся в набор сам")
	# Гейт игрока: не в наборе — не срабатывает; в наборе — срабатывает.
	var p = m._player
	if p._skill_ready("smother") != gc.is_equipped("smother"):
		_fail(name, "гейт игрока не совпадает с набором")
	gc.loadout = ["flash"]
	if p._skill_ready("dash"):
		_fail(name, "Рывок вне набора считается готовым")
	gc.loadout_toggle("dash")
	if not p._skill_ready("dash"):
		_fail(name, "Рывок в наборе не считается готовым")
	if gc.loadout_toggle("smother") and gc.loadout.size() > gc.loadout_slots():
		_fail(name, "набор длиннее числа слотов")
	# Апекс берёт форму только из набора.
	gc.skills_unlocked["sonar"] = true
	gc.skill_uses["sonar"] = 500
	gc.loadout = ["flash", "dash"]
	if gc.top_mastered(1).has("sonar"):
		_fail(name, "Апекс взял форму навыка вне набора")
	gc.loadout = ["flash", "sonar"]
	if gc.top_mastered(1) != ["sonar"]:
		_fail(name, "Апекс не взял форму навыка из набора: %s" % str(gc.top_mastered(1)))
	# Вспышка для боя с Ядром встаёт сама.
	gc.loadout = ["dash", "sonar"]
	m._ensure_flash_for_boss()
	if not gc.loadout.has("flash") or gc.loadout.size() > gc.loadout_slots():
		_fail(name, "Вспышка не встала в набор для боя: %s" % str(gc.loadout))
	# Сенсорные кнопки строятся из набора + Апекс.
	gc.skills_unlocked["apex"] = true
	var ids: Array = m._touch_skill_ids()
	if ids.back() != "apex" or ids.size() != gc.loadout.size() + 1:
		_fail(name, "сенсорные кнопки не из набора: %s" % str(ids))
	# Сенсорная кнопка нажимается (и одно касание не срабатывает дважды).
	m._touch_layer = null
	m._build_touch_controls()
	if not m._touch_icons.has(gc.loadout[0]):
		_fail(name, "нет сенсорной кнопки для первого навыка набора")
	else:
		var ic: SkillHudIcon = m._touch_icons[gc.loadout[0]]
		var taps := [0]
		ic.tapped.connect(func() -> void: taps[0] += 1)
		var ev := InputEventMouseButton.new()
		ev.button_index = MOUSE_BUTTON_LEFT
		ev.pressed = true
		ic._gui_input(ev)
		ic._gui_input(ev)
		if taps[0] != 1:
			_fail(name, "сенсорная кнопка сработала %d раз(а) вместо одного" % taps[0])
	# Стойка света на сенсорном интерфейсе: «+» делает ярче, «−» тусклее.
	var stance_btn: Button = null
	for b in m._touch_layer.find_children("*", "Button", true, false):
		if (b as Button).text == "+":
			stance_btn = b
	if stance_btn == null:
		_fail(name, "нет сенсорной кнопки стойки света")
	else:
		var before: int = int(p.light_stance)
		p.light_stance = 1
		stance_btn.pressed.emit()
		if int(p.light_stance) != 2:
			_fail(name, "кнопка «+» не подняла стойку света")
		p.light_stance = before
	# Обучение: всё доступно.
	gc.tutorial_mode = true
	gc.loadout = []
	if not gc.is_equipped("sonar") or gc.loadout_slots() < 12:
		_fail(name, "в обучении навыки должны быть доступны все")
	gc.loadout = keep["lo"]
	gc.loadout_seen = keep["seen"]
	gc.skills_unlocked = keep["sk"]
	gc.max_unlocked_level = keep["mx"]
	gc.skill_uses = keep["uses"]
	gc.active_run = keep["run"]
	gc.tutorial_mode = keep["tut"]

func _check_death_price(name: String, m) -> void:
	var e: Vector2i = m._entry_cell
	var d: Dictionary = m._bfs_dist(m._grids[0], e)
	m._cp_pos = m._cell_to_world(e)
	m._cp_floor = 0
	var near: Array = []
	var far: Array = []
	for c in d.keys():
		if int(d[c]) > 8:
			continue
		var key := Vector3i(0, c.x, c.y)
		m._claim(key)
		if maxi(absi(c.x - e.x), absi(c.y - e.y)) <= m.DEATH_REFUGE_CELLS:
			near.append(key)
		else:
			far.append(key)
	if near.is_empty() or far.is_empty():
		_fail(name, "не нашлось клеток для проверки (рядом %d, далеко %d)" % [near.size(), far.size()])
		return
	var lost: int = m._dark_reclaims_ground()
	if lost < far.size():
		_fail(name, "потеряно %d клеток, ожидалось не меньше %d" % [lost, far.size()])
	for k in near:
		if not m.is_claimed(k):
			_fail(name, "пятачок у станции %s потерян — он должен остаться своим" % str(k))
			break
	for k in far:
		if m.is_claimed(k):
			_fail(name, "клетка %s осталась своей после смерти" % str(k))
			break
		if m.ground_danger(k) < 0.9:
			_fail(name, "потерянная клетка %s не «свежая потеря» (опасность %.2f)" % [str(k), m.ground_danger(k)])
			break
	m._claim(far[0])
	if m.is_claimed(far[0]):
		_fail(name, "тьма отдала клетку сразу — 30 секунд должны держаться")
	m._elapsed += m.DEATH_SCORCH_SECONDS + 1.0
	m._claim(far[0])
	if not m.is_claimed(far[0]):
		_fail(name, "после 30 секунд клетку нельзя вернуть")

# Симуляция выполнения шага обучения: выставляем ровно то состояние, которое
# проверяет main.gd::_tut_step_done (по одной ветке на тип условия).
func _tut_simulate(m, step: Dictionary) -> bool:
	var gc = root.get_node("GameConfig")
	var kind: String = str(step["done"])
	if kind.begins_with("skill:"):
		var id: String = kind.substr(6)
		gc.skill_uses[id] = int(gc.skill_uses.get(id, 0)) + 1
		return true
	match kind:
		"move": m._player.started = true
		"stance": m._tut_stance_changed = true
		"shard": m._shards_collected = 1
		"station": m.tutorial_station_used()
		"enemy":
			if m._tut_enemy == null or not is_instance_valid(m._tut_enemy):
				return false
			m._player.global_position = m._tut_enemy.global_position
		"claim":
			for k in 6:
				m._claim_time[Vector3i(0, k, 99)] = 0.0
		"draft":
			if m._draft_node == null or not is_instance_valid(m._draft_node):
				return false
			m._tut_draft_moved = true
			m._draft_node.emitting = true
		"combo": m._tut_combo_done = true
		"pit":
			if m._tut_pit == null or not is_instance_valid(m._tut_pit):
				return false
			m._player.global_position = m._tut_pit.global_position
			m._player._dash_time = 1.0
		"dark":
			if m._tut_darkstation == null or not is_instance_valid(m._tut_darkstation):
				return false
			m._tut_darkstation.active = false
		_:
			return false
	return true

# [v6.3, §84] Урок обучения: декорации на месте, последний шаг — выход, каждый
# остальной шаг сам собой НЕ выполнен, выполним симуляцией и переводит движок дальше.
func _check_tutorial(name: String, s: Dictionary, m) -> void:
	var tl = load("res://tutorial_lessons.gd")
	var lesson: Dictionary = tl.LESSONS[int(s["lesson"])]
	var extras: Array = lesson["extras"]
	if extras.has("enemy") and (m._tut_enemy == null or not is_instance_valid(m._tut_enemy)):
		_fail(name, "нужен враг, а его нет")
	if extras.has("dark") and (m._tut_darkstation == null or not is_instance_valid(m._tut_darkstation)):
		_fail(name, "нужна тёмная станция, а её нет")
	if extras.has("pit") and (m._tut_pit == null or not is_instance_valid(m._tut_pit)):
		_fail(name, "нужна яма, а её нет")
	var steps: Array = lesson["steps"]
	if str(steps[steps.size() - 1]["done"]) != "exit":
		_fail(name, "последний шаг урока должен быть «exit»")
	if m._cols != int(lesson["size"].x) or m._rows != int(lesson["size"].y):
		_fail(name, "размер лабиринта %dx%d, а в уроке %s" % [m._cols, m._rows, str(lesson["size"])])
	if m._level != 1:
		_fail(name, "уровень обучения %d, ожидался 1" % m._level)
	for i in steps.size() - 1:
		m._tut_step = i
		m._tut_lesson_time = 0.0
		if m._tut_step_done(steps[i]):
			_fail(name, "шаг %d («%s») выполнен сам собой до всякого действия" % [i + 1, steps[i]["done"]])
			return
		if not _tut_simulate(m, steps[i]):
			_fail(name, "шаг %d («%s»): нечем его симулировать (нет нужного объекта)" % [i + 1, steps[i]["done"]])
			return
		if not m._tut_step_done(steps[i]):
			_fail(name, "шаг %d («%s») не засчитался после выполнения" % [i + 1, steps[i]["done"]])
			return
		m._update_tutorial()
		if m._tut_step != i + 1:
			_fail(name, "движок не перешёл со шага %d на %d (остался на %d)" % [i + 1, i + 2, m._tut_step])
			return
		m._tut_lesson_time = 0.0
		m._tut_freeze = false
	root.get_node("GameConfig").skill_uses = _saved_uses.duplicate()

# [AUDIT 05.10.2026 №1] Форма арены двери-босса: карман BOSS_ARENA_* внутри
# поля нужного размера. (0,0) — вход игрока, открыт; клетка за карманом —
# стена (арена изолирована паддингом, GAMEDESIGN §28/§37).
func _check_boss_door(name: String, m) -> void:
	var bf: int = m._boss_floor
	if bf < 0 or bf >= m._grids.size():
		_fail(name, "арена двери-босса не создана (_boss_floor=%d)" % bf)
		return
	var arena: Array = m._grids[bf]
	if arena.size() != m._gh or (arena[0] as Array).size() != m._gw:
		_fail(name, "сетка арены не дополнена до поля: %dx%d != %dx%d"
			% [(arena[0] as Array).size(), arena.size(), m._gw, m._gh])
		return
	if not m._cell_is_open(arena, Vector2i(0, 0)):
		_fail(name, "клетка входа (0,0) арены — стена")
		return
	var outside := Vector2i(m.BOSS_ARENA_COLS + 1, m.BOSS_ARENA_ROWS + 1)
	if m._cell_is_open(arena, outside):
		_fail(name, "клетка %s за карманом арены открыта — арена не изолирована стенами" % str(outside))

# [AUDIT 05.10.2026 №3] Спавн «подальше от старта» обязан мериться от
# _entry_cell, не от угла (0,0) — на мега-уровнях вход случайный.
# Якорь _far_spawn_cells проверяется по его собственному контракту: всё
# возвращённое — дальней половина лабиринта ИМЕННО от входа (dist*2 > max).
# Элита (типы 3+): не ближе 8 манхэттана от входа (фильтр _spawn_elites).
func _check_spawn_dist(name: String, m) -> void:
	var grid: Array = m._grids[0]
	var dist: Dictionary = m._bfs_dist(grid, m._entry_cell)
	if dist.is_empty():
		_fail(name, "BFS от входа пуст")
		return
	var max_d := 0
	for k in dist.keys():
		max_d = maxi(max_d, int(dist[k]))
	var far: Array = m._far_spawn_cells(grid, 6)
	if far.is_empty():
		_fail(name, "_far_spawn_cells вернул пусто")
		return
	for c in far:
		if not dist.has(c) or int(dist[c]) * 2 <= max_d:
			_fail(name, "клетка врага %s не в дальней половине от входа — якорь не _entry_cell?" % str(c))
			return
	for e in m.get_tree().get_nodes_in_group("enemy"):
		if not is_instance_valid(e) or not ("enemy_type" in e):
			continue
		if int(e.enemy_type) >= 3 and int(e._enemy_floor) == 0:
			var cell: Vector2i = m._world_to_cell(e.global_position, 0)
			if absi(cell.x - m._entry_cell.x) + absi(cell.y - m._entry_cell.y) < 8:
				_fail(name, "элита %s ближе 8 манхэттана от входа" % str(cell))
				return

func _check(s: Dictionary) -> void:
	checked += 1
	var name: String = s["name"]
	var m = current_scene
	if s.get("boss_door", false) and m != null and m.has_method("_bfs_dist"):
		_check_boss_door(name, m)
	if s.get("spawn_dist", false) and m != null and m.has_method("_bfs_dist"):
		_check_spawn_dist(name, m)
	if s["mode"] == "tutorial" and m != null and m.has_method("_bfs_dist"):
		_check_tutorial(name, s, m)
	if s.get("toast", false) and m != null and m.has_method("_bfs_dist"):
		_check_toast(name, m)
	if s.get("loadout", false) and m != null and m.has_method("_bfs_dist"):
		_check_loadout(name, m)
	if s.get("death_price", false) and m != null and m.has_method("_bfs_dist"):
		_check_death_price(name, m)
	if s["mode"] == "hud" and m != null and m.has_method("_bfs_dist"):
		_check_hud(name, m)
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
