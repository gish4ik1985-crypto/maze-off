extends Node2D

const TILE := 48.0        # размер одной клетки сетки в пикселях
const MAX_LEVEL := 20     # всего уровней (11-20 — органические «корни»)
const ORGANIC_FROM := 11  # с этого уровня лабиринт ветвится как корни/ветки
const MAX_FLOORS := 4     # потолок числа этажей
const MAX_DIM := 36       # потолок размера лабиринта по стороне
const MAX_STATIONS := 40  # потолок станций на этаж (защита от мерцания света)
const SHARDS_PER_FLOOR := 5  # осколков света на этаж

# ── Накал (режим забега) ─────────────────────────────────────────────────────
const EMBER_PER_SHARD   := 10.0    # Накал за осколок (умножается на серию)
const EMBER_LEVEL_BONUS := 25.0    # Накал за пройденный этаж
const EMBER_CLEAN_BONUS := 20.0    # доп. Накал, если этаж пройден без потери жизни
const EMBER_STREAK_STEP := 0.25    # +25% к набору за каждый этаж серии
const EMBER_STREAK_MAX  := 8       # потолок серии
const EMBER_HEAT_FULL   := 200.0   # при стольких единицах несомого Накала — макс. «жар»
# Цены апгрейдов на алтаре (в Накале), валюта — забанканный Накал.
const ALTAR_OFFER := [
	{"id": "sonar",    "name": "Сонар (E)",          "cost": 60},
	{"id": "shield",   "name": "Щит (C)",            "cost": 70},
	{"id": "guide",    "name": "Искра (G)",          "cost": 90},
	{"id": "reveal",   "name": "Озарение (F)",       "cost": 90},
	{"id": "range",    "name": "Дальний свет +25%",  "cost": 50},
	{"id": "legs",     "name": "Лёгкие ноги +15%",   "cost": 50},
	{"id": "capacity", "name": "Ёмкость +30%",       "cost": 70},
	{"id": "save",     "name": "Энергосбережение",   "cost": 70},
	{"id": "charge",   "name": "Быстрая зарядка",    "cost": 70},
	{"id": "magic",    "name": "Эффективная магия",  "cost": 110},
]

const FLOOR_COLOR := Color(0.07, 0.08, 0.11)  # цвет пола (виден только при свете)

# Неоновые цвета стен по уровням (стиль Tron). Это ЯРКИЕ базовые цвета — из них
# textures.gd выводит тёмную крышку блока, цветной ореол грани и оттенок фона.
const WALL_THEMES := [
	Color(0.18, 0.72, 1.00),  # 1: электрик-циан
	Color(0.30, 0.52, 1.00),  # 2: лазурный синий
	Color(0.20, 0.92, 0.85),  # 3: бирюза/аква
	Color(0.50, 0.46, 1.00),  # 4: сине-фиолетовый
	Color(0.42, 0.78, 1.00),  # 5: ледяной голубой
]
var _wall_color: Color = WALL_THEMES[0]

# Неоновые тоннели (уровни 11-20): тёплый «биолюм» — корни/споры/магма
const ORGANIC_THEMES := [
	Color(1.00, 0.55, 0.18),  # тёплый янтарь
	Color(0.55, 1.00, 0.30),  # споровый лайм
	Color(1.00, 0.28, 0.30),  # магма
	Color(0.30, 0.78, 1.00),  # ледяной грот
	Color(1.00, 0.78, 0.20),  # золото
]
var _organic: bool = false
var _organic_color: Color = ORGANIC_THEMES[0]

# ── Биомы ────────────────────────────────────────────────────────────────────
# Каждые BIOME_SPAN этажей биом сменяется (циклически). Палитра биома задаёт цвет
# стен, ореол граней и оттенок фона (ambient выводится из _wall_color).
const BIOME_SPAN := 5
const BIOMES := [
	{
		"name": "Лазурные шахты",
		"colors": [
			Color(0.18, 0.72, 1.00), Color(0.30, 0.52, 1.00),
			Color(0.20, 0.92, 0.85), Color(0.42, 0.78, 1.00), Color(0.50, 0.46, 1.00),
		],
	},
	{
		"name": "Багровые недра",
		"colors": [
			Color(1.00, 0.32, 0.26), Color(1.00, 0.50, 0.16),
			Color(1.00, 0.22, 0.42), Color(0.96, 0.66, 0.20), Color(1.00, 0.40, 0.30),
		],
	},
	{
		"name": "Споровые пустоты",
		"colors": [
			Color(0.55, 1.00, 0.30), Color(0.30, 1.00, 0.62),
			Color(0.72, 0.96, 0.22), Color(0.40, 0.92, 0.55), Color(0.62, 1.00, 0.40),
		],
	},
]
var _biome: int = 0
var _biome_name: String = ""
var _wall_tex_cache: Dictionary = {}   # open_mask(int) -> CanvasTexture (на время постройки уровня)

var _level: int
var _floors: int
var _cols: int
var _rows: int
var _gw: int
var _gh: int
var _floor_gap: float
var _grids: Array = []
var _drain_mult: float = 1.0
var _floor_containers: Array = []      # Node2D на каждый этаж
var _organic_floors: Array = []        # organic_floor на каждый этаж (для перерисовки)
var _wall_nodes: Dictionary = {}       # Vector3i(f,gx,gy) -> StaticBody2D
var _door_links: Dictionary = {}       # Vector3i(f,cx,cy) -> Array[Vector3i] (переходы между этажами)
var _exit_cell: Vector2i = Vector2i.ZERO
var _exit_floor: int = 0

var _player: CharacterBody2D
var _cp_pos: Vector2
var _cp_floor: int = 0

var _lives: int = 3
var _shards_collected: int = 0
var _shards_total: int = 0
var _shards_remaining: Array = []   # сколько осколков ещё не собрано на каждом этаже
var _last_floor: int = -1           # для надписи при заходе на новый этаж
var _keys: int = 0

# Накал (активно только при GameConfig.active_run >= 0)
var _ember: float = 0.0          # несомый Накал (под угрозой при гибели)
var _ember_banked: int = 0       # забанканная валюта (тратится на алтаре)
var _ember_streak: int = 0       # серия чистых этажей → множитель набора
var _level_clean: bool = true    # на текущем этаже ещё не теряли жизнь
var _skill_uses_at_start: int = 0  # снимок суммы применений навыков (для ранга «без способностей»)
var _ember_label: Label          # HUD-индикатор Накала
var _altar_layer: CanvasLayer    # оверлей магазина-алтаря
var _altar_rows: VBoxContainer
var _altar_bank_lbl: Label

var _visited: Dictionary = {}    # Vector3i(floor,cx,cy) -> true (для миникарты)
var _heat_map: Dictionary = {}   # Vector3i(floor,cx,cy) -> float (секунды в клетке)
var _heat_sample_t: float = 0.0
var _optimal_path_len: int = 0   # длина BFS-кратчайшего пути (в клетках)

# Босс
const BOSS_EVERY_N := 10         # каждые N уровней в режиме Накал → босс-этаж
const BOSS_ARENA_COLS := 12
const BOSS_ARENA_ROWS := 10
var _boss_level: bool = false
var _boss: Node = null
var _boss_fragments: int = 0     # живых фрагментов в фазе 2
var _toast_time: float = 0.0
var _elapsed: float = 0.0
var _won: bool = false
var _dead: bool = false
var _paused: bool = false
var _game_over: bool = false

# Случайные события
var _events_enabled: bool = true
var _event_cd: float = 0.0
var _event_active: float = 0.0

# Интерфейс
var _time_label: Label
var _fps_label: Label          # счётчик FPS (внизу слева, если включён в настройках)
var _level_label: Label
var _win_label: Label
var _hud_layer: CanvasLayer     # слой HUD (layer 2) — прячем на экране результатов
var _msg_label: Label
var _event_label: Label
var _energy_bar: ProgressBar
var _energy_fill: StyleBoxFlat
# Навыки в HUD: id -> {chip, cap, name, base, accent, ready, glow}. Компактные
# чипы (keycap + кулдаун) в нижней панели; видимостью управляем по разблокировке.
var _skills_ui: Dictionary = {}
var _skill_bar: Control       # нижняя панель-экшенбар с чипами навыков
var _lives_label: Label
var _shards_label: Label
var _keys_label: Label
var _lives_icon: HudIcon
var _shards_icon: HudIcon
var _keys_icon: HudIcon
var _shards_shown: int = -1   # последнее показанное число (для «пинка» иконки при изменении)
var _keys_shown: int = -1
var _boost_row: Control       # накопительная пассивка «Разгон» (иконка + значение)
var _adapt_row: Control       # накопительная пассивка «Адаптация»
var _boost_label: Label
var _adapt_label: Label
var _reveal_glow_on: bool = false   # крутится ли подсветка готового «Озарения»
var _toast_label: Label
var _minimap: TextureRect
var _joystick: Control
var _tint: ColorRect
var _tint_target: Color = Color(0, 0, 0, 0)
var _pause_overlay: Control
var _pause_info: Label
var _xp_bar: ProgressBar
var _sp_label: Label

# Активные навыки: клавиша (для keycap) + русское имя + акцентный неон.
const SKILL_DEFS := [
	{"id": "flash",  "key": "Q",     "name": "Вспышка",  "accent": Color(0.45, 0.85, 1.0)},
	{"id": "dash",   "key": "Shift", "name": "Рывок",    "accent": Color(0.45, 0.85, 1.0)},
	{"id": "sonar",  "key": "E",     "name": "Сонар",    "accent": Color(0.45, 0.85, 1.0)},
	{"id": "shield", "key": "C",     "name": "Щит",      "accent": Color(0.45, 0.85, 1.0)},
	{"id": "guide",  "key": "G",     "name": "Искра",    "accent": Color(0.45, 0.85, 1.0)},
	{"id": "reveal", "key": "F",     "name": "Озарение", "accent": Color(1.0, 0.82, 0.35)},
]

# HUD-текст обновляем не каждый кадр, а ~15 раз/с: покадровое форматирование
# десятка строк (таймер, кулдауны, XP) зря грузит CPU, особенно на мобилке.
var _hud_accum: float = 999.0
const HUD_INTERVAL := 1.0 / 15.0

var _dark: CanvasModulate
var _ambient: Color
var _reveal_time: float = 0.0

# Высота верхней HUD-панели (лог. px). Камера резервирует эту полосу сверху:
# граница лабиринта и игрок никогда не заходят под HUD (hud_top_inset).
const HUD_BAND := 116.0

var _dark_mat: ShaderMaterial   # виньетка «туман войны» вокруг игрока
var _dark_open: float = 0.0     # 0 = виньетка закрыта, 1 = открыта (Озарение)
const DARK_MAX := 0.93          # базовое затемнение по краям экрана
const DARK_INNER := 0.50        # базовый радиус полностью видимой зоны (доли полувысоты)
const DARK_OUTER := 0.76        # базовый радиус полного затемнения
var _vision: float = 1.0        # текущий масштаб радиуса видимости (плавный)
var _vision_target: float = 1.0 # цель: 1.0 — норма; <1 ужимает обзор (утечка/туман)

var _fx   # менеджер экранных эффектов (screenfx.gd)
var _music: AudioStreamPlayer

# Звуковые эффекты (загружаются один раз, проигрываются разовыми плеерами)
var _sfx_shard: AudioStream   # подбор осколка
var _sfx_key: AudioStream     # ключ потрачен, дверь открылась
var _sfx_win: AudioStream     # уровень пройден
var _sfx_beep: AudioStream    # глоток энергии с кристалла-станции
var _sfx_damage: AudioStream  # удар врага по свету
var _sfx_sonar: AudioStream   # навык «Сонар»
var _sfx_sparkle: AudioStream # навык «Искра» (Guide)

func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS   # чтобы ввод работал во время паузы
	get_tree().paused = false

	# В режиме «Накал» спуск бесконечный — снимаем потолок уровней.
	var _lvl_cap: int = 9999 if GameConfig.active_run >= 0 else MAX_LEVEL
	_level = clampi(GameConfig.level, 1, _lvl_cap)
	_floors = mini(_level, MAX_FLOORS)
	_cols = mini(GameConfig.cols + (_level - 1) * 6, MAX_DIM)
	_rows = mini(GameConfig.rows + (_level - 1) * 4, MAX_DIM - 12)
	_gw = _cols * 2 + 1
	_gh = _rows * 2 + 1
	_floor_gap = (_gh + 2) * TILE

	# Усложнение по уровням: быстрее разрядка и темнее фон
	_drain_mult = 1.0 + (_level - 1) * 0.07
	var dark_scale := maxf(0.55, 1.0 - (_level - 1) * 0.03)

	_events_enabled = GameConfig.events_enabled
	_event_cd = randf_range(10.0, 16.0)
	_lives = maxi(1, GameConfig.lives)
	# Накал: подтянуть несомый/забанканный/серию из слота забега
	if GameConfig.active_run >= 0:
		var r: Dictionary = GameConfig.runs[GameConfig.active_run]
		_ember        = float(r.get("ember_carried", 0))
		_ember_banked = int(r.get("ember_banked", 0))
		_ember_streak = int(r.get("ember_streak", 0))
		_level_clean  = true
	# Снимок применений активных навыков — для ранга «пройдено без способностей».
	_skill_uses_at_start = 0
	for sk in ["flash", "dash", "sonar", "shield", "guide", "reveal"]:
		_skill_uses_at_start += int(GameConfig.skill_uses.get(sk, 0))
	_apply_biome()
	_organic = false

	# Фон (CanvasModulate): тёмный, но НЕ чёрный — тонирован неоном темы, чтобы
	# грани стен читались по всему лабиринту и сплошная чернота не давила на глаза.
	# Луминанс ~0.10 на 1-м уровне, мягко темнеет вглубь (dark_scale).
	var neon := _wall_color
	_ambient = Color(
		(neon.r * 0.15 + 0.022) * dark_scale,
		(neon.g * 0.16 + 0.028) * dark_scale,
		(neon.b * 0.17 + 0.038) * dark_scale,
		1.0)

	_build_world()
	_build_hud()
	_build_screen_fx()
	_start_music()
	_load_sfx()
	if DisplayServer.is_touchscreen_available():
		_build_touch_controls()

	# При продолжении забега из меню — заметный баннер: на какой ты глубине и банк.
	# Снимает путаницу «этаж 1 = уровень 1» и подтверждает, что прогресс на месте.
	if GameConfig.active_run >= 0 and GameConfig.resumed:
		GameConfig.resumed = false
		_show_resume_banner()

