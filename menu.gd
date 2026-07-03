extends Control

# Главное меню: Играть / Настройки / Выход.
# Настройки правят синглтон GameConfig, который читает игра.

var _menu_box: VBoxContainer
var _settings_box: VBoxContainer
var _settings_scroll: ScrollContainer
var _level_box: VBoxContainer
var _level_grid: GridContainer
var _boss_section: VBoxContainer  # секция тест-боссов в выборе уровней
var _help_scroll: ScrollContainer
var _back_btn: Button

# Режим «Накал»: панель выбора слота-забега и брифинг.
var _runs_box: VBoxContainer
var _runs_slots_box: VBoxContainer
var _briefing_box: VBoxContainer
var _briefing_slot: int = 0

# Дневник лабиринта: объединённые «Статистика» + «Результаты» — цифры, история
# последних уровней и «голос лабиринта» (наблюдения и советы по твоей игре).
var _journal_scroll: ScrollContainer
var _journal_box: VBoxContainer

# Спуск дня: ежедневный забег с сидом от даты, одна попытка в день.
var _daily_box: VBoxContainer

# Выбор режима после «Играть»: Уровни (продолжить/выбрать) или Накал.
var _mode_scroll: ScrollContainer
var _mode_box: VBoxContainer

const LEVEL_COUNT := 50

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

	_start_menu_music()
	_build_menu(root)
	_build_mode(root)
	_build_runs(root)
	_build_briefing(root)
	_build_journal(root)
	_build_daily(root)
	_build_level_select(root)
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

# Спрятать ВСЕ панели (включая корневое меню). Каждый _on_open_* обязан звать
# это перед показом своей панели: панели — соседи в одной колонке, и забытая
# видимая панель выталкивает новую за край экрана («кнопка не работает»).
func _hide_all_panels() -> void:
	_menu_box.visible = false
	_level_box.visible = false
	_settings_scroll.visible = false
	_help_scroll.visible = false
	_runs_box.visible = false
	_briefing_box.visible = false
	_journal_scroll.visible = false
	if _daily_box:
		_daily_box.visible = false
	if _mode_scroll:
		_mode_scroll.visible = false

# Единая точка возврата (кнопка сверху-слева, Esc и нижние «Назад»).
# Иерархия: брифинг → слоты Накала; подпанели «Играть» (слоты, выбор уровня,
# спуск дня, дневник) → экран режимов; остальное → корневое меню.
func _go_back() -> void:
	if _briefing_box and _briefing_box.visible:
		_on_briefing_back()
		return
	var from_mode_child: bool = _runs_box.visible or _level_box.visible \
		or _journal_scroll.visible \
		or (_daily_box != null and _daily_box.visible)
	_hide_all_panels()
	if from_mode_child:
		_on_open_mode()
		return
	_menu_box.visible = true
	if _back_btn:
		_back_btn.visible = false

func _fit_panels() -> void:
	# Место под заголовком MAZE + подзаголовком + отступами (~250px) с запасом.
	var vh: float = get_viewport().get_visible_rect().size.y
	var avail: float = max(220.0, vh - 300.0)
	_settings_scroll.custom_minimum_size.y = min(480.0, avail)
	_help_scroll.custom_minimum_size.y = min(520.0, avail)
	if _journal_scroll:
		_journal_scroll.custom_minimum_size.y = min(520.0, avail)
	if _mode_scroll:
		_mode_scroll.custom_minimum_size.y = min(520.0, avail)

func _build_menu(root: VBoxContainer) -> void:
	_menu_box = VBoxContainer.new()
	_menu_box.add_theme_constant_override("separation", 12)
	root.add_child(_menu_box)

	_menu_box.add_child(_make_button("Играть", _on_open_mode))
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

	# Счётчик FPS внизу слева. Сохраняется между запусками.
	var fps_check := CheckButton.new()
	fps_check.text = "Показывать счётчик FPS"
	fps_check.button_pressed = GameConfig.show_fps
	fps_check.add_theme_font_size_override("font_size", 18)
	fps_check.toggled.connect(func(on: bool) -> void:
		GameConfig.show_fps = on
		GameConfig.save_game()
	)
	_settings_box.add_child(fps_check)

	# ── Громкость (как принято: два ползунка, музыка и звуки) ──────────────
	_add_volume_slider("Громкость музыки", GameConfig.music_volume, func(v: float) -> void:
		GameConfig.music_volume = v
		GameConfig.apply_volumes()
		GameConfig.save_game())
	_add_volume_slider("Громкость звуков", GameConfig.sfx_volume, func(v: float) -> void:
		GameConfig.sfx_volume = v
		GameConfig.apply_volumes()
		GameConfig.save_game())

	# ── Экран ────────────────────────────────────────────────────────────────
	var fs_check := CheckButton.new()
	fs_check.text = "Полноэкранный режим"
	fs_check.button_pressed = GameConfig.fullscreen
	fs_check.add_theme_font_size_override("font_size", 18)
	fs_check.toggled.connect(func(on: bool) -> void:
		GameConfig.fullscreen = on
		GameConfig.apply_display()
		GameConfig.save_game())
	_settings_box.add_child(fs_check)

	var res_row := HBoxContainer.new()
	res_row.add_theme_constant_override("separation", 10)
	_settings_box.add_child(res_row)
	var res_lbl := Label.new()
	res_lbl.text = "Разрешение (в окне)"
	res_lbl.custom_minimum_size = Vector2(200, 0)
	res_lbl.add_theme_font_size_override("font_size", 18)
	res_row.add_child(res_lbl)
	var res_opt := OptionButton.new()
	for r in GameConfig.RESOLUTIONS:
		res_opt.add_item("%d × %d" % [r.x, r.y])
	res_opt.selected = GameConfig.resolution_idx
	res_opt.add_theme_font_size_override("font_size", 16)
	res_opt.item_selected.connect(func(i: int) -> void:
		GameConfig.resolution_idx = i
		GameConfig.apply_display()
		GameConfig.save_game())
	res_row.add_child(res_opt)

	var vs_check := CheckButton.new()
	vs_check.text = "Вертикальная синхронизация (VSync)"
	vs_check.button_pressed = GameConfig.vsync
	vs_check.add_theme_font_size_override("font_size", 18)
	vs_check.toggled.connect(func(on: bool) -> void:
		GameConfig.vsync = on
		GameConfig.apply_display()
		GameConfig.save_game())
	_settings_box.add_child(vs_check)

	# Пульс-указатель к маяку: полупрозрачная искра летит от игрока к маяку.
	var pulse_check := CheckButton.new()
	pulse_check.text = "Пульс-указатель к маяку"
	pulse_check.button_pressed = GameConfig.beacon_pulse
	pulse_check.add_theme_font_size_override("font_size", 18)
	pulse_check.toggled.connect(func(on: bool) -> void:
		GameConfig.beacon_pulse = on
		GameConfig.save_game()
	)
	_settings_box.add_child(pulse_check)

	# ── ТЕСТИРОВАНИЕ (для автора проекта) ──────────────────────────────────
	var tsep := HSeparator.new()
	tsep.modulate = Color(1.0, 0.6, 0.2, 0.5)
	_settings_box.add_child(tsep)
	var tlbl := Label.new()
	tlbl.text = "🔧 Тестирование (для автора)"
	tlbl.add_theme_font_size_override("font_size", 20)
	tlbl.add_theme_color_override("font_color", Color(1.0, 0.6, 0.2))
	_settings_box.add_child(tlbl)
	var thint := Label.new()
	thint.text = "В тест-режиме открыто всё, а статистика, XP, история уровней\nи Спуск дня НЕ записываются — прогоны не искажают Дневник."
	thint.add_theme_font_size_override("font_size", 13)
	thint.add_theme_color_override("font_color", Color(0.6, 0.62, 0.68))
	_settings_box.add_child(thint)

	# Мастер-тумблер тест-режима: статистика/XP/истории не пишутся,
	# Спуск дня — без лимита попыток.
	var daily_test := CheckButton.new()
	daily_test.text = "Тест-режим (статистика не пишется, Спуск дня без лимита)"
	daily_test.button_pressed = GameConfig.test_mode
	daily_test.add_theme_font_size_override("font_size", 18)
	daily_test.add_theme_color_override("font_color", Color(1.0, 0.6, 0.2))
	daily_test.toggled.connect(func(on: bool) -> void:
		GameConfig.test_mode = on
		GameConfig.save_game()
		_toast("Тест-режим: %s" % ("ВКЛ — статистика не записывается" if on else "выкл"))
	)
	_settings_box.add_child(daily_test)

	# Тест: переключатель «открыть все уровни». При выключении возвращает
	# реальный прогресс, запомненный до разблокировки.
	_unlock_baseline = GameConfig.max_unlocked_level
	var unlock_all := CheckButton.new()
	unlock_all.text = "Разблокировать все уровни"
	unlock_all.button_pressed = GameConfig.max_unlocked_level >= LEVEL_COUNT
	unlock_all.add_theme_font_size_override("font_size", 18)
	unlock_all.add_theme_color_override("font_color", Color(1.0, 0.6, 0.2))
	unlock_all.toggled.connect(_on_unlock_toggled)
	_settings_box.add_child(unlock_all)

	# Тест: включить/выключить боссовые уровни в выборе уровней.
	var boss_test := CheckButton.new()
	boss_test.text = "⚔ Тест боссов (уровни с боссом в меню)"
	boss_test.button_pressed = GameConfig.boss_test_enabled
	boss_test.add_theme_font_size_override("font_size", 18)
	boss_test.add_theme_color_override("font_color", Color(1.0, 0.6, 0.2))
	boss_test.toggled.connect(func(on: bool) -> void:
		GameConfig.boss_test_enabled = on
		_populate_levels()
	)
	_settings_box.add_child(boss_test)

	# Сброс прогресса — в самом низу настроек, с подтверждением вторым нажатием
	# (раньше висел в главном меню и стирал всё одним случайным кликом).
	var reset_armed := [false]
	var reset_btn: Button
	reset_btn = _make_button("Сбросить прогресс", func() -> void:
		if reset_armed[0]:
			GameConfig.reset_progress()
			reset_armed[0] = false
			reset_btn.text = "Сбросить прогресс"
			_toast("Прогресс сброшен")
		else:
			reset_armed[0] = true
			reset_btn.text = "Точно сбросить ВСЁ? Нажми ещё раз"
	)
	reset_btn.add_theme_color_override("font_color", Color(1.0, 0.45, 0.4))
	_settings_box.add_child(reset_btn)

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

