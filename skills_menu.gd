extends CanvasLayer

# Меню навыков: открывается из паузы поверх игры.
# Игра уже поставлена на паузу — этот слой только рисует интерфейс.

signal closed

# ── Данные навыков ──────────────────────────────────────────────────────────

const SKILL_INFO := {
	"flash":    {passive=false, name="Вспышка",          key="Q",     desc="Резкий всплеск света на 0.5 с.\nОсмотреться в темноте."},
	"dash":     {passive=false, name="Рывок",             key="Shift", desc="Мгновенный бросок в направлении\nдвижения. Уйти от врага."},
	"smother":  {passive=false, name="Тление",            key="R",     desc="Пригаситься на пару секунд:\nмедленно и слепо, зато враги\nтеряют тебя из виду."},
	"sonar":    {passive=false, name="Сонар",             key="E",     desc="Кольцо света раскрывает планировку\nлабиринта на 5 секунд."},
	"shield":   {passive=false, name="Щит",               key="C",     desc="Полностью останавливает разрядку\nна 4 секунды."},
	"guide":    {passive=false, name="Искра",             key="G",     desc="Путеводный огонёк ведёт\nк выходу с текущего этажа."},
	"reveal":   {passive=false, name="Озарение",          key="F",     desc="Освещает весь этаж на 4 с.\nЗаряжается на станциях."},
	"save":     {passive=true,  name="Энергосбережение",  key="",      desc="Расход света −30%."},
	"capacity": {passive=true,  name="Ёмкость",           key="",      desc="Максимальный запас света +30%."},
	"charge":   {passive=true,  name="Быстрая зарядка",   key="",      desc="Скорость зарядки на станциях +50%."},
	"range":    {passive=true,  name="Дальний свет",      key="",      desc="Радиус свечения +25%."},
	"legs":     {passive=true,  name="Лёгкие ноги",       key="",      desc="Скорость передвижения +15%."},
	"magic":    {passive=true,  name="Магия",             key="",      desc="Навыки дешевле на 30%\nи перезаряжаются быстрее."},
	"apex":     {passive=false, name="АПЕКС",             key="H",     desc="Супернавык. Открывается, когда\nкуплены все 6 активных навыков.\nФорма зависит от того, какой навык\nты прокачал сильнее всего."},
}

# Цвета иконок
const ICON_COLORS := {
	"flash":    Color(1.00, 0.88, 0.15),
	"dash":     Color(0.30, 0.65, 1.00),
	"smother":  Color(0.60, 0.50, 0.85),
	"sonar":    Color(0.30, 0.92, 1.00),
	"shield":   Color(0.45, 0.72, 1.00),
	"guide":    Color(1.00, 0.58, 0.18),
	"reveal":   Color(0.95, 0.95, 1.00),
	"save":     Color(0.25, 0.92, 0.42),
	"capacity": Color(0.72, 0.38, 1.00),
	"charge":   Color(1.00, 0.90, 0.18),
	"range":    Color(1.00, 0.48, 0.28),
	"legs":     Color(0.25, 0.90, 0.72),
	"magic":    Color(1.00, 0.38, 0.82),
	"apex":     Color(1.00, 0.20, 0.30),
}

var _skill_buttons: Dictionary = {}   # skill_id -> Button
var _xp_bar: ProgressBar
var _xp_label: Label
var _sp_label: Label

# ── Инициализация ────────────────────────────────────────────────────────────

func _ready() -> void:
	layer = 10
	process_mode = Node.PROCESS_MODE_ALWAYS
	_build()

func _input(event: InputEvent) -> void:
	if event is InputEventKey and event.pressed and event.keycode == KEY_ESCAPE:
		get_viewport().set_input_as_handled()
		_on_close()

# ── Построение UI ────────────────────────────────────────────────────────────

