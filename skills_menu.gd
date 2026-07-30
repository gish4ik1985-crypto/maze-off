extends CanvasLayer

# Магазин навыков — колесо Апекса. Открывается из паузы (Уровни) и из меню.
# Всё управление — через колесо: клик по ноде показывает описание и кнопку
# «Открыть/Усилить». Вокруг каждого навыка — его ветвь-пассивка: она растёт
# сама от действий игрока и усиливает навык, а через него — форму Апекса.

signal closed

# ── Данные навыков ──────────────────────────────────────────────────────────

const SKILL_INFO := {
	"flash":    {name="Вспышка",   key="Q",     desc="Резкий всплеск света на 0.5 с + бьёт врагов рядом. Открыта с самого начала — твой основной ответ на погоню. Дешёвая и частая; за разведку и обзор отвечает Сонар."},
	"dash":     {name="Рывок",     key="Shift", desc="Мгновенный бросок в направлении движения. Уйти от врага."},
	"smother":  {name="Тление",    key="R",     desc="Пригаситься на пару секунд: медленно и слепо, зато враги теряют тебя из виду."},
	"sonar":    {name="Сонар",     key="E",     desc="Кольцо света раздвигает обзор на ~6 секунд — сканирование лабиринта и передвижение, урона не наносит. Дороже и куда реже Вспышки: разведка, а не боевая кнопка (для врагов — Вспышка)."},
	"shield":   {name="Щит",       key="C",     desc="Полностью останавливает разрядку на 4 секунды."},
	"guide":    {name="Искра",     key="G",     desc="Путеводный огонёк летит к ближайшему осколку-улике. К самому выходу ведёт только после того, как выход найден: это инструмент следствия, а не стрелка «тут выход»."},
	"reveal":   {name="Озарение",  key="F",     desc="Освещает весь этаж на 4 с. Заряжается на станциях."},
	"pulse":    {name="Пульс",     key="B",     desc="На 10 секунд включает звуковой ориентир. Пока выход не найден, «пик» учащается по мере приближения к НЕИЗВЕДАННЫМ коридорам; когда выход известен — к нему самому."},
	"mirage":   {name="Мираж",     key="T",     desc="Ложная светящаяся цель: враги поблизости бегут проверять её. Дар Тёмного Ядра."},
	"breach":   {name="Разлом",    key="Y",     desc="Проламывает стену по направлению взгляда. Дар Тёмного Ядра."},
	"chrono":   {name="Хронос",    key="V",     desc="Замораживает всех врагов этажа на несколько секунд. Дар Тёмного Ядра."},
	"apex":     {name="АПЕКС",     key="H",     desc="Супернавык. Открывается, когда куплены все 7 активных навыков — или досрочно: куплено 4+ навыков и один из них прокачан до ★5. Форма зависит от того, какой навык ты прокачал сильнее всего."},
}
const SKILL_INFO_EN := {
	"flash":    {name="Flash",   desc="A sharp burst of light for 0.5s + hits nearby enemies. Unlocked from the very start — your go-to answer to a chase. Cheap and frequent; Sonar handles recon and sight."},
	"dash":     {name="Dash",    desc="An instant burst in your direction of movement. Escape an enemy."},
	"smother":  {name="Smother", desc="Dim yourself for a couple of seconds: slow and half-blind, but enemies lose sight of you."},
	"sonar":    {name="Sonar",   desc="A ring of light widens your sight for ~6 seconds — scanning the maze and moving through it, deals no damage. Pricier and much rarer than Flash: recon, not a combat button (for enemies, use Flash)."},
	"shield":   {name="Shield",  desc="Fully stops your drain for 4 seconds."},
	"guide":    {name="Guide",   desc="A guiding light leads to the exit on the current floor."},
	"reveal":   {name="Reveal",  desc="Lights up the whole floor for 4s. Charges at stations."},
	"pulse":    {name="Pulse",   desc="For 10 seconds, turns on an audio guide: a beep, faster and brighter the closer you get along the corridor to the exit."},
	"mirage":   {name="Mirage",  desc="A false glowing target: nearby enemies rush to check it. Dark Core's gift."},
	"breach":   {name="Breach",  desc="Breaks a wall in the direction you're facing. Dark Core's gift."},
	"chrono":   {name="Chrono",  desc="Freezes every enemy on the floor for a few seconds. Dark Core's gift."},
	"apex":     {name="APEX",    desc="A superskill. Unlocks once all 7 active skills are bought — or early, once you own 4+ skills and one has reached ★5 mastery. Its form depends on your most-mastered skill."},
}

func skill_info(id: String) -> Dictionary:
	if GameConfig.locale == "en" and SKILL_INFO_EN.has(id):
		var base: Dictionary = SKILL_INFO.get(id, {})
		var en: Dictionary = SKILL_INFO_EN[id]
		return {"name": en.get("name", base.get("name", id)), "key": base.get("key", ""), "desc": en.get("desc", base.get("desc", ""))}
	return SKILL_INFO.get(id, {})

# ── Навыки призыва (GAMEDESIGN.md §25) — данные для отдельного колеса
# «Призыв» (SummonWheel ниже). ОТДЕЛЬНЫЙ пул от SKILL_INFO/POOL Апекса —
# растёт так же (просто дописать id сюда + в SummonWheel.POOL), когда
# появятся новые навыки призыва. Пока один — Зеркальный союзник.
const SUMMON_INFO := {
	"mirror_ally": {name="Зеркальный союзник", key="N", desc="Призывает временного союзника — следует за тобой и сам атакует ближайшего врага короткими импульсами света. Хрупкий и недолговечный: угасает через 25 секунд."},
}
const SUMMON_INFO_EN := {
	"mirror_ally": {name="Mirror Ally", desc="Summons a temporary ally — follows you and strikes the nearest enemy with short pulses of light on its own. Fragile and short-lived: fades after 25 seconds."},
}
func summon_info(id: String) -> Dictionary:
	if GameConfig.locale == "en" and SUMMON_INFO_EN.has(id):
		var base: Dictionary = SUMMON_INFO.get(id, {})
		var en: Dictionary = SUMMON_INFO_EN[id]
		return {"name": en.get("name", base.get("name", id)), "key": base.get("key", ""), "desc": en.get("desc", base.get("desc", ""))}
	return SUMMON_INFO.get(id, {})

# Что усиливает мастерство (+15% за ★, см. GameConfig.mastery_bonus). У навыков
# без масштабирования мастерство влияет только на выбор формы Апекса.
const MASTERY_WHAT := {
	"flash":   "длительность вспышки",
	"dash":    "дальность рывка",
	"sonar":   "радиус и послесвечение сонара",
	"shield":  "длительность щита",
	"reveal":  "длительность озарения",
	"smother": "длительность тления",
	"pulse":   "длительность окна пульса",
	"mirage":  "радиус приманки миража",
	"chrono":  "длительность заморозки",
	"mirror_ally": "живучесть и урон союзника",
}
const MASTERY_WHAT_EN := {
	"flash":   "flash duration",
	"dash":    "dash range",
	"sonar":   "sonar radius and afterglow",
	"shield":  "shield duration",
	"reveal":  "reveal duration",
	"smother": "smother duration",
	"pulse":   "pulse window duration",
	"mirage":  "mirage lure radius",
	"chrono":  "freeze duration",
	"mirror_ally": "ally toughness and damage",
}