func _process(delta: float) -> void:
	if _paused:
		return

	if _toast_time > 0.0:
		_toast_time -= delta
		if _toast_time <= 0.0 and _toast_label:
			_toast_label.visible = false

	# Время и события идут только после первого движения игрока
	var has_started: bool = _player and is_instance_valid(_player) and _player.started
	if not _won and not _dead and has_started:
		_elapsed += delta
		_update_events(delta)
		_mark_visited()
		_heat_sample_t += delta
		if _heat_sample_t >= 0.5:
			_heat_sample_t = 0.0
			_sample_heat()

	if _player and is_instance_valid(_player):
		# Надпись при заходе на новый этаж: сколько осколков на нём осталось
		if _player.current_floor != _last_floor:
			_last_floor = _player.current_floor
			var rem: int = int(_shards_remaining[_last_floor]) if _last_floor >= 0 and _last_floor < _shards_remaining.size() else 0
			flash_message("Этаж %d · осколков: %d" % [_last_floor + 1, rem])

		if _joystick:
			_player.touch_dir = _joystick.output

	# HUD-текст — на троттлинге (~15 Гц), а не каждый кадр (см. _update_hud)
	_hud_accum += delta
	if _hud_accum >= HUD_INTERVAL:
		_hud_accum = 0.0
		_update_hud()

	# Озарение
	if _dark:
		if _reveal_time > 0.0:
			_reveal_time -= delta
			_dark.color = _dark.color.lerp(Color(0.85, 0.85, 0.9), 0.12)
		else:
			_dark.color = _dark.color.lerp(_ambient, 0.06)

	# Виньетка-«туман войны»: приоткрывается во время Озарения, иначе закрыта.
	# Утечка света / густой туман, наоборот, ужимают радиус видимости (темнее, тяжелее).
	if _dark_mat:
		_vision = lerpf(_vision, _vision_target, 0.07)
		_dark_mat.set_shader_parameter("inner", DARK_INNER * _vision)
		_dark_mat.set_shader_parameter("outer", DARK_OUTER * _vision)
		_dark_open = lerpf(_dark_open, 1.0 if _reveal_time > 0.0 else 0.0, 0.12)
		_dark_mat.set_shader_parameter("max_dark", lerpf(DARK_MAX, 0.0, _dark_open))
		# Центр виньетки следует за экранной позицией игрока: у краёв лабиринта
		# камера упирается в границу, игрок съезжает от центра — и «шар видимости»
		# должен оставаться на игроке, иначе он пропадает в темноте.
		if _player and is_instance_valid(_player):
			var vp := get_viewport()
			var sp: Vector2 = vp.get_canvas_transform() * _player.global_position
			var vs: Vector2 = vp.get_visible_rect().size
			if vs.x > 0.0 and vs.y > 0.0:
				_dark_mat.set_shader_parameter("center", sp / vs)

	# Цветовой тинт событий
	if _tint:
		_tint.color = _tint.color.lerp(_tint_target, 0.1)

# Обновление HUD-текста. Вызывается из _process на троттлинге (~15 Гц): кулдауны
# показываются с точностью 0.1 с, поэтому форматировать десяток строк каждый кадр
# незачем — это лишние аллокации строк и переразметка лейблов (заметно на мобилке).
func _update_hud() -> void:
	if not _won and not _dead and _player and is_instance_valid(_player):
		_time_label.text = "%.1f с" % _elapsed
		var lvl_word := "Глубина" if GameConfig.active_run >= 0 else "Уровень"
		_level_label.text = "%s %d   ·   %s   ·   этаж %d / %d" % [lvl_word, _level, _biome_name, _player.current_floor + 1, _floors]

	# Индикатор Накала + «жар» (ярче горишь → агрессивнее враги)
	if _ember_label and is_instance_valid(_ember_label):
		var heat := enemy_heat()
		var hot := "   🔥" if heat > 0.5 else ""
		_ember_label.text = "НАКАЛ %d   ·   банк %d   ·   ×%.2f%s" % [int(_ember), _ember_banked, _ember_mult(), hot]
		_ember_label.add_theme_color_override("font_color", Color(1.0, 0.72, 0.3).lerp(Color(1.0, 0.4, 0.2), heat))
		if _player and is_instance_valid(_player):
			_player.ember_glow = heat

	if _player and is_instance_valid(_player):
		var r: float = clampf(_player.energy / _player.max_energy, 0.0, 1.0)
		_energy_bar.value = lerpf(_energy_bar.value, r, 0.4)   # плавная «стрелка» света
		_energy_fill.bg_color = Color(0.9, 0.2, 0.2).lerp(Color(1.0, 0.85, 0.3), r)

		# Экранный эффект: красная тревога ниже 40% света.
		if _fx:
			_fx.set_danger(clampf((0.4 - r) / 0.4, 0.0, 1.0))

		_update_skills_hud()

		if GameConfig.progressive_enabled:
			_boost_row.visible = true
			_adapt_row.visible = true
			_boost_label.text = "Разгон  +%d%%" % int(_player.momentum_bonus * 100.0)
			_adapt_label.text = "Адаптация  −%d%%" % int(_player.adapt_bonus * 100.0)
		else:
			_boost_row.visible = false
			_adapt_row.visible = false

	if _fps_label:
		_fps_label.text = "FPS: %d" % Engine.get_frames_per_second()

	# XP / SP в HUD
	if _sp_label:
		_sp_label.text = "SP: %d   XP: %d/%d" % [GameConfig.skill_points, GameConfig.xp, GameConfig.XP_PER_SP]
	if _xp_bar:
		_xp_bar.value = GameConfig.xp

# --- Случайные события ---

func _update_events(delta: float) -> void:
	if not _events_enabled or _level < 2:
		return

	if _event_active > 0.0:
		_event_active -= delta
		if _event_active <= 0.0:
			_end_event()
		return

	_event_cd -= delta
	if _event_cd <= 0.0:
		_trigger_event()

func _trigger_event() -> void:
	var roll := randf()
	var dur := randf_range(3.0, 5.0)
	var kind := ""
	if roll < 0.18:
		kind = "relief"
	elif roll < 0.40:
		kind = "fog"
	elif roll < 0.60:
		kind = "leak"
	elif roll < 0.80:
		kind = "flicker"
	else:
		kind = "shift"

	_event_active = dur

	match kind:
		"shift":
			_event_label.text = "▦ Лабиринт сдвигается"
			_event_label.add_theme_color_override("font_color", Color(0.8, 0.6, 1.0))
			_tint_target = Color(0.4, 0.25, 0.6, 0.14)
			_maze_shift()
		"relief":
			_event_label.text = "✦ Просвет"
			_event_label.add_theme_color_override("font_color", Color(0.5, 1.0, 0.6))
			_tint_target = Color(0.2, 0.6, 0.3, 0.10)
			_reveal_time = maxf(_reveal_time, 1.6)
			if _player:
				_player.energy = minf(_player.max_energy, _player.energy + 0.3)
		"fog":
			_event_label.text = "≈ Густой туман"
			_event_label.add_theme_color_override("font_color", Color(0.6, 0.8, 1.0))
			_tint_target = Color(0.25, 0.4, 0.7, 0.16)
			_vision_target = 0.6   # туман ужимает обзор до 60%
			if _player:
				_player.apply_event("fog", dur)
		"leak":
			_event_label.text = "⚠ Утечка света"
			_event_label.add_theme_color_override("font_color", Color(1.0, 0.5, 0.4))
			_tint_target = Color(0.7, 0.2, 0.2, 0.16)
			_vision_target = 0.5   # утечка режет радиус видимости вдвое — прям темно
			if _player:
				_player.apply_event("leak", dur)
		"flicker":
			_event_label.text = "⚡ Перебой света"
			_event_label.add_theme_color_override("font_color", Color(1.0, 0.9, 0.4))
			_tint_target = Color(0.1, 0.1, 0.1, 0.12)
			_vision_target = 0.6   # перебой света тоже ужимает обзор + свет пульсирует
			if _player:
				_player.apply_event("flicker", dur)

	_event_label.visible = true

func _end_event() -> void:
	_event_label.visible = false
	_tint_target = Color(0, 0, 0, 0)
	_vision_target = 1.0   # вернуть нормальный радиус видимости
	# Следующее событие — реже на низких уровнях, чаще на высоких
	var lo := maxf(6.0, 16.0 - _level)
	_event_cd = randf_range(lo, lo + 8.0)

# --- Пауза ---

func _toggle_pause() -> void:
	_paused = not _paused
	get_tree().paused = _paused
	_pause_overlay.visible = _paused
	if _fx:
		_fx.visible = not _paused   # не показывать виньетки поверх меню паузы
	if _paused:
		_refresh_pause()

func _refresh_pause() -> void:
	var t := "[ Активные навыки ]\n"
	t += "Q — Вспышка     Shift — Рывок\n"
	t += "E — Сонар       C — Щит\n"
	t += "G — Искра (путь к выходу)\n"
	if _player:
		t += "F — Озарение (%d%%)\n\n" % int(_player.reveal_charge * 100.0)
	else:
		t += "F — Озарение\n\n"

	t += "[ Пассивные навыки ]\n"
	var names := {
		"save": "Энергосбережение", "capacity": "Ёмкость",
		"charge": "Быстрая зарядка", "range": "Дальний свет",
		"legs": "Лёгкие ноги", "magic": "Эффективная магия",
	}
	var any := false
	for k in names:
		if GameConfig.passives.get(k, false):
			t += "• %s\n" % names[k]
			any = true
	if not any:
		t += "— не выбраны —\n"

	if GameConfig.progressive_enabled and _player:
		t += "\n[ Накопительные ]\n"
		t += "Разгон: +%d%% скорости\n" % int(_player.momentum_bonus * 100.0)
		t += "Адаптация: −%d%% разрядки\n" % int(_player.adapt_bonus * 100.0)

	_pause_info.text = t

	if _minimap:
		_minimap.texture = _build_minimap_texture()

func _restart() -> void:
	get_tree().paused = false
	get_tree().reload_current_scene()

func _goto_menu() -> void:
	if GameConfig.active_run >= 0:
		# Накал: гибель завершает забег, иначе — сохраняем и продолжим позже.
		if _game_over:
			GameConfig.end_run()
		else:
			GameConfig.leave_run()
	else:
		GameConfig.save_game()
	get_tree().paused = false
	get_tree().change_scene_to_file("res://menu.tscn")

func _open_skills_menu() -> void:
	_pause_overlay.visible = false
	var sm := CanvasLayer.new()
	sm.set_script(load("res://skills_menu.gd"))
	add_child(sm)
	sm.closed.connect(func():
		if is_instance_valid(_pause_overlay):
			_pause_overlay.visible = true)

func _unhandled_input(event: InputEvent) -> void:
	if not (event is InputEventKey and event.pressed and not event.echo):
		return
	var k: int = event.keycode

	if _won or _game_over:
		if k == KEY_ESCAPE:
			_goto_menu()
		elif (k == KEY_R or k == KEY_SPACE) and GameConfig.active_run < 0:
			# В режиме «Накал» рестарт уровня недоступен — забег окончен.
			_restart()
		return

	if k == KEY_ESCAPE or k == KEY_P:
		# Если открыт магазин-алтарь — Escape закрывает его и возвращает в паузу,
		# а не снимает паузу под открытым экраном (иначе игра шла бы «за» меню).
		if is_instance_valid(_altar_layer):
			if k == KEY_ESCAPE:
				_close_altar_shop()
			return
		_toggle_pause()
	elif k == KEY_R and not _paused and GameConfig.active_run < 0:
		# В «Накале» рестарт уровня запрещён — иначе бесплатный реролл лабиринта.
		_restart()

# --- Генерация лабиринта (recursive backtracker) ---

func _make_grid() -> Array:
	var grid: Array = []
	grid.resize(_gh)
	for y in _gh:
		var row := []
		row.resize(_gw)
		for x in _gw:
			row[x] = true
		grid[y] = row

	# Growing-tree: чаще берём самую свежую клетку (длинные коридоры),
	# иногда — случайную из активных (ветвление). Для органических уровней
	# больше ветвлений — структура напоминает корни/ветви дерева.
	var newest_prob := 1.0
	var visited := {}
	var active: Array[Vector2i] = []
	var start := Vector2i(0, 0)
	visited[start] = true
	grid[1][1] = false
	active.append(start)

	while not active.is_empty():
		var idx: int = active.size() - 1 if randf() < newest_prob else randi() % active.size()
		var c: Vector2i = active[idx]
		var neighbors := _unvisited_neighbors(c, visited)
		if neighbors.is_empty():
			active.remove_at(idx)
		else:
			var n: Vector2i = neighbors[randi() % neighbors.size()]
			visited[n] = true
			grid[n.y * 2 + 1][n.x * 2 + 1] = false
			grid[c.y + n.y + 1][c.x + n.x + 1] = false
			active.append(n)

	return grid

func _unvisited_neighbors(c: Vector2i, visited: Dictionary) -> Array[Vector2i]:
	var res: Array[Vector2i] = []
	for d in [Vector2i(1, 0), Vector2i(-1, 0), Vector2i(0, 1), Vector2i(0, -1)]:
		var n: Vector2i = c + d
		if n.x >= 0 and n.x < _cols and n.y >= 0 and n.y < _rows and not visited.has(n):
			res.append(n)
	return res

# --- Построение мира ---

