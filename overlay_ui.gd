extends RefCounted

# Вынесено из main.gd механически (tools/extract_fn.py, v6.8): код функций
# тот же, что был в main.gd; `g` — главный узел, все его члены с префиксом `g.`.
# Состояние остаётся в main.gd (переменные `_hud_layer`, `_vitals`, …).

static func _show_stats_screen(g) -> void:
	var vp_size: Vector2 = g.get_viewport().get_visible_rect().size

	var overlay = CanvasLayer.new()
	overlay.layer = 4
	g.add_child(overlay)

	# Прячем HUD (вместе с большим баннером победы) — на экране результатов он лишь
	# засоряет картинку и мешает фону читаться затемнённым. Сцена перезагрузится в
	# _restart(), так что восстанавливать видимость не нужно.
	if g._hud_layer:
		g._hud_layer.visible = false

	# Затемняющая вуаль: проявляется плавно и НЕ до конца — лабиринт виден сквозь неё.
	var bg = ColorRect.new()
	bg.color = Color(0.01, 0.01, 0.04, 0.0)
	bg.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	overlay.add_child(bg)
	var bg_alpha = 0.70   # целевая непрозрачность вуали

	# Тепловая карта (этаж 0)
	var cell_px: int = clamp(int((vp_size.x * 0.45) / float(maxi(g._cols, 1))), 4, 20)
	var map_w: int = g._cols * cell_px
	var map_h: int = g._rows * cell_px
	var img = Image.create_empty(map_w, map_h, false, Image.FORMAT_RGBA8)
	img.fill(Color(0.04, 0.04, 0.08, 1.0))

	var max_heat: float = 0.1
	for v in g._heat_map.values():
		max_heat = maxf(max_heat, float(v))

	# Оптимальный путь (подсвечиваем зелёным)
	var opt_cells: Dictionary = {}
	var s0 = Vector3i(0, g._entry_cell.x, g._entry_cell.y)
	var g0 = Vector3i(g._exit_floor, g._exit_cell.x, g._exit_cell.y)
	var prev_opt: Dictionary = {}
	var vis_opt: Dictionary = {s0: true}
	var q_opt: Array[Vector3i] = [s0]
	var found_opt = false
	while not q_opt.is_empty() and not found_opt:
		var cur: Vector3i = q_opt.pop_front()
		if cur == g0:
			found_opt = true
			var c2 = cur
			while c2 != s0:
				if c2.x == 0:
					opt_cells[Vector2i(c2.y, c2.z)] = true
				c2 = prev_opt.get(c2, s0)
			break
		for nb in g._cell_neighbors(cur):
			if not vis_opt.has(nb):
				vis_opt[nb] = true
				prev_opt[nb] = cur
				q_opt.append(nb)

	for cy in g._rows:
		for cx in g._cols:
			var k = Vector3i(0, cx, cy)
			var heat: float = float(g._heat_map.get(k, 0.0)) / max_heat
			var col: Color
			if opt_cells.has(Vector2i(cx, cy)):
				col = Color(0.1, 0.8, 0.3, 1.0).lerp(Color(0.6, 1.0, 0.5, 1.0), heat)
			elif heat > 0.0:
				if heat < 0.4:
					col = Color(0.1, 0.4, 1.0, 1.0).lerp(Color(0.1, 0.9, 0.9, 1.0), heat / 0.4)
				elif heat < 0.75:
					col = Color(0.1, 0.9, 0.9, 1.0).lerp(Color(1.0, 0.9, 0.2, 1.0), (heat - 0.4) / 0.35)
				else:
					col = Color(1.0, 0.9, 0.2, 1.0).lerp(Color(1.0, 1.0, 1.0, 1.0), (heat - 0.75) / 0.25)
			else:
				col = Color(0.07, 0.07, 0.12, 1.0)
			for dy in cell_px:
				for dx in cell_px:
					img.set_pixel(cx * cell_px + dx, cy * cell_px + dy, col)

	# Старт и выход (старт — не всегда угол (0,0): см. _entry_cell/мега-лабиринт)
	for dy in cell_px:
		for dx in cell_px:
			if g._entry_cell.x < g._cols and g._entry_cell.y < g._rows:
				img.set_pixel(g._entry_cell.x * cell_px + dx, g._entry_cell.y * cell_px + dy, Color(0.3, 1.0, 0.6, 1.0))
			if g._exit_cell.x < g._cols and g._exit_cell.y < g._rows:
				img.set_pixel(g._exit_cell.x * cell_px + dx, g._exit_cell.y * cell_px + dy, Color(1.0, 0.5, 0.1, 1.0))

	# --- Композиция по центру: заголовок · карта · легенда · статистика · подсказка ---
	var center = CenterContainer.new()
	center.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	overlay.add_child(center)

	var col = VBoxContainer.new()
	col.alignment = BoxContainer.ALIGNMENT_CENTER
	col.add_theme_constant_override("separation", 16)
	center.add_child(col)

	# Заголовок — расшифровка ранга (раньше жила только в мелькавшей 1 секунду
	# жёлтой надписи и терялась насовсем; теперь часть постоянного экрана).
	var title = Label.new()
	title.add_theme_font_size_override("font_size", 26)
	title.add_theme_color_override("font_color", Color(1.0, 0.85, 0.3))
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	title.text = g._last_rank_line if g._last_rank_line != "" else (GameConfig.tt("Глубина %d пройдена", "Depth %d cleared") % g._level if GameConfig.active_run >= 0 else GameConfig.tt("Уровень %d пройден", "Level %d cleared") % g._level)
	g._label_outline(title, 5)
	col.add_child(title)

	if g._last_rank_detail != "":
		var detail_lbl = Label.new()
		detail_lbl.add_theme_font_size_override("font_size", 14)
		detail_lbl.add_theme_color_override("font_color", Color(0.75, 0.8, 0.9))
		detail_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		detail_lbl.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		detail_lbl.custom_minimum_size = Vector2(560, 0)
		detail_lbl.text = g._last_rank_detail
		g._label_outline(detail_lbl, 3)
		col.add_child(detail_lbl)

	# Карта (по центру, без растяжения — чтобы не искажать пиксели)
	var map_tex = TextureRect.new()
	map_tex.texture = ImageTexture.create_from_image(img)
	map_tex.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	map_tex.custom_minimum_size = Vector2(map_w, map_h)
	map_tex.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	col.add_child(map_tex)

	# Легенда — раньше все квадраты были одного серого цвета текста и не
	# показывали, какому реально цвету на карте что соответствует (жалоба
	# «из скрина непонятно, что такое старт/выход/оптимальный путь»). Теперь
	# каждый пункт — квашратик РЕАЛЬНОГО цвета из отрисовки карты выше, плюс
	# настоящий цветовой градиент вместо текста-стрелки для «тепла».
	var legend_row = HBoxContainer.new()
	legend_row.alignment = BoxContainer.ALIGNMENT_CENTER
	legend_row.add_theme_constant_override("separation", 16)
	col.add_child(legend_row)
	g._legend_swatch(legend_row, Color(0.3, 1.0, 0.6, 1.0), GameConfig.tt("старт", "start"))
	g._legend_swatch(legend_row, Color(1.0, 0.5, 0.1, 1.0), GameConfig.tt("выход", "exit"))
	g._legend_swatch(legend_row, Color(0.3, 0.9, 0.4, 1.0), GameConfig.tt("твой оптимальный путь", "your optimal path"))
	g._legend_heat_swatch(legend_row)

	# Сравнение с симулированными игроками
	var optimal_t: float = float(g._optimal_path_len) * g.TILE / maxf(GameConfig.player_speed, 1.0) if g._optimal_path_len > 0 else g._elapsed
	var median_t:  float = optimal_t * 1.7 + float(g._level) * 2.0
	var ratio: float = median_t / maxf(g._elapsed, 0.01)
	var pct: int = clamp(int(50.0 + 40.0 * (ratio - 1.0) / (ratio + 0.5)), 1, 99)

	var stats_lbl = Label.new()
	stats_lbl.add_theme_font_size_override("font_size", 19)
	stats_lbl.add_theme_color_override("font_color", Color(0.9, 0.9, 1.0))
	stats_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	stats_lbl.text = (
		GameConfig.tt("Время: %.1f с   ·   оптимум: %.1f с\nТы быстрее %d%% игроков",
			"Time: %.1f s   ·   optimum: %.1f s\nYou're faster than %d%% of players") %
		[g._elapsed, optimal_t, pct]
	)
	g._label_outline(stats_lbl, 4)
	col.add_child(stats_lbl)

	# Отступ перед подсказкой
	var spacer = Control.new()
	spacer.custom_minimum_size = Vector2(0, 10)
	col.add_child(spacer)

	# ── Кнопки выбора: дальше / заново / меню / навыки. Никаких «любых клавиш»
	# и хоткеев рестарта — осознанный выбор мышью/кликом.
	g._stats_choice = "next"
	var btn_row = HBoxContainer.new()
	btn_row.alignment = BoxContainer.ALIGNMENT_CENTER
	btn_row.add_theme_constant_override("separation", 12)
	col.add_child(btn_row)

	var mk = func(txt: String, choice: String) -> Button:
		return UIStyle.make_button(txt, func() -> void:
			g._stats_choice = choice
			if is_instance_valid(overlay):
				overlay.queue_free(), 190, 46, 18)
	btn_row.add_child(mk.call(GameConfig.tt("Дальше ▶", "Next ▶"), "next"))
	if GameConfig.active_run < 0:
		btn_row.add_child(mk.call(GameConfig.tt("↻ Заново", "↻ Replay"), "replay"))
	# «Магазин навыков» — открывает полноценное меню навыков поверх результатов
	# (тот же skills_menu, что в паузе). Только в «Уровнях»: в Накале прокачка
	# на алтаре, из экрана результатов туда не попасть по правилам забега.
	if GameConfig.active_run < 0:
		var sk_btn = UIStyle.make_button(GameConfig.tt("Магазин навыков", "Skill shop"), func() -> void:
			var sm = CanvasLayer.new()
			sm.set_script(load("res://skills_menu.gd"))
			sm.layer = 6   # поверх оверлея результатов (layer 4)
			g.add_child(sm), 210, 46, 18)
		btn_row.add_child(sk_btn)
		var lo_btn = UIStyle.make_button(GameConfig.tt("Набор навыков", "Loadout"), func() -> void:
			var lm = CanvasLayer.new()
			lm.set_script(load("res://loadout_menu.gd"))
			lm.layer = 6
			g.add_child(lm), 210, 46, 18)
		btn_row.add_child(lo_btn)
	btn_row.add_child(mk.call(GameConfig.tt("В меню", "To menu"), "menu"))

	# Проявление вуали; ждём выбор кнопкой (без таймаута и «любой клавиши»).
	while is_instance_valid(overlay):
		var dt = g.get_process_delta_time()
		bg.color.a = minf(bg_alpha, bg.color.a + dt * (bg_alpha / 0.35))
		await g.get_tree().process_frame

