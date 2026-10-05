extends Control

# Главное меню: Играть / Настройки / Выход.
# Настройки правят синглтон GameConfig, который читает игра.

var _menu_box: VBoxContainer
var _settings_box: VBoxContainer
var _settings_scroll: ScrollContainer
var _level_box: ScrollContainer
var _level_inner: VBoxContainer
var _level_grid: GridContainer
var _boss_section: VBoxContainer  # секция тест-боссов в выборе уровней

# Режим «Логово»: выбор одного из 10 уровней с боссом в центре лабиринта.
var _lair_box: ScrollContainer
var _lair_grid: GridContainer
var _caves_box: ScrollContainer
var _tutorial_box: ScrollContainer     # [v6.3] список уроков обучения
var _tutorial_grid: GridContainer
var _caves_grid: GridContainer
# [CODEX §30] Кодекс — двухколоночный экран вместо прежней карусели слайдов
# Справки: слева навигация (разделы и статьи), справа сама статья с картинкой.
# Данные статей — в codex.gd, здесь только UI и сборка картинок.
var _codex_root: HBoxContainer      # корень экрана (скрыт, пока не открыт)
var _codex_nav: ScrollContainer     # левая колонка со списком статей
var _codex_nav_box: VBoxContainer
var _codex_article: ScrollContainer # правая колонка — тело статьи
var _codex_open_sec: String = "start"   # [v5.1] раскрытый раздел навигации (ровно один)
var _codex_body: VBoxContainer
var _codex_entries: Array = []      # плоский список статей (данные + версии)
var _codex_buttons: Array = []      # кнопки навигации, индекс = индекс статьи
var _codex_idx: int = -1

# [CAROUSEL-BOUNDS] Обёртки-ScrollContainer карточек каруселей — высоту им
# считает _fit_carousel (по контенту, но не выше окна).
var _root_col: VBoxContainer       # центрированная колонка всей страницы меню
var _journal_slide_scroll: ScrollContainer
var _bestiary_slide_scroll: ScrollContainer
var _back_btn: Button

# Режим «Накал»: панель выбора слота-забега и брифинг.
# Оба — ScrollContainer (не голый VBoxContainer): на низких окнах список
# слотов/текст брифинга длиннее экрана, а CenterContainer центрирует
# несворачиваемый контент — верх и низ (в т.ч. кнопка «Назад») уезжают за
# кадр (см. жалобу «кнопки за пределами экрана» — та же причина, что была
# у settings/help/journal, отсюда и общий приём с _fit_panels()).
var _runs_box: ScrollContainer
var _runs_slots_box: VBoxContainer
var _briefing_box: ScrollContainer
var _briefing_slot: int = 0
var _briefing_contracts_box: VBoxContainer
var _briefing_contract: String = ""   # выбранный контракт спуска ("" — без)

# [JOURNAL-CAROUSEL] Дневник лабиринта — карусель слайдов (тот же паттерн,
# что у Кодекса: раньше был один длинный скролл из 8
# текстовых панелей подряд — чтобы увидеть общую картину, нужно было долго
# скроллить, и цифры/инфографика тонули в тексте. Теперь один слайд = один
# самодостаточный визуальный раздел. _journal_scroll — внешняя обёртка
# (заголовок + стрелки), _journal_box — контейнер ТЕКУЩЕГО
# слайда. Состав и число слайдов зависят от прогресса игрока
# («Путь к навыкам»/«Спуск дня» не показываются, если там нечего показывать),
# поэтому список пересобирается при каждом открытии — см. _journal_rebuild_slides.
var _journal_scroll: VBoxContainer
var _journal_box: VBoxContainer
var _journal_nav_label: Label
var _journal_prev_btn: Button
var _journal_next_btn: Button
var _journal_slide_idx: int = 0
var _journal_slides: Array = []   # [{title:String, build:Callable}]

# Спуск дня: ежедневный забег с сидом от даты, одна попытка в день.
var _daily_box: ScrollContainer
var _daily_inner: VBoxContainer

# [BESTIARY-CAROUSEL] Бестиарий «Досье лабиринта» — карусель слайдов (тот же
# паттерн, что у Дневника): раньше один длинный скролл (шапка + угроза
# + 6 карточек врагов подряд) тонул в тексте. Теперь один слайд = «Текущая
# угроза» + по одному слайду на каждого врага, крупнее и просторнее.
var _bestiary_scroll: VBoxContainer
var _bestiary_box: VBoxContainer
var _bestiary_nav_label: Label
var _bestiary_prev_btn: Button
var _bestiary_next_btn: Button
var _bestiary_slide_idx: int = 0
var _bestiary_slides: Array = []   # [{title:String, build:Callable}]

# Выбор режима после «Играть»: Уровни (продолжить/выбрать) или Накал.
var _mode_scroll: ScrollContainer
var _mode_box: VBoxContainer

const LEVEL_COUNT := 50
const SETTINGS_W := 560   # единая ширина строк в настройках



var _unlock_baseline: int = 1  # честный прогресс, чтобы вернуть его при выключении переключателя

var _title: Label
# [CODEX §30] Узлы шапки. На экране Кодекса они скрываются: это единственный
# экран для ЧТЕНИЯ, и 300px неонового логотипа отбирали у статьи почти
# половину доступной высоты. На остальных экранах шапка остаётся как была.
var _header_title: CenterContainer
var _header_sub: Label
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
	# [CAROUSEL-BOUNDS] Вся страница меню — ОДНА центрированная колонка, поэтому
	# «влезает ли экран» = «высота этой колонки ≤ высоты окна». Держим ссылку,
	# чтобы _fit_carousel считал доступное место по факту, а не по угаданной
	# константе-запасу (именно такая угаданная константа и протухла).
	_root_col = root

	# Неоновый заголовок с ореолом
	var title_wrap := CenterContainer.new()
	_header_title = title_wrap
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
	_header_sub = subtitle
	subtitle.text = GameConfig.t("subtitle")
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
	_build_bestiary(root)
	_build_daily(root)
	_build_level_select(root)
	_build_lair_select(root)
	_build_caves_select(root)
	_build_tutorial_select(root)
	_build_settings(root)
	_build_codex(root)

	# Прокручиваемые панели не должны быть выше экрана: иначе CenterContainer
	# центрирует их и верх/низ (в т.ч. кнопка «Назад») уезжают за кадр.
	_fit_panels()
	get_viewport().size_changed.connect(_fit_panels)

	# Постоянная «← Назад» сверху-слева: видна в любом подразделе и не зависит от
	# прокрутки (раньше кнопка «Назад» терялась внизу длинного скролла).
	_back_btn = Button.new()
	_back_btn.text = GameConfig.t("back_arrow")
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

	# После обучения — сразу открыть экран «Играть», а не корневое меню:
	# игрок только что закончил обучение и логично ведёт его к выбору режима.
	if GameConfig.open_mode_on_start:
		GameConfig.open_mode_on_start = false
		_on_open_mode()

func _unhandled_input(event: InputEvent) -> void:
	if event is InputEventKey and event.pressed and not event.echo and event.keycode == KEY_ESCAPE:
		if _back_btn and _back_btn.visible:
			_go_back()
			get_viewport().set_input_as_handled()

# Спрятать ВСЕ панели (включая корневое меню). Каждый _on_open_* обязан звать
# это перед показом своей панели: панели — соседи в одной колонке, и забытая
# видимая панель выталкивает новую за край экрана («кнопка не работает»).
# Компактный режим шапки: логотип и подзаголовок прячутся, освобождая высоту
# под длинный текст. Включается только Кодексом, снимается любым уходом с него.
func _set_header_compact(on: bool) -> void:
	if _header_title:
		_header_title.visible = not on
	if _header_sub:
		_header_sub.visible = not on

func _hide_all_panels() -> void:
	_set_header_compact(false)
	_menu_box.visible = false
	_level_box.visible = false
	if _lair_box:
		_lair_box.visible = false
	if _caves_box:
		_caves_box.visible = false
	if _tutorial_box:
		_tutorial_box.visible = false
	_settings_scroll.visible = false
	if _codex_root:
		_codex_root.visible = false
	_runs_box.visible = false
	_briefing_box.visible = false
	_journal_scroll.visible = false
	if _bestiary_scroll:
		_bestiary_scroll.visible = false
	if _daily_box:
		_daily_box.visible = false
	if _mode_scroll:
		_mode_scroll.visible = false

# Единая точка возврата (кнопка сверху-слева, Esc и нижние «Назад»).
# Иерархия: брифинг → слоты Накала; подпанели «Играть» (слоты, выбор уровня,
# спуск дня, дневник) → экран режимов; остальное → корневое меню.
func _go_back() -> void:
	GameConfig.codex_flush()   # [v5.1.1] отметки «прочитано» — одной пачкой на выходе
	if _briefing_box and _briefing_box.visible:
		_on_briefing_back()
		return
	var from_mode_child: bool = _runs_box.visible or _level_box.visible \
		or (_lair_box != null and _lair_box.visible) \
		or (_caves_box != null and _caves_box.visible) \
		or (_tutorial_box != null and _tutorial_box.visible) \
		or _journal_scroll.visible \
		or (_bestiary_scroll != null and _bestiary_scroll.visible) \
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
	# [CAROUSEL-BOUNDS] Колонки Кодекса и карточки Дневника/Бестиария тоже
	# обязаны влезать в окно — раньше они были исключены отсюда «потому что
	# фиксированные», и это дало ровно тот баг, ради которого правило и
	# существует: слайды уезжали за нижний край. См. _fit_carousel.
	_fit_codex()
	_fit_carousel(_journal_slide_scroll, _journal_box)
	_fit_carousel(_bestiary_slide_scroll, _bestiary_box)
	if _mode_scroll:
		_mode_scroll.custom_minimum_size.y = min(520.0, avail)
	if _runs_box:
		_runs_box.custom_minimum_size.y = min(480.0, avail)
	if _briefing_box:
		_briefing_box.custom_minimum_size.y = min(480.0, avail)
	if _level_box:
		_level_box.custom_minimum_size.y = min(480.0, avail)
	if _lair_box:
		_lair_box.custom_minimum_size.y = min(480.0, avail)
	if _caves_box:
		_caves_box.custom_minimum_size.y = min(480.0, avail)
	if _tutorial_box:
		_tutorial_box.custom_minimum_size.y = min(480.0, avail)
	if _daily_box:
		_daily_box.custom_minimum_size.y = min(480.0, avail)

# [CAROUSEL-BOUNDS] Общая обёртка слайда карусели. Решает СРАЗУ две прошлые
# жалобы, которые тянули в разные стороны:
#   • «фиксированная коробка с вечной полосой прокрутки — дыра, а не карточка»
#     (Дневник, 06.07.2026) — отсюда высота ПО КОНТЕНТУ, пока он влезает;
#   • «слайды не целые / уезжают за экран» (Кодекс и Дневник) — отсюда
#     жёсткий потолок по высоте окна и прокрутка, когда контент выше.
# Ширина зафиксирована ВСЕГДА, и место под вертикальную полосу зарезервировано
# в самом контенте — иначе появление полосы на «длинном» слайде сужало бы текст
# и стрелки прыгали бы между слайдами (тот же урок, что был у Справки про
# SCROLL_MODE_AUTO).
func _carousel_slide_scroll(width: int) -> ScrollContainer:
	var sc := ScrollContainer.new()
	sc.custom_minimum_size = Vector2(width, 0)
	sc.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	sc.vertical_scroll_mode = ScrollContainer.SCROLL_MODE_AUTO
	return sc

# Ширина контента внутри карусельной карточки с учётом зарезервированной полосы.
func _carousel_content_width(sc: ScrollContainer, width: int) -> int:
	var bar := sc.get_v_scroll_bar()
	var bw: int = int(bar.get_combined_minimum_size().x) if bar else 12
	return maxi(width - maxi(bw, 12), 100)

# Высота карточки = сколько реально нужно слайду, но не выше того, что влезает
# в окно. Зовётся после КАЖДОЙ перерисовки слайда и из _fit_panels (ресайз).
func _fit_carousel(sc: ScrollContainer, box: Control) -> void:
	if sc == null or box == null or not is_instance_valid(sc) or not is_instance_valid(box):
		return
	if not sc.visible or not sc.is_visible_in_tree():
		return
	var vh: float = get_viewport().get_visible_rect().size.y
	# Сколько занимает ВСЁ остальное в колонке (заголовок MAZE, подзаголовок,
	# имя экрана, счётчик страниц, кнопки, поля карточки) — измеряем, а не
	# угадываем: высота карточки здесь единственная переменная величина.
	var avail: float = vh - 32.0
	if _root_col and is_instance_valid(_root_col) and _root_col.size.y > 0.0 and sc.size.y > 0.0:
		avail = vh - 32.0 - (_root_col.size.y - sc.size.y)
	else:
		avail -= 320.0
	avail = maxf(avail, 200.0)
	var needed: float = box.get_combined_minimum_size().y
	sc.custom_minimum_size.y = min(needed, avail)

func _build_menu(root: VBoxContainer) -> void:
	_menu_box = VBoxContainer.new()
	_menu_box.add_theme_constant_override("separation", 12)
	root.add_child(_menu_box)

	_menu_box.add_child(_make_button(GameConfig.t("menu_play"), _on_open_mode))
	_menu_box.add_child(_make_button(GameConfig.t("menu_settings"), _on_open_settings))
	_codex_menu_btn = _make_button(GameConfig.t("menu_help"), _on_open_codex)
	_menu_box.add_child(_codex_menu_btn)
	_refresh_codex_badge()
	_menu_box.add_child(_make_button(GameConfig.t("menu_quit"), _on_quit))

func _build_settings(root: VBoxContainer) -> void:
	_settings_scroll = ScrollContainer.new()
	_settings_scroll.visible = false
	_settings_scroll.custom_minimum_size = Vector2(620, 480)
	_settings_scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	root.add_child(_settings_scroll)

	_settings_box = VBoxContainer.new()
	_settings_box.add_theme_constant_override("separation", 10)
	_settings_scroll.add_child(_settings_box)

	# Единая сетка: секции с заголовками, все строки одной ширины (560),
	# подписи слева, значения справа — ровная левая кромка по всей колонке.

	# Профиль (v1.9): несколько игроков на одной машине, у каждого свой
	# полностью отдельный сейв (прогресс, настройки, статистика). Сброс
	# прогресса ниже трогает только ЭТОГО, текущего, игрока.
	_settings_section(GameConfig.tt("Профиль", "Profile"), Color(0.5, 0.8, 1.0))
	var prof_row := HBoxContainer.new()
	prof_row.custom_minimum_size = Vector2(SETTINGS_W, 0)
	prof_row.add_theme_constant_override("separation", 10)
	_settings_box.add_child(prof_row)
	var prof_lbl := Label.new()
	prof_lbl.text = GameConfig.tt("Игрок: %s", "Player: %s") % GameConfig.profile_name
	prof_lbl.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	prof_lbl.add_theme_font_size_override("font_size", 18)
	prof_row.add_child(prof_lbl)
	var prof_btn := Button.new()
	prof_btn.text = GameConfig.tt("Сменить игрока", "Switch player")
	prof_btn.custom_minimum_size = Vector2(190, 36)
	prof_btn.add_theme_font_size_override("font_size", 14)
	_style_button(prof_btn)
	prof_btn.pressed.connect(_show_profile_switcher)
	prof_row.add_child(prof_btn)

	_settings_section(GameConfig.t("settings_sound"), Color(0.5, 0.8, 1.0))
	_add_volume_slider(GameConfig.t("vol_music"), GameConfig.music_volume, func(v: float) -> void:
		GameConfig.music_volume = v
		GameConfig.apply_volumes()
		GameConfig.save_game())
	_add_volume_slider(GameConfig.t("vol_sfx"), GameConfig.sfx_volume, func(v: float) -> void:
		GameConfig.sfx_volume = v
		GameConfig.apply_volumes()
		GameConfig.save_game())

	_settings_section(GameConfig.t("settings_screen"), Color(0.5, 0.8, 1.0))
	_settings_check(GameConfig.t("fullscreen"), GameConfig.fullscreen, func(on: bool) -> void:
		GameConfig.fullscreen = on
		GameConfig.apply_display()
		GameConfig.save_game())

	var res_row := HBoxContainer.new()
	res_row.custom_minimum_size = Vector2(SETTINGS_W, 0)
	res_row.add_theme_constant_override("separation", 10)
	_settings_box.add_child(res_row)
	var res_lbl := Label.new()
	res_lbl.text = GameConfig.t("resolution")
	res_lbl.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	res_lbl.add_theme_font_size_override("font_size", 18)
	res_row.add_child(res_lbl)
	var res_opt := OptionButton.new()
	UIStyle.style_button(res_opt)   # [AUDIT 05.10.2026 №7] конвенция: все кнопки через UIStyle
	for r in GameConfig.RESOLUTIONS:
		res_opt.add_item("%d × %d" % [r.x, r.y])
	res_opt.selected = GameConfig.resolution_idx
	res_opt.add_theme_font_size_override("font_size", 16)
	res_opt.item_selected.connect(func(i: int) -> void:
		GameConfig.resolution_idx = i
		GameConfig.apply_display()
		GameConfig.save_game())
	res_row.add_child(res_opt)

	_settings_check(GameConfig.t("vsync"), GameConfig.vsync, func(on: bool) -> void:
		GameConfig.vsync = on
		GameConfig.apply_display()
		GameConfig.save_game())
	_settings_option(GameConfig.t("fps_cap"), [str(60), str(120), str(144), GameConfig.tt("Без лимита", "Unlimited")],
		maxi(GameConfig.FPS_CAPS.find(GameConfig.fps_cap), 0), func(i: int) -> void:
			GameConfig.fps_cap = int(GameConfig.FPS_CAPS[i])
			GameConfig.apply_display()
			GameConfig.save_game())
	_settings_option(GameConfig.tt("Цвета", "Colors"), [GameConfig.tt("Стандарт", "Standard"), GameConfig.tt("Мягкий", "Soft"), GameConfig.tt("Минимальный", "Minimal")],
		GameConfig.color_preset, func(i: int) -> void:
			GameConfig.color_preset = i
			GameConfig.apply_color_preset()
			GameConfig.save_game())
	_settings_option(GameConfig.t("quality"), [GameConfig.tt("Низкое", "Low"), GameConfig.tt("Среднее", "Medium"), GameConfig.tt("Высокое", "High")],
		GameConfig.quality, func(i: int) -> void:
			GameConfig.quality = i
			GameConfig.save_game()
			_toast(GameConfig.tt("Качество применится с нового уровня", "Quality applies from the next level")))

	_settings_section(GameConfig.t("settings_game"), Color(0.5, 0.8, 1.0))
	_settings_check(GameConfig.t("hints_opt"), GameConfig.show_hints, func(on: bool) -> void:
		GameConfig.show_hints = on
		GameConfig.save_game())
	_settings_check(GameConfig.t("beacon_pulse_opt"), GameConfig.beacon_pulse, func(on: bool) -> void:
		GameConfig.beacon_pulse = on
		GameConfig.save_game())
	_settings_check(GameConfig.t("show_fps_opt"), GameConfig.show_fps, func(on: bool) -> void:
		GameConfig.show_fps = on
		GameConfig.save_game())
	_settings_check(GameConfig.tt("Эхо времени (следы прошлого забега)", "Echo of Time (footprints from your last run)"),
		GameConfig.echo_time_enabled, func(on: bool) -> void:
			GameConfig.echo_time_enabled = on
			GameConfig.save_game())

	# Язык интерфейса: два переключаемых радио-кнопки. Меняет только основной
	# UI (меню/HUD/настройки/справка) — лор и голос лабиринта пока по-русски.
	var lang_row := HBoxContainer.new()
	lang_row.custom_minimum_size = Vector2(SETTINGS_W, 0)
	lang_row.add_theme_constant_override("separation", 10)
	_settings_box.add_child(lang_row)
	var lang_lbl := Label.new()
	lang_lbl.text = GameConfig.t("language")
	lang_lbl.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	lang_lbl.add_theme_font_size_override("font_size", 18)
	lang_row.add_child(lang_lbl)
	var lang_btns: Array = []
	for code in ["ru", "en"]:
		var lb := Button.new()
		lb.text = "Русский" if code == "ru" else "English"
		lb.toggle_mode = true
		lb.button_pressed = GameConfig.locale == code
		lb.custom_minimum_size = Vector2(110, 36)
		lb.add_theme_font_size_override("font_size", 15)
		_style_button(lb)
		lang_btns.append(lb)
		var c: String = code
		lb.pressed.connect(func() -> void:
			if GameConfig.locale == c:
				return
			GameConfig.locale = c
			GameConfig.save_game()
			# Перестраиваем меню целиком — большинство подписей строится один
			# раз в _ready(), «на лету» без перезагрузки сцены не обновится.
			get_tree().reload_current_scene()
		)
		lang_row.add_child(lb)

	_settings_section(GameConfig.tt("⚙ Сложность — тонкая настройка", "⚙ Difficulty — fine tuning"), Color(1.0, 0.85, 0.35))
	var tune_hint := Label.new()
	tune_hint.text = GameConfig.tt(
		"Множители поверх обычного баланса; ×1.00 — как задумано.\nДействуют сразу, на текущем уровне. Официальные сложности (Тлеющий/Горящий/Пылающий) работают поверх этих множителей.",
		"Multipliers on top of the regular balance; ×1.00 — as designed.\nApplied at once, on the current level. The official difficulties (Ember/Blaze/Inferno) stack on top of these.")
	tune_hint.custom_minimum_size = Vector2(SETTINGS_W, 0)
	tune_hint.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	tune_hint.add_theme_font_size_override("font_size", 13)
	tune_hint.add_theme_color_override("font_color", Color(0.6, 0.62, 0.68))
	_settings_box.add_child(tune_hint)
	_add_tune_slider(GameConfig.tt("Дальность видимости", "Light range"),
		GameConfig.tune_light_scale, func(v: float) -> void: GameConfig.tune_light_scale = v)
	_add_tune_slider(GameConfig.tt("Расход Света", "Light drain"),
		GameConfig.tune_drain, func(v: float) -> void: GameConfig.tune_drain = v)
	_add_tune_slider(GameConfig.tt("Скорость игрока", "Player speed"),
		GameConfig.tune_player_speed, func(v: float) -> void: GameConfig.tune_player_speed = v)
	_add_tune_slider(GameConfig.tt("Скорость врагов", "Enemy speed"),
		GameConfig.tune_enemy_speed, func(v: float) -> void: GameConfig.tune_enemy_speed = v)
	_add_tune_slider(GameConfig.tt("Регенерация Воли", "Will regeneration"),
		GameConfig.tune_will_regen, func(v: float) -> void: GameConfig.tune_will_regen = v)
	_add_tune_slider(GameConfig.tt("Длительность Озарения", "Reveal duration"),
		GameConfig.tune_reveal_dur, func(v: float) -> void: GameConfig.tune_reveal_dur = v)
	_add_tune_slider(GameConfig.tt("Заметность для врагов", "Visibility to enemies"),
		GameConfig.tune_visibility, func(v: float) -> void: GameConfig.tune_visibility = v)
	var tune_reset := UIStyle.make_button(GameConfig.tt("Сбросить всё в ×1.00", "Reset all to ×1.00"), func() -> void:
		for k in GameConfig.TUNE_KEYS:
			GameConfig.set(k, 1.0)
		GameConfig.save_game()
		_toast(GameConfig.tt("Тонкая настройка сброшена", "Fine tuning reset"))
		get_tree().reload_current_scene()   # слайдеры перерисуются на ×1.00
	, 240, 44, 15)
	tune_reset.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	_settings_box.add_child(tune_reset)

	_settings_section(GameConfig.t("settings_test"), Color(1.0, 0.6, 0.2))
	var thint := Label.new()
	thint.text = GameConfig.tt(
		"В тест-режиме открыто всё, а статистика, XP, история уровней\nи Спуск дня НЕ записываются — прогоны не искажают Дневник.",
		"In test mode everything is unlocked, and stats, XP, level history,\nand Daily Dive are NOT recorded — test runs don't skew the Journal.")
	thint.custom_minimum_size = Vector2(SETTINGS_W, 0)
	thint.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	thint.add_theme_font_size_override("font_size", 13)
	thint.add_theme_color_override("font_color", Color(0.6, 0.62, 0.68))
	_settings_box.add_child(thint)

	var on_test := func(on: bool) -> void:
		GameConfig.test_mode = on
		GameConfig.save_game()
		_toast(GameConfig.tt("Тест-режим: %s", "Test mode: %s") % (
			GameConfig.tt("ВКЛ — статистика не записывается", "ON — stats are not recorded") if on
			else GameConfig.tt("выкл", "off")))
	_settings_check(GameConfig.tt("Тест-режим (статистика не пишется)", "Test mode (stats not recorded)"), GameConfig.test_mode, on_test, Color(1.0, 0.6, 0.2))
	_unlock_baseline = GameConfig.max_unlocked_level
	_settings_check(GameConfig.tt("Разблокировать все уровни", "Unlock all levels"), GameConfig.max_unlocked_level >= LEVEL_COUNT,
		_on_unlock_toggled, Color(1.0, 0.6, 0.2))
	# ВНИМАНИЕ на формулировку. Прежняя подпись — «уровни с боссом в меню» —
	# читалась как «добавит в меню кнопки боссовых уровней», тогда как флаг
	# заменяет ареной КАЖДЫЙ уровень кампании. Игрок включал его, шёл играть и
	# спрашивал «а где сами лабиринты?» (жалоба 29.07.2026, до этого — «открыл
	# 49 уровень и там темнота», §28). Подпись обязана называть последствие.
	var on_boss := func(on: bool) -> void:
		GameConfig.boss_test_enabled = on
		_populate_levels()
		if on:
			_toast(GameConfig.tt(
				"⚔ Тест боссов ВКЛЮЧЁН: теперь КАЖДЫЙ уровень — арена с боссом, обычных лабиринтов не будет. Выключи здесь же, чтобы вернуть кампанию.",
				"⚔ Boss test ON: EVERY level is now a boss arena, no normal mazes. Turn it off here to get the campaign back."))
	_settings_check(GameConfig.tt(
		"⚔ Тест боссов: КАЖДЫЙ уровень станет ареной",
		"⚔ Boss test: EVERY level becomes an arena"), GameConfig.boss_test_enabled, on_boss, Color(1.0, 0.6, 0.2))
	# [v6.6] Сенсорное управление: на телефоне включено само, на ПК его не видно,
	# пока не включишь здесь (проверить раскладку мышью).
	var on_touch := func(on: bool) -> void:
		GameConfig.touch_controls = on
		GameConfig.save_game()
		_toast(GameConfig.tt("Сенсорное управление: %s (применится со следующего уровня)", "Touch controls: %s (applies from the next level)") % (
			GameConfig.tt("ВКЛ", "ON") if on else GameConfig.tt("выкл", "off")))
	_settings_check(GameConfig.tt("Сенсорное управление (тест на ПК)", "Touch controls (PC test)"),
		GameConfig.touch_controls, on_touch, Color(1.0, 0.6, 0.2))
	# Витрина «Навыки призыва» (GAMEDESIGN.md §25) по-хорошему открывается
	# только победой над дверь-боссом — этот тумблер даёт её потрогать без
	# реального прохождения, не трогая сам флаг прогресса насовсем (можно
	# выключить обратно, если победы ещё не было).
	var on_summon := func(on: bool) -> void:
		GameConfig.door_boss_defeated = on
		GameConfig.save_game()
		_toast(GameConfig.tt("Витрина «Навыки призыва»: %s", "«Summon Skills» shelf: %s") % (
			GameConfig.tt("открыта для теста", "opened for testing") if on
			else GameConfig.tt("скрыта (если нет реальной победы над дверь-боссом)", "hidden (unless a real door-boss win unlocked it)")))
	_settings_check(GameConfig.tt("✦ Тест навыков призыва (открыть витрину)", "✦ Test summon skills (open the shelf)"), GameConfig.door_boss_defeated, on_summon, Color(1.0, 0.6, 0.2))

	# ── Кнопки внизу: по центру колонки ──────────────────────────────────────
	var bsep := HSeparator.new()
	bsep.modulate = Color(0.4, 0.5, 0.7, 0.4)
	_settings_box.add_child(bsep)

	var btn_col := VBoxContainer.new()
	btn_col.alignment = BoxContainer.ALIGNMENT_CENTER
	btn_col.add_theme_constant_override("separation", 10)
	btn_col.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	_settings_box.add_child(btn_col)

	# Сброс прогресса — с подтверждением вторым нажатием. Трогает только
	# текущий профиль (см. GameConfig.reset_progress) — прогресс других
	# игроков на этой машине не задет.
	var reset_hint := Label.new()
	reset_hint.text = GameConfig.tt("Сброс — только для текущего игрока (%s)", "Reset — only for the current player (%s)") % GameConfig.profile_name
	reset_hint.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	reset_hint.add_theme_font_size_override("font_size", 12)
	reset_hint.add_theme_color_override("font_color", Color(0.6, 0.62, 0.68))
	btn_col.add_child(reset_hint)

	var reset_armed := [false]
	var reset_btn := Button.new()
	reset_btn.text = GameConfig.t("reset_progress")
	reset_btn.custom_minimum_size = Vector2(300, 50)
	reset_btn.add_theme_font_size_override("font_size", 24)
	_style_button(reset_btn)
	reset_btn.pressed.connect(func() -> void:
		if reset_armed[0]:
			GameConfig.reset_progress()
			reset_armed[0] = false
			reset_btn.text = GameConfig.t("reset_progress")
			_toast(GameConfig.tt("Прогресс сброшен", "Progress reset"))
		else:
			reset_armed[0] = true
			reset_btn.text = GameConfig.t("reset_confirm")
	)
	reset_btn.add_theme_color_override("font_color", Color(1.0, 0.45, 0.4))
	btn_col.add_child(reset_btn)