# Ползунок громкости: подпись + HSlider 0..1 + процент справа.
func _add_volume_slider(text: String, value: float, setter: Callable) -> void:
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 10)
	_settings_box.add_child(row)
	var lbl := Label.new()
	lbl.text = text
	lbl.custom_minimum_size = Vector2(200, 0)
	lbl.add_theme_font_size_override("font_size", 18)
	row.add_child(lbl)
	var slider := HSlider.new()
	slider.min_value = 0.0
	slider.max_value = 1.0
	slider.step = 0.05
	slider.value = value
	slider.custom_minimum_size = Vector2(220, 24)
	slider.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	row.add_child(slider)
	var pct := Label.new()
	pct.text = "%d%%" % int(round(value * 100.0))
	pct.custom_minimum_size = Vector2(52, 0)
	pct.add_theme_font_size_override("font_size", 16)
	pct.add_theme_color_override("font_color", Color(0.7, 0.78, 0.9))
	row.add_child(pct)
	slider.value_changed.connect(func(v: float) -> void:
		pct.text = "%d%%" % int(round(v * 100.0))
		setter.call(v))

func _add_check(text: String, value: bool, setter: Callable) -> void:
	var cb := CheckButton.new()
	cb.text = text
	cb.button_pressed = value
	cb.add_theme_font_size_override("font_size", 18)
	cb.toggled.connect(func(on): setter.call(on))
	_settings_box.add_child(cb)

# Фоновая музыка меню — тот же тёмный дрон, что и в игре, но тише:
# меню и лабиринт звучат одним миром, без склейки при переходе.
func _start_menu_music() -> void:
	var stream = load("res://sounds/ambient_dark.wav")
	if stream == null:
		return
	if stream is AudioStreamWAV:
		stream.loop_mode = AudioStreamWAV.LOOP_FORWARD
		stream.loop_begin = 0
		stream.loop_end = stream.data.size() / 4   # 16 бит × 2 канала
	var p := AudioStreamPlayer.new()
	p.stream = stream
	p.volume_db = -12.0
	p.bus = "Music"
	add_child(p)
	p.play()

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

	# Боссовая секция — только при включённом тест-флаге
	if is_instance_valid(_boss_section):
		_boss_section.queue_free()
		_boss_section = null

	if GameConfig.boss_test_enabled:
		_boss_section = VBoxContainer.new()
		_boss_section.add_theme_constant_override("separation", 8)
		_level_box.add_child(_boss_section)
		# Вставить перед кнопкой «Назад» (последний дочерний элемент)
		_level_box.move_child(_boss_section, _level_box.get_child_count() - 2)

		var sep := HSeparator.new()
		sep.modulate = Color(1.0, 0.6, 0.2, 0.5)
		_boss_section.add_child(sep)

		var lbl := Label.new()
		lbl.text = "⚔ Тест-уровни с боссом"
		lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		lbl.add_theme_font_size_override("font_size", 18)
		lbl.add_theme_color_override("font_color", Color(1.0, 0.6, 0.2))
		_boss_section.add_child(lbl)

		var hint := Label.new()
		hint.text = "Открывает арену с Тёмным Ядром на выбранном уровне."
		hint.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		hint.add_theme_font_size_override("font_size", 14)
		hint.add_theme_color_override("font_color", Color(0.6, 0.5, 0.4))
		_boss_section.add_child(hint)

		var grid := GridContainer.new()
		grid.columns = 5
		grid.add_theme_constant_override("h_separation", 8)
		grid.add_theme_constant_override("v_separation", 6)
		_boss_section.add_child(grid)

		for lvl in [1, 5, 10, 15, 20]:
			var btn := Button.new()
			btn.text = "⚔ %d" % lvl
			btn.custom_minimum_size = Vector2(90, 50)
			btn.add_theme_font_size_override("font_size", 18)
			btn.add_theme_color_override("font_color", Color(1.0, 0.65, 0.2))
			_style_button(btn)
			var capture: int = lvl
			btn.pressed.connect(func():
				GameConfig.boss_test_enabled = true
				_on_play(capture)
			)
			grid.add_child(btn)

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
	_hide_all_panels()
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

# =============================================================================
# ДНЕВНИК ЛАБИРИНТА — объединённые «Статистика» + «Результаты».
# Подача: карточки-панели с неоновой рамкой. Сверху — «Голос лабиринта»:
# лабиринт «наблюдает» за игрой и говорит с игроком — наблюдения, советы и
# слухи о секретах. Набор и формулировки меняются от визита к визиту, чтобы
# дневник ощущался живым, а не статичной таблицей.
# =============================================================================

func _build_journal(root: VBoxContainer) -> void:
	_journal_scroll = ScrollContainer.new()
	_journal_scroll.visible = false
	_journal_scroll.custom_minimum_size = Vector2(720, 520)
	_journal_scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	root.add_child(_journal_scroll)

	_journal_box = VBoxContainer.new()
	_journal_box.add_theme_constant_override("separation", 12)
	_journal_scroll.add_child(_journal_box)

const _RESULT_RANK_COLORS := {
	"S": Color(1.0, 0.85, 0.3), "A": Color(0.5, 1.0, 0.6),
	"B": Color(0.5, 0.8, 1.0), "C": Color(0.9, 0.7, 0.4), "D": Color(0.9, 0.4, 0.4),
}

# Карточка-панель с тонкой неоновой рамкой; возвращает VBox для содержимого.
func _journal_panel(title: String, accent: Color) -> VBoxContainer:
	var panel := PanelContainer.new()
	var sb := StyleBoxFlat.new()
	sb.bg_color = Color(0.045, 0.055, 0.10, 0.88)
	sb.set_corner_radius_all(10)
	sb.set_border_width_all(1)
	sb.border_color = Color(accent.r, accent.g, accent.b, 0.45)
	sb.content_margin_left = 16
	sb.content_margin_right = 16
	sb.content_margin_top = 10
	sb.content_margin_bottom = 12
	panel.add_theme_stylebox_override("panel", sb)
	_journal_box.add_child(panel)

	var box := VBoxContainer.new()
	box.add_theme_constant_override("separation", 5)
	panel.add_child(box)

	var l := Label.new()
	l.text = title
	l.add_theme_font_size_override("font_size", 21)
	l.add_theme_color_override("font_color", accent)
	box.add_child(l)
	return box