const APEX_FORM_NAMES := {
	"flash":  "Сверхвспышка",
	"dash":   "Цепной рывок",
	"sonar":  "Карта мира",
	"shield": "Бессмертие",
	"guide":  "Прозрение: находит выход и переносит к нему",
	"reveal": "Вечное озарение",
	"pulse":  "Незатухающий пульс",
	"mirage": "Великий обман",
	"breach": "Землетрясение",
	"chrono": "Остановка времени",
}
const APEX_FORM_NAMES_EN := {
	"flash":  "Superflash",
	"dash":   "Chain Dash",
	"sonar":  "World Map",
	"shield": "Immortality",
	"guide":  "Exit Teleport",
	"reveal": "Eternal Reveal",
	"pulse":  "Everlasting Pulse",
	"mirage": "Grand Deception",
	"breach": "Earthquake",
	"chrono": "Time Stop",
}

const APEX_FORM_DESCS := {
	"flash":  "огромная вспышка + ускорение",
	"dash":   "три рывка подряд, таранит погоню",
	"sonar":  "сонар тройного радиуса, выжигает гонящихся",
	"shield": "долгая полная неуязвимость + полный заряд",
	"guide":  "находит выход и мгновенно переносит к нему",
	"reveal": "долгое озарение, этаж чистится от погони",
	"pulse":  "пульс не смолкает всю карту, чувствуешь всех врагов этажа",
	"mirage": "приманки по всему этажу + невидимость",
	"breach": "пролом нескольких стен разом",
	"chrono": "долгая заморозка всего этажа + глоток Воли",
}
const APEX_FORM_DESCS_EN := {
	"flash":  "a huge flash + speed boost",
	"dash":   "three dashes in a row, tackles pursuers",
	"sonar":  "triple-radius sonar, burns pursuers",
	"shield": "long full invulnerability + full charge",
	"guide":  "instant teleport to the exit",
	"reveal": "long reveal, the floor is cleared of pursuers",
	"pulse":  "the pulse never stops, senses every enemy on the floor",
	"mirage": "lures across the whole floor + invisibility",
	"breach": "breaks several walls at once",
	"chrono": "a long freeze of the whole floor + a sip of Will",
}

func apex_form_name(id: String) -> String:
	return str(APEX_FORM_NAMES_EN.get(id, id)) if GameConfig.locale == "en" else str(APEX_FORM_NAMES.get(id, id))

func apex_form_desc(id: String) -> String:
	return str(APEX_FORM_DESCS_EN.get(id, "")) if GameConfig.locale == "en" else str(APEX_FORM_DESCS.get(id, ""))

# Строка «что даст усиление»: текущий множитель → следующий.
func _mastery_line(id: String) -> String:
	var m := GameConfig.mastery(id)
	var en := GameConfig.locale == "en"
	if not MASTERY_WHAT.has(id):
		return "Mastery here only affects the Apex form (whichever is most mastered becomes Apex)." if en else \
			"Мастерство здесь влияет только на выбор формы Апекса (кто прокачан сильнее — тем Апекс и станет)."
	var what: String = MASTERY_WHAT_EN[id] if en else MASTERY_WHAT[id]
	var cur := 1.0 + m * 0.15
	if m >= GameConfig.MASTERY_MAX:
		return (("★ boosts %s: now ×%.2f — max.") if en else ("★ усиливает %s: сейчас ×%.2f — предел.")) % [what, cur]
	return (("★ boosts %s: now ×%.2f → after upgrade ×%.2f.") if en else ("★ усиливает %s: сейчас ×%.2f → после усиления ×%.2f.")) % [what, cur, cur + 0.15]

var _xp_bar: ProgressBar
var _xp_label: Label
var _sp_label: Label
var _wheel: ApexWheel
var _wheel_wrap: Control   # обёртка колеса: масштаб под высоту окна (без скролла)

# Панель описания выбранной ноды
var _d_name: Label
var _d_desc: Label
var _d_meta: Label
var _d_eff: Label
var _d_how: Label
var _action_btn: Button
var _selected: String = ""   # id навыка, "apex" или "p:<id пассивки>"

# ── Страницы: Апекс / Призыв (GAMEDESIGN.md §25) ────────────────────────────
var _apex_page: HBoxContainer
var _summon_page: HBoxContainer
var _page_apex_btn: Button
var _page_summon_btn: Button
var _summon_wheel: SummonWheel
var _summon_wheel_wrap: Control
var _sd_name: Label
var _sd_desc: Label
var _sd_how: Label
var _summon_action_btn: Button
var _selected_summon: String = ""

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
	# Полностью непрозрачный: магазин открывается и поверх главного меню,
	# сквозить нижний экран не должен.
	bg.color = Color(0.02, 0.02, 0.06, 1.0)
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
	title.text = GameConfig.tt("МАГАЗИН НАВЫКОВ", "SKILL SHOP")
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
	xp_title.text = GameConfig.tt("Опыт (до следующего SP):", "Experience (to next SP):")
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

	# ── Переключатель страниц: Апекс / Призыв (GAMEDESIGN.md §25) ──────────
	# Кнопки сверху — «Призыв» появляется после первой победы над дверь-боссом
	# (☠, уровни кратные 5) — раньше висело на супербоссе (ур. 50), из-за чего
	# навык был доступен практически только на переигровке уже пройденного
	# финала. До этого момента игрок о нём не знает вовсе, не «замок на кнопке».
	# Задел на будущее: колесо Призыва задумано расти так же, как когда-то
	# росло колесо Апекса — сейчас в нём один навык, структура уже готова
	# принять больше (см. SummonWheel.POOL).
	if GameConfig.door_boss_defeated:
		var switch_row := HBoxContainer.new()
		switch_row.alignment = BoxContainer.ALIGNMENT_CENTER
		switch_row.add_theme_constant_override("separation", 10)
		switch_row.process_mode = Node.PROCESS_MODE_ALWAYS
		vbox.add_child(switch_row)
		_page_apex_btn = UIStyle.make_button(GameConfig.tt("⚙ Апекс", "⚙ Apex"), func() -> void: _switch_page("apex"), 160, 40, 15)
		_page_apex_btn.process_mode = Node.PROCESS_MODE_ALWAYS
		switch_row.add_child(_page_apex_btn)
		_page_summon_btn = UIStyle.make_button(GameConfig.tt("✦ Призыв", "✦ Summon"), func() -> void: _switch_page("summon"), 160, 40, 15)
		_page_summon_btn.process_mode = Node.PROCESS_MODE_ALWAYS
		switch_row.add_child(_page_summon_btn)

	# ── Колесо с ветвями + панель выбранной ноды. Под колесом ничего нет. ──
	var scroll := ScrollContainer.new()
	scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	scroll.process_mode = Node.PROCESS_MODE_ALWAYS
	vbox.add_child(scroll)
	var content := VBoxContainer.new()
	content.add_theme_constant_override("separation", 10)
	content.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	scroll.add_child(content)

	_apex_page = HBoxContainer.new()
	_apex_page.alignment = BoxContainer.ALIGNMENT_CENTER
	_apex_page.add_theme_constant_override("separation", 20)
	content.add_child(_apex_page)
	var wheel_row := _apex_page
	# Колесо всегда целиком на экране: живёт в обёртке и масштабируется под
	# высоту окна (сам скролл остаётся для колонок ниже колеса).
	_wheel_wrap = Control.new()
	wheel_row.add_child(_wheel_wrap)
	_wheel = ApexWheel.new()
	_wheel.custom_minimum_size = Vector2(660, 600)
	_wheel_wrap.add_child(_wheel)
	_wheel.on_select = _select
	_fit_wheel()
	get_viewport().size_changed.connect(_fit_wheel)

	var desc_box := VBoxContainer.new()
	desc_box.custom_minimum_size = Vector2(340, 0)
	desc_box.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	# Верх, не центр: desc_box растягивается на всю высоту колеса (660x600), и
	# при ALIGNMENT_CENTER заголовок «плавал» по Y в зависимости от того,
	# сколько текста ниже (разные навыки — разная длина описания/эффекта) —
	# жалоба «описание на разных высотах». Верхнее выравнивание держит имя
	# навыка на одной и той же Y всегда, независимо от длины остального текста.
	desc_box.alignment = BoxContainer.ALIGNMENT_BEGIN
	desc_box.add_theme_constant_override("separation", 6)
	desc_box.process_mode = Node.PROCESS_MODE_ALWAYS
	wheel_row.add_child(desc_box)
	_d_name = _desc_label(desc_box, 22, Color(0.85, 0.9, 1.0))
	_d_name.text = GameConfig.tt("Кликни ноду в колесе", "Click a node in the wheel")
	_d_desc = _desc_label(desc_box, 15, Color(0.72, 0.78, 0.9))
	var wheel_hint_ru := "Навыки — на кольце, их ветви-пассивки — снаружи.