# Заголовок секции настроек: отступ + цветная строка одной ширины с колонкой.
func _settings_section(text: String, col: Color) -> void:
	var pad := Control.new()
	pad.custom_minimum_size = Vector2(0, 6)
	_settings_box.add_child(pad)
	var l := Label.new()
	l.text = text
	l.custom_minimum_size = Vector2(SETTINGS_W, 0)
	l.add_theme_font_size_override("font_size", 20)
	l.add_theme_color_override("font_color", col)
	_settings_box.add_child(l)

# Строка-переключатель настроек: та же раскладка HBox(подпись слева, растёт;
# контрол справа), что у ползунков/разрешения/языка — единая левая кромка для
# ВСЕХ строк настроек (раньше текст CheckButton рисовался с собственным
# встроенным отступом и «гулял» относительно обычных Label — жалоба
# «шрифты и выравнивание»; переключатель CheckButton больше не носит текст сам).
# Строка «подпись + выпадающий список» — та же раскладка, что у разрешения.
func _settings_option(text: String, items: Array, selected: int, on_pick: Callable) -> void:
	var row := HBoxContainer.new()
	row.custom_minimum_size = Vector2(SETTINGS_W, 0)
	row.add_theme_constant_override("separation", 10)
	_settings_box.add_child(row)
	var lbl := Label.new()
	lbl.text = text
	lbl.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	lbl.add_theme_font_size_override("font_size", 18)
	row.add_child(lbl)
	var opt := OptionButton.new()
	UIStyle.style_button(opt)   # [AUDIT 05.10.2026 №7] конвенция: все кнопки через UIStyle
	for it in items:
		opt.add_item(str(it))
	opt.selected = selected
	opt.add_theme_font_size_override("font_size", 16)
	opt.item_selected.connect(on_pick)
	row.add_child(opt)

func _settings_check(text: String, value: bool, setter: Callable, col: Color = Color(1, 1, 1)) -> void:
	var row := HBoxContainer.new()
	row.custom_minimum_size = Vector2(SETTINGS_W, 0)
	row.add_theme_constant_override("separation", 10)
	_settings_box.add_child(row)

	var lbl := Label.new()
	lbl.text = text
	lbl.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	lbl.add_theme_font_size_override("font_size", 18)
	if col != Color(1, 1, 1):
		lbl.add_theme_color_override("font_color", col)
	row.add_child(lbl)

	var cb := CheckButton.new()
	cb.text = ""
	cb.button_pressed = value
	cb.toggled.connect(setter)
	row.add_child(cb)

# Модальное окно списка игроков (v1.9): переключиться на существующий
# профиль, создать нового или удалить неактивный. Тот же паттерн окна,
# что и остальные окна — тёмная панель + оверлей, не нативный диалог.
func _show_profile_switcher() -> void:
	var overlay := CanvasLayer.new()
	overlay.layer = 20
	add_child(overlay)

	var dim := ColorRect.new()
	dim.color = Color(0.0, 0.0, 0.0, 0.6)
	dim.set_anchors_preset(Control.PRESET_FULL_RECT)
	dim.mouse_filter = Control.MOUSE_FILTER_STOP
	overlay.add_child(dim)

	var center := CenterContainer.new()
	center.set_anchors_preset(Control.PRESET_FULL_RECT)
	overlay.add_child(center)

	var panel := PanelContainer.new()
	panel.add_theme_stylebox_override("panel", UIStyle.panel_stylebox())
	center.add_child(panel)

	var col := VBoxContainer.new()
	col.add_theme_constant_override("separation", 14)
	col.custom_minimum_size = Vector2(420, 0)
	panel.add_child(col)

	var title := Label.new()
	title.text = GameConfig.tt("Игроки", "Players")
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	title.add_theme_font_size_override("font_size", 24)
	title.add_theme_color_override("font_color", Color(0.85, 0.85, 1.0))
	col.add_child(title)

	var list_scroll := ScrollContainer.new()
	list_scroll.custom_minimum_size = Vector2(400, 200)
	list_scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	col.add_child(list_scroll)
	var list_col := VBoxContainer.new()
	list_col.add_theme_constant_override("separation", 8)
	list_col.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	list_scroll.add_child(list_col)

	for pname in GameConfig.profile_list:
		var row := HBoxContainer.new()
		row.add_theme_constant_override("separation", 8)
		list_col.add_child(row)

		var is_active: bool = (pname == GameConfig.profile_name)
		var pbtn := Button.new()
		pbtn.text = ("● " if is_active else "○ ") + str(pname) + (GameConfig.tt(" (текущий)", " (current)") if is_active else "")
		pbtn.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		pbtn.custom_minimum_size = Vector2(0, 44)
		pbtn.add_theme_font_size_override("font_size", 16)
		pbtn.disabled = is_active
		_style_button(pbtn)
		var nm: String = pname
		pbtn.pressed.connect(func() -> void:
			if GameConfig.switch_profile(nm):
				overlay.queue_free()
				get_tree().reload_current_scene()
		)
		row.add_child(pbtn)

		if not is_active and GameConfig.profile_list.size() > 1:
			var del_btn := Button.new()
			del_btn.text = "✕"
			del_btn.custom_minimum_size = Vector2(44, 44)
			del_btn.add_theme_font_size_override("font_size", 16)
			_style_button(del_btn)
			del_btn.pressed.connect(func() -> void:
				GameConfig.delete_profile(nm)
				overlay.queue_free()
				_show_profile_switcher()
			)
			row.add_child(del_btn)

	var sep := HSeparator.new()
	col.add_child(sep)

	var new_lbl := Label.new()
	new_lbl.text = GameConfig.tt("Новый игрок:", "New player:")
	new_lbl.add_theme_font_size_override("font_size", 16)
	col.add_child(new_lbl)

	var new_row := HBoxContainer.new()
	new_row.add_theme_constant_override("separation", 8)
	col.add_child(new_row)
	var name_edit := LineEdit.new()
	name_edit.placeholder_text = GameConfig.tt("Имя игрока", "Player name")
	name_edit.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	name_edit.custom_minimum_size = Vector2(0, 40)
	new_row.add_child(name_edit)
	var create_btn := Button.new()
	create_btn.text = GameConfig.tt("Создать", "Create")
	create_btn.custom_minimum_size = Vector2(110, 40)
	_style_button(create_btn)
	create_btn.pressed.connect(func() -> void:
		if GameConfig.create_profile(name_edit.text):
			overlay.queue_free()
			get_tree().reload_current_scene()
		else:
			name_edit.placeholder_text = GameConfig.tt("Имя занято/пустое", "Name taken/empty")
			name_edit.text = ""
	)
	new_row.add_child(create_btn)

	col.add_child(UIStyle.make_button(GameConfig.t("close_esc").split("  ")[0], overlay.queue_free, 220, 46, 20))

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
		_toast(GameConfig.tt("Все %d уровней открыты", "All %d levels unlocked") % LEVEL_COUNT)
	else:
		_toast(GameConfig.tt("Уровни закрыты до %d", "Levels locked back to %d") % GameConfig.max_unlocked_level)

# Короткое всплывающее сообщение по центру экрана.
# Короткое подтверждение действия (настройка применена и т.п.) — фон-плашка,
# как и все остальные всплывающие сообщения в игре, а не голый цветной текст.
func _toast(text: String) -> void:
	var wrapc := CenterContainer.new()
	wrapc.set_anchors_preset(Control.PRESET_TOP_WIDE)
	wrapc.position = Vector2(0, 20)
	wrapc.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(wrapc)

	var panel := PanelContainer.new()
	panel.add_theme_stylebox_override("panel", UIStyle.panel_stylebox(Color(0.4, 0.95, 0.7, 0.6)))
	wrapc.add_child(panel)

	var lbl := Label.new()
	lbl.text = text
	lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	lbl.add_theme_font_size_override("font_size", 20)
	lbl.add_theme_color_override("font_color", Color(0.7, 1.0, 0.85))
	panel.add_child(lbl)

	var tw := create_tween()
	tw.tween_interval(1.4)
	tw.tween_property(panel, "modulate:a", 0.0, 0.6)
	tw.tween_callback(wrapc.queue_free)

# Ползунок громкости: подпись + HSlider 0..1 + процент справа.
func _add_volume_slider(text: String, value: float, setter: Callable) -> void:
	var row := HBoxContainer.new()
	row.custom_minimum_size = Vector2(SETTINGS_W, 0)
	row.add_theme_constant_override("separation", 10)
	_settings_box.add_child(row)
	var lbl := Label.new()
	lbl.text = text
	lbl.size_flags_horizontal = Control.SIZE_EXPAND_FILL
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

# Слайдер тонкой настройки сложности (GAMEDESIGN §93): тот же паттерн строки,
# что у громкости, значение показывается как «×N.NN». Вариация: множитель
# применяется в переменную НА ЛЕТУ (кадровая логика читает её каждый кадр),
# а save_game зовётся один раз — на ОКОНЧАНИИ перетаскивания (drag_ended),
# иначе перетаскивание слайдера пишало бы диск десятки раз.
func _add_tune_slider(text: String, value: float, setter: Callable) -> void:
	var row := HBoxContainer.new()
	row.custom_minimum_size = Vector2(SETTINGS_W, 0)
	row.add_theme_constant_override("separation", 10)
	_settings_box.add_child(row)
	var lbl := Label.new()
	lbl.text = text
	lbl.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	lbl.add_theme_font_size_override("font_size", 18)
	row.add_child(lbl)
	var slider := HSlider.new()
	slider.min_value = 0.25
	slider.max_value = 3.0
	slider.step = 0.05
	slider.value = value
	slider.custom_minimum_size = Vector2(220, 24)
	slider.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	row.add_child(slider)
	var pct := Label.new()
	pct.text = "×%.2f" % value
	pct.custom_minimum_size = Vector2(58, 0)
	pct.add_theme_font_size_override("font_size", 16)
	pct.add_theme_color_override("font_color", Color(0.7, 0.78, 0.9))
	row.add_child(pct)
	slider.value_changed.connect(func(v: float) -> void:
		pct.text = "×%.2f" % v
		setter.call(v))
	slider.drag_ended.connect(func(_changed: bool) -> void:
		GameConfig.save_game())

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
	return UIStyle.make_button(text, on_pressed)

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
	UIStyle.style_button(b)

# Есть ли над контролом ScrollContainer (тогда «выступающие» эффекты запрещены).
func _inside_scroll(n: Node) -> bool:
	var p := n.get_parent()
	while p != null:
		if p is ScrollContainer:
			return true
		p = p.get_parent()
	return false

func _process(delta: float) -> void:
	_t += delta
	if _title_glow:
		_title_glow.modulate.a = 0.26 + 0.09 * sin(_t * 2.0)

func _build_level_select(root: VBoxContainer) -> void:
	_level_box = ScrollContainer.new()
	_level_box.visible = false
	_level_box.custom_minimum_size = Vector2(700, 480)
	_level_box.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	root.add_child(_level_box)

	var inner := VBoxContainer.new()
	inner.add_theme_constant_override("separation", 14)
	inner.custom_minimum_size = Vector2(680, 0)
	_level_box.add_child(inner)
	_level_inner = inner

	var lbl := Label.new()
	lbl.text = GameConfig.tt("Выбери уровень", "Choose a level")
	lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	lbl.add_theme_font_size_override("font_size", 28)
	lbl.add_theme_color_override("font_color", Color(0.85, 0.85, 1.0))
	inner.add_child(lbl)

	var note := Label.new()
	note.text = GameConfig.tt("Чем выше уровень — тем больше лабиринт, темнее, быстрее разрядка и чаще события. Иногда попадаются открытые залы и петляющие развилки — не только тесные коридоры.\nЗакрытые уровни (🔒) откроются после прохождения предыдущего.", "The higher the level, the bigger the maze, the darker it gets, and the faster your light drains. Some floors hide open halls and looping side-paths, not just narrow corridors.\nLocked levels (🔒) unlock after you clear the previous one.")
	note.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	note.add_theme_font_size_override("font_size", 15)
	note.add_theme_color_override("font_color", Color(0.6, 0.6, 0.7))
	inner.add_child(note)

	_level_grid = GridContainer.new()
	_level_grid.columns = 10
	_level_grid.add_theme_constant_override("h_separation", 8)
	_level_grid.add_theme_constant_override("v_separation", 8)
	# [LAYOUT-FIX 2026-07-06] GridContainer не умеет центрировать себя (нет
	# понятия alignment, в отличие от H/VBoxContainer) — если родитель
	# (_level_box/inner, ScrollContainer/VBox без явного size_flags) оказался
	# шире грида (а он оказывается, когда рядом есть более широкие панели —
	# root вычисляет свою ширину по САМОЙ широкой панели среди ВСЕХ, не только
	# видимой), грид просто прилипает к левому краю, а Label'ы над ним
	# выглядят «центрированными», потому что центрируют ТЕКСТ внутри своего
	# растянутого ректа, а не сам рект. SIZE_SHRINK_CENTER — грид остаётся
	# своего натурального размера и центрируется в отведённом месте, как текст.
	_level_grid.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	inner.add_child(_level_grid)
	_populate_levels()

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
			# Лучший ранг уровня — мотив перепройти на S.
			var best: String = str(GameConfig.level_best_ranks.get(lvl, ""))
			if best != "":
				btn.text = "%d\n%s" % [lvl, best]
				btn.add_theme_font_size_override("font_size", 15)
				btn.add_theme_color_override("font_color", _RESULT_RANK_COLORS.get(best, Color(0.8, 0.85, 0.95)))
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
		_level_inner.add_child(_boss_section)
		# Вставить перед кнопкой «Назад» (последний дочерний элемент)
		_level_inner.move_child(_boss_section, _level_inner.get_child_count() - 2)

		var sep := HSeparator.new()
		sep.modulate = Color(1.0, 0.6, 0.2, 0.5)
		_boss_section.add_child(sep)

		var lbl := Label.new()
		lbl.text = GameConfig.tt("⚔ Тест-уровни с боссом", "⚔ Boss test levels")
		lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		lbl.add_theme_font_size_override("font_size", 18)
		lbl.add_theme_color_override("font_color", Color(1.0, 0.6, 0.2))
		_boss_section.add_child(lbl)

		var hint := Label.new()
		hint.text = GameConfig.tt("Открывает арену с Тёмным Ядром на выбранном уровне.", "Opens the Dark Core arena on the chosen level.")
		hint.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		hint.add_theme_font_size_override("font_size", 14)
		hint.add_theme_color_override("font_color", Color(0.6, 0.5, 0.4))
		_boss_section.add_child(hint)

		var grid := GridContainer.new()
		grid.columns = 5
		grid.add_theme_constant_override("h_separation", 8)
		grid.add_theme_constant_override("v_separation", 6)
		grid.size_flags_horizontal = Control.SIZE_SHRINK_CENTER   # [LAYOUT-FIX 2026-07-06] см. _level_grid
		_boss_section.add_child(grid)

		# 50 — САМЫЙ сильный босс (страж лабиринта, §25). Без него тест-режим
		# давал потрогать только рядового дверь-босса, а финал приходилось
		# добывать прохождением всей кампании (просьба 30.07.2026).
		for lvl in [1, 5, 10, 15, 20, 50]:
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

# --- Режим «Логово»: 10 уровней, босс в центре лабиринта ---

func _build_lair_select(root: VBoxContainer) -> void:
	_lair_box = ScrollContainer.new()
	_lair_box.visible = false
	_lair_box.custom_minimum_size = Vector2(620, 480)
	_lair_box.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	root.add_child(_lair_box)

	var inner := VBoxContainer.new()
	inner.add_theme_constant_override("separation", 14)
	inner.custom_minimum_size = Vector2(600, 0)
	_lair_box.add_child(inner)

	var lbl := Label.new()
	lbl.text = GameConfig.tt("ЛОГОВО — тронный зал в центре лабиринта", "LAIR — a throne room at the maze's center")
	lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	lbl.add_theme_font_size_override("font_size", 26)
	lbl.add_theme_color_override("font_color", Color(1.0, 0.45, 0.4))
	inner.add_child(lbl)

	var note := Label.new()
	note.text = GameConfig.tt("Лабиринт растёт и густеет от логова к логову — к 10-му он огромен.\nВладыка тьмы ждёт в центре: дойди сквозь стражу и повергни его.", "The maze grows and thickens lair by lair — by the 10th it is huge.\nA dark lord waits at the center: fight through the guard and defeat it.")
	note.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	note.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	note.custom_minimum_size = Vector2(560, 0)
	note.add_theme_font_size_override("font_size", 15)
	note.add_theme_color_override("font_color", Color(0.68, 0.55, 0.55))
	inner.add_child(note)

	_lair_grid = GridContainer.new()
	_lair_grid.columns = 5
	_lair_grid.add_theme_constant_override("h_separation", 10)
	_lair_grid.add_theme_constant_override("v_separation", 10)
	_lair_grid.size_flags_horizontal = Control.SIZE_SHRINK_CENTER   # [LAYOUT-FIX 2026-07-06] см. _level_grid
	inner.add_child(_lair_grid)
	_populate_lair_levels()

func _populate_lair_levels() -> void:
	for c in _lair_grid.get_children():
		c.queue_free()
	for i in GameConfig.LAIR_LEVELS:
		var lvl := i + 1
		var btn := Button.new()
		btn.custom_minimum_size = Vector2(84, 56)
		btn.add_theme_font_size_override("font_size", 20)
		_style_button(btn)
		var unlocked: bool = lvl <= GameConfig.lair_max_unlocked
		if unlocked:
			btn.text = "☠ %d" % lvl
			btn.add_theme_color_override("font_color", Color(1.0, 0.55, 0.5))
			btn.pressed.connect(func(): _on_play_lair(lvl))
		else:
			btn.text = "🔒"
			btn.disabled = true
			btn.modulate = Color(0.5, 0.5, 0.55)
		_lair_grid.add_child(btn)

func _on_open_lair_select() -> void:
	_populate_lair_levels()
	_hide_all_panels()
	_lair_box.visible = true
	_back_btn.visible = true

func _on_play_lair(lvl: int) -> void:
	GameConfig.active_run = -1
	GameConfig.tutorial_mode = false
	GameConfig.lair_mode = true
	GameConfig.lair_level = lvl
	get_tree().change_scene_to_file("res://main.tscn")

# --- Режим «Пещеры» (v4.0, §60): 10 уровней, пол — organic_floor.gd ---
# Клон блока «Логово» выше — тот же паттерн экрана выбора, то же разделение
# transient/persistent состояния (GameConfig.caves_mode/level не сохраняются,
# caves_max_unlocked сохраняется).

func _build_caves_select(root: VBoxContainer) -> void:
	_caves_box = ScrollContainer.new()
	_caves_box.visible = false
	_caves_box.custom_minimum_size = Vector2(620, 480)
	_caves_box.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	root.add_child(_caves_box)

	var inner := VBoxContainer.new()
	inner.add_theme_constant_override("separation", 14)
	inner.custom_minimum_size = Vector2(600, 0)
	_caves_box.add_child(inner)

	var lbl := Label.new()
	lbl.text = GameConfig.tt("ПЕЩЕРЫ — лабиринт без прямых стен", "CAVES — a maze without straight walls")
	lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	lbl.add_theme_font_size_override("font_size", 26)
	lbl.add_theme_color_override("font_color", Color(0.75, 0.6, 0.45))
	inner.add_child(lbl)

	var note := Label.new()
	note.text = GameConfig.tt("Та же цель, что в «Уровнях» — найти выход, — но проходы читаются как сеть скруглённых тоннелей, а не сетка прямых коридоров. Лабиринт растёт от пещеры к пещере.", "The same goal as «Levels» — find the exit — but the passages read as a web of rounded tunnels, not a grid of straight corridors. The maze grows cave by cave.")
	note.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	note.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	note.custom_minimum_size = Vector2(560, 0)
	note.add_theme_font_size_override("font_size", 15)
	note.add_theme_color_override("font_color", Color(0.62, 0.56, 0.5))
	inner.add_child(note)

	_caves_grid = GridContainer.new()
	_caves_grid.columns = 5
	_caves_grid.add_theme_constant_override("h_separation", 10)
	_caves_grid.add_theme_constant_override("v_separation", 10)
	_caves_grid.size_flags_horizontal = Control.SIZE_SHRINK_CENTER   # [LAYOUT-FIX 2026-07-06] см. _level_grid
	inner.add_child(_caves_grid)
	_populate_caves_levels()

func _populate_caves_levels() -> void:
	for c in _caves_grid.get_children():
		c.queue_free()
	for i in GameConfig.CAVES_LEVELS:
		var lvl := i + 1
		var btn := Button.new()
		btn.custom_minimum_size = Vector2(84, 56)
		btn.add_theme_font_size_override("font_size", 20)
		_style_button(btn)
		var unlocked: bool = lvl <= GameConfig.caves_max_unlocked
		if unlocked:
			btn.text = "◯ %d" % lvl
			btn.add_theme_color_override("font_color", Color(0.8, 0.68, 0.5))
			btn.pressed.connect(func(): _on_play_caves(lvl))
		else:
			btn.text = "🔒"
			btn.disabled = true
			btn.modulate = Color(0.5, 0.5, 0.55)
		_caves_grid.add_child(btn)

func _on_open_caves_select() -> void:
	_populate_caves_levels()
	_hide_all_panels()
	_caves_box.visible = true
	_back_btn.visible = true