func _build() -> void:
	var bg := ColorRect.new()
	bg.set_anchors_preset(Control.PRESET_FULL_RECT)
	bg.color = Color(0.02, 0.02, 0.06, 0.97)
	bg.process_mode = Node.PROCESS_MODE_ALWAYS
	add_child(bg)

	var margin := MarginContainer.new()
	margin.set_anchors_preset(Control.PRESET_FULL_RECT)
	margin.add_theme_constant_override("margin_left",   50)
	margin.add_theme_constant_override("margin_right",  50)
	margin.add_theme_constant_override("margin_top",    18)
	margin.add_theme_constant_override("margin_bottom", 18)
	margin.process_mode = Node.PROCESS_MODE_ALWAYS
	add_child(margin)

	var vbox := VBoxContainer.new()
	vbox.add_theme_constant_override("separation", 10)
	margin.add_child(vbox)

	# ── Заголовок ──
	var title := Label.new()
	title.text = "НАВЫКИ"
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	title.add_theme_font_size_override("font_size", 32)
	title.add_theme_color_override("font_color", Color(1.0, 0.85, 0.3))
	vbox.add_child(title)

	# ── Строка XP / SP ──
	var xp_row := HBoxContainer.new()
	xp_row.alignment = BoxContainer.ALIGNMENT_CENTER
	xp_row.add_theme_constant_override("separation", 28)
	xp_row.process_mode = Node.PROCESS_MODE_ALWAYS
	vbox.add_child(xp_row)

	_sp_label = Label.new()
	_sp_label.add_theme_font_size_override("font_size", 20)
	_sp_label.add_theme_color_override("font_color", Color(1.0, 0.82, 0.3))
	xp_row.add_child(_sp_label)

	var xp_col := VBoxContainer.new()
	xp_col.add_theme_constant_override("separation", 2)
	xp_row.add_child(xp_col)

	var xp_title := Label.new()
	xp_title.text = "Опыт (до следующего SP):"
	xp_title.add_theme_font_size_override("font_size", 13)
	xp_title.add_theme_color_override("font_color", Color(0.55, 0.55, 0.65))
	xp_col.add_child(xp_title)

	var bar_row := HBoxContainer.new()
	bar_row.add_theme_constant_override("separation", 8)
	xp_col.add_child(bar_row)

	_xp_bar = ProgressBar.new()
	_xp_bar.min_value = 0
	_xp_bar.max_value = GameConfig.XP_PER_SP
	_xp_bar.show_percentage = false
	_xp_bar.custom_minimum_size = Vector2(260, 20)
	var bb := StyleBoxFlat.new(); bb.bg_color = Color(0.08, 0.08, 0.15); bb.set_corner_radius_all(4)
	_xp_bar.add_theme_stylebox_override("background", bb)
	var bf := StyleBoxFlat.new(); bf.bg_color = Color(0.55, 0.42, 1.0); bf.set_corner_radius_all(4)
	_xp_bar.add_theme_stylebox_override("fill", bf)
	bar_row.add_child(_xp_bar)

	_xp_label = Label.new()
	_xp_label.add_theme_font_size_override("font_size", 14)
	_xp_label.add_theme_color_override("font_color", Color(0.65, 0.6, 0.9))
	bar_row.add_child(_xp_label)

	# ── Всё содержимое — в одном ScrollContainer (страница скроллится целиком) ──
	var scroll := ScrollContainer.new()
	scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	scroll.process_mode = Node.PROCESS_MODE_ALWAYS
	vbox.add_child(scroll)
	var content := VBoxContainer.new()
	content.add_theme_constant_override("separation", 10)
	content.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	scroll.add_child(content)

	# ── Колесо Апекса + панель описания выбранного навыка (клик по иконке) ──
	var wheel_row := HBoxContainer.new()
	wheel_row.alignment = BoxContainer.ALIGNMENT_CENTER
	wheel_row.add_theme_constant_override("separation", 24)
	content.add_child(wheel_row)
	var wheel := ApexWheel.new()
	wheel.custom_minimum_size = Vector2(520, 310)
	wheel_row.add_child(wheel)

	var desc_box := VBoxContainer.new()
	desc_box.custom_minimum_size = Vector2(300, 0)
	desc_box.alignment = BoxContainer.ALIGNMENT_CENTER
	desc_box.add_theme_constant_override("separation", 6)
	wheel_row.add_child(desc_box)
	var d_name := Label.new()
	d_name.add_theme_font_size_override("font_size", 22)
	d_name.text = "Кликни навык в колесе"
	d_name.add_theme_color_override("font_color", Color(0.85, 0.9, 1.0))
	desc_box.add_child(d_name)
	var d_desc := Label.new()
	d_desc.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	d_desc.custom_minimum_size = Vector2(300, 0)
	d_desc.add_theme_font_size_override("font_size", 15)
	d_desc.add_theme_color_override("font_color", Color(0.72, 0.78, 0.9))
	d_desc.text = "— увидишь описание, мастерство и связь с Апексом."
	desc_box.add_child(d_desc)
	var d_meta := Label.new()
	d_meta.add_theme_font_size_override("font_size", 14)
	d_meta.add_theme_color_override("font_color", Color(1.0, 0.85, 0.3))
	desc_box.add_child(d_meta)
	var d_how := Label.new()
	d_how.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	d_how.custom_minimum_size = Vector2(300, 0)
	d_how.add_theme_font_size_override("font_size", 13)
	d_how.add_theme_color_override("font_color", Color(0.55, 0.85, 0.65))
	desc_box.add_child(d_how)
	wheel.on_select = func(id: String) -> void:
		var info: Dictionary = SKILL_INFO.get(id, {})
		var col: Color = ICON_COLORS.get(id, Color.WHITE)
		d_name.text = "%s  [%s]" % [str(info.get("name", id)), str(info.get("key", ""))]
		d_name.add_theme_color_override("font_color", col)
		var extra := ""
		if id in ["mirage", "breach", "chrono"]:
			extra = "
