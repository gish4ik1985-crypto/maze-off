extends Control

# Главное меню: Играть / Настройки / Выход.
# Настройки правят синглтон GameConfig, который читает игра.

var _menu_box: VBoxContainer
var _settings_box: VBoxContainer
var _settings_scroll: ScrollContainer
var _level_box: VBoxContainer
var _level_grid: GridContainer
var _passive_box: VBoxContainer
var _help_scroll: ScrollContainer
var _back_btn: Button

# Режим «Накал»: панель выбора слота-забега и брифинг.
var _runs_box: VBoxContainer
var _runs_slots_box: VBoxContainer
var _briefing_box: VBoxContainer
var _briefing_slot: int = 0

# Статистика
var _stats_scroll: ScrollContainer
var _stats_box: VBoxContainer

const LEVEL_COUNT := 20

var _unlock_baseline: int = 1  # честный прогресс, чтобы вернуть его при выключении переключателя

var _title: Label
var _title_glow: TextureRect
var _t: float = 0.0

func _ready() -> void:
	set_anchors_preset(Control.PRESET_FULL_RECT)

	# Фон: очень тёмный, загадочный; слабые неоновые ореолы + редкие искры
	var bg := ColorRect.new()
	bg.color = Color(0.012, 0.016, 0.032)
	bg.set_anchors_preset(Control.PRESET_FULL_RECT)
	add_child(bg)

	_add_bg_glow(Vector2(0.5, 0.27), Color(0.12, 0.5, 1.0), 760.0, 0.15)
	_add_bg_glow(Vector2(0.14, 0.88), Color(0.6, 0.22, 1.0), 600.0, 0.07)
	_add_bg_glow(Vector2(0.88, 0.84), Color(1.0, 0.45, 0.18), 600.0, 0.05)
	_add_motes()

	var center := CenterContainer.new()
	center.set_anchors_preset(Control.PRESET_FULL_RECT)
	add_child(center)

	var root := VBoxContainer.new()
	root.add_theme_constant_override("separation", 16)
	root.alignment = BoxContainer.ALIGNMENT_CENTER
	center.add_child(root)

	# Неоновый заголовок с ореолом
	var title_wrap := CenterContainer.new()
	title_wrap.custom_minimum_size = Vector2(560, 128)
	root.add_child(title_wrap)

	_title_glow = TextureRect.new()
	_title_glow.texture = MazeTextures.make_light(256)
	_title_glow.custom_minimum_size = Vector2(460, 190)
	_title_glow.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	_title_glow.stretch_mode = TextureRect.STRETCH_SCALE
	_title_glow.modulate = Color(0.18, 0.5, 0.95, 0.32)
	_title_glow.material = _additive()
	_title_glow.mouse_filter = Control.MOUSE_FILTER_IGNORE
	title_wrap.add_child(_title_glow)

	_title = Label.new()
	_title.text = "MAZE"
	_title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_title.add_theme_font_size_override("font_size", 76)
	_title.add_theme_color_override("font_color", Color(0.7, 0.85, 1.0))
	_title.add_theme_color_override("font_outline_color", Color(0.13, 0.4, 0.85))
	_title.add_theme_constant_override("outline_size", 6)
	title_wrap.add_child(_title)

	var subtitle := Label.new()
	subtitle.text = "лабиринт во тьме"
	subtitle.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	subtitle.add_theme_font_size_override("font_size", 18)
	subtitle.add_theme_color_override("font_color", Color(0.45, 0.62, 0.82))
	root.add_child(subtitle)

	_build_menu(root)
	_build_runs(root)
	_build_briefing(root)
	_build_stats(root)
	_build_level_select(root)
	_build_passives(root)
	_build_settings(root)
	_build_help(root)

	# Прокручиваемые панели не должны быть выше экрана: иначе CenterContainer
	# центрирует их и верх/низ (в т.ч. кнопка «Назад») уезжают за кадр.
	_fit_panels()
	get_viewport().size_changed.connect(_fit_panels)

	# Постоянная «← Назад» сверху-слева: видна в любом подразделе и не зависит от
	# прокрутки (раньше кнопка «Назад» терялась внизу длинного скролла).
	_back_btn = Button.new()
	_back_btn.text = "← Назад"
	_back_btn.visible = false
	_back_btn.focus_mode = Control.FOCUS_NONE
	_back_btn.custom_minimum_size = Vector2(130, 44)
	_back_btn.add_theme_font_size_override("font_size", 20)
	_style_button(_back_btn)
	_back_btn.set_anchors_preset(Control.PRESET_TOP_LEFT)
	_back_btn.offset_left = 20
	_back_btn.offset_top = 20
	_back_btn.pressed.connect(_go_back)
	add_child(_back_btn)