func _build_world() -> void:
	_dark = CanvasModulate.new()
	_dark.color = _ambient
	add_child(_dark)

	# Bloom: мягкий неоновый ореол вокруг ярких граней, кристаллов и света игрока.
	var env := Environment.new()
	env.background_mode = Environment.BG_CANVAS
	env.glow_enabled = true
	env.glow_intensity = 1.15
	env.glow_strength = 1.2
	env.glow_bloom = 0.32
	env.glow_blend_mode = Environment.GLOW_BLEND_MODE_ADDITIVE
	env.glow_hdr_threshold = 0.62
	env.glow_hdr_scale = 2.2
	for i in 7:
		env.set_glow_level(i, 1.0 if i >= 1 and i <= 3 else 0.0)
	var we := WorldEnvironment.new()
	we.environment = env
	add_child(we)

	# Босс-этаж: каждые BOSS_EVERY_N уровней в режиме Накал, или принудительно при тест-флаге.
	_boss_level = (_level > 0 and _level % BOSS_EVERY_N == 0 and GameConfig.active_run >= 0) \
		or GameConfig.boss_test_enabled
	if _boss_level:
		_floors = 1
		_cols = BOSS_ARENA_COLS
		_rows = BOSS_ARENA_ROWS
		_gw = _cols * 2 + 1
		_gh = _rows * 2 + 1
		_floor_gap = (_gh + 2) * TILE

	_wall_tex_cache.clear()
	_grids.clear()
	for f in _floors:
		var grid := _make_arena_grid() if _boss_level else _make_grid()
		_grids.append(grid)
		_build_floor(f, grid)

	if _boss_level:
		_spawn_player()
		_spawn_boss()
	else:
		_place_doors()
		_place_exit()
		_spawn_player()
		_compute_optimal_path_len()
		if GameConfig.darkness_chaser and _level >= 4:
			_spawn_enemies()

func _spawn_enemies() -> void:
	# Количество врагов каждого типа в зависимости от уровня
	var n_slow   := 0
	var n_fast   := 0
	var n_cyclic := 0
	if _level >= 4:  n_slow   = 1
	if _level >= 6:  n_fast   = 1
	if _level >= 8:  n_cyclic = 1
	# С 11 уровня — каждый тип получает +1
	if _level >= 11:
		n_slow   += 1
		n_fast   += 1
		n_cyclic += 1
	# Дополнительная эскалация по отдельным типам
	if _level >= 12: n_slow   += 1
	if _level >= 15: n_fast   += 1
	if _level >= 18: n_cyclic += 1

	var types: Array = []
	for _i in n_slow:   types.append(0)
	for _i in n_fast:   types.append(1)
	for _i in n_cyclic: types.append(2)
	types.shuffle()

	# Распределяем врагов ПО ЭТАЖАМ (со случайного старта), чтобы единственный
	# враг не сидел всегда на стартовом этаже, который игрок быстро покидает —
	# тогда враги встречаются на всём пути вниз, а не только в начале.
	var base: int = (randi() % _floors) if _floors > 0 else 0
	for i in types.size():
		var f: int = (i + base) % maxi(1, _floors)
		var cells := _far_spawn_cells(_grids[f], 1)
		if cells.is_empty():
			continue
		_spawn_one_enemy(int(types[i]), cells[0], f)

func _make_arena_grid() -> Array:
	var grid: Array = []
	grid.resize(_gh)
	for gy in _gh:
		var row := []
		row.resize(_gw)
		for gx in _gw:
			row[gx] = (gx == 0 or gx == _gw - 1 or gy == 0 or gy == _gh - 1)
		grid[gy] = row
	# Несколько колонн-укрытий для тактики
	var pillars := [
		Vector2i(3, 2), Vector2i(3, _rows - 3),
		Vector2i(_cols - 4, 2), Vector2i(_cols - 4, _rows - 3),
		Vector2i(_cols / 2, _rows / 2 - 1), Vector2i(_cols / 2, _rows / 2 + 1),
	]
	for p: Vector2i in pillars:
		var gx: int = p.x * 2 + 1
		var gy: int = p.y * 2 + 1
		if gx > 0 and gx < _gw - 1 and gy > 0 and gy < _gh - 1:
			grid[gy][gx] = true
	return grid

func _spawn_boss() -> void:
	# В тест-режиме разблокируем вспышку и сонар, чтобы босс был проходим
	if GameConfig.boss_test_enabled:
		GameConfig.skills_unlocked["flash"] = true
		GameConfig.skills_unlocked["sonar"] = true

	var center_cell := Vector2i(_cols / 2, _rows / 2)
	var b := Node2D.new()
	b.set_script(load("res://boss.gd"))
	b.position = _cell_to_world(center_cell)
	b.set_meta("game", self)
	b.process_mode = Node.PROCESS_MODE_PAUSABLE
	add_child(b)
	_boss = b
	_boss_fragments = 0
	flash_message("⚠ Тёмное Ядро\nПодойди и нажми Q (Вспышка)\nE (Сонар) усилит удар ×2")

func on_boss_phase2(boss_pos: Vector2) -> void:
	_boss = null
	_boss_fragments = 3
	var offsets := [Vector2(-80, -60), Vector2(80, -60), Vector2(0, 80)]
	for i in 3:
		var frag := Node2D.new()
		frag.set_script(load("res://pursuer.gd"))
		frag.enemy_type = 1   # FAST
		frag.spawn_level = _level
		frag._enemy_floor = 0
		frag.position = boss_pos + offsets[i]
		frag.target = _player
		frag._game = self
		frag.set_meta("boss_fragment", true)
		frag.set_meta("frag_hp", 2)
		frag.process_mode = Node.PROCESS_MODE_PAUSABLE
		add_child(frag)
	flash_message("Тёмное Ядро расщепилось · Щит + Вспышка")

func on_boss_fragment_killed() -> void:
	_boss_fragments -= 1
	if _boss_fragments <= 0:
		on_player_win()

# Вызывается игроком при каждом применении Вспышки (Q). Наносит урон боссу/фрагментам.
func on_player_flash(player_pos: Vector2) -> void:
	if not _boss_level or _won or _dead:
		return
	if _boss and is_instance_valid(_boss):
		if _boss.has_method("try_flash_hit"):
			_boss.try_flash_hit(player_pos)
	elif _boss_fragments > 0:
		_boss_try_flash_fragment(player_pos)

func _boss_try_flash_hit(player_pos: Vector2) -> void:
	if _boss == null or not is_instance_valid(_boss):
		return
	if _boss.has_method("try_flash_hit"):
		_boss.try_flash_hit(player_pos)

func _boss_try_flash_fragment(player_pos: Vector2) -> void:
	var hit_any := false
	for frag in get_tree().get_nodes_in_group("enemy"):
		if not is_instance_valid(frag) or not frag.has_meta("boss_fragment"):
			continue
		if player_pos.distance_to(frag.global_position) > 240.0:
			continue
		hit_any = true
		# Заморожен щитом → двойной урон (так задумано: Щит + Вспышка)
		var dmg: int = 2 if frag.stun_time >= 0.5 else 1
		var hp: int = int(frag.get_meta("frag_hp", 2)) - dmg
		var bst := Node2D.new()
		bst.set_script(load("res://burst.gd"))
		bst.color = Color(1.0, 0.6, 0.1, 1.0)
		bst.max_scale = 5.0
		bst.dur = 0.4
		add_child(bst)
		bst.global_position = frag.global_position
		if hp <= 0:
			frag.queue_free()
			on_boss_fragment_killed()
		else:
			frag.set_meta("frag_hp", hp)
			flash_message("Фрагмент: ещё %d · заморозь Щитом (C) для добивания" % hp)
		break   # один удар — один фрагмент
	if not hit_any:
		flash_message("Подойди к фрагменту и жми Q")

func _spawn_one_enemy(type: int, cell: Vector2i, floor_idx: int) -> void:
	var pur := Node2D.new()
	pur.set_script(load("res://pursuer.gd"))
	pur.enemy_type = type
	pur.spawn_level = _level
	pur._enemy_floor = floor_idx
	pur.position = _cell_to_world(cell) + Vector2(0, floor_idx * _floor_gap)
	pur.target = _player
	pur._game = self
	# main — PROCESS_MODE_ALWAYS (ввод на паузе), поэтому враг по наследованию тоже
	# не вставал бы на паузе. Явно делаем его PAUSABLE, чтобы замирал при паузе.
	pur.process_mode = Node.PROCESS_MODE_PAUSABLE
	add_child(pur)

# BFS от (0,0) — возвращает до `count` ячеек из дальней половины лабиринта.
func _far_spawn_cells(grid: Array, count: int) -> Array[Vector2i]:
	var start := Vector2i(0, 0)
	var dist_map := {start: 0}
	var queue: Array[Vector2i] = [start]
	var max_d := 0
	while not queue.is_empty():
		var c: Vector2i = queue.pop_front()
		for d in [Vector2i(1,0), Vector2i(-1,0), Vector2i(0,1), Vector2i(0,-1)]:
			var n: Vector2i = c + d
			if n.x < 0 or n.x >= _cols or n.y < 0 or n.y >= _rows or dist_map.has(n):
				continue
			if not grid[c.y + n.y + 1][c.x + n.x + 1]:
				dist_map[n] = dist_map[c] + 1
				max_d = maxi(max_d, dist_map[n])
				queue.append(n)

	# Берём ячейки из дальней половины (BFS-расстояние > max/2)
	var threshold := max_d / 2
	var far: Array[Vector2i] = []
	for k: Vector2i in dist_map.keys():
		if dist_map[k] > threshold:
			far.append(k)
	far.shuffle()
	return far.slice(0, count)

func _build_floor(f: int, grid: Array) -> void:
	var container := Node2D.new()
	container.position = Vector2(0, f * _floor_gap)
	add_child(container)
	_floor_containers.resize(maxi(_floor_containers.size(), f + 1))
	_floor_containers[f] = container

	if _organic:
		# Органический пол: плавные скруглённые тоннели по форме лабиринта.
		var of := Node2D.new()
		of.set_script(load("res://organic_floor.gd"))
		of.tile = TILE
		of.cols = _cols
		of.rows = _rows
		of.gw = _gw
		of.gh = _gh
		of.col = _organic_color
		of.grid = grid
		container.add_child(of)
		_organic_floors.resize(maxi(_organic_floors.size(), f + 1))
		_organic_floors[f] = of
	else:
		var floor_node := Polygon2D.new()
		floor_node.color = FLOOR_COLOR
		floor_node.polygon = PackedVector2Array([
			Vector2(0, 0),
			Vector2(_gw * TILE, 0),
			Vector2(_gw * TILE, _gh * TILE),
			Vector2(0, _gh * TILE),
		])
		container.add_child(floor_node)

	for gy in _gh:
		for gx in _gw:
			if grid[gy][gx]:
				_add_wall(container, f, gx, gy)

	# Станции (они же чекпоинты)
	var cells := _passage_cells(f == 0, grid)
	cells.shuffle()
	var area: int = _cols * _rows
	var density: float = float(GameConfig.station_count) / (16 * 10)
	var lvl_factor: float = 1.0 + (mini(_level, 6) - 1) * 0.25
	var scaled: int = max(GameConfig.station_count, int(area * density * lvl_factor))
	var count: int = mini(mini(scaled, MAX_STATIONS), cells.size())
	for i in count:
		var st := Area2D.new()
		st.set_script(load("res://station.gd"))
		st.game = self
		st.floor_index = f
		st.position = _cell_to_world(cells[i])
		container.add_child(st)

	# Осколки света (собираемые бонусы)
	var shard_cells := _passage_cells(f == 0, grid)
	shard_cells.shuffle()
	var sc: int = mini(SHARDS_PER_FLOOR, shard_cells.size())
	for i in sc:
		var sh := Area2D.new()
		sh.set_script(load("res://shard.gd"))
		sh.game = self
		sh.position = _cell_to_world(shard_cells[i])
		container.add_child(sh)
		_shards_total += 1
	_shards_remaining.resize(maxi(_shards_remaining.size(), f + 1))
	_shards_remaining[f] = sc   # осколков на этом этаже (для счётчика «осталось»)

# Битовая маска открытых сторон стены-клетки (gx,gy) на этаже f.
# Сторона «открыта», если соседняя клетка сетки — проход (grid==false).
# Выход за границы трактуем как стену (закрыто).
# Кардиналы: N=1, E=2, S=4, W=8. Диагонали (для заполнения выпуклых углов):
# NE=16, SE=32, SW=64, NW=128.
func _wall_open_mask(f: int, gx: int, gy: int) -> int:
	var grid: Array = _grids[f]
	var m := 0
	if gy - 1 >= 0 and not grid[gy - 1][gx]:
		m |= 1
	if gx + 1 < _gw and not grid[gy][gx + 1]:
		m |= 2
	if gy + 1 < _gh and not grid[gy + 1][gx]:
		m |= 4
	if gx - 1 >= 0 and not grid[gy][gx - 1]:
		m |= 8
	if gy - 1 >= 0 and gx + 1 < _gw and not grid[gy - 1][gx + 1]:
		m |= 16
	if gy + 1 < _gh and gx + 1 < _gw and not grid[gy + 1][gx + 1]:
		m |= 32
	if gy + 1 < _gh and gx - 1 >= 0 and not grid[gy + 1][gx - 1]:
		m |= 64
	if gy - 1 >= 0 and gx - 1 >= 0 and not grid[gy - 1][gx - 1]:
		m |= 128
	return m

# Текстура стены для маски (кэш на время постройки уровня; ~16 на этаж).
func _wall_texture(mask: int) -> Texture2D:
	if not _wall_tex_cache.has(mask):
		_wall_tex_cache[mask] = MazeTextures.make_wall_tile(int(TILE), mask, _wall_color)
	return _wall_tex_cache[mask]

func _add_wall(container: Node2D, f: int, gx: int, gy: int) -> void:
	var body := StaticBody2D.new()
	body.position = Vector2(gx * TILE + TILE * 0.5, gy * TILE + TILE * 0.5)

	var col := CollisionShape2D.new()
	var rect := RectangleShape2D.new()
	rect.size = Vector2(TILE, TILE)
	col.shape = rect
	body.add_child(col)

	var h := TILE * 0.5
	var square := PackedVector2Array([
		Vector2(-h, -h), Vector2(h, -h), Vector2(h, h), Vector2(-h, h),
	])

	# На органических уровнях стены не рисуем квадратами — форму тоннеля задаёт
	# скруглённый пол. Коллизия и окклюдер (тень) остаются.
	if not _organic:
		# Визуал: спрайт с beveled-текстурой (albedo+normal) по маске открытых сторон.
		# Ссылку храним в meta для быстрого обновления при изменениях лабиринта.
		var vis := Sprite2D.new()
		vis.texture = _wall_texture(_wall_open_mask(f, gx, gy))
		vis.light_mask = 3   # бит1: общий свет; бит2: отдельный «настенный» свет игрока
		body.add_child(vis)
		body.set_meta("vis", vis)

	var occ := LightOccluder2D.new()
	var occ_poly := OccluderPolygon2D.new()
	occ_poly.polygon = square
	occ_poly.closed = true
	occ.occluder = occ_poly
	body.add_child(occ)

	container.add_child(body)
	_wall_nodes[Vector3i(f, gx, gy)] = body