Пассивки растут сами от твоих действий и усиливают навык — а через него и форму Апекса.

● Золотое кольцо с ценой — хватает SP, чтобы ОТКРЫТЬ.
▲ Зелёное кольцо — хватает SP, чтобы УСИЛИТЬ (+1★). Каждая ★ дороже прежней."
	var wheel_hint_en := "Skills sit on the ring, their passive branches — outside.
Passives grow on their own from your actions and boost the skill — and through it, the Apex form.

● Gold ring with a price — enough SP to UNLOCK.
▲ Green ring — enough SP to UPGRADE (+1★). Each ★ costs more."
	_d_desc.text = wheel_hint_en if GameConfig.locale == "en" else wheel_hint_ru
	_d_meta = _desc_label(desc_box, 14, Color(1.0, 0.85, 0.3))
	_d_eff = _desc_label(desc_box, 13, Color(0.85, 0.75, 1.0))
	_d_how = _desc_label(desc_box, 13, Color(0.55, 0.85, 0.65))

	_action_btn = UIStyle.make_button("", _on_action, 240, 44, 16)
	_action_btn.visible = false
	_action_btn.process_mode = Node.PROCESS_MODE_ALWAYS
	desc_box.add_child(_action_btn)

	if GameConfig.door_boss_defeated:
		_build_summon_page(content)
		_switch_page("apex")

	# Постоянная «← Назад» сверху-слева — единственный способ закрыть магазин
	# (раньше тут был ещё и «Закрыть (Esc)» внизу — то же самое действие
	# продублировано двумя разными кнопками, жалоба «зачем кнопка закрыть,
	# если назад слева вверху»).
	var back_btn := UIStyle.make_button(GameConfig.t("back_arrow"), _on_close, 130, 44, 18)
	back_btn.focus_mode = Control.FOCUS_NONE
	back_btn.process_mode = Node.PROCESS_MODE_ALWAYS
	back_btn.set_anchors_preset(Control.PRESET_TOP_LEFT)
	back_btn.offset_left = 20
	back_btn.offset_top = 14
	add_child(back_btn)

	_refresh()

# Страница «Призыв» (GAMEDESIGN.md §25) — ОТДЕЛЬНОЕ колесо от Апекса
# (решено в обсуждении: не смешивать с уже сбалансированной системой),
# переключается кнопками сверху (_switch_page). Появляется после первой
# победы над дверь-боссом (GameConfig.door_boss_defeated). Пока один навык —
# Зеркальный союзник — но структура (SummonWheel.POOL + этот метод) уже
# рассчитана расти так же, как когда-то выросло колесо Апекса.
func _build_summon_page(content: VBoxContainer) -> void:
	_summon_page = HBoxContainer.new()
	_summon_page.alignment = BoxContainer.ALIGNMENT_CENTER
	_summon_page.add_theme_constant_override("separation", 20)
	_summon_page.visible = false
	content.add_child(_summon_page)

	_summon_wheel_wrap = Control.new()
	# Без явного размера обёртка репортит родителю (HBoxContainer) нулевую
	# ширину, и колесо рисуется поверх соседней колонки текста вместо своей —
	# тот же класс бага, что решает _fit_wheel() у ApexWheel, только там
	# исправлено масштабом под высоту окна, здесь пока фиксированный размер.
	_summon_wheel_wrap.custom_minimum_size = Vector2(420, 420)
	_summon_page.add_child(_summon_wheel_wrap)
	_summon_wheel = SummonWheel.new()
	_summon_wheel.custom_minimum_size = Vector2(420, 420)
	_summon_wheel_wrap.add_child(_summon_wheel)
	_summon_wheel.on_select = _select_summon

	var sdesc_box := VBoxContainer.new()
	sdesc_box.custom_minimum_size = Vector2(340, 0)
	sdesc_box.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	sdesc_box.alignment = BoxContainer.ALIGNMENT_BEGIN
	sdesc_box.add_theme_constant_override("separation", 6)
	sdesc_box.process_mode = Node.PROCESS_MODE_ALWAYS
	_summon_page.add_child(sdesc_box)
	_sd_name = _desc_label(sdesc_box, 22, Color(0.55, 1.0, 0.65))
	_sd_name.text = GameConfig.tt("Кликни узел в колесе", "Click a node in the wheel")
	_sd_desc = _desc_label(sdesc_box, 15, Color(0.72, 0.78, 0.9))
	_sd_desc.text = GameConfig.tt(
		"Навыки призыва — отдельная ветка, открытая победой над дверь-боссом (☠). Пока один навык; колесо задумано расти так же, как когда-то выросло колесо Апекса.",
		"Summon skills are a separate branch, unlocked by beating a door boss (☠). Just one skill for now — this wheel is meant to grow the same way the Apex wheel once did.")
	_sd_how = _desc_label(sdesc_box, 13, Color(0.55, 0.85, 0.65))

	_summon_action_btn = UIStyle.make_button("", _on_summon_action, 240, 44, 16)
	_summon_action_btn.visible = false
	_summon_action_btn.process_mode = Node.PROCESS_MODE_ALWAYS
	sdesc_box.add_child(_summon_action_btn)

func _switch_page(page: String) -> void:
	if _apex_page:
		_apex_page.visible = (page == "apex")
	if _summon_page:
		_summon_page.visible = (page == "summon")
	if _page_apex_btn:
		_page_apex_btn.disabled = (page == "apex")
	if _page_summon_btn:
		_page_summon_btn.disabled = (page == "summon")