func _unhandled_input(event: InputEvent) -> void:
	if event is InputEventKey and event.pressed and not event.echo and event.keycode == KEY_ESCAPE:
		if _back_btn and _back_btn.visible:
			_go_back()
			get_viewport().set_input_as_handled()

# Единая точка возврата в корневое меню (кнопка сверху-слева, Esc и нижние «Назад»).
func _go_back() -> void:
	_level_box.visible = false
	_passive_box.visible = false
	_settings_scroll.visible = false
	_help_scroll.visible = false
	_runs_box.visible = false
	_briefing_box.visible = false
	_stats_scroll.visible = false
	_menu_box.visible = true
	if _back_btn:
		_back_btn.visible = false

func _fit_panels() -> void:
	# Место под заголовком MAZE + подзаголовком + отступами (~250px) с запасом.
	var vh: float = get_viewport().get_visible_rect().size.y
	var avail: float = max(220.0, vh - 300.0)
	_settings_scroll.custom_minimum_size.y = min(480.0, avail)
	_help_scroll.custom_minimum_size.y = min(520.0, avail)
	if _stats_scroll:
		_stats_scroll.custom_minimum_size.y = min(500.0, avail)

func _build_menu(root: VBoxContainer) -> void:
	_menu_box = VBoxContainer.new()
	_menu_box.add_theme_constant_override("separation", 12)
	root.add_child(_menu_box)

	_menu_box.add_child(_make_button("Играть", _on_open_runs))
	_menu_box.add_child(_make_button("Уровни", _on_open_level_select))
	_menu_box.add_child(_make_button("Статистика", _on_open_stats))
	_menu_box.add_child(_make_button("Настройки", _on_open_settings))
	_menu_box.add_child(_make_button("Справка", _on_open_help))
	_menu_box.add_child(_make_button("Сбросить прогресс", _on_reset_progress))
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

	# Тест: переключатель «открыть все уровни». При выключении возвращает
	# реальный прогресс, запомненный до разблокировки.
	_unlock_baseline = GameConfig.max_unlocked_level
	var unlock_all := CheckButton.new()
	unlock_all.text = "Разблокировать все уровни"
	unlock_all.button_pressed = GameConfig.max_unlocked_level >= LEVEL_COUNT
	unlock_all.add_theme_font_size_override("font_size", 18)
	unlock_all.toggled.connect(_on_unlock_toggled)
	_settings_box.add_child(unlock_all)

	_settings_box.add_child(_make_button("Назад", _on_close_settings))

func _on_unlock_toggled(on: bool) -> void:
	if on:
		# Запомнить честный прогресс перед открытием всех уровней.
		if GameConfig.max_unlocked_level < LEVEL_COUNT:
			_unlock_baseline = GameConfig.max_unlocked_level
		GameConfig.max_unlocked_level = LEVEL_COUNT
	else:
		GameConfig.max_unlocked_level = _unlock_baseline
	GameConfig.save_game()
	_populate_levels()
	if on:
		_toast("Все %d уровней открыты" % LEVEL_COUNT)
	else:
		_toast("Уровни закрыты до %d" % GameConfig.max_unlocked_level)