func _place_doors() -> void:
	var pairs: int = clampi(GameConfig.door_pairs, 1, 4)
	for f in range(_floors - 1):
		# Порталы ставим в «выемки» — клетки-тупики этого этажа. Если тупиков мало,
		# добиваем обычными проходами, чтобы число порталов не уменьшилось.
		var cells := _dead_end_cells(_grids[f])
		cells.shuffle()
		if cells.size() < pairs:
			var extra := _passage_cells(true)
			extra.shuffle()
			for e in extra:
				if not cells.has(e):
					cells.append(e)
		for p in mini(pairs, cells.size()):
			var c: Vector2i = cells[p]
			var local := _cell_to_world(c)
			# Первая пара (p == 0) всегда открыта — гарантированный путь.
			# Остальные заперты и требуют осколок-ключ.
			var lock := p > 0
			var d_a := _make_door(local + Vector2(0, f * _floor_gap), _floor_gap, f + 1, lock)
			var d_b := _make_door(local + Vector2(0, (f + 1) * _floor_gap), -_floor_gap, f, lock)
			d_a.partner = d_b
			d_b.partner = d_a
			# Запоминаем переход между этажами для поиска пути «Искрой»
			var na := Vector3i(f, c.x, c.y)
			var nb := Vector3i(f + 1, c.x, c.y)
			if not _door_links.has(na):
				_door_links[na] = []
			_door_links[na].append(nb)
			if not _door_links.has(nb):
				_door_links[nb] = []
			_door_links[nb].append(na)

func _make_door(pos: Vector2, dy: float, target_floor: int, locked: bool) -> Area2D:
	var d := Area2D.new()
	d.set_script(load("res://door.gd"))
	d.delta_y = dy
	d.target_floor = target_floor
	d.game = self
	d.locked = locked
	# Перегенерация — только если дверей не меньше 4 (иначе искать проход слишком тяжело)
	var regen_ok: bool = GameConfig.door_regen_enabled and GameConfig.door_pairs >= 4
	d.regen_chance = GameConfig.door_regen_chance if regen_ok else 0.0
	d.position = pos
	add_child(d)
	d.add_to_group("door")
	return d

# Переходы между этажами — односторонние (вниз). После спуска убираем все порталы,
# ведущие на пройденные верхние этажи (target_floor < текущего): назад дороги нет.
func seal_below(floor_idx: int) -> void:
	for dr in get_tree().get_nodes_in_group("door"):
		if is_instance_valid(dr) and dr.target_floor < floor_idx:
			if dr.has_method("vanish"):
				dr.vanish()
			else:
				dr.queue_free()

func _place_exit() -> void:
	var lf := _floors - 1
	var c := _farthest_cell(_grids[lf])
	_exit_cell = c
	_exit_floor = lf
	var exit := Area2D.new()
	exit.set_script(load("res://exit.gd"))
	exit.game = self
	exit.position = _cell_to_world(c) + Vector2(0, lf * _floor_gap)
	add_child(exit)

func _spawn_player() -> void:
	_player = preload("res://player.tscn").instantiate()
	_player.speed = GameConfig.player_speed
	_player.drain_per_sec = GameConfig.drain_per_sec * _drain_mult
	_player.max_energy = GameConfig.max_energy
	_player.position = _cell_to_world(Vector2i(0, 0))
	# main — PROCESS_MODE_ALWAYS, поэтому игрок по наследованию двигался бы и на
	# паузе. Явно PAUSABLE — замирает вместе с миром при паузе.
	_player.process_mode = Node.PROCESS_MODE_PAUSABLE
	add_child(_player)

	_cp_floor = 0
	_cp_pos = _player.position

func _farthest_cell(grid: Array) -> Vector2i:
	var start := Vector2i(0, 0)
	var dist := {start: 0}
	var queue: Array[Vector2i] = [start]
	var best := start
	var best_d := 0
	while not queue.is_empty():
		var c: Vector2i = queue.pop_front()
		if dist[c] > best_d:
			best_d = dist[c]
			best = c
		for d in [Vector2i(1, 0), Vector2i(-1, 0), Vector2i(0, 1), Vector2i(0, -1)]:
			var n: Vector2i = c + d
			if n.x < 0 or n.x >= _cols or n.y < 0 or n.y >= _rows or dist.has(n):
				continue
			var mx := c.x + n.x + 1
			var my := c.y + n.y + 1
			if not grid[my][mx]:
				dist[n] = dist[c] + 1
				queue.append(n)
	return best

func _passage_cells(exclude_start: bool, grid: Array = []) -> Array[Vector2i]:
	var arr: Array[Vector2i] = []
	for cy in _rows:
		for cx in _cols:
			if exclude_start and cx == 0 and cy == 0:
				continue
			# Если передана сетка — пропускаем клетки-стены (колонны арены босса),
			# иначе объекты спавнятся внутри стены и их не собрать.
			if not grid.is_empty() and grid[cy * 2 + 1][cx * 2 + 1]:
				continue
			arr.append(Vector2i(cx, cy))
	return arr

# Клетки-«выемки» (тупики): проход ровно с ОДНОЙ открытой стороной — естественный
# карман со стенами с трёх сторон. Старт (0,0) исключаем. Используется для порталов.
func _dead_end_cells(grid: Array) -> Array[Vector2i]:
	var res: Array[Vector2i] = []
	for cy in _rows:
		for cx in _cols:
			if cx == 0 and cy == 0:
				continue
			var gx := cx * 2 + 1
			var gy := cy * 2 + 1
			var open := 0
			if gy - 1 >= 0 and not grid[gy - 1][gx]: open += 1
			if gy + 1 < _gh and not grid[gy + 1][gx]: open += 1
			if gx - 1 >= 0 and not grid[gy][gx - 1]: open += 1
			if gx + 1 < _gw and not grid[gy][gx + 1]: open += 1
			if open == 1:
				res.append(Vector2i(cx, cy))
	return res

func _cell_to_world(cell: Vector2i) -> Vector2:
	var gx := cell.x * 2 + 1
	var gy := cell.y * 2 + 1
	return Vector2(gx * TILE + TILE * 0.5, gy * TILE + TILE * 0.5)

func _grid_to_world(gx: int, gy: int, f: int) -> Vector2:
	return Vector2(gx * TILE + TILE * 0.5, gy * TILE + TILE * 0.5) + Vector2(0, f * _floor_gap)

# Мировые границы (Rect2) лабиринта на этаже f — для ограничения камеры по краям.
# Этаж f смещён по Y на f*_floor_gap; сетка занимает _gw×_gh клеток по TILE.
func floor_world_bounds(f: int) -> Rect2:
	var top: float = f * _floor_gap
	return Rect2(Vector2(0.0, top), Vector2(_gw * TILE, _gh * TILE))

# Высота верхней HUD-полосы (лог. px = мировые единицы при zoom 1). Камера резервирует
# её сверху, чтобы граница лабиринта и игрок не заходили под HUD.
func hud_top_inset() -> float:
	return HUD_BAND

# Соседние клетки-проходы для поиска пути «Искрой»: открытые проходы текущего
# этажа + переходы через двери на соседние этажи. node = Vector3i(этаж, cx, cy).
func _cell_neighbors(node: Vector3i) -> Array:
	var res: Array = []
	var f: int = node.x
	var cx: int = node.y
	var cy: int = node.z
	var grid: Array = _grids[f]
	for d in [Vector2i(1, 0), Vector2i(-1, 0), Vector2i(0, 1), Vector2i(0, -1)]:
		var nx: int = cx + d.x
		var ny: int = cy + d.y
		if nx < 0 or nx >= _cols or ny < 0 or ny >= _rows:
			continue
		# стена между клетками — на серединной координате сетки; false = проход
		if not grid[cy + ny + 1][cx + nx + 1]:
			res.append(Vector3i(f, nx, ny))
	if _door_links.has(node):
		for nb in _door_links[node]:
			res.append(nb)
	return res

# Кратчайший путь (мировые точки) от позиции игрока к выходу — для «Искры».
# BFS по клеткам всех этажей; путь обрезается по первому переходу на другой
# этаж, чтобы огонёк вёл по текущему этажу к нужной двери (или к выходу).
func guide_path_to_exit(from_pos: Vector2, from_floor: int) -> PackedVector2Array:
	if from_floor < 0 or from_floor >= _grids.size():
		return PackedVector2Array()
	var sx: int = clampi(int(round((from_pos.x / TILE - 1.5) / 2.0)), 0, _cols - 1)
	var sy: int = clampi(int(round(((from_pos.y - from_floor * _floor_gap) / TILE - 1.5) / 2.0)), 0, _rows - 1)
	var start := Vector3i(from_floor, sx, sy)
	var goal := Vector3i(_exit_floor, _exit_cell.x, _exit_cell.y)

	var prev := {}
	var visited := {start: true}
	var queue: Array[Vector3i] = [start]
	var found := false
	while not queue.is_empty():
		var cur: Vector3i = queue.pop_front()
		if cur == goal:
			found = true
			break
		for nb in _cell_neighbors(cur):
			if not visited.has(nb):
				visited[nb] = true
				prev[nb] = cur
				queue.append(nb)
	if not found:
		return PackedVector2Array()

	# Восстановить последовательность клеток start -> goal
	var cells: Array[Vector3i] = []
	var c: Vector3i = goal
	while c != start:
		cells.append(c)
		c = prev[c]
	cells.append(start)
	cells.reverse()

	# Мировые точки, обрезая по первому переходу на другой этаж
	var out := PackedVector2Array()
	out.append(from_pos)
	for cell in cells:
		if cell.x != from_floor:
			break
		out.append(_grid_to_world(cell.y * 2 + 1, cell.z * 2 + 1, from_floor))
	return out

func _mark_visited() -> void:
	if _player == null or not is_instance_valid(_player):
		return
	var f: int = _player.current_floor
	var px: float = _player.global_position.x
	var py: float = _player.global_position.y - f * _floor_gap
	var cx: int = int(round((px / TILE - 1.5) / 2.0))
	var cy: int = int(round((py / TILE - 1.5) / 2.0))
	if cx >= 0 and cx < _cols and cy >= 0 and cy < _rows:
		_visited[Vector3i(f, cx, cy)] = true

func _sample_heat() -> void:
	if _player == null or not is_instance_valid(_player):
		return
	var f: int = _player.current_floor
	var px: float = _player.global_position.x
	var py: float = _player.global_position.y - f * _floor_gap
	var cx: int = int(round((px / TILE - 1.5) / 2.0))
	var cy: int = int(round((py / TILE - 1.5) / 2.0))
	if cx >= 0 and cx < _cols and cy >= 0 and cy < _rows:
		var k := Vector3i(f, cx, cy)
		_heat_map[k] = _heat_map.get(k, 0.0) + 0.5

func _compute_optimal_path_len() -> void:
	var start := Vector3i(0, 0, 0)
	var goal  := Vector3i(_exit_floor, _exit_cell.x, _exit_cell.y)
	var dist  := {start: 0}
	var queue: Array[Vector3i] = [start]
	while not queue.is_empty():
		var cur: Vector3i = queue.pop_front()
		if cur == goal:
			_optimal_path_len = dist[cur]
			return
		for nb in _cell_neighbors(cur):
			if not dist.has(nb):
				dist[nb] = dist[cur] + 1
				queue.append(nb)
	_optimal_path_len = 0