func _journal_line(box: VBoxContainer, t: String, col: Color = Color(0.78, 0.84, 0.95), fsize: int = 16, wrap: bool = false) -> void:
	var l := Label.new()
	l.text = t
	l.add_theme_font_size_override("font_size", fsize)
	l.add_theme_color_override("font_color", col)
	if wrap:
		l.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		l.custom_minimum_size.x = 660
	box.add_child(l)

# «Спидометр» уровня: чем быстрее пар-тайма, тем больше заполненных сегментов.
func _journal_speed_bar(t: float, par: float) -> String:
	var frac: float = clampf(par / maxf(t, 0.1), 0.0, 1.0)   # 1.0 = не хуже пар-тайма
	var filled := int(round(frac * 5.0))
	return "▰".repeat(filled) + "▱".repeat(5 - filled)

func _populate_journal() -> void:
	for c in _journal_box.get_children():
		c.queue_free()
	var s: Dictionary = GameConfig.stats
	var hist: Array = GameConfig.level_history

	var head := Label.new()
	head.text = "Дневник лабиринта"
	head.add_theme_font_size_override("font_size", 30)
	head.add_theme_color_override("font_color", Color(0.85, 0.9, 1.0))
	_journal_box.add_child(head)

	# --- Голос лабиринта: наблюдения и советы (главная карточка, сверху) ---
	var voice := _journal_panel("✧ Голос лабиринта", Color(1.0, 0.85, 0.3))
	for line in _journal_voice_lines(hist, s):
		_journal_line(voice, line, Color(0.95, 0.9, 0.75), 16, true)

	# --- Твой стиль: навыки в картинках — частота, мастерство, форма Апекса ---
	var style := _journal_panel("Твой стиль", Color(0.8, 0.7, 1.0))
	var srow := HBoxContainer.new()
	srow.add_theme_constant_override("separation", 12)
	style.add_child(srow)
	for id in ["flash", "dash", "smother", "sonar", "shield", "guide", "reveal", "mirage", "breach", "chrono"]:
		var uses := int(GameConfig.skill_uses.get(id, 0))
		var unlocked: bool = GameConfig.skills_unlocked.get(id, false)
		var cellv := VBoxContainer.new()
		cellv.alignment = BoxContainer.ALIGNMENT_CENTER
		var ic := TextureRect.new()
		ic.texture = SkillIcons.make(id, 30)
		ic.stretch_mode = TextureRect.STRETCH_KEEP_CENTERED
		ic.custom_minimum_size = Vector2(34, 34)
		if not unlocked:
			ic.modulate = Color(0.32, 0.32, 0.38)
		cellv.add_child(ic)
		var nml := Label.new()
		nml.text = {"flash": "Вспышка", "dash": "Рывок", "smother": "Тление", "sonar": "Сонар",
			"shield": "Щит", "guide": "Искра", "reveal": "Озарение", "mirage": "Мираж",
			"breach": "Разлом", "chrono": "Хронос"}.get(id, id)
		nml.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		nml.add_theme_font_size_override("font_size", 11)
		nml.add_theme_color_override("font_color", Color(0.7, 0.76, 0.88))
		cellv.add_child(nml)
		var ul := Label.new()
		ul.text = ("×%d" % uses) if unlocked else "🔒"
		ul.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		ul.add_theme_font_size_override("font_size", 12)
		ul.add_theme_color_override("font_color", Color(0.75, 0.8, 0.92) if unlocked else Color(0.45, 0.48, 0.55))
		cellv.add_child(ul)
		var mstars := GameConfig.mastery(id)
		if unlocked and mstars > 0:
			var ml := Label.new()
			ml.text = "★".repeat(mstars)
			ml.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
			ml.add_theme_font_size_override("font_size", 10)
			ml.add_theme_color_override("font_color", Color(1.0, 0.85, 0.3))
			cellv.add_child(ml)
		srow.add_child(cellv)
	# Прогноз Апекса: форма = самый прокачанный навык, эхо = второй.
	var sk_names := {"flash": "Вспышка", "dash": "Рывок", "sonar": "Сонар", "shield": "Щит",
		"guide": "Искра", "reveal": "Озарение", "smother": "Тление",
		"mirage": "Мираж", "breach": "Разлом", "chrono": "Хронос"}
	if GameConfig.skills_unlocked.get("apex", false):
		var top := GameConfig.top_mastered(2)
		var arow := HBoxContainer.new()
		arow.add_theme_constant_override("separation", 8)
		style.add_child(arow)
		var al := Label.new()
		al.text = "Апекс (H) сейчас примет форму:"
		al.add_theme_font_size_override("font_size", 15)
		al.add_theme_color_override("font_color", Color(1.0, 0.5, 0.55))
		arow.add_child(al)
		var mic := TextureRect.new()
		mic.texture = SkillIcons.make(top[0], 26)
		mic.stretch_mode = TextureRect.STRETCH_KEEP_CENTERED
		arow.add_child(mic)
		var mn := Label.new()
		mn.text = str(sk_names.get(top[0], top[0]))
		mn.add_theme_font_size_override("font_size", 15)
		arow.add_child(mn)
		if top.size() > 1:
			var el := Label.new()
			el.text = "· эхо:"
			el.add_theme_font_size_override("font_size", 14)
			el.add_theme_color_override("font_color", Color(0.65, 0.7, 0.82))
			arow.add_child(el)
			var eic := TextureRect.new()
			eic.texture = SkillIcons.make(top[1], 22)
			eic.stretch_mode = TextureRect.STRETCH_KEEP_CENTERED
			arow.add_child(eic)
			var en := Label.new()
			en.text = str(sk_names.get(top[1], top[1]))
			en.add_theme_font_size_override("font_size", 14)
			arow.add_child(en)
		_journal_line(style, "Хочешь другую форму — чаще применяй нужный навык: мастерство и решает.", Color(0.6, 0.66, 0.78), 13, true)
	else:
		_journal_line(style, "Апекс (H) откроется, когда собраны все 6 базовых активных навыков — и примет форму того, что качаешь сильнее.", Color(0.6, 0.66, 0.78), 13, true)

	# --- Путь: агрегаты за всё время + сводка по последним уровням ---
	var path := _journal_panel("Путь", Color(0.5, 0.8, 1.0))
	_journal_line(path, "Этажей пройдено: %d   ·   осколков собрано: %d" % [
		int(s.get("levels_cleared", 0)), int(s.get("shards_total", 0))])
	_journal_line(path, "Лучшая глубина Накала: %d   ·   рекорд банка: %d   ·   забегов: %d / %d" % [
		int(s.get("best_depth", 0)), int(s.get("best_ember", 0)),
		int(s.get("runs_ended", 0)), int(s.get("runs_started", 0))])
	_journal_line(path, "Ранги:   S %d   ·   A %d   ·   B %d   ·   C %d   ·   D %d" % [
		int(s.get("rank_S", 0)), int(s.get("rank_A", 0)), int(s.get("rank_B", 0)),
		int(s.get("rank_C", 0)), int(s.get("rank_D", 0))])

	# --- Последние уровни: цветные строки со «спидометром» ---
	var recent := _journal_panel("Последние уровни", Color(0.85, 0.9, 1.0))
	if hist.is_empty():
		_journal_line(recent, "Пока пусто — пройди первый уровень, и лабиринт начнёт записывать.")
	else:
		_journal_line(recent, "▰ — скорость против пар-тайма: больше заполнено = быстрее", Color(0.55, 0.6, 0.72), 12)
		var start := maxi(0, hist.size() - 6)
		for i in range(hist.size() - 1, start - 1, -1):
			var e: Dictionary = hist[i]
			var t: float = float(e.get("time", 0.0))
			var par: float = maxf(1.0, float(e.get("par", 1.0)))
			var rk: String = str(e.get("rank", "?"))
			var col: Color = _RESULT_RANK_COLORS.get(rk, Color(0.78, 0.84, 0.95))
			var clean_tag := "  ·  без урона ✦" if bool(e.get("no_dmg", false)) else ""
			var dtag: String = ["  ·  ◦тлеющий", "", "  ·  ☀ПЫЛАЮЩИЙ"][clampi(int(e.get("diff", 1)), 0, 2)]
			_journal_line(recent, "%s  %s   ур. %d   ·   %.1fс   ·   осколки %d%%%s%s" % [
				rk, _journal_speed_bar(t, par), int(e.get("level", 0)), t,
				int(round(float(e.get("shards_pct", 0.0)) * 100.0)), clean_tag, dtag], col)

	# --- Путь к навыкам: цели-майлстоуны (навык откроется сам за достижение) ---
	var locked_ms: Array = []
	for id in GameConfig.SKILL_MILESTONES:
		if not GameConfig.skills_unlocked.get(id, false):
			locked_ms.append(id)
	if not locked_ms.is_empty():
		var goals := _journal_panel("Путь к навыкам", Color(0.5, 1.0, 0.6))
		_journal_line(goals, "Навыки открываются за дела — или за SP в меню навыков, что раньше.", Color(0.6, 0.75, 0.65), 14, true)
		var names := {"sonar": "Сонар (E)", "shield": "Щит (C)", "guide": "Искра (G)", "reveal": "Озарение (F)"}
		for id in locked_ms:
			var ms: Dictionary = GameConfig.SKILL_MILESTONES[id]
			var cur := mini(int(s.get(ms["stat"], 0)), int(ms["need"]))
			var frac := float(cur) / float(ms["need"])
			var bar := "▰".repeat(int(round(frac * 8.0))) + "▱".repeat(8 - int(round(frac * 8.0)))
			_journal_line(goals, "%s   %s   %d / %d — %s" % [names.get(id, id), bar, cur, int(ms["need"]), str(ms["text"])])

	# --- Спуск дня: серия и последние результаты ---
	if not GameConfig.daily_history.is_empty():
		var daily := _journal_panel("Спуск дня", Color(1.0, 0.85, 0.3))
		var streak := GameConfig.daily_streak()
		if streak >= 2:
			_journal_line(daily, "🔥 Серия: %d %s подряд" % [streak, _plural(streak, "день", "дня", "дней")], Color(1.0, 0.62, 0.25))
		var dh: Array = GameConfig.daily_history
		var dstart := maxi(0, dh.size() - 5)
		for i in range(dh.size() - 1, dstart - 1, -1):
			var e: Dictionary = dh[i]
			_journal_line(daily, "%s   ·   глубина %d   ·   Накал %d" % [
				str(e.get("date", "?")), int(e.get("depth", 1)), int(e.get("ember", 0))])

	# --- Забеги Накала: слоты ---
	var runs := _journal_panel("Забеги Накала", Color(1.0, 0.62, 0.25))
	for i in GameConfig.RUN_SLOTS:
		var sm := GameConfig.run_summary(i)
		if sm["status"] == "empty":
			_journal_line(runs, "Слот %d:  пусто" % (i + 1), Color(0.55, 0.6, 0.7))
			continue
		var st: String = "идёт" if sm["status"] == "active" else "завершён"
		_journal_line(runs, "Слот %d:  %s · глубина %d (макс %d)" % [i + 1, st, sm["level"], sm["max_depth"]])
		var r = GameConfig.runs[i]
		if r != null:
			var ranks: Array = r.get("ranks", [])
			if ranks.size() > 0:
				var rstart := maxi(0, ranks.size() - 10)
				var tail := ""
				for j in range(rstart, ranks.size()):
					tail += "%s " % str(ranks[j].get("rank", "?"))
				_journal_line(runs, "      последние ранги:  %s" % tail.strip_edges(), Color(0.7, 0.75, 0.85))

	_journal_box.add_child(_make_button("Назад", _go_back))

