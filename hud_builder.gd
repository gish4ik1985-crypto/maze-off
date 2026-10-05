extends RefCounted

# Вынесено из main.gd механически (tools/extract_fn.py, v6.8): код функций
# тот же, что был в main.gd; `g` — главный узел, все его члены с префиксом `g.`.
# Состояние остаётся в main.gd (переменные `_hud_layer`, `_vitals`, …).

static func _build_hud(g) -> void:
	# Слой тинта (под HUD, над миром)
	var fx = CanvasLayer.new()
	fx.layer = 1
	g.add_child(fx)

	g._tint = ColorRect.new()
	g._tint.set_anchors_preset(Control.PRESET_FULL_RECT)
	g._tint.color = Color(0, 0, 0, 0)
	g._tint.mouse_filter = Control.MOUSE_FILTER_IGNORE
	fx.add_child(g._tint)

	# Виньетка темноты («туман войны») — шар видимости вокруг игрока (камера держит
	# его в центре экрана). Приоткрывается во время Озарения; max_dark<1 пропускает
	# яркий свет (сонар, выход), гася лишь тусклый ambient далёкого лабиринта.
	var dark_rect = ColorRect.new()
	dark_rect.set_anchors_preset(Control.PRESET_FULL_RECT)
	dark_rect.mouse_filter = Control.MOUSE_FILTER_IGNORE
	g._dark_mat = ShaderMaterial.new()
	g._dark_mat.shader = load("res://darkness.gdshader")
	g._dark_mat.set_shader_parameter("inner", g.DARK_INNER)
	g._dark_mat.set_shader_parameter("outer", g.DARK_OUTER)
	g._dark_mat.set_shader_parameter("max_dark", g.DARK_MAX)
	dark_rect.material = g._dark_mat
	fx.add_child(dark_rect)
	g._update_darkness_aspect()
	g.get_viewport().size_changed.connect(g._update_darkness_aspect)

	var layer = CanvasLayer.new()
	layer.layer = 2
	g.add_child(layer)
	g._hud_layer = layer

	# ═══ HUD «Фонарь» (v6.0) ═══
	# Раньше: сплошная тёмная полоса на всю ширину, стандартные ProgressBar и
	# подписи «Свет / Воля / Осколки: 0 / 5». С миром (неон, тьма, мягкий свет) это
	# не складывалось. Теперь ничего не заперто в панель: у краёв лишь мягкое
	# затемнение под текстом, а сами элементы светятся, как всё остальное.
	#   слева-сверху — орб жизненных сил (дуги Света и Воли вокруг лампы) и уровень;
	#   справа-сверху — сердца-жизни, осколки, ключи (иконка + число);
	#   по центру — таймер и (в Накале) плашка жара;
	#   снизу — панель навыков: круглые «бусины» с кольцом перезарядки, над ней —
	#           стойка света и накопительные пассивки.
	g._add_edge_fade(layer, true, 96.0)
	g._add_edge_fade(layer, false, 124.0)

	# --- Слева-сверху: орб + уровень/биом/этаж + полоска опыта ---
	g._vitals = HudVitals.new()
	g._vitals.position = Vector2(12, 5)
	g._vitals.tooltip_text = GameConfig.tt(
		"Свет (внешняя дуга) — твоя жизнь. Тает от движения во тьме и ударов врагов, гаснет совсем — минус жизнь.\nВосполняется у станций/осколков; рядом со станцией не тает вовсе.\n\n",
		"Light (outer arc) is your life. Drains as you move in the dark and from enemy hits — fully out costs a life.\nRefills at stations/shards; doesn't drain at all right next to a station.\n\n") + g._will_tooltip_text()
	layer.add_child(g._vitals)

	g._level_label = Label.new()
	g._level_label.text = GameConfig.tt("Уровень %d", "Level %d") % g._level
	g._level_label.position = Vector2(90, 6)
	g._level_label.add_theme_font_size_override("font_size", 21)
	g._level_label.add_theme_color_override("font_color", Color(0.9, 0.95, 1.0))
	g._label_outline(g._level_label)
	layer.add_child(g._level_label)

	g._sub_label = Label.new()
	g._sub_label.text = GameConfig.tt("этаж 1 / %d", "floor 1 / %d") % g._floors
	g._sub_label.position = Vector2(90, 33)
	g._sub_label.add_theme_font_size_override("font_size", 13)
	g._sub_label.add_theme_color_override("font_color", Color(0.62, 0.74, 0.92))
	g._label_outline(g._sub_label, 3)
	layer.add_child(g._sub_label)

	# Полоска опыта до следующего SP — тонкая светящаяся нить под названием.
	g._xp_bar = ProgressBar.new()
	g._xp_bar.min_value = 0
	g._xp_bar.max_value = GameConfig.XP_PER_SP
	g._xp_bar.show_percentage = false
	g._xp_bar.position = Vector2(91, 56)
	g._xp_bar.custom_minimum_size = Vector2(150, 4)
	g._xp_bar.size = Vector2(150, 4)
	var xb = StyleBoxFlat.new()
	xb.bg_color = Color(0.1, 0.12, 0.2, 0.75)
	xb.set_corner_radius_all(2)
	g._xp_bar.add_theme_stylebox_override("background", xb)
	var xf = StyleBoxFlat.new()
	xf.bg_color = Color(0.68, 0.52, 1.0)
	xf.set_corner_radius_all(2)
	xf.shadow_color = Color(0.68, 0.52, 1.0, 0.5)
	xf.shadow_size = 4
	g._xp_bar.add_theme_stylebox_override("fill", xf)
	layer.add_child(g._xp_bar)

	g._sp_label = Label.new()
	g._sp_label.position = Vector2(250, 48)
	g._sp_label.add_theme_font_size_override("font_size", 13)
	g._sp_label.add_theme_color_override("font_color", Color(0.82, 0.72, 1.0))
	g._label_outline(g._sp_label, 3)
	g._sp_label.mouse_filter = Control.MOUSE_FILTER_STOP
	layer.add_child(g._sp_label)

	# --- По центру сверху: плашка жара (Накал) и таймер ---
	var center = VBoxContainer.new()
	center.set_anchors_preset(Control.PRESET_TOP_WIDE)
	center.offset_top = 8.0
	center.offset_bottom = 66.0
	center.add_theme_constant_override("separation", 4)
	center.mouse_filter = Control.MOUSE_FILTER_IGNORE
	layer.add_child(center)

	if GameConfig.active_run >= 0:
		var pill = PanelContainer.new()
		pill.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
		pill.mouse_filter = Control.MOUSE_FILTER_IGNORE
		var psb = StyleBoxFlat.new()
		psb.bg_color = Color(0.10, 0.04, 0.02, 0.55)
		psb.set_corner_radius_all(15)
		psb.set_border_width_all(1)
		psb.border_color = Color(1.0, 0.6, 0.25, 0.55)
		psb.shadow_color = Color(1.0, 0.5, 0.15, 0.22)
		psb.shadow_size = 8
		psb.content_margin_left = 16.0
		psb.content_margin_right = 16.0
		psb.content_margin_top = 3.0
		psb.content_margin_bottom = 3.0
		pill.add_theme_stylebox_override("panel", psb)
		center.add_child(pill)
		g._ember_label = Label.new()
		g._ember_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		g._ember_label.add_theme_font_size_override("font_size", 16)
		g._ember_label.add_theme_color_override("font_color", Color(1.0, 0.72, 0.3))
		pill.add_child(g._ember_label)

	var time_row = HBoxContainer.new()
	time_row.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	time_row.add_theme_constant_override("separation", 6)
	time_row.mouse_filter = Control.MOUSE_FILTER_IGNORE
	center.add_child(time_row)
	g._time_icon = g._add_icon(time_row, "clock", Color(0.6, 0.85, 1.0), Vector2.ZERO, 16)
	g._time_label = Label.new()
	g._time_label.text = GameConfig.tt("0.0 с", "0.0 s")
	g._time_label.add_theme_font_size_override("font_size", 15)
	g._time_label.add_theme_color_override("font_color", Color(0.78, 0.88, 1.0, 0.9))
	g._label_outline(g._time_label)
	time_row.add_child(g._time_label)

	# [SAFETY 2026-07-29] Тест-флаг боссов работал МОЛЧА: он заменяет ареной
	# каждый уровень кампании, но на экране об этом ничего не говорило. Игрок
	# дважды приходил с вопросами — «уровень 49 чёрный» (§28) и «а где сами
	# лабиринты?». Пока флаг включён, он обязан быть виден.
	if GameConfig.boss_test_enabled:
		var warn = Label.new()
		warn.text = GameConfig.tt("⚔ ТЕСТ БОССОВ: все уровни — арены", "⚔ BOSS TEST: every level is an arena")
		warn.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
		warn.add_theme_font_size_override("font_size", 13)
		warn.add_theme_color_override("font_color", Color(1.0, 0.62, 0.2))
		warn.mouse_filter = Control.MOUSE_FILTER_STOP
		warn.tooltip_text = GameConfig.tt(
			"Выключается в Настройках → Тестирование. Обычные лабиринты вернутся сразу.",
			"Turn it off in Settings → Testing. Normal mazes come back immediately.")
		g._label_outline(warn, 3)
		center.add_child(warn)

	# --- Справа-сверху: жизни / осколки / ключи (иконка + число, без подписей) ---
	var right = VBoxContainer.new()
	right.anchor_left = 1.0
	right.anchor_right = 1.0
	right.offset_left = -300.0
	right.offset_right = -16.0
	right.offset_top = 8.0
	right.offset_bottom = 84.0
	right.add_theme_constant_override("separation", 3)
	right.mouse_filter = Control.MOUSE_FILTER_IGNORE
	layer.add_child(right)

	g._lives_box = HBoxContainer.new()
	g._lives_box.alignment = BoxContainer.ALIGNMENT_END
	g._lives_box.add_theme_constant_override("separation", 5)
	g._lives_box.mouse_filter = Control.MOUSE_FILTER_STOP
	g._lives_box.tooltip_text = GameConfig.tt(
		"Жизни. Свет погас — минус одна, возврат к последней станции, и тьма забирает землю, которую ты держал.",
		"Lives. When your Light runs out you lose one, return to the last station, and the dark takes back the ground you held.")
	right.add_child(g._lives_box)
	g._update_lives()

	var shard_row = HBoxContainer.new()
	shard_row.alignment = BoxContainer.ALIGNMENT_END
	shard_row.add_theme_constant_override("separation", 7)
	shard_row.mouse_filter = Control.MOUSE_FILTER_IGNORE
	right.add_child(shard_row)
	# Серия: слева от счётчика осколков, чтобы читаться одним движением глаз.
	g._streak_label = Label.new()
	g._streak_label.add_theme_font_size_override("font_size", 14)
	g._streak_label.pivot_offset = Vector2(60, 10)
	g._streak_label.visible = false
	g._streak_label.mouse_filter = Control.MOUSE_FILTER_STOP
	g._streak_label.tooltip_text = GameConfig.tt(
		"Серия осколков без урона: каждый следующий осколок дороже (до ×2.5).\nЛюбой удар врага серию обрывает.",
		"Shard streak without damage: each next shard is worth more (up to x2.5).\nAny enemy hit breaks it.")
	g._label_outline(g._streak_label)
	shard_row.add_child(g._streak_label)
	g._shards_icon = g._add_icon(shard_row, "shard", Color(1.0, 0.82, 0.4), Vector2.ZERO, 22)
	g._shards_label = Label.new()
	g._shards_label.add_theme_font_size_override("font_size", 19)
	g._shards_label.add_theme_color_override("font_color", Color(1.0, 0.92, 0.55))
	g._shards_label.mouse_filter = Control.MOUSE_FILTER_STOP
	g._shards_label.tooltip_text = GameConfig.tt(
		"Осколки уровня: собрано / всего. Каждый — улика о выходе, глоток Воли и ключ для дверей между этажами.",
		"Level shards: collected / total. Each is a clue to the exit, a sip of Will and a key for the doors between floors.")
	g._label_outline(g._shards_label)
	shard_row.add_child(g._shards_label)

	var key_row = HBoxContainer.new()
	key_row.alignment = BoxContainer.ALIGNMENT_END
	key_row.add_theme_constant_override("separation", 7)
	key_row.mouse_filter = Control.MOUSE_FILTER_IGNORE
	right.add_child(key_row)
	g._keys_icon = g._add_icon(key_row, "key", Color(0.55, 0.85, 1.0), Vector2.ZERO, 22)
	g._keys_label = Label.new()
	g._keys_label.add_theme_font_size_override("font_size", 19)
	g._keys_label.add_theme_color_override("font_color", Color(0.72, 0.88, 1.0))
	g._keys_label.mouse_filter = Control.MOUSE_FILTER_STOP
	g._keys_label.tooltip_text = GameConfig.tt(
		"Ключи: каждый собранный осколок даёт один. Открывают запертые двери между этажами.",
		"Keys: every shard you collect gives one. They open the locked doors between floors.")
	g._label_outline(g._keys_label)
	key_row.add_child(g._keys_label)

	# [§39] Строка последней улики. Живёт под правым столбцом, чтобы не лезть на
	# него, и появляется только когда улика есть: пустая строка на экране
	# читалась бы как «что-то сломалось».
	g._clue_label = Label.new()
	g._clue_label.anchor_left = 1.0
	g._clue_label.anchor_right = 1.0
	g._clue_label.offset_left = -496.0
	g._clue_label.offset_right = -16.0
	g._clue_label.offset_top = g.HUD_BAND + 8.0
	g._clue_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	g._clue_label.add_theme_font_size_override("font_size", 15)
	g._clue_label.add_theme_color_override("font_color", Color(1.0, 0.82, 0.45))
	g._label_outline(g._clue_label)
	g._clue_label.visible = false
	g._clue_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	layer.add_child(g._clue_label)
	g._update_shards()

	# --- Снизу по центру: строка состояния (стойка / пассивки) и панель навыков ---
	g._hud_bottom = VBoxContainer.new()
	g._hud_bottom.anchor_left = 0.0
	g._hud_bottom.anchor_right = 1.0
	g._hud_bottom.anchor_top = 1.0
	g._hud_bottom.anchor_bottom = 1.0
	g._hud_bottom.offset_top = -100.0
	g._hud_bottom.offset_bottom = -6.0
	g._hud_bottom.alignment = BoxContainer.ALIGNMENT_END
	g._hud_bottom.add_theme_constant_override("separation", 4)
	g._hud_bottom.mouse_filter = Control.MOUSE_FILTER_IGNORE
	layer.add_child(g._hud_bottom)

	var status = HBoxContainer.new()
	status.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	status.add_theme_constant_override("separation", 24)
	status.mouse_filter = Control.MOUSE_FILTER_IGNORE
	g._hud_bottom.add_child(status)

	# [GAMEDESIGN §29] Стойка света — три «пилюли» и подпись с текущим расходом.
	# Стоит рядом с навыками: управляется так же, с клавиатуры, в бою.
	var stance_box = HBoxContainer.new()
	stance_box.add_theme_constant_override("separation", 8)
	stance_box.mouse_filter = Control.MOUSE_FILTER_STOP
	stance_box.tooltip_text = GameConfig.tt(
		"Стойка света (Z / X или колесо мыши).\nЯркий — видишь дальше, но горишь быстрее и тебя видно издалека.\nТусклый — экономишь Свет и прячешься, но идёшь вслепую и медленнее.",
		"Light stance (Z / X or mouse wheel).\nBright — see farther, but burn faster and be seen from afar.\nDim — save Light and hide, but walk near-blind and slower.")
	status.add_child(stance_box)
	g._stance_row = stance_box
	g._stance_pips = HudStance.new()
	stance_box.add_child(g._stance_pips)
	g._stance_label = Label.new()
	g._stance_label.add_theme_font_size_override("font_size", 12)
	g._label_outline(g._stance_label, 3)
	stance_box.add_child(g._stance_label)

	# Накопительные пассивки — рядом со стойкой
	g._boost_row = HBoxContainer.new()
	g._boost_row.add_theme_constant_override("separation", 5)
	g._boost_row.mouse_filter = Control.MOUSE_FILTER_IGNORE
	status.add_child(g._boost_row)
	g._add_icon(g._boost_row, "boost", Color(0.5, 0.95, 0.6), Vector2.ZERO, 16)
	g._boost_label = Label.new()
	g._boost_label.add_theme_font_size_override("font_size", 12)
	g._boost_label.add_theme_color_override("font_color", Color(0.6, 0.95, 0.7))
	g._label_outline(g._boost_label, 3)
	g._boost_row.add_child(g._boost_label)

	g._adapt_row = HBoxContainer.new()
	g._adapt_row.add_theme_constant_override("separation", 5)
	g._adapt_row.mouse_filter = Control.MOUSE_FILTER_IGNORE
	status.add_child(g._adapt_row)
	g._add_icon(g._adapt_row, "adapt", Color(0.5, 0.95, 0.6), Vector2.ZERO, 16)
	g._adapt_label = Label.new()
	g._adapt_label.add_theme_font_size_override("font_size", 12)
	g._adapt_label.add_theme_color_override("font_color", Color(0.6, 0.95, 0.7))
	g._label_outline(g._adapt_label, 3)
	g._adapt_row.add_child(g._adapt_label)

	# Панель навыков: ряд «бусин», центрируется сам (_layout_skills считает ширину).
	g._skill_bar = Control.new()
	g._skill_bar.custom_minimum_size = Vector2(0, SkillHudIcon.H)
	g._skill_bar.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	g._skill_bar.mouse_filter = Control.MOUSE_FILTER_IGNORE
	g._hud_bottom.add_child(g._skill_bar)
	for d in g.SKILL_DEFS:
		g._make_skill_chip(g._skill_bar, d)
	g._layout_skills()

	# --- Подсказка по паузе — мелко в нижнем-правом углу ---
	var hint = Label.new()
	hint.text = GameConfig.tt("P / Esc — пауза", "P / Esc — pause")
	hint.set_anchors_preset(Control.PRESET_BOTTOM_RIGHT)
	hint.offset_left = -150
	hint.offset_right = -12
	hint.offset_top = -26
	hint.offset_bottom = -8
	hint.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	hint.add_theme_font_size_override("font_size", 13)
	hint.add_theme_color_override("font_color", Color(0.5, 0.53, 0.6))
	g._label_outline(hint, 3)
	hint.mouse_filter = Control.MOUSE_FILTER_IGNORE
	layer.add_child(hint)

	# --- Счётчик FPS (внизу слева, только если включён в настройках) ---
	if GameConfig.show_fps:
		g._fps_label = Label.new()
		g._fps_label.set_anchors_preset(Control.PRESET_BOTTOM_LEFT)
		g._fps_label.offset_left = 16
		g._fps_label.offset_right = 200
		g._fps_label.offset_top = -30
		g._fps_label.offset_bottom = -6
		g._fps_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
		g._fps_label.text = "FPS: 0"
		g._fps_label.add_theme_font_size_override("font_size", 16)
		g._fps_label.add_theme_color_override("font_color", Color(0.6, 0.95, 0.7))
		g._label_outline(g._fps_label, 3)
		g._fps_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
		layer.add_child(g._fps_label)

	# Сообщение (тост) — вверху по центру, под строкой события. Тёмная плашка
	# с рамкой + крестик-закрытие, а не голый жёлтый текст без фона (жалоба
	# «не просто жёлтое сообщение, а нормальное всплывающее, которое висит и
	# его можно выключить или просто смотреть»): держится дольше (см.
	# flash_message — время зависит от длины текста) и закрывается вручную.
	g._top_stack = VBoxContainer.new()
	g._top_stack.set_anchors_preset(Control.PRESET_TOP_WIDE)
	g._top_stack.position = Vector2(0, g.HUD_BAND + 10.0)
	g._top_stack.add_theme_constant_override("separation", 8)
	g._top_stack.mouse_filter = Control.MOUSE_FILTER_IGNORE
	layer.add_child(g._top_stack)

	# Сообщения живут в левом углу под HUD, а не по центру: центр — это игра
	# (и цель обучения); угол её не закрывает (v6.4, §85).
	g._toast_col = VBoxContainer.new()
	g._toast_col.position = Vector2(16, g.HUD_BAND + 10.0)
	g._toast_col.mouse_filter = Control.MOUSE_FILTER_IGNORE
	layer.add_child(g._toast_col)

	g._toast_panel = PanelContainer.new()
	g._toast_panel.visible = false
	g._toast_panel.size_flags_horizontal = Control.SIZE_SHRINK_BEGIN
	g._toast_panel.mouse_filter = Control.MOUSE_FILTER_STOP
	g._toast_sb = UIStyle.panel_stylebox(Color(1.0, 0.82, 0.45, 0.55))
	g._toast_sb.bg_color.a = 0.62
	g._toast_sb.content_margin_top = 7
	g._toast_sb.content_margin_bottom = 7
	g._toast_panel.add_theme_stylebox_override("panel", g._toast_sb)
	g._toast_col.add_child(g._toast_panel)

	var toast_row = HBoxContainer.new()
	toast_row.add_theme_constant_override("separation", 10)
	g._toast_panel.add_child(toast_row)

	g._toast_label = Label.new()
	g._toast_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_LEFT
	g._toast_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	g._toast_label.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	g._toast_label.add_theme_font_size_override("font_size", 18)
	g._toast_label.add_theme_color_override("font_color", Color(1.0, 0.85, 0.52))
	toast_row.add_child(g._toast_label)

	var toast_close = Button.new()
	toast_close.text = "×"
	toast_close.focus_mode = Control.FOCUS_NONE
	toast_close.custom_minimum_size = Vector2(40, 40) if GameConfig.touch_ui() else Vector2(26, 26)
	toast_close.size_flags_vertical = Control.SIZE_SHRINK_BEGIN
	toast_close.add_theme_font_size_override("font_size", 16)
	UIStyle.style_button(toast_close)
	toast_close.pressed.connect(func() -> void:
		g._toast_time = 0.0
		g._toast_next())
	toast_row.add_child(toast_close)

	# Сообщение о событии (вверху по центру) — тоже плашка с фоном, не голый
	# обведённый текст (тот же приём, что у тоста/эпизодов победы ниже).
	g._event_label = g._build_message_panel(layer, Control.PRESET_TOP_WIDE, Vector2(0, 24), 22,
		Color(0.6, 0.6, 0.72, 0.55))

	# Сообщение о смерти — раньше голый красный текст на весь экран без фона,
	# который то ли всплыл, то ли нет; теперь настоящая плашка по центру.
	g._msg_label = g._build_message_panel(layer, Control.PRESET_CENTER, Vector2.ZERO, 30,
		Color(1.0, 0.4, 0.4, 0.55))
	g._msg_label.add_theme_color_override("font_color", Color(1.0, 0.55, 0.5))

	# Экран победы — та самая «жёлтая надпись в конце уровня» без фона и без
	# возможности спокойно прочитать (жалоба повторялась несколько раз).
	# Теперь плашка как везде; для обычного прохождения уровня/Накала она почти
	# сразу сменяется полным экраном результатов (_show_stats_screen), а для
	# терминальных экранов (обучение/финал кампании/Логово) держится, пока не
	# нажат Esc — и её наконец можно спокойно дочитать.
	g._win_label = g._build_message_panel(layer, Control.PRESET_CENTER, Vector2.ZERO, 32,
		Color(1.0, 0.85, 0.3, 0.6))
	g._win_label.add_theme_color_override("font_color", Color(1.0, 0.85, 0.3))

	g._build_pause_overlay(layer)