func _show_stats_screen() -> void:
	var vp_size: Vector2 = get_viewport().get_visible_rect().size

	var overlay := CanvasLayer.new()
	overlay.layer = 4
	add_child(overlay)

	# Прячем HUD (вместе с большим баннером победы) — на экране результатов он лишь
	# засоряет картинку и мешает фону читаться затемнённым. Сцена перезагрузится в
	# _restart(), так что восстанавливать видимость не нужно.
	if _hud_layer:
		_hud_layer.visible = false

	# Затемняющая вуаль: проявляется плавно и НЕ до конца — лабиринт виден сквозь неё.
	var bg := ColorRect.new()
	bg.color = Color(0.01, 0.01, 0.04, 0.0)
	bg.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	overlay.add_child(bg)
	var bg_alpha := 0.70   # целевая непрозрачность вуали

	# Тепловая карта (этаж 0)
	var cell_px: int = clamp(int((vp_size.x * 0.45) / float(maxi(_cols, 1))), 4, 20)
	var map_w: int = _cols * cell_px
	var map_h: int = _rows * cell_px
	var img := Image.create_empty(map_w, map_h, false, Image.FORMAT_RGBA8)
	img.fill(Color(0.04, 0.04, 0.08, 1.0))

	var max_heat: float = 0.1
	for v in _heat_map.values():
		max_heat = maxf(max_heat, float(v))

	# Оптимальный путь (подсвечиваем зелёным)
	var opt_cells: Dictionary = {}
	var s0 := Vector3i(0, 0, 0)
	var g0 := Vector3i(_exit_floor, _exit_cell.x, _exit_cell.y)
	var prev_opt: Dictionary = {}
	var vis_opt: Dictionary = {s0: true}
	var q_opt: Array[Vector3i] = [s0]
	var found_opt := false
	while not q_opt.is_empty() and not found_opt:
		var cur: Vector3i = q_opt.pop_front()
		if cur == g0:
			found_opt = true
			var c2 := cur
			while c2 != s0:
				if c2.x == 0:
					opt_cells[Vector2i(c2.y, c2.z)] = true
				c2 = prev_opt.get(c2, s0)
			break
		for nb in _cell_neighbors(cur):
			if not vis_opt.has(nb):
				vis_opt[nb] = true
				prev_opt[nb] = cur
				q_opt.append(nb)

	for cy in _rows:
		for cx in _cols:
			var k := Vector3i(0, cx, cy)
			var heat: float = float(_heat_map.get(k, 0.0)) / max_heat
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

	# Старт и выход
	for dy in cell_px:
		for dx in cell_px:
			img.set_pixel(dx, dy, Color(0.3, 1.0, 0.6, 1.0))
			if _exit_cell.x < _cols and _exit_cell.y < _rows:
				img.set_pixel(_exit_cell.x * cell_px + dx, _exit_cell.y * cell_px + dy, Color(1.0, 0.5, 0.1, 1.0))

	# --- Композиция по центру: заголовок · карта · легенда · статистика · подсказка ---
	var center := CenterContainer.new()
	center.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	overlay.add_child(center)

	var col := VBoxContainer.new()
	col.alignment = BoxContainer.ALIGNMENT_CENTER
	col.add_theme_constant_override("separation", 16)
	center.add_child(col)

	# Заголовок
	var title := Label.new()
	title.add_theme_font_size_override("font_size", 30)
	title.add_theme_color_override("font_color", Color(1.0, 0.85, 0.3))
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	title.text = ("Глубина %d пройдена" % _level) if GameConfig.active_run >= 0 else ("Уровень %d пройден" % _level)
	_label_outline(title, 5)
	col.add_child(title)

	# Карта (по центру, без растяжения — чтобы не искажать пиксели)
	var map_tex := TextureRect.new()
	map_tex.texture = ImageTexture.create_from_image(img)
	map_tex.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	map_tex.custom_minimum_size = Vector2(map_w, map_h)
	map_tex.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	col.add_child(map_tex)

	# Легенда (подпись под картой)
	var legend := Label.new()
	legend.add_theme_font_size_override("font_size", 13)
	legend.add_theme_color_override("font_color", Color(0.6, 0.6, 0.72))
	legend.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	legend.text = "■ Старт   ■ Выход   ■ Оптимальный путь   тепло: синий → жёлтый → белый"
	_label_outline(legend, 3)
	col.add_child(legend)

	# Сравнение с симулированными игроками
	var optimal_t: float = float(_optimal_path_len) * TILE / maxf(GameConfig.player_speed, 1.0) if _optimal_path_len > 0 else _elapsed
	var median_t:  float = optimal_t * 1.7 + float(_level) * 2.0
	var ratio: float = median_t / maxf(_elapsed, 0.01)
	var pct: int = clamp(int(50.0 + 40.0 * (ratio - 1.0) / (ratio + 0.5)), 1, 99)

	var stats_lbl := Label.new()
	stats_lbl.add_theme_font_size_override("font_size", 19)
	stats_lbl.add_theme_color_override("font_color", Color(0.9, 0.9, 1.0))
	stats_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	stats_lbl.text = (
		"Время: %.1f с   ·   оптимум: %.1f с\nТы быстрее %d%% игроков" %
		[_elapsed, optimal_t, pct]
	)
	_label_outline(stats_lbl, 4)
	col.add_child(stats_lbl)

	# Отступ перед подсказкой
	var spacer := Control.new()
	spacer.custom_minimum_size = Vector2(0, 10)
	col.add_child(spacer)

	# Подсказка — пульсирует (см. цикл ожидания ниже)
	var hint_lbl := Label.new()
	hint_lbl.add_theme_font_size_override("font_size", 16)
	hint_lbl.add_theme_color_override("font_color", Color(0.85, 0.9, 1.0))
	hint_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	hint_lbl.text = "Нажми любую клавишу, чтобы продолжить"
	_label_outline(hint_lbl, 3)
	col.add_child(hint_lbl)

	# Ждём ввода или таймаут; параллельно проявляем вуаль и пульсируем подсказкой.
	var t: float = 0.0
	while is_instance_valid(overlay):
		var dt := get_process_delta_time()
		t += dt
		# плавное затемнение фона (за ~0.35 с до целевой непрозрачности)
		bg.color.a = minf(bg_alpha, bg.color.a + dt * (bg_alpha / 0.35))
		# мягкая пульсация подсказки, чтобы было понятно «жми кнопку»
		hint_lbl.modulate.a = 0.45 + 0.55 * (0.5 + 0.5 * sin(t * TAU * 0.9))
		# небольшая защита от мгновенного «проскока» по зажатой клавише
		if t > 0.2 and Input.is_anything_pressed():
			break
		if t > 8.0:
			break
		await get_tree().process_frame
	if is_instance_valid(overlay):
		overlay.queue_free()

func _build_minimap_texture() -> ImageTexture:
	var img := Image.create_empty(_cols, _rows, false, Image.FORMAT_RGBA8)
	img.fill(Color(0.08, 0.08, 0.11, 1.0))
	var f: int = _player.current_floor if (_player and is_instance_valid(_player)) else 0
	var cur := Vector2i(-1, -1)
	if _player and is_instance_valid(_player):
		var px: float = _player.global_position.x
		var py: float = _player.global_position.y - f * _floor_gap
		cur = Vector2i(int(round((px / TILE - 1.5) / 2.0)), int(round((py / TILE - 1.5) / 2.0)))
	for key in _visited:
		if key.x == f and key.y >= 0 and key.y < _cols and key.z >= 0 and key.z < _rows:
			img.set_pixel(key.y, key.z, Color(0.5, 0.85, 0.7))
	if cur.x >= 0 and cur.x < _cols and cur.y >= 0 and cur.y < _rows:
		img.set_pixel(cur.x, cur.y, Color(1.0, 0.9, 0.4))
	return ImageTexture.create_from_image(img)

# --- Изменение структуры лабиринта ---

# Пересчитать маску и обновить текстуру стены-клетки (если она ещё стена).
func _refresh_wall_tile(f: int, gx: int, gy: int) -> void:
	if gx < 0 or gx >= _gw or gy < 0 or gy >= _gh:
		return
	var key := Vector3i(f, gx, gy)
	if not _wall_nodes.has(key):
		return   # проход — обновлять нечего
	var body: StaticBody2D = _wall_nodes[key]
	var vis = body.get_meta("vis", null)
	if vis:
		vis.texture = _wall_texture(_wall_open_mask(f, gx, gy))

func _set_wall(f: int, gx: int, gy: int, is_wall: bool) -> void:
	(_grids[f] as Array)[gy][gx] = is_wall
	var key := Vector3i(f, gx, gy)
	if is_wall:
		if not _wall_nodes.has(key):
			_add_wall(_floor_containers[f], f, gx, gy)
	else:
		if _wall_nodes.has(key):
			_wall_nodes[key].queue_free()
			_wall_nodes.erase(key)
	# Сторона у соседей изменилась — обновить их бевели (и свою, если осталась стеной).
	_refresh_wall_tile(f, gx, gy)
	_refresh_wall_tile(f, gx, gy - 1)
	_refresh_wall_tile(f, gx + 1, gy)
	_refresh_wall_tile(f, gx, gy + 1)
	_refresh_wall_tile(f, gx - 1, gy)
	# На органических уровнях перерисовать тоннели этого этажа.
	if _organic and f < _organic_floors.size() and is_instance_valid(_organic_floors[f]):
		_organic_floors[f].queue_redraw()

# Путь между двумя клетками-проходами по текущему дереву (в координатах сетки),
# возвращает список рёбер-стен на пути. Ребро exclude игнорируется.
func _path_edges(grid: Array, a: Vector2i, b: Vector2i, exclude: Vector2i) -> Array:
	var prev := {}
	var visited := {a: true}
	var queue: Array[Vector2i] = [a]
	while not queue.is_empty():
		var c: Vector2i = queue.pop_front()
		if c == b:
			break
		for d in [Vector2i(2, 0), Vector2i(-2, 0), Vector2i(0, 2), Vector2i(0, -2)]:
			var n: Vector2i = c + d
			if n.x < 1 or n.x >= _gw - 1 or n.y < 1 or n.y >= _gh - 1:
				continue
			var edge := Vector2i((c.x + n.x) / 2, (c.y + n.y) / 2)
			if edge == exclude or grid[edge.y][edge.x] or visited.has(n):
				continue
			visited[n] = true
			prev[n] = [c, edge]
			queue.append(n)
	if not visited.has(b):
		return []
	var edges: Array = []
	var cur: Vector2i = b
	while cur != a:
		var pe = prev[cur]
		edges.append(pe[1])
		cur = pe[0]
	return edges

# Случайное событие: открыть одно ребро и закрыть другое на образовавшемся
# цикле — лабиринт меняется, но остаётся проходимым (остаётся деревом).
func _maze_shift() -> void:
	if _player == null:
		return
	var f: int = _player.current_floor
	if f < 0 or f >= _grids.size():
		return
	var grid: Array = _grids[f]

	var closed: Array = []
	for gy in range(1, _gh - 1):
		for gx in range(1, _gw - 1):
			if not grid[gy][gx]:
				continue
			# ребро между двумя проходами: ровно одна координата чётная
			if (gx % 2 == 0) == (gy % 2 == 0):
				continue
			closed.append(Vector2i(gx, gy))
	if closed.is_empty():
		return
	closed.shuffle()
	var opened: Vector2i = closed[0]

	var a: Vector2i
	var b: Vector2i
	if opened.x % 2 == 0:
		a = Vector2i(opened.x - 1, opened.y)
		b = Vector2i(opened.x + 1, opened.y)
	else:
		a = Vector2i(opened.x, opened.y - 1)
		b = Vector2i(opened.x, opened.y + 1)

	var path := _path_edges(grid, a, b, opened)
	if path.is_empty():
		return

	_set_wall(f, opened.x, opened.y, false)  # открыли проход

	# закрыть ребро на пути, не вплотную к игроку
	path.shuffle()
	var to_close: Vector2i = path[0]
	for e in path:
		if _grid_to_world(e.x, e.y, f).distance_to(_player.global_position) > TILE * 2.0:
			to_close = e
			break
	_set_wall(f, to_close.x, to_close.y, true)

# Полная перегенерация этажа (для события у дверей).
# Постройка разбита на кадры, чтобы не было фриза на больших лабиринтах.
func regenerate_floor(f: int) -> void:
	if f < 0 or f >= _grids.size() or f >= _floor_containers.size():
		return
	for key in _wall_nodes.keys():
		if key.x == f:
			_wall_nodes[key].queue_free()
			_wall_nodes.erase(key)
	var grid := _make_grid()
	_grids[f] = grid
	# Сбрасываем пройденный путь этого этажа — карта обнуляется
	for vk in _visited.keys():
		if vk.x == f:
			_visited.erase(vk)
	# На органических уровнях обновить тоннели под новую сетку
	if _organic and f < _organic_floors.size() and is_instance_valid(_organic_floors[f]):
		_organic_floors[f].grid = grid
		_organic_floors[f].queue_redraw()
	var container: Node2D = _floor_containers[f]
	var built := 0
	for gy in _gh:
		for gx in _gw:
			if grid[gy][gx]:
				_add_wall(container, f, gx, gy)
				built += 1
				if built % 100 == 0:
					await get_tree().process_frame
					if not is_instance_valid(container):
						return

# --- Игровые события ---

func set_checkpoint(floor_idx: int, pos: Vector2) -> void:
	_cp_floor = floor_idx
	_cp_pos = pos

func reveal(duration: float) -> void:
	_reveal_time = duration

# ── Накал: набор, банк, «жар», алтарь ────────────────────────────────────────

func _apply_biome() -> void:
	_biome = int((_level - 1) / BIOME_SPAN) % BIOMES.size()
	var b: Dictionary = BIOMES[_biome]
	_biome_name = b["name"]
	var cols: Array = b["colors"]
	_wall_color = cols[(_level - 1) % cols.size()]

func _ember_mult() -> float:
	return 1.0 + mini(_ember_streak, EMBER_STREAK_MAX) * EMBER_STREAK_STEP

# Оценка прохождения уровня (в стиле MGS): осколки + без урона + без способностей +
# скорость → ранг S/A/B/C/D. Работает в обоих режимах.
func _compute_rank() -> Dictionary:
	var ratio: float = 1.0 if _shards_total <= 0 else float(_shards_collected) / float(_shards_total)
	var used_now: int = 0
	for sk in ["flash", "dash", "sonar", "shield", "guide", "reveal"]:
		used_now += int(GameConfig.skill_uses.get(sk, 0))
	var no_skills: bool = used_now <= _skill_uses_at_start
	var clean: bool = _level_clean
	var par: float = 20.0 + _level * 12.0
	var fast: bool = _elapsed <= par
	var score: float = ratio * 50.0
	if clean: score += 25.0
	if no_skills: score += 15.0
	if fast: score += 10.0
	var rank := "D"
	if score >= 95.0: rank = "S"
	elif score >= 80.0: rank = "A"
	elif score >= 60.0: rank = "B"
	elif score >= 40.0: rank = "C"
	return {"rank": rank, "score": int(round(score)), "ratio": ratio,
		"clean": clean, "no_skills": no_skills, "fast": fast}

# 0..1: чем больше несомого Накала — тем агрессивнее враги (читают это значение).
func enemy_heat() -> float:
	if GameConfig.active_run < 0:
		return 0.0
	return clampf(_ember / EMBER_HEAT_FULL, 0.0, 1.0)

func _persist_ember() -> void:
	if GameConfig.active_run < 0:
		return
	var r: Dictionary = GameConfig.runs[GameConfig.active_run]
	r["ember_carried"] = _ember
	r["ember_banked"]  = _ember_banked
	r["ember_streak"]  = _ember_streak

# Алтарь (станция в Накале) банкует несомый Накал в безопасность.
func bank_ember() -> int:
	if GameConfig.active_run < 0:
		return 0
	var amt := int(floor(_ember))
	if amt <= 0:
		return 0
	_ember_banked += amt
	_ember -= float(amt)
	_persist_ember()
	GameConfig.stats["best_ember"] = maxi(int(GameConfig.stats.get("best_ember", 0)), _ember_banked)
	GameConfig.save_game()
	# Подсказка про прокачку, если уже хватает на что-то непокупленное.
	var hint := ""
	for offer in ALTAR_OFFER:
		if not GameConfig.skills_unlocked.get(offer["id"], false) and _ember_banked >= int(offer["cost"]):
			hint = "  ·  прокачка: Пауза → Алтарь"
			break
	flash_message("Алтарь · +%d Накала в банк (всего %d)%s" % [amt, _ember_banked, hint])
	if _fx:
		_fx.gold_pulse(1.1)
	return amt