Дар Ядра: добывается победой над боссом (дверь ☠)."
		d_desc.text = str(info.get("desc", "")).replace("
", " ") + extra
		var m := GameConfig.mastery(id)
		var owned: bool = GameConfig.skills_unlocked.get(id, false)
		var top := GameConfig.top_mastered(1)
		var form_tag := "   ·   ТЕКУЩАЯ ФОРМА АПЕКСА" if (top.size() > 0 and top[0] == id) else ""
		d_meta.text = ("Мастерство: %s%s%s" % ["★".repeat(m), "☆".repeat(5 - m), form_tag]) if owned else "Ещё не открыт"
		# Как получить / как усилить
		var cost := int(GameConfig.SKILL_COSTS.get(id, 0))
		if not owned:
			if id in ["mirage", "breach", "chrono"]:
				d_how.text = "Получение: победи Тёмное Ядро за багровой дверью ☠ (уровни, кратные 5)."
			elif id == "apex":
				d_how.text = "Получение: открой все 6 базовых активных навыков — Апекс проявится сам."
			else:
				var ms: Dictionary = GameConfig.SKILL_MILESTONES.get(id, {})
				var alt := (" — или само: %s" % str(ms.get("text", ""))) if not ms.is_empty() else ""
				d_how.text = "Получение: купи за %d SP в списке ниже%s." % [cost, alt]
		elif id != "apex" and GameConfig.skill_uses.has(id):
			if m < GameConfig.MASTERY_MAX:
				d_how.text = "Усиление: применяй навык (10 применений = ★) — или купи усиление за %d SP ниже." % maxi(cost, 2)
			else:
				d_how.text = "Мастерство на пределе — это вершина навыка."
		else:
			d_how.text = ""

	# ── Две колонки магазина ──
	var cols_row := HBoxContainer.new()
	cols_row.add_theme_constant_override("separation", 32)
	cols_row.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	content.add_child(cols_row)

	cols_row.add_child(_make_column("АКТИВНЫЕ  (Q / Shift / R / E / C / G / F)",
		Color(0.65, 0.85, 1.0), ["flash","dash","smother","sonar","shield","guide","reveal"]))
	cols_row.add_child(_make_passives_column())

	# ── Кнопка закрыть ──
	var close_row := HBoxContainer.new()
	close_row.alignment = BoxContainer.ALIGNMENT_CENTER
	close_row.process_mode = Node.PROCESS_MODE_ALWAYS
	vbox.add_child(close_row)

	var close_btn := Button.new()
	close_btn.text = "Закрыть  (Esc)"
	close_btn.custom_minimum_size = Vector2(220, 44)
	close_btn.add_theme_font_size_override("font_size", 20)
	close_btn.process_mode = Node.PROCESS_MODE_ALWAYS
	close_btn.pressed.connect(_on_close)
	close_row.add_child(close_btn)

	# Постоянная «← Назад» сверху-слева — для единообразия с остальными экранами.
	var back_btn := Button.new()
	back_btn.text = "← Назад"
	back_btn.focus_mode = Control.FOCUS_NONE
	back_btn.process_mode = Node.PROCESS_MODE_ALWAYS
	back_btn.custom_minimum_size = Vector2(130, 44)
	back_btn.add_theme_font_size_override("font_size", 18)
	back_btn.set_anchors_preset(Control.PRESET_TOP_LEFT)
	back_btn.offset_left = 20
	back_btn.offset_top = 14
	back_btn.pressed.connect(_on_close)
	add_child(back_btn)

	_refresh()

const APEX_FORM_NAMES := {
	"flash":  "Сверхвспышка",
	"dash":   "Цепной рывок",
	"sonar":  "Карта мира",
	"shield": "Бессмертие",
	"guide":  "Телепорт к выходу",
	"reveal": "Вечное озарение",
}

const APEX_FORM_DESCS := {
	"flash":  "огромная вспышка + ускорение 3 с",
	"dash":   "три рывка подряд в направлении движения",
	"sonar":  "сонар тройного радиуса, освещает весь этаж",
	"shield": "10 секунд полной неуязвимости + полный заряд",
	"guide":  "мгновенный перенос к выходу",
	"reveal": "озарение на 20 секунд",
}

func _make_apex_card() -> PanelContainer:
	var apex_unlocked: bool = GameConfig.skills_unlocked.get("apex", false)

	var card := PanelContainer.new()
	card.process_mode = Node.PROCESS_MODE_ALWAYS
	var sty := StyleBoxFlat.new()
	if apex_unlocked:
		sty.bg_color = Color(0.18, 0.06, 0.10)
		sty.border_color = Color(1.0, 0.35, 0.45)
	else:
		sty.bg_color = Color(0.08, 0.05, 0.10)
		sty.border_color = Color(0.45, 0.25, 0.35)
	sty.border_width_left = 3; sty.border_width_right = 3
	sty.border_width_top = 3;  sty.border_width_bottom = 3
	sty.set_corner_radius_all(10)
	sty.set_content_margin_all(14)
	card.add_theme_stylebox_override("panel", sty)

	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 18)
	card.add_child(row)

	# Большая иконка Апекса
	var icon := TextureRect.new()
	icon.texture = _make_icon("apex", 72)
	icon.custom_minimum_size = Vector2(72, 72)
	icon.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	if not apex_unlocked:
		icon.modulate = Color(0.55, 0.45, 0.55)
	row.add_child(icon)

	# Текст
	var txt := VBoxContainer.new()
	txt.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	txt.add_theme_constant_override("separation", 2)
	row.add_child(txt)

	var title := HBoxContainer.new()
	title.add_theme_constant_override("separation", 6)
	txt.add_child(title)

	var tname := Label.new()
	tname.text = "★ АПЕКС ★"
	tname.add_theme_font_size_override("font_size", 24)
	tname.add_theme_color_override("font_color", Color(1.0, 0.45, 0.55) if apex_unlocked else Color(0.7, 0.5, 0.55))
	title.add_child(tname)

	var key_lbl := Label.new()
	key_lbl.text = "[H]"
	key_lbl.add_theme_font_size_override("font_size", 14)
	key_lbl.add_theme_color_override("font_color", Color(0.85, 0.7, 0.75))
	title.add_child(key_lbl)

	# Текущая форма на основе мастерства
	var forms_lbl := RichTextLabel.new()
	forms_lbl.bbcode_enabled = true
	forms_lbl.fit_content = true
	forms_lbl.scroll_active = false
	forms_lbl.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	forms_lbl.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	forms_lbl.add_theme_font_size_override("normal_font_size", 13)
	if apex_unlocked:
		var top: Array = GameConfig.top_mastered(2)
		var main_id: String = top[0]
		var echo_id: String = top[1] if top.size() > 1 else ""
		var s := "Текущая форма: [color=#ffb060]%s[/color] — %s." % [
			APEX_FORM_NAMES.get(main_id, "?"),
			APEX_FORM_DESCS.get(main_id, "")]
		if echo_id != "" and echo_id != main_id:
			s += "\nЭхо: %s (слабее)." % APEX_FORM_NAMES.get(echo_id, "?")
		forms_lbl.text = s
		forms_lbl.add_theme_color_override("default_color", Color(0.9, 0.85, 0.7))
	else:
		forms_lbl.text = "Закрыт. Откроется автоматически, когда\nкуплены все 6 активных навыков."
		forms_lbl.add_theme_color_override("default_color", Color(0.55, 0.55, 0.6))
	txt.add_child(forms_lbl)

	# Подсказка про мастерство
	var hint := Label.new()
	hint.text = "Прокачивай разные навыки — Апекс будет принимать форму того,\nкоторый ты использовал чаще всего."
	hint.add_theme_font_size_override("font_size", 11)
	hint.add_theme_color_override("font_color", Color(0.55, 0.55, 0.65))
	txt.add_child(hint)

	return card

