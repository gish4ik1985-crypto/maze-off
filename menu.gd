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
var _help_scroll: ScrollContainer
var _help_box: VBoxContainer      # текущий слайд справки (перестраивается по одному за раз)
var _help_nav_label: Label
var _help_slide_idx: int = 0
# Пока не подтверждено (`GameConfig.help_intro_seen == false`), карусель Справки
# ограничена тремя темами для новичка (Цель / Свет и Воля / Управление) —
# остальные 13 доступны по кнопке «Показать все темы».
const _HELP_BEGINNER_IDX := [0, 1, 9]
var _help_show_all_btn: Button
const HELP_SLIDE_TITLES := [
	"Цель", "Свет и Воля", "Осколки, двери, ключи", "Маяк и события",
	"Навыки", "Враги", "Гости лабиринта", "Режимы игры",
	"Сложность и ранг", "Управление", "Версия 1.7 (1/2)", "Версия 1.7 (2/2)",
	"Версия 1.6 (1/2)", "Версия 1.6 (2/2)", "Версия 1.5 (1/2)", "Версия 1.5 (2/2)",
]
const HELP_SLIDE_TITLES_EN := [
	"Goal", "Light and Will", "Shards, doors, keys", "Beacon and events",
	"Skills", "Enemies", "Maze guests", "Game modes",
	"Difficulty and rank", "Controls", "Version 1.7 (1/2)", "Version 1.7 (2/2)",
	"Version 1.6 (1/2)", "Version 1.6 (2/2)", "Version 1.5 (1/2)", "Version 1.5 (2/2)",
]

func _help_titles() -> Array:
	return HELP_SLIDE_TITLES_EN if GameConfig.locale == "en" else HELP_SLIDE_TITLES
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

# Дневник лабиринта: объединённые «Статистика» + «Результаты» — цифры, история
# последних уровней и «голос лабиринта» (наблюдения и советы по твоей игре).
var _journal_scroll: ScrollContainer
var _journal_box: VBoxContainer

# Спуск дня: ежедневный забег с сидом от даты, одна попытка в день.
var _daily_box: ScrollContainer
var _daily_inner: VBoxContainer

# Бестиарий «Досье лабиринта»: карточки врагов, открываются встречей/убийством.
var _bestiary_scroll: ScrollContainer
var _bestiary_box: VBoxContainer

# Выбор режима после «Играть»: Уровни (продолжить/выбрать) или Накал.
var _mode_scroll: ScrollContainer
var _mode_box: VBoxContainer

const LEVEL_COUNT := 50
const SETTINGS_W := 560   # единая ширина строк в настройках

# История версий — показывается в конце Справки и в окне «О версиях» (настройки).
const CHANGELOG_TEXT := """ЧТО НОВОГО

ВЕРСИЯ 1.7
• Английская локализация: полный перевод игры — меню, HUD, все режимы, магазин навыков, Дневник с Бестиарием, все игровые сообщения и «Голос лабиринта». Переключатель «Язык» — в настройках.
• Исправлен баг: босс мог проходить сквозь стены арены на рывке. Теперь у него настоящая физическая коллизия, как у игрока.

ВЕРСИЯ 1.6
• Бестиарий «Досье лабиринта»: карточки всех врагов — лор, тактика, твои счётчики встреч/побед. Открываются встречей, слабости — победой. Блок «Текущая угроза» объясняет, почему тьма стала злее именно у тебя.
• Ранги заработали: на экране победы — расшифровка (чего не хватило до S), ранг множит награды (S ×1.5 … D ×0.7), серия S/A даёт «Благословение» (свет ярче), серия D — «Снисхождение» (кристалл у старта). Лучший ранг виден на кнопках выбора уровня.
• «Гости лабиринта» — редкие мини-события: Охота (поймай беглеца — награда), Огонёк-союзник (отвлекает врагов), Норы кротов (клетки на время блокируются — не стой над ними!), Вор (крадёт Накал/свет — догони и верни с процентами).
• Накал — «спуск за огнём»: именованные горизонты каждые 5 глубин, контракты спуска (Пепельный путь / Гон / Одно дыхание), обеты слотов — исполни и получи SP в профиль «Уровней».
• Новый режим «Логово»: 10 больших уровней, владыка тьмы ждёт в тронном зале — в центре лабиринта. Дойди сквозь стражу и повергни его.
• Дневник: «Путь мастерства» — лабиринт не комментирует твою игру, а учит: текущий урок, прогресс и конкретный совет, как его пройти.
• Обучение переработано: полупрозрачные попапы вместо жёлтой строки, стрелка-указатель к цели шага, проиграть нельзя — свет подзаряжается бесплатно.
• Автопауза и тишина при сворачивании игры; настройки очищены от устаревших ползунков.

ВЕРСИЯ 1.5
• Кампания выросла до 50 уровней (кривая сложности растянута вдвое).
• Дверь-босс ☠ на уровнях кратных 5: арена, победа — дар Ядра (Мираж T / Разлом Y / Хронос V).
• Элита глубин: Страж (броня, дальнее зрение), Фантом (быстрый, хрупкий), Пиявка (пьёт Волю).
• Три сложности: Тлеющий / Горящий / Пылающий (без станций, награды ×1.5).
• Спуск дня: один лабиринт на всех, одна попытка в день, серия дней.
• Тление (R): погасни до искры и исчезни из виду врагов.
• Пассивки-прогрессии: растут сами от твоих действий, усиливают навыки и Апекс.
• Колесо Апекса и магазин навыков с усилениями за SP; Дневник лабиринта.
• Процедурная музыка и звуки навыков, слой погони-«сердцебиения»."""