func _on_play_caves(lvl: int) -> void:
	GameConfig.active_run = -1
	GameConfig.tutorial_mode = false
	GameConfig.caves_mode = true
	GameConfig.caves_level = lvl
	get_tree().change_scene_to_file("res://main.tscn")

# --- Режим «Накал»: слоты забегов и брифинг ---

func _build_runs(root: VBoxContainer) -> void:
	_runs_box = ScrollContainer.new()
	_runs_box.visible = false
	_runs_box.custom_minimum_size = Vector2(620, 480)
	_runs_box.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	root.add_child(_runs_box)

	var inner := VBoxContainer.new()
	inner.add_theme_constant_override("separation", 12)
	inner.custom_minimum_size = Vector2(600, 0)
	_runs_box.add_child(inner)

	var lbl := Label.new()
	lbl.text = GameConfig.tt("НАКАЛ — спуск за огнём", "EMBER — a descent for fire")
	lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	lbl.add_theme_font_size_override("font_size", 30)
	lbl.add_theme_color_override("font_color", Color(1.0, 0.78, 0.4))
	inner.add_child(lbl)

	var note := Label.new()
	note.text = GameConfig.tt("Ты несёшь уголёк из глубин. Каждый раз с нуля, %d жизни на весь спуск, гибель — конец забега.\nУ каждого слота — свой обет: исполни его и награда уйдёт в профиль «Уровней».",
		"You carry an ember from the depths. Every run starts from zero, %d lives for the whole descent, death ends the run.\nEach slot has its own vow: fulfill it and the reward goes to your «Levels» profile.") % GameConfig.RUN_LIVES
	note.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	note.add_theme_font_size_override("font_size", 15)
	note.add_theme_color_override("font_color", Color(0.72, 0.64, 0.52))
	inner.add_child(note)

	_runs_slots_box = VBoxContainer.new()
	_runs_slots_box.add_theme_constant_override("separation", 10)
	inner.add_child(_runs_slots_box)

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
				btn.text = GameConfig.tt("Слот %d   ·   %s (глубина %d)   ·   ♥ %d   — продолжить", "Slot %d   ·   %s (depth %d)   ·   ♥ %d   — resume") % [slot + 1, GameConfig.horizon_name(int(s["level"])), s["level"], s["lives"]]
				btn.add_theme_color_override("font_color", Color(0.72, 1.0, 0.82))
			"ended":
				btn.text = GameConfig.tt("Слот %d   ·   завершён: %s (глубина %d)   — новый забег", "Slot %d   ·   finished: %s (depth %d)   — new run") % [slot + 1, GameConfig.horizon_name(int(s["max_depth"])), s["max_depth"]]
				btn.add_theme_color_override("font_color", Color(0.92, 0.62, 0.56))
			_:
				btn.text = GameConfig.tt("Слот %d   ·   пусто   — новый забег", "Slot %d   ·   empty   — new run") % [slot + 1]
		btn.pressed.connect(func(): _on_run_slot_pressed(slot))
		_runs_slots_box.add_child(btn)
		# Обет слота — долгосрочная цель, награда уходит в профиль «Уровней».
		if slot < GameConfig.RUN_VOWS.size():
			var vow: Dictionary = GameConfig.RUN_VOWS[slot]
			var done: bool = bool(GameConfig.vows_done[slot])
			var vlbl := Label.new()
			vlbl.text = GameConfig.tt("   🕯 Обет: %s — %s", "   🕯 Vow: %s — %s") % [GameConfig.vow_text(slot),
				(GameConfig.tt("исполнен ✓ (+%d SP)", "fulfilled ✓ (+%d SP)") % int(vow["sp"])) if done else (GameConfig.tt("+%d SP в «Уровни»", "+%d SP to «Levels»") % int(vow["sp"]))]
			vlbl.add_theme_font_size_override("font_size", 13)
			vlbl.add_theme_color_override("font_color",
				Color(0.55, 0.9, 0.6) if done else Color(0.65, 0.6, 0.5))
			_runs_slots_box.add_child(vlbl)

func _on_run_slot_pressed(slot: int) -> void:
	var s := GameConfig.run_summary(slot)
	if s["status"] == "active":
		GameConfig.resume_run(slot)
		_launch_game()
	else:
		_show_briefing(slot)

func _build_briefing(root: VBoxContainer) -> void:
	_briefing_box = ScrollContainer.new()
	_briefing_box.visible = false
	_briefing_box.custom_minimum_size = Vector2(620, 480)
	_briefing_box.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	root.add_child(_briefing_box)

	var inner := VBoxContainer.new()
	inner.add_theme_constant_override("separation", 12)
	inner.custom_minimum_size = Vector2(600, 0)
	_briefing_box.add_child(inner)

	var lbl := Label.new()
	lbl.text = GameConfig.tt("Спуск за огнём", "A descent for fire")
	lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	lbl.add_theme_font_size_override("font_size", 28)
	lbl.add_theme_color_override("font_color", Color(1.0, 0.82, 0.45))
	inner.add_child(lbl)

	var body := Label.new()
	body.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	body.custom_minimum_size = Vector2(560, 0)
	body.add_theme_font_size_override("font_size", 16)
	body.add_theme_color_override("font_color", Color(0.82, 0.86, 0.95))
	var horizons_preview: Array = []
	for hi in mini(3, GameConfig.HORIZONS.size()):
		horizons_preview.append(GameConfig.horizon_name(hi * GameConfig.HORIZON_SPAN + 1))
	body.text = GameConfig.tt(
		"Внизу тлеет огонь, которого хватит на всех. Спустись, набери Накал и удержи его.\n\n" +
		"• %d жизни на ВЕСЬ забег — между этажами не восстанавливаются.\n" +
		"• Начинаешь с нуля: только Вспышка (Q), Рывок (Shift) и Тление (R).\n" +
		"• Несомый Накал — риск: гибель сжигает половину, и жар притягивает тьму.\n" +
		"• Алтари (станции) банкуют Накал навсегда — и продают навыки за банк.\n" +
		"• Каждые %d глубин — новый горизонт: %s…\n" +
		"• Гибель завершает забег; выйти в меню можно всегда — слот сохранится.",
		"Below smolders a fire enough for everyone. Descend, gather Ember and hold on to it.\n\n" +
		"• %d lives for the WHOLE run — they don't recover between floors.\n" +
		"• You start from zero: only Flash (Q), Dash (Shift) and Smother (R).\n" +
		"• Carried Ember is a risk: dying burns half of it, and heat draws the dark.\n" +
		"• Altars (stations) bank Ember forever — and sell skills for the bank.\n" +
		"• Every %d depths — a new horizon: %s…\n" +
		"• Dying ends the run; you can always leave to the menu — the slot is saved.") % [
			GameConfig.RUN_LIVES, GameConfig.HORIZON_SPAN,
			", ".join(horizons_preview)]
	inner.add_child(body)

	# Контракт забега: необязательный модификатор риск/награда.
	var clbl := Label.new()
	clbl.text = GameConfig.tt("Контракт спуска (по желанию):", "Descent contract (optional):")
	clbl.add_theme_font_size_override("font_size", 17)
	clbl.add_theme_color_override("font_color", Color(1.0, 0.7, 0.35))
	inner.add_child(clbl)

	_briefing_contracts_box = VBoxContainer.new()
	_briefing_contracts_box.add_theme_constant_override("separation", 6)
	inner.add_child(_briefing_contracts_box)

	inner.add_child(_make_button(GameConfig.tt("Начать забег", "Start the run"), _start_briefed_run))

# Кнопки контрактов: одна выбирается, повторный клик снимает выбор.
func _populate_briefing_contracts() -> void:
	for c in _briefing_contracts_box.get_children():
		c.queue_free()
	_briefing_contract = ""
	var ids: Array = GameConfig.RUN_CONTRACTS.keys()
	for id in ids:
		var b := Button.new()
		b.toggle_mode = true
		b.custom_minimum_size = Vector2(560, 54)
		b.add_theme_font_size_override("font_size", 15)
		_style_button(b)
		b.text = "%s — %s" % [GameConfig.contract_name(id), GameConfig.contract_desc(id).replace("\n", " ")]
		b.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		var cid := str(id)
		b.toggled.connect(func(on: bool) -> void:
			if on:
				_briefing_contract = cid
				for other in _briefing_contracts_box.get_children():
					if other != b and other is Button:
						other.set_pressed_no_signal(false)
			elif _briefing_contract == cid:
				_briefing_contract = ""
		)
		_briefing_contracts_box.add_child(b)

func _on_open_runs() -> void:
	_populate_runs()
	_hide_all_panels()
	_runs_box.visible = true
	_back_btn.visible = true

func _show_briefing(slot: int) -> void:
	_briefing_slot = slot
	_populate_briefing_contracts()
	_runs_box.visible = false
	_briefing_box.visible = true
	_back_btn.visible = true

func _on_briefing_back() -> void:
	_briefing_box.visible = false
	_runs_box.visible = true

func _start_briefed_run() -> void:
	GameConfig.start_new_run(_briefing_slot, _briefing_contract)
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
	_journal_scroll = VBoxContainer.new()
	_journal_scroll.visible = false
	_journal_scroll.add_theme_constant_override("separation", 14)
	root.add_child(_journal_scroll)

	var title := Label.new()
	title.text = GameConfig.tt("Дневник лабиринта", "Maze Journal")
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	title.add_theme_font_size_override("font_size", 30)
	title.add_theme_color_override("font_color", Color(0.85, 0.9, 1.0))
	_journal_scroll.add_child(title)

	# Стрелки по бокам карточки (как в Справке) — щёлкать всегда в одном месте,
	# независимо от высоты текущего слайда.
	var row := HBoxContainer.new()
	row.alignment = BoxContainer.ALIGNMENT_CENTER
	row.add_theme_constant_override("separation", 14)
	_journal_scroll.add_child(row)

	_journal_prev_btn = _make_button("‹", func() -> void: _populate_journal_slide(_journal_slide_idx - 1))
	_journal_prev_btn.custom_minimum_size = Vector2(52, 52)
	_journal_prev_btn.add_theme_font_size_override("font_size", 26)
	_journal_prev_btn.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	row.add_child(_journal_prev_btn)

	var card := PanelContainer.new()
	var sb := StyleBoxFlat.new()
	sb.bg_color = Color(0.045, 0.055, 0.10, 0.9)
	sb.set_corner_radius_all(12)
	sb.set_border_width_all(1)
	sb.border_color = Color(0.4, 0.5, 0.75, 0.5)
	sb.content_margin_left = 22
	sb.content_margin_right = 22
	sb.content_margin_top = 16
	sb.content_margin_bottom = 16
	card.add_theme_stylebox_override("panel", sb)
	row.add_child(card)

	# [CAROUSEL-BOUNDS] Карточка по-прежнему подстраивается под высоту контента
	# (жалоба про «фиксированную коробку с дырой внизу» никуда не делась), но
	# теперь через _carousel_slide_scroll — с потолком по высоте окна. Без него
	# длинные слайды («Путь мастерства») уезжали за нижний край экрана.
	_journal_slide_scroll = _carousel_slide_scroll(700)
	card.add_child(_journal_slide_scroll)

	_journal_box = VBoxContainer.new()
	_journal_box.add_theme_constant_override("separation", 12)
	_journal_box.custom_minimum_size = Vector2(_carousel_content_width(_journal_slide_scroll, 700), 0)
	_journal_slide_scroll.add_child(_journal_box)

	_journal_next_btn = _make_button("›", func() -> void: _populate_journal_slide(_journal_slide_idx + 1))
	_journal_next_btn.custom_minimum_size = Vector2(52, 52)
	_journal_next_btn.add_theme_font_size_override("font_size", 26)
	_journal_next_btn.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	row.add_child(_journal_next_btn)

	_journal_nav_label = Label.new()
	_journal_nav_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_journal_nav_label.add_theme_font_size_override("font_size", 16)
	_journal_nav_label.add_theme_color_override("font_color", Color(0.6, 0.68, 0.8))
	_journal_scroll.add_child(_journal_nav_label)

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

func _journal_line(box: VBoxContainer, t: String, col: Color = Color(0.78, 0.84, 0.95), fsize: int = 16, wrapc: bool = false) -> void:
	var l := Label.new()
	l.text = t
	l.add_theme_font_size_override("font_size", fsize)
	l.add_theme_color_override("font_color", col)
	if wrapc:
		l.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		l.custom_minimum_size.x = 660
	box.add_child(l)

# Ряд «чипов»-статистик: иконка сверху, крупное число, мелкая подпись снизу.
# Оборачивается по ширине (HFlowContainer) — не растягивает панель на узких окнах.
func _journal_stat_chips(box: VBoxContainer, items: Array) -> void:
	var flow := HFlowContainer.new()
	flow.add_theme_constant_override("h_separation", 10)
	flow.add_theme_constant_override("v_separation", 8)
	box.add_child(flow)
	for it in items:
		var icon: String = str(it[0])
		var value: String = str(it[1])
		var caption: String = str(it[2])
		var panel := PanelContainer.new()
		var sb := StyleBoxFlat.new()
		sb.bg_color = Color(0.08, 0.1, 0.16, 0.7)
		sb.set_corner_radius_all(8)
		sb.content_margin_left = 12
		sb.content_margin_right = 12
		sb.content_margin_top = 6
		sb.content_margin_bottom = 6
		panel.add_theme_stylebox_override("panel", sb)
		flow.add_child(panel)

		var cv := VBoxContainer.new()
		cv.alignment = BoxContainer.ALIGNMENT_CENTER
		cv.add_theme_constant_override("separation", 0)
		panel.add_child(cv)

		var vl := Label.new()
		vl.text = "%s %s" % [icon, value]
		vl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		vl.add_theme_font_size_override("font_size", 20)
		vl.add_theme_color_override("font_color", Color(0.95, 0.92, 1.0))
		cv.add_child(vl)

		var cl := Label.new()
		cl.text = caption
		cl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		cl.add_theme_font_size_override("font_size", 12)
		cl.add_theme_color_override("font_color", Color(0.6, 0.65, 0.78))
		cv.add_child(cl)

# Полоска-диаграмма распределения рангов: закрашенный сегмент на ранг
# (пропорционально количеству) + легенда с цветом/буквой/числом под ней —
# вместо текста «S 0 · A 0 · B 5 · C 1 · D 0», который не считывается с ходу.
func _journal_rank_bar(box: VBoxContainer, counts: Dictionary) -> void:
	var total := 0
	for k in counts:
		total += int(counts[k])
	var bar := HBoxContainer.new()
	bar.add_theme_constant_override("separation", 2)
	bar.custom_minimum_size = Vector2(0, 14)
	box.add_child(bar)
	var order := ["S", "A", "B", "C", "D"]
	for rk in order:
		var n: int = int(counts.get(rk, 0))
		var seg := ColorRect.new()
		seg.color = _RESULT_RANK_COLORS.get(rk, Color(0.4, 0.4, 0.5))
		seg.custom_minimum_size = Vector2(0, 14)
		seg.size_flags_horizontal = Control.SIZE_EXPAND_FILL if n > 0 else Control.SIZE_FILL
		# «Пусто» — тонкая тёмная полоска-заглушка, чтобы порядок S..D был виден
		# и когда конкретного ранга ещё не было ни разу.
		if n == 0:
			seg.color.a = 0.15
			seg.custom_minimum_size.x = 6
		else:
			seg.size_flags_stretch_ratio = float(n) / float(maxi(total, 1))
		bar.add_child(seg)

	var legend := HBoxContainer.new()
	legend.add_theme_constant_override("separation", 14)
	box.add_child(legend)
	for rk in order:
		var n: int = int(counts.get(rk, 0))
		var item := HBoxContainer.new()
		item.add_theme_constant_override("separation", 4)
		legend.add_child(item)
		var sw := ColorRect.new()
		sw.color = _RESULT_RANK_COLORS.get(rk, Color(0.4, 0.4, 0.5))
		sw.custom_minimum_size = Vector2(10, 10)
		item.add_child(sw)
		var lbl := Label.new()
		lbl.text = "%s %d" % [rk, n]
		lbl.add_theme_font_size_override("font_size", 13)
		lbl.add_theme_color_override("font_color", Color(0.75, 0.8, 0.9))
		item.add_child(lbl)

# Доля «спидометра»: 1.0 = не хуже пар-тайма, 0 = вдвое и хуже медленнее.
func _journal_speed_frac(t: float, par: float) -> float:
	return clampf(par / maxf(t, 0.1), 0.0, 1.0)

# Карточка слота Накала: статус-бейдж + глубина текущая/макс + ранги-пипсы.
func _journal_run_card(box: VBoxContainer, slot: int, sm: Dictionary) -> void:
	var card := PanelContainer.new()
	var sb := StyleBoxFlat.new()
	sb.bg_color = Color(0.07, 0.08, 0.13, 0.6)
	sb.set_corner_radius_all(8)
	sb.content_margin_left = 12
	sb.content_margin_right = 12
	sb.content_margin_top = 8
	sb.content_margin_bottom = 8
	card.add_theme_stylebox_override("panel", sb)
	box.add_child(card)

	var cv := VBoxContainer.new()
	cv.add_theme_constant_override("separation", 6)
	card.add_child(cv)

	var head := HBoxContainer.new()
	head.add_theme_constant_override("separation", 10)
	cv.add_child(head)

	var slot_lbl := Label.new()
	slot_lbl.text = GameConfig.tt("Слот %d", "Slot %d") % (slot + 1)
	slot_lbl.add_theme_font_size_override("font_size", 16)
	slot_lbl.add_theme_color_override("font_color", Color(0.9, 0.92, 1.0))
	head.add_child(slot_lbl)

	var status: String = str(sm.get("status", "empty"))
	var badge_text: String
	var badge_col: Color
	match status:
		"active":
			badge_text = GameConfig.tt("● идёт", "● active")
			badge_col = Color(0.4, 0.95, 0.55)
		"ended":
			badge_text = GameConfig.tt("○ завершён", "○ finished")
			badge_col = Color(0.75, 0.6, 0.5)
		_:
			badge_text = GameConfig.tt("пусто", "empty")
			badge_col = Color(0.5, 0.55, 0.65)
	var badge := Label.new()
	badge.text = badge_text
	badge.add_theme_font_size_override("font_size", 14)
	badge.add_theme_color_override("font_color", badge_col)
	head.add_child(badge)

	if status == "empty":
		return

	_journal_stat_chips(cv, [
		["⌀", str(int(sm.get("level", 1))), GameConfig.tt("текущая глубина", "current depth")],
		["⌂", str(int(sm.get("max_depth", 1))), GameConfig.tt("лучшая глубина", "best depth")],
		["♥", str(int(sm.get("lives", 0))), GameConfig.tt("жизней осталось", "lives left")],
	])

	var r = GameConfig.runs[slot]
	var ranks: Array = r.get("ranks", []) if r != null else []
	if ranks.is_empty():
		return
	var ranks_lbl := Label.new()
	ranks_lbl.text = GameConfig.tt("Ранги последних этажей:", "Ranks of last floors:")
	ranks_lbl.add_theme_font_size_override("font_size", 12)
	ranks_lbl.add_theme_color_override("font_color", Color(0.6, 0.65, 0.78))
	cv.add_child(ranks_lbl)

	var pip_row := HBoxContainer.new()
	pip_row.add_theme_constant_override("separation", 5)
	cv.add_child(pip_row)
	var rstart := maxi(0, ranks.size() - 12)
	for j in range(rstart, ranks.size()):
		var rk: String = str(ranks[j].get("rank", "?"))
		var pip := PanelContainer.new()
		var psb := StyleBoxFlat.new()
		psb.bg_color = _RESULT_RANK_COLORS.get(rk, Color(0.4, 0.4, 0.5))
		psb.set_corner_radius_all(4)
		pip.add_theme_stylebox_override("panel", psb)
		pip.custom_minimum_size = Vector2(20, 20)
		var pl := Label.new()
		pl.text = rk
		pl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		pl.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
		pl.add_theme_font_size_override("font_size", 12)
		pl.add_theme_color_override("font_color", Color(0.05, 0.05, 0.08))
		pip.add_child(pl)
		pip_row.add_child(pip)

# Строка «Последних уровней» — таблица с фиксированными колонками, не текст.
func _journal_level_row(box: VBoxContainer, rk: String, speed_frac: float,
		level: int, time_s: float, shards_pct: float, tags: Array) -> void:
	var col: Color = _RESULT_RANK_COLORS.get(rk, Color(0.78, 0.84, 0.95))
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 10)
	box.add_child(row)

	var rk_lbl := Label.new()
	rk_lbl.text = rk
	rk_lbl.custom_minimum_size = Vector2(22, 0)
	rk_lbl.add_theme_font_size_override("font_size", 16)
	rk_lbl.add_theme_color_override("font_color", col)
	row.add_child(rk_lbl)

	var bar_bg := PanelContainer.new()
	bar_bg.custom_minimum_size = Vector2(70, 12)
	var bg_sb := StyleBoxFlat.new()
	bg_sb.bg_color = Color(0.15, 0.16, 0.2, 0.6)
	bg_sb.set_corner_radius_all(3)
	bar_bg.add_theme_stylebox_override("panel", bg_sb)
	row.add_child(bar_bg)
	var bar_fill := ColorRect.new()
	bar_fill.color = col
	bar_fill.custom_minimum_size = Vector2(70.0 * clampf(speed_frac, 0.0, 1.0), 12)
	var fill_wrap := Control.new()
	fill_wrap.custom_minimum_size = Vector2(70, 12)
	fill_wrap.add_child(bar_fill)
	bar_bg.add_child(fill_wrap)

	var lvl_lbl := Label.new()
	lvl_lbl.text = GameConfig.tt("ур. %d", "lvl %d") % level
	lvl_lbl.custom_minimum_size = Vector2(64, 0)
	lvl_lbl.add_theme_font_size_override("font_size", 14)
	lvl_lbl.add_theme_color_override("font_color", Color(0.8, 0.84, 0.95))
	row.add_child(lvl_lbl)

	var time_lbl := Label.new()
	time_lbl.text = "%.1fс" % time_s if GameConfig.locale != "en" else "%.1fs" % time_s
	time_lbl.custom_minimum_size = Vector2(58, 0)
	time_lbl.add_theme_font_size_override("font_size", 14)
	time_lbl.add_theme_color_override("font_color", Color(0.8, 0.84, 0.95))
	row.add_child(time_lbl)

	var shard_lbl := Label.new()
	shard_lbl.text = GameConfig.tt("осколки %d%%", "shards %d%%") % int(round(shards_pct * 100.0))
	shard_lbl.custom_minimum_size = Vector2(90, 0)
	shard_lbl.add_theme_font_size_override("font_size", 14)
	shard_lbl.add_theme_color_override("font_color", Color(0.8, 0.84, 0.95))
	row.add_child(shard_lbl)

	if not tags.is_empty():
		var tag_lbl := Label.new()
		tag_lbl.text = "  ·  ".join(tags)
		tag_lbl.add_theme_font_size_override("font_size", 13)
		tag_lbl.add_theme_color_override("font_color", Color(0.65, 0.7, 0.6))
		row.add_child(tag_lbl)

# [JOURNAL-CAROUSEL] Пересобирает список слайдов Дневника — состав зависит от
# прогресса игрока (некоторые слайды не показываются, если данных ещё нет).
# Данные (stats/history) снимаются ОДИН раз здесь и передаются в билдеры
# замыканиями — картина не «плывёт», если что-то поменяется, пока дневник открыт.
func _journal_rebuild_slides() -> void:
	var s: Dictionary = GameConfig.stats
	var hist: Array = GameConfig.level_history
	_journal_slides = []

	# [JOURNAL-CAROUSEL] Дневник «молчит», пока не пройдено вообще ничего —
	# нулевые чипы, все навыки за замком и голос-приветствие «мы не знакомы»
	# на 8 слайдах подряд выглядели уныло и бессмысленно для чистого
	# сохранения. Один тихий слайд вместо всей карусели, пока нет ни одной
	# зацепки за реальный прогресс.
	var has_progress: bool = int(s.get("levels_cleared", 0)) > 0 \
		or not hist.is_empty() \
		or int(s.get("runs_started", 0)) > 0 \
		or not GameConfig.daily_history.is_empty()
	if not has_progress:
		_journal_slides.append({"title": GameConfig.tt("Дневник лабиринта", "Maze Journal"),
			"build": func() -> void: _journal_slide_empty()})
		return

	# [v5.1] Порядок намеренно начинается с РАЗБОРА, а не со счётчиков:
	# первый экран должен отвечать «что делать», а не «сколько я набегал».
	_journal_slides.append({"title": GameConfig.tt("Ближайшие цели", "Next up"),
		"build": func() -> void: _journal_slide_next(s)})
	_journal_slides.append({"title": GameConfig.tt("На чём ты теряешь", "Where you lose"),
		"build": func() -> void: _journal_slide_weak(s, hist)})
	_journal_slides.append({"title": GameConfig.tt("Чем ты не пользуешься", "What you never use"),
		"build": func() -> void: _journal_slide_idle()})
	_journal_slides.append({"title": GameConfig.tt("Твой стиль", "Your Style"),
		"build": func() -> void: _journal_slide_style()})
	_journal_slides.append({"title": GameConfig.tt("🎓 Путь мастерства", "🎓 Path of Mastery"),
		"build": func() -> void: _journal_slide_mastery(s, hist)})
	_journal_slides.append({"title": GameConfig.tt("Последние уровни", "Recent levels"),
		"build": func() -> void: _journal_slide_history(hist)})
	var locked_ms: Array = []
	for id in GameConfig.SKILL_MILESTONES:
		if not GameConfig.skills_unlocked.get(id, false):
			locked_ms.append(id)
	if not locked_ms.is_empty():
		_journal_slides.append({"title": GameConfig.tt("Путь к навыкам", "Path to skills"),
			"build": func() -> void: _journal_slide_goals(s, locked_ms)})
	_journal_slides.append({"title": GameConfig.tt("✧ Голос лабиринта", "✧ Voice of the Maze"),
		"build": func() -> void: _journal_slide_voice(hist, s)})
	if not GameConfig.daily_history.is_empty():
		_journal_slides.append({"title": GameConfig.tt("Спуск дня", "Daily Dive"),
			"build": func() -> void: _journal_slide_daily()})
	_journal_slides.append({"title": GameConfig.tt("Забеги Накала", "Ember runs"),
		"build": func() -> void: _journal_slide_runs()})
	_journal_slides.append({"title": GameConfig.tt("Цифры", "Raw numbers"),
		"build": func() -> void: _journal_slide_overview(s)})