# Короткое всплывающее сообщение по центру экрана.
func _toast(text: String) -> void:
	var lbl := Label.new()
	lbl.text = text
	lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	lbl.set_anchors_preset(Control.PRESET_CENTER_TOP)
	lbl.offset_top = 24
	lbl.offset_left = -260
	lbl.offset_right = 260
	lbl.add_theme_font_size_override("font_size", 22)
	lbl.add_theme_color_override("font_color", Color(0.7, 1.0, 0.85))
	lbl.add_theme_color_override("font_outline_color", Color(0.0, 0.25, 0.15))
	lbl.add_theme_constant_override("outline_size", 5)
	lbl.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(lbl)
	var tw := create_tween()
	tw.tween_interval(1.2)
	tw.tween_property(lbl, "modulate:a", 0.0, 0.6)
	tw.tween_callback(lbl.queue_free)

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
	b.custom_minimum_size = Vector2(300, 50)
	b.add_theme_font_size_override("font_size", 24)
	b.pressed.connect(on_pressed)
	_style_button(b)
	return b

# --- Неоновое оформление ---

func _additive() -> CanvasItemMaterial:
	var m := CanvasItemMaterial.new()
	m.blend_mode = CanvasItemMaterial.BLEND_MODE_ADD
	return m

func _add_bg_glow(anchor: Vector2, col: Color, sz: float, alpha: float) -> void:
	var g := TextureRect.new()
	g.texture = MazeTextures.make_light(256)
	g.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	g.stretch_mode = TextureRect.STRETCH_SCALE
	g.modulate = Color(col.r, col.g, col.b, alpha)
	g.material = _additive()
	g.mouse_filter = Control.MOUSE_FILTER_IGNORE
	g.anchor_left = anchor.x; g.anchor_right = anchor.x
	g.anchor_top = anchor.y; g.anchor_bottom = anchor.y
	g.offset_left = -sz * 0.5; g.offset_right = sz * 0.5
	g.offset_top = -sz * 0.5; g.offset_bottom = sz * 0.5
	add_child(g)

func _add_motes() -> void:
	var vp := get_viewport().get_visible_rect().size
	var p := CPUParticles2D.new()
	p.texture = MazeTextures.make_ball(4, Color(1, 1, 1))
	p.amount = 38
	p.lifetime = 7.0
	p.preprocess = 4.0
	p.position = vp * 0.5
	p.emission_shape = CPUParticles2D.EMISSION_SHAPE_RECTANGLE
	p.emission_rect_extents = vp * 0.5
	p.direction = Vector2(0, -1)
	p.spread = 22.0
	p.gravity = Vector2.ZERO
	p.initial_velocity_min = 7.0
	p.initial_velocity_max = 22.0
	p.scale_amount_min = 0.4
	p.scale_amount_max = 1.0
	var ramp := Gradient.new()
	ramp.offsets = PackedFloat32Array([0.0, 0.25, 1.0])
	ramp.colors = PackedColorArray([
		Color(0.4, 0.8, 1.0, 0.0), Color(0.45, 0.78, 1.0, 0.26), Color(0.45, 0.78, 1.0, 0.0)])
	p.color_ramp = ramp
	p.material = _additive()
	add_child(p)

func _style_button(b: Button) -> void:
	var normal := StyleBoxFlat.new()
	normal.bg_color = Color(0.035, 0.065, 0.11, 0.8)
	normal.set_border_width_all(2)
	normal.border_color = Color(0.18, 0.5, 0.82, 0.6)
	normal.set_corner_radius_all(8)
	normal.content_margin_left = 16
	normal.content_margin_right = 16
	normal.content_margin_top = 8
	normal.content_margin_bottom = 8
	var hover := normal.duplicate()
	hover.bg_color = Color(0.12, 0.26, 0.40, 0.95)
	hover.border_color = Color(0.5, 0.9, 1.0, 1.0)
	var pressed := normal.duplicate()
	pressed.bg_color = Color(0.2, 0.42, 0.58, 1.0)
	pressed.border_color = Color(0.7, 0.97, 1.0, 1.0)
	var disabled := normal.duplicate()
	disabled.bg_color = Color(0.05, 0.06, 0.09, 0.65)
	disabled.border_color = Color(0.2, 0.22, 0.28, 0.5)
	b.add_theme_stylebox_override("normal", normal)
	b.add_theme_stylebox_override("hover", hover)
	b.add_theme_stylebox_override("pressed", pressed)
	b.add_theme_stylebox_override("focus", hover)
	b.add_theme_stylebox_override("disabled", disabled)
	b.add_theme_color_override("font_color", Color(0.78, 0.93, 1.0))
	b.add_theme_color_override("font_hover_color", Color(1, 1, 1))
	b.add_theme_color_override("font_focus_color", Color(1, 1, 1))