func _show_resume_banner() -> void:
	if _msg_label == null or not is_instance_valid(_msg_label):
		return
	var skills_n: int = 0
	for sk in ["sonar", "shield", "guide", "reveal", "range", "legs", "capacity", "save", "charge", "magic"]:
		if GameConfig.skills_unlocked.get(sk, false):
			skills_n += 1
	_msg_label.text = "⟳ Забег продолжен\nГлубина %d · банк %d Накала · апгрейдов %d" % [_level, _ember_banked, skills_n]
	_msg_label.visible = true
	await get_tree().create_timer(2.6).timeout
	if is_instance_valid(_msg_label) and not _dead and not _game_over and not _won:
		_msg_label.visible = false

func _open_altar_shop() -> void:
	if GameConfig.active_run < 0:
		return
	if is_instance_valid(_pause_overlay):
		_pause_overlay.visible = false
	_altar_layer = CanvasLayer.new()
	_altar_layer.layer = 4
	_altar_layer.process_mode = Node.PROCESS_MODE_ALWAYS
	add_child(_altar_layer)

	var dim := ColorRect.new()
	dim.set_anchors_preset(Control.PRESET_FULL_RECT)
	dim.color = Color(0.02, 0.03, 0.05, 0.9)
	_altar_layer.add_child(dim)

	var center := CenterContainer.new()
	center.set_anchors_preset(Control.PRESET_FULL_RECT)
	_altar_layer.add_child(center)

	var box := VBoxContainer.new()
	box.add_theme_constant_override("separation", 8)
	center.add_child(box)

	var title := Label.new()
	title.text = "АЛТАРЬ"
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	title.add_theme_font_size_override("font_size", 28)
	title.add_theme_color_override("font_color", Color(1.0, 0.78, 0.4))
	box.add_child(title)

	var hint := Label.new()
	hint.text = "Трать Накал на улучшения. Эффект — со следующего этажа."
	hint.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	hint.add_theme_font_size_override("font_size", 14)
	hint.add_theme_color_override("font_color", Color(0.7, 0.66, 0.56))
	box.add_child(hint)

	_altar_bank_lbl = Label.new()
	_altar_bank_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_altar_bank_lbl.add_theme_font_size_override("font_size", 20)
	_altar_bank_lbl.add_theme_color_override("font_color", Color(0.95, 0.88, 0.6))
	box.add_child(_altar_bank_lbl)

	_altar_rows = VBoxContainer.new()
	_altar_rows.add_theme_constant_override("separation", 6)
	box.add_child(_altar_rows)

	var close := Button.new()
	close.text = "Закрыть"
	close.custom_minimum_size = Vector2(200, 44)
	close.add_theme_font_size_override("font_size", 20)
	close.pressed.connect(_close_altar_shop)
	box.add_child(close)

	_altar_refresh()

func _altar_refresh() -> void:
	if not is_instance_valid(_altar_rows):
		return
	_altar_bank_lbl.text = "Банк Накала: %d" % _ember_banked
	for c in _altar_rows.get_children():
		c.queue_free()
	for offer in ALTAR_OFFER:
		var id: String = offer["id"]
		var cost: int = int(offer["cost"])
		var owned: bool = GameConfig.skills_unlocked.get(id, false)
		var b := Button.new()
		b.custom_minimum_size = Vector2(460, 40)
		b.add_theme_font_size_override("font_size", 18)
		if owned:
			b.text = "%s   ·   куплено" % offer["name"]
			b.disabled = true
		else:
			b.text = "%s   ·   %d Накала" % [offer["name"], cost]
			b.disabled = _ember_banked < cost
			b.pressed.connect(_on_altar_buy.bind(id))
		_altar_rows.add_child(b)

func _on_altar_buy(id: String) -> void:
	if _altar_buy(id):
		if _fx:
			_fx.gold_pulse(0.8)
		_altar_refresh()

func _altar_cost(id: String) -> int:
	for offer in ALTAR_OFFER:
		if offer["id"] == id:
			return int(offer["cost"])
	return 999999

func _altar_buy(id: String) -> bool:
	if GameConfig.skills_unlocked.get(id, false):
		return false
	var cost := _altar_cost(id)
	if _ember_banked < cost:
		return false
	_ember_banked -= cost
	GameConfig.skills_unlocked[id] = true
	if GameConfig.passives.has(id):
		GameConfig.passives[id] = true   # пассивки работают при unlocked И passive == true
	if GameConfig.all_active_skills_unlocked():
		GameConfig.skills_unlocked["apex"] = true
	_persist_ember()
	GameConfig.save_game()
	return true

func _close_altar_shop() -> void:
	if is_instance_valid(_altar_layer):
		_altar_layer.queue_free()
	_altar_layer = null   # queue_free отложен — снимаем ссылку сразу, чтобы Escape не «видел» магазин
	if is_instance_valid(_pause_overlay):
		_pause_overlay.visible = true

# Апекс (форма guide): телепортация игрока к выходу.
# Полная форма телепортирует прямо к выходу; эхо — на полпути.
func apex_teleport_to_exit(full: bool) -> void:
	if _player == null or not is_instance_valid(_player):
		return
	var target := _cell_to_world(_exit_cell) + Vector2(0, _exit_floor * _floor_gap)
	if full:
		_player.global_position = target
		_player.current_floor = _exit_floor
	else:
		_player.global_position = _player.global_position.lerp(target, 0.5)
	_player.snap_camera()
	if _fx:
		_fx.flash(Color(1.0, 0.7, 0.3), 0.4)

func on_player_death() -> void:
	if _dead or _won or _game_over:
		return
	_lives -= 1
	_update_lives()
	_level_clean = false                   # этаж больше не «чистый» — серия прервётся
	if GameConfig.active_run >= 0:
		_ember *= 0.5                      # потеря жизни сжигает половину несомого Накала
		_ember_streak = 0
		_persist_ember()
		GameConfig.lives = _lives          # фиксируем убыль жизней в слоте
		GameConfig.save_game()

	# Резкий отклик на смерть: красная вспышка + сильная тряска
	if _fx:
		_fx.flash(Color(1.0, 0.2, 0.15), 0.55)
	if _player and is_instance_valid(_player):
		_player.add_shake(13.0, 0.5)

	if _lives <= 0:
		_game_over = true
		if GameConfig.active_run >= 0:
			GameConfig.runs[GameConfig.active_run]["ended"] = true
			GameConfig.save_game()
			_msg_label.text = "ЗАБЕГ ОКОНЧЕН\nГлубина: %d\n\nEsc — в меню" % _level
		else:
			_msg_label.text = "ИГРА ОКОНЧЕНА\n\nR — заново   Esc — в меню"
		_msg_label.visible = true
		return

	_dead = true
	_msg_label.text = "Свет погас!  Осталось жизней: %d\nВозврат к последней станции…" % _lives
	_msg_label.visible = true
	await get_tree().create_timer(1.2).timeout
	if not is_instance_valid(_player):
		return
	_player.respawn(_cp_pos, _cp_floor)
	_msg_label.visible = false
	_dead = false

func _update_lives() -> void:
	if _lives_label:
		_lives_label.text = "Жизни: %d" % maxi(_lives, 0)
	# Иконка статична; на последней жизни — только краснее (без анимации).
	if _lives_icon and is_instance_valid(_lives_icon):
		_lives_icon.col = Color(1.0, 0.32, 0.38) if _lives <= 1 else Color(1.0, 0.5, 0.55)
		_lives_icon.queue_redraw()

func collect_shard() -> void:
	_shards_collected += 1
	_keys += 1
	GameConfig.add_xp(75)   # 75 XP за каждый осколок
	GameConfig.stats["shards_total"] = int(GameConfig.stats.get("shards_total", 0)) + 1
	if GameConfig.active_run >= 0:
		_ember += EMBER_PER_SHARD * _ember_mult()   # Накал с осколка × серия
		_persist_ember()
	_update_shards()
	play_sfx(_sfx_shard)   # звук подбора осколка
	# Сочный отклик: золотой всплеск по краям + короткая вспышка + лёгкая тряска
	if _fx:
		_fx.gold_pulse(1.5)
		_fx.flash(Color(1.0, 0.9, 0.55), 0.16)
	if _player and is_instance_valid(_player):
		_player.add_shake(4.0, 0.18)
	# Надпись о прогрессе: сколько осколков ещё осталось на этом этаже
	var f: int = _player.current_floor if (_player and is_instance_valid(_player)) else 0
	if f >= 0 and f < _shards_remaining.size():
		_shards_remaining[f] = maxi(0, int(_shards_remaining[f]) - 1)
		var rem: int = _shards_remaining[f]
		if rem > 0:
			flash_message("✦ Осколок (+ключ) · на этаже ещё %d" % rem)
		else:
			flash_message("✦ Осколок (+ключ) · этаж зачищен!")

func use_key() -> bool:
	if _keys > 0:
		_keys -= 1
		_update_shards()
		play_sfx(_sfx_key)   # ключ сработал, запертая дверь открывается
		flash_message("🔑 Ключ потрачен · осталось %d" % _keys)
		return true
	return false

func _update_shards() -> void:
	if _shards_label:
		_shards_label.text = "Осколки: %d / %d" % [_shards_collected, _shards_total]
		if _shards_icon and is_instance_valid(_shards_icon) and _shards_shown >= 0 and _shards_collected != _shards_shown:
			_shards_icon.pop()
		_shards_shown = _shards_collected
	if _keys_label:
		_keys_label.text = "Ключи: %d" % _keys
		if _keys_icon and is_instance_valid(_keys_icon) and _keys_shown >= 0 and _keys != _keys_shown:
			_keys_icon.pop()
		_keys_shown = _keys

func flash_message(text: String) -> void:
	if _toast_label:
		_toast_label.text = text
		_toast_label.visible = true
		_toast_time = 1.6
		# Появление: лёгкий выезд сверху + проявление.
		var base_y := 62.0
		var m := _toast_label.modulate
		m.a = 0.0
		_toast_label.modulate = m
		_toast_label.position.y = base_y - 10.0
		var t := create_tween().set_parallel(true)
		t.tween_property(_toast_label, "modulate:a", 1.0, 0.18)
		t.tween_property(_toast_label, "position:y", base_y, 0.22).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)

func on_player_win() -> void:
	if _won:
		return
	_won = true
	if _player:
		_player.active = false

	play_sfx(_sfx_win)   # фанфары завершения уровня

	# Праздничный отклик: золотая вспышка и всплеск по краям
	if _fx:
		_fx.flash(Color(1.0, 0.85, 0.4), 0.4)
		_fx.gold_pulse(2.2)

	# Салют на месте игрока: большое кольцо света + фонтан искр
	if _player and is_instance_valid(_player):
		var b := Node2D.new()
		b.set_script(load("res://burst.gd"))
		b.color = Color(1.0, 0.88, 0.5, 1.0)
		b.max_scale = 16.0
		b.dur = 0.9
		b.light_energy = 3.2
		add_child(b)
		b.global_position = _player.global_position
		var sp := CPUParticles2D.new()
		sp.set_script(load("res://sparkle.gd"))
		sp.spark_color = Color(1.0, 0.9, 0.55)
		sp.spark_amount = 44
		sp.spark_speed = 340.0
		add_child(sp)
		sp.global_position = _player.global_position
		_player.add_shake(7.0, 0.4)

	# Оценка прохождения уровня (ранг) — в обоих режимах.
	var rank_info := _compute_rank()
	var rk: String = rank_info["rank"]
	GameConfig.stats["rank_" + rk] = int(GameConfig.stats.get("rank_" + rk, 0)) + 1
	if GameConfig.active_run >= 0:
		var ranks: Array = GameConfig.runs[GameConfig.active_run]["ranks"]
		ranks.append({
			"lvl": _level, "rank": rk, "score": rank_info["score"],
			"shards": _shards_collected, "total": _shards_total,
			"clean": rank_info["clean"], "no_skills": rank_info["no_skills"],
			"time": _elapsed,
		})
	var rank_line := "Ранг %s   ·   осколки %d/%d   ·   %d очк." % [rk, _shards_collected, _shards_total, rank_info["score"]]

	if GameConfig.active_run >= 0:
		# Режим «Накал»: бесконечный спуск, прогресс пишется в слот забега.
		GameConfig.add_xp(400)
		GameConfig.stats["levels_cleared"] = int(GameConfig.stats.get("levels_cleared", 0)) + 1
		# Награда Накалом за этаж + бонус и рост серии за «чистый» спуск.
		_ember += EMBER_LEVEL_BONUS * _ember_mult()
		if _level_clean:
			_ember += EMBER_CLEAN_BONUS * _ember_mult()
			_ember_streak = mini(_ember_streak + 1, EMBER_STREAK_MAX)
		else:
			_ember_streak = 0
		_persist_ember()
		GameConfig.level = _level + 1
		GameConfig.lives = _lives          # жизни переносятся в следующий этаж
		GameConfig.save_game()             # маршрутизируется в слот
		var clean_tag := "  ·  чисто ×%d" % _ember_streak if _level_clean else ""
		_win_label.text = "Глубина %d · ранг %s\nНакал %d%s · %d очк.\nВремя: %.1f с" % [_level, rk, int(_ember), clean_tag, rank_info["score"], _elapsed]
		_win_label.visible = true
		await get_tree().create_timer(1.0).timeout
		await _show_stats_screen()
		_restart()
	elif _level < MAX_LEVEL:
		GameConfig.add_xp(400)   # 400 XP за завершение уровня
		GameConfig.level = _level + 1
		GameConfig.max_unlocked_level = maxi(GameConfig.max_unlocked_level, _level + 1)
		GameConfig.save_game()
		_win_label.text = "Уровень %d пройден!\n%s\nВремя: %.1f с" % [_level, rank_line, _elapsed]
		_win_label.visible = true
		await get_tree().create_timer(1.0).timeout
		await _show_stats_screen()
		_restart()
	else:
		GameConfig.save_game()
		_win_label.text = "ПОБЕДА!  Все %d уровней\n%s\nВремя: %.1f с\n\nR — заново   Esc — в меню" % [MAX_LEVEL, rank_line, _elapsed]
		_win_label.visible = true

# --- Интерфейс ---

func _label_outline(l: Label, sz: int = 4) -> void:
	# Тонкая тёмная обводка — читаемость текста поверх ярких неоновых стен.
	l.add_theme_constant_override("outline_size", sz)
	l.add_theme_color_override("font_outline_color", Color(0, 0, 0, 0.75))