static func _build_pause_overlay(g, layer: CanvasLayer) -> void:
	g._pause_overlay = Control.new()
	g._pause_overlay.set_anchors_preset(Control.PRESET_FULL_RECT)
	g._pause_overlay.visible = false
	g._pause_overlay.process_mode = Node.PROCESS_MODE_ALWAYS
	layer.add_child(g._pause_overlay)

	var bg = ColorRect.new()
	bg.set_anchors_preset(Control.PRESET_FULL_RECT)
	bg.color = Color(0.03, 0.03, 0.06, 0.9)
	g._pause_overlay.add_child(bg)

	var center = CenterContainer.new()
	center.set_anchors_preset(Control.PRESET_FULL_RECT)
	g._pause_overlay.add_child(center)

	var root = VBoxContainer.new()
	root.add_theme_constant_override("separation", 22)
	root.alignment = BoxContainer.ALIGNMENT_CENTER
	center.add_child(root)

	var title = Label.new()
	title.text = GameConfig.t("pause_title")
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	title.add_theme_font_size_override("font_size", 48)
	title.add_theme_color_override("font_color", Color(1.0, 0.85, 0.3))
	root.add_child(title)

	# Две колонки: слева карта + кнопки, справа информация.
	var cols = HBoxContainer.new()
	cols.add_theme_constant_override("separation", 56)
	cols.alignment = BoxContainer.ALIGNMENT_CENTER
	root.add_child(cols)

	# --- Левая колонка: карта и кнопки ---
	var left = VBoxContainer.new()
	left.add_theme_constant_override("separation", 12)
	cols.add_child(left)

	var map_title = Label.new()
	map_title.text = GameConfig.tt("Карта (пройденный путь)", "Map (path traveled)")
	map_title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	map_title.add_theme_font_size_override("font_size", 16)
	map_title.add_theme_color_override("font_color", Color(0.7, 0.7, 0.8))
	left.add_child(map_title)

	g._minimap = TextureRect.new()
	g._minimap.custom_minimum_size = Vector2(320, 200)
	g._minimap.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	g._minimap.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	g._minimap.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	left.add_child(g._minimap)

	# небольшой отступ между картой и кнопками
	var spacer = Control.new()
	spacer.custom_minimum_size = Vector2(0, 8)
	left.add_child(spacer)

	# «Продолжить» отдельной кнопкой не дублируем — тот же жест уже делает
	# «← Назад» в углу (единый способ вернуться в игру, как и везде в меню).
	if GameConfig.tutorial_mode:
		pass   # обучение: без магазина/навыков — не отвлекать от шагов
	elif GameConfig.active_run >= 0:
		# В «Накале» прокачка — на алтаре за Накал; рестарт уровня запрещён.
		left.add_child(g._make_overlay_button(GameConfig.t("pause_loadout"), g._open_loadout_menu))
		left.add_child(g._make_overlay_button(GameConfig.t("pause_altar"), g._open_altar_shop))
	else:
		left.add_child(g._make_overlay_button(GameConfig.t("pause_loadout"), g._open_loadout_menu))
		left.add_child(g._make_overlay_button(GameConfig.t("pause_skills"), g._open_skills_menu))
		left.add_child(g._make_overlay_button(GameConfig.t("pause_restart"), g._restart))
	if not GameConfig.tutorial_mode:
		# «Эхо времени» (§7) — переключается и прямо из игры, не только в
		# настройках: тумблер тут же обновляет свой текст и сохраняет выбор.
		g._echo_toggle_btn = g._make_overlay_button(g._echo_toggle_text(), g._toggle_echo_time)
		left.add_child(g._echo_toggle_btn)
	left.add_child(g._make_overlay_button(GameConfig.t("pause_menu"), g._goto_menu))

	# --- Правая колонка: информация ---
	var right = VBoxContainer.new()
	right.alignment = BoxContainer.ALIGNMENT_CENTER
	cols.add_child(right)

	g._pause_info = Label.new()
	g._pause_info.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	g._pause_info.add_theme_font_size_override("font_size", 18)
	right.add_child(g._pause_info)

	# Постоянная «← Назад» сверху-слева (поверх всего; возобновляет игру, как Esc).
	var back_btn = g._make_overlay_button(GameConfig.t("back_arrow"), g._toggle_pause)
	back_btn.custom_minimum_size = Vector2(130, 44)
	back_btn.focus_mode = Control.FOCUS_NONE
	back_btn.set_anchors_preset(Control.PRESET_TOP_LEFT)
	back_btn.offset_left = 20
	back_btn.offset_top = 20
	g._pause_overlay.add_child(back_btn)

