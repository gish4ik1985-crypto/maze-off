extends Control

# Главное меню: Играть / Настройки / Выход.
# Настройки правят синглтон GameConfig, который читает игра.

var _menu_box: VBoxContainer
var _settings_box: VBoxContainer
var _settings_scroll: ScrollContainer
var _level_box: VBoxContainer
var _passive_box: VBoxContainer
var _help_scroll: ScrollContainer

func _ready() -> void:
	set_anchors_preset(Control.PRESET_FULL_RECT)

	var bg := ColorRect.new()
	bg.color = Color(0.04, 0.04, 0.07)
	bg.set_anchors_preset(Control.PRESET_FULL_RECT)
	add_child(bg)

	var center := CenterContainer.new()
	center.set_anchors_preset(Control.PRESET_FULL_RECT)
	add_child(center)

	var root := VBoxContainer.new()
	root.add_theme_constant_override("separation", 18)
	root.alignment = BoxContainer.ALIGNMENT_CENTER
	center.add_child(root)

	var title := Label.new()
	title.text = "MAZE"
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	title.add_theme_font_size_override("font_size", 64)
	title.add_theme_color_override("font_color", Color(1.0, 0.85, 0.3))
	root.add_child(title)

	_build_menu(root)
	_build_level_select(root)
	_build_passives(root)
	_build_settings(root)
	_build_help(root)

func _build_menu(root: VBoxContainer) -> void:
	_menu_box = VBoxContainer.new()
	_menu_box.add_theme_constant_override("separation", 12)
	root.add_child(_menu_box)

	_menu_box.add_child(_make_button("Играть", _on_open_level_select))
	_menu_box.add_child(_make_button("Пассивки", _on_open_passives))
	_menu_box.add_child(_make_button("Настройки", _on_open_settings))
	_menu_box.add_child(_make_button("Справка", _on_open_help))
	_menu_box.add_child(_make_button("Выход", _on_quit))

func _build_settings(root: VBoxContainer) -> void:
	_settings_scroll = ScrollContainer.new()
	_settings_scroll.visible = false
	_settings_scroll.custom_minimum_size = Vector2(430, 480)
	_settings_scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	root.add_child(_settings_scroll)

	_settings_box = VBoxContainer.new()
	_settings_box.add_theme_constant_override("separation", 10)
	_settings_scroll.add_child(_settings_box)

	_add_slider("Ширина", 6, 40, 1, GameConfig.cols, true,
		func(v): GameConfig.cols = int(v))
	_add_slider("Высота", 4, 25, 1, GameConfig.rows, true,
		func(v): GameConfig.rows = int(v))
	_add_slider("Станций", 0, 15, 1, GameConfig.station_count, true,
		func(v): GameConfig.station_count = int(v))
	_add_slider("Скорость", 120, 600, 10, GameConfig.player_speed, true,
		func(v): GameConfig.player_speed = v)
	_add_slider("Запас света", 1.0, 3.0, 0.1, GameConfig.max_energy, false,
		func(v): GameConfig.max_energy = v)
	_add_slider("Разрядка/сек", 0.0, 0.2, 0.005, GameConfig.drain_per_sec, false,
		func(v): GameConfig.drain_per_sec = v)
	_add_slider("Темнота", 0.0, 0.2, 0.005, GameConfig.darkness, false,
		func(v): GameConfig.darkness = v)
	_add_slider("Дверей между этажами", 1, 4, 1, GameConfig.door_pairs, true,
		func(v): GameConfig.door_pairs = int(v))
	_add_slider("Жизни", 1, 9, 1, GameConfig.lives, true,
		func(v): GameConfig.lives = int(v))
	_add_slider("Шанс перегенерации, %", 0, 100, 5, GameConfig.door_regen_chance * 100.0, true,
		func(v): GameConfig.door_regen_chance = v / 100.0)

	_add_check("Случайные события", GameConfig.events_enabled,
		func(on): GameConfig.events_enabled = on)
	_add_check("Накопительные пассивки", GameConfig.progressive_enabled,
		func(on): GameConfig.progressive_enabled = on)
	_add_check("Перегенерация при переходе (от 4 дверей)", GameConfig.door_regen_enabled,
		func(on): GameConfig.door_regen_enabled = on)
	_add_check("Тьма-преследователь (с ур. 4)", GameConfig.darkness_chaser,
		func(on): GameConfig.darkness_chaser = on)

	_settings_box.add_child(_make_button("Назад", _on_close_settings))

func _add_check(text: String, value: bool, setter: Callable) -> void:
	var cb := CheckButton.new()
	cb.text = text
	cb.button_pressed = value
	cb.add_theme_font_size_override("font_size", 18)
	cb.toggled.connect(func(on): setter.call(on))
	_settings_box.add_child(cb)

func _make_button(text: String, on_pressed: Callable) -> Button:
	var b := Button.new()
	b.text = text
	b.custom_minimum_size = Vector2(280, 48)
	b.add_theme_font_size_override("font_size", 24)
	b.pressed.connect(on_pressed)
	return b