# Правая колонка: пассивки (растут САМИ, не покупаются) + дары Ядра.
func _make_passives_column() -> VBoxContainer:
	var col := VBoxContainer.new()
	col.add_theme_constant_override("separation", 8)
	col.size_flags_horizontal = Control.SIZE_EXPAND_FILL

	var hdr := Label.new()
	hdr.text = "ПАССИВНЫЕ  (растут сами от твоих действий)"
	hdr.add_theme_font_size_override("font_size", 18)
	hdr.add_theme_color_override("font_color", Color(0.82, 0.65, 1.0))
	col.add_child(hdr)

	for pid in GameConfig.PASSIVE_DEFS:
		var d: Dictionary = GameConfig.PASSIVE_DEFS[pid]
		var lvl := GameConfig.passive_level(pid)
		var row := HBoxContainer.new()
		row.add_theme_constant_override("separation", 8)
		col.add_child(row)
		var ic := TextureRect.new()
		ic.texture = SkillIcons.make(pid, 26)
		ic.stretch_mode = TextureRect.STRETCH_KEEP_CENTERED
		row.add_child(ic)
		var l := Label.new()
		l.text = "%s  %s%s\n%s — %s" % [str(d["name"]), "★".repeat(lvl), "☆".repeat(5 - lvl), str(d["per"]), str(d["act"])]
		l.add_theme_font_size_override("font_size", 14)
		l.add_theme_color_override("font_color", Color(0.78, 0.82, 0.94))
		row.add_child(l)

	var ghdr := Label.new()
	ghdr.text = "ДАРЫ ЯДРА  (за победу над боссом, дверь ☠)"
	ghdr.add_theme_font_size_override("font_size", 18)
	ghdr.add_theme_color_override("font_color", Color(1.0, 0.5, 0.5))
	col.add_child(ghdr)
	var gift_names := {"mirage": "Мираж (T) — ложная цель для врагов",
		"breach": "Разлом (Y) — пролом стены", "chrono": "Хронос (V) — заморозка этажа"}
	for gid in ["mirage", "breach", "chrono"]:
		var gl := Label.new()
		var owned: bool = GameConfig.skills_unlocked.get(gid, false)
		gl.text = ("✓ " if owned else "☠ ") + gift_names[gid] + ("" if owned else "  ·  ещё не получен")
		gl.add_theme_font_size_override("font_size", 14)
		gl.add_theme_color_override("font_color", Color(0.5, 0.95, 0.6) if owned else Color(0.62, 0.55, 0.6))
		col.add_child(gl)
	return col