# Те же новости, но разбитые на короткие порции для слайдов Справки
# (CHANGELOG_TEXT целиком — только для модального окна «О версиях» в настройках).
const CHANGELOG_17_A := """• Английская локализация: меню, HUD, все режимы, магазин навыков.
• Дневник с Бестиарием — тоже на английском, включая «Голос лабиринта».
• Переключатель «Язык» — в настройках, две кнопки: Русский / English."""
const CHANGELOG_17_B := """• Исправлен баг: босс мог проходить сквозь стены арены на рывке.
• Теперь у босса настоящая физическая коллизия — как у игрока."""
const CHANGELOG_16_A := """• Бестиарий «Досье лабиринта»: карточки врагов, лор, тактика, твои счётчики встреч/побед.
• Ранги заработали: ранг множит награды (S ×1.5 … D ×0.7), серии дают Благословение/Снисхождение.
• «Гости лабиринта»: Охота, Огонёк-союзник, Норы кротов, Вор — редкие мини-события.
• Накал — «спуск за огнём»: горизонты глубины, контракты спуска, обеты слотов."""
const CHANGELOG_16_B := """• Новый режим «Логово»: 10 уровней, владыка тьмы — в центре лабиринта.
• Дневник: «Путь мастерства» — не комментирует игру, а учит, шаг за шагом.
• Обучение переработано: попапы-указатели, стрелка к цели, проиграть нельзя.
• Автопауза и тишина при сворачивании; настройки очищены от старых ползунков."""
const CHANGELOG_15_A := """• Кампания выросла до 50 уровней (сложность растянута вдвое).
• Дверь-босс ☠ на уровнях кратных 5: арена, победа — дар Ядра.
• Элита глубин: Страж (броня), Фантом (скорость), Пиявка (пьёт Волю).
• Три сложности: Тлеющий / Горящий / Пылающий (награды ×0.75…×1.5)."""
const CHANGELOG_15_B := """• Спуск дня: один лабиринт на всех, одна попытка в день, серия дней.
• Тление (R): погасни до искры и исчезни из виду врагов.
• Пассивки-прогрессии: растут сами от твоих действий, усиливают Апекс.
• Колесо Апекса, магазин навыков, Дневник лабиринта, процедурное аудио."""

# Английские версии тех же новостей — для смены языка в настройках.
const CHANGELOG_17_A_EN := """• English localization: menu, HUD, all modes, skill shop.
• Journal and Bestiary — also in English, including the «Voice of the Maze».
• A «Language» switch in settings, two buttons: Русский / English."""
const CHANGELOG_17_B_EN := """• Fixed a bug: the boss could dash straight through arena walls.
• The boss now has real physics collision — just like the player."""
const CHANGELOG_16_A_EN := """• Bestiary «Maze Dossier»: enemy cards — lore, tactics, your encounter/kill counters.
• Ranks now matter: rank multiplies rewards (S ×1.5 … D ×0.7), streaks grant Blessing/Mercy.
• «Maze guests»: Runner, Wisp, Moles, Thief — rare mini-events.
• Ember mode — «descend for fire»: depth horizons, run contracts, slot vows."""
const CHANGELOG_16_B_EN := """• New mode «Lair»: 10 levels, a dark lord — at the maze's center.
• Journal: «Mastery Path» — doesn't just comment on your play, it teaches, step by step.
• Tutorial reworked: pointer popups, an arrow to the goal, you can't lose.
• Auto-pause and mute on minimize; settings cleaned of old sliders."""
const CHANGELOG_15_A_EN := """• Campaign grew to 50 levels (difficulty curve stretched twice).
• Boss door ☠ on levels divisible by 5: an arena, victory — a Core gift.
• Deep elites: Guardian (armor), Phantom (speed), Leech (drains Will).
• Three difficulties: Ember / Blaze / Inferno (rewards ×0.75…×1.5)."""
const CHANGELOG_15_B_EN := """• Daily Dive: one maze for everyone, one attempt per day, a streak.
• Smother (R): dim to a spark and vanish from enemies' sight.
• Passive progressions: grow on their own from your actions, boost Apex.
• Apex wheel, skill shop, maze Journal, procedural audio."""


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
	_build_settings(root)
	_build_help(root)

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
	if _lair_box:
		_lair_box.visible = false
	_settings_scroll.visible = false
	_help_scroll.visible = false
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
	if _briefing_box and _briefing_box.visible:
		_on_briefing_back()
		return
	var from_mode_child: bool = _runs_box.visible or _level_box.visible \
		or (_lair_box != null and _lair_box.visible) \
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
	_help_scroll.custom_minimum_size.y = min(520.0, avail)
	if _journal_scroll:
		_journal_scroll.custom_minimum_size.y = min(520.0, avail)
	if _bestiary_scroll:
		_bestiary_scroll.custom_minimum_size.y = min(520.0, avail)
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
	if _daily_box:
		_daily_box.custom_minimum_size.y = min(480.0, avail)