func _add_slider(name_text: String, mn: float, mx: float, step: float,
		val: float, is_int: bool, setter: Callable) -> void:
	var row := VBoxContainer.new()
	row.custom_minimum_size = Vector2(360, 0)

	var lbl := Label.new()
	var update := func(v: float) -> void:
		if is_int:
			lbl.text = "%s: %d" % [name_text, int(v)]
		else:
			lbl.text = "%s: %.3f" % [name_text, v]
	update.call(val)
	lbl.add_theme_font_size_override("font_size", 18)
	row.add_child(lbl)

	var slider := HSlider.new()
	slider.min_value = mn
	slider.max_value = mx
	slider.step = step
	slider.value = val
	slider.custom_minimum_size = Vector2(360, 0)
	slider.value_changed.connect(func(v):
		update.call(v)
		setter.call(v))
	row.add_child(slider)

	_settings_box.add_child(row)

func _build_level_select(root: VBoxContainer) -> void:
	_level_box = VBoxContainer.new()
	_level_box.add_theme_constant_override("separation", 14)
	_level_box.visible = false
	root.add_child(_level_box)

	var lbl := Label.new()
	lbl.text = "Выбери уровень"
	lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	lbl.add_theme_font_size_override("font_size", 28)
	lbl.add_theme_color_override("font_color", Color(0.85, 0.85, 1.0))
	_level_box.add_child(lbl)

	var note := Label.new()
	note.text = "Чем выше уровень — тем больше лабиринт, темнее, быстрее разрядка и чаще события.\nУровни 11-20 — органические лабиринты-«корни» с плавными тоннелями."
	note.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	note.add_theme_font_size_override("font_size", 15)
	note.add_theme_color_override("font_color", Color(0.6, 0.6, 0.7))
	_level_box.add_child(note)

	var grid := GridContainer.new()
	grid.columns = 10
	grid.add_theme_constant_override("h_separation", 8)
	grid.add_theme_constant_override("v_separation", 8)
	_level_box.add_child(grid)

	for i in 20:
		var lvl := i + 1
		var btn := Button.new()
		btn.text = "%d" % lvl
		btn.custom_minimum_size = Vector2(64, 50)
		btn.add_theme_font_size_override("font_size", 20)
		# Органические уровни (11-20) — землистым цветом
		if lvl >= 11:
			btn.add_theme_color_override("font_color", Color(0.85, 0.7, 0.45))
		btn.pressed.connect(func(): _on_play(lvl))
		grid.add_child(btn)

	_level_box.add_child(_make_button("Назад", _on_close_level_select))

func _build_passives(root: VBoxContainer) -> void:
	_passive_box = VBoxContainer.new()
	_passive_box.add_theme_constant_override("separation", 10)
	_passive_box.visible = false
	root.add_child(_passive_box)

	var lbl := Label.new()
	lbl.text = "Пассивные навыки"
	lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	lbl.add_theme_font_size_override("font_size", 28)
	lbl.add_theme_color_override("font_color", Color(0.85, 0.85, 1.0))
	_passive_box.add_child(lbl)

	var defs := [
		["save", "Энергосбережение", "разрядка света −30%"],
		["capacity", "Ёмкость", "максимальный заряд +30%"],
		["charge", "Быстрая зарядка", "станции заряжают +50%"],
		["range", "Дальний свет", "радиус свечения +25%"],
		["legs", "Лёгкие ноги", "скорость +15%"],
		["magic", "Эффективная магия", "навыки −30% цены, быстрее КД"],
	]
	for d in defs:
		var key: String = d[0]
		var cb := CheckButton.new()
		cb.text = "%s — %s" % [d[1], d[2]]
		cb.button_pressed = GameConfig.passives.get(key, false)
		cb.add_theme_font_size_override("font_size", 18)
		cb.toggled.connect(func(on): GameConfig.passives[key] = on)
		_passive_box.add_child(cb)

	_passive_box.add_child(_make_button("Назад", _on_close_passives))

func _on_open_passives() -> void:
	_menu_box.visible = false
	_passive_box.visible = true

func _on_close_passives() -> void:
	_passive_box.visible = false
	_menu_box.visible = true

func _build_help(root: VBoxContainer) -> void:
	_help_scroll = ScrollContainer.new()
	_help_scroll.visible = false
	_help_scroll.custom_minimum_size = Vector2(720, 520)
	_help_scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	root.add_child(_help_scroll)

	var box := VBoxContainer.new()
	box.add_theme_constant_override("separation", 10)
	_help_scroll.add_child(box)

	var title := Label.new()
	title.text = "Справка"
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	title.add_theme_font_size_override("font_size", 30)
	title.add_theme_color_override("font_color", Color(0.85, 0.85, 1.0))
	box.add_child(title)

	var body := Label.new()
	body.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	body.custom_minimum_size = Vector2(690, 0)
	body.add_theme_font_size_override("font_size", 17)
	body.text = _help_text()
	box.add_child(body)

	box.add_child(_make_button("Назад", _on_close_help))