# Сводка по кольцевому буферу последних уровней.
func _journal_aggregates(hist: Array) -> Dictionary:
	var sum_ratio := 0.0
	var sum_shards := 0.0
	var clean_count := 0
	for e in hist:
		var par: float = maxf(1.0, float(e.get("par", 1.0)))
		sum_ratio += float(e.get("time", 0.0)) / par
		sum_shards += float(e.get("shards_pct", 0.0))
		if bool(e.get("no_dmg", false)):
			clean_count += 1
	var n := maxi(hist.size(), 1)
	return {
		avg_ratio = sum_ratio / n,
		avg_shards = sum_shards / n,
		clean_pct = float(clean_count) / n,
	}

# =============================================================================
# «Голос лабиринта»: строит реплики по накопленным данным. Никакого ИИ — только
# пороги, но с ВАРИАТИВНОСТЬЮ: у каждого наблюдения несколько формулировок,
# из подходящих выбираются случайные 3 (приветствие — всегда). Каждый визит
# дневник звучит немного иначе — лабиринт «живой» и правда наблюдает.
# =============================================================================

const _SKILL_NAMES := {"flash": "Вспышка", "dash": "Рывок", "sonar": "Сонар",
	"shield": "Щит", "guide": "Искра", "reveal": "Озарение", "smother": "Тление",
	"mirage": "Мираж", "breach": "Разлом", "chrono": "Хронос"}

# Слухи о секретах: подмешиваются, когда советов мало (или просто повезёт).
const _JOURNAL_RUMORS := [
	"Слух: если собрать три осколка подряд, не получив урона, тьма отступает сама. Проверь.",
	"Слух: осколки иногда оставляют эхо. Услышишь звон за спиной — реши, стоит ли возвращаться.",
	"Слух: Рывок сквозь собственную Вспышку летит дальше обычного. Кто-то называл это «световым копьём».",
	"Слух: Сонар, пущенный во время Озарения, видит всё — и враги слепнут от него.",
	"Слух: далёкий огонёк-маяк живёт полминуты. Успевший к нему получает подарок.",
	"Слух: тот, кто стоит у энергокристалла, не тает. Станция — убежище, переведи дух.",
	"Слух: в глубинах Накала чем ярче горишь — тем громче бьётся сердце экрана. Тьма это слышит.",
]

# Русское склонение: _plural(3, "этаж", "этажа", "этажей") → «этажа».
func _plural(n: int, one: String, few: String, many: String) -> String:
	var m := absi(n) % 100
	if m >= 11 and m <= 14:
		return many
	match m % 10:
		1: return one
		2, 3, 4: return few
		_: return many