func _build_menu(root: VBoxContainer) -> void:
	_menu_box = VBoxContainer.new()
	_menu_box.add_theme_constant_override("separation", 12)
	root.add_child(_menu_box)

	_menu_box.add_child(_make_button(GameConfig.t("menu_play"), _on_open_mode))
	_menu_box.add_child(_make_button(GameConfig.t("menu_settings"), _on_open_settings))
	_menu_box.add_child(_make_button(GameConfig.t("menu_help"), _on_open_help))
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

	_settings_section(GameConfig.t("settings_game"), Color(0.5, 0.8, 1.0))
	_settings_check(GameConfig.t("beacon_pulse_opt"), GameConfig.beacon_pulse, func(on: bool) -> void:
		GameConfig.beacon_pulse = on
		GameConfig.save_game())
	_settings_check(GameConfig.t("show_fps_opt"), GameConfig.show_fps, func(on: bool) -> void:
		GameConfig.show_fps = on
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

	_settings_section(GameConfig.t("settings_test"), Color(1.0, 0.6, 0.2))
	var thint := Label.new()
	thint.text = "В тест-режиме открыто всё, а статистика, XP, история уровней
и Спуск дня НЕ записываются — прогоны не искажают Дневник."
	thint.custom_minimum_size = Vector2(SETTINGS_W, 0)
	thint.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	thint.add_theme_font_size_override("font_size", 13)
	thint.add_theme_color_override("font_color", Color(0.6, 0.62, 0.68))
	_settings_box.add_child(thint)

	var on_test := func(on: bool) -> void:
		GameConfig.test_mode = on
		GameConfig.save_game()
		_toast("Тест-режим: %s" % ("ВКЛ — статистика не записывается" if on else "выкл"))
	_settings_check("Тест-режим (статистика не пишется)", GameConfig.test_mode, on_test, Color(1.0, 0.6, 0.2))
	_unlock_baseline = GameConfig.max_unlocked_level
	_settings_check("Разблокировать все уровни", GameConfig.max_unlocked_level >= LEVEL_COUNT,
		_on_unlock_toggled, Color(1.0, 0.6, 0.2))
	var on_boss := func(on: bool) -> void:
		GameConfig.boss_test_enabled = on
		_populate_levels()
	_settings_check("⚔ Тест боссов (уровни с боссом в меню)", GameConfig.boss_test_enabled, on_boss, Color(1.0, 0.6, 0.2))

	# ── Кнопки внизу: по центру колонки ──────────────────────────────────────
	var bsep := HSeparator.new()
	bsep.modulate = Color(0.4, 0.5, 0.7, 0.4)
	_settings_box.add_child(bsep)

	var btn_col := VBoxContainer.new()
	btn_col.alignment = BoxContainer.ALIGNMENT_CENTER
	btn_col.add_theme_constant_override("separation", 10)
	btn_col.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	_settings_box.add_child(btn_col)

	# «О версиях»: окно с историей изменений (тот же текст, что в конце Справки).
	btn_col.add_child(_make_button(GameConfig.t("about_versions"), _show_changelog))

	# Сброс прогресса — с подтверждением вторым нажатием.
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
			_toast("Прогресс сброшен")
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

# Окно «О версиях»: прокручиваемая история изменений поверх настроек.
func _show_changelog() -> void:
	# Своё модальное окно вместо AcceptDialog: нативный диалог Godot рисуется
	# системной темой ОС и торчит белым квадратом посреди неонового меню (та
	# самая жалоба «окно не в общей стилистике»). Тёмная панель + оверлей —
	# как и всё остальное в игре.
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
	panel.add_child(col)

	var title := Label.new()
	title.text = "О версиях"
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	title.add_theme_font_size_override("font_size", 24)
	title.add_theme_color_override("font_color", Color(0.85, 0.85, 1.0))
	col.add_child(title)

	var scroll := ScrollContainer.new()
	scroll.custom_minimum_size = Vector2(640, 460)
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	col.add_child(scroll)
	var lbl := Label.new()
	lbl.text = CHANGELOG_TEXT
	lbl.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	lbl.custom_minimum_size = Vector2(600, 0)
	lbl.add_theme_font_size_override("font_size", 15)
	lbl.add_theme_color_override("font_color", Color(0.82, 0.86, 0.95))
	scroll.add_child(lbl)

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
		_toast("Все %d уровней открыты" % LEVEL_COUNT)
	else:
		_toast("Уровни закрыты до %d" % GameConfig.max_unlocked_level)

# Короткое всплывающее сообщение по центру экрана.
# Короткое подтверждение действия (настройка применена и т.п.) — фон-плашка,
# как и все остальные всплывающие сообщения в игре, а не голый цветной текст.
func _toast(text: String) -> void:
	var wrap := CenterContainer.new()
	wrap.set_anchors_preset(Control.PRESET_TOP_WIDE)
	wrap.position = Vector2(0, 20)
	wrap.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(wrap)

	var panel := PanelContainer.new()
	panel.add_theme_stylebox_override("panel", UIStyle.panel_stylebox(Color(0.4, 0.95, 0.7, 0.6)))
	wrap.add_child(panel)

	var lbl := Label.new()
	lbl.text = text
	lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	lbl.add_theme_font_size_override("font_size", 20)
	lbl.add_theme_color_override("font_color", Color(0.7, 1.0, 0.85))
	panel.add_child(lbl)

	var tw := create_tween()
	tw.tween_interval(1.4)
	tw.tween_property(panel, "modulate:a", 0.0, 0.6)
	tw.tween_callback(wrap.queue_free)

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
	note.text = GameConfig.tt("Чем выше уровень — тем больше лабиринт, темнее, быстрее разрядка и чаще события.\nЗакрытые уровни (🔒) откроются после прохождения предыдущего.", "The higher the level, the bigger the maze, the darker it gets, and the faster your light drains.\nLocked levels (🔒) unlock after you clear the previous one.")
	note.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	note.add_theme_font_size_override("font_size", 15)
	note.add_theme_color_override("font_color", Color(0.6, 0.6, 0.7))
	inner.add_child(note)

	_level_grid = GridContainer.new()
	_level_grid.columns = 10
	_level_grid.add_theme_constant_override("h_separation", 8)
	_level_grid.add_theme_constant_override("v_separation", 8)
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

	var is_en := GameConfig.locale == "en"
	var head := Label.new()
	head.text = GameConfig.tt("Дневник лабиринта", "Maze Journal")
	head.add_theme_font_size_override("font_size", 30)
	head.add_theme_color_override("font_color", Color(0.85, 0.9, 1.0))
	_journal_box.add_child(head)

	# --- Голос лабиринта: наблюдения и советы (главная карточка, сверху) ---
	var voice := _journal_panel(GameConfig.tt("✧ Голос лабиринта", "✧ Voice of the Maze"), Color(1.0, 0.85, 0.3))
	for line in _journal_voice_lines(hist, s):
		_journal_line(voice, line, Color(0.95, 0.9, 0.75), 16, true)

	# --- Путь мастерства: лабиринт не комментирует, а ТРЕНИРУЕТ (п. «ноухау») ---
	# Последовательная программа: по статистике находим первый непройденный
	# «урок», показываем прогресс до цели и конкретный совет, как её взять.
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

	# --- Твой стиль: навыки в картинках — частота, мастерство, форма Апекса ---
	var style := _journal_panel(GameConfig.tt("Твой стиль", "Your Style"), Color(0.8, 0.7, 1.0))
	var srow := HBoxContainer.new()
	srow.add_theme_constant_override("separation", 12)
	style.add_child(srow)
	for id in ["flash", "dash", "smother", "sonar", "shield", "guide", "reveal", "pulse", "mirage", "breach", "chrono"]:
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
			"shield": "Щит", "guide": "Искра", "reveal": "Озарение", "pulse": "Пульс",
			"mirage": "Мираж", "breach": "Разлом", "chrono": "Хронос"}.get(id, id)
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
		"guide": "Искра", "reveal": "Озарение", "smother": "Тление", "pulse": "Пульс",
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
	var path := _journal_panel(GameConfig.tt("Путь", "Path"), Color(0.5, 0.8, 1.0))
	_journal_line(path, "Этажей пройдено: %d   ·   осколков собрано: %d" % [
		int(s.get("levels_cleared", 0)), int(s.get("shards_total", 0))])
	_journal_line(path, "Лучшая глубина Накала: %d   ·   рекорд банка: %d   ·   забегов: %d / %d" % [
		int(s.get("best_depth", 0)), int(s.get("best_ember", 0)),
		int(s.get("runs_ended", 0)), int(s.get("runs_started", 0))])
	_journal_line(path, "Ранги:   S %d   ·   A %d   ·   B %d   ·   C %d   ·   D %d" % [
		int(s.get("rank_S", 0)), int(s.get("rank_A", 0)), int(s.get("rank_B", 0)),
		int(s.get("rank_C", 0)), int(s.get("rank_D", 0))])

	# --- Последние уровни: цветные строки со «спидометром» ---
	var recent := _journal_panel(GameConfig.tt("Последние уровни", "Recent levels"), Color(0.85, 0.9, 1.0))
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
		var goals := _journal_panel(GameConfig.tt("Путь к навыкам", "Path to skills"), Color(0.5, 1.0, 0.6))
		_journal_line(goals, "Навыки открываются за дела — или за SP в меню навыков, что раньше.", Color(0.6, 0.75, 0.65), 14, true)
		var names := {"sonar": "Сонар (E)", "shield": "Щит (C)", "guide": "Искра (G)", "reveal": "Озарение (F)", "pulse": "Пульс (B)"}
		for id in locked_ms:
			var ms: Dictionary = GameConfig.SKILL_MILESTONES[id]
			var cur := mini(int(s.get(ms["stat"], 0)), int(ms["need"]))
			var frac := float(cur) / float(ms["need"])
			var bar := "▰".repeat(int(round(frac * 8.0))) + "▱".repeat(8 - int(round(frac * 8.0)))
			_journal_line(goals, "%s   %s   %d / %d — %s" % [names.get(id, id), bar, cur, int(ms["need"]), str(ms["text"])])

	# --- Спуск дня: серия и последние результаты ---
	if not GameConfig.daily_history.is_empty():
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

	# --- Забеги Накала: слоты ---
	var runs := _journal_panel(GameConfig.tt("Забеги Накала", "Ember runs"), Color(1.0, 0.62, 0.25))
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
const _SKILL_NAMES_EN := {"flash": "Flash", "dash": "Dash", "sonar": "Sonar",
	"shield": "Shield", "guide": "Guide", "reveal": "Reveal", "smother": "Smother",
	"mirage": "Mirage", "breach": "Breach", "chrono": "Chrono"}

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