func _select_summon(id: String) -> void:
	_selected_summon = id
	if id == "hub":
		_sd_name.text = GameConfig.tt("ПРИЗЫВ", "SUMMON")
		_sd_name.add_theme_color_override("font_color", Color(0.55, 1.0, 0.65))
		_sd_desc.text = GameConfig.tt(
			"Хаб будущего колеса призыва. Когда навыков станет больше — здесь появится общая сводка/синергии, как у Апекса.",
			"Hub of the future summon wheel. Once there are more skills, a shared overview/synergy summary will live here, like Apex's.")
		_sd_how.text = ""
		_summon_action_btn.visible = false
		return
	var info: Dictionary = summon_info(id)
	_sd_name.text = "%s  [%s]" % [str(info.get("name", id)), str(info.get("key", ""))]
	_sd_name.add_theme_color_override("font_color", SummonWheel.TINTS.get(id, Color(0.6, 0.85, 1.0)))
	_sd_desc.text = str(info.get("desc", ""))
	var owned: bool = GameConfig.summon_unlocked.get(id, false)
	var cost: int = GameConfig.SUMMON_COSTS.get(id, 3)
	if owned:
		var m := GameConfig.mastery(id)
		var meta_line := (("Мастерство: %s%s") % ["★".repeat(m), "☆".repeat(5 - m)]) if GameConfig.locale != "en" else \
			(("Mastery: %s%s") % ["★".repeat(m), "☆".repeat(5 - m)])
		var eff := _mastery_line(id)
		if m < GameConfig.MASTERY_MAX:
			var up_cost := GameConfig.summon_upgrade_cost(id)
			_sd_how.text = "%s\n%s\n%s" % [meta_line, eff, GameConfig.tt(
				"Усиление: применяй навык (10 применений = ★) — или купи ★ прямо здесь.",
				"Upgrade: use the skill (10 uses = ★) — or buy a ★ right here.")]
			_summon_action_btn.visible = true
			_summon_action_btn.text = GameConfig.tt("Усилить %s→%s  (%d SP)", "Upgrade %s→%s  (%d SP)") % [
				"★".repeat(m) if m > 0 else "☆", "★".repeat(m + 1), up_cost]
			_summon_action_btn.disabled = GameConfig.skill_points < up_cost
		else:
			_sd_how.text = "%s\n%s\n%s" % [meta_line, eff, GameConfig.tt(
				"Мастерство на пределе — это вершина навыка.", "Mastery is at its cap — this is the skill's peak.")]
			_summon_action_btn.visible = false
	else:
		_sd_how.text = GameConfig.tt("Получение: купи за %d SP.", "Get it: buy for %d SP.") % cost
		_summon_action_btn.visible = true
		_summon_action_btn.text = GameConfig.tt("Открыть  (%d SP)", "Unlock  (%d SP)") % cost
		_summon_action_btn.disabled = GameConfig.skill_points < cost

func _on_summon_action() -> void:
	var id := _selected_summon
	if id == "" or id == "hub":
		return
	if GameConfig.summon_unlocked.get(id, false):
		if not GameConfig.try_upgrade_summon(id):
			return
	else:
		var cost: int = GameConfig.SUMMON_COSTS.get(id, 3)
		if GameConfig.skill_points < cost:
			return
		GameConfig.skill_points -= cost
		GameConfig.summon_unlocked[id] = true
		# [SAVE-SAFETY] см. main.gd::on_superboss_defeated — test_mode не гейтит
		# save_game() само по себе, харнессы должны сами это проверять.
		if not GameConfig.test_mode:
			GameConfig.save_game()
	if _sp_label:
		_sp_label.text = GameConfig.tt("Очки навыков: %d", "Skill points: %d") % GameConfig.skill_points
	if _summon_wheel:
		_summon_wheel._rebuild()
	_select_summon(id)

# Мельче 55% не ужимаем — станет нечитаемым.
func _fit_wheel() -> void:
	if _wheel == null or _wheel_wrap == null:
		return
	var vh: float = get_viewport().get_visible_rect().size.y
	var f: float = clampf((vh - 220.0) / 600.0, 0.55, 1.0)
	_wheel.scale = Vector2(f, f)
	_wheel.position = Vector2.ZERO
	_wheel_wrap.custom_minimum_size = Vector2(660.0 * f, 600.0 * f)

func _desc_label(parent: Control, fsize: int, col: Color) -> Label:
	var l := Label.new()
	l.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	l.custom_minimum_size = Vector2(340, 0)
	l.add_theme_font_size_override("font_size", fsize)
	l.add_theme_color_override("font_color", col)
	parent.add_child(l)
	return l

# ── Выбор ноды ───────────────────────────────────────────────────────────────

func _select(id: String) -> void:
	_selected = id
	if id.begins_with("p:"):
		_select_passive(id.substr(2))
		return
	var en := GameConfig.locale == "en"
	var info: Dictionary = skill_info(id)
	var col: Color = SkillIcons.color_of(id)
	_d_name.text = "%s  [%s]" % [str(info.get("name", id)), str(info.get("key", ""))]
	_d_name.add_theme_color_override("font_color", col)
	var extra := ""
	if id in ["mirage", "breach", "chrono"]:
		extra = (" Dark Core's gift: earned by defeating the boss (☠ door).") if en else \
			(" Дар Ядра: добывается победой над боссом (дверь ☠).")
	_d_desc.text = str(info.get("desc", "")).replace("\n", " ") + extra
	var m := GameConfig.mastery(id)
	var owned: bool = GameConfig.skills_unlocked.get(id, false)
	var top := GameConfig.top_mastered(1)
	var form_tag := ("   ·   CURRENT APEX FORM" if en else "   ·   ТЕКУЩАЯ ФОРМА АПЕКСА") if (top.size() > 0 and top[0] == id) else ""
	if id == "apex":
		_select_apex(owned)
		return
	_d_meta.text = (("Mastery: %s%s%s" if en else "Мастерство: %s%s%s") % ["★".repeat(m), "☆".repeat(5 - m), form_tag]) if owned else ("Not unlocked yet" if en else "Ещё не открыт")
	# Мастерство + ветвь-пассивка
	var eff := _mastery_line(id) if owned else ""
	var pid: String = GameConfig.SKILL_PASSIVE.get(id, "")
	if pid != "":
		var bonus := float(GameConfig.PASSIVE_SKILL_BONUS.get(id, 0.04))
		eff += (("\nBranch «%s» (lvl %d): +%d%% to the skill's power per level — and just as much to the Apex form from it.") if en else
			("\nВетвь «%s» (ур. %d): +%d%% к силе навыка за уровень — и настолько же к форме Апекса от него.")) % [
			GameConfig.passive_name(pid), GameConfig.passive_level(pid), int(round(bonus * 100))]
	_d_eff.text = eff
	# Как получить / как усилить + кнопка действия
	var cost := int(GameConfig.SKILL_COSTS.get(id, 0))
	_action_btn.visible = false
	if not owned:
		if id in ["mirage", "breach", "chrono"]:
			_d_how.text = "Get it: defeat the Dark Core beyond the crimson door ☠ (levels divisible by 5)." if en else \
				"Получение: победи Тёмное Ядро за багровой дверью ☠ (уровни, кратные 5)."
		else:
			var ms: Dictionary = GameConfig.SKILL_MILESTONES.get(id, {})
			var ms_text := GameConfig.milestone_text(id)
			var alt := ((" — or on its own: %s" % ms_text) if en else (" — или само: %s" % ms_text)) if not ms.is_empty() else ""
			_d_how.text = (("Get it: buy for %d SP%s.") if en else ("Получение: купи за %d SP%s.")) % [cost, alt]
			_action_btn.visible = true
			_action_btn.text = ("Unlock  (%d SP)" if en else "Открыть  (%d SP)") % cost
			_action_btn.disabled = GameConfig.skill_points < cost
	elif GameConfig.skill_uses.has(id):
		if m < GameConfig.MASTERY_MAX:
			var up_cost := GameConfig.upgrade_cost(id)
			_d_how.text = "Upgrade: use the skill (10 uses = ★) — or buy a ★ right here. Each ★ costs more." if en else \
				"Усиление: применяй навык (10 применений = ★) — или купи ★ прямо здесь. Каждая ★ дороже."
			_action_btn.visible = true
			_action_btn.text = ("Upgrade %s→%s  (%d SP)" if en else "Усилить %s→%s  (%d SP)") % ["★".repeat(m) if m > 0 else "☆", "★".repeat(m + 1), up_cost]
			_action_btn.disabled = GameConfig.skill_points < up_cost
		else:
			_d_how.text = "Mastery is at its cap — this is the skill's peak." if en else "Мастерство на пределе — это вершина навыка."
	else:
		_d_how.text = ""