func _journal_voice_lines(hist: Array, s: Dictionary) -> Array:
	var out: Array = []
	var total := int(s.get("levels_cleared", 0))
	var fl := _plural(total, "этаж", "этажа", "этажей")

	# Приветствие — всегда первое, зависит от «стажа» и меняет формулировку.
	var greet: Array
	if total <= 0:
		greet = [
			"Мы ещё не знакомы. Пройди хотя бы один этаж — и я начну записывать твою историю.",
			"Дневник пуст. Лабиринт ждёт первого шага.",
		]
	elif total < 10:
		greet = [
			"Я наблюдаю за тобой уже %d %s. Пока присматриваюсь." % [total, fl],
			"%d %s позади. Я начинаю узнавать твою походку." % [total, fl],
		]
	elif total < 50:
		greet = [
			"%d %s вместе. Я уже знаю, как ты играешь — читай ниже." % [total, fl],
			"Я видел каждый из твоих %d этажей. Кое-что мне хочется сказать." % total,
		]
	else:
		greet = [
			"%d %s. Ты здесь дольше многих огоньков. Я помню каждый." % [total, fl],
			"После %d этажей мне трудно тебя удивить. Но я попробую." % total,
		]
	out.append(greet[randi() % greet.size()])
	if hist.is_empty():
		return out

	# --- Пул наблюдений: [условие уже проверено] массив формулировок ---
	var pool: Array = []
	var agg := _journal_aggregates(hist)
	var n := hist.size()

	# Темп
	if agg.avg_ratio > 1.6:
		pool.append([
			"Ты подолгу блуждаешь — в среднем %d%% от пар-тайма. Искра (G) покажет дорогу, а Сонар вскроет планировку за углом." % int(round(agg.avg_ratio * 100.0)),
			"Я вижу, как ты кружишь по одним и тем же коридорам. Доверься Сонару — он рисует то, чего не видит глаз.",
		])
	elif agg.avg_ratio <= 1.05 and n >= 3:
		pool.append([
			"Ты проходишь быстрее, чем я успеваю перестраивать стены. Впечатляет.",
			"Твой темп — %d%% от пар-тайма. Мало кто ходит по мне так уверенно." % int(round(agg.avg_ratio * 100.0)),
		])

	# Чистота
	if agg.clean_pct < 0.3 and n >= 3:
		pool.append([
			"Тьма слишком часто дотягивается до тебя. Щит (C) прощает одну ошибку, а Рывок (Shift) — полторы.",
			"Ты получаешь урон в %d%% уровней. Попробуй держать Щит на случай тесных коридоров." % int(round((1.0 - agg.clean_pct) * 100.0)),
		])
	elif agg.clean_pct >= 0.7 and n >= 5:
		pool.append([
			"Ты почти неуловим — %d%% уровней без единой царапины. Может, пора рискнуть: неси Накал дольше, не банкуя." % int(round(agg.clean_pct * 100.0)),
			"Тьма жалуется, что не может тебя коснуться. Дай ей шанс — и забери больше Накала.",
		])

	# Осколки
	if agg.avg_shards < 0.5 and n >= 3:
		pool.append([
			"Ты оставляешь больше половины осколков лежать в темноте. Они — ключи, Воля и Накал. И они скучают.",
			"Осколки шепчут, что ты проходишь мимо. Собери три подряд без урона — и увидишь, что будет.",
		])
	elif agg.avg_shards >= 0.9 and n >= 3:
		pool.append([
			"Ты собираешь почти всё, что я прячу. Коллекционер. Мне приходится прятать лучше.",
			"%d%% осколков — ты выметаешь меня подчистую. Уважаю." % int(round(agg.avg_shards * 100.0)),
		])

	# Динамика: последние 5 уровней против предыдущих
	if n >= 8:
		var recent_h := hist.slice(n - 5, n)
		var prev_h := hist.slice(maxi(0, n - 10), n - 5)
		var ra := _journal_aggregates(recent_h)
		var pa := _journal_aggregates(prev_h)
		if ra.avg_ratio < pa.avg_ratio - 0.15:
			pool.append([
				"Я сравнил твои последние уровни с прежними: ты стал заметно быстрее. Я это запомнил.",
				"Ты растёшь. Пять уровней назад ты ходил медленнее — теперь коридоры сами расступаются.",
			])
		elif ra.avg_ratio > pa.avg_ratio + 0.2:
			pool.append([
				"Последние уровни даются тяжелее прежних. Устал? Станции — убежище: Свет там не тает.",
				"Я чувствую, что ты сбавил шаг. Иногда полезно постоять у кристалла и оглядеться.",
			])

	# Серия рангов
	if n >= 3:
		var last3_top := true
		for i in range(n - 3, n):
			var rk: String = str(hist[i].get("rank", "?"))
			if rk != "S" and rk != "A":
				last3_top = false
				break
		if last3_top:
			pool.append([
				"Три высоких ранга подряд. Ты играешь так, будто видишь в темноте.",
				"S и A идут один за другим. Я начинаю строить стены злее — не обижайся.",
			])

	# Навыки: забытый и любимый
	var uses: Dictionary = GameConfig.skill_uses
	var max_key := ""
	var min_key := ""
	var max_v := -1
	var min_v := 999999999
	for k in uses.keys():
		var v: int = int(uses[k])
		if v > max_v:
			max_v = v
			max_key = k
		if v < min_v:
			min_v = v
			min_key = k
	if min_key != "" and max_v > 0 and min_v <= int(max_v / 4.0):
		var nm: String = _SKILL_NAMES.get(min_key, min_key)
		pool.append([
			"«%s» пылится без дела. Я видел огоньков, которым он спасал жизнь." % nm,
			"Ты почти не зовёшь «%s». Попробуй — возможно, это твой недостающий инструмент." % nm,
		])
	if max_v >= 10 and max_key != "":
		var combo_hint := ""
		match max_key:
			"flash": combo_hint = " К слову: Рывок во время Вспышки летит в полтора раза дальше."
			"dash":  combo_hint = " К слову: если сорваться в Рывок во время Вспышки — получится «световое копьё»."
			"sonar": combo_hint = " К слову: Сонар во время Озарения накрывает вдвое больше и глушит врагов."
		if combo_hint != "":
			pool.append([
				"Твой любимый инструмент — «%s», %d применений.%s" % [_SKILL_NAMES.get(max_key, max_key), max_v, combo_hint],
			])

	# Выбираем случайные 3 наблюдения; если мало — добиваем слухом о секретах.
	pool.shuffle()
	for i in mini(3, pool.size()):
		var variants: Array = pool[i]
		out.append("◈ " + variants[randi() % variants.size()])
	if out.size() < 3 or randf() < 0.35:
		out.append("◈ " + _JOURNAL_RUMORS[randi() % _JOURNAL_RUMORS.size()])
	return out

func _on_open_journal() -> void:
	_populate_journal()
	_hide_all_panels()
	_journal_scroll.visible = true
	_back_btn.visible = true

# =============================================================================
# ВЫБОР РЕЖИМА («Играть») — последовательный путь игрока: сначала выбор режима,
# затем игра. «Уровни» продолжаются с того места, где остановился; выбор
# конкретного уровня — вторичная кнопка внутри, а не главный экран.
# =============================================================================

func _build_mode(root: VBoxContainer) -> void:
	_mode_scroll = ScrollContainer.new()
	_mode_scroll.visible = false
	_mode_scroll.custom_minimum_size = Vector2(720, 520)
	_mode_scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	root.add_child(_mode_scroll)
	_mode_box = VBoxContainer.new()
	_mode_box.add_theme_constant_override("separation", 12)
	_mode_box.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_mode_scroll.add_child(_mode_box)

func _populate_mode() -> void:
	for c in _mode_box.get_children():
		c.queue_free()

	# --- Верхний ряд: всегда доступные разделы (не режимы) ---
	var top_row := HBoxContainer.new()
	top_row.alignment = BoxContainer.ALIGNMENT_CENTER
	top_row.add_theme_constant_override("separation", 14)
	_mode_box.add_child(top_row)
	for pair in [["Магазин", _on_open_shop], ["Обучение", _on_open_tutorial], ["Дневник", _on_open_journal]]:
		var tb := _make_button(str(pair[0]), pair[1])
		tb.custom_minimum_size = Vector2(200, 44)
		tb.add_theme_font_size_override("font_size", 18)
		top_row.add_child(tb)

	# --- Три больших карточки-режима слева направо ---
	var cards := HBoxContainer.new()
	cards.alignment = BoxContainer.ALIGNMENT_CENTER
	cards.add_theme_constant_override("separation", 16)
	_mode_box.add_child(cards)

	var cur := clampi(GameConfig.level, 1, GameConfig.max_unlocked_level)
	cards.add_child(_mode_card("УРОВНИ",
		"Кампания: 50 уровней, прогресс и навыки — навсегда.\n\nПродолжить: уровень %d" % cur,
		Color(0.45, 0.75, 1.0),
		func() -> void:
			GameConfig.active_run = -1
			_on_play(cur)))

	cards.add_child(_mode_card("НАКАЛ",
		"Рогалик: старт с нуля, 3 жизни на весь спуск, бесконечная глубина.\n\nНесёшь Накал — рискуешь им; банкуй на алтарях.",
		Color(1.0, 0.55, 0.25), _on_open_runs))

	var streak := GameConfig.daily_streak()
	cards.add_child(_mode_card("СПУСК ДНЯ",
		"Один лабиринт на всех, одна попытка в день.\n\n%s%s" % [GameConfig.today_str(),
			("\n🔥 серия: %d" % streak) if streak >= 2 else ""],
		Color(1.0, 0.85, 0.35), _on_open_daily))

	# --- Одна строка: выбор уровня + сложность ---
	var opts_row := HBoxContainer.new()
	opts_row.alignment = BoxContainer.ALIGNMENT_CENTER
	opts_row.add_theme_constant_override("separation", 12)
	_mode_box.add_child(opts_row)

	var pick_btn := _make_button("выбор уровня (%d)" % GameConfig.max_unlocked_level, _on_open_level_select)
	pick_btn.custom_minimum_size = Vector2(220, 42)
	pick_btn.add_theme_font_size_override("font_size", 16)
	opts_row.add_child(pick_btn)

	var diff_lbl := Label.new()
	diff_lbl.text = "Сложность:"
	diff_lbl.add_theme_font_size_override("font_size", 15)
	diff_lbl.add_theme_color_override("font_color", Color(0.8, 0.85, 0.95))
	opts_row.add_child(diff_lbl)

	var diff_desc := Label.new()
	diff_desc.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	diff_desc.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	diff_desc.custom_minimum_size = Vector2(660, 0)
	diff_desc.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	diff_desc.add_theme_font_size_override("font_size", 13)
	diff_desc.add_theme_color_override("font_color", Color(0.62, 0.68, 0.8))
	diff_desc.text = GameConfig.DIFF_DESC[GameConfig.difficulty]

	var diff_colors := [Color(0.55, 0.8, 1.0), Color(1.0, 0.8, 0.35), Color(1.0, 0.42, 0.32)]
	var diff_btns: Array = []
	for i in 3:
		var db := Button.new()
		db.text = ["◦ Тлеющий", "● Горящий", "☀ Пылающий"][i]
		db.toggle_mode = true
		db.button_pressed = GameConfig.difficulty == i
		db.custom_minimum_size = Vector2(140, 42)
		db.add_theme_font_size_override("font_size", 16)
		db.add_theme_color_override("font_color", diff_colors[i])
		_style_button(db)
		diff_btns.append(db)
		var idx := i
		db.pressed.connect(func() -> void:
			GameConfig.difficulty = idx
			GameConfig.save_game()
			for j in 3:
				diff_btns[j].button_pressed = (j == idx)
			diff_desc.text = GameConfig.DIFF_DESC[idx]
			_toast("Сложность: %s" % GameConfig.DIFF_NAMES[idx])
		)
		opts_row.add_child(db)
	_mode_box.add_child(diff_desc)