func _bestiary_appear(i: int) -> String:
	return (_BESTIARY_APPEAR_EN if GameConfig.locale == "en" else _BESTIARY_APPEAR)[i]

func _build_bestiary(root: VBoxContainer) -> void:
	_bestiary_scroll = ScrollContainer.new()
	_bestiary_scroll.visible = false
	_bestiary_scroll.custom_minimum_size = Vector2(720, 520)
	_bestiary_scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	root.add_child(_bestiary_scroll)
	_bestiary_box = VBoxContainer.new()
	_bestiary_box.add_theme_constant_override("separation", 12)
	_bestiary_box.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_bestiary_scroll.add_child(_bestiary_box)

func _on_open_bestiary() -> void:
	_populate_bestiary()
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

func _bestiary_line(box: VBoxContainer, t: String, col: Color = Color(0.78, 0.84, 0.95), fsize: int = 15, wrap: bool = true) -> void:
	var l := Label.new()
	l.text = t
	l.add_theme_font_size_override("font_size", fsize)
	l.add_theme_color_override("font_color", col)
	if wrap:
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
	if lvl >= 25:
		if en:
			out.append("You've gone deep: the maze unleashes elites — Guardians%s%s." % [
				", Phantoms" if lvl >= 30 else "", " and Leeches" if lvl >= 35 else ""])
		else:
			out.append("Ты спустился глубоко: лабиринт выпускает элиту — Стражей%s%s." % [
				", Фантомов" if lvl >= 30 else "", " и Пиявок" if lvl >= 35 else ""])
	if out.is_empty():
		out.append("The dark is still dozing: enemies at their normal strength. The deeper, the fiercer." if en else
			"Пока тьма дремлет: враги в своей обычной силе. Чем глубже — тем злее.")
	return out