# Неоновая HUD-иконка (см. hud_icons.gd): создаём, ставим размер/позицию, цвет.
func _add_icon(parent: Node, kind: String, color: Color, pos: Vector2, sz: float) -> HudIcon:
	var ic := HudIcon.new()
	ic.kind = kind
	ic.col = color
	ic.size = Vector2(sz, sz)
	ic.custom_minimum_size = ic.size
	ic.position = pos
	ic.mouse_filter = Control.MOUSE_FILTER_IGNORE
	parent.add_child(ic)
	return ic

# Бейдж-клавиша (keycap): скруглённый прямоугольник с тонкой неоновой рамкой и
# буквой по центру. Это маленький значок, а НЕ панель интерфейса.
func _make_keycap(txt: String, accent: Color) -> Panel:
	var p := Panel.new()
	p.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var sb := StyleBoxFlat.new()
	sb.bg_color = Color(0.09, 0.12, 0.19, 0.72)
	sb.set_corner_radius_all(6)
	sb.set_border_width_all(1)
	sb.border_color = Color(accent.r, accent.g, accent.b, 0.6)
	p.add_theme_stylebox_override("panel", sb)
	var w := 26.0 if txt.length() == 1 else 20.0 + float(txt.length()) * 8.5
	p.custom_minimum_size = Vector2(w, 24)
	p.size = Vector2(w, 24)
	p.pivot_offset = p.size * 0.5
	var l := Label.new()
	l.text = txt
	l.add_theme_font_size_override("font_size", 13)
	l.add_theme_color_override("font_color", Color(0.86, 0.95, 1.0))
	l.set_anchors_preset(Control.PRESET_FULL_RECT)
	l.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	l.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	l.mouse_filter = Control.MOUSE_FILTER_IGNORE
	p.add_child(l)
	return p

# Мягкая подсветка позади keycap (для пульса готового «Озарения»).
func _make_cap_glow(cap: Panel, accent: Color) -> Panel:
	var g := Panel.new()
	g.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var sb := StyleBoxFlat.new()
	sb.bg_color = Color(accent.r, accent.g, accent.b, 1.0)
	sb.set_corner_radius_all(10)
	g.add_theme_stylebox_override("panel", sb)
	g.custom_minimum_size = cap.size + Vector2(10, 10)
	g.size = cap.size + Vector2(10, 10)
	var m := g.modulate
	m.a = 0.0
	g.modulate = m
	return g

# Строка навыка: [keycap клавиши] [название]. Позиционируем абсолютно (как раньше),
# чтобы левый угол остался свободным макетом без панели.
# Иконка навыка в HUD: пиктограмма (как в меню навыков) + кольцо перезарядки
# вокруг неё (как шкала станции) + клавиша снизу.
func _make_skill_chip(parent: Control, d: Dictionary) -> void:
	var accent: Color = SkillIcons.color_of(d["id"])
	var icon := SkillHudIcon.new()
	icon.icon_tex = SkillIcons.make(d["id"], 42)
	icon.accent = accent
	parent.add_child(icon)
	icon.set_key(d["key"])

	_skills_ui[d["id"]] = {
		"icon": icon, "base": d["name"], "accent": accent, "ready": true,
	}

# Раскладывает ВИДИМЫЕ иконки навыков в ряд слева направо без пропусков.
func _layout_skills() -> void:
	var x := 14.0
	for d in SKILL_DEFS:
		var ui = _skills_ui.get(d["id"])
		if ui == null:
			continue
		var icon: SkillHudIcon = ui["icon"]
		if not icon.visible:
			continue
		icon.position = Vector2(x, 0)
		x += 56.0

# Обновление иконок навыков: видимость по разблокировке + состояние (готов/кд/мало света).
func _update_skills_hud() -> void:
	for d in SKILL_DEFS:
		var ui = _skills_ui.get(d["id"])
		if ui == null:
			continue
		var unlocked: bool = GameConfig.skills_unlocked.get(d["id"], false)
		ui["icon"].visible = unlocked
		if not unlocked:
			continue
		var m: float = _player._skill_cd_mult
		match d["id"]:
			"flash":  _update_skill("flash",  _player.flash_cd,  _player.energy, _player.FLASH_COST,  _player.FLASH_COOLDOWN * m)
			"dash":   _update_skill("dash",   _player.dash_cd,   _player.energy, _player.DASH_COST,   _player.DASH_COOLDOWN * m)
			"sonar":  _update_skill("sonar",  _player.sonar_cd,  _player.energy, _player.SONAR_COST,  _player.SONAR_COOLDOWN * m)
			"shield": _update_skill("shield", _player.shield_cd, _player.energy, _player.SHIELD_COST, _player.SHIELD_COOLDOWN * m)
			"guide":  _update_skill("guide",  _player.guide_cd,  _player.energy, _player.GUIDE_COST,  _player.GUIDE_COOLDOWN * m)
			"reveal": _update_reveal(_player.reveal_charge)
	_layout_skills()

func _build_screen_fx() -> void:
	_fx = CanvasLayer.new()
	_fx.set_script(load("res://screenfx.gd"))
	add_child(_fx)

func _update_darkness_aspect() -> void:
	if _dark_mat:
		var s := get_viewport().get_visible_rect().size
		_dark_mat.set_shader_parameter("aspect", (s.x / s.y) if s.y > 0.0 else 1.777)

# Короткая полноэкранная засветка (навыки, переход между этажами).
func flash_screen(col: Color, strength: float) -> void:
	if _fx:
		_fx.flash(col, strength)

func _build_touch_controls() -> void:
	var layer := CanvasLayer.new()
	layer.layer = 2
	add_child(layer)

	# Виртуальный джойстик (реагирует на левую половину экрана)
	_joystick = Control.new()
	_joystick.set_script(load("res://touch_joystick.gd"))
	_joystick.process_mode = Node.PROCESS_MODE_PAUSABLE
	layer.add_child(_joystick)

	var vw: float = get_viewport().get_visible_rect().size.x
	var vh: float = get_viewport().get_visible_rect().size.y

	# Кнопки навыков (справа снизу): Вспышка/Рывок/Сонар/Щит/Искра/Озарение
	var grid := GridContainer.new()
	grid.columns = 3
	grid.add_theme_constant_override("h_separation", 10)
	grid.add_theme_constant_override("v_separation", 10)
	grid.position = Vector2(vw - 350, vh - 190)
	grid.process_mode = Node.PROCESS_MODE_PAUSABLE
	layer.add_child(grid)

	grid.add_child(_make_touch_button("Вспышка", func(): _skill(0)))
	grid.add_child(_make_touch_button("Рывок", func(): _skill(1)))
	grid.add_child(_make_touch_button("Сонар", func(): _skill(2)))
	grid.add_child(_make_touch_button("Щит", func(): _skill(3)))
	grid.add_child(_make_touch_button("Искра", func(): _skill(4)))
	grid.add_child(_make_touch_button("Озарение", func(): _skill(5)))

	# Кнопка паузы (вверху по центру)
	var pause_btn := _make_touch_button("II", _toggle_pause)
	pause_btn.custom_minimum_size = Vector2(70, 44)
	pause_btn.position = Vector2(vw * 0.5 - 35, 6)
	pause_btn.process_mode = Node.PROCESS_MODE_PAUSABLE
	layer.add_child(pause_btn)

func _make_touch_button(text: String, on_pressed: Callable) -> Button:
	var b := Button.new()
	b.text = text
	b.custom_minimum_size = Vector2(108, 56)
	b.focus_mode = Control.FOCUS_NONE
	b.add_theme_font_size_override("font_size", 17)
	b.modulate = Color(1, 1, 1, 0.85)
	b.pressed.connect(on_pressed)
	return b

func _skill(which: int) -> void:
	if not (_player and is_instance_valid(_player)):
		return
	match which:
		0: _player._try_flash()
		1: _player._try_dash()
		2: _player._try_sonar()
		3: _player._try_shield()
		4: _player._try_guide()
		5: _player._try_reveal()

func _start_music() -> void:
	var stream := _load_audio("res://sounds/8-bit-music-1.mp3", true)
	if stream == null:
		return  # mp3 ещё не импортирован редактором — просто без музыки
	_music = AudioStreamPlayer.new()
	_music.stream = stream
	_music.volume_db = -9.0   # фон, чтобы не перебивал эффекты
	_music.process_mode = Node.PROCESS_MODE_ALWAYS   # играет и на паузе
	add_child(_music)
	_music.play()

func _load_sfx() -> void:
	# Эффекты лежат в sounds/. Если файл ещё не импортирован — будет null,
	# play_sfx это переживёт (просто без звука), как и музыка.
	_sfx_shard = _load_audio("res://sounds/shrapnel.mp3")
	_sfx_key   = _load_audio("res://sounds/key.mp3")
	_sfx_win   = _load_audio("res://sounds/win.mp3")
	_sfx_beep  = _load_audio("res://sounds/beep.mp3")
	_sfx_damage  = _load_audio("res://sounds/damage.mp3")
	_sfx_sonar   = _load_audio("res://sounds/sonar.mp3")
	_sfx_sparkle = _load_audio("res://sounds/sparkle.mp3")

# Звук глотка энергии с кристалла (вызывается из station.gd).
func beep() -> void:
	play_sfx(_sfx_beep)

# Звук активного навыка (вызывается из player.gd при успешном применении).
func play_skill_sfx(which: String) -> void:
	match which:
		"sonar":
			play_sfx(_sfx_sonar)
			if _boss and is_instance_valid(_boss) and _boss.has_method("reveal_weak_point"):
				_boss.reveal_weak_point()
		"guide": play_sfx(_sfx_sparkle)

# Отклик на удар врага: красный всплеск по углам + короткая красная засветка.
func enemy_hit_fx() -> void:
	play_sfx(_sfx_damage)                            # звук удара врага
	if _fx:
		_fx.danger_pulse(1.1)                       # красные углы — основной отклик
		_fx.flash(Color(1.0, 0.2, 0.15), 0.12)      # лёгкая красная засветка для удара

func _load_audio(path: String, looped: bool = false) -> AudioStream:
	var stream = load(path)
	if stream == null:
		return null
	if stream is AudioStreamMP3:
		stream.loop = looped   # музыку зацикливаем, эффекты — нет
	return stream

func play_sfx(stream: AudioStream, volume_db: float = 0.0) -> void:
	# Разовый плеер: создаём, играем, сам себя удаляет по окончании.
	# Так звуки не обрывают друг друга и могут накладываться.
	if stream == null:
		return
	var p := AudioStreamPlayer.new()
	p.stream = stream
	p.volume_db = volume_db
	p.process_mode = Node.PROCESS_MODE_ALWAYS   # звучит и во время паузы
	add_child(p)
	p.finished.connect(p.queue_free)
	p.play()