func _select_apex(owned: bool) -> void:
	var en := GameConfig.locale == "en"
	var top := GameConfig.top_mastered(2)
	_d_meta.text = ""
	_action_btn.visible = false
	if owned:
		var main_id: String = top[0]
		var s := (("Current form: %s — %s.") if en else ("Текущая форма: %s — %s.")) % [
			apex_form_name(main_id), apex_form_desc(main_id)]
		if top.size() > 1 and top[1] != main_id:
			s += (("\nEcho: %s (weaker).") if en else ("\nЭхо: %s (слабее).")) % apex_form_name(top[1])
		_d_meta.text = s
		_d_eff.text = (("Form power right now: ×%.2f (mastery of «%s» × its passive branch).") if en else
			("Сила формы сейчас: ×%.2f (мастерство «%s» × его ветвь-пассивка).")) % [
			GameConfig.apex_power(main_id), str(skill_info(main_id).get("name", main_id))]
		_d_how.text = "Upgrading Apex: level up the mastery of the form's skill and feed its passive branch — Apex inherits their power." if en else \
			"Усиление Апекса: качай мастерство навыка-формы и корми его ветвь-пассивку — Апекс наследует их силу."
	else:
		_d_eff.text = ""
		_d_how.text = "Get it: unlock all 7 active skills — or early, once you own 4+ and one has reached ★5 mastery." if en else \
			"Получение: открой все 7 активных навыков — или досрочно: купи 4+ навыков и прокачай один до ★5."

func _select_passive(pid: String) -> void:
	var en := GameConfig.locale == "en"
	var pd: Dictionary = GameConfig.PASSIVE_DEFS.get(pid, {})
	if pd.is_empty():
		return
	var lvl := GameConfig.passive_level(pid)
	var col: Color = SkillIcons.color_of(pid)
	_d_name.text = GameConfig.passive_name(pid)
	_d_name.add_theme_color_override("font_color", col)
	_d_desc.text = (("%s\nGrows on its own: %s.") if en else ("%s\nРастёт сама: %s.")) % [GameConfig.passive_per(pid), GameConfig.passive_act(pid)]
	var pr: Array = GameConfig.passive_progress(pid)
	_d_meta.text = (("Level: %s%s   ·   progress %d / %d") if en else ("Уровень: %s%s   ·   прогресс %d / %d")) % ["★".repeat(lvl), "☆".repeat(5 - lvl), int(pr[0]), int(pr[1])]
	# К какому навыку ведёт ветвь
	var skill_id := ""
	for sid in GameConfig.SKILL_PASSIVE:
		if str(GameConfig.SKILL_PASSIVE[sid]) == pid:
			skill_id = sid
			break
	if skill_id != "":
		var bonus := float(GameConfig.PASSIVE_SKILL_BONUS.get(skill_id, 0.04))
		_d_eff.text = (("Skill branch «%s»: currently ×%.2f to its power (+%d%%/lvl) — and just as much to the Apex form from it.") if en else
			("Ветвь навыка «%s»: сейчас ×%.2f к его силе (+%d%%/ур) — и настолько же к форме Апекса от него.")) % [
			str(skill_info(skill_id).get("name", skill_id)),
			GameConfig.skill_passive_mult(skill_id), int(round(bonus * 100))]
	else:
		_d_eff.text = ""
	_d_how.text = "Passives aren't bought — they grow from your actions in the maze." if en else \
		"Пассивки не покупаются — они растут от твоих действий в лабиринте."
	_action_btn.visible = false

func _on_action() -> void:
	if _selected == "" or _selected.begins_with("p:") or _selected == "apex":
		return
	if GameConfig.try_buy_skill(_selected):
		_refresh()
		_wheel.refresh()
		_select(_selected)   # обновить текст и кнопку под новое состояние

func _refresh() -> void:
	_sp_label.text = GameConfig.tt("Очки навыков: %d", "Skill points: %d") % GameConfig.skill_points
	_xp_bar.value  = GameConfig.xp
	_xp_label.text = "%d / %d" % [GameConfig.xp, GameConfig.XP_PER_SP]

func _on_close() -> void:
	emit_signal("closed")
	queue_free()