func _process(delta: float) -> void:
	_t += delta
	if _title_glow:
		_title_glow.modulate.a = 0.26 + 0.09 * sin(_t * 2.0)

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
	note.text = "Чем выше уровень — тем больше лабиринт, темнее, быстрее разрядка и чаще события.\nЗакрытые уровни (🔒) откроются после прохождения предыдущего."
	note.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	note.add_theme_font_size_override("font_size", 15)
	note.add_theme_color_override("font_color", Color(0.6, 0.6, 0.7))
	_level_box.add_child(note)

	_level_grid = GridContainer.new()
	_level_grid.columns = 10
	_level_grid.add_theme_constant_override("h_separation", 8)
	_level_grid.add_theme_constant_override("v_separation", 8)
	_level_box.add_child(_level_grid)
	_populate_levels()

	_level_box.add_child(_make_button("Назад", _on_close_level_select))

func _populate_levels() -> void:
	for c in _level_grid.get_children():
		c.queue_free()
	for i in LEVEL_COUNT:
		var lvl := i + 1
		var btn := Button.new()
		btn.custom_minimum_size = Vector2(64, 50)
		btn.add_theme_font_size_override("font_size", 20)
		_style_button(btn)
		var unlocked: bool = lvl <= GameConfig.max_unlocked_level
		if unlocked:
			btn.text = "%d" % lvl
			# Органические уровни (11-20) — тёплым неоном
			if lvl >= 11:
				btn.add_theme_color_override("font_color", Color(1.0, 0.78, 0.4))
			btn.pressed.connect(func(): _on_play(lvl))
		else:
			btn.text = "🔒"
			btn.disabled = true
			btn.modulate = Color(0.5, 0.5, 0.55)
		_level_grid.add_child(btn)

# --- Режим «Накал»: слоты забегов и брифинг ---

func _build_runs(root: VBoxContainer) -> void:
	_runs_box = VBoxContainer.new()
	_runs_box.add_theme_constant_override("separation", 12)
	_runs_box.visible = false
	root.add_child(_runs_box)

	var lbl := Label.new()
	lbl.text = "НАКАЛ — спуск за светом"
	lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	lbl.add_theme_font_size_override("font_size", 30)
	lbl.add_theme_color_override("font_color", Color(1.0, 0.78, 0.4))
	_runs_box.add_child(lbl)

	var note := Label.new()
	note.text = "Рогалик-забег: каждый раз с нуля, 3 жизни на весь спуск, гибель — конец забега.\nВыбери слот: продолжить начатый или начать новый."
	note.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	note.add_theme_font_size_override("font_size", 15)
	note.add_theme_color_override("font_color", Color(0.72, 0.64, 0.52))
	_runs_box.add_child(note)

	_runs_slots_box = VBoxContainer.new()
	_runs_slots_box.add_theme_constant_override("separation", 10)
	_runs_box.add_child(_runs_slots_box)

	_runs_box.add_child(_make_button("Назад", _go_back))