static func _build_touch_controls(g) -> void:
	var layer = CanvasLayer.new()
	layer.layer = 2
	g.add_child(layer)

	# Виртуальный джойстик (реагирует на левую половину экрана)
	g._joystick = Control.new()
	g._joystick.set_script(load("res://touch_joystick.gd"))
	g._joystick.process_mode = Node.PROCESS_MODE_PAUSABLE
	g._joystick.allow_mouse = not OS.has_feature("mobile")
	layer.add_child(g._joystick)
	if g._skill_bar:
		g._skill_bar.visible = false   # иконки навыков теперь под пальцем, нижний ряд дублировал бы их

	var vh: float = g.get_viewport().get_visible_rect().size.y

	# Кнопки навыков (справа снизу) — из НАБОРА: до 4 навыков + Апекс. Пересобираются
	# при смене набора (_sync_touch_skills). Большому пальцу правой руки хватает
	# четырёх; пятая — контекстная (Апекс).
	g._touch_layer = layer
	g._sync_touch_skills()

	# Кнопка паузы (внизу слева, в общем неоновом стиле)
	var pause_btn = UIStyle.make_button("II", g._toggle_pause, 70, 50, 20)
	pause_btn.focus_mode = Control.FOCUS_NONE
	pause_btn.position = Vector2(16, vh - 66)
	pause_btn.process_mode = Node.PROCESS_MODE_PAUSABLE
	layer.add_child(pause_btn)

	# Стойка света (на клавиатуре Z/X и колесо мыши): тусклее / ярче.
	var stance_row = HBoxContainer.new()
	stance_row.add_theme_constant_override("separation", 8)
	stance_row.position = Vector2(100, vh - 66)
	stance_row.process_mode = Node.PROCESS_MODE_PAUSABLE
	layer.add_child(stance_row)
	for d in [[-1, "−"], [1, "+"]]:
		var delta_i: int = d[0]
		var sb = UIStyle.make_button(str(d[1]), func() -> void:
			if g._player and is_instance_valid(g._player):
				g._player.set_light_stance(g._player.light_stance + delta_i), 56, 50, 24)
		sb.focus_mode = Control.FOCUS_NONE
		stance_row.add_child(sb)