# Перерисовать слайд idx (с зацикливанием). Заголовок — общий для всех
# слайдов (единый стиль), сам билдер добавляет только содержимое.
func _populate_journal_slide(idx: int) -> void:
	if _journal_slides.is_empty():
		_journal_rebuild_slides()
	var n := _journal_slides.size()
	_journal_slide_idx = ((idx % n) + n) % n
	for c in _journal_box.get_children():
		c.queue_free()
	var slide: Dictionary = _journal_slides[_journal_slide_idx]
	var t := Label.new()
	t.text = str(slide["title"])
	t.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	t.add_theme_font_size_override("font_size", 22)
	t.add_theme_color_override("font_color", Color(0.85, 0.9, 1.0))
	_journal_box.add_child(t)
	(slide["build"] as Callable).call()
	# Один слайд (дневник «молчит», см. _journal_rebuild_slides) — стрелки и
	# счётчик страниц ни на что не указывают, прячем их совсем.
	var multi := n > 1
	_journal_prev_btn.visible = multi
	_journal_next_btn.visible = multi
	_journal_nav_label.visible = multi
	_journal_nav_label.text = "%d / %d" % [_journal_slide_idx + 1, n]
	# Высота карточки считается ПОСЛЕ сборки контента и через кадр — до этого
	# get_combined_minimum_size() ещё не учитывает только что добавленные узлы.
	_refit_carousel_deferred(_journal_slide_scroll, _journal_box)

# Пересчёт высоты карточки на следующем кадре: контейнеры Godot вычисляют свои
# минимальные размеры не мгновенно, а к следующему проходу layout'а.
func _refit_carousel_deferred(sc: ScrollContainer, box: Control) -> void:
	if sc == null or box == null:
		return
	# Два прохода: первый ставит высоту по свежесобранному контенту, второй
	# уточняет её, когда колонка уже пересчиталась под новый размер карточки.
	for _pass in 2:
		await get_tree().process_frame
		if not is_inside_tree():
			return
		_fit_carousel(sc, box)

# --- Единственный слайд для чистого сохранения — см. _journal_rebuild_slides.
func _journal_slide_empty() -> void:
	var panel := _journal_panel(GameConfig.tt("✧ Голос лабиринта", "✧ Voice of the Maze"), Color(1.0, 0.85, 0.3))
	_journal_line(panel, GameConfig.tt(
		"Мы ещё не знакомы. Пройди хотя бы один этаж — и я начну записывать твою историю.",
		"We haven't met yet. Clear at least one floor — and I'll start recording your story."),
		Color(0.95, 0.9, 0.75), 16, true)

# --- Слайд «Обзор»: агрегаты за всё время — карточки-цифры + полоска рангов.
# Самый «дашбордный» слайд — читается одним взглядом, без единого абзаца текста.
func _journal_slide_overview(s: Dictionary) -> void:
	var path := _journal_panel(GameConfig.tt("Путь", "Path"), Color(0.5, 0.8, 1.0))
	_journal_stat_chips(path, [
		["🚪", str(int(s.get("levels_cleared", 0))), GameConfig.tt("этажей пройдено", "floors cleared")],
		["✦", str(int(s.get("shards_total", 0))), GameConfig.tt("осколков собрано", "shards collected")],
		["⌀", str(int(s.get("best_depth", 0))), GameConfig.tt("лучшая глубина Накала", "best Ember depth")],
		["🏦", str(int(s.get("best_ember", 0))), GameConfig.tt("рекорд банка", "best bank")],
		["🔥", "%d/%d" % [int(s.get("runs_ended", 0)), int(s.get("runs_started", 0))], GameConfig.tt("забегов завершено", "runs finished")],
	])
	_journal_rank_bar(path, {
		"S": int(s.get("rank_S", 0)), "A": int(s.get("rank_A", 0)), "B": int(s.get("rank_B", 0)),
		"C": int(s.get("rank_C", 0)), "D": int(s.get("rank_D", 0)),
	})

# --- Слайд «Твой стиль»: навыки в картинках — частота, мастерство, форма Апекса.
func _journal_slide_style() -> void:
	var style := _journal_panel(GameConfig.tt("Твой стиль", "Your Style"), Color(0.8, 0.7, 1.0))
	var srow := HBoxContainer.new()
	srow.add_theme_constant_override("separation", 12)
	style.add_child(srow)
	for id in ["flash", "dash", "smother", "mark", "sonar", "shield", "guide", "reveal", "pulse", "mirage", "breach", "chrono"]:
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
		nml.text = _skill_name(id)
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
	if GameConfig.skills_unlocked.get("apex", false):
		var top := GameConfig.top_mastered(2)
		var arow := HBoxContainer.new()
		arow.add_theme_constant_override("separation", 8)
		style.add_child(arow)
		var al := Label.new()
		al.text = GameConfig.tt("Апекс (H) сейчас примет форму:", "Apex (H) will currently take the form:")
		al.add_theme_font_size_override("font_size", 15)
		al.add_theme_color_override("font_color", Color(1.0, 0.5, 0.55))
		arow.add_child(al)
		var mic := TextureRect.new()
		mic.texture = SkillIcons.make(top[0], 26)
		mic.stretch_mode = TextureRect.STRETCH_KEEP_CENTERED
		arow.add_child(mic)
		var mn := Label.new()
		mn.text = _skill_name(top[0])
		mn.add_theme_font_size_override("font_size", 15)
		arow.add_child(mn)
		if top.size() > 1:
			var el := Label.new()
			el.text = GameConfig.tt("· эхо:", "· echo:")
			el.add_theme_font_size_override("font_size", 14)
			el.add_theme_color_override("font_color", Color(0.65, 0.7, 0.82))
			arow.add_child(el)
			var eic := TextureRect.new()
			eic.texture = SkillIcons.make(top[1], 22)
			eic.stretch_mode = TextureRect.STRETCH_KEEP_CENTERED
			arow.add_child(eic)
			var en := Label.new()
			en.text = _skill_name(top[1])
			en.add_theme_font_size_override("font_size", 14)
			arow.add_child(en)
		_journal_line(style, GameConfig.tt("Форма Апекса — это всегда самый прокачанный навык из твоего НАБОРА. Хочешь другую форму — применяй нужный навык чаще других и держи его в наборе, и Апекс перейдёт на него.",
			"The Apex form is always the most-mastered skill IN YOUR LOADOUT. Want a different form — use that skill more than the others and keep it in your loadout, and Apex will switch to it."), Color(0.6, 0.66, 0.78), 13, true)
	else:
		_journal_line(style, GameConfig.tt("Апекс (H) откроется, когда куплены все 7 активных навыков — или досрочно: 4+ навыка и один прокачан до ★5. Форму примет тот, что качаешь сильнее.",
			"Apex (H) unlocks once all 7 active skills are bought — or early: 4+ skills with one at ★5 mastery. It takes the form of whichever you've mastered most."), Color(0.6, 0.66, 0.78), 13, true)

# --- Слайд «Путь мастерства»: лабиринт не комментирует, а ТРЕНИРУЕТ.
# Последовательная программа: по статистике находим первый непройденный
# «урок», показываем прогресс до цели и конкретный совет, как её взять.
func _journal_slide_mastery(s: Dictionary, hist: Array) -> void:
	var is_en := GameConfig.locale == "en"
	var coach := _journal_panel(GameConfig.tt("🎓 Путь мастерства", "🎓 Path of Mastery"), Color(0.45, 0.95, 0.75))
	var steps := _coach_steps(s, hist)
	var done_n := 0
	for st in steps:
		if bool(st["done"]):
			done_n += 1
	_journal_line(coach, (("Lessons done: %d of %d") if is_en else ("Пройдено уроков: %d из %d")) % [done_n, steps.size()], Color(0.6, 0.75, 0.7), 14)
	var shown_current := false
	var upcoming := 0
	for st in steps:
		if bool(st["done"]):
			_journal_line(coach, "✓ %s" % str(st["title"]), Color(0.45, 0.7, 0.55), 14)
		elif not shown_current:
			shown_current = true
			var prog := str(st["progress"])
			_journal_line(coach, (("▶ CURRENT LESSON: %s%s") if is_en else ("▶ ТЕКУЩИЙ УРОК: %s%s")) % [str(st["title"]),
				("   (%s)" % prog) if prog != "" else ""],
				Color(0.55, 1.0, 0.8), 17, true)
			_journal_line(coach, (("   How: %s") if is_en else ("   Как: %s")) % str(st["how"]), Color(0.85, 0.95, 0.85), 15, true)
		elif upcoming < 2:
			upcoming += 1
			_journal_line(coach, (("· next: %s") if is_en else ("· дальше: %s")) % str(st["title"]), Color(0.45, 0.52, 0.6), 13)
	if not shown_current:
		_journal_line(coach, "The path is fully walked. The maze is no longer your teacher — now you teach it to fear you." if is_en else
			"Путь пройден целиком. Лабиринт больше не учитель тебе — теперь ты учишь его бояться.",
			Color(1.0, 0.85, 0.3), 15, true)

# --- Слайд «Последние уровни»: настоящая таблица (не текст с пробелами!),
# теперь на отдельном слайде — влезает больше строк, чем в общем скролле.
func _journal_slide_history(hist: Array) -> void:
	var recent := _journal_panel(GameConfig.tt("Последние уровни", "Recent levels"), Color(0.85, 0.9, 1.0))
	if hist.is_empty():
		_journal_line(recent, "Пока пусто — пройди первый уровень, и лабиринт начнёт записывать.")
	else:
		_journal_line(recent, GameConfig.tt("полоска — скорость против пар-тайма: длиннее = быстрее", "bar — speed vs par time: longer = faster"), Color(0.55, 0.6, 0.72), 12)
		var start := maxi(0, hist.size() - 10)
		for i in range(hist.size() - 1, start - 1, -1):
			var e: Dictionary = hist[i]
			var t: float = float(e.get("time", 0.0))
			var par: float = maxf(1.0, float(e.get("par", 1.0)))
			var rk: String = str(e.get("rank", "?"))
			var tags: Array = []
			if bool(e.get("no_dmg", false)):
				tags.append(GameConfig.tt("без урона ✦", "no damage ✦"))
			var diff_tag: String = ["◦ " + GameConfig.tt("тлеющий", "ember"), "", "☀ " + GameConfig.tt("ПЫЛАЮЩИЙ", "INFERNO")][clampi(int(e.get("diff", 1)), 0, 2)]
			if diff_tag != "":
				tags.append(diff_tag)
			_journal_level_row(recent, rk, _journal_speed_frac(t, par),
				int(e.get("level", 0)), t, float(e.get("shards_pct", 0.0)), tags)

# --- Слайд «Путь к навыкам»: цели-майлстоуны (навык откроется сам за достижение).
func _journal_slide_goals(s: Dictionary, locked_ms: Array) -> void:
	var goals := _journal_panel(GameConfig.tt("Путь к навыкам", "Path to skills"), Color(0.5, 1.0, 0.6))
	_journal_line(goals, "Навыки открываются за дела — или за SP в меню навыков, что раньше.", Color(0.6, 0.75, 0.65), 14, true)
	var names := {"sonar": "Сонар (E)", "shield": "Щит (C)", "guide": "Искра (G)", "reveal": "Озарение (F)", "pulse": "Пульс (B)"}
	for id in locked_ms:
		var ms: Dictionary = GameConfig.SKILL_MILESTONES[id]
		var cur := mini(int(s.get(ms["stat"], 0)), int(ms["need"]))
		var frac := float(cur) / float(ms["need"])
		var bar := "▰".repeat(int(round(frac * 8.0))) + "▱".repeat(8 - int(round(frac * 8.0)))
		_journal_line(goals, "%s   %s   %d / %d — %s" % [names.get(id, id), bar, cur, int(ms["need"]), str(ms["text"])])

# --- Слайд «Голос лабиринта»: наблюдения и советы по игре.
func _journal_slide_voice(hist: Array, s: Dictionary) -> void:
	var voice := _journal_panel(GameConfig.tt("✧ Голос лабиринта", "✧ Voice of the Maze"), Color(1.0, 0.85, 0.3))
	for line in _journal_voice_lines(hist, s):
		_journal_line(voice, line, Color(0.95, 0.9, 0.75), 16, true)

# --- Слайд «Спуск дня»: серия и последние результаты.
func _journal_slide_daily() -> void:
	var daily := _journal_panel(GameConfig.tt("Спуск дня", "Daily Dive"), Color(1.0, 0.85, 0.3))
	var streak := GameConfig.daily_streak()
	if streak >= 2:
		_journal_line(daily, "🔥 Серия: %d %s подряд" % [streak, _plural(streak, "день", "дня", "дней")], Color(1.0, 0.62, 0.25))
	var dh: Array = GameConfig.daily_history
	var dstart := maxi(0, dh.size() - 5)
	for i in range(dh.size() - 1, dstart - 1, -1):
		var e: Dictionary = dh[i]
		_journal_line(daily, "%s   ·   глубина %d   ·   Накал %d" % [
			str(e.get("date", "?")), int(e.get("depth", 1)), int(e.get("ember", 0))])

# --- Слайд «Забеги Накала»: слоты — карточка на слот вместо строки текста.
func _journal_slide_runs() -> void:
	var runs := _journal_panel(GameConfig.tt("Забеги Накала", "Ember runs"), Color(1.0, 0.62, 0.25))
	for i in GameConfig.RUN_SLOTS:
		var sm := GameConfig.run_summary(i)
		_journal_run_card(runs, i, sm)

# Сводка по кольцевому буферу последних уровней.
# =============================================================================
# [v5.1] ДНЕВНИК: ТРИ СЛАЙДА-РАЗБОРА вместо свалки счётчиков
# =============================================================================
# Жалоба игрока: «дневник не информативен, ничего не даёт». Диагноз: он
# показывал ЧТО Я СДЕЛАЛ («302 осколка», «14 этажей»), но не отвечал ни на
# один вопрос, который у игрока реально есть: что делать дальше, на чём я
# теряю, чем не пользуюсь. Все данные для ответов давно лежали в
# level_history/stats/skill_uses — их просто никто не интерпретировал.
# Сырые цифры не выброшены, а понижены до последнего слайда «Цифры».

# --- 1. «Что дальше»: ближайшая КОНКРЕТНАЯ цель с прогрессом ------------------
# Порядок целей — от самой близкой к дальней, чтобы верхняя строка всегда была
# достижимой сегодня, а не «пройди 30 уровней».
func _journal_slide_next(s: Dictionary) -> void:
	var box := _journal_panel(GameConfig.tt("Что откроется дальше", "What unlocks next"), Color(1.0, 0.86, 0.35))
	var goals: Array = []

	# Вехи навыков — самая осязаемая цель: навык открывается сам.
	for id in GameConfig.SKILL_MILESTONES:
		if GameConfig.skills_unlocked.get(id, false):
			continue
		var ms: Dictionary = GameConfig.SKILL_MILESTONES[id]
		var have: int = int(s.get(str(ms["stat"]), 0))
		var need: int = int(ms["need"])
		goals.append({
			"t": GameConfig.tt("Навык «%s»", "Skill «%s»") % _skill_name(str(id)),
			"sub": GameConfig.milestone_text(str(id)),
			"have": have, "need": need, "col": Color(0.45, 0.85, 1.0)})

	# Открытие режимов и следующая ступень лестницы — по уровню.
	var lvl: int = GameConfig.max_unlocked_level
	for e in GameConfig.LADDER:
		var el: int = int(e.get("level", 999))
		if el <= lvl:
			continue
		goals.append({
			"t": str(e.get("name_en" if GameConfig.locale == "en" else "name", "?")),
			"sub": GameConfig.tt("откроется на уровне %d", "unlocks at level %d") % el,
			"have": lvl, "need": el, "col": Color(e.get("color", Color(0.7, 0.8, 1.0)))})
		if goals.size() >= 6:
			break

	if goals.is_empty():
		_journal_line(box, GameConfig.tt("Открыто всё. Дальше — только твои рекорды.",
			"Everything is unlocked. From here on it's your own records."), Color(0.75, 0.85, 1.0), 16, true)
		return

	# Ближе к цели — выше в списке: «почти получилось» мотивирует сильнее.
	goals.sort_custom(func(a, b):
		return (float(a["have"]) / maxf(float(a["need"]), 1.0)) > (float(b["have"]) / maxf(float(b["need"]), 1.0)))
	for g in goals.slice(0, 4):
		_journal_goal_row(box, g)

# Строка цели: название, подпись и полоса прогресса с реальными числами.
func _journal_goal_row(box: VBoxContainer, g: Dictionary) -> void:
	var row := VBoxContainer.new()
	row.add_theme_constant_override("separation", 2)
	box.add_child(row)
	var head := Label.new()
	head.text = "%s — %s" % [str(g["t"]), str(g["sub"])]
	head.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	head.add_theme_font_size_override("font_size", 15)
	head.add_theme_color_override("font_color", Color(0.85, 0.9, 1.0))
	row.add_child(head)

	var have: float = float(g["have"])
	var need: float = maxf(float(g["need"]), 1.0)
	var frac: float = clampf(have / need, 0.0, 1.0)
	var bar := HBoxContainer.new()
	bar.add_theme_constant_override("separation", 8)
	row.add_child(bar)
	var track := ColorRect.new()
	track.color = Color(0.14, 0.16, 0.22)
	track.custom_minimum_size = Vector2(300, 10)
	bar.add_child(track)
	var fill := ColorRect.new()
	fill.color = Color(g["col"])
	fill.custom_minimum_size = Vector2(maxf(2.0, 300.0 * frac), 10)
	fill.position = Vector2.ZERO
	track.add_child(fill)
	var num := Label.new()
	num.text = "%d / %d" % [int(have), int(need)]
	num.add_theme_font_size_override("font_size", 13)
	num.add_theme_color_override("font_color", Color(0.62, 0.7, 0.85))
	bar.add_child(num)

# --- 2. «На чём ты теряешь»: разбор по истории, а не счётчики -----------------
func _journal_slide_weak(s: Dictionary, hist: Array) -> void:
	var box := _journal_panel(GameConfig.tt("Разбор последних уровней", "Recent levels breakdown"), Color(1.0, 0.5, 0.45))
	if hist.is_empty():
		_journal_line(box, GameConfig.tt("Пройди хотя бы один уровень — тогда будет что разбирать.",
			"Clear at least one level and there will be something to analyse."), Color(0.7, 0.75, 0.85), 15, true)
		return
	var ag := _journal_aggregates(hist)
	var verdicts: Array = []

	# Скорость относительно нормы времени уровня.
	var ratio: float = float(ag["avg_ratio"])
	if ratio > 1.6:
		verdicts.append([GameConfig.tt("Время: ×%.1f от нормы — ты блуждаешь", "Time: x%.1f of par — you wander") % ratio,
			GameConfig.tt("Тяга воздуха (просто остановись) и Пульс ведут к выходу без перебора коридоров.",
				"The draft (just stand still) and Pulse lead you out without brute-forcing corridors."), Color(1.0, 0.6, 0.4)])
	elif ratio <= 1.0:
		verdicts.append([GameConfig.tt("Время: ×%.1f от нормы — быстрее нормы", "Time: x%.1f of par — faster than par") % ratio,
			GameConfig.tt("Скорость у тебя есть. Ранг теперь упирается в чистоту и осколки.",
				"Speed you have. Your rank now hinges on clean runs and shards."), Color(0.5, 1.0, 0.6)])

	# Чистота: сколько уровней пройдено без единого удара.
	var clean: float = float(ag["clean_pct"])
	if clean < 0.34:
		verdicts.append([GameConfig.tt("Чисто пройдено: %d%% уровней", "Clean clears: %d%% of levels") % int(clean * 100.0),
			GameConfig.tt("Каждый удар рвёт серию осколков. Щит (C) и Тление (R) дешевле, чем потерянный множитель.",
				"Every hit breaks your shard streak. Shield (C) and Smother (R) cost less than the lost multiplier."), Color(1.0, 0.6, 0.4)])

	# Кто именно тебя бьёт — по счётчикам бестиария.
	var worst := -1
	var worst_hits := 0
	for t in 6:
		var h: int = int(s.get("hit_t%d" % t, 0))
		if h > worst_hits:
			worst_hits = h
			worst = t
	if worst >= 0 and worst_hits >= 3:
		verdicts.append([GameConfig.tt("Больше всех бьёт: %s (%d раз)", "Hits you most: %s (%d times)") % [GameConfig.bestiary_name(worst), worst_hits],
			GameConfig.bestiary_tactic(worst), Color(1.0, 0.75, 0.4)])

	# Осколки — это знание о выходе, а не очки.
	var sh: float = float(ag["avg_shards"])
	if sh < 40.0:
		verdicts.append([GameConfig.tt("Осколков за уровень: %d%%", "Shards per level: %d%%") % int(sh),
			GameConfig.tt("Осколок — улика о выходе и ключ от двери. Ходить вслепую дороже, чем свернуть за ним.",
				"A shard is a clue to the exit and a door key. Walking blind costs more than the detour."), Color(1.0, 0.75, 0.4)])

	if verdicts.is_empty():
		_journal_line(box, GameConfig.tt("Слабых мест не видно: скорость, чистота и сбор в норме. Поднимай сложность.",
			"No weak spots: speed, cleanliness and collection are all fine. Raise the difficulty."), Color(0.5, 1.0, 0.6), 16, true)
		return
	for v in verdicts:
		_journal_verdict(box, str(v[0]), str(v[1]), Color(v[2]))

# Вердикт: жирная строка-наблюдение + строка «что с этим делать».
func _journal_verdict(box: VBoxContainer, head: String, advice: String, col: Color) -> void:
	var h := Label.new()
	h.text = "▸ " + head
	h.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	h.add_theme_font_size_override("font_size", 16)
	h.add_theme_color_override("font_color", col)
	box.add_child(h)
	var a := Label.new()
	a.text = "     " + advice
	a.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	a.add_theme_font_size_override("font_size", 14)
	a.add_theme_color_override("font_color", Color(0.68, 0.74, 0.86))
	box.add_child(a)

# --- 3. «Чем ты не пользуешься»: купленное, но простаивающее ------------------
# Смысл: у игрока к середине кампании открыто 10+ активных навыков, а играет он
# двумя-тремя. Дневник — единственное место, где это вообще видно.
const _JOURNAL_SKILL_WHY := {
	"sonar":   ["показывает планировку сквозь стены — разведка без ходьбы", "reveals the layout through walls — recon without walking"],
	"shield":  ["следующий контакт замораживает врага, а не бьёт тебя", "the next contact freezes the enemy instead of hurting you"],
	"guide":   ["сама летит к ближайшему осколку — не надо помнить, где он", "flies to the nearest shard on its own — no need to remember where"],
	"reveal":  ["Воли не тратит вовсе: заряжается осколками и станциями", "costs no Will at all: it charges from shards and stations"],
	"pulse":   ["звуковой компас к выходу — ведёт, пока ты смотришь по сторонам", "a sound compass to the exit — it leads while you look around"],
	"smother": ["враги теряют след: аварийная кнопка, а не режим ходьбы", "enemies lose your trail: a panic button, not a travel mode"],
	"mark":    ["держит клетку твоей 45 секунд, что бы ни делала тьма", "holds a cell as yours for 45s no matter what the dark does"],
	"mirage":  ["приманка уводит погоню в сторону", "a decoy leads the chase away"],
	"breach":  ["ломает стену: срезка и аварийный выход разом", "smashes a wall: a shortcut and an escape hatch at once"],
	"chrono":  ["замораживает весь этаж — окно, чтобы уйти или добить", "freezes the whole floor — a window to leave or finish them"],
}

func _journal_slide_idle() -> void:
	var box := _journal_panel(GameConfig.tt("Простаивает без дела", "Sitting idle"), Color(0.7, 0.85, 1.0))
	var total_casts: int = 0
	for id in GameConfig.skill_uses:
		total_casts += int(GameConfig.skill_uses[id])
	var idle: Array = []
	for id in _JOURNAL_SKILL_WHY:
		if not GameConfig.skills_unlocked.get(id, false):
			continue
		var u: int = int(GameConfig.skill_uses.get(id, 0))
		# «Простаивает» — это относительно того, сколько игрок вообще кастует:
		# 5 применений у новичка и у ветерана означают разное.
		if u <= maxi(3, int(float(total_casts) * 0.03)):
			idle.append([id, u])
	if idle.is_empty():
		_journal_line(box, GameConfig.tt("Ты пользуешься всем, что открыл. Редкий случай — так и надо.",
			"You use everything you've unlocked. That's rare — keep it up."), Color(0.5, 1.0, 0.6), 16, true)
		return
	idle.sort_custom(func(a, b): return int(a[1]) < int(b[1]))
	_journal_line(box, GameConfig.tt("Открыто, но почти не используется — а мастерство растёт только от применения:",
		"Unlocked but barely used — and mastery only grows from casting:"), Color(0.72, 0.78, 0.9), 14, true)
	for pair in idle.slice(0, 5):
		var id: String = str(pair[0])
		var why: Array = _JOURNAL_SKILL_WHY[id]
		_journal_verdict(box,
			"%s — %d %s" % [_skill_name(id), int(pair[1]), GameConfig.tt("раз", "casts")],
			str(why[1] if GameConfig.locale == "en" else why[0]),
			Color(0.8, 0.88, 1.0))

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
	"shield": "Щит", "guide": "Искра", "reveal": "Озарение", "smother": "Тление", "pulse": "Пульс",
	"mirage": "Мираж", "breach": "Разлом", "chrono": "Хронос", "mark": "Метка"}