# Колесо связей Апекса (рисует нити мастерства; иконки — дети-контролы).
class ApexWheel extends Control:
	const POOL := ["flash", "dash", "sonar", "shield", "guide", "reveal", "mirage", "breach", "chrono"]
	const NAMES := {"flash": "Вспышка", "dash": "Рывок", "sonar": "Сонар", "shield": "Щит",
		"guide": "Искра", "reveal": "Озарение", "mirage": "Мираж", "breach": "Разлом", "chrono": "Хронос"}
	const R := 112.0
	var _t: float = 0.0
	var selected: String = ""
	var on_select: Callable = Callable()

	func _ready() -> void:
		mouse_filter = Control.MOUSE_FILTER_IGNORE
		# Центральный Апекс
		var apex := TextureRect.new()
		apex.texture = SkillIcons.make("apex", 44)
		apex.stretch_mode = TextureRect.STRETCH_KEEP_CENTERED
		apex.position = custom_minimum_size * 0.5 - Vector2(22, 22)
		apex.custom_minimum_size = Vector2(44, 44)
		apex.mouse_filter = Control.MOUSE_FILTER_STOP
		apex.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
		apex.gui_input.connect(func(ev: InputEvent) -> void:
			if ev is InputEventMouseButton and ev.pressed and ev.button_index == MOUSE_BUTTON_LEFT:
				selected = "apex"
				if on_select.is_valid():
					on_select.call("apex"))
		add_child(apex)
		var anml := Label.new()
		anml.text = "АПЕКС"
		anml.add_theme_font_size_override("font_size", 11)
		anml.add_theme_color_override("font_color", SkillIcons.color_of("apex"))
		anml.position = custom_minimum_size * 0.5 + Vector2(-20, 26)
		add_child(anml)
		# Навыки по кругу + звёзды мастерства
		for i in POOL.size():
			var id: String = POOL[i]
			var ang := TAU * float(i) / POOL.size() - PI * 0.5
			var p := custom_minimum_size * 0.5 + Vector2(cos(ang), sin(ang)) * R
			var ic := TextureRect.new()
			ic.texture = SkillIcons.make(id, 28)
			ic.stretch_mode = TextureRect.STRETCH_KEEP_CENTERED
			ic.position = p - Vector2(14, 14)
			ic.custom_minimum_size = Vector2(28, 28)
			ic.mouse_filter = Control.MOUSE_FILTER_STOP
			ic.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
			if not GameConfig.skills_unlocked.get(id, false):
				ic.modulate = Color(0.35, 0.35, 0.42)
			var sid := id
			ic.gui_input.connect(func(ev: InputEvent) -> void:
				if ev is InputEventMouseButton and ev.pressed and ev.button_index == MOUSE_BUTTON_LEFT:
					selected = sid
					if on_select.is_valid():
						on_select.call(sid))
			add_child(ic)
			# Подпись имени навыка (снаружи круга, чтобы не мешала нитям)
			var nml := Label.new()
			nml.text = str(NAMES.get(id, id))
			nml.add_theme_font_size_override("font_size", 11)
			nml.add_theme_color_override("font_color", SkillIcons.color_of(id))
			var out_p := custom_minimum_size * 0.5 + Vector2(cos(ang), sin(ang)) * (R + 34.0)
			nml.position = out_p - Vector2(24, 8)
			add_child(nml)
			var m := GameConfig.mastery(id)
			if m > 0:
				var ml := Label.new()
				ml.text = "★".repeat(m)
				ml.add_theme_font_size_override("font_size", 9)
				ml.add_theme_color_override("font_color", Color(1.0, 0.85, 0.3))
				ml.position = p + Vector2(-14, 15)
				add_child(ml)

	func _process(delta: float) -> void:
		_t += delta
		queue_redraw()

	func _draw() -> void:
		var c := custom_minimum_size * 0.5
		var top := GameConfig.top_mastered(2)
		var apex_open: bool = GameConfig.skills_unlocked.get("apex", false)
		for i in POOL.size():
			var id: String = POOL[i]
			var ang := TAU * float(i) / POOL.size() - PI * 0.5
			var p := c + Vector2(cos(ang), sin(ang)) * (R - 20.0)
			var col: Color = SkillIcons.color_of(id)
			var m := GameConfig.mastery(id)
			var width := 1.0 + float(m) * 1.1
			var alpha := 0.10 + 0.13 * float(m)
			if apex_open and id == top[0]:
				alpha = 0.65 + 0.35 * (0.5 + 0.5 * sin(_t * 4.0))
				width += 2.0
				# бегущая искра по нити — «энергия течёт в Апекс»
				var k := fmod(_t * 0.6, 1.0)
				draw_circle(p.lerp(c + (p - c).normalized() * 26.0, k), 3.5, Color(col.r, col.g, col.b, 0.9))
			elif apex_open and top.size() > 1 and id == top[1]:
				alpha = 0.4 + 0.2 * (0.5 + 0.5 * sin(_t * 4.0 + 1.5))
				width += 1.0
			if not GameConfig.skills_unlocked.get(id, false):
				alpha = 0.05
			draw_line(p, c + (p - c).normalized() * 28.0, Color(col.r, col.g, col.b, alpha), width, true)
		# Кольцо выделения вокруг выбранного навыка (в т.ч. сам Апекс в центре)
		if selected == "apex":
			draw_arc(c, 33.0 + 1.5 * sin(_t * 5.0), 0, TAU, 40, Color(1.0, 0.35, 0.4, 0.9), 2.0, true)
		if selected != "" and selected in POOL:
			var si := POOL.find(selected)
			var sang := TAU * float(si) / POOL.size() - PI * 0.5
			var sp := c + Vector2(cos(sang), sin(sang)) * R
			var scol: Color = SkillIcons.color_of(selected)
			draw_arc(sp, 20.0 + 1.5 * sin(_t * 5.0), 0, TAU, 32, Color(scol.r, scol.g, scol.b, 0.9), 2.0, true)
		# Ореол вокруг Апекса дышит в цвет текущей формы
		if apex_open:
			var fc: Color = SkillIcons.color_of(top[0])
			draw_arc(c, 26.0 + 2.0 * sin(_t * 3.0), 0, TAU, 40, Color(fc.r, fc.g, fc.b, 0.55), 2.0, true)