func _build_hud() -> void:
	# Слой тинта (под HUD, над миром)
	var fx := CanvasLayer.new()
	fx.layer = 1
	add_child(fx)

	_tint = ColorRect.new()
	_tint.set_anchors_preset(Control.PRESET_FULL_RECT)
	_tint.color = Color(0, 0, 0, 0)
	_tint.mouse_filter = Control.MOUSE_FILTER_IGNORE
	fx.add_child(_tint)

	# Виньетка темноты («туман войны») — шар видимости вокруг игрока (камера держит
	# его в центре экрана). Приоткрывается во время Озарения; max_dark<1 пропускает
	# яркий свет (сонар, выход), гася лишь тусклый ambient далёкого лабиринта.
	var dark_rect := ColorRect.new()
	dark_rect.set_anchors_preset(Control.PRESET_FULL_RECT)
	dark_rect.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_dark_mat = ShaderMaterial.new()
	_dark_mat.shader = load("res://darkness.gdshader")
	_dark_mat.set_shader_parameter("inner", DARK_INNER)
	_dark_mat.set_shader_parameter("outer", DARK_OUTER)
	_dark_mat.set_shader_parameter("max_dark", DARK_MAX)
	dark_rect.material = _dark_mat
	fx.add_child(dark_rect)
	_update_darkness_aspect()
	get_viewport().size_changed.connect(_update_darkness_aspect)

	var layer := CanvasLayer.new()
	layer.layer = 2
	add_child(layer)
	_hud_layer = layer

	var vpw: float = get_viewport().get_visible_rect().size.x

	# === Верхняя HUD-панель: всё в одной полосе сверху, лабиринт всегда ниже неё ===
	# Полупрозрачный фон полосы (мазе слегка просвечивает, но текст читаем).
	var band := ColorRect.new()
	band.set_anchors_preset(Control.PRESET_TOP_WIDE)
	band.offset_bottom = HUD_BAND
	band.color = Color(0.02, 0.03, 0.06, 0.62)
	band.mouse_filter = Control.MOUSE_FILTER_IGNORE
	layer.add_child(band)
	# Тонкая неоновая линия-подчёркивание снизу панели
	var band_line := ColorRect.new()
	band_line.set_anchors_preset(Control.PRESET_TOP_WIDE)
	band_line.offset_top = HUD_BAND - 2.0
	band_line.offset_bottom = HUD_BAND
	band_line.color = Color(0.3, 0.55, 0.9, 0.35)
	band_line.mouse_filter = Control.MOUSE_FILTER_IGNORE
	layer.add_child(band_line)

	# Тонкий XP-бар по самому верхнему краю
	_xp_bar = ProgressBar.new()
	_xp_bar.min_value = 0
	_xp_bar.max_value = GameConfig.XP_PER_SP
	_xp_bar.show_percentage = false
	_xp_bar.position = Vector2(0, 0)
	_xp_bar.custom_minimum_size = Vector2(vpw, 4)
	_xp_bar.size = Vector2(vpw, 4)
	var xb := StyleBoxFlat.new(); xb.bg_color = Color(0.06, 0.06, 0.12, 0.6)
	_xp_bar.add_theme_stylebox_override("background", xb)
	var xf := StyleBoxFlat.new(); xf.bg_color = Color(0.6, 0.45, 1.0)
	_xp_bar.add_theme_stylebox_override("fill", xf)
	layer.add_child(_xp_bar)

	# --- Строка 1 (слева): уровень · биом · этаж + SP ---
	_level_label = Label.new()
	_level_label.text = "Уровень %d   ·   этаж 1 / %d" % [_level, _floors]
	_level_label.position = Vector2(14, 8)
	_level_label.add_theme_font_size_override("font_size", 18)
	_level_label.add_theme_color_override("font_color", Color(0.86, 0.93, 1.0))
	_label_outline(_level_label)
	layer.add_child(_level_label)

	_sp_label = Label.new()
	_sp_label.position = Vector2(14, 34)
	_sp_label.add_theme_font_size_override("font_size", 13)
	_sp_label.add_theme_color_override("font_color", Color(0.75, 0.6, 1.0))
	_label_outline(_sp_label, 3)
	layer.add_child(_sp_label)

	# Индикатор Накала (только в забеге) — по центру панели
	if GameConfig.active_run >= 0:
		_ember_label = Label.new()
		_ember_label.position = Vector2(vpw * 0.5 - 180, 8)
		_ember_label.custom_minimum_size = Vector2(360, 0)
		_ember_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		_ember_label.add_theme_font_size_override("font_size", 18)
		_ember_label.add_theme_color_override("font_color", Color(1.0, 0.72, 0.3))
		_label_outline(_ember_label)
		layer.add_child(_ember_label)

	# --- Строка 2 (слева): время · свет · пассивки ---
	_add_icon(layer, "clock", Color(0.6, 0.85, 1.0), Vector2(120, 35), 18)
	_time_label = Label.new()
	_time_label.text = "0.0 с"
	_time_label.position = Vector2(144, 33)
	_time_label.add_theme_font_size_override("font_size", 16)
	_time_label.add_theme_color_override("font_color", Color(0.82, 0.9, 1.0))
	_label_outline(_time_label)
	layer.add_child(_time_label)

	var bar_label := Label.new()
	bar_label.text = "Свет"
	bar_label.position = Vector2(232, 35)
	bar_label.add_theme_font_size_override("font_size", 14)
	bar_label.add_theme_color_override("font_color", Color(0.85, 0.9, 1.0))
	_label_outline(bar_label, 3)
	layer.add_child(bar_label)

	_energy_bar = ProgressBar.new()
	_energy_bar.min_value = 0.0
	_energy_bar.max_value = 1.0
	_energy_bar.step = 0.001
	_energy_bar.show_percentage = false
	_energy_bar.value = 1.0
	_energy_bar.position = Vector2(278, 36)
	_energy_bar.custom_minimum_size = Vector2(150, 14)
	var bg := StyleBoxFlat.new()
	bg.bg_color = Color(0.08, 0.09, 0.13, 0.7)
	bg.set_corner_radius_all(6)
	bg.set_border_width_all(1)
	bg.border_color = Color(0.4, 0.55, 0.8, 0.35)
	_energy_bar.add_theme_stylebox_override("background", bg)
	_energy_fill = StyleBoxFlat.new()
	_energy_fill.bg_color = Color(1.0, 0.85, 0.3)
	_energy_fill.set_corner_radius_all(6)
	_energy_bar.add_theme_stylebox_override("fill", _energy_fill)
	layer.add_child(_energy_bar)

	# Пассивки — компактно справа от полосы света
	_boost_row = Control.new()
	_boost_row.position = Vector2(448, 33)
	_boost_row.mouse_filter = Control.MOUSE_FILTER_IGNORE
	layer.add_child(_boost_row)
	_add_icon(_boost_row, "boost", Color(0.5, 0.95, 0.6), Vector2(0, 0), 17)
	_boost_label = Label.new()
	_boost_label.position = Vector2(20, 1)
	_boost_label.add_theme_font_size_override("font_size", 13)
	_boost_label.add_theme_color_override("font_color", Color(0.6, 0.95, 0.7))
	_label_outline(_boost_label, 3)
	_boost_row.add_child(_boost_label)

	_adapt_row = Control.new()
	_adapt_row.position = Vector2(572, 33)
	_adapt_row.mouse_filter = Control.MOUSE_FILTER_IGNORE
	layer.add_child(_adapt_row)
	_add_icon(_adapt_row, "adapt", Color(0.5, 0.95, 0.6), Vector2(0, 0), 17)
	_adapt_label = Label.new()
	_adapt_label.position = Vector2(20, 1)
	_adapt_label.add_theme_font_size_override("font_size", 13)
	_adapt_label.add_theme_color_override("font_color", Color(0.6, 0.95, 0.7))
	_label_outline(_adapt_label, 3)
	_adapt_row.add_child(_adapt_label)

	# --- Правый край панели: жизни / осколки / ключи (компактно по вертикали) ---
	var right_x: float = vpw - 200.0
	_lives_icon = _add_icon(layer, "heart", Color(1.0, 0.5, 0.55), Vector2(right_x, 8), 20)
	_lives_label = Label.new()
	_lives_label.position = Vector2(right_x + 28, 6)
	_lives_label.add_theme_font_size_override("font_size", 19)
	_lives_label.add_theme_color_override("font_color", Color(1.0, 0.6, 0.6))
	_label_outline(_lives_label)
	layer.add_child(_lives_label)
	_update_lives()

	_shards_icon = _add_icon(layer, "shard", Color(1.0, 0.82, 0.4), Vector2(right_x, 40), 20)
	_shards_label = Label.new()
	_shards_label.position = Vector2(right_x + 28, 38)
	_shards_label.add_theme_font_size_override("font_size", 18)
	_shards_label.add_theme_color_override("font_color", Color(1.0, 0.92, 0.5))
	_label_outline(_shards_label)
	layer.add_child(_shards_label)

	_keys_icon = _add_icon(layer, "key", Color(0.55, 0.85, 1.0), Vector2(right_x, 72), 20)
	_keys_label = Label.new()
	_keys_label.position = Vector2(right_x + 28, 70)
	_keys_label.add_theme_font_size_override("font_size", 18)
	_keys_label.add_theme_color_override("font_color", Color(0.7, 0.85, 1.0))
	_label_outline(_keys_label)
	layer.add_child(_keys_label)
	_update_shards()

	# --- Строка 3: навыки — пиктограммы с кольцом перезарядки и клавишей ---
	_skill_bar = Control.new()
	_skill_bar.position = Vector2(0, 48)
	_skill_bar.mouse_filter = Control.MOUSE_FILTER_IGNORE
	layer.add_child(_skill_bar)
	for d in SKILL_DEFS:
		_make_skill_chip(_skill_bar, d)
	_layout_skills()

	# --- Подсказка по паузе — мелко в нижнем-правом углу ---
	var hint := Label.new()
	hint.text = "P / Esc — пауза"
	hint.set_anchors_preset(Control.PRESET_BOTTOM_RIGHT)
	hint.offset_left = -150
	hint.offset_right = -12
	hint.offset_top = -26
	hint.offset_bottom = -8
	hint.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	hint.add_theme_font_size_override("font_size", 13)
	hint.add_theme_color_override("font_color", Color(0.5, 0.53, 0.6))
	_label_outline(hint, 3)
	hint.mouse_filter = Control.MOUSE_FILTER_IGNORE
	layer.add_child(hint)

	# --- Счётчик FPS (внизу слева, только если включён в настройках) ---
	if GameConfig.show_fps:
		_fps_label = Label.new()
		_fps_label.set_anchors_preset(Control.PRESET_BOTTOM_LEFT)
		_fps_label.offset_left = 16
		_fps_label.offset_right = 200
		_fps_label.offset_top = -30
		_fps_label.offset_bottom = -6
		_fps_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
		_fps_label.text = "FPS: 0"
		_fps_label.add_theme_font_size_override("font_size", 16)
		_fps_label.add_theme_color_override("font_color", Color(0.6, 0.95, 0.7))
		_label_outline(_fps_label, 3)
		_fps_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
		layer.add_child(_fps_label)

	# Короткое сообщение (тост) — вверху по центру, под строкой события
	_toast_label = Label.new()
	_toast_label.visible = false
	_toast_label.set_anchors_preset(Control.PRESET_TOP_WIDE)
	_toast_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_toast_label.position = Vector2(0, 62)
	_toast_label.add_theme_font_size_override("font_size", 22)
	_toast_label.add_theme_color_override("font_color", Color(1.0, 0.82, 0.45))
	_label_outline(_toast_label)
	layer.add_child(_toast_label)

	# Сообщение о событии (вверху по центру)
	_event_label = Label.new()
	_event_label.visible = false
	_event_label.set_anchors_preset(Control.PRESET_TOP_WIDE)
	_event_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_event_label.position = Vector2(0, 24)
	_event_label.add_theme_font_size_override("font_size", 28)
	_label_outline(_event_label)
	layer.add_child(_event_label)

	# Сообщение о смерти
	_msg_label = Label.new()
	_msg_label.visible = false
	_msg_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_msg_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	_msg_label.add_theme_font_size_override("font_size", 36)
	_msg_label.add_theme_color_override("font_color", Color(1.0, 0.4, 0.4))
	_msg_label.set_anchors_preset(Control.PRESET_FULL_RECT)
	layer.add_child(_msg_label)

	# Экран победы
	_win_label = Label.new()
	_win_label.visible = false
	_win_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_win_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	_win_label.add_theme_font_size_override("font_size", 44)
	_win_label.add_theme_color_override("font_color", Color(1.0, 0.85, 0.3))
	_win_label.set_anchors_preset(Control.PRESET_FULL_RECT)
	layer.add_child(_win_label)

	_build_pause_overlay(layer)

func _build_pause_overlay(layer: CanvasLayer) -> void:
	_pause_overlay = Control.new()
	_pause_overlay.set_anchors_preset(Control.PRESET_FULL_RECT)
	_pause_overlay.visible = false
	_pause_overlay.process_mode = Node.PROCESS_MODE_ALWAYS
	layer.add_child(_pause_overlay)

	var bg := ColorRect.new()
	bg.set_anchors_preset(Control.PRESET_FULL_RECT)
	bg.color = Color(0.03, 0.03, 0.06, 0.9)
	_pause_overlay.add_child(bg)

	var center := CenterContainer.new()
	center.set_anchors_preset(Control.PRESET_FULL_RECT)
	_pause_overlay.add_child(center)

	var root := VBoxContainer.new()
	root.add_theme_constant_override("separation", 22)
	root.alignment = BoxContainer.ALIGNMENT_CENTER
	center.add_child(root)

	var title := Label.new()
	title.text = "ПАУЗА"
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	title.add_theme_font_size_override("font_size", 48)
	title.add_theme_color_override("font_color", Color(1.0, 0.85, 0.3))
	root.add_child(title)

	# Две колонки: слева карта + кнопки, справа информация.
	var cols := HBoxContainer.new()
	cols.add_theme_constant_override("separation", 56)
	cols.alignment = BoxContainer.ALIGNMENT_CENTER
	root.add_child(cols)

	# --- Левая колонка: карта и кнопки ---
	var left := VBoxContainer.new()
	left.add_theme_constant_override("separation", 12)
	cols.add_child(left)

	var map_title := Label.new()
	map_title.text = "Карта (пройденный путь)"
	map_title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	map_title.add_theme_font_size_override("font_size", 16)
	map_title.add_theme_color_override("font_color", Color(0.7, 0.7, 0.8))
	left.add_child(map_title)

	_minimap = TextureRect.new()
	_minimap.custom_minimum_size = Vector2(320, 200)
	_minimap.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	_minimap.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	_minimap.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	left.add_child(_minimap)

	# небольшой отступ между картой и кнопками
	var spacer := Control.new()
	spacer.custom_minimum_size = Vector2(0, 8)
	left.add_child(spacer)

	left.add_child(_make_overlay_button("Продолжить", _toggle_pause))
	if GameConfig.active_run >= 0:
		# В «Накале» прокачка — на алтаре за Накал; рестарт уровня запрещён.
		left.add_child(_make_overlay_button("Алтарь — магазин", _open_altar_shop))
	else:
		left.add_child(_make_overlay_button("Навыки", _open_skills_menu))
		left.add_child(_make_overlay_button("Заново", _restart))
	left.add_child(_make_overlay_button("В меню", _goto_menu))

	# --- Правая колонка: информация ---
	var right := VBoxContainer.new()
	right.alignment = BoxContainer.ALIGNMENT_CENTER
	cols.add_child(right)

	_pause_info = Label.new()
	_pause_info.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_pause_info.add_theme_font_size_override("font_size", 18)
	right.add_child(_pause_info)

	# Постоянная «← Назад» сверху-слева (поверх всего; возобновляет игру, как Esc).
	var back_btn := _make_overlay_button("← Назад", _toggle_pause)
	back_btn.custom_minimum_size = Vector2(130, 44)
	back_btn.focus_mode = Control.FOCUS_NONE
	back_btn.set_anchors_preset(Control.PRESET_TOP_LEFT)
	back_btn.offset_left = 20
	back_btn.offset_top = 20
	_pause_overlay.add_child(back_btn)

func _make_overlay_button(text: String, on_pressed: Callable) -> Button:
	var b := Button.new()
	b.text = text
	b.custom_minimum_size = Vector2(240, 44)
	b.add_theme_font_size_override("font_size", 22)
	b.pressed.connect(on_pressed)
	return b

func _update_reveal(charge: float) -> void:
	var ui = _skills_ui.get("reveal")
	if ui == null:
		return
	var icon: SkillHudIcon = ui["icon"]
	icon.ready_frac = clampf(charge, 0.0, 1.0)
	icon.glow_pulse = charge >= 1.0
	icon.low_energy = false
	icon.queue_redraw()

func _update_skill(id: String, cd: float, energy: float, cost: float, cd_max: float) -> void:
	var ui = _skills_ui.get(id)
	if ui == null:
		return
	var icon: SkillHudIcon = ui["icon"]
	var ready := cd <= 0.05 and energy >= cost
	icon.ready_frac = 1.0 if cd <= 0.05 else clampf(1.0 - cd / maxf(cd_max, 0.01), 0.0, 1.0)
	icon.low_energy = energy < cost
	icon.queue_redraw()
	# Переход кулдаун → готов: короткий «пинок» иконки.
	if ready and not ui["ready"]:
		_icon_pop(icon)
	ui["ready"] = ready

func _icon_pop(icon: Control) -> void:
	icon.pivot_offset = icon.size * 0.5
	var t := create_tween()
	t.tween_property(icon, "scale", Vector2.ONE * 1.18, 0.08).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	t.tween_property(icon, "scale", Vector2.ONE, 0.16).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