const _SKILL_NAMES_EN := {"flash": "Flash", "dash": "Dash", "sonar": "Sonar",
	"shield": "Shield", "guide": "Guide", "reveal": "Reveal", "smother": "Smother", "pulse": "Pulse",
	"mirage": "Mirage", "breach": "Breach", "chrono": "Chrono", "mark": "Mark"}

func _skill_name(id: String) -> String:
	var names: Dictionary = _SKILL_NAMES_EN if GameConfig.locale == "en" else _SKILL_NAMES
	return str(names.get(id, id))

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
const _JOURNAL_RUMORS_EN := [
	"Rumor: gather three shards in a row without taking damage, and the dark retreats on its own. Try it.",
	"Rumor: shards sometimes leave an echo. Hear a chime behind you — decide whether it's worth turning back.",
	"Rumor: a Dash through your own Flash flies farther than usual. Some call it a «light spear».",
	"Rumor: Sonar fired during Reveal sees everything — and enemies are blinded by it.",
	"Rumor: a distant beacon lives for half a minute. Whoever reaches it gets a gift.",
	"Rumor: whoever stands by an energy crystal doesn't fade. A station is a refuge — catch your breath.",
	"Rumor: deep in Ember, the brighter you burn, the louder the screen's heart beats. The dark hears it.",
]

func _journal_rumors() -> Array:
	return _JOURNAL_RUMORS_EN if GameConfig.locale == "en" else _JOURNAL_RUMORS

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
	var en := GameConfig.locale == "en"
	var out: Array = []
	var total := int(s.get("levels_cleared", 0))
	var fl := _plural(total, "этаж", "этажа", "этажей")

	# Приветствие — всегда первое, зависит от «стажа» и меняет формулировку.
	var greet: Array
	if en:
		if total <= 0:
			greet = [
				"We haven't met yet. Clear at least one floor — and I'll start recording your story.",
				"The journal is empty. The maze awaits your first step.",
			]
		elif total < 10:
			greet = [
				"I've been watching you for %d floor(s). Still sizing you up." % total,
				"%d floor(s) behind you. I'm starting to recognize your gait." % total,
			]
		elif total < 50:
			greet = [
				"%d floors together. I already know how you play — read below." % total,
				"I've seen every one of your %d floors. There's something I want to say." % total,
			]
		else:
			greet = [
				"%d floors. You've been here longer than most sparks. I remember every one." % total,
				"After %d floors it's hard to surprise you. But I'll try." % total,
			]
	else:
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
		pool.append(([
			"You tend to wander — averaging %d%% of par time. Guide (G) will show the way, and Sonar reveals what's around the corner." % int(round(agg.avg_ratio * 100.0)),
			"I see you circling the same corridors. Trust Sonar — it draws what the eye can't see.",
		] if en else [
			"Ты подолгу блуждаешь — в среднем %d%% от пар-тайма. Искра (G) покажет дорогу, а Сонар вскроет планировку за углом." % int(round(agg.avg_ratio * 100.0)),
			"Я вижу, как ты кружишь по одним и тем же коридорам. Доверься Сонару — он рисует то, чего не видит глаз.",
		]))
	elif agg.avg_ratio <= 1.05 and n >= 3:
		pool.append(([
			"You clear levels faster than I can rebuild the walls. Impressive.",
			"Your pace — %d%% of par time. Few walk me with such confidence." % int(round(agg.avg_ratio * 100.0)),
		] if en else [
			"Ты проходишь быстрее, чем я успеваю перестраивать стены. Впечатляет.",
			"Твой темп — %d%% от пар-тайма. Мало кто ходит по мне так уверенно." % int(round(agg.avg_ratio * 100.0)),
		]))

	# Чистота
	if agg.clean_pct < 0.3 and n >= 3:
		pool.append(([
			"The dark reaches you too often. Shield (C) forgives one mistake, Dash (Shift) — one and a half.",
			"You take damage in %d%% of levels. Try holding Shield ready for tight corridors." % int(round((1.0 - agg.clean_pct) * 100.0)),
		] if en else [
			"Тьма слишком часто дотягивается до тебя. Щит (C) прощает одну ошибку, а Рывок (Shift) — полторы.",
			"Ты получаешь урон в %d%% уровней. Попробуй держать Щит на случай тесных коридоров." % int(round((1.0 - agg.clean_pct) * 100.0)),
		]))
	elif agg.clean_pct >= 0.7 and n >= 5:
		pool.append(([
			"You're almost untouchable — %d%% of levels without a scratch. Maybe it's time to risk it: carry Ember longer without banking." % int(round(agg.clean_pct * 100.0)),
			"The dark complains it can't touch you. Give it a chance — and take more Ember.",
		] if en else [
			"Ты почти неуловим — %d%% уровней без единой царапины. Может, пора рискнуть: неси Накал дольше, не банкуя." % int(round(agg.clean_pct * 100.0)),
			"Тьма жалуется, что не может тебя коснуться. Дай ей шанс — и забери больше Накала.",
		]))

	# Осколки
	if agg.avg_shards < 0.5 and n >= 3:
		pool.append(([
			"You leave more than half the shards lying in the dark. They're keys, Will and Ember. And they're bored.",
			"Shards whisper that you walk past. Collect three in a row without damage — and see what happens.",
		] if en else [
			"Ты оставляешь больше половины осколков лежать в темноте. Они — ключи, Воля и Накал. И они скучают.",
			"Осколки шепчут, что ты проходишь мимо. Собери три подряд без урона — и увидишь, что будет.",
		]))
	elif agg.avg_shards >= 0.9 and n >= 3:
		pool.append(([
			"You collect almost everything I hide. A collector. I'll have to hide better.",
			"%d%% of shards — you sweep me clean. Respect." % int(round(agg.avg_shards * 100.0)),
		] if en else [
			"Ты собираешь почти всё, что я прячу. Коллекционер. Мне приходится прятать лучше.",
			"%d%% осколков — ты выметаешь меня подчистую. Уважаю." % int(round(agg.avg_shards * 100.0)),
		]))

	# Динамика: последние 5 уровней против предыдущих
	if n >= 8:
		var recent_h := hist.slice(n - 5, n)
		var prev_h := hist.slice(maxi(0, n - 10), n - 5)
		var ra := _journal_aggregates(recent_h)
		var pa := _journal_aggregates(prev_h)
		if ra.avg_ratio < pa.avg_ratio - 0.15:
			pool.append(([
				"I compared your recent levels to your older ones: you've gotten noticeably faster. I've noted it.",
				"You're growing. Five levels ago you moved slower — now corridors part for you.",
			] if en else [
				"Я сравнил твои последние уровни с прежними: ты стал заметно быстрее. Я это запомнил.",
				"Ты растёшь. Пять уровней назад ты ходил медленнее — теперь коридоры сами расступаются.",
			]))
		elif ra.avg_ratio > pa.avg_ratio + 0.2:
			pool.append(([
				"Recent levels are harder for you than before. Tired? Stations are a refuge: Light doesn't fade there.",
				"I sense you've slowed down. Sometimes it helps to stand by a crystal and look around.",
			] if en else [
				"Последние уровни даются тяжелее прежних. Устал? Станции — убежище: Свет там не тает.",
				"Я чувствую, что ты сбавил шаг. Иногда полезно постоять у кристалла и оглядеться.",
			]))

	# Серия рангов
	if n >= 3:
		var last3_top := true
		for i in range(n - 3, n):
			var rk: String = str(hist[i].get("rank", "?"))
			if rk != "S" and rk != "A":
				last3_top = false
				break
		if last3_top:
			pool.append(([
				"Three high ranks in a row. You play as if you can see in the dark.",
				"S and A, one after another. I'm starting to build meaner walls — don't take it personally.",
			] if en else [
				"Три высоких ранга подряд. Ты играешь так, будто видишь в темноте.",
				"S и A идут один за другим. Я начинаю строить стены злее — не обижайся.",
			]))

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
		var nm: String = _skill_name(min_key)
		pool.append(([
			"«%s» gathers dust. I've seen sparks it saved the life of." % nm,
			"You barely call on «%s». Try it — it might be the tool you're missing." % nm,
		] if en else [
			"«%s» пылится без дела. Я видел огоньков, которым он спасал жизнь." % nm,
			"Ты почти не зовёшь «%s». Попробуй — возможно, это твой недостающий инструмент." % nm,
		]))
	if max_v >= 10 and max_key != "":
		var combo_hint := ""
		if en:
			match max_key:
				"flash": combo_hint = " By the way: Dash during Flash flies one and a half times farther."
				"dash":  combo_hint = " By the way: bursting into Dash during Flash makes a «light spear»."
				"sonar": combo_hint = " By the way: Sonar during Reveal covers twice the area and stuns enemies."
		else:
			match max_key:
				"flash": combo_hint = " К слову: Рывок во время Вспышки летит в полтора раза дальше."
				"dash":  combo_hint = " К слову: если сорваться в Рывок во время Вспышки — получится «световое копьё»."
				"sonar": combo_hint = " К слову: Сонар во время Озарения накрывает вдвое больше и глушит врагов."
		if combo_hint != "":
			pool.append(([
				"Your favorite tool is «%s», %d uses.%s" % [_skill_name(max_key), max_v, combo_hint],
			] if en else [
				"Твой любимый инструмент — «%s», %d применений.%s" % [_skill_name(max_key), max_v, combo_hint],
			]))

	# Выбираем случайные 3 наблюдения; если мало — добиваем слухом о секретах.
	pool.shuffle()
	for i in mini(3, pool.size()):
		var variants: Array = pool[i]
		out.append("◈ " + variants[randi() % variants.size()])
	if out.size() < 3 or randf() < 0.35:
		var rumors := _journal_rumors()
		out.append("◈ " + rumors[randi() % rumors.size()])
	return out

# =============================================================================
# БЕСТИАРИЙ «Досье лабиринта» — карточки врагов: портрет, лор, тактика, счётчики.
# Карточка скрыта («???») до первой погони (seen_tN), тактика открывается
# первым убийством (kill_tN). Данные — GameConfig.BESTIARY.
# =============================================================================

# С какого уровня появляется каждый тип (0-2 — с первых встреч, элита — глубины).
const _BESTIARY_APPEAR := [
	"обитает повсюду", "обитает повсюду", "обитает повсюду",
	"глубины 25+", "глубины 30+", "глубины 35+",
]
const _BESTIARY_APPEAR_EN := [
	"found everywhere", "found everywhere", "found everywhere",
	"depth 25+", "depth 30+", "depth 35+",
]

# [v5.2] Индекс типа BESTIARY -> id статьи Кодекса (codex.gd, sec=enemies) —
# порядок массивов совпадает (Блуждающий/Гончий/Циклит/Страж/Фантом/Пиявка =
# slow/fast/cyclic/sentinel/phantom/leech), но полагаться на совпадение
# порядка молча — источник будущего бага, поэтому маппинг явный.
const _BESTIARY_CODEX_IDS := ["slow", "fast", "cyclic", "sentinel", "phantom", "leech"]

func _bestiary_appear(i: int) -> String:
	return (_BESTIARY_APPEAR_EN if GameConfig.locale == "en" else _BESTIARY_APPEAR)[i]

func _build_bestiary(root: VBoxContainer) -> void:
	_bestiary_scroll = VBoxContainer.new()
	_bestiary_scroll.visible = false
	_bestiary_scroll.add_theme_constant_override("separation", 14)
	root.add_child(_bestiary_scroll)

	var title := Label.new()
	title.text = GameConfig.tt("Досье лабиринта", "Maze Dossier")
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	title.add_theme_font_size_override("font_size", 30)
	title.add_theme_color_override("font_color", Color(0.85, 0.9, 1.0))
	_bestiary_scroll.add_child(title)

	# Стрелки по бокам карточки — тот же паттерн, что у Справки/Дневника.
	var row := HBoxContainer.new()
	row.alignment = BoxContainer.ALIGNMENT_CENTER
	row.add_theme_constant_override("separation", 14)
	_bestiary_scroll.add_child(row)

	_bestiary_prev_btn = _make_button("‹", func() -> void: _populate_bestiary_slide(_bestiary_slide_idx - 1))
	_bestiary_prev_btn.custom_minimum_size = Vector2(52, 52)
	_bestiary_prev_btn.add_theme_font_size_override("font_size", 26)
	_bestiary_prev_btn.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	row.add_child(_bestiary_prev_btn)

	var card := PanelContainer.new()
	var sb := StyleBoxFlat.new()
	sb.bg_color = Color(0.045, 0.055, 0.10, 0.9)
	sb.set_corner_radius_all(12)
	sb.set_border_width_all(1)
	sb.border_color = Color(0.4, 0.5, 0.75, 0.5)
	sb.content_margin_left = 22
	sb.content_margin_right = 22
	sb.content_margin_top = 16
	sb.content_margin_bottom = 16
	card.add_theme_stylebox_override("panel", sb)
	row.add_child(card)

	# [CAROUSEL-BOUNDS] Тот же общий механизм, что у Дневника и Справки:
	# высота по контенту, пока он влезает в окно, дальше — прокрутка.
	# Бестиарий сейчас в границы укладывается, но карточки врагов растут
	# вместе с лором, и держать его на «пока влезает» — та же протухающая
	# подгонка, что уже подвела Справку.
	_bestiary_slide_scroll = _carousel_slide_scroll(700)
	card.add_child(_bestiary_slide_scroll)

	_bestiary_box = VBoxContainer.new()
	_bestiary_box.add_theme_constant_override("separation", 12)
	_bestiary_box.custom_minimum_size = Vector2(_carousel_content_width(_bestiary_slide_scroll, 700), 0)
	_bestiary_slide_scroll.add_child(_bestiary_box)

	_bestiary_next_btn = _make_button("›", func() -> void: _populate_bestiary_slide(_bestiary_slide_idx + 1))
	_bestiary_next_btn.custom_minimum_size = Vector2(52, 52)
	_bestiary_next_btn.add_theme_font_size_override("font_size", 26)
	_bestiary_next_btn.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	row.add_child(_bestiary_next_btn)

	_bestiary_nav_label = Label.new()
	_bestiary_nav_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_bestiary_nav_label.add_theme_font_size_override("font_size", 16)
	_bestiary_nav_label.add_theme_color_override("font_color", Color(0.6, 0.68, 0.8))
	_bestiary_scroll.add_child(_bestiary_nav_label)

func _on_open_bestiary() -> void:
	_bestiary_rebuild_slides()
	_populate_bestiary_slide(0)
	_hide_all_panels()
	_bestiary_scroll.visible = true
	if _back_btn:
		_back_btn.visible = true

# Карточка-панель бестиария (та же стилистика, что у дневника, но своя колонка).
func _bestiary_panel(title: String, accent: Color) -> VBoxContainer:
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
	_bestiary_box.add_child(panel)
	var box := VBoxContainer.new()
	box.add_theme_constant_override("separation", 5)
	panel.add_child(box)
	var l := Label.new()
	l.text = title
	l.add_theme_font_size_override("font_size", 21)
	l.add_theme_color_override("font_color", accent)
	box.add_child(l)
	return box

func _bestiary_line(box: VBoxContainer, t: String, col: Color = Color(0.78, 0.84, 0.95), fsize: int = 15, wrapc: bool = true) -> void:
	var l := Label.new()
	l.text = t
	l.add_theme_font_size_override("font_size", fsize)
	l.add_theme_color_override("font_color", col)
	if wrapc:
		l.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		l.custom_minimum_size.x = 600
	box.add_child(l)

# «Текущая угроза»: почему враги сейчас сильнее именно у этого игрока.
func _bestiary_threat_lines() -> Array:
	var en := GameConfig.locale == "en"
	var out: Array = []
	var lvl: int = GameConfig.max_unlocked_level
	var speed_pct := int(round(minf(float(lvl), 50.0) * 0.5))
	if speed_pct > 0:
		out.append(("Depth %d: the dark has sped up — enemy speed +%d%%." % [lvl, speed_pct]) if en else
			("Глубина %d: тьма разогналась — скорость врагов +%d%%." % [lvl, speed_pct]))
	match GameConfig.difficulty:
		0: out.append("Ember flame: enemies are lazier than usual (−15% speed)." if en else "Тлеющее пламя: враги ленивее обычного (−15% прыти).")
		2: out.append("Inferno flame: enemies are fiercer (+10% speed), no stations — the dark senses weakness." if en else "Пылающее пламя: враги злее (+10% прыти), станций нет — тьма чует слабость.")
	for i in GameConfig.RUN_SLOTS:
		var r = GameConfig.runs[i]
		if r != null and not bool(r.get("ended", false)) and float(r.get("ember_carried", 0)) > 0.0:
			out.append("In an Ember run you're carrying unbanked heat — the dark comes for its light. Bank it at altars." if en else
				"В забеге Накала ты несёшь незабанканный жар — тьма идёт на его свет. Банкуй на алтарях.")
			break
	if lvl >= 27:
		# [AUDIT 05.10.2026 №16] Пороги как в LADDER: Страж 27+, Фантом 33+, Пиявка 37+
		# (раньше здесь оставались старые 25/30/35).
		if en:
			out.append("You've gone deep: the maze unleashes elites — Guardians%s%s." % [
				", Phantoms" if lvl >= 33 else "", " and Leeches" if lvl >= 37 else ""])
		else:
			out.append("Ты спустился глубоко: лабиринт выпускает элиту — Стражей%s%s." % [
				", Фантомов" if lvl >= 33 else "", " и Пиявок" if lvl >= 37 else ""])
	if out.is_empty():
		out.append("The dark is still dozing: enemies at their normal strength. The deeper, the fiercer." if en else
			"Пока тьма дремлет: враги в своей обычной силе. Чем глубже — тем злее.")
	return out

# [BESTIARY-CAROUSEL] Пересобирает список слайдов — «Текущая угроза» первым,
# затем один слайд на каждого врага (заголовок слайда — имя, если встречен,
# иначе «???», чтобы не спойлерить в счётчике страниц).
func _bestiary_rebuild_slides() -> void:
	var s: Dictionary = GameConfig.stats
	_bestiary_slides = []
	_bestiary_slides.append({"title": GameConfig.tt("⚠ Текущая угроза", "⚠ Current threat"),
		"build": func() -> void: _bestiary_slide_threat(s)})
	for t in GameConfig.BESTIARY.size():
		var tt := t   # заморозить значение цикла для замыкания — иначе все билдеры увидят последнее t
		var seen := int(s.get("seen_t%d" % tt, 0))
		var title: String = GameConfig.bestiary_name(tt) if seen > 0 else "???"
		_bestiary_slides.append({"title": title,
			"build": func() -> void: _bestiary_slide_enemy(s, tt)})

# Перерисовать слайд idx (с зацикливанием). Заголовок — общий для всех слайдов.
func _populate_bestiary_slide(idx: int) -> void:
	if _bestiary_slides.is_empty():
		_bestiary_rebuild_slides()
	var n := _bestiary_slides.size()
	_bestiary_slide_idx = ((idx % n) + n) % n
	for c in _bestiary_box.get_children():
		c.queue_free()
	var slide: Dictionary = _bestiary_slides[_bestiary_slide_idx]
	var t := Label.new()
	t.text = str(slide["title"])
	t.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	t.add_theme_font_size_override("font_size", 22)
	t.add_theme_color_override("font_color", Color(0.85, 0.9, 1.0))
	_bestiary_box.add_child(t)
	(slide["build"] as Callable).call()
	_bestiary_nav_label.text = "%d / %d" % [_bestiary_slide_idx + 1, n]
	_refit_carousel_deferred(_bestiary_slide_scroll, _bestiary_box)

# --- Слайд «Текущая угроза»: сколько досье открыто + живое объяснение силы врагов.
func _bestiary_slide_threat(s: Dictionary) -> void:
	var known := 0
	for t in GameConfig.BESTIARY.size():
		if int(s.get("seen_t%d" % t, 0)) > 0:
			known += 1
	var sub := Label.new()
	sub.text = GameConfig.tt("Открыто досье: %d из %d. Встреча открывает имя, победа — слабости.",
		"Dossiers unlocked: %d of %d. An encounter reveals the name, a victory — its weaknesses.") % [known, GameConfig.BESTIARY.size()]
	sub.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	sub.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	sub.add_theme_font_size_override("font_size", 14)
	sub.add_theme_color_override("font_color", Color(0.6, 0.68, 0.8))
	_bestiary_box.add_child(sub)

	var threat := _bestiary_panel(GameConfig.tt("⚠ Текущая угроза", "⚠ Current threat"), Color(1.0, 0.55, 0.25))
	for line in _bestiary_threat_lines():
		_bestiary_line(threat, str(line), Color(0.95, 0.85, 0.7))

# --- Слайд одного врага: свой слайд на каждого — просторнее, крупнее портрет.
func _bestiary_slide_enemy(s: Dictionary, t: int) -> void:
	var d: Dictionary = GameConfig.BESTIARY[t]
	var seen := int(s.get("seen_t%d" % t, 0))
	var kills := int(s.get("kill_t%d" % t, 0))
	var hits := int(s.get("hit_t%d" % t, 0))
	var col: Color = d["color"]

	if seen <= 0:
		# Неизвестный: силуэт и намёк, где искать.
		var lock := _bestiary_panel("???", Color(0.35, 0.4, 0.5))
		var lrow := HBoxContainer.new()
		lrow.add_theme_constant_override("separation", 16)
		lock.add_child(lrow)
		var sil := TextureRect.new()
		sil.texture = MazeTextures.make_enemy(t, 40)
		# [BESTIARY-CAROUSEL] make_enemy(40) генерит текстуру ~172×172 (радиус —
		# не итоговый пиксельный размер, текстура больше из-за свечения).
		# STRETCH_KEEP_CENTERED не масштабирует — рисует текстуру в РЕАЛЬНОМ
		# размере поверх рамки, и она вылезает за края 90×90 (заметно только
		# тут, где рядом всего одна строка текста — со старым радиусом 26
		# текстура была меньше рамки, и баг был не виден). KEEP_ASPECT_CENTERED
		# реально уменьшает картинку под рамку. expand_mode нужен, чтобы
		# custom_minimum_size вообще мог сжать control ниже размера текстуры.
		sil.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
		sil.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		sil.custom_minimum_size = Vector2(90, 90)
		sil.modulate = Color(0.06, 0.07, 0.1)   # чёрный силуэт
		lrow.add_child(sil)
		var lv := VBoxContainer.new()
		lrow.add_child(lv)
		_bestiary_line(lv, GameConfig.tt("Ещё не встречен (%s).", "Not encountered yet (%s).") % _bestiary_appear(t), Color(0.5, 0.55, 0.65), 16)
		# Текст короче иконки (одна строка) — без этого строка ровно 90px
		# высотой, иконка упирается точно в нижний паддинг панели, и её мягкое
		# свечение визуально задевает рамку. Небольшой запас снизу решает это.
		var spacer := Control.new()
		spacer.custom_minimum_size = Vector2(0, 10)
		lock.add_child(spacer)
		return

	var box := _bestiary_panel(GameConfig.bestiary_name(t), col)
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 16)
	box.add_child(row)

	# Портрет крупнее, чем в старой построчной вёрстке (26→40) — свой слайд, места хватает.
	var ic := TextureRect.new()
	ic.texture = MazeTextures.make_enemy(t, 40)
	ic.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED   # [BESTIARY-CAROUSEL] см. sil выше
	ic.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	ic.custom_minimum_size = Vector2(90, 90)
	row.add_child(ic)

	var body := VBoxContainer.new()
	body.add_theme_constant_override("separation", 6)
	body.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	row.add_child(body)

	_bestiary_line(body, GameConfig.bestiary_lore(t), Color(0.75, 0.8, 0.92), 16)
	# [BUGFIX v5.2, дублирование с Кодексом] Раньше здесь пересказывалась
	# «Тактика» — тот же текст (HP, слабость, как бить), что статьи Кодекса
	# «Враги» дают бесплатно и сразу (см. codex.gd, sec=enemies). Хуже того,
	# тут он был ЗАПЕРТ за первым убийством, а в Кодексе — нет: победа
	# награждала игрока информацией, которую он мог прочитать пятью минутами
	# раньше. Бестиарий и Кодекс должны отвечать на разные вопросы: Кодекс —
	# «как это работает», Бестиарий — «как у МЕНЯ с этим конкретным врагом».
	# Личный счёт ниже — то, что Кодекс дать не может в принципе.
	if seen > 0:
		var eff := 100.0 * float(kills) / float(maxi(seen, 1))
		_bestiary_line(body, GameConfig.tt("Твой счёт: %d побед из %d встреч (%d%%)", "Your record: %d wins of %d encounters (%d%%)") % [kills, seen, int(round(eff))],
			Color(0.6, 1.0, 0.7) if kills > 0 else Color(0.85, 0.75, 0.5), 15)
	var codex_btn := _make_button(GameConfig.tt("Как бороться — Кодекс", "How to fight it — Codex"), func() -> void: _codex_open_by_id("enemies", _BESTIARY_CODEX_IDS[t]))
	codex_btn.custom_minimum_size = Vector2(0, 32)
	codex_btn.add_theme_font_size_override("font_size", 13)
	body.add_child(codex_btn)
	_bestiary_line(body, GameConfig.tt("Встреч: %d   •   Побеждено: %d   •   Ударов по тебе: %d   •   %s", "Encounters: %d   •   Defeated: %d   •   Hits on you: %d   •   %s") % [seen, kills, hits, _bestiary_appear(t)],
		Color(0.55, 0.62, 0.75), 13)