static func _open_altar_shop(g) -> void:
	if GameConfig.active_run < 0:
		return
	if is_instance_valid(g._pause_overlay):
		g._pause_overlay.visible = false
	g._altar_layer = CanvasLayer.new()
	g._altar_layer.layer = 4
	g._altar_layer.process_mode = Node.PROCESS_MODE_ALWAYS
	g.add_child(g._altar_layer)

	var dim = ColorRect.new()
	dim.set_anchors_preset(Control.PRESET_FULL_RECT)
	dim.color = Color(0.02, 0.03, 0.05, 0.9)
	g._altar_layer.add_child(dim)

	var center = CenterContainer.new()
	center.set_anchors_preset(Control.PRESET_FULL_RECT)
	g._altar_layer.add_child(center)

	var box = VBoxContainer.new()
	box.add_theme_constant_override("separation", 8)
	center.add_child(box)

	var title = Label.new()
	title.text = GameConfig.tt("АЛТАРЬ", "ALTAR")
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	title.add_theme_font_size_override("font_size", 28)
	title.add_theme_color_override("font_color", Color(1.0, 0.78, 0.4))
	box.add_child(title)

	var hint = Label.new()
	hint.text = GameConfig.tt("Трать Накал на улучшения. Эффект — со следующего этажа.", "Spend Ember on upgrades. The effect kicks in from the next floor.")
	hint.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	hint.add_theme_font_size_override("font_size", 14)
	hint.add_theme_color_override("font_color", Color(0.7, 0.66, 0.56))
	box.add_child(hint)

	g._altar_bank_lbl = Label.new()
	g._altar_bank_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	g._altar_bank_lbl.add_theme_font_size_override("font_size", 20)
	g._altar_bank_lbl.add_theme_color_override("font_color", Color(0.95, 0.88, 0.6))
	box.add_child(g._altar_bank_lbl)

	# Карточки товаров: сетка 5 колонок (иконка + имя + мастерство + цена).
	g._altar_rows = GridContainer.new()
	g._altar_rows.columns = 5
	g._altar_rows.add_theme_constant_override("h_separation", 10)
	g._altar_rows.add_theme_constant_override("v_separation", 10)
	# [LAYOUT-FIX v5.5] GridContainer не умеет центрировать себя (свойства
	# alignment у него нет, в отличие от H/VBoxContainer). Над ним в этой же
	# колонке стоят заголовок и подсказка с HORIZONTAL_ALIGNMENT_CENTER: они
	# центрируют ТЕКСТ внутри своего растянутого прямоугольника, а сетка без
	# этого флага прижимается к левому краю панели. Симптом ровно тот же, что
	# уже ловили на сетках выбора уровня и Логова: «подписи по центру, а
	# кнопки уехали влево». Единственный GridContainer в игре, где флага не
	# было, — остальные его получили ещё в правке 06.07.2026.
	g._altar_rows.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	box.add_child(g._altar_rows)

	box.add_child(UIStyle.make_button(GameConfig.t("close_esc").split("  ")[0], g._close_altar_shop, 200, 44, 20))

	g._altar_refresh()