func _populate_bestiary() -> void:
	for c in _bestiary_box.get_children():
		c.queue_free()
	var s: Dictionary = GameConfig.stats

	var en := GameConfig.locale == "en"
	var head := Label.new()
	head.text = "Maze Dossier" if en else "Досье лабиринта"
	head.add_theme_font_size_override("font_size", 30)
	head.add_theme_color_override("font_color", Color(0.85, 0.9, 1.0))
	_bestiary_box.add_child(head)

	var known := 0
	for t in GameConfig.BESTIARY.size():
		if int(s.get("seen_t%d" % t, 0)) > 0:
			known += 1
	var sub := Label.new()
	sub.text = ("Dossiers unlocked: %d of %d. A encounter reveals the name, a victory — its weaknesses." % [known, GameConfig.BESTIARY.size()]) if en else \
		("Открыто досье: %d из %d. Встреча открывает имя, победа — слабости." % [known, GameConfig.BESTIARY.size()])
	sub.add_theme_font_size_override("font_size", 14)
	sub.add_theme_color_override("font_color", Color(0.6, 0.68, 0.8))
	_bestiary_box.add_child(sub)

	# --- Текущая угроза: живое объяснение силы врагов ---
	var threat := _bestiary_panel(("⚠ Current threat" if en else "⚠ Текущая угроза"), Color(1.0, 0.55, 0.25))
	for line in _bestiary_threat_lines():
		_bestiary_line(threat, str(line), Color(0.95, 0.85, 0.7))

	# --- Карточки врагов ---
	for t in GameConfig.BESTIARY.size():
		var d: Dictionary = GameConfig.BESTIARY[t]
		var seen := int(s.get("seen_t%d" % t, 0))
		var kills := int(s.get("kill_t%d" % t, 0))
		var hits := int(s.get("hit_t%d" % t, 0))
		var col: Color = d["color"]

		if seen <= 0:
			# Неизвестный: силуэт и намёк, где искать.
			var lock := _bestiary_panel("???", Color(0.35, 0.4, 0.5))
			var lrow := HBoxContainer.new()
			lrow.add_theme_constant_override("separation", 14)
			lock.add_child(lrow)
			var sil := TextureRect.new()
			sil.texture = MazeTextures.make_enemy(t, 26)
			sil.stretch_mode = TextureRect.STRETCH_KEEP_CENTERED
			sil.custom_minimum_size = Vector2(64, 64)
			sil.modulate = Color(0.06, 0.07, 0.1)   # чёрный силуэт
			lrow.add_child(sil)
			var lv := VBoxContainer.new()
			lrow.add_child(lv)
			_bestiary_line(lv, ("Not encountered yet (%s)." % _bestiary_appear(t)) if en else ("Ещё не встречен (%s)." % _bestiary_appear(t)), Color(0.5, 0.55, 0.65))
			continue

		var box := _bestiary_panel(GameConfig.bestiary_name(t), col)
		var row := HBoxContainer.new()
		row.add_theme_constant_override("separation", 14)
		box.add_child(row)

		# Портрет: сейчас процедурный (make_enemy), позже заменяем текстуру тут же.
		var ic := TextureRect.new()
		ic.texture = MazeTextures.make_enemy(t, 26)
		ic.stretch_mode = TextureRect.STRETCH_KEEP_CENTERED
		ic.custom_minimum_size = Vector2(64, 64)
		row.add_child(ic)

		var body := VBoxContainer.new()
		body.add_theme_constant_override("separation", 4)
		body.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		row.add_child(body)

		_bestiary_line(body, GameConfig.bestiary_lore(t), Color(0.75, 0.8, 0.92))
		if kills > 0:
			_bestiary_line(body, ("Tactic: %s" % GameConfig.bestiary_tactic(t)) if en else ("Тактика: %s" % GameConfig.bestiary_tactic(t)), Color(0.6, 1.0, 0.7))
		else:
			_bestiary_line(body, "Dossier incomplete: defeat one to record its weaknesses." if en else "Досье неполно: одолей одного, чтобы вписать его слабости.", Color(0.85, 0.75, 0.5))
		_bestiary_line(body, ("Encounters: %d   •   Defeated: %d   •   Hits on you: %d   •   %s" % [seen, kills, hits, _bestiary_appear(t)]) if en else
			("Встреч: %d   •   Побеждено: %d   •   Ударов по тебе: %d   •   %s" % [seen, kills, hits, _bestiary_appear(t)]),
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
	for id in ["flash", "dash", "smother", "sonar", "shield", "guide", "reveal", "pulse", "mirage", "breach", "chrono"]:
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
			{"title": "Collector: 25 shards (unlocks Sonar)", "done": shards >= 25,
			 "progress": "%d/25" % mini(shards, 25),
			 "how": "shards are both keys and Will. Detour for a shard: it pays off."},
			{"title": "Fighter: defeat 8 enemies (unlocks Shield)", "done": kills >= 8,
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
			 "how": "rank formula: all shards + no damage + speed. The breakdown is on the victory screen."},
			{"title": "Master: bring any skill to 3★", "done": best_mastery >= 3,
			 "progress": "best — %d★" % best_mastery,
			 "how": "mastery grows from uses (10 = ★). Or buy an upgrade for SP in the skill shop."},
			{"title": "Apex: unlock all 7 active skills (or 4+ skills with one at ★5)", "done": bool(GameConfig.skills_unlocked.get("apex", false)),
			 "progress": "",
			 "how": "buy them for SP or earn them as milestones (Journal → «Path to skills»). The seventh skill unlocks Apex (H) on its own — or master one skill to ★5 once you own 4+."},
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
		{"title": "Собиратель: 25 осколков (откроет Сонар)", "done": shards >= 25,
		 "progress": "%d/25" % mini(shards, 25),
		 "how": "осколки — это и ключи, и Воля. Сверни с прямого пути ради осколка: он окупается."},
		{"title": "Боец: победи 8 врагов (откроет Щит)", "done": kills >= 8,
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
		 "how": "формула ранга: все осколки + без урона + скорость. Расшифровка — на экране победы."},
		{"title": "Мастер: доведи любой навык до 3★", "done": best_mastery >= 3,
		 "progress": "лучший — %d★" % best_mastery,
		 "how": "мастерство растёт от применений (10 = ★). Или купи усиление за SP в магазине навыков."},
		{"title": "Апекс: открой все 7 активных навыков (или 4+ навыка и один на ★5)", "done": bool(GameConfig.skills_unlocked.get("apex", false)),
		 "progress": "",
		 "how": "покупай за SP или бери целями (Дневник → «Путь к навыкам»). Седьмой навык откроет Апекс (H) сам — или прокачай один навык до ★5, когда куплено 4+."},
		{"title": "Огненосец: глубина 10 в «Накале»", "done": depth >= 10,
		 "progress": "%d/10" % mini(depth, 10),
		 "how": "не жадничай: банкуй Накал на каждом алтаре. Несомый жар притягивает тьму — банк нет."},
		{"title": "Пылающий: пройди уровень на высшей сложности", "done": blazing_done,
		 "progress": "ещё нет" if not blazing_done else "есть",
		 "how": "станций нет — свет только из осколков (запас ×2). Планируй маршрут по осколкам и не стой на месте."},
	]

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
	for pair in [[GameConfig.t("top_shop"), _on_open_shop], [GameConfig.t("top_tutorial"), _on_open_tutorial], [GameConfig.t("top_journal"), _on_open_journal], [GameConfig.t("top_bestiary"), _on_open_bestiary]]:
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

	cards.add_child(_mode_card(GameConfig.t("mode_ember_title"),
		GameConfig.t("mode_ember_desc"),
		Color(1.0, 0.55, 0.25), _on_open_runs))

	var streak := GameConfig.daily_streak()
	cards.add_child(_mode_card(GameConfig.t("mode_daily_title"),
		"%s\n\n%s%s" % [GameConfig.t("mode_daily_desc"), GameConfig.today_str(),
			("\n🔥 %d" % streak) if streak >= 2 else ""],
		Color(1.0, 0.85, 0.35), _on_open_daily))

	cards.add_child(_mode_card(GameConfig.t("mode_lair_title"),
		GameConfig.t("mode_lair_desc") % [GameConfig.lair_max_unlocked, GameConfig.LAIR_LEVELS],
		Color(1.0, 0.3, 0.35), _on_open_lair_select))

	# --- Одна строка: выбор уровня + сложность ---
	var opts_row := HBoxContainer.new()
	opts_row.alignment = BoxContainer.ALIGNMENT_CENTER
	opts_row.add_theme_constant_override("separation", 12)
	_mode_box.add_child(opts_row)

	var pick_btn := _make_button(GameConfig.t("pick_level") % GameConfig.max_unlocked_level, _on_open_level_select)
	pick_btn.custom_minimum_size = Vector2(220, 42)
	pick_btn.add_theme_font_size_override("font_size", 16)
	opts_row.add_child(pick_btn)

	var diff_lbl := Label.new()
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
		opts_row.add_child(db)
	_mode_box.add_child(diff_desc)