func _make_column(header: String, hdr_color: Color, skill_ids: Array) -> VBoxContainer:
	var col := VBoxContainer.new()
	col.add_theme_constant_override("separation", 6)
	col.size_flags_horizontal = Control.SIZE_EXPAND_FILL

	var hdr := Label.new()
	hdr.text = header
	hdr.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	hdr.add_theme_font_size_override("font_size", 15)
	hdr.add_theme_color_override("font_color", hdr_color)
	col.add_child(hdr)

	for skill_id in skill_ids:
		col.add_child(_make_card(skill_id))

	return col

func _make_card(skill_id: String) -> PanelContainer:
	var info: Dictionary = SKILL_INFO[skill_id]

	var card := PanelContainer.new()
	card.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	card.process_mode = Node.PROCESS_MODE_ALWAYS
	var sty := StyleBoxFlat.new()
	sty.bg_color = Color(0.07, 0.07, 0.13)
	sty.set_corner_radius_all(6)
	sty.set_content_margin_all(7)
	card.add_theme_stylebox_override("panel", sty)

	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 9)
	card.add_child(row)

	# Иконка 42×42
	var icon_rect := TextureRect.new()
	icon_rect.texture = _make_icon(skill_id, 42)
	icon_rect.custom_minimum_size = Vector2(42, 42)
	icon_rect.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	row.add_child(icon_rect)

	# Текст
	var txt := VBoxContainer.new()
	txt.add_theme_constant_override("separation", 1)
	txt.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	row.add_child(txt)

	var name_row := HBoxContainer.new()
	name_row.add_theme_constant_override("separation", 6)
	txt.add_child(name_row)

	var name_lbl := Label.new()
	name_lbl.text = info["name"]
	name_lbl.add_theme_font_size_override("font_size", 15)
	name_row.add_child(name_lbl)

	if info["key"] != "":
		var key_lbl := Label.new()
		key_lbl.text = "[%s]" % info["key"]
		key_lbl.add_theme_font_size_override("font_size", 12)
		key_lbl.add_theme_color_override("font_color", Color(0.55, 0.55, 0.65))
		name_row.add_child(key_lbl)

	var cost: int = GameConfig.SKILL_COSTS.get(skill_id, 0)
	if cost > 0:
		var cost_lbl := Label.new()
		cost_lbl.text = "Стоимость: %d SP" % cost
		cost_lbl.add_theme_font_size_override("font_size", 11)
		cost_lbl.add_theme_color_override("font_color", Color(0.9, 0.75, 0.3))
		txt.add_child(cost_lbl)

	var desc_lbl := Label.new()
	desc_lbl.text = info["desc"]
	desc_lbl.add_theme_font_size_override("font_size", 12)
	desc_lbl.add_theme_color_override("font_color", Color(0.58, 0.58, 0.68))
	desc_lbl.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	txt.add_child(desc_lbl)

	# Полоса мастерства (только для активных навыков, у которых есть skill_uses)
	if not info["passive"] and GameConfig.skill_uses.has(skill_id):
		var m: int = GameConfig.mastery(skill_id)
		var uses: int = GameConfig.skill_uses.get(skill_id, 0)
		var m_lbl := Label.new()
		var stars := "★".repeat(m) + "☆".repeat(GameConfig.MASTERY_MAX - m)
		m_lbl.text = "Мастерство: %s   (%d исп.)" % [stars, uses]
		m_lbl.add_theme_font_size_override("font_size", 11)
		m_lbl.add_theme_color_override("font_color", Color(1.0, 0.78, 0.3))
		txt.add_child(m_lbl)

	# Кнопка действия
	var btn := Button.new()
	btn.custom_minimum_size = Vector2(108, 38)
	btn.add_theme_font_size_override("font_size", 13)
	btn.process_mode = Node.PROCESS_MODE_ALWAYS
	btn.pressed.connect(func(): _on_action(skill_id))
	row.add_child(btn)

	_skill_buttons[skill_id] = btn
	return card

# ── Обновление кнопок ────────────────────────────────────────────────────────

func _refresh() -> void:
	_sp_label.text = "Очки навыков: %d" % GameConfig.skill_points
	_xp_bar.value  = GameConfig.xp
	_xp_label.text = "%d / %d" % [GameConfig.xp, GameConfig.XP_PER_SP]

	for skill_id in _skill_buttons:
		var btn: Button  = _skill_buttons[skill_id]
		var info         = SKILL_INFO[skill_id]
		var unlocked: bool = GameConfig.skills_unlocked.get(skill_id, false)
		var cost: int      = GameConfig.SKILL_COSTS.get(skill_id, 0)
		var is_passive: bool = info["passive"]

		if not unlocked:
			if cost == 0:
				btn.text     = "Активен"
				btn.disabled = true
				btn.modulate = Color(0.5, 1.0, 0.5)
			else:
				btn.text     = "Открыть (%d SP)" % cost
				btn.disabled = GameConfig.skill_points < cost
				btn.modulate = Color(1.0, 1.0, 1.0) if not btn.disabled else Color(0.5, 0.5, 0.55)
		else:
			if is_passive:
				var active: bool = GameConfig.passives.get(skill_id, false)
				if active:
					btn.text     = "ВКЛ  (нажми)"
					btn.disabled = false
					btn.modulate = Color(0.45, 1.0, 0.55)
				else:
					btn.text     = "ВЫКЛ  (нажми)"
					btn.disabled = false
					btn.modulate = Color(0.85, 0.85, 0.9)
			else:
				# Открытый активный навык можно УСИЛИВАТЬ повторными покупками:
				# каждая даёт +★ мастерства (эквивалент 10 применений), до 5★.
				var m := GameConfig.mastery(skill_id)
				var up_cost := maxi(cost, 2)
				if GameConfig.skill_uses.has(skill_id) and m < GameConfig.MASTERY_MAX:
					btn.text     = "Усилить %s→%s  (%d SP)" % ["★".repeat(maxi(m, 0)) if m > 0 else "☆", "★".repeat(m + 1), up_cost]
					btn.disabled = GameConfig.skill_points < up_cost
					btn.modulate = Color(1.0, 0.9, 0.5) if not btn.disabled else Color(0.55, 0.55, 0.6)
				else:
					btn.text     = "МАКС ★★★★★" if GameConfig.skill_uses.has(skill_id) else "Открыт"
					btn.disabled = true
					btn.modulate = Color(0.5, 1.0, 0.5)