# Большая квадратная карточка режима: цветная рамка, название, описание.
func _mode_card(title: String, sub: String, accent: Color, cb: Callable) -> Button:
	var b := Button.new()
	b.custom_minimum_size = Vector2(224, 224)
	b.focus_mode = Control.FOCUS_NONE
	var sb := StyleBoxFlat.new()
	sb.bg_color = Color(0.045, 0.06, 0.12, 0.92)
	sb.set_corner_radius_all(14)
	sb.set_border_width_all(2)
	sb.border_color = Color(accent.r, accent.g, accent.b, 0.55)
	b.add_theme_stylebox_override("normal", sb)
	var sbh: StyleBoxFlat = sb.duplicate()
	sbh.border_color = accent
	sbh.bg_color = Color(0.07, 0.09, 0.17, 0.96)
	b.add_theme_stylebox_override("hover", sbh)
	var sbp: StyleBoxFlat = sbh.duplicate()
	sbp.bg_color = Color(0.10, 0.13, 0.22, 0.98)
	b.add_theme_stylebox_override("pressed", sbp)
	b.pressed.connect(cb)

	var mc := MarginContainer.new()
	mc.set_anchors_preset(Control.PRESET_FULL_RECT)
	mc.mouse_filter = Control.MOUSE_FILTER_IGNORE
	for m in ["margin_left", "margin_right", "margin_top", "margin_bottom"]:
		mc.add_theme_constant_override(m, 14)
	b.add_child(mc)
	var v := VBoxContainer.new()
	v.mouse_filter = Control.MOUSE_FILTER_IGNORE
	v.alignment = BoxContainer.ALIGNMENT_CENTER
	v.add_theme_constant_override("separation", 10)
	mc.add_child(v)

	var t := Label.new()
	t.text = title
	t.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	t.add_theme_font_size_override("font_size", 24)
	t.add_theme_color_override("font_color", accent)
	t.add_theme_constant_override("outline_size", 5)
	t.add_theme_color_override("font_outline_color", Color(accent.r * 0.25, accent.g * 0.25, accent.b * 0.25, 0.9))
	v.add_child(t)

	var s := Label.new()
	s.text = sub
	s.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	s.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	s.add_theme_font_size_override("font_size", 13)
	s.add_theme_color_override("font_color", Color(0.72, 0.78, 0.9))
	v.add_child(s)
	return b

# Магазин навыков (колесо Апекса) — тот же оверлей, что в паузе «Уровней».
# Правит глобальный профиль «Уровней» (в меню active_run всегда -1).
func _on_open_shop() -> void:
	var sm := CanvasLayer.new()
	sm.set_script(load("res://skills_menu.gd"))
	add_child(sm)

func _on_open_mode() -> void:
	_populate_mode()
	_hide_all_panels()
	_mode_scroll.visible = true
	_back_btn.visible = true

# =============================================================================
# СПУСК ДНЯ — ежедневный забег. Один и тот же лабиринт у всех игроков в этот
# день (сид = дата), одна попытка. Умер — приходи завтра. Механика — обёртка
# над забегом «Накал» (скрытый 4-й слот DAILY_SLOT в GameConfig).
# =============================================================================

func _build_daily(root: VBoxContainer) -> void:
	_daily_box = VBoxContainer.new()
	_daily_box.add_theme_constant_override("separation", 10)
	_daily_box.visible = false
	root.add_child(_daily_box)

func _populate_daily() -> void:
	for c in _daily_box.get_children():
		c.queue_free()

	var title := Label.new()
	title.text = "Спуск дня — %s" % GameConfig.today_str()
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	title.add_theme_font_size_override("font_size", 28)
	title.add_theme_color_override("font_color", Color(1.0, 0.85, 0.3))
	_daily_box.add_child(title)

	var sub := Label.new()
	sub.text = "Каждый день лабиринт один для всех: тот же лабиринт, те же враги.\nОдна попытка. Правила Накала: 3 жизни на весь спуск, смерть — конец."
	sub.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	sub.add_theme_font_size_override("font_size", 15)
	sub.add_theme_color_override("font_color", Color(0.7, 0.76, 0.88))
	_daily_box.add_child(sub)

	var streak := GameConfig.daily_streak()
	if streak >= 2:
		var sl := Label.new()
		sl.text = "🔥 Серия: %d %s подряд" % [streak, _plural(streak, "день", "дня", "дней")]
		sl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		sl.add_theme_font_size_override("font_size", 17)
		sl.add_theme_color_override("font_color", Color(1.0, 0.62, 0.25))
		_daily_box.add_child(sl)

	# --- Состояние сегодняшнего дня ---
	if GameConfig.daily_resumable():
		var msg := Label.new()
		msg.text = "Сегодняшний спуск не завершён — глубина %d." % int(GameConfig.runs[GameConfig.DAILY_SLOT].get("level", 1))
		msg.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		msg.add_theme_font_size_override("font_size", 17)
		msg.add_theme_color_override("font_color", Color(0.8, 0.9, 1.0))
		_daily_box.add_child(msg)
		_daily_box.add_child(_make_button("Продолжить спуск", func() -> void:
			GameConfig.resume_daily_run()
			get_tree().change_scene_to_file("res://main.tscn")))
	elif GameConfig.daily_played_today() and not GameConfig.test_mode:
		var today := GameConfig.today_str()
		var res: Dictionary = {}
		for e in GameConfig.daily_history:
			if str(e.get("date", "")) == today:
				res = e
		var msg := Label.new()
		msg.text = "Сегодня ты уже спускался: глубина %d, Накал %d.\nЛабиринт сменит облик в полночь — возвращайся завтра." % [
			int(res.get("depth", 1)), int(res.get("ember", 0))]
		msg.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		msg.add_theme_font_size_override("font_size", 17)
		msg.add_theme_color_override("font_color", Color(0.8, 0.9, 1.0))
		_daily_box.add_child(msg)
	else:
		if GameConfig.daily_played_today():
			var tst := Label.new()
			tst.text = "(тест-режим: лимит попыток отключён)"
			tst.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
			tst.add_theme_font_size_override("font_size", 14)
			tst.add_theme_color_override("font_color", Color(1.0, 0.6, 0.2))
			_daily_box.add_child(tst)
		_daily_box.add_child(_make_button("Начать спуск", func() -> void:
			GameConfig.start_daily_run()
			get_tree().change_scene_to_file("res://main.tscn")))

	# --- Последние дни ---
	if not GameConfig.daily_history.is_empty():
		var hl := Label.new()
		hl.text = "Последние дни"
		hl.add_theme_font_size_override("font_size", 20)
		hl.add_theme_color_override("font_color", Color(0.85, 0.9, 1.0))
		_daily_box.add_child(hl)
		var hist: Array = GameConfig.daily_history
		var start := maxi(0, hist.size() - 7)
		for i in range(hist.size() - 1, start - 1, -1):
			var e: Dictionary = hist[i]
			var l := Label.new()
			l.text = "%s   ·   глубина %d   ·   Накал %d" % [
				str(e.get("date", "?")), int(e.get("depth", 1)), int(e.get("ember", 0))]
			l.add_theme_font_size_override("font_size", 15)
			l.add_theme_color_override("font_color", Color(0.72, 0.78, 0.9))
			_daily_box.add_child(l)

	_daily_box.add_child(_make_button("Назад", _go_back))