# Большая квадратная карточка режима: цветная рамка, название, описание.
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
		if _inside_scroll(b):
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

func _build_help(root: VBoxContainer) -> void:
	_help_scroll = ScrollContainer.new()
	_help_scroll.visible = false
	_help_scroll.custom_minimum_size = Vector2(720, 420)
	_help_scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	root.add_child(_help_scroll)

	var outer := VBoxContainer.new()
	outer.add_theme_constant_override("separation", 14)
	_help_scroll.add_child(outer)

	var title := Label.new()
	title.text = "Справка"
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	title.add_theme_font_size_override("font_size", 30)
	title.add_theme_color_override("font_color", Color(0.85, 0.85, 1.0))
	outer.add_child(title)

	# Стрелки — по бокам самой карточки в одной строке (а не отдельным рядом
	# под ней): щёлкать всегда в ОДНОМ И ТОМ ЖЕ месте, независимо от того,
	# насколько высок текущий слайд (см. жалобу «кнопки скачут»).
	var row := HBoxContainer.new()
	row.alignment = BoxContainer.ALIGNMENT_CENTER
	row.add_theme_constant_override("separation", 14)
	outer.add_child(row)

	var prev_btn := _make_button("‹", func() -> void: _populate_help_slide(_help_step(-1)))
	prev_btn.custom_minimum_size = Vector2(52, 52)
	prev_btn.add_theme_font_size_override("font_size", 26)
	prev_btn.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	row.add_child(prev_btn)

	# Карточка — фиксированный размер на ВСЕХ слайдах (а не «подстраивается»
	# под контент): контент центрируется внутри неё, стрелки не гуляют по высоте.
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

	# ScrollContainer, а не голый CenterContainer: его custom_minimum_size —
	# ЖЁСТКИЙ потолок независимо от содержимого (длинное имя врага без
	# пробелов или широкая галерея не может «раздуть» карточку и сдвинуть
	# стрелки — см. жалобу «кнопки скачут», проверено харнессом). Если слайд
	# всё же не влезает — внутри появится вертикальная прокрутка, а не сдвиг.
	var slide_scroll := ScrollContainer.new()
	slide_scroll.custom_minimum_size = Vector2(556, 268)
	# SHOW_ALWAYS на обеих осях — не AUTO и не DISABLED: DISABLED снимает
	# ограничение размера (контейнер просто раздувается под контент), а
	# «плавающее» появление/исчезновение авто-скроллбара само по себе чуть
	# меняет ширину/высоту. Только «всегда показан» держит размер карточки
	# ИДЕНТИЧНЫМ на любом слайде — стрелки не «дёргаются» (проверено харнессом).
	slide_scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_SHOW_ALWAYS
	slide_scroll.vertical_scroll_mode = ScrollContainer.SCROLL_MODE_SHOW_ALWAYS
	card.add_child(slide_scroll)

	var center := CenterContainer.new()
	center.custom_minimum_size = Vector2(556, 0)
	slide_scroll.add_child(center)

	_help_box = VBoxContainer.new()
	_help_box.add_theme_constant_override("separation", 10)
	center.add_child(_help_box)

	var next_btn := _make_button("›", func() -> void: _populate_help_slide(_help_step(1)))
	next_btn.custom_minimum_size = Vector2(52, 52)
	next_btn.add_theme_font_size_override("font_size", 26)
	next_btn.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	row.add_child(next_btn)

	_help_nav_label = Label.new()
	_help_nav_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_help_nav_label.add_theme_font_size_override("font_size", 16)
	_help_nav_label.add_theme_color_override("font_color", Color(0.6, 0.68, 0.8))
	outer.add_child(_help_nav_label)

	_help_show_all_btn = _make_button("Показать все темы", func() -> void:
		GameConfig.help_intro_seen = true
		GameConfig.save_game()
		_help_show_all_btn.visible = false
		_populate_help_slide(0))
	_help_show_all_btn.visible = not GameConfig.help_intro_seen
	outer.add_child(_help_show_all_btn)

	_populate_help_slide(0)

# Следующий/предыдущий индекс слайда с учётом режима новичка: пока
# `help_intro_seen == false`, шаг идёт только по _HELP_BEGINNER_IDX по кругу,
# а не по всему списку тем.
func _help_step(dir: int) -> int:
	if GameConfig.help_intro_seen:
		return _help_slide_idx + dir
	var pos := _HELP_BEGINNER_IDX.find(_help_slide_idx)
	if pos == -1:
		pos = 0
	var n := _HELP_BEGINNER_IDX.size()
	return _HELP_BEGINNER_IDX[((pos + dir) % n + n) % n]