func _populate_runs() -> void:
	for c in _runs_slots_box.get_children():
		c.queue_free()
	for i in GameConfig.RUN_SLOTS:
		var slot := i
		var s := GameConfig.run_summary(slot)
		var btn := Button.new()
		btn.custom_minimum_size = Vector2(440, 60)
		btn.add_theme_font_size_override("font_size", 20)
		_style_button(btn)
		match s["status"]:
			"active":
				btn.text = "Слот %d   ·   глубина %d   ·   ♥ %d   — продолжить" % [slot + 1, s["level"], s["lives"]]
				btn.add_theme_color_override("font_color", Color(0.72, 1.0, 0.82))
			"ended":
				btn.text = "Слот %d   ·   завершён, глубина %d   — новый забег" % [slot + 1, s["max_depth"]]
				btn.add_theme_color_override("font_color", Color(0.92, 0.62, 0.56))
			_:
				btn.text = "Слот %d   ·   пусто   — новый забег" % [slot + 1]
		btn.pressed.connect(func(): _on_run_slot_pressed(slot))
		_runs_slots_box.add_child(btn)

func _on_run_slot_pressed(slot: int) -> void:
	var s := GameConfig.run_summary(slot)
	if s["status"] == "active":
		GameConfig.resume_run(slot)
		_launch_game()
	else:
		_show_briefing(slot)

func _build_briefing(root: VBoxContainer) -> void:
	_briefing_box = VBoxContainer.new()
	_briefing_box.add_theme_constant_override("separation", 12)
	_briefing_box.visible = false
	root.add_child(_briefing_box)

	var lbl := Label.new()
	lbl.text = "Новый забег"
	lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	lbl.add_theme_font_size_override("font_size", 28)
	lbl.add_theme_color_override("font_color", Color(1.0, 0.82, 0.45))
	_briefing_box.add_child(lbl)

	var body := Label.new()
	body.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	body.custom_minimum_size = Vector2(560, 0)
	body.add_theme_font_size_override("font_size", 17)
	body.add_theme_color_override("font_color", Color(0.82, 0.86, 0.95))
	body.text = ("• %d жизни на ВЕСЬ забег — между этажами не восстанавливаются.\n" +
		"• Начинаешь с нуля: открыты только Вспышка (Q) и Рывок (Shift).\n" +
		"• Спуск бесконечный — иди настолько глубоко, насколько сможешь.\n" +
		"• Гибель завершает забег. Выйти в меню можно в любой момент — забег сохранится в слоте.") % GameConfig.RUN_LIVES
	_briefing_box.add_child(body)

	_briefing_box.add_child(_make_button("Начать забег", _start_briefed_run))
	_briefing_box.add_child(_make_button("Назад", _on_briefing_back))

func _on_open_runs() -> void:
	_populate_runs()
	_menu_box.visible = false
	_runs_box.visible = true
	_back_btn.visible = true

func _show_briefing(slot: int) -> void:
	_briefing_slot = slot
	_runs_box.visible = false
	_briefing_box.visible = true
	_back_btn.visible = true

func _on_briefing_back() -> void:
	_briefing_box.visible = false
	_runs_box.visible = true

func _start_briefed_run() -> void:
	GameConfig.start_new_run(_briefing_slot)
	_launch_game()

func _launch_game() -> void:
	get_tree().change_scene_to_file("res://main.tscn")

# --- Статистика ---

func _build_stats(root: VBoxContainer) -> void:
	_stats_scroll = ScrollContainer.new()
	_stats_scroll.visible = false
	_stats_scroll.custom_minimum_size = Vector2(660, 480)
	_stats_scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	root.add_child(_stats_scroll)

	_stats_box = VBoxContainer.new()
	_stats_box.add_theme_constant_override("separation", 7)
	_stats_scroll.add_child(_stats_box)