func _on_open_daily() -> void:
	_populate_daily()
	_hide_all_panels()
	_daily_box.visible = true
	_back_btn.visible = true

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
	# Галерея навыков: иконки + клавиши — картинка вместо голого текста.
	var gal_title := Label.new()
	gal_title.text = "Навыки"
	gal_title.add_theme_font_size_override("font_size", 22)
	gal_title.add_theme_color_override("font_color", Color(0.85, 0.9, 1.0))
	box.add_child(gal_title)
	var gal := GridContainer.new()
	gal.columns = 6
	gal.add_theme_constant_override("h_separation", 12)
	gal.add_theme_constant_override("v_separation", 8)
	box.add_child(gal)
	for it in [["flash","Q Вспышка"],["dash","Shift Рывок"],["smother","R Тление"],["sonar","E Сонар"],["shield","C Щит"],["guide","G Искра"],["reveal","F Озарение"],["mirage","T Мираж"],["breach","Y Разлом"],["chrono","V Хронос"],["apex","H АПЕКС"]]:
		var cell := VBoxContainer.new()
		cell.alignment = BoxContainer.ALIGNMENT_CENTER
		var ic := TextureRect.new()
		ic.texture = SkillIcons.make(it[0], 34)
		ic.stretch_mode = TextureRect.STRETCH_KEEP_CENTERED
		ic.custom_minimum_size = Vector2(38, 38)
		cell.add_child(ic)
		var lb := Label.new()
		lb.text = it[1]
		lb.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		lb.add_theme_font_size_override("font_size", 12)
		lb.add_theme_color_override("font_color", SkillIcons.color_of(it[0]))
		cell.add_child(lb)
		gal.add_child(cell)
	body.text = _help_text()
	box.add_child(body)

	box.add_child(_make_button("Назад", _on_close_help))

func _on_open_help() -> void:
	_hide_all_panels()
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

СВЕТ И ВОЛЯ (два ресурса)
• СВЕТ (жёлтая полоса) — твоя жизнь. Медленно гаснет, пока идёшь во тьме; удары врагов гасят его сильнее. Погас совсем — минус жизнь. Восполняется глотками у энергокристаллов.
• ВОЛЯ (фиолетовая полоса) — топливо навыков. ТОЛЬКО навыки тратят Волю; тьма её не трогает. Копится сама понемногу, +за каждый осколок и +за каждый глоток станции. Играешь активно — навыки кормят сами себя.

ЭНЕРГОКРИСТАЛЛЫ (синие)
Заходишь — кристалл мгновенно даёт глоток света, немного Воли, XP и заряд «Озарения», и служит точкой сохранения (после гибели появляешься у последнего). Затем он истощается и ~3 секунды восстанавливается (видно по кольцу-шкале вокруг) — пока не зарядится снова, не действует. Стоять и фармить бесконечно нельзя: чтобы взять ещё глоток, выйди из зоны и вернись. НО: пока стоишь в зоне кристалла, Свет не гаснет — станция служит убежищем, где можно перевести дух и осмотреться.

ОСКОЛКИ СВЕТА (золотые)
Собираемые бонусы: дают немного заряда света, немного Воли и идут в счётчик. Каждый осколок — это КЛЮЧ для запертой двери.

ЖИЗНИ
Несколько жизней на уровень (настройка). Свет погас — минус жизнь и возврат на станцию. Жизни кончились — игра окончена.

КАК ОТКРЫВАЮТСЯ НАВЫКИ (режим «Уровни»)
Закрытый навык можно купить за SP в меню навыков — ИЛИ он откроется сам за игровое достижение: Сонар — за 25 собранных осколков, Щит — за 8 побеждённых врагов, Искра — за 20 глотков из кристаллов, Озарение — за 6 пройденных уровней. Прогресс целей виден в Дневнике («Путь к навыкам»). Каждое применение навыка растит его МАСТЕРСТВО (+15% силы за уровень, до 5 звёзд) — играть активно выгодно вдвойне.

АКТИВНЫЕ НАВЫКИ (тратят Волю, есть перезарядка)
• Q — Вспышка: яркий импульс, осмотреться вокруг — и наносит урон врагам вблизи (ближний бой). Но помни: яркая вспышка ДЕМАСКИРУЕТ — враги видят тебя дальше обычного, пока она горит.
• R — Тление: «задержать дыхание» — добровольно пригаситься на пару секунд. Ты медленнее и почти слеп, но враги ТЕРЯЮТ тебя (заметность падает до ~20%). Погоня на хвосте? Юркни за угол, притлей — и охотник пробежит мимо.
• Shift / Пробел — Рывок: быстрый рывок в сторону движения, оторваться от опасности — а если во время рывка врезаешься во врага, урон достаётся ЕМУ, а не тебе («таран»).
• E — Сонар: кольцо света сквозь стены, разведка планировки за углами — расходящееся кольцо наносит урон всем врагам, кого задевает (дальний бой).
• C — Щит: на несколько секунд полностью останавливает разрядку и защищает от тьмы; если враг коснётся тебя под щитом — он сам замирает на 4 сек (чисто оборона, без урона).

БОЙ С ВРАГАМИ
У врагов есть запас прочности (у быстрых меньше, у остальных больше). Сбить его можно тараном на Рывке, вспышкой в упор или кольцом Сонара — три разных стиля: мобильный (Рывок), ближний (Вспышка), дальний (Сонар). Щит — чисто оборона, урона не наносит. Уничтоженный враг даёт немного опыта и (в «Накале») Накала.
• F — Озарение: накопительный навык. Подсвечивает весь этаж на пару секунд. Копится на станциях.
• G — Искра: пускает светящийся маячок-проводник в сторону выхода — если потерялся, он покажет направление.
• H — Апекс: мощный супернавык с долгой перезарядкой, открывается автоматически, когда куплены все остальные активные навыки. Принимает форму твоего самого используемого навыка (усиленная версия) + слабое «эхо» второго по использованию. Работает ТОЛЬКО если рядом реально гонится враг (иначе молчит, не тратя ни энергию, ни кулдаун) — и в каждой форме уничтожает тех, кто гонится, насмерть: Вспышка/Рывок/Сонар — в радиусе, Искра/Озарение — на всём этаже, Щит — любого, кто коснётся тебя, пока он активен.

КОМБО НАВЫКОВ (сочетай осознанно)
• Световое копьё — Рывок ВО ВРЕМЯ Вспышки: дальность рывка ×1.5.
• Всевидение — Сонар ВО ВРЕМЯ Озарения: волна вдвое шире и оглушает всех врагов на пару секунд.

ПАССИВКИ (внешнее кольцо в «Магазине»; не покупаются — растут сами от твоих действий, до 5 уровней)
Каждая пассивка — ветвь конкретного навыка: её уровень усиливает и сам навык, и форму Апекса от него. Энергосбережение (−6% разрядки/ур → Озарение), Ёмкость (+6% запаса/ур → Щит), Быстрая зарядка (+10%/ур → Искра), Дальний свет (+5% радиуса/ур → Вспышка), Лёгкие ноги (+3% скорости/ур → Рывок), Эффективная магия (дешевле и быстрее навыки → Сонар), Обман (→ Мираж), Сокрушение (→ Разлом), Стазис (→ Хронос).

НАКОПИТЕЛЬНЫЕ ПАССИВКИ (растут в процессе игры)
• Разгон — скорость растёт по мере пройденного расстояния (до +30%).
• Адаптация — разрядка слабеет по мере выживания (до −30%).

СЛУЧАЙНЫЕ СОБЫТИЯ (с уровня 2)
• Просвет ✦ — бонус: радиус видимости на время расширяется (не убирает тьму целиком) и немного заряда.
• Пятна тумана ≈ — на этаже появляются 2-3 клубящиеся «кляксы»; внутри пятна видимость резко падает, снаружи — всё как обычно. Спустя время рассасываются. Можно обойти, а можно нырнуть насквозь.
• Утечка света ⚠ — свет тратится быстрее.
• Перебой света ⚡ — свечение мерцает.
• Сдвиг стен ▦ — лабиринт меняется (один проход закрывается, другой открывается; пройти всё равно можно).
• Землетрясение ⛰ (редкое) — часть стен этажа рушится, открывая новые проходы. Хаос — но и короткие пути.