# Перестроить содержимое карточки под слайд idx (с зацикливанием по кругу).
func _populate_help_slide(idx: int) -> void:
	var titles := _help_titles()
	var n := titles.size()
	_help_slide_idx = ((idx % n) + n) % n
	for c in _help_box.get_children():
		c.queue_free()

	var t := Label.new()
	t.text = titles[_help_slide_idx]
	t.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	t.add_theme_font_size_override("font_size", 24)
	t.add_theme_color_override("font_color", Color(0.85, 0.9, 1.0))
	_help_box.add_child(t)

	var en := GameConfig.locale == "en"
	match _help_slide_idx:
		0:
			# Игрок (белый огонёк) -> золотой выход - те же цвета, что в игре.
			_help_icon_row([
				[MazeTextures.make_player_orb(22), Color.WHITE],
				"->",
				[MazeTextures.make_gem(18, Color(1.0, 0.86, 0.30)), Color.WHITE],
			])
			_help_para(("You are a spark of light in the dark. Reach the golden EXIT before your Light burns out." if en else "Ты -- огонёк во тьме. Дойди до золотого ВЫХОДА, не дав погаснуть Свету."))
		1:
			_help_icon_row([
				[MazeTextures.make_light(46), Color(1.0, 0.85, 0.3)],
				[MazeTextures.make_light(46), Color(0.68, 0.5, 1.0)],
			])
			var s1_en := "💡 Light (yellow bar) — your life: fades in the dark and from enemy hits, refills at blue crystals (doesn't drain at all while you stand near one). Fully out — you lose a life.\n\n🔮 Will (violet bar) — fuel for skills: builds on its own from shards and sips, the dark never touches it."
			var s1_ru := "💡 Свет (жёлтая полоса) — твоя жизнь: гаснет во тьме и от ударов врагов, восполняется у синих кристаллов (рядом с ними не тает совсем). Погас совсем — минус жизнь.\n\n🔮 Воля (фиолетовая полоса) — топливо навыков: копится сама с осколков и глотков, тьма её не трогает."
			_help_para(s1_en if en else s1_ru)
		2:
			_help_icon_row([
				[MazeTextures.make_gem(18, Color(1.0, 0.82, 0.32)), Color.WHITE],
				[MazeTextures.make_portal(18, Color(0.66, 0.45, 1.0)), Color.WHITE],
				[MazeTextures.make_portal(18, Color(1.0, 0.52, 0.32)), Color.WHITE],
			])
			var s2_en := "✦ Light shards — a sip of Light, a bit of Will, and a KEY for locked doors.\n\n🚪 Doors between floors: the first (violet) is always open, the rest (amber) need a key."
			var s2_ru := "✦ Осколки света — глоток Света, немного Воли и КЛЮЧ от запертых дверей.\n\n🚪 Двери между этажами: первая (фиолетовая) всегда открыта, остальные (янтарные) — только по ключу."
			_help_para(s2_en if en else s2_ru)
		3:
			_help_icon_row([[MazeTextures.make_gem(18, Color(1.0, 0.85, 0.25)), Color.WHITE]])
			var s3_en := "Once per level a BEACON lights up somewhere for 20-30 sec — reach it for a random bonus.\n\nRandom Events (fog, light leak, an earthquake…) don't get in your way — they add variety."
			var s3_ru := "Раз в уровень где-то на 20-30 сек загорается МАЯК — добежишь, получишь случайный бонус.\n\nСлучайные События (туман, утечка света, землетрясение…) не мешают, а разнообразят путь."
			_help_para(s3_en if en else s3_ru)
		4:
			_help_slide_gallery(
				([["flash","Q Flash"],["dash","Shift Dash"],["smother","R Smother"],["sonar","E Sonar"],["shield","C Shield"],["guide","G Guide"],["reveal","F Reveal"],["pulse","B Pulse"],["mirage","T Mirage"],["breach","Y Breach"],["chrono","V Chrono"],["apex","H APEX"]] if en else
				[["flash","Q Вспышка"],["dash","Shift Рывок"],["smother","R Тление"],["sonar","E Сонар"],["shield","C Щит"],["guide","G Искра"],["reveal","F Озарение"],["pulse","B Пульс"],["mirage","T Мираж"],["breach","Y Разлом"],["chrono","V Хронос"],["apex","H АПЕКС"]]),
				6,
				func(id: String) -> Texture2D: return SkillIcons.make(id, 30),
				func(id: String) -> Color: return SkillIcons.color_of(id),
				("Dash during Flash - a Light Spear (x1.5 range). Sonar during Reveal - Omniscience.\nPassives grow on their own from your actions - track progress in the Skill Shop." if en else
				"Рывок во время Вспышки -- «Световое копьё» (x1.5 дальность). Сонар во время Озарения -- «Всевидение».\nПассивки растут сами от твоих действий -- прогресс в Магазине навыков."))
		5:
			var en_names := {0:"Wanderer",1:"Hound",2:"Cyclite",3:"Guardian",4:"Phantom",5:"Leech"}
			var items: Array = []
			for it in GameConfig.BESTIARY.size():
				var d: Dictionary = GameConfig.BESTIARY[it]
				items.append([it, (str(en_names.get(it, d["name"])) if en else str(d["name"]))])
			_help_slide_gallery(items, 6,
				func(id): return MazeTextures.make_enemy(int(id), 20),
				func(id): return GameConfig.BESTIARY[int(id)]["color"],
				("Three basics - from level 4; elites (Guardian/Phantom/Leech) - deeper in.\nFull dossier and tactics for each - in the Bestiary." if en else
				"Три обычных -- с 4-го уровня; элита (Страж/Фантом/Пиявка) -- на глубине.\nПолное досье и тактика по каждому -- в «Бестиарии»."))
		6:
			_help_slide_gallery(
				([["gold","Runner: catch - reward"],["azure","Wisp: distracts enemies"],["crimson","Moles: avoid the burrow"],["silver","Thief: chase, get it back"]] if en else
				[["gold","Беглец: поймай — награда"],["azure","Огонёк: отвлекает врагов"],["crimson","Кроты: не стой над норой"],["silver","Вор: догони, верни своё"]]),
				4,
				func(id: String) -> Texture2D: return MazeTextures.make_gem(15, _GUEST_COLORS.get(id, Color.WHITE)),
				func(id: String) -> Color: return _GUEST_COLORS.get(id, Color.WHITE),
				("Random optional events -- at most once per level, from level 3." if en else "Случайные необязательные события -- не чаще раза за уровень, с 3-го уровня."))
		7:
			_help_slide_gallery(
				([["u","LEVELS"], ["n","EMBER"], ["d","DAILY"], ["l","LAIR"]] if en else
				[["u","УРОВНИ"], ["n","НАКАЛ"], ["d","СПУСК ДНЯ"], ["l","ЛОГОВО"]]),
				4,
				func(id: String) -> Texture2D: return MazeTextures.make_gem(15, _MODE_COLORS.get(id, Color.WHITE)),
				func(id: String) -> Color: return _MODE_COLORS.get(id, Color.WHITE),
				("Levels - a 50-level campaign, progress forever. Ember - a roguelite run from zero, 3 lives for the run. Daily Dive - one maze for everyone, one attempt a day. Lair - 10 big levels: a dark lord in a throne room at the maze's center." if en else
				"«Уровни» -- 50 уровней кампании, прогресс навсегда. «Накал» -- рогалик-спуск с нуля, 3 жизни на весь забег. «Спуск дня» -- один лабиринт на всех, одна попытка в сутки. «Логово» -- 10 больших уровней: владыка тьмы в тронном зале, в центре лабиринта."))
		8:
			_help_slide_gallery(
				[["S","S"], ["A","A"], ["B","B"], ["C","C"], ["D","D"]],
				5,
				func(id: String) -> Texture2D: return MazeTextures.make_gem(13, _RESULT_RANK_COLORS.get(id, Color.WHITE)),
				func(id: String) -> Color: return _RESULT_RANK_COLORS.get(id, Color.WHITE),
				("Difficulty (Ember / Blaze / Inferno) shifts balance and rewards x0.75 / x1 / x1.5 -- Inferno Levels has no stations.\n\nLevel rank (S...D) also multiplies the reward -- the breakdown awaits on the victory screen." if en else
				"Сложность (Тлеющий / Горящий / Пылающий) меняет баланс и награды x0.75 / x1 / x1.5 -- в Пылающем «Уровней» станций нет.\n\nРанг уровня (S...D) тоже множит награду -- расшифровка ждёт на экране победы."))
		9:
			_help_icon_row(["Q","Shift","R","E","C","F","G","B","H","T","Y","V"])
			_help_para(("Arrow keys move you, the keys above are skills.\nP or Esc -- pause. Restarting a level -- only via the pause menu or results screen." if en else
				"Стрелки -- движение, клавиши выше -- навыки.\nP или Esc -- пауза. Перезапуск уровня -- только через меню паузы или экран результатов."))
		10:
			_help_icon_row([[MazeTextures.make_portal(20, Color(0.55, 0.95, 0.6)), Color.WHITE]])
			_help_para(CHANGELOG_17_A_EN if en else CHANGELOG_17_A)
		11:
			_help_icon_row([[MazeTextures.make_portal(20, Color(0.55, 0.95, 0.6)), Color.WHITE]])
			_help_para(CHANGELOG_17_B_EN if en else CHANGELOG_17_B)
		12:
			_help_icon_row([[MazeTextures.make_portal(20, Color(1.0, 0.3, 0.35)), Color.WHITE]])
			_help_para(CHANGELOG_16_A_EN if en else CHANGELOG_16_A)
		13:
			_help_icon_row([[MazeTextures.make_portal(20, Color(1.0, 0.3, 0.35)), Color.WHITE]])
			_help_para(CHANGELOG_16_B_EN if en else CHANGELOG_16_B)
		14:
			_help_icon_row([[MazeTextures.make_portal(20, Color(0.45, 0.75, 1.0)), Color.WHITE]])
			_help_para(CHANGELOG_15_A_EN if en else CHANGELOG_15_A)
		15:
			_help_icon_row([[MazeTextures.make_portal(20, Color(0.45, 0.75, 1.0)), Color.WHITE]])
			_help_para(CHANGELOG_15_B_EN if en else CHANGELOG_15_B)

	if GameConfig.help_intro_seen:
		_help_nav_label.text = "%d / %d" % [_help_slide_idx + 1, n]
	else:
		var bpos := _HELP_BEGINNER_IDX.find(_help_slide_idx)
		_help_nav_label.text = "%d / %d" % [maxi(bpos, 0) + 1, _HELP_BEGINNER_IDX.size()]