# Учебная программа «Пути мастерства»: упорядоченные уроки от выживания до
# Пылающего. Каждый — проверка по статистике + конкретный совет «как взять».
func _coach_steps(s: Dictionary, hist: Array) -> Array:
	var clean_done := false
	var fast_done := false
	var blazing_done := false
	for e in hist:
		if bool(e.get("no_dmg", false)):
			clean_done = true
		if float(e.get("time", 1e9)) <= float(e.get("par", 0.0)):
			fast_done = true
		if int(e.get("diff", 1)) == 2:
			blazing_done = true
	var best_mastery := 0
	for id in ["flash", "dash", "smother", "mark", "sonar", "shield", "guide", "reveal", "pulse", "mirage", "breach", "chrono"]:
		best_mastery = maxi(best_mastery, GameConfig.mastery(id))
	var lvls := int(s.get("levels_cleared", 0))
	var shards := int(s.get("shards_total", 0))
	var kills := int(s.get("enemies_killed", 0))
	var ranks_good := int(s.get("rank_S", 0)) + int(s.get("rank_A", 0))
	var depth := int(s.get("best_depth", 0))
	var en := GameConfig.locale == "en"
	if en:
		return [
			{"title": "Survival: clear 3 levels", "done": lvls >= 3,
			 "progress": "%d/3" % mini(lvls, 3),
			 "how": "stick to energy crystals — your light doesn't fade near them, it's a refuge and a checkpoint."},
			{"title": "Collector: 25 shards", "done": shards >= 25,
			 "progress": "%d/25" % mini(shards, 25),
			 "how": "shards are keys, Will and clues about the exit. Detour for a shard: it pays off."},
			{"title": "Fighter: defeat 8 enemies", "done": kills >= 8,
			 "progress": "%d/8" % mini(kills, 8),
			 "how": "dash THROUGH an enemy — a tackle with no damage to you; flash point-blank also hits. A frozen enemy takes +1 damage."},
			{"title": "Shadow: clear a level without damage", "done": clean_done,
			 "progress": "not yet" if not clean_done else "done",
			 "how": "Smother (R) dims you to a spark — enemies lose your trail. Freeze, let the patrol pass, move on."},
			{"title": "Wind: clear a level faster than par time", "done": fast_done,
			 "progress": "not yet" if not fast_done else "done",
			 "how": "Guide (G) shows the path to the exit, dash speeds you up. Decide ahead: this level is for speed."},
			{"title": "Straight-A: get rank A or S", "done": ranks_good > 0,
			 "progress": "%d" % ranks_good,
			 "how": "rank formula: speed + no losses + held ground + skills (shards don't affect the rank). The breakdown is on the victory screen."},
			{"title": "Master: bring any skill to 3★", "done": best_mastery >= 3,
			 "progress": "best — %d★" % best_mastery,
			 "how": "mastery grows from uses (10 = ★). Or buy an upgrade for SP in the skill shop."},
			{"title": "Apex: find 5 of the 7 active skills", "done": bool(GameConfig.skills_unlocked.get("apex", false)),
			 "progress": "",
			 "how": "skills come as relics found in the maze (see «What unlocks next» in the Journal). The fifth one unlocks Apex (H) on its own; every later relic adds a new form to the wheel."},
			{"title": "Firebearer: depth 10 in «Ember»", "done": depth >= 10,
			 "progress": "%d/10" % mini(depth, 10),
			 "how": "don't be greedy: bank Ember at every altar. Carried heat draws the dark — banked doesn't."},
			{"title": "Inferno: clear a level on the highest difficulty", "done": blazing_done,
			 "progress": "not yet" if not blazing_done else "done",
			 "how": "no stations — light only from shards (double capacity). Plan your route by shards and keep moving."},
		]
	return [
		{"title": "Выживание: пройди 3 уровня", "done": lvls >= 3,
		 "progress": "%d/3" % mini(lvls, 3),
		 "how": "держись энергокристаллов — возле них свет не гаснет, это убежище и точка возврата."},
		{"title": "Собиратель: 25 осколков", "done": shards >= 25,
		 "progress": "%d/25" % mini(shards, 25),
		 "how": "осколки — это и ключи, и Воля, и улики о выходе. Сверни с прямого пути ради осколка: он окупается."},
		{"title": "Боец: победи 8 врагов", "done": kills >= 8,
		 "progress": "%d/8" % mini(kills, 8),
		 "how": "рывок СКВОЗЬ врага — таран без урона по тебе; вспышка в упор тоже бьёт. Замороженный враг ловит +1 урона."},
		{"title": "Тень: пройди уровень без урона", "done": clean_done,
		 "progress": "ещё нет" if not clean_done else "есть",
		 "how": "Тление (R) гасит тебя до искры — враги теряют след. Замри, пропусти патруль, иди дальше."},
		{"title": "Ветер: пройди уровень быстрее пар-тайма", "done": fast_done,
		 "progress": "ещё нет" if not fast_done else "есть",
		 "how": "Искра (G) показывает путь к выходу, рывок ускоряет. Реши заранее: этот уровень — на скорость."},
		{"title": "Отличник: возьми ранг A или S", "done": ranks_good > 0,
		 "progress": "%d" % ranks_good,
		 "how": "формула ранга: скорость + без потерь + своя земля + навыки (осколки на ранг не влияют). Расшифровка — на экране победы."},
		{"title": "Мастер: доведи любой навык до 3★", "done": best_mastery >= 3,
		 "progress": "лучший — %d★" % best_mastery,
		 "how": "мастерство растёт от применений (10 = ★). Или купи усиление за SP в магазине навыков."},
		{"title": "Апекс: найди 5 из 7 активных навыков", "done": bool(GameConfig.skills_unlocked.get("apex", false)),
		 "progress": "",
		 "how": "навыки приходят реликвиями, найденными в лабиринте (Дневник → «Что откроется дальше»). Пятый откроет Апекс (H) сам, а каждая следующая реликвия добавит в колесо новую форму."},
		{"title": "Огненосец: глубина 10 в «Накале»", "done": depth >= 10,
		 "progress": "%d/10" % mini(depth, 10),
		 "how": "не жадничай: банкуй Накал на каждом алтаре. Несомый жар притягивает тьму — банк нет."},
		{"title": "Пылающий: пройди уровень на высшей сложности", "done": blazing_done,
		 "progress": "ещё нет" if not blazing_done else "есть",
		 "how": "станций нет — свет только из осколков (запас ×2). Планируй маршрут по осколкам и не стой на месте."},
	]

func _on_open_journal() -> void:
	_journal_rebuild_slides()
	_populate_journal_slide(0)
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
	_mode_scroll.custom_minimum_size = Vector2(980, 520)
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
	# [v5.7, §76-2] Разделы открываются по мере игры, а не все с первой минуты:
	# новичку с первого экрана достаточно «Играть» и «Обучения».
	var prog: int = GameConfig.max_unlocked_level
	for pair in [[GameConfig.t("top_shop"), _on_open_shop, 4], [GameConfig.t("top_tutorial"), _on_open_tutorial, 1], [GameConfig.t("top_journal"), _on_open_journal, 3], [GameConfig.t("top_bestiary"), _on_open_bestiary, 4]]:
		if prog < int(pair[2]):
			continue
		var tb := _make_button(str(pair[0]), pair[1])
		tb.custom_minimum_size = Vector2(200, 44)
		tb.add_theme_font_size_override("font_size", 18)
		top_row.add_child(tb)

	# --- Карточки-режимы. FlowContainer вместо HBox: на узких окнах карточки
	# переносятся на вторую строку вместо обрезания краем экрана (см.
	# GAMEDESIGN.md, «Известная проблема: границы экрана») — стало актуальнее
	# с добавлением 4-й карточки «Логово».
	# Все 4 карточки — в один ряд (не переносить кроме совсем узких окон):
	# HFlowContainer остаётся страховкой на маленьких экранах, но при ширине
	# _mode_scroll (980px) четыре карточки по 180px + отступы влезают в ряд.
	var cards := HFlowContainer.new()
	cards.alignment = FlowContainer.ALIGNMENT_CENTER
	cards.add_theme_constant_override("h_separation", 14)
	cards.add_theme_constant_override("v_separation", 14)
	_mode_box.add_child(cards)

	var cur := clampi(GameConfig.level, 1, GameConfig.max_unlocked_level)
	cards.add_child(_mode_card(GameConfig.t("mode_levels_title"),
		GameConfig.t("mode_levels_desc") % cur,
		Color(0.45, 0.75, 1.0),
		func() -> void:
			GameConfig.active_run = -1
			_on_play(cur)))

	# [GAMEDESIGN §18] Последовательное открытие режимов — новичку видна только
	# «Уровни», остальные три появляются по мере прохождения кампании (пороги —
	# GameConfig.MODE_UNLOCK_*), вместо того чтобы вываливать все 4 сразу.
	# [v5.7] Закрытые режимы не выстраиваются рядом с замками все сразу: виден
	# только БЛИЖАЙШИЙ — как цель, а не как стена меню.
	var next_lock := ""
	for pair in [["daily", GameConfig.MODE_UNLOCK_DAILY, GameConfig.is_daily_unlocked()], ["ember", GameConfig.MODE_UNLOCK_EMBER, GameConfig.is_ember_unlocked()], ["caves", GameConfig.MODE_UNLOCK_CAVES, GameConfig.is_caves_unlocked()], ["lair", GameConfig.MODE_UNLOCK_LAIR, GameConfig.is_lair_unlocked()]]:
		if not bool(pair[2]) and (next_lock == "" or int(pair[1]) < GameConfig.ladder_level("mode_" + next_lock)):
			next_lock = str(pair[0])
	if GameConfig.is_ember_unlocked():
		cards.add_child(_mode_card(GameConfig.t("mode_ember_title"),
			GameConfig.t("mode_ember_desc"),
			Color(1.0, 0.55, 0.25), _on_open_runs))
	elif next_lock == "ember":
		cards.add_child(_locked_mode_card(GameConfig.t("mode_ember_title"), GameConfig.MODE_UNLOCK_EMBER - 1))

	if GameConfig.is_daily_unlocked():
		var streak := GameConfig.daily_streak()
		cards.add_child(_mode_card(GameConfig.t("mode_daily_title"),
			"%s\n\n%s%s" % [GameConfig.t("mode_daily_desc"), GameConfig.today_str(),
				("\n🔥 %d" % streak) if streak >= 2 else ""],
			Color(1.0, 0.85, 0.35), _on_open_daily))
	elif next_lock == "daily":
		cards.add_child(_locked_mode_card(GameConfig.t("mode_daily_title"), GameConfig.MODE_UNLOCK_DAILY - 1))

	if GameConfig.is_caves_unlocked():
		cards.add_child(_mode_card(GameConfig.t("mode_caves_title"),
			GameConfig.t("mode_caves_desc") % [GameConfig.caves_max_unlocked, GameConfig.CAVES_LEVELS],
			Color(0.75, 0.6, 0.45), _on_open_caves_select))
	elif next_lock == "caves":
		cards.add_child(_locked_mode_card(GameConfig.t("mode_caves_title"), GameConfig.MODE_UNLOCK_CAVES - 1))

	if GameConfig.is_lair_unlocked():
		cards.add_child(_mode_card(GameConfig.t("mode_lair_title"),
			GameConfig.t("mode_lair_desc") % [GameConfig.lair_max_unlocked, GameConfig.LAIR_LEVELS],
			Color(1.0, 0.3, 0.35), _on_open_lair_select))
	elif next_lock == "lair":
		cards.add_child(_locked_mode_card(GameConfig.t("mode_lair_title"), GameConfig.MODE_UNLOCK_LAIR - 1))

	# --- Одна строка: выбор уровня + сложность ---
	var opts_row := HBoxContainer.new()
	opts_row.alignment = BoxContainer.ALIGNMENT_CENTER
	opts_row.add_theme_constant_override("separation", 12)
	_mode_box.add_child(opts_row)

	var pick_btn := _make_button(GameConfig.t("pick_level") % GameConfig.max_unlocked_level, _on_open_level_select)
	pick_btn.visible = prog >= 3
	pick_btn.custom_minimum_size = Vector2(220, 42)
	pick_btn.add_theme_font_size_override("font_size", 16)
	opts_row.add_child(pick_btn)

	var diff_lbl := Label.new()
	diff_lbl.visible = prog >= 5
	diff_lbl.text = GameConfig.t("difficulty")
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
	diff_desc.text = GameConfig.diff_desc(GameConfig.difficulty)

	var diff_colors := [Color(0.55, 0.8, 1.0), Color(1.0, 0.8, 0.35), Color(1.0, 0.42, 0.32)]
	var diff_marks := ["◦ ", "● ", "☀ "]
	var diff_btns: Array = []
	for i in 3:
		var db := Button.new()
		db.text = diff_marks[i] + GameConfig.diff_name(i)
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
			diff_desc.text = GameConfig.diff_desc(idx)
			_toast("%s: %s" % [GameConfig.t("difficulty").trim_suffix(":"), GameConfig.diff_name(idx)])
		)
		db.visible = prog >= 5
		opts_row.add_child(db)
	diff_desc.visible = prog >= 5
	_mode_box.add_child(diff_desc)

# Большая квадратная карточка режима: цветная рамка, название, описание.
# ОСОЗНАННОЕ ИСКЛЮЧЕНИЕ из правила UIStyle (AUDIT 05.10.2026 №7): это не кнопка
# действия, а крупная цветная карточка-плитка со своим визуалом (как
# _make_touch_button) — не стилизовать через UIStyle.style_button.
func _mode_card(title: String, sub: String, accent: Color, cb: Callable) -> Button:
	var b := Button.new()
	# 4 карточки в один ряд при ширине _mode_scroll (980px): 4×182 + 3×14 = 770.
	b.custom_minimum_size = Vector2(182, 250)
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
	# Карточка «оживает» под курсором: слегка приподнимается. Внутри
	# ScrollContainer масштаб запрещён (клиппинг краёв — см. GAMEDESIGN.md).
	b.mouse_entered.connect(func() -> void:
		if _inside_scroll(b) or GameConfig.touch_ui():
			return
		b.pivot_offset = b.size * 0.5
		var tw := b.create_tween()
		tw.tween_property(b, "scale", Vector2(1.04, 1.04), 0.14) \
			.set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT))
	b.mouse_exited.connect(func() -> void:
		if b.scale == Vector2.ONE:
			return
		var tw := b.create_tween()
		tw.tween_property(b, "scale", Vector2.ONE, 0.14) \
			.set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT))

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
	# Автоперенос заголовка: «СПУСК ДНЯ» иначе не влезает в узкую карточку
	# (4 карточки в ряд — см. GAMEDESIGN.md, «Известная проблема: границы экрана»).
	t.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	t.add_theme_font_size_override("font_size", 20)
	t.add_theme_color_override("font_color", accent)
	t.add_theme_constant_override("outline_size", 5)
	t.add_theme_color_override("font_outline_color", Color(accent.r * 0.25, accent.g * 0.25, accent.b * 0.25, 0.9))
	v.add_child(t)

	var s := Label.new()
	s.text = sub
	s.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	s.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	s.custom_minimum_size = Vector2(150, 0)
	s.add_theme_font_size_override("font_size", 12)
	s.add_theme_color_override("font_color", Color(0.72, 0.78, 0.9))
	v.add_child(s)
	return b

# [GAMEDESIGN §18] Карточка ещё не открытого режима — тот же _mode_card
# (единый стиль), только приглушённая (серый акцент + прозрачность) и с
# заголовком-подсказкой вместо описания; клик — тост с условием, а не переход.
func _locked_mode_card(title: String, need_level: int) -> Button:
	var grey := Color(0.42, 0.45, 0.5)
	var hint := GameConfig.tt("🔒 Откроется после уровня %d", "🔒 Unlocks after level %d") % need_level
	var card := _mode_card(title, hint, grey, func() -> void:
		_toast(GameConfig.tt("Пока закрыто — пройди уровень %d", "Still locked — clear level %d") % need_level))
	card.modulate = Color(1.0, 1.0, 1.0, 0.55)
	return card

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
	_daily_box = ScrollContainer.new()
	_daily_box.visible = false
	_daily_box.custom_minimum_size = Vector2(620, 480)
	_daily_box.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	root.add_child(_daily_box)

	_daily_inner = VBoxContainer.new()
	_daily_inner.add_theme_constant_override("separation", 10)
	_daily_inner.custom_minimum_size = Vector2(600, 0)
	_daily_box.add_child(_daily_inner)

func _populate_daily() -> void:
	for c in _daily_inner.get_children():
		c.queue_free()

	var en := GameConfig.locale == "en"
	var title := Label.new()
	title.text = GameConfig.tt("Спуск дня — %s", "Daily Dive — %s") % GameConfig.today_str()
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	title.add_theme_font_size_override("font_size", 28)
	title.add_theme_color_override("font_color", Color(1.0, 0.85, 0.3))
	_daily_inner.add_child(title)

	var sub := Label.new()
	sub.text = "Every day the maze is the same for everyone: same layout, same enemies.\nOne attempt. Ember rules: 3 lives for the whole descent, death ends it." if en else \
		"Каждый день лабиринт один для всех: тот же лабиринт, те же враги.\nОдна попытка. Правила Накала: 3 жизни на весь спуск, смерть — конец."
	sub.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	sub.add_theme_font_size_override("font_size", 15)
	sub.add_theme_color_override("font_color", Color(0.7, 0.76, 0.88))
	_daily_inner.add_child(sub)

	var streak := GameConfig.daily_streak()
	if streak >= 2:
		var sl := Label.new()
		sl.text = ("🔥 Streak: %d days in a row" % streak) if en else ("🔥 Серия: %d %s подряд" % [streak, _plural(streak, "день", "дня", "дней")])
		sl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		sl.add_theme_font_size_override("font_size", 17)
		sl.add_theme_color_override("font_color", Color(1.0, 0.62, 0.25))
		_daily_inner.add_child(sl)

	# --- Состояние сегодняшнего дня ---
	if GameConfig.daily_resumable():
		var msg := Label.new()
		msg.text = (("Today's descent isn't finished — depth %d.") if en else ("Сегодняшний спуск не завершён — глубина %d.")) % int(GameConfig.runs[GameConfig.DAILY_SLOT].get("level", 1))
		msg.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		msg.add_theme_font_size_override("font_size", 17)
		msg.add_theme_color_override("font_color", Color(0.8, 0.9, 1.0))
		_daily_inner.add_child(msg)
		_daily_inner.add_child(_make_button(GameConfig.tt("Продолжить спуск", "Resume the descent"), func() -> void:
			GameConfig.resume_daily_run()
			get_tree().change_scene_to_file("res://main.tscn")))
	elif GameConfig.daily_played_today() and not GameConfig.test_mode:
		var today := GameConfig.today_str()
		var res: Dictionary = {}
		for e in GameConfig.daily_history:
			if str(e.get("date", "")) == today:
				res = e
		var msg := Label.new()
		msg.text = (("Today you already descended: depth %d, Ember %d.\nThe maze will change shape at midnight — come back tomorrow.") if en else
			("Сегодня ты уже спускался: глубина %d, Накал %d.\nЛабиринт сменит облик в полночь — возвращайся завтра.")) % [
			int(res.get("depth", 1)), int(res.get("ember", 0))]
		msg.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		msg.add_theme_font_size_override("font_size", 17)
		msg.add_theme_color_override("font_color", Color(0.8, 0.9, 1.0))
		_daily_inner.add_child(msg)
	else:
		if GameConfig.daily_played_today():
			var tst := Label.new()
			tst.text = "(test mode: attempt limit disabled)" if en else "(тест-режим: лимит попыток отключён)"
			tst.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
			tst.add_theme_font_size_override("font_size", 14)
			tst.add_theme_color_override("font_color", Color(1.0, 0.6, 0.2))
			_daily_inner.add_child(tst)
		_daily_inner.add_child(_make_button(GameConfig.tt("Начать спуск", "Start the descent"), func() -> void:
			GameConfig.start_daily_run()
			get_tree().change_scene_to_file("res://main.tscn")))

	# --- Последние дни ---
	if not GameConfig.daily_history.is_empty():
		var hl := Label.new()
		hl.text = GameConfig.tt("Последние дни", "Recent days")
		hl.add_theme_font_size_override("font_size", 20)
		hl.add_theme_color_override("font_color", Color(0.85, 0.9, 1.0))
		_daily_inner.add_child(hl)
		var hist: Array = GameConfig.daily_history
		var start := maxi(0, hist.size() - 7)
		for i in range(hist.size() - 1, start - 1, -1):
			var e: Dictionary = hist[i]
			var l := Label.new()
			l.text = GameConfig.tt("%s   ·   глубина %d   ·   Накал %d", "%s   ·   depth %d   ·   Ember %d") % [
				str(e.get("date", "?")), int(e.get("depth", 1)), int(e.get("ember", 0))]
			l.add_theme_font_size_override("font_size", 15)
			l.add_theme_color_override("font_color", Color(0.72, 0.78, 0.9))
			_daily_inner.add_child(l)

func _on_open_daily() -> void:
	_populate_daily()
	_hide_all_panels()
	_daily_box.visible = true
	_back_btn.visible = true

# ── КОДЕКС (GAMEDESIGN §30) ──────────────────────────────────────────────────
# Двухколоночный экран вместо прежней карусели слайдов Справки. Слева —
# навигация: заголовки разделов и кнопки статей (одним списком, как в кодексах
# современных игр). Справа — статья: заголовок, картинка, текст абзацами.
#
# Почему не карусель: слайд обязан влезать в один экран, поэтому текст
# приходилось резать до трёх строк — «прочитать и разобраться» по такому
# формату невозможно. У статьи есть своя прокрутка, поэтому её можно писать
# нормальной длины, а навигация при этом всегда на виду.

const CODEX_NAV_W := 288
const CODEX_ART_W := 604

func _build_codex(root: VBoxContainer) -> void:
	_codex_root = HBoxContainer.new()
	_codex_root.visible = false
	_codex_root.add_theme_constant_override("separation", 16)
	root.add_child(_codex_root)

	# --- левая колонка: список разделов и статей ---
	var nav_panel := PanelContainer.new()
	nav_panel.add_theme_stylebox_override("panel", _codex_panel_style())
	_codex_root.add_child(nav_panel)

	_codex_nav = ScrollContainer.new()
	_codex_nav.custom_minimum_size = Vector2(CODEX_NAV_W, 0)
	_codex_nav.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	_codex_nav.vertical_scroll_mode = ScrollContainer.SCROLL_MODE_AUTO
	nav_panel.add_child(_codex_nav)

	_codex_nav_box = VBoxContainer.new()
	_codex_nav_box.add_theme_constant_override("separation", 4)
	_codex_nav_box.custom_minimum_size = Vector2(_carousel_content_width(_codex_nav, CODEX_NAV_W), 0)
	_codex_nav.add_child(_codex_nav_box)

	# --- правая колонка: тело статьи ---
	var art_panel := PanelContainer.new()
	art_panel.add_theme_stylebox_override("panel", _codex_panel_style())
	_codex_root.add_child(art_panel)

	_codex_article = ScrollContainer.new()
	_codex_article.custom_minimum_size = Vector2(CODEX_ART_W, 0)
	_codex_article.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	_codex_article.vertical_scroll_mode = ScrollContainer.SCROLL_MODE_AUTO
	art_panel.add_child(_codex_article)

	_codex_body = VBoxContainer.new()
	_codex_body.add_theme_constant_override("separation", 12)
	_codex_body.custom_minimum_size = Vector2(_carousel_content_width(_codex_article, CODEX_ART_W), 0)
	_codex_article.add_child(_codex_body)

	_codex_rebuild_nav()

func _codex_panel_style() -> StyleBoxFlat:
	var sb := StyleBoxFlat.new()
	sb.bg_color = Color(0.045, 0.055, 0.10, 0.9)
	sb.set_corner_radius_all(12)
	sb.set_border_width_all(1)
	sb.border_color = Color(0.4, 0.5, 0.75, 0.5)
	sb.content_margin_left = 14
	sb.content_margin_right = 14
	sb.content_margin_top = 12
	sb.content_margin_bottom = 12
	return sb