# ── Колесо связей Апекса с ветвями-пассивками ────────────────────────────────
# Внутреннее кольцо — навыки (нити ведут к Апексу в центре), внешнее — их
# ветви-пассивки. Толщина обода = мастерство/уровень; клики — по нодам.
class ApexWheel extends Control:
	const POOL := ["flash", "dash", "sonar", "shield", "guide", "reveal", "pulse", "mirage", "breach", "chrono"]
	const NAMES := {"flash": "Вспышка", "dash": "Рывок", "sonar": "Сонар", "shield": "Щит",
		"guide": "Искра", "reveal": "Озарение", "pulse": "Пульс", "mirage": "Мираж", "breach": "Разлом", "chrono": "Хронос"}
	const NAMES_EN := {"flash": "Flash", "dash": "Dash", "sonar": "Sonar", "shield": "Shield",
		"guide": "Guide", "reveal": "Reveal", "pulse": "Pulse", "mirage": "Mirage", "breach": "Breach", "chrono": "Chrono"}
	func node_name(id: String) -> String:
		return str(NAMES_EN.get(id, id)) if GameConfig.locale == "en" else str(NAMES.get(id, id))
	const R := 140.0          # радиус кольца навыков
	const R2 := 236.0         # радиус кольца пассивок
	const NODE_R := 27.0      # радиус плашки навыка
	const PNODE_R := 19.0     # радиус плашки пассивки
	const APEX_R := 38.0      # радиус центральной плашки Апекса
	var _t: float = 0.0
	var selected: String = ""
	var hovered: String = ""
	var on_select: Callable = Callable()

	func _angle(i: int) -> float:
		return TAU * float(i) / POOL.size() - PI * 0.5

	func _node_pos(i: int) -> Vector2:
		var a := _angle(i)
		return custom_minimum_size * 0.5 + Vector2(cos(a), sin(a)) * R

	func _pnode_pos(i: int) -> Vector2:
		var a := _angle(i)
		return custom_minimum_size * 0.5 + Vector2(cos(a), sin(a)) * R2

	func _ready() -> void:
		mouse_filter = Control.MOUSE_FILTER_IGNORE
		_rebuild()

	# Кликабельная нода с иконкой + подпись. sel_id — что сообщать в on_select.
	func _add_node(pos: Vector2, icon_id: String, sel_id: String, icon_px: int, half: float,
			label_text: String, label_col: Color, label_pos: Vector2, dim: bool) -> void:
		var ic := TextureRect.new()
		ic.texture = SkillIcons.make_hd(icon_id, icon_px)
		ic.stretch_mode = TextureRect.STRETCH_KEEP_CENTERED
		ic.position = pos - Vector2(half, half)
		ic.custom_minimum_size = Vector2(half * 2, half * 2)
		ic.size = Vector2(half * 2, half * 2)   # клик по всей плашке
		ic.mouse_filter = Control.MOUSE_FILTER_STOP
		ic.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
		if dim:
			ic.modulate = Color(0.38, 0.38, 0.46)
		ic.gui_input.connect(func(ev: InputEvent) -> void:
			if ev is InputEventMouseButton and ev.pressed and ev.button_index == MOUSE_BUTTON_LEFT:
				selected = sel_id
				if on_select.is_valid():
					on_select.call(sel_id))
		ic.mouse_entered.connect(func() -> void: hovered = sel_id)
		ic.mouse_exited.connect(func() -> void:
			if hovered == sel_id: hovered = "")
		add_child(ic)

		if label_text != "":
			var nml := Label.new()
			nml.text = label_text
			nml.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
			nml.custom_minimum_size = Vector2(96, 0)
			nml.size = Vector2(96, 16)
			nml.add_theme_font_size_override("font_size", 12)
			nml.add_theme_color_override("font_color", label_col)
			nml.add_theme_constant_override("outline_size", 4)
			nml.add_theme_color_override("font_outline_color", Color(0, 0, 0, 0.85))
			nml.position = label_pos - Vector2(48, 8)
			nml.mouse_filter = Control.MOUSE_FILTER_IGNORE
			add_child(nml)

	func _rebuild() -> void:
		for ch in get_children():
			ch.queue_free()
		var c := custom_minimum_size * 0.5

		# Центральный Апекс
		var apex_dim: bool = not GameConfig.skills_unlocked.get("apex", false)
		_add_node(c, "apex", "apex", 56, 36, "", Color.WHITE, Vector2.ZERO, apex_dim)
		var anml := Label.new()
		anml.text = GameConfig.tt("АПЕКС", "APEX")
		anml.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		anml.custom_minimum_size = Vector2(90, 0)
		anml.size = Vector2(90, 16)
		anml.add_theme_font_size_override("font_size", 13)
		anml.add_theme_color_override("font_color", SkillIcons.color_of("apex"))
		anml.add_theme_constant_override("outline_size", 4)
		anml.add_theme_color_override("font_outline_color", Color(0, 0, 0, 0.85))
		anml.position = c + Vector2(-45, APEX_R + 6)
		anml.mouse_filter = Control.MOUSE_FILTER_IGNORE
		add_child(anml)

		for i in POOL.size():
			var id: String = POOL[i]
			var ang := _angle(i)
			var dir := Vector2(cos(ang), sin(ang))
			var unlocked: bool = GameConfig.skills_unlocked.get(id, false)

			# Нода навыка; подпись — внутри, между Апексом и нодой (боковые —
			# с добавочным горизонтальным сдвигом, чтобы не лезли на плашку)
			var side := clampf((absf(dir.x) - 0.7) / 0.3, 0.0, 1.0)   # только почти-горизонтальные
			var lbl_pos := c + dir * (R - NODE_R - 16.0) - Vector2(dir.x * 26.0 * side, 0)
			_add_node(_node_pos(i), id, id, 40, NODE_R, node_name(id),
				SkillIcons.color_of(id) if unlocked else Color(0.5, 0.52, 0.6),
				lbl_pos, not unlocked)

			# Ветвь-пассивка снаружи; подпись — дальше по радиусу
			var pid: String = GameConfig.SKILL_PASSIVE.get(id, "")
			if pid == "":
				continue
			# Подпись пассивки — строго над нодой (верхняя половина колеса)
			# или под ней (нижняя): радиальное размещение по диагонали ложилось
			# на плашку. Фиксированный вертикальный зазор не пересекается ни с
			# нодой, ни с пипсами уровня.
			var plbl_pos: Vector2
			if dir.y < -0.3:
				plbl_pos = _pnode_pos(i) - Vector2(0, PNODE_R + 16.0)
			else:
				plbl_pos = _pnode_pos(i) + Vector2(0, PNODE_R + 16.0)
			var plvl := GameConfig.passive_level(pid)
			_add_node(_pnode_pos(i), pid, "p:" + pid, 26, PNODE_R, GameConfig.passive_name(pid),
				SkillIcons.color_of(pid) if plvl > 0 else Color(0.5, 0.52, 0.6),
				plbl_pos, plvl == 0)

	# Перестроить после покупки: открывшиеся ноды теряют серость.
	func refresh() -> void:
		_rebuild()

	func _process(delta: float) -> void:
		_t += delta
		queue_redraw()

	func _draw() -> void:
		var c := custom_minimum_size * 0.5
		var top := GameConfig.top_mastered(2)
		var apex_open: bool = GameConfig.skills_unlocked.get("apex", false)

		# Фон: направляющие кольца через центры нод
		draw_arc(c, R, 0, TAU, 96, Color(0.45, 0.55, 0.85, 0.08), 1.5, true)
		draw_arc(c, R2, 0, TAU, 96, Color(0.65, 0.5, 0.9, 0.06), 1.2, true)

		# ── Нити мастерства (под плашками) ──
		for i in POOL.size():
			var id: String = POOL[i]
			var p := _node_pos(i)
			var dir := (p - c).normalized()
			var a_from := p - dir * NODE_R          # от края плашки
			var a_to := c + dir * APEX_R            # до края плашки Апекса
			var col: Color = SkillIcons.color_of(id)
			var m := GameConfig.mastery(id)
			var width := 1.0 + float(m) * 1.1
			var alpha := 0.10 + 0.13 * float(m)
			if apex_open and id == top[0]:
				alpha = 0.65 + 0.35 * (0.5 + 0.5 * sin(_t * 4.0))
				width += 2.0
				# бегущая искра — «энергия течёт в Апекс»
				var k := fmod(_t * 0.6, 1.0)
				draw_circle(a_from.lerp(a_to, k), 3.5, Color(col.r, col.g, col.b, 0.9))
			elif apex_open and top.size() > 1 and id == top[1]:
				alpha = 0.4 + 0.2 * (0.5 + 0.5 * sin(_t * 4.0 + 1.5))
				width += 1.0
			if not GameConfig.skills_unlocked.get(id, false):
				alpha = 0.05
			draw_line(a_from, a_to, Color(col.r, col.g, col.b, alpha), width, true)

			# ── Ветвь к пассивке (наружу) ──
			var pid: String = GameConfig.SKILL_PASSIVE.get(id, "")
			if pid != "":
				var pp := _pnode_pos(i)
				var plvl := GameConfig.passive_level(pid)
				var pcol: Color = SkillIcons.color_of(pid)
				var b_from := p + dir * NODE_R
				var b_to := pp - dir * PNODE_R
				var b_alpha := 0.08 + 0.14 * float(plvl)
				var b_width := 1.0 + float(plvl) * 0.8
				draw_line(b_from, b_to, Color(pcol.r, pcol.g, pcol.b, b_alpha), b_width, true)
				if plvl > 0:
					# искра течёт из пассивки в навык — «ветвь кормит навык»
					var bk := fmod(_t * 0.45 + float(i) * 0.13, 1.0)
					draw_circle(b_to.lerp(b_from, bk), 2.2, Color(pcol.r, pcol.g, pcol.b, 0.6))

		# ── Плашки нод навыков: тёмный диск + цветной обод (толще = мастерство) ──
		var font := ThemeDB.fallback_font
		for i in POOL.size():
			var id: String = POOL[i]
			var p := _node_pos(i)
			var col: Color = SkillIcons.color_of(id)
			var unlocked: bool = GameConfig.skills_unlocked.get(id, false)
			var m := GameConfig.mastery(id)
			draw_circle(p, NODE_R, Color(0.05, 0.06, 0.11, 0.96))
			var ring_col := Color(col.r, col.g, col.b, 0.85) if unlocked else Color(0.32, 0.34, 0.42, 0.7)
			draw_arc(p, NODE_R - 1.0, 0, TAU, 48, ring_col, 1.5 + float(m) * 0.7, true)
			if hovered == id and selected != id:
				draw_arc(p, NODE_R + 3.0, 0, TAU, 48, Color(col.r, col.g, col.b, 0.45), 1.5, true)

			# ── Доступные действия — читаются с одного взгляда ──
			# ЗОЛОТОЕ пульсирующее кольцо + цена: навык можно ОТКРЫТЬ за SP.
			# ЗЕЛЁНОЕ кольцо + стрелка вверх: открытый навык можно УСИЛИТЬ (+1★).
			var is_gift: bool = id in ["mirage", "breach", "chrono"]
			var cost := int(GameConfig.SKILL_COSTS.get(id, 999))
			var pulse := 0.55 + 0.45 * sin(_t * 5.0 + float(i))
			if not unlocked and not is_gift and GameConfig.skill_points >= cost:
				draw_arc(p, NODE_R + 5.0, 0, TAU, 48, Color(1.0, 0.85, 0.3, 0.35 + 0.4 * pulse), 2.5, true)
				var tag := "%d SP" % cost
				var tp := p + Vector2(NODE_R * 0.35, -NODE_R - 8.0)
				draw_string_outline(font, tp, tag, HORIZONTAL_ALIGNMENT_LEFT, -1, 12, 4, Color(0, 0, 0, 0.9))
				draw_string(font, tp, tag, HORIZONTAL_ALIGNMENT_LEFT, -1, 12, Color(1.0, 0.85, 0.3))
			elif unlocked and m < GameConfig.MASTERY_MAX and GameConfig.skill_points >= GameConfig.upgrade_cost(id):
				draw_arc(p, NODE_R + 5.0, 0, TAU, 48, Color(0.4, 1.0, 0.55, 0.30 + 0.35 * pulse), 2.0, true)
				# Стрелка-«апгрейд» у верхнего края плашки
				var ap := p + Vector2(NODE_R * 0.85, -NODE_R * 0.85)
				draw_colored_polygon(PackedVector2Array([
					ap + Vector2(0, -7), ap + Vector2(6, 3), ap + Vector2(-6, 3)]),
					Color(0.4, 1.0, 0.55, 0.65 + 0.35 * pulse))
			# Пипсы мастерства — дужка из точек по нижнему краю обода
			if unlocked and m > 0:
				for k in m:
					var pang := PI * 0.5 + (float(k) - float(m - 1) * 0.5) * 0.32
					var ppp := p + Vector2(cos(pang), sin(pang)) * (NODE_R + 5.0)
					draw_circle(ppp, 2.4, Color(1.0, 0.85, 0.3, 0.95))

		# ── Плашки пассивок ──
		for i in POOL.size():
			var id: String = POOL[i]
			var pid: String = GameConfig.SKILL_PASSIVE.get(id, "")
			if pid == "":
				continue
			var pp := _pnode_pos(i)
			var pcol: Color = SkillIcons.color_of(pid)
			var plvl := GameConfig.passive_level(pid)
			draw_circle(pp, PNODE_R, Color(0.05, 0.06, 0.11, 0.96))
			var pring := Color(pcol.r, pcol.g, pcol.b, 0.8) if plvl > 0 else Color(0.32, 0.34, 0.42, 0.7)
			draw_arc(pp, PNODE_R - 1.0, 0, TAU, 40, pring, 1.2 + float(plvl) * 0.6, true)
			var sel_id := "p:" + pid
			if hovered == sel_id and selected != sel_id:
				draw_arc(pp, PNODE_R + 3.0, 0, TAU, 40, Color(pcol.r, pcol.g, pcol.b, 0.45), 1.5, true)
			if plvl > 0:
				for k in plvl:
					var pang := PI * 0.5 + (float(k) - float(plvl - 1) * 0.5) * 0.36
					var dp := pp + Vector2(cos(pang), sin(pang)) * (PNODE_R + 4.0)
					draw_circle(dp, 1.9, Color(1.0, 0.85, 0.3, 0.95))

		# ── Плашка Апекса ──
		var apex_col := SkillIcons.color_of("apex")
		draw_circle(c, APEX_R, Color(0.07, 0.05, 0.10, 0.97))
		draw_arc(c, APEX_R - 1.0, 0, TAU, 64, Color(apex_col.r, apex_col.g, apex_col.b, 0.9 if apex_open else 0.35), 2.0, true)
		if apex_open:
			# Дышащий ореол в цвет текущей формы
			var fc: Color = SkillIcons.color_of(top[0])
			draw_arc(c, APEX_R + 5.0 + 2.0 * sin(_t * 3.0), 0, TAU, 64, Color(fc.r, fc.g, fc.b, 0.5), 2.0, true)
		if hovered == "apex" and selected != "apex":
			draw_arc(c, APEX_R + 3.0, 0, TAU, 64, Color(apex_col.r, apex_col.g, apex_col.b, 0.45), 1.5, true)

		# ── Кольцо выделения выбранного ──
		if selected == "apex":
			draw_arc(c, APEX_R + 4.0 + 1.5 * sin(_t * 5.0), 0, TAU, 64, Color(1.0, 0.35, 0.4, 0.95), 2.5, true)
		elif selected.begins_with("p:"):
			var spid := selected.substr(2)
			for i in POOL.size():
				if str(GameConfig.SKILL_PASSIVE.get(POOL[i], "")) == spid:
					var spp := _pnode_pos(i)
					var scol: Color = SkillIcons.color_of(spid)
					draw_arc(spp, PNODE_R + 4.0 + 1.5 * sin(_t * 5.0), 0, TAU, 40, Color(scol.r, scol.g, scol.b, 0.95), 2.5, true)
					break
		elif selected != "" and selected in POOL:
			var sp := _node_pos(POOL.find(selected))
			var scol2: Color = SkillIcons.color_of(selected)
			draw_arc(sp, NODE_R + 4.0 + 1.5 * sin(_t * 5.0), 0, TAU, 48, Color(scol2.r, scol2.g, scol2.b, 0.95), 2.5, true)