static func _sync_touch_skills(g) -> void:
	if g._touch_layer == null or not is_instance_valid(g._touch_layer):
		return
	var ids = g._touch_skill_ids()
	var sig = ",".join(PackedStringArray(ids))
	if sig == g._touch_sig:
		return
	g._touch_sig = sig
	g._touch_icons = {}
	if g._touch_box and is_instance_valid(g._touch_box):
		g._touch_box.queue_free()
	var vw: float = g.get_viewport().get_visible_rect().size.x
	var vh: float = g.get_viewport().get_visible_rect().size.y
	g._touch_box = Control.new()
	g._touch_box.process_mode = Node.PROCESS_MODE_PAUSABLE
	g._touch_box.mouse_filter = Control.MOUSE_FILTER_IGNORE
	g._touch_layer.add_child(g._touch_box)
	# Дуга под большой палец: навыки набора — по четверти круга вокруг точки
	# покоя пальца (P), Апекс — крупнее, в самой точке покоя.
	var p_rest = Vector2(vw - 110.0, vh - 110.0)
	var n = ids.size()
	var n_skill: int = n - (1 if str(ids.back() if n > 0 else "") == "apex" else 0)
	var k = 0
	for i in n:
		var id: String = str(ids[i])
		var big: bool = id == "apex"
		var center = p_rest
		if not big:
			var ang: float = deg_to_rad(180.0 + 90.0 * float(k) / maxf(1.0, float(n_skill - 1)))
			center = p_rest + Vector2(cos(ang), sin(ang)) * 175.0
			k += 1
		var icon = SkillHudIcon.new()
		icon.icon_tex = SkillIcons.make(id, 64)
		icon.accent = SkillIcons.color_of(id)
		icon.show_key = false
		icon.pressable = true
		var sc = 1.9 if big else 1.6
		icon.scale = Vector2(sc, sc)
		icon.position = center - Vector2(SkillHudIcon.W * 0.5, 25.0) * sc
		icon.tapped.connect(func() -> void: g._press_skill(id))
		g._touch_box.add_child(icon)
		g._touch_icons[id] = icon