# [GAMEDESIGN §38] Статья «Лестница открытий» — единственное место, где игрок
# видит ВЕСЬ порядок ввода механик разом: что уже открылось, что следующее и на
# каком уровне. Строится из GameConfig.LADDER, а не из литерала: реестр там
# один, и статья не может разъехаться с реальными гейтами.
# Уже пройденное показывается с описанием, будущее — только именем и уровнем:
# ответ на вопрос «откуда это взялось» нужен, спойлер на 30 уровней вперёд — нет.
func _codex_ladder_article() -> Dictionary:
	var en := GameConfig.locale == "en"
	var lvl: int = GameConfig.max_unlocked_level
	var lines: Array = []
	lines.append(("Every mechanic in «Levels» enters the game at a fixed level, and always inside the stretch of the biome that owns it. Here is what has arrived so far, in order; what comes next is not shown until you get there."
		if en else
		"Каждая механика «Уровней» входит в игру на фиксированном уровне — и всегда внутри полосы того биома, которому она принадлежит. Здесь то, что уже пришло, по порядку; что дальше — не показывается, пока не дойдёшь."))
	lines.append("")
	var ahead := 0
	for e in GameConfig.LADDER:
		var el: int = int(e["level"])
		var nm: String = str(e["name_en"]) if en else str(e["name"])
		if lvl >= el:
			lines.append("✓  %d · %s" % [el, nm])
			lines.append("     " + (str(e["what_en"]) if en else str(e["what"])))
			lines.append("")
		else:
			ahead += 1
	if ahead > 0:
		lines.append(("→  %d more to come" if en else "→  впереди ещё %d") % ahead)
	var title: String = "The ladder of discovery" if en else "Лестница открытий"
	var body: String = "\n".join(lines)
	return {
		"sec": "progress", "id": "ladder", "fig": "ladder",
		"title": title, "title_en": title,
		"body": body, "body_en": body,
	}

# Полный плоский список статей: данные из codex.gd плюс лестница и версии.
func _codex_all_articles() -> Array:
	var out: Array = []
	for a in Codex.ARTICLES:
		if Codex.is_unlocked(str(a["sec"]), str(a["id"])):
			out.append(a)
	if Codex.is_unlocked("progress", "ladder"):
		out.append(_codex_ladder_article())
	return out

# Всего статей в Кодексе (с ещё закрытыми) — для счётчиков «открыто / всего».
func _codex_total_in(sid: String) -> int:
	var n := 0
	for a in Codex.ARTICLES:
		if str(a["sec"]) == sid:
			n += 1
	if sid == "progress":
		n += 1   # «Лестница открытий» собирается в коде
	return n

# Ключ статьи для отметки «прочитано» — сквозной по всем источникам
# (codex.gd, лестница, версии): у каждой статьи есть sec и id.
# Открыть статью Кодекса по (sec,id) — переход «Бестиарий -> Кодекс», чтобы
# не дублировать механику текстом, а вести к единственному месту, где она
# описана. Открывает соответствующий раздел свёрнутым в нужное состояние.
func _codex_open_by_id(sec: String, id: String) -> void:
	_hide_all_panels()
	_set_header_compact(true)
	if _codex_entries.is_empty():
		_codex_rebuild_nav()
	for i in _codex_entries.size():
		var a: Dictionary = _codex_entries[i]
		if str(a.get("sec", "")) == sec and str(a.get("id", "")) == id:
			_codex_root.visible = true
			_back_btn.visible = true
			_codex_open(i)
			return
	# Статья ещё закрыта (или её нет): открываем Кодекс на том, что есть.
	_codex_root.visible = true
	_back_btn.visible = true
	_codex_open(clampi(_codex_idx, 0, maxi(_codex_entries.size() - 1, 0)))

# Кнопка «Кодекс» в главном меню: точка и число, пока есть открытые, но
# непрочитанные статьи — так видно, что игра открыла что-то новое.
var _codex_menu_btn: Button

func _refresh_codex_badge() -> void:
	if _codex_menu_btn == null or not is_instance_valid(_codex_menu_btn):
		return
	var unread := 0
	for a in _codex_all_articles():
		if not GameConfig.codex_is_read(_codex_key(a)):
			unread += 1
	var base: String = GameConfig.t("menu_help")
	_codex_menu_btn.text = base if unread == 0 else "%s   •%d" % [base, unread]

func _codex_key(art: Dictionary) -> String:
	return "%s|%s" % [str(art.get("sec", "?")), str(art.get("id", "?"))]

# [v5.1] «Читать сейчас» — до трёх НЕПРОЧИТАННЫХ статей, отобранных по
# состоянию игрока. Причина существования: 88 пунктов навигации не отвечали
# на вопрос «с чего начать», а «читать всё подряд» — не чтение, а обязанность.
# Порядок приоритета намеренно такой:
#   1) свежая версия — единственное, что устаревает само и потому срочно;
#   2) основы, пока не прочитаны, — новичку больше нечего спросить;
#   3) механики, которые лестница уже открыла игроку, — они про его СЕЙЧАС.
func _codex_rebuild_nav() -> void:
	for c in _codex_nav_box.get_children():
		c.queue_free()
	_codex_entries = _codex_all_articles()
	_codex_buttons = []
	_codex_buttons.resize(_codex_entries.size())

	# [BUGFIX v5.3] Блок «Читать сейчас» УБРАН. Он подбирался из непрочитанного,
	# а прочитанной становилась каждая открытая статья — то есть содержимое
	# верхних трёх кнопок менялось от использования самого блока. Игрок жал «во
	# вторую кнопку» и каждый раз попадал в другую статью; жалоба на «меню
	# перескакивает» пришла трижды. Замер показал, что дрожания кадров нет
	# (0.01% пикселей между кадрами) — «перескакивало» именно СОДЕРЖИМОЕ.
	# Навигация теперь полностью предсказуема: десять неподвижных разделов,
	# раскрыт ровно один. На вопрос «что я ещё не читал» отвечают точки у
	# статей и счётчики «•N» у разделов — этого достаточно, а блок сверху,
	# меняющийся сам по себе, только сбивал.

	# --- Разделы: раскрыт ровно ОДИН. 88 кнопок разом и были «свалкой»;
	# свёрнутые разделы превращают их в десять строк оглавления. ---
	for sec in Codex.SECTIONS:
		var sid: String = str(sec["id"])
		var idxs: Array = []
		var unread := 0
		for i in _codex_entries.size():
			if str((_codex_entries[i] as Dictionary)["sec"]) == sid:
				idxs.append(i)
				if not GameConfig.codex_is_read(_codex_key(_codex_entries[i])):
					unread += 1
		if idxs.is_empty():
			continue
		var opened: bool = _codex_open_sec == sid
		var head := Button.new()
		head.text = "%s  %s%s" % [
			"▾" if opened else "▸",
			Codex.title_of(sec).to_upper(),
			("   •%d" % unread) if unread > 0 else "   %d/%d" % [idxs.size(), _codex_total_in(sid)]]
		head.alignment = HORIZONTAL_ALIGNMENT_LEFT
		head.custom_minimum_size = Vector2(0, 32)
		head.add_theme_font_size_override("font_size", 13)
		UIStyle.style_button(head)
		head.add_theme_color_override("font_color", sec["color"])
		var cap_sid: String = sid
		head.pressed.connect(func() -> void:
			_codex_open_sec = "" if _codex_open_sec == cap_sid else cap_sid
			_codex_rebuild_nav())
		_codex_nav_box.add_child(head)
		if not opened:
			continue
		for i: int in idxs:
			# [v5.3.1] Отступ вправо у статей раскрытого раздела — иначе заголовок
			# раздела и его статьи стоят вровень по левому краю, и на глаз не
			# отличить «это заголовок» от «это пункт внутри». Индент — тот же
			# визуальный язык, что у вложенных списков где угодно ещё.
			var row := HBoxContainer.new()
			var indent := Control.new()
			indent.custom_minimum_size = Vector2(18, 0)
			row.add_child(indent)
			var item_btn := _codex_nav_button(i)
			item_btn.size_flags_horizontal = Control.SIZE_EXPAND_FILL
			row.add_child(item_btn)
			_codex_nav_box.add_child(row)

	# Закрытое не показываем, но говорим, что оно есть: Кодекс растёт вместе с игрой.
	var total_all: int = Codex.ARTICLES.size() + 1
	if _codex_entries.size() < total_all:
		var hint := Label.new()
		hint.text = GameConfig.tt("🔒 Ещё %d статей откроются по мере игры", "🔒 %d more articles unlock as you play") % (total_all - _codex_entries.size())
		hint.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		hint.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		hint.add_theme_font_size_override("font_size", 12)
		hint.add_theme_color_override("font_color", Color(0.5, 0.56, 0.68))
		_codex_nav_box.add_child(hint)
	_refresh_codex_badge()
# Кнопка статьи в навигации. Непрочитанное помечено точкой — это и есть ответ
# на «что мне ещё читать», которого раньше не было ни в каком виде.
func _codex_nav_button(i: int) -> Button:
	var art: Dictionary = _codex_entries[i]
	var read: bool = GameConfig.codex_is_read(_codex_key(art))
	var btn := Button.new()
	btn.text = ("   " if read else " • ") + Codex.title_of(art)
	btn.alignment = HORIZONTAL_ALIGNMENT_LEFT
	btn.custom_minimum_size = Vector2(0, 34)
	btn.add_theme_font_size_override("font_size", 14)
	btn.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	UIStyle.style_button(btn)
	if i == _codex_idx:
		btn.add_theme_color_override("font_color", Color(1.0, 0.95, 0.75))
	elif not read:
		btn.add_theme_color_override("font_color", Color(0.85, 0.9, 1.0))
	else:
		btn.add_theme_color_override("font_color", Color(0.6, 0.66, 0.78))
	var capture: int = i
	btn.pressed.connect(func() -> void: _codex_open(capture))
	_codex_buttons[i] = btn
	return btn

# Открыть статью idx: перерисовать правую колонку и подсветить кнопку слева.
# Перекрашивает уже существующие кнопки навигации под текущее состояние —
# без пересоздания дерева (в отличие от _codex_rebuild_nav). Вызывается
# синхронно из _codex_open, чтобы подсветка «какая статья открыта» не
# отставала от неё на кадр.
func _codex_recolor_buttons() -> void:
	for i in _codex_buttons.size():
		var b: Button = _codex_buttons[i]
		if b == null or not is_instance_valid(b):
			continue
		if i == _codex_idx:
			b.add_theme_color_override("font_color", Color(1.0, 0.95, 0.75))
		elif not GameConfig.codex_is_read(_codex_key(_codex_entries[i])):
			b.add_theme_color_override("font_color", Color(0.85, 0.9, 1.0))
		else:
			b.add_theme_color_override("font_color", Color(0.6, 0.66, 0.78))

func _codex_open(idx: int) -> void:
	if _codex_entries.is_empty():
		_codex_rebuild_nav()
	if _codex_entries.is_empty():
		return
	_codex_idx = clampi(idx, 0, _codex_entries.size() - 1)
	var art: Dictionary = _codex_entries[_codex_idx]

	# [BUGFIX v5.2] Раздел навигации меняется ТОЛЬКО явным кликом по заголовку
	# раздела — открытие статьи на это не влияет (раньше статья насильно
	# раскрывала свой раздел и сворачивала прежний, перестраивая весь экран).
	# Навигацию перерисовываем, только если статья прочитана впервые — чтобы
	# обновить её точку и счётчик раздела.
	var fresh: bool = GameConfig.codex_mark_read(_codex_key(art))
	# [BUGFIX v5.2.1] Подсветка текущей статьи красилась СРАЗУ только в ветке
	# "уже прочитана"; для свежих статей она ждала call_deferred(_codex_rebuild_nav)
	# — то есть один кадр (иногда больше, судя по живому отчёту) навигация слева
	# показывала подсветку на СТАРОЙ статье, пока не прочитанной статье
	# принадлежит почти каждый клик. Красим немедленно всегда, рассылку точек/
	# счётчиков «прочитано» по-прежнему делаем отложенно — это чисто
	# косметическое обновление, не подсветка, и кадр разницы в нём не виден.
	_codex_recolor_buttons()
	if fresh:
		_codex_rebuild_nav.call_deferred()

	for c in _codex_body.get_children():
		c.queue_free()

	var sec_col := Color(0.7, 0.8, 1.0)
	for sec in Codex.SECTIONS:
		if str(sec["id"]) == str(art["sec"]):
			sec_col = sec["color"]
			break

	var kicker := Label.new()
	kicker.text = _codex_section_title(str(art["sec"])).to_upper()
	kicker.add_theme_font_size_override("font_size", 12)
	kicker.add_theme_color_override("font_color", sec_col)
	_codex_body.add_child(kicker)

	var title := Label.new()
	title.text = Codex.title_of(art)
	title.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	title.add_theme_font_size_override("font_size", 24)
	title.add_theme_color_override("font_color", Color(0.9, 0.94, 1.0))
	_codex_body.add_child(title)

	var fig := _codex_figure(str(art["fig"]), sec_col)
	if fig != null:
		_codex_body.add_child(fig)

	# Текст абзацами: пустая строка в данных = новый Label. Так у абзацев есть
	# настоящий интервал, а не двойной перевод строки внутри одной метки.
	# Списки-перечисления (абзац из пунктов «•») режем ещё и по одиночному
	# переводу строки — иначе список склеивается в простыню без интервалов.
	for para in Codex.body_of(art).split("\n\n"):
		var chunk: String = para.strip_edges()
		if chunk == "":
			continue
		var pieces: Array = [chunk]
		if chunk.begins_with("•") and chunk.contains("\n"):
			pieces = chunk.split("\n")
		for piece in pieces:
			var t: String = str(piece).strip_edges()
			if t == "":
				continue
			var l := Label.new()
			l.text = t
			l.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
			l.add_theme_font_size_override("font_size", 15)
			l.add_theme_color_override("font_color", Color(0.84, 0.88, 0.96))
			_codex_body.add_child(l)

	_codex_article.scroll_vertical = 0
	_refit_codex_deferred()

func _codex_section_title(sid: String) -> String:
	for sec in Codex.SECTIONS:
		if str(sec["id"]) == sid:
			return Codex.title_of(sec)
	return ""

func _on_open_codex() -> void:
	_hide_all_panels()
	# [v6.0] Состав статей зависит от прогресса: пересобираем при каждом входе и
	# оставляем открытой ту же статью, если она всё ещё на месте.
	var cur_key := ""
	if _codex_idx >= 0 and _codex_idx < _codex_entries.size():
		cur_key = _codex_key(_codex_entries[_codex_idx])
	_codex_rebuild_nav()
	var start_idx := 0
	for i in _codex_entries.size():
		if _codex_key(_codex_entries[i]) == cur_key:
			start_idx = i
			break
	_codex_open(start_idx)
	_set_header_compact(true)
	_codex_root.visible = true
	_back_btn.visible = true
	_fit_codex()

# [BUGFIX v5.1.1] Обе колонки Кодекса держат ОДНУ И ТУ ЖЕ фиксированную высоту
# по измеренному остатку колонки — и НЕ подстраиваются под содержимое.
#
# Раньше здесь звался _fit_carousel, который ставит min(нужно, доступно), то
# есть высота зависела от текущей статьи и от того, какой раздел раскрыт. Вся
# страница меню центрирована, поэтому любое изменение высоты сдвигало её
# целиком: при каждом переключении раздела/статьи экран заметно прыгал
# (жалоба игрока). Для карусели такое поведение нормально — там одна карточка;
# для двух колонок, которые обязаны стоять рядом ровно, — нет.
#
# Правило «Screen bounds» не нарушено: высота по-прежнему ИЗМЕРЯЕТСЯ (остаток
# колонки), а не захардкожена, а всё, что не влезло, доступно через
# SCROLL_MODE_AUTO внутри самой колонки.
func _fit_codex() -> void:
	if _codex_root == null or not is_instance_valid(_codex_root):
		return
	if not _codex_root.is_visible_in_tree():
		return
	var vh: float = get_viewport().get_visible_rect().size.y
	# «Всё остальное в колонке» = заголовок MAZE, подзаголовок и поля. Меряем
	# через уже разложенные размеры; до первого прохода layout берём запас.
	var other: float = 320.0
	if _root_col and is_instance_valid(_root_col) and _root_col.size.y > 0.0 and _codex_root.size.y > 0.0:
		other = _root_col.size.y - _codex_root.size.y
	var avail: float = maxf(vh - 32.0 - other, 240.0)
	_codex_nav.custom_minimum_size.y = avail
	_codex_article.custom_minimum_size.y = avail

func _refit_codex_deferred() -> void:
	for _pass in 2:
		await get_tree().process_frame
		if not is_inside_tree():
			return
		_fit_codex()

# ── Картинки статей ─────────────────────────────────────────────────────────
# Собираются из ТЕХ ЖЕ генераторов, что рисуют объекты в игре (MazeTextures,
# SkillIcons) — иначе картинка в кодексе и предмет в лабиринте однажды
# разойдутся. Диаграммы (полосы, стойка, ранги) рисуются простыми ColorRect.

func _codex_figure(id: String, accent: Color) -> Control:
	match id:
		"goal":
			return _codex_icons([
				[MazeTextures.make_player_orb(20), Color.WHITE, "ты"],
				[MazeTextures.make_key_crystal(16, Color(1.0, 0.55, 0.30)), Color.WHITE, "осколок"],
				[MazeTextures.make_portal(20, Color(1.0, 0.86, 0.30)), Color.WHITE, "портал"],
			])
		"controls":
			return _codex_keys(["Z", "X", "Q", "Shift", "R", "E", "C", "G", "F", "H"])
		"first_run":
			return _codex_icons([
				[MazeTextures.make_key_crystal(16, Color(1.0, 0.55, 0.30)), Color.WHITE, "собери"],
				[MazeTextures.make_charge_station(18, Color(0.35, 0.8, 1.0)), Color.WHITE, "заправься"],
				[MazeTextures.make_portal(18, Color(1.0, 0.86, 0.30)), Color.WHITE, "уходи"],
			])
		"bars":
			return _codex_bars()
		"hud":
			return _codex_skill_row(["flash", "dash", "smother", "sonar", "shield"], ["Q", "Shift", "R", "E", "C"])
		"stance", "visibility":
			return _codex_stance()
		"skills_base":
			return _codex_skill_row(["flash", "dash", "smother"], ["Q", "Shift", "R"])
		"skills_buy":
			return _codex_skill_row(["sonar", "shield", "guide", "reveal"], ["E", "C", "G", "F"])
		"skills_combo":
			return _codex_skill_row(["dash", "flash", "shield", "sonar"], ["+", "=", "+", "="])
		"skills_gift":
			return _codex_skill_row(["mirage", "breach", "chrono", "apex"], ["T", "Y", "V", "H"])
		"noise":
			return _codex_noise()
		"streak":
			return _codex_streak()
		"escalation":
			return _codex_escalation()
		"hearing":
			return _codex_hearing()
		"shards":
			return _codex_icons([
				[MazeTextures.make_key_crystal(16, Color(1.0, 0.55, 0.30)), Color.WHITE, "осколок = ключ"],
				[MazeTextures.make_portal(16, Color(0.66, 0.45, 1.0)), Color.WHITE, "открыта"],
				[MazeTextures.make_lock(16, Color(1.0, 0.55, 0.30)), Color.WHITE, "заперта"],
			])
		"stations":
			return _codex_icons([
				[MazeTextures.make_charge_station(18, Color(0.35, 0.8, 1.0)), Color.WHITE, "укрытие"],
				[MazeTextures.make_portal(16, Color(0.55, 0.2, 0.75)), Color.WHITE, "тёмная"],
			])
		"hazards":
			return _codex_icons([
				[MazeTextures.make_ring(28), Color(0.45, 0.42, 0.5), "яма"],
				[MazeTextures.make_portal(16, Color(0.3, 0.9, 0.85)), Color.WHITE, "срезка"],
			])
		"events":
			return _codex_glyphs(["⛰", "▦", "✦", "≈", "⚠", "⚡"], accent)
		"claim":
			# [§41] Те же цвета, что у следа в игре (main.gd claim_color).
			return _codex_glyphs(["свежая ▮", "тлеет ▮", "тьма забрала ▯"], Color(1.0, 0.78, 0.42))
		"mark":
			# [v4.4] Метка выделена в свою статью из claim — свой значок с клавишей.
			return _codex_keys(["M"])
		"watchers":
			# [v4.4] Соглядатай/Очаг выделены в свою статью из claim.
			return _codex_glyphs([
				"Соглядатай" if GameConfig.locale != "en" else "Onlooker",
				"Тлеющий очаг" if GameConfig.locale != "en" else "Smould. Hearth",
			], accent)
		"draft":
			# [§72] Три ступени силы потока — ровно то, что игрок читает как
			# «горячо/холодно» (цвет тот же, что у пылинок в draft.gd).
			var dc := Color(0.72, 0.88, 1.0)
			return _codex_icons([
				[MazeTextures.make_light(18), Color(dc.r, dc.g, dc.b, 0.30),
					"далеко" if GameConfig.locale != "en" else "far"],
				[MazeTextures.make_light(22), Color(dc.r, dc.g, dc.b, 0.62),
					"ближе" if GameConfig.locale != "en" else "closer"],
				[MazeTextures.make_light(28), dc,
					"у выхода" if GameConfig.locale != "en" else "at the exit"],
			])
		"spine":
			# [§40] Те же цвета, что у столпов в игре (main.gd HUB_COLORS).
			return _codex_icons([
				[MazeTextures.make_light(26), Color(0.35, 0.85, 1.00), "зал"],
				[MazeTextures.make_light(26), Color(1.00, 0.55, 0.25), "зал"],
				[MazeTextures.make_light(26), Color(0.75, 0.45, 1.00), "зал"],
			])
		"ladder":
			# [§38] Ближайшие ступени: последняя пройденная и три следующие —
			# картинка отвечает «где я на лестнице», а текст статьи — «что где».
			return _codex_glyphs(_codex_ladder_glyphs(), accent)
		"biomes", "biomes3":
			return _codex_biomes()
		"enemies":
			return _codex_enemies()
		"enemy_slow", "enemy_fast", "enemy_cyclic", "enemy_sentinel", "enemy_phantom", "enemy_leech":
			return _codex_enemy_portrait(id)
		"role_herder":
			return _codex_icons([
				[MazeTextures.make_enemy(0, 26), Color(1.0, 0.85, 0.45),
					"загонщик" if GameConfig.locale != "en" else "herder"],
			])
		"role_mimic":
			return _codex_icons([
				[MazeTextures.make_charge_station(20, Color(0.35, 0.8, 1.0)), Color.WHITE,
					"мимик?" if GameConfig.locale != "en" else "mimic?"],
			])
		"guests":
			return _codex_icons([
				[_guest_icon("gold"), Color.WHITE, "беглец"],
				[_guest_icon("azure"), Color(0.5, 1.0, 0.75), "огонёк"],
				[_guest_icon("crimson"), Color.WHITE, "кроты"],
				[_guest_icon("silver"), Color.WHITE, "вор"],
			])
		"boss_door":
			return _codex_icons([
				[MazeTextures.make_portal(20, Color(0.8, 0.12, 0.2)), Color.WHITE, "дверь"],
				[MazeTextures.make_ball(16, Color(0.6, 0.2, 0.9)), Color.WHITE, "ядро"],
			])
		"boss_final":
			return _codex_icons([
				[MazeTextures.make_superboss_body(22, Color(0.75, 0.2, 0.85)), Color.WHITE, "страж"],
				[MazeTextures.make_portal(16, Color(0.42, 0.12, 0.55)), Color.WHITE, "арена"],
			])
		"modes_levels":
			return _codex_glyphs(["Тлеющий", "Горящий", "Пылающий"], accent)
		"modes_ember":
			return _codex_icons([
				[MazeTextures.make_light(36), Color(1.0, 0.55, 0.2), "жар"],
				[MazeTextures.make_charge_station(18, Color(1.0, 0.7, 0.3)), Color.WHITE, "алтарь"],
			])
		"modes_daily":
			return _codex_glyphs(["1/сутки", "общий сид"] if GameConfig.locale != "en" else ["1/day", "shared seed"], accent)
		"modes_lair":
			return _codex_icons([
				[MazeTextures.make_ball(18, Color(0.55, 0.2, 0.75)), Color.WHITE, "владыка"],
				[MazeTextures.make_light(28), Color(0.6, 0.25, 0.8), "тронный зал"],
			])
		"modes_tutorial":
			return _codex_glyphs(["3 этапа", "без риска"] if GameConfig.locale != "en" else ["3 stages", "no risk"], accent)
		"modes_caves":
			return _codex_glyphs(["◯", "◯", "◯"], accent)
		"progress_sp":
			return _codex_glyphs(["SP", "★★★☆☆", "пассивки"], accent)
		"progress_rank":
			return _codex_ranks()
		"progress_journal":
			return _codex_glyphs(["Дневник", "Бестиарий", "Профили"], accent)
	return null

# Ряд «иконка + подпись».
func _codex_icons(items: Array) -> Control:
	var row := HBoxContainer.new()
	row.alignment = BoxContainer.ALIGNMENT_CENTER
	row.add_theme_constant_override("separation", 22)
	for it in items:
		var spec: Array = it
		var col := VBoxContainer.new()
		col.add_theme_constant_override("separation", 2)
		var ic := TextureRect.new()
		ic.texture = spec[0]
		ic.modulate = spec[1]
		ic.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		ic.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
		ic.custom_minimum_size = Vector2(52, 52)
		col.add_child(ic)
		var lb := Label.new()
		lb.text = str(spec[2])
		lb.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		lb.add_theme_font_size_override("font_size", 11)
		lb.add_theme_color_override("font_color", Color(0.65, 0.72, 0.85))
		col.add_child(lb)
		row.add_child(col)
	return row

# Ряд иконок навыков с подписью клавиши.
func _codex_skill_row(ids: Array, keys: Array) -> Control:
	var items: Array = []
	for i in ids.size():
		var sid: String = str(ids[i])
		items.append([SkillIcons.make_hd(sid, 46), Color.WHITE, str(keys[i])])
	return _codex_icons(items)