# ── Колесо ПРИЗЫВА (GAMEDESIGN.md §25) ──────────────────────────────────────
# Тот же общий приём, что у ApexWheel выше (хаб в центре + узлы-навыки по
# кольцу, клик — колбэк on_select), но заметно проще: без ветвей-пассивок и
# мастерства-звёзд — навыков призыва пока один, и что именно у них будет
# «прокачкой» ещё не решено (см. GAMEDESIGN.md §25 «остаётся решить»).
# Растёт так же, как Апекс когда-то рос от одного навыка: дописать id в
# POOL + имя/иконку/тон ниже — новый узел встанет в кольцо сам.
class SummonWheel extends Control:
	const POOL := ["mirror_ally"]
	const NAMES := {"mirror_ally": "Зеркальный союзник"}
	const NAMES_EN := {"mirror_ally": "Mirror Ally"}
	const TINTS := {"mirror_ally": Color(0.55, 1.0, 0.65)}
	const R := 130.0
	const NODE_R := 32.0
	const HUB_R := 38.0
	var _t: float = 0.0
	var selected: String = ""
	var hovered: String = ""
	var on_select: Callable = Callable()

	func node_name(id: String) -> String:
		return str(NAMES_EN.get(id, id)) if GameConfig.locale == "en" else str(NAMES.get(id, id))

	func _tint(id: String) -> Color:
		return TINTS.get(id, Color(0.6, 0.85, 1.0))

	func _angle(i: int) -> float:
		return TAU * float(i) / maxf(float(POOL.size()), 1.0) - PI * 0.5

	func _node_pos(i: int) -> Vector2:
		var a := _angle(i)
		return custom_minimum_size * 0.5 + Vector2(cos(a), sin(a)) * R

	func _ready() -> void:
		mouse_filter = Control.MOUSE_FILTER_IGNORE
		_rebuild()
		set_process(true)

	func _process(delta: float) -> void:
		_t += delta
		queue_redraw()

	func _icon_for(id: String) -> Texture2D:
		match id:
			"mirror_ally":
				return MazeTextures.make_player_orb(15)
			_:
				return MazeTextures.make_light(40)

	func _add_node(pos: Vector2, id: String, radius: float, label_text: String, label_col: Color, dim: bool) -> void:
		var area := Control.new()
		area.position = pos - Vector2(radius, radius)
		area.custom_minimum_size = Vector2(radius * 2, radius * 2)
		area.size = Vector2(radius * 2, radius * 2)
		area.mouse_filter = Control.MOUSE_FILTER_STOP
		area.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
		area.gui_input.connect(func(ev: InputEvent) -> void:
			if ev is InputEventMouseButton and ev.pressed and ev.button_index == MOUSE_BUTTON_LEFT:
				selected = id
				if on_select.is_valid():
					on_select.call(id))
		area.mouse_entered.connect(func() -> void: hovered = id)
		area.mouse_exited.connect(func() -> void:
			if hovered == id: hovered = "")
		add_child(area)

		if id != "hub":
			var ic := TextureRect.new()
			ic.texture = _icon_for(id)
			ic.stretch_mode = TextureRect.STRETCH_KEEP_CENTERED
			ic.custom_minimum_size = Vector2(radius * 2, radius * 2)
			ic.size = Vector2(radius * 2, radius * 2)
			ic.mouse_filter = Control.MOUSE_FILTER_IGNORE
			if dim:
				ic.modulate = Color(0.4, 0.4, 0.46)
			area.add_child(ic)

		if label_text != "":
			var lbl := Label.new()
			lbl.text = label_text
			lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
			lbl.custom_minimum_size = Vector2(110, 0)
			lbl.size = Vector2(110, 16)
			lbl.add_theme_font_size_override("font_size", 12)
			lbl.add_theme_color_override("font_color", label_col)
			lbl.add_theme_constant_override("outline_size", 4)
			lbl.add_theme_color_override("font_outline_color", Color(0, 0, 0, 0.85))
			lbl.position = pos - Vector2(55, -(radius + 8))
			lbl.mouse_filter = Control.MOUSE_FILTER_IGNORE
			add_child(lbl)

	func _rebuild() -> void:
		for ch in get_children():
			ch.queue_free()
		var c: Vector2 = custom_minimum_size * 0.5
		_add_node(c, "hub", HUB_R, GameConfig.tt("ПРИЗЫВ", "SUMMON"), Color(0.55, 1.0, 0.65), false)
		for i in POOL.size():
			var id: String = POOL[i]
			var owned: bool = GameConfig.summon_unlocked.get(id, false)
			_add_node(_node_pos(i), id, NODE_R, node_name(id), _tint(id) if owned else Color(0.5, 0.52, 0.6), not owned)

	func _draw() -> void:
		var c: Vector2 = custom_minimum_size * 0.5
		for i in POOL.size():
			var id: String = POOL[i]
			var owned: bool = GameConfig.summon_unlocked.get(id, false)
			var tint := _tint(id)
			draw_line(c, _node_pos(i), Color(tint.r, tint.g, tint.b, 0.35 if owned else 0.15), 2.0)

		draw_circle(c, HUB_R, Color(0.05, 0.08, 0.06, 0.97))
		draw_arc(c, HUB_R - 1.0, 0, TAU, 48, Color(0.55, 1.0, 0.65, 0.85), 2.0, true)
		if hovered == "hub" and selected != "hub":
			draw_arc(c, HUB_R + 3.0, 0, TAU, 48, Color(0.55, 1.0, 0.65, 0.4), 1.5, true)

		for i in POOL.size():
			var id: String = POOL[i]
			var np := _node_pos(i)
			var owned: bool = GameConfig.summon_unlocked.get(id, false)
			var tint := _tint(id)
			draw_circle(np, NODE_R, Color(0.05, 0.06, 0.09, 0.97))
			var ring_col := Color(tint.r, tint.g, tint.b, 0.9) if owned else Color(0.32, 0.34, 0.42, 0.7)
			var ring_w := 2.2 + float(GameConfig.mastery(id)) * 0.9 if owned else 2.2   # толще = выше ★
			draw_arc(np, NODE_R - 1.0, 0, TAU, 40, ring_col, ring_w, true)
			if hovered == id and selected != id:
				draw_arc(np, NODE_R + 3.0, 0, TAU, 40, Color(tint.r, tint.g, tint.b, 0.45), 1.5, true)
			if selected == id:
				draw_arc(np, NODE_R + 4.0 + 1.5 * sin(_t * 5.0), 0, TAU, 40, Color(1.0, 0.35, 0.4, 0.95), 2.5, true)
