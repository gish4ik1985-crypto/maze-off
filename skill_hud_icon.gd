extends Control
class_name SkillHudIcon

# HUD-«бусина» навыка (панель навыков внизу экрана, v6.0): иконка из SkillIcons,
# вокруг — неоновое кольцо. Готов — кольцо целое и мягко светится; на перезарядке
# иконка тускнеет, её накрывает тёмная «шторка», а кольцо заполняется по часовой;
# не хватает Воли — иконка и кольцо красноватые. Под бусиной — клавиша.

const W := 46.0            # ширина ячейки
const H := 62.0            # высота ячейки (бусина + клавиша)
const ICON_D := 42.0       # диаметр иконки
const RING_R := 24.0       # радиус кольца

var icon_tex: Texture2D
var accent: Color = Color.WHITE
var ready_frac: float = 1.0   # 1 = готов; <1 = доля до готовности (кольцо заполняется)
var low_energy: bool = false  # не хватает Воли — иконка краснеет
var glow_pulse: bool = false  # пульс готового заряда (Озарение)

# Сенсорный режим (v6.6): та же «бусина», но по ней можно нажать, а клавиши нет.
signal tapped
var show_key: bool = true
var pressable: bool = false
var _last_tap_ms: int = -1000

var _key_label: Label
var _key_text: String = ""
var _center := Vector2(W * 0.5, 25.0)
var _pulse_t: float = 0.0
var _halo: Texture2D

func _ready() -> void:
	custom_minimum_size = Vector2(W, H)
	size = Vector2(W, H)
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	_halo = MazeTextures.make_light(64)
	_key_label = Label.new()
	_key_label.text = _key_text
	_key_label.add_theme_font_size_override("font_size", 11)
	_key_label.add_theme_color_override("font_color", Color(0.82, 0.92, 1.0))
	_key_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_key_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	_key_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(_key_label)
	_key_label.visible = show_key
	if pressable:
		mouse_filter = Control.MOUSE_FILTER_STOP
	_place_key()

func _gui_input(event: InputEvent) -> void:
	if not pressable:
		return
	var hit := false
	if event is InputEventScreenTouch and event.pressed:
		hit = true
	elif event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT:
		hit = true
	if not hit:
		return
	accept_event()
	# Касание приходит и как ScreenTouch, и как эмулированная мышь: одно нажатие — один раз.
	var now := Time.get_ticks_msec()
	if now - _last_tap_ms < 150:
		return
	_last_tap_ms = now
	tapped.emit()

func _process(delta: float) -> void:
	if glow_pulse:
		_pulse_t += delta
		queue_redraw()

func set_key(t: String) -> void:
	_key_text = t
	if _key_label:
		_key_label.text = t
		_place_key()

func _key_rect() -> Rect2:
	var kw := maxf(20.0, 12.0 + 6.5 * float(_key_text.length()))
	return Rect2(Vector2(W * 0.5 - kw * 0.5, 47.0), Vector2(kw, 15.0))

func _place_key() -> void:
	var kr := _key_rect()
	_key_label.position = kr.position
	_key_label.size = kr.size

func _ring(a0: float, a1: float, col: Color, w: float) -> void:
	draw_arc(_center, RING_R, a0, a1, 48, Color(col.r, col.g, col.b, 0.12), w * 2.6, true)
	draw_arc(_center, RING_R, a0, a1, 48, Color(col.r, col.g, col.b, 0.30), w * 1.6, true)
	draw_arc(_center, RING_R, a0, a1, 48, col, w, true)

func _draw() -> void:
	var frac := clampf(ready_frac, 0.0, 1.0)
	var is_ready := frac >= 0.999
	var ring_col := Color(accent.r, accent.g, accent.b, 0.95)
	if low_energy:
		ring_col = Color(0.95, 0.4, 0.34, 0.9)
	# Мягкий ореол за готовой бусиной (у «Озарения» пульсирует).
	if is_ready and not low_energy:
		var pa := 0.16
		if glow_pulse:
			pa = 0.2 + 0.16 * (0.5 + 0.5 * sin(_pulse_t * 4.5))
		draw_texture_rect(_halo, Rect2(_center - Vector2(32, 32), Vector2(64, 64)), false,
			Color(accent.r, accent.g, accent.b, pa))
	# Иконка: тускнеет на перезарядке, краснеет при нехватке Воли.
	if icon_tex:
		var mod := Color(1, 1, 1, 1)
		if not is_ready:
			mod = Color(0.5, 0.52, 0.58, 1.0)
		elif low_energy:
			mod = Color(1.0, 0.66, 0.62, 1.0)
		draw_texture_rect(icon_tex, Rect2(_center - Vector2(ICON_D, ICON_D) * 0.5, Vector2(ICON_D, ICON_D)), false, mod)
	# «Шторка» перезарядки: тёмный сектор на ещё не восстановленную долю.
	if not is_ready:
		var a0 := -PI * 0.5 + TAU * frac
		var a1 := -PI * 0.5 + TAU
		var pts := PackedVector2Array([_center])
		var steps := maxi(3, int(ceilf((a1 - a0) / 0.2)))
		for i in steps + 1:
			var a := lerpf(a0, a1, float(i) / float(steps))
			pts.append(_center + Vector2(cos(a), sin(a)) * (ICON_D * 0.5 - 0.5))
		draw_colored_polygon(pts, Color(0.01, 0.02, 0.04, 0.6))
	# Кольцо: пустой трек + заполнение (целое, когда готов).
	draw_arc(_center, RING_R, 0.0, TAU, 48, Color(0.2, 0.25, 0.33, 0.5), 2.0, true)
	if is_ready:
		if glow_pulse and not low_energy:
			var p := 0.55 + 0.45 * sin(_pulse_t * 4.5)
			ring_col = Color(accent.r, accent.g, accent.b, 0.5 + 0.5 * p)
		_ring(0.0, TAU, ring_col, 2.2)
	else:
		_ring(-PI * 0.5, -PI * 0.5 + TAU * frac, ring_col, 2.2)
	if not show_key:
		return
	# Клавиша: тёмная пилюля с тонкой рамкой цвета навыка.
	var sb := StyleBoxFlat.new()
	sb.bg_color = Color(0.03, 0.05, 0.09, 0.8)
	sb.set_corner_radius_all(7)
	sb.set_border_width_all(1)
	sb.border_color = Color(accent.r, accent.g, accent.b, 0.45)
	draw_style_box(sb, _key_rect())