# Клавиши как «кнопки» — для статьи про управление.
func _codex_keys(keys: Array) -> Control:
	var row := HFlowContainer.new()
	row.alignment = FlowContainer.ALIGNMENT_CENTER
	row.add_theme_constant_override("h_separation", 8)
	row.add_theme_constant_override("v_separation", 8)
	for k in keys:
		var p := PanelContainer.new()
		var sb := StyleBoxFlat.new()
		sb.bg_color = Color(0.10, 0.13, 0.20, 0.95)
		sb.set_corner_radius_all(6)
		sb.set_border_width_all(1)
		sb.border_color = Color(0.45, 0.6, 0.9, 0.6)
		sb.content_margin_left = 10
		sb.content_margin_right = 10
		sb.content_margin_top = 5
		sb.content_margin_bottom = 5
		p.add_theme_stylebox_override("panel", sb)
		var l := Label.new()
		l.text = str(k)
		l.add_theme_font_size_override("font_size", 14)
		l.add_theme_color_override("font_color", Color(0.85, 0.9, 1.0))
		p.add_child(l)
		row.add_child(p)
	return row

# Диаграмма двух полос — Свет и Воля, теми же цветами, что в HUD.
func _codex_bars() -> Control:
	# [v6.0] Свет и Воля в HUD — два кольца орба; здесь тот же самый виджет.
	var row := HBoxContainer.new()
	row.alignment = BoxContainer.ALIGNMENT_CENTER
	row.add_theme_constant_override("separation", 16)
	var orb := HudVitals.new()
	orb.light = 0.72
	orb.will = 0.5
	orb.snap()
	orb.mouse_filter = Control.MOUSE_FILTER_IGNORE
	row.add_child(orb)
	var box := VBoxContainer.new()
	box.alignment = BoxContainer.ALIGNMENT_CENTER
	box.add_theme_constant_override("separation", 10)
	row.add_child(box)
	for spec in [
		["Свет", "Light", Color(1.0, 0.85, 0.3), "внешнее кольцо · жизнь, тает во тьме", "outer ring - life, fades in the dark"],
		["Воля", "Will", Color(0.3, 0.9, 0.95), "внутреннее кольцо · навыки, копится сама", "inner ring - skills, refills itself"],
	]:
		var item := VBoxContainer.new()
		item.add_theme_constant_override("separation", 1)
		var nm_lbl := Label.new()
		nm_lbl.text = str(spec[1]) if GameConfig.locale == "en" else str(spec[0])
		nm_lbl.add_theme_font_size_override("font_size", 14)
		nm_lbl.add_theme_color_override("font_color", spec[2])
		item.add_child(nm_lbl)
		var note := Label.new()
		note.text = str(spec[4]) if GameConfig.locale == "en" else str(spec[3])
		note.add_theme_font_size_override("font_size", 11)
		note.add_theme_color_override("font_color", Color(0.62, 0.7, 0.82))
		item.add_child(note)
		box.add_child(item)
	return row

# Диаграмма стойки света: три сегмента с реальными числами из player.gd.
func _codex_stance() -> Control:
	var row := HBoxContainer.new()
	row.alignment = BoxContainer.ALIGNMENT_CENTER
	row.add_theme_constant_override("separation", 14)
	var names_ru := ["Тусклый", "Ровный", "Яркий"]
	var names_en := ["Dim", "Even", "Bright"]
	var cols := [Color(0.45, 0.60, 0.85), Color(1.0, 0.86, 0.35), Color(1.0, 0.72, 0.25)]
	var drain := ["×0.45", "×1.0", "×2.40"]
	var vis := ["×0.55", "×1.0", "×1.75"]
	for i in 3:
		var card := PanelContainer.new()
		var sb := StyleBoxFlat.new()
		sb.bg_color = Color(cols[i].r * 0.16, cols[i].g * 0.16, cols[i].b * 0.16, 0.95)
		sb.set_corner_radius_all(8)
		sb.set_border_width_all(1)
		sb.border_color = Color(cols[i].r, cols[i].g, cols[i].b, 0.55)
		sb.content_margin_left = 12
		sb.content_margin_right = 12
		sb.content_margin_top = 8
		sb.content_margin_bottom = 8
		card.add_theme_stylebox_override("panel", sb)
		var col := VBoxContainer.new()
		col.add_theme_constant_override("separation", 3)
		var glow := TextureRect.new()
		glow.texture = MazeTextures.make_light(30)
		glow.modulate = cols[i]
		glow.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		glow.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
		glow.custom_minimum_size = Vector2(38 + i * 12, 34)
		col.add_child(glow)
		var nm := Label.new()
		nm.text = str(names_en[i]) if GameConfig.locale == "en" else str(names_ru[i])
		nm.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		nm.add_theme_font_size_override("font_size", 13)
		nm.add_theme_color_override("font_color", cols[i])
		col.add_child(nm)
		var d := Label.new()
		d.text = ("burn %s" % drain[i]) if GameConfig.locale == "en" else ("расход %s" % drain[i])
		d.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		d.add_theme_font_size_override("font_size", 11)
		d.add_theme_color_override("font_color", Color(0.7, 0.76, 0.88))
		col.add_child(d)
		var v := Label.new()
		v.text = ("seen %s" % vis[i]) if GameConfig.locale == "en" else ("заметность %s" % vis[i])
		v.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		v.add_theme_font_size_override("font_size", 11)
		v.add_theme_color_override("font_color", Color(0.7, 0.76, 0.88))
		col.add_child(v)
		card.add_child(col)
		row.add_child(card)
	return row

# Три биома — их настоящие цвета стен из main.gd BIOMES.
func _codex_biomes() -> Control:
	var row := HBoxContainer.new()
	row.alignment = BoxContainer.ALIGNMENT_CENTER
	row.add_theme_constant_override("separation", 18)
	for spec in [
		[Color(0.18, 0.72, 1.00), "Лазурные шахты", "Azure Mines", "срезки", "shortcuts"],
		[Color(1.00, 0.32, 0.26), "Багровые недра", "Crimson Depths", "ямы", "chasms"],
		[Color(0.55, 1.00, 0.30), "Споровые пустоты", "Spore Wastes", "тьма", "darkness"],
	]:
		var col := VBoxContainer.new()
		col.add_theme_constant_override("separation", 3)
		var sw := ColorRect.new()
		sw.color = spec[0]
		sw.custom_minimum_size = Vector2(120, 14)
		col.add_child(sw)
		var nm := Label.new()
		nm.text = str(spec[2]) if GameConfig.locale == "en" else str(spec[1])
		nm.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		nm.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		nm.custom_minimum_size = Vector2(120, 0)
		nm.add_theme_font_size_override("font_size", 12)
		nm.add_theme_color_override("font_color", spec[0])
		col.add_child(nm)
		var th := Label.new()
		th.text = str(spec[4]) if GameConfig.locale == "en" else str(spec[3])
		th.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		th.add_theme_font_size_override("font_size", 11)
		th.add_theme_color_override("font_color", Color(0.66, 0.73, 0.85))
		col.add_child(th)
		row.add_child(col)
	return row

# Портреты врагов — те же make_enemy, что в игре и в Бестиарии.
func _codex_enemies() -> Control:
	var row := HFlowContainer.new()
	row.alignment = FlowContainer.ALIGNMENT_CENTER
	row.add_theme_constant_override("h_separation", 14)
	row.add_theme_constant_override("v_separation", 6)
	var names_ru := ["медлит.", "быстрый", "циклич.", "Страж", "Фантом", "Пиявка"]
	var names_en := ["slow", "fast", "cyclic", "Sentinel", "Phantom", "Leech"]
	for t in 6:
		var col := VBoxContainer.new()
		col.add_theme_constant_override("separation", 2)
		var ic := TextureRect.new()
		ic.texture = MazeTextures.make_enemy(t, 18)
		ic.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		ic.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
		ic.custom_minimum_size = Vector2(46, 46)
		col.add_child(ic)
		var lb := Label.new()
		lb.text = str(names_en[t]) if GameConfig.locale == "en" else str(names_ru[t])
		lb.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		lb.add_theme_font_size_override("font_size", 11)
		lb.add_theme_color_override("font_color", Color(0.7, 0.76, 0.86))
		col.add_child(lb)
		row.add_child(col)
	return row

# [v4.4] Портрет одного типа врага — для его отдельной страницы Кодекса
# (раньше все шесть типов были свалены в одну статью, см. §66 GAMEDESIGN).
# Крупнее иконки общего ряда _codex_enemies(): своя страница, места хватает.
const _ENEMY_PORTRAIT_TYPE := {
	"enemy_slow": 0, "enemy_fast": 1, "enemy_cyclic": 2,
	"enemy_sentinel": 3, "enemy_phantom": 4, "enemy_leech": 5,
}
func _codex_enemy_portrait(fig_id: String) -> Control:
	var t: int = int(_ENEMY_PORTRAIT_TYPE.get(fig_id, 0))
	var names_ru := ["медлительный", "быстрый", "цикличный", "Страж", "Фантом", "Пиявка"]
	var names_en := ["slow", "fast", "cyclic", "Sentinel", "Phantom", "Leech"]
	var en_name: String = str(names_en[t]) if GameConfig.locale == "en" else str(names_ru[t])
	return _codex_icons([[MazeTextures.make_enemy(t, 30), Color.WHITE, en_name]])

# Ранги — теми же цветами, что на экране результатов.
func _codex_ranks() -> Control:
	var row := HBoxContainer.new()
	row.alignment = BoxContainer.ALIGNMENT_CENTER
	row.add_theme_constant_override("separation", 10)
	for spec in [["S", "×1.5"], ["A", "×1.25"], ["B", "×1.0"], ["C", "×0.85"], ["D", "×0.7"]]:
		var c: Color = _RESULT_RANK_COLORS.get(str(spec[0]), Color.WHITE)
		var card := PanelContainer.new()
		var sb := StyleBoxFlat.new()
		sb.bg_color = Color(c.r * 0.16, c.g * 0.16, c.b * 0.16, 0.95)
		sb.set_corner_radius_all(8)
		sb.set_border_width_all(1)
		sb.border_color = Color(c.r, c.g, c.b, 0.6)
		sb.content_margin_left = 14
		sb.content_margin_right = 14
		sb.content_margin_top = 6
		sb.content_margin_bottom = 6
		card.add_theme_stylebox_override("panel", sb)
		var col := VBoxContainer.new()
		col.add_theme_constant_override("separation", 1)
		var r := Label.new()
		r.text = str(spec[0])
		r.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		r.add_theme_font_size_override("font_size", 22)
		r.add_theme_color_override("font_color", c)
		col.add_child(r)
		var m := Label.new()
		m.text = str(spec[1])
		m.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		m.add_theme_font_size_override("font_size", 11)
		m.add_theme_color_override("font_color", Color(0.72, 0.78, 0.88))
		col.add_child(m)
		card.add_child(col)
		row.add_child(card)
	return row

# Диаграмма шума: сравнение радиусов слышимости с радиусом ЗРЕНИЯ врага —
# главная мысль статьи в одной картинке (Сонар слышно вдвое дальше, чем ты
# успеешь увидеть пришедшего). Полосы масштабированы к самой громкой.
func _codex_noise() -> Control:
	var box := VBoxContainer.new()
	box.add_theme_constant_override("separation", 5)
	var rows := [
		["Разлом", "Breach", 700.0, Color(1.0, 0.45, 0.35)],
		["Сонар", "Sonar", 620.0, Color(1.0, 0.55, 0.35)],
		["Вспышка", "Flash", 520.0, Color(1.0, 0.72, 0.35)],
		["зрение врага", "enemy sight", 330.0, Color(0.55, 0.75, 1.0)],
		["Рывок", "Dash", 200.0, Color(0.75, 0.85, 0.6)],
		["Метка", "Mark", 90.0, Color(1.0, 0.55, 0.15)],
		["Тление", "Smother", 0.0, Color(0.45, 0.60, 0.85)],
	]
	for r in rows:
		var row := HBoxContainer.new()
		row.add_theme_constant_override("separation", 8)
		var nm := Label.new()
		nm.text = str(r[1]) if GameConfig.locale == "en" else str(r[0])
		nm.custom_minimum_size = Vector2(112, 0)
		nm.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
		nm.add_theme_font_size_override("font_size", 12)
		nm.add_theme_color_override("font_color", r[3])
		row.add_child(nm)
		var bar := ColorRect.new()
		bar.color = r[3]
		bar.custom_minimum_size = Vector2(maxf(float(r[2]) / 700.0 * 300.0, 3.0), 11)
		bar.size_flags_vertical = Control.SIZE_SHRINK_CENTER
		row.add_child(bar)
		var val := Label.new()
		val.text = ("бесшумно" if GameConfig.locale != "en" else "silent") if float(r[2]) <= 0.0 else str(int(r[2]))
		val.add_theme_font_size_override("font_size", 11)
		val.add_theme_color_override("font_color", Color(0.66, 0.73, 0.85))
		row.add_child(val)
		box.add_child(row)
	return box

# Диаграмма слуха: насколько дальше слышно врагов в разных стойках. Числа те
# же, что в player.STANCE_HEARING/SMOTHER_HEARING — при правке баланса
# правится и здесь (menu.gd не грузит player.gd).
func _codex_hearing() -> Control:
	var box := VBoxContainer.new()
	box.add_theme_constant_override("separation", 5)
	for r in [
			["Тление", "Smother", 1.5, Color(0.55, 0.75, 1.0)],
			["Тусклый", "Dim", 1.35, Color(0.45, 0.60, 0.85)],
			["Ровный", "Even", 1.0, Color(1.0, 0.86, 0.35)],
			["Яркий", "Bright", 0.8, Color(1.0, 0.72, 0.25)]]:
		var row := HBoxContainer.new()
		row.add_theme_constant_override("separation", 10)
		var nm := Label.new()
		nm.text = str(r[1]) if GameConfig.locale == "en" else str(r[0])
		nm.custom_minimum_size = Vector2(96, 0)
		nm.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
		nm.add_theme_font_size_override("font_size", 13)
		nm.add_theme_color_override("font_color", r[3])
		row.add_child(nm)
		var bar := ColorRect.new()
		bar.color = r[3]
		bar.custom_minimum_size = Vector2(float(r[2]) / 1.5 * 230.0, 12)
		bar.size_flags_vertical = Control.SIZE_SHRINK_CENTER
		row.add_child(bar)
		var val := Label.new()
		val.text = "×%.2f" % float(r[2])
		val.add_theme_font_size_override("font_size", 11)
		val.add_theme_color_override("font_color", Color(0.66, 0.73, 0.85))
		row.add_child(val)
		box.add_child(row)
	return box

# Диаграмма серии осколков: лестница множителей до потолка. Числа берутся из
# тех же констант, что и в игре (main.gd STREAK_STEP / STREAK_MULT_MAX), но
# menu.gd не грузит main.gd — поэтому шаг задан здесь и должен совпадать.
const _CODEX_STREAK_STEP := 0.25
const _CODEX_STREAK_MAX := 2.5

func _codex_streak() -> Control:
	var row := HBoxContainer.new()
	row.alignment = BoxContainer.ALIGNMENT_CENTER
	row.add_theme_constant_override("separation", 6)
	for n in [1, 2, 3, 4, 5, 7]:
		var m: float = minf(1.0 + (n - 1) * _CODEX_STREAK_STEP, _CODEX_STREAK_MAX)
		var k: float = clampf((m - 1.0) / (_CODEX_STREAK_MAX - 1.0), 0.0, 1.0)
		var c: Color = Color(1.0, 0.72, 0.45).lerp(Color(1.0, 0.95, 0.45), k)
		var card := PanelContainer.new()
		var sb := StyleBoxFlat.new()
		sb.bg_color = Color(c.r * 0.16, c.g * 0.16, c.b * 0.16, 0.95)
		sb.set_corner_radius_all(8)
		sb.set_border_width_all(1)
		sb.border_color = Color(c.r, c.g, c.b, 0.55)
		sb.content_margin_left = 10
		sb.content_margin_right = 10
		sb.content_margin_top = 6
		sb.content_margin_bottom = 6
		card.add_theme_stylebox_override("panel", sb)
		var col := VBoxContainer.new()
		col.add_theme_constant_override("separation", 1)
		var s1 := Label.new()
		s1.text = "×%d" % n
		s1.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		s1.add_theme_font_size_override("font_size", 15)
		s1.add_theme_color_override("font_color", Color(0.72, 0.78, 0.88))
		col.add_child(s1)
		var s2 := Label.new()
		s2.text = "%.2f" % m
		s2.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		s2.add_theme_font_size_override("font_size", 17)
		s2.add_theme_color_override("font_color", c)
		col.add_child(s2)
		card.add_child(col)
		row.add_child(card)
	return row

# Диаграмма эскалации: три стадии уровня как шкала времени. Пороги подписаны
# в долях нормы времени, а не в секундах — в игре они и считаются так
# (main.gd ESCALATION_STAGE*_MULT), потому что зависят от номера уровня.
func _codex_escalation() -> Control:
	var box := VBoxContainer.new()
	box.add_theme_constant_override("separation", 6)
	var rows := [
		["Тишина", "Silence", "до нормы времени", "up to par time", Color(0.55, 0.85, 0.65), 0.30],
		["Тьма густеет", "Dark thickens", "×1.15 нормы  ·  обзор 0.9", "x1.15 par  -  view 0.9", Color(0.55, 0.65, 0.95), 0.62],
		["Охота: ЛОВЧИЙ", "The hunt: STALKER", "×1.90 нормы  ·  обзор 0.8", "x1.90 par  -  view 0.8", Color(1.0, 0.45, 0.75), 1.0],
	]
	for r in rows:
		var row := HBoxContainer.new()
		row.add_theme_constant_override("separation", 10)
		var nm := Label.new()
		nm.text = str(r[1]) if GameConfig.locale == "en" else str(r[0])
		nm.custom_minimum_size = Vector2(130, 0)
		nm.add_theme_font_size_override("font_size", 13)
		nm.add_theme_color_override("font_color", r[4])
		row.add_child(nm)
		var bar := ColorRect.new()
		bar.color = r[4]
		bar.custom_minimum_size = Vector2(float(r[5]) * 190.0, 12)
		bar.size_flags_vertical = Control.SIZE_SHRINK_CENTER
		row.add_child(bar)
		var note := Label.new()
		note.text = str(r[3]) if GameConfig.locale == "en" else str(r[2])
		note.add_theme_font_size_override("font_size", 11)
		note.add_theme_color_override("font_color", Color(0.66, 0.73, 0.85))
		row.add_child(note)
		box.add_child(row)
	return box

# Картинка статьи про роли: слева обычный враг (идёт к тебе), в центре
# загонщик в своём жёлтом тоне (идёт к твоему пути отхода), справа мимик —
# та же текстура станции, что и у настоящей, иначе подделка не читалась бы.
# Ряд текстовых глифов/ярлыков — для статей без своей иконки.
# [§38] Метки ступеней для картинки статьи «Лестница открытий»: пройденное с
# галочкой, ближайшее со стрелкой. Берём окно вокруг текущего прогресса, а не
# весь список из 18 пунктов — иначе строка чипов уезжает за край панели.
func _codex_ladder_glyphs() -> Array:
	var en := GameConfig.locale == "en"
	var lvl: int = GameConfig.max_unlocked_level
	var done: Array = []
	for e in GameConfig.LADDER:
		var nm: String = str(e["name_en"]) if en else str(e["name"])
		if lvl >= int(e["level"]):
			done.append("✓ %d · %s" % [int(e["level"]), nm])
	# Что дальше — не называем: Кодекс открывает только встреченное.
	var out: Array = done.slice(maxi(done.size() - 3, 0))
	if done.size() < GameConfig.LADDER.size():
		out.append("→ ?")
	return out

func _codex_glyphs(items: Array, accent: Color) -> Control:
	var row := HFlowContainer.new()
	row.alignment = FlowContainer.ALIGNMENT_CENTER
	row.add_theme_constant_override("h_separation", 12)
	row.add_theme_constant_override("v_separation", 6)
	for it in items:
		var p := PanelContainer.new()
		var sb := StyleBoxFlat.new()
		sb.bg_color = Color(accent.r * 0.14, accent.g * 0.14, accent.b * 0.14, 0.95)
		sb.set_corner_radius_all(8)
		sb.set_border_width_all(1)
		sb.border_color = Color(accent.r, accent.g, accent.b, 0.5)
		sb.content_margin_left = 12
		sb.content_margin_right = 12
		sb.content_margin_top = 6
		sb.content_margin_bottom = 6
		p.add_theme_stylebox_override("panel", sb)
		var l := Label.new()
		l.text = str(it)
		l.add_theme_font_size_override("font_size", 16)
		l.add_theme_color_override("font_color", accent)
		p.add_child(l)
		row.add_child(p)
	return row

# Цветовые метки гостей лабиринта (те же, что у самих гостей в игре).
const _GUEST_COLORS := {
	"gold": Color(1.0, 0.8, 0.2), "azure": Color(0.5, 1.0, 0.75),
	"crimson": Color(0.85, 0.6, 0.3), "silver": Color(0.7, 0.4, 1.0),
}

# Иконка гостя — та же текстура, что у самого гостя в игре.
func _guest_icon(id: String) -> Texture2D:
	var col: Color = _GUEST_COLORS.get(id, Color.WHITE)
	match id:
		"gold":
			return MazeTextures.make_runner_spark(15, col)
		"crimson":
			return MazeTextures.make_molehill(13, col)
		"silver":
			return MazeTextures.make_sack(15, col)
		_:
			return MazeTextures.make_light(40)   # azure/Огонёк — тот же мягкий блик, что и в игре
# Цвета карточек режимов (те же, что на экране «Играть»).
const _MODE_COLORS := {
	"u": Color(0.45, 0.75, 1.0), "n": Color(1.0, 0.55, 0.25),
	"d": Color(1.0, 0.85, 0.35), "l": Color(1.0, 0.3, 0.35),
}

# Мини-галерея слайда: иконка + подпись в сетке, короткая заметка под ней.
func _on_play(lvl: int = 1) -> void:
	GameConfig.level = lvl
	get_tree().change_scene_to_file("res://main.tscn")

# [v6.3, §84] «Обучение» открывает список уроков — по одному понятию на урок.
# Проходить можно подряд (после урока игра сама предлагает следующий) или
# выбирать любой; пройденные помечены галочкой.
func _build_tutorial_select(root: VBoxContainer) -> void:
	_tutorial_box = ScrollContainer.new()
	_tutorial_box.visible = false
	_tutorial_box.custom_minimum_size = Vector2(640, 480)
	_tutorial_box.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	root.add_child(_tutorial_box)

	var inner := VBoxContainer.new()
	inner.add_theme_constant_override("separation", 12)
	inner.custom_minimum_size = Vector2(620, 0)
	_tutorial_box.add_child(inner)

	var lbl := Label.new()
	lbl.text = GameConfig.tt("ОБУЧЕНИЕ", "TUTORIAL")
	lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	lbl.add_theme_font_size_override("font_size", 30)
	lbl.add_theme_color_override("font_color", Color(0.55, 1.0, 0.7))
	inner.add_child(lbl)

	var note := Label.new()
	note.text = GameConfig.tt(
		"Короткие уроки — по одному понятию на урок. Проходи подряд или выбирай любой. Проиграть нельзя.",
		"Short lessons, one idea each. Play them in order or pick any. You cannot lose.")
	note.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	note.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	note.add_theme_font_size_override("font_size", 15)
	note.add_theme_color_override("font_color", Color(0.62, 0.74, 0.68))
	inner.add_child(note)

	# GridContainer сам себя не центрирует (см. CLAUDE.md) — SHRINK_CENTER.
	_tutorial_grid = GridContainer.new()
	_tutorial_grid.columns = 2
	_tutorial_grid.add_theme_constant_override("h_separation", 12)
	_tutorial_grid.add_theme_constant_override("v_separation", 10)
	_tutorial_grid.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	inner.add_child(_tutorial_grid)

func _populate_tutorial_select() -> void:
	for c in _tutorial_grid.get_children():
		c.queue_free()
	var next_i := -1
	for i in TutorialLessons.count():
		if not GameConfig.tutorial_done.has(str(i)):
			next_i = i
			break
	for i in TutorialLessons.count():
		var idx := i
		var done: bool = GameConfig.tutorial_done.has(str(i))
		var btn := Button.new()
		btn.text = "%d · %s%s" % [i + 1, TutorialLessons.title_of(i), "  ✓" if done else ""]
		btn.custom_minimum_size = Vector2(296, 52)
		btn.add_theme_font_size_override("font_size", 17)
		btn.clip_text = true
		_style_button(btn)
		if done:
			btn.add_theme_color_override("font_color", Color(0.62, 0.95, 0.72))
		elif i == next_i:
			btn.add_theme_color_override("font_color", Color(1.0, 0.9, 0.55))
		btn.pressed.connect(func() -> void: _on_play_tutorial(idx))
		_tutorial_grid.add_child(btn)

func _on_open_tutorial() -> void:
	_populate_tutorial_select()
	_hide_all_panels()
	_tutorial_box.visible = true
	_back_btn.visible = true

# Не трогаем GameConfig.level: указатель кампании обучение не меняет
# (main.gd в режиме обучения сам ставит _level = 1).
func _on_play_tutorial(lesson: int) -> void:
	GameConfig.active_run = -1
	GameConfig.tutorial_mode = true
	GameConfig.tutorial_lesson = lesson
	get_tree().change_scene_to_file("res://main.tscn")

func _on_open_level_select() -> void:
	_hide_all_panels()
	_level_box.visible = true
	_back_btn.visible = true

func _on_open_settings() -> void:
	_hide_all_panels()
	_settings_scroll.visible = true
	_back_btn.visible = true

func _on_reset_progress() -> void:
	GameConfig.reset_progress()

func _on_quit() -> void:
	GameConfig.save_game()
	get_tree().quit()