# Цветовые метки гостей лабиринта (те же, что у самих гостей в игре).
const _GUEST_COLORS := {
	"gold": Color(1.0, 0.8, 0.2), "azure": Color(0.5, 1.0, 0.75),
	"crimson": Color(0.85, 0.6, 0.3), "silver": Color(0.7, 0.4, 1.0),
}
# Цвета карточек режимов (те же, что на экране «Играть»).
const _MODE_COLORS := {
	"u": Color(0.45, 0.75, 1.0), "n": Color(1.0, 0.55, 0.25),
	"d": Color(1.0, 0.85, 0.35), "l": Color(1.0, 0.3, 0.35),
}

# Мини-галерея слайда: иконка + подпись в сетке, короткая заметка под ней.
func _help_slide_gallery(items: Array, columns: int, icon_fn: Callable, color_fn: Callable, note: String) -> void:
	var gal := GridContainer.new()
	gal.columns = columns
	gal.add_theme_constant_override("h_separation", 14)
	gal.add_theme_constant_override("v_separation", 6)
	_help_box.add_child(gal)
	for pair in items:
		var id = pair[0]
		var label_text: String = str(pair[1])
		var cell := VBoxContainer.new()
		cell.alignment = BoxContainer.ALIGNMENT_CENTER
		var ic := TextureRect.new()
		ic.texture = icon_fn.call(id)
		ic.stretch_mode = TextureRect.STRETCH_KEEP_CENTERED
		ic.custom_minimum_size = Vector2(30, 30)
		cell.add_child(ic)
		var lb := Label.new()
		lb.text = label_text
		lb.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		lb.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		lb.custom_minimum_size = Vector2(76, 0)
		lb.add_theme_font_size_override("font_size", 11)
		lb.add_theme_color_override("font_color", color_fn.call(id))
		cell.add_child(lb)
		gal.add_child(cell)
	_help_para(note)

# Небольшой эскиз-ряд над текстом слайда: элементы — либо [Texture2D, Color]
# (иконка с тонировкой), либо String (клавиша/стрелка как текстовый глиф).
func _help_icon_row(items: Array) -> void:
	var row := HBoxContainer.new()
	row.alignment = BoxContainer.ALIGNMENT_CENTER
	row.add_theme_constant_override("separation", 12)
	_help_box.add_child(row)
	for it in items:
		if it is String:
			var lb := Label.new()
			lb.text = it
			lb.add_theme_font_size_override("font_size", 22)
			lb.add_theme_color_override("font_color", Color(0.6, 0.68, 0.8))
			row.add_child(lb)
		else:
			var spec: Array = it
			var ic := TextureRect.new()
			ic.texture = spec[0]
			ic.modulate = spec[1]
			ic.stretch_mode = TextureRect.STRETCH_KEEP_CENTERED
			ic.custom_minimum_size = Vector2(40, 40)
			row.add_child(ic)

# Абзац текущего слайда: автоперенос, фиксированная ширина колонки.
func _help_para(text: String) -> void:
	var l := Label.new()
	l.text = text
	l.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	l.custom_minimum_size = Vector2(520, 0)
	l.add_theme_font_size_override("font_size", 15)
	_help_box.add_child(l)

func _on_open_help() -> void:
	_hide_all_panels()
	_populate_help_slide(0)
	_help_scroll.visible = true
	_back_btn.visible = true

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

func _on_open_settings() -> void:
	_hide_all_panels()
	_settings_scroll.visible = true
	_back_btn.visible = true

func _on_reset_progress() -> void:
	GameConfig.reset_progress()

func _on_quit() -> void:
	GameConfig.save_game()
	get_tree().quit()