static func _altar_card(g, offer: Dictionary) -> Control:
	var id: String = offer["id"]
	var cost: int = int(offer["cost"])
	var can: bool = bool(offer.get("can", true))
	var afford: bool = g._ember_banked >= cost and can

	var panel = PanelContainer.new()
	var sb = StyleBoxFlat.new()
	sb.bg_color = Color(0.05, 0.06, 0.10, 0.95)
	sb.set_corner_radius_all(10)
	sb.set_border_width_all(2)
	if not can:
		sb.border_color = Color(0.35, 0.9, 0.5, 0.8)
	elif afford:
		sb.border_color = Color(1.0, 0.75, 0.3, 0.8)
	else:
		sb.border_color = Color(0.3, 0.34, 0.42, 0.6)
	sb.content_margin_left = 10
	sb.content_margin_right = 10
	sb.content_margin_top = 8
	sb.content_margin_bottom = 8
	panel.add_theme_stylebox_override("panel", sb)
	panel.custom_minimum_size = Vector2(148, 150)

	var v = VBoxContainer.new()
	v.add_theme_constant_override("separation", 4)
	v.alignment = BoxContainer.ALIGNMENT_CENTER
	panel.add_child(v)

	var icon = TextureRect.new()
	icon.texture = SkillIcons.make(str(offer.get("icon", id)), 40)
	icon.stretch_mode = TextureRect.STRETCH_KEEP_CENTERED
	icon.custom_minimum_size = Vector2(44, 44)
	if not afford and can:
		icon.modulate = Color(0.55, 0.55, 0.6)
	v.add_child(icon)

	var nm = Label.new()
	nm.text = str(offer["name_en"]) if GameConfig.locale == "en" else str(offer["name"])
	nm.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	nm.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	nm.add_theme_font_size_override("font_size", 14)
	nm.add_theme_color_override("font_color", Color(0.88, 0.92, 1.0))
	v.add_child(nm)

	# Для навыков — текущее мастерство забега (база + временные звёзды).
	if str(offer.get("kind", "")) == "star":
		var m = GameConfig.mastery(id)
		var ml = Label.new()
		ml.text = "★".repeat(m) + "☆".repeat(GameConfig.MASTERY_MAX - m)
		ml.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		ml.tooltip_text = GameConfig.tt("Мастерство: +15% силы за звезду.\nЗвёзды алтаря действуют до конца этого забега.", "Mastery: +15% power per star.\nAltar stars last until the end of this run.")
		ml.add_theme_font_size_override("font_size", 14)
		ml.add_theme_color_override("font_color", Color(1.0, 0.85, 0.3) if m > 0 else Color(0.45, 0.5, 0.6))
		v.add_child(ml)

	if not can:
		var ol = Label.new()
		ol.text = GameConfig.tt("✓ предел", "✓ maxed")
		ol.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		ol.add_theme_font_size_override("font_size", 14)
		ol.add_theme_color_override("font_color", Color(0.4, 0.95, 0.55))
		v.add_child(ol)
	else:
		var buy = UIStyle.make_button("%d ⌀" % cost, g._on_altar_buy.bind(id), 90, 32, 16)
		buy.disabled = not afford
		buy.add_theme_color_override("font_color", Color(1.0, 0.85, 0.4) if afford else Color(0.5, 0.52, 0.58))
		v.add_child(buy)
	return panel