ПОДАРКИ ЛАБИРИНТА (каждый — не чаще раза за уровень)
• Резонанс ✧ — собери 3 осколка подряд без урона, и тьма ненадолго отступит: весь этаж видно несколько секунд.
• Эхо осколка ✦ — иногда через пару секунд после сбора из той же точки поднимается ВТОРОЙ осколок (слышен сигнал). Решай: вернуться за ним или идти дальше.
• Тишина ❄ — если получил два удара за короткое время, все враги застывают на 5 секунд. Передышка, чтобы выдохнуть и уйти.

МАЯК (раз в уровень, не раньше 20 сек от старта)
Где-то в лабиринте на 20-30 секунд загорается яркая мерцающая точка — слышен тихий «пинг», но где именно она появилась, не сказано. Успеешь добежать — получишь случайный бонус (лишние осколки, полный заряд света, заморозка всех врагов на 5 сек, сброс перезарядки случайного навыка, а в «Накале» — ещё и Накал). Не успеешь — она просто гаснет. Решай сам: рискнуть и сорваться за ней или спокойно идти своим маршрутом. Пока маяк горит, от тебя раз в пару секунд улетает полупрозрачная искра в его сторону — направление подсказано (отключается в настройках).

ДВЕРЬ БОССА (уровни, кратные 5)
Где-то в лабиринте появляется БАГРОВЫЙ портал с черепом ☠ — он не обязателен. Войдёшь — попадёшь на арену Тёмного Ядра (фаза 1: Вспышка в упор, Сонар ×2; фаза 2: добей три фрагмента). Победа даёт ДАР — новый навык, недоступный иначе, — и возвращает тебя на место.

ДАРЫ ЯДРА (по одному за каждую победу, влияют и на Апекс!)
• T — Мираж: ложная светящаяся цель — враги поблизости бегут проверять её. Апекс-форма: приманки по всему этажу + сам тлеешь.
• Y — Разлом: проламывает стену по направлению взгляда. Апекс-форма: пролом трёх стен + удар по преследователям.
• V — Хронос: замораживает врагов этажа. Апекс-форма: долгая остановка времени + глоток Воли.
Помни: Апекс принимает форму САМОГО ПРОКАЧАННОГО навыка — дары расширяют его варианты.

ЗАМЕТНОСТЬ (ты — свет, и это твоя уязвимость)
Радиус, с которого враги замечают тебя, зависит от твоей ЯРКОСТИ. Вспышка и несомый Накал делают тебя видимым издалека; Тление (R) прячет почти полностью. Гореть ярко или тлеть незаметно — решай по ситуации.

ВРАГИ (с уровня 4, тип и число растут с каждым чётным уровнем)
Три базовых типа — медленный (фиолетовый), быстрый (оранжевый) и цикличный (бирюзовый). На глубине приходят ЭЛИТНЫЕ:
• Страж (багровый, с ур. 25) — броня 6 HP, медленный, видит в полтора раза дальше. Заморозь (Щит/Хронос: замороженный ловит +1 урона) и бей — или обойди.
• Фантом (бледный, с ур. 30) — 1 HP, но очень быстрый. Один точный удар решает; Тление сбрасывает его погоню.
• Пиявка (зелёная, с ур. 35) — при касании высасывает ВОЛЮ, топливо навыков. Не подпускай: Сонар издалека, Рывок мимо. Враг живёт своей жизнью: бродит по этажу, пока не заметит тебя. Заметить может, только если ты в его радиусе видимости И между вами нет стены — сквозь стены не видит. Заметив — гонится по кратчайшему пути; потеряв из виду, ещё несколько секунд ищет тебя у последнего замеченного места, а затем возвращается к своим делам. Вблизи погоня давит: враг почти не отстаёт по скорости, оторваться получится только точной игрой, а не просто отойти на шаг. Противодействие: Щит (замораживает врага при контакте, без урона), Рывок (оторваться), станции (заряжайся и убегай).

ПЕРЕГЕНЕРАЦИЯ (опция, от 4 дверей)
Если включить, при переходе через дверь этаж может полностью пересобраться. Карта пройденного пути этого этажа при этом обнуляется.

КАРТА
В паузе (P или Esc) можно посмотреть карту текущего этажа — на ней виден только уже пройденный путь.

РЕЖИМЫ ИГРЫ
• «Уровни» — классический режим: 50 уровней (сложность растёт плавно, к 40-му — как прежний максимум), жизни на каждый уровень свои, прогресс сохраняется навсегда, навыки покупаются за SP в обычном меню.
• «Спуск дня» — ежедневный забег по правилам Накала: сид от даты, у ВСЕХ игроков в этот день один и тот же лабиринт, одна попытка в сутки. Результаты и серия дней — в Дневнике. (Для тестов лимит попыток отключается в настройках.)
СЛОЖНОСТЬ (выбирается в меню «Играть», влияет на оба режима)
• ◦ Тлеющий — мягче: свет тает на треть медленнее, враги ленивее, +2 жизни. Награды ×0.75.
• ● Горящий — базовый баланс. Награды ×1.
• ☀ Пылающий — в «Уровнях» станций НЕТ: свет только из осколков (двойной глоток + заряд Озарения, стартовый запас ×2). Враги злее. Награды ×1.5, а прохождение отмечается в Дневнике особой меткой — есть смысл перепройти любимые уровни на пределе.
• «Накал» — рогалик-забег на 3 сохранения: старт всегда с нуля (только Вспышка и Рывок), 3 жизни на ВЕСЬ забег, спуск бесконечный. Несомый Накал — рискованная валюта, которую можно потерять при гибели (сгорает наполовину); станции в этом режиме ещё и алтари — заходишь и банкуешь Накал в безопасный запас, который тратится в магазине алтаря на постоянные для этого забега навыки и улучшения. Чем больше несёшь Накала — тем ярче горишь и тем агрессивнее враги; жар виден по оранжевой «горящей» кромке экрана, которая пульсирует как сердцебиение — чем чаще бьётся, тем ты заметнее.

РАНГ УРОВНЯ (S / A / B / C / D)
За каждый пройденный уровень начисляется ранг по четырём критериям: сколько осколков собрано, прошёл ли без урона, не потратил ли ни одного применения навыка и уложился ли в ориентировочное время. Чем больше выполнено — тем выше ранг.

РЕЗУЛЬТАТЫ (пункт меню)
Отдельный экран с историей последних пройденных уровней и разбором своей игры: среднее время относительно ориентира, доля уровней без урона, самый частый ранг, какой навык почти не используется — и текстовые подсказки, что стоит попробовать по-другому.

УРОВНИ
Всего 50 уровней в «Уровнях» (в «Накале» — бесконечно). Чем выше — тем больше лабиринт, темнее, быстрее разрядка, чаще события и опаснее враги. С 4-го уровня форма лабиринта дышит в ритме: обычный → УЗКИЙ (длинные тесные коридоры — рывок и вспышка решают) → ШИРОКИЙ (открытые залы с петлями — враги видят издалека), и снова по кругу.

УПРАВЛЕНИЕ
Стрелки — движение. Q / Shift (или Пробел) / R / E / C / F / G / H / T / Y / V — навыки. P или Esc — пауза. F5 — начать уровень заново."""

func _on_play(lvl: int = 1) -> void:
	GameConfig.level = lvl
	get_tree().change_scene_to_file("res://main.tscn")

func _on_open_tutorial() -> void:
	GameConfig.active_run = -1
	GameConfig.tutorial_mode = true
	GameConfig.level = 1
	get_tree().change_scene_to_file("res://main.tscn")

func _on_open_level_select() -> void:
	_hide_all_panels()
	_level_box.visible = true
	_back_btn.visible = true

func _on_close_level_select() -> void:
	_go_back()

func _on_open_settings() -> void:
	_hide_all_panels()
	_settings_scroll.visible = true
	_back_btn.visible = true

func _on_close_settings() -> void:
	_go_back()

func _on_reset_progress() -> void:
	GameConfig.reset_progress()

func _on_quit() -> void:
	GameConfig.save_game()
	get_tree().quit()