func _on_action(skill_id: String) -> void:
	var info       = SKILL_INFO[skill_id]
	var unlocked   = GameConfig.skills_unlocked.get(skill_id, false)

	if not unlocked or not info["passive"]:
		GameConfig.try_buy_skill(skill_id)
	elif info["passive"]:
		GameConfig.passives[skill_id] = not GameConfig.passives.get(skill_id, false)
		GameConfig.save_game()

	_refresh()

func _on_close() -> void:
	emit_signal("closed")
	queue_free()

# ── Иконки ───────────────────────────────────────────────────────────────────

func _make_icon(skill_id: String, size: int) -> ImageTexture:
	var img := Image.create_empty(size, size, false, Image.FORMAT_RGBA8)
	var col: Color = ICON_COLORS.get(skill_id, Color.WHITE)
	_draw_bg_circle(img, size, col)
	match skill_id:
		"flash":    _icon_star(img, size, col, 8)
		"dash":     _icon_arrow(img, size, col)
		"sonar":    _icon_rings(img, size, col)
		"shield":   _icon_shield(img, size, col)
		"guide":    _icon_flame(img, size, col)
		"reveal":   _icon_eye(img, size, col)
		"save":     _icon_bolt(img, size, col)
		"capacity": _icon_jar(img, size, col)
		"charge":   _icon_battery(img, size, col)
		"range":    _icon_expand(img, size, col)
		"legs":     _icon_speed(img, size, col)
		"magic":    _icon_star(img, size, col, 4)
		"apex":     _icon_apex(img, size, col)
	return ImageTexture.create_from_image(img)

func _icon_apex(img: Image, size: int, col: Color) -> void:
	# Звезда + кольцо вокруг — символ супер-формы
	var cx := size * 0.5; var cy := size * 0.5
	for deg in 360:
		var a := deg_to_rad(float(deg))
		var x := int(cx + cos(a) * size * 0.40); var y := int(cy + sin(a) * size * 0.40)
		_px(img, x, y, col)
	_icon_star(img, size, col, 5)

func _draw_bg_circle(img: Image, size: int, col: Color) -> void:
	var cx := size * 0.5; var cy := size * 0.5; var r := size * 0.5 - 1.0
	for y in size:
		for x in size:
			var d := Vector2(x - cx + 0.5, y - cy + 0.5).length()
			if d < r:
				var edge := clampf(1.0 - maxf(0.0, d - (r - 2.0)) / 2.0, 0.0, 1.0)
				img.set_pixel(x, y, Color(col.r * 0.15, col.g * 0.15, col.b * 0.15, edge))

func _px(img: Image, x: int, y: int, c: Color) -> void:
	if x >= 0 and x < img.get_width() and y >= 0 and y < img.get_height():
		# Смешиваем поверх фона
		var bg := img.get_pixel(x, y)
		img.set_pixel(x, y, Color(
			lerpf(bg.r, c.r, c.a), lerpf(bg.g, c.g, c.a),
			lerpf(bg.b, c.b, c.a), maxf(bg.a, c.a)))

func _line(img: Image, x0: int, y0: int, x1: int, y1: int, c: Color, w: int = 1) -> void:
	var dx := absi(x1 - x0); var dy := absi(y1 - y0)
	var sx := 1 if x0 < x1 else -1; var sy := 1 if y0 < y1 else -1
	var err := dx - dy; var x := x0; var y := y0
	while true:
		for oy in range(-w, w + 1):
			for ox in range(-w, w + 1):
				_px(img, x + ox, y + oy, c)
		if x == x1 and y == y1: break
		var e2 := 2 * err
		if e2 > -dy: err -= dy; x += sx
		if e2 < dx:  err += dx; y += sy

func _icon_star(img: Image, size: int, col: Color, pts: int) -> void:
	var cx := size * 0.5; var cy := size * 0.5
	var ro := size * 0.36; var ri := size * 0.15
	for i in pts:
		var ao := TAU * i / pts - PI * 0.5
		var ai := ao + TAU / (pts * 2)
		var an := ao + TAU / pts
		_line(img, int(cx), int(cy), int(cx + cos(ao)*ro), int(cy + sin(ao)*ro), col, 1)
		_line(img, int(cx + cos(ao)*ro), int(cy + sin(ao)*ro), int(cx + cos(ai)*ri), int(cy + sin(ai)*ri), col, 1)
		_line(img, int(cx + cos(ai)*ri), int(cy + sin(ai)*ri), int(cx + cos(an)*ro), int(cy + sin(an)*ro), col, 1)