func _on_open_help() -> void:
	_menu_box.visible = false
	_help_scroll.visible = true

func _on_close_help() -> void:
	_help_scroll.visible = false
	_menu_box.visible = true

func _help_text() -> String:
	return """ЦЕЛЬ ИГРЫ
Ты — белый светящийся шарик в полной темноте. Виден только небольшой круг вокруг тебя; стены отбрасывают тень, поэтому видно лишь то, что в прямой видимости. Нужно найти золотой ВЫХОД и дойти до него. Свет постоянно гаснет — если погаснет совсем, теряешь жизнь.

ЭТАЖИ И ВЫХОД
Уровень состоит из нескольких этажей-лабиринтов, расположенных «друг под другом». Выход всегда на самом нижнем этаже, поэтому пройти можно, только посетив все этажи.

ДВЕРИ
Серые двери — переходы между соседними этажами, работают в обе стороны. Их может быть несколько (настройка «Дверей между этажами»).
• Первая дверь между этажами всегда открыта.
• Остальные двери ЗАПЕРТЫ (оранжево-красные) — чтобы открыть, нужен осколок-ключ.

СТАНЦИИ ЗАРЯДКИ (зелёные)
Восстанавливают свет и служат точками сохранения: после гибели появляешься на последней посещённой станции. Если постоять на станции 5 секунд — копится навык «Озарение». Долгое стояние увеличивает радиус обзора.

ОСКОЛКИ СВЕТА (золотые)
Собираемые бонусы: дают немного заряда и идут в счётчик. Каждый осколок — это КЛЮЧ для запертой двери.

ЖИЗНИ
Несколько жизней на уровень (настройка). Свет погас — минус жизнь и возврат на станцию. Жизни кончились — игра окончена.

АКТИВНЫЕ НАВЫКИ (тратят свет, есть перезарядка)
• Q — Вспышка: яркий импульс, осмотреться вокруг.
• Shift — Рывок: быстрый рывок в сторону движения, оторваться от опасности.
• E — Сонар: кольцо света сквозь стены, разведка планировки за углами.
• C — Щит: на несколько секунд полностью останавливает разрядку и защищает от тьмы.
• F — Озарение: накопительный навык. Подсвечивает весь этаж на пару секунд. Копится на станциях.

ПАССИВНЫЕ НАВЫКИ (выбираются в меню «Пассивки»)
Энергосбережение (−30% разрядки), Ёмкость (+30% заряда), Быстрая зарядка (+50%), Дальний свет (+25% радиуса), Лёгкие ноги (+15% скорости), Эффективная магия (навыки дешевле и быстрее).

НАКОПИТЕЛЬНЫЕ ПАССИВКИ (растут в процессе игры)
• Разгон — скорость растёт по мере пройденного расстояния (до +30%).
• Адаптация — разрядка слабеет по мере выживания (до −30%).

СЛУЧАЙНЫЕ СОБЫТИЯ (с уровня 2)
• Просвет ✦ — бонус: вспышка обзора и немного заряда.
• Густой туман ≈ — радиус обзора падает.
• Утечка света ⚠ — свет тратится быстрее.
• Перебой света ⚡ — свечение мерцает.
• Сдвиг стен ▦ — лабиринт меняется (один проход закрывается, другой открывается; пройти всё равно можно).

ТЬМА-ПРЕСЛЕДОВАТЕЛЬ (с уровня 4)
Тёмно-фиолетовый сгусток медленно ползёт к тебе сквозь стены. Рядом с ним свет тратится быстрее, а вплотную он глушит зарядку станции. Противодействие: Щит (полностью защищает), Рывок (оторваться), станции (заряжайся и убегай). Ты гораздо быстрее — убежать можно.

ПЕРЕГЕНЕРАЦИЯ (опция, от 4 дверей)
Если включить, при переходе через дверь этаж может полностью пересобраться. Карта пройденного пути этого этажа при этом обнуляется.

КАРТА
В паузе (P или Esc) можно посмотреть карту текущего этажа — на ней виден только уже пройденный путь.

УРОВНИ
Всего 10 уровней. Чем выше — тем больше лабиринт, темнее, быстрее разрядка и чаще события.

УПРАВЛЕНИЕ
Стрелки — движение. Q / Shift / E / C / F — навыки. P или Esc — пауза. R — начать уровень заново."""

func _on_play(lvl: int = 1) -> void:
	GameConfig.level = lvl
	get_tree().change_scene_to_file("res://main.tscn")

func _on_open_level_select() -> void:
	_menu_box.visible = false
	_level_box.visible = true

func _on_close_level_select() -> void:
	_level_box.visible = false
	_menu_box.visible = true

func _on_open_settings() -> void:
	_menu_box.visible = false
	_settings_scroll.visible = true

func _on_close_settings() -> void:
	_settings_scroll.visible = false
	_menu_box.visible = true

func _on_quit() -> void:
	get_tree().quit()