func _populate_stats() -> void:
	for c in _stats_box.get_children():
		c.queue_free()
	var s: Dictionary = GameConfig.stats
	_stats_title("Статистика")
	_stats_line("Лучшая глубина: %d" % int(s.get("best_depth", 0)))
	_stats_line("Рекорд банка Накала: %d" % int(s.get("best_ember", 0)))
	_stats_line("Забегов: начато %d · завершено %d" % [int(s.get("runs_started", 0)), int(s.get("runs_ended", 0))])
	_stats_line("Этажей пройдено всего: %d" % int(s.get("levels_cleared", 0)))
	_stats_line("Осколков собрано всего: %d" % int(s.get("shards_total", 0)))
	_stats_line("Ранги:   S %d   ·   A %d   ·   B %d   ·   C %d   ·   D %d" % [
		int(s.get("rank_S", 0)), int(s.get("rank_A", 0)), int(s.get("rank_B", 0)),
		int(s.get("rank_C", 0)), int(s.get("rank_D", 0))])

	_stats_title("Забеги")
	for i in GameConfig.RUN_SLOTS:
		var sm := GameConfig.run_summary(i)
		if sm["status"] == "empty":
			_stats_line("Слот %d:  пусто" % (i + 1))
			continue
		var st: String = "идёт" if sm["status"] == "active" else "завершён"
		_stats_line("Слот %d:  %s · глубина %d (макс %d)" % [i + 1, st, sm["level"], sm["max_depth"]])
		var r = GameConfig.runs[i]
		if r != null:
			var ranks: Array = r.get("ranks", [])
			if ranks.size() > 0:
				var start := maxi(0, ranks.size() - 10)
				var tail := ""
				for j in range(start, ranks.size()):
					tail += "%s " % str(ranks[j].get("rank", "?"))
				_stats_line("      последние ранги:  %s" % tail.strip_edges())

	_stats_box.add_child(_make_button("Назад", _go_back))

func _stats_title(t: String) -> void:
	var l := Label.new()
	l.text = t
	l.add_theme_font_size_override("font_size", 24)
	l.add_theme_color_override("font_color", Color(0.85, 0.9, 1.0))
	_stats_box.add_child(l)

func _stats_line(t: String) -> void:
	var l := Label.new()
	l.text = t
	l.add_theme_font_size_override("font_size", 17)
	l.add_theme_color_override("font_color", Color(0.78, 0.84, 0.95))
	_stats_box.add_child(l)

func _on_open_stats() -> void:
	_populate_stats()
	_menu_box.visible = false
	_stats_scroll.visible = true
	_back_btn.visible = true

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
	_back_btn.visible = true

func _on_close_passives() -> void:
	_go_back()

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
	_back_btn.visible = true

func _on_close_help() -> void:
	_go_back()

func _help_text() -> String:
	return """ЦЕЛЬ ИГРЫ
Ты — белый светящийся шарик в полной темноте. Виден только небольшой круг вокруг тебя; стены отбрасывают тень, поэтому видно лишь то, что в прямой видимости. Нужно найти золотой ВЫХОД и дойти до него. Свет постоянно гаснет — если погаснет совсем, теряешь жизнь.

ЭТАЖИ И ВЫХОД
Уровень состоит из нескольких этажей-лабиринтов, расположенных «друг под другом». Выход всегда на самом нижнем этаже, поэтому пройти можно, только посетив все этажи.

ДВЕРИ
Серые двери — переходы между соседними этажами, работают в обе стороны. Их может быть несколько (настройка «Дверей между этажами»).
• Первая дверь между этажами всегда открыта.
• Остальные двери ЗАПЕРТЫ (оранжево-красные) — чтобы открыть, нужен осколок-ключ.

ЭНЕРГОКРИСТАЛЛЫ (синие)
Заходишь — кристалл мгновенно даёт глоток света, немного XP и заряд «Озарения», и служит точкой сохранения (после гибели появляешься у последнего). Затем он истощается и ~3 секунды восстанавливается (видно по кольцу-шкале вокруг) — пока не зарядится снова, не действует. Стоять и фармить бесконечно нельзя: чтобы взять ещё глоток, выйди из зоны и вернись.

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
	_back_btn.visible = true

func _on_close_level_select() -> void:
	_go_back()

func _on_open_settings() -> void:
	_menu_box.visible = false
	_settings_scroll.visible = true
	_back_btn.visible = true

func _on_close_settings() -> void:
	_go_back()

func _on_reset_progress() -> void:
	GameConfig.reset_progress()

func _on_quit() -> void:
	GameConfig.save_game()
	get_tree().quit()