func _icon_arrow(img: Image, size: int, col: Color) -> void:
	var m := size / 2; var l := size / 6; var r := size * 5 / 6
	_line(img, l, m, r, m, col, 2)
	_line(img, r, m, int(r - size * 0.22), int(m - size * 0.22), col, 2)
	_line(img, r, m, int(r - size * 0.22), int(m + size * 0.22), col, 2)

func _icon_rings(img: Image, size: int, col: Color) -> void:
	var cx := size * 0.5; var cy := size * 0.5
	for ri_f: float in [0.13, 0.24, 0.37]:
		var rad: float = size * ri_f
		for deg in 360:
			var a := deg_to_rad(float(deg))
			var x := int(cx + cos(a) * rad); var y := int(cy + sin(a) * rad)
			_px(img, x, y, col); _px(img, x+1, y, col)

func _icon_shield(img: Image, size: int, col: Color) -> void:
	var cx := size / 2; var t := size / 6; var b := size * 5 / 6; var hw := size * 3 / 8
	_line(img, cx - hw, t, cx + hw, t, col, 1)
	_line(img, cx - hw, t, cx - hw, size / 2, col, 1)
	_line(img, cx + hw, t, cx + hw, size / 2, col, 1)
	_line(img, cx - hw, size / 2, cx, b, col, 1)
	_line(img, cx + hw, size / 2, cx, b, col, 1)
	_line(img, cx - hw + 4, t + 4, cx + hw - 4, t + 4, Color(col.r, col.g, col.b, 0.45), 1)

func _icon_flame(img: Image, size: int, col: Color) -> void:
	var cx := size * 0.5
	for y in size:
		for x in size:
			var fx := float(x) - cx; var fy := float(y) - size * 0.18
			var d := (fx*fx) / pow(size*0.14, 2) + (fy*fy) / pow(size*0.34, 2)
			if d < 1.0:
				_px(img, x, y, Color(col.r, col.g, col.b, clampf(1.2 - d, 0.0, 1.0)))

func _icon_eye(img: Image, size: int, col: Color) -> void:
	var cx := size * 0.5; var cy := size * 0.5
	for deg in 360:
		var a := deg_to_rad(float(deg))
		var x := int(cx + cos(a) * size * 0.36); var y := int(cy + sin(a) * size * 0.20)
		_px(img, x, y, col); _px(img, x+1, y, col)
	for y in size:
		for x in size:
			if Vector2(x - cx + 0.5, y - cy + 0.5).length() < size * 0.10:
				_px(img, x, y, col)

func _icon_bolt(img: Image, size: int, col: Color) -> void:
	var pts := [Vector2i(size*6/10, size/8), Vector2i(size*4/10, size*4/8),
				Vector2i(size*6/10, size*4/8), Vector2i(size*3/10, size*7/8)]
	for i in pts.size()-1:
		_line(img, pts[i].x, pts[i].y, pts[i+1].x, pts[i+1].y, col, 2)

func _icon_jar(img: Image, size: int, col: Color) -> void:
	var l := size/4; var r := size*3/4; var t := size/5; var b := size*4/5
	var nl := size*5/12; var nr := size*7/12
	_line(img, nl, t, nr, t, col, 1); _line(img, nl, t, l, t+size/8, col, 1)
	_line(img, nr, t, r, t+size/8, col, 1); _line(img, l, t+size/8, l, b, col, 1)
	_line(img, r, t+size/8, r, b, col, 1); _line(img, l, b, r, b, col, 1)
	_line(img, l+3, b-size/4, r-3, b-size/4, Color(col.r, col.g, col.b, 0.5), 2)

func _icon_battery(img: Image, size: int, col: Color) -> void:
	var l := size/8; var r := size*6/8; var t := size*3/8; var b := size*5/8
	_line(img, l, t, r, t, col, 1); _line(img, l, b, r, b, col, 1)
	_line(img, l, t, l, b, col, 1); _line(img, r, t, r, b, col, 1)
	_line(img, r, t+3, size*7/8, t+3, col, 1); _line(img, r, b-3, size*7/8, b-3, col, 1)
	_line(img, size*7/8, t+3, size*7/8, b-3, col, 1)
	for i in 3:
		_line(img, l+4+i*(size/6), t+3, l+4+i*(size/6), b-3, col, 1)

func _icon_expand(img: Image, size: int, col: Color) -> void:
	var cx := size*0.5; var cy := size*0.5
	for ri_f: float in [0.20, 0.34]:
		var rad: float = size * ri_f
		for deg in 360:
			var a := deg_to_rad(float(deg))
			var x := int(cx + cos(a)*rad); var y := int(cy + sin(a)*rad)
			_px(img, x, y, col)
	_line(img, int(cx)-2, int(cy)-2, int(cx)+2, int(cy)+2, col, 1)

func _icon_speed(img: Image, size: int, col: Color) -> void:
	for i in 3:
		var off := (i - 1) * size / 5
		_line(img, size/5+off, size*3/4, size*4/5+off, size/4, col, 1)
