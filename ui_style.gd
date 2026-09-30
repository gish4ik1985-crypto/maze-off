extends RefCounted
class_name UIStyle

# Единая неоновая стилистика кнопок — общая для ВСЕХ экранов (главное меню,
# пауза, экран результатов, магазин навыков, алтарь Накала, любые диалоги).
# Раньше каждый экран красил кнопки по-своему (или не красил вовсе — обычные
# серые кнопки Godot по умолчанию в паузе/магазине/алтаре/окне «О версиях»,
# отсюда жалоба «кнопки не совпадают со стилем»). Теперь любой новый Button
# должен пройти через style_button() (или make_button()) — единственный
# источник правды для внешнего вида кнопок.

const PANEL_BG := Color(0.045, 0.06, 0.11, 0.94)      # фон тёмных панелей/диалогов
const PANEL_BORDER := Color(0.3, 0.5, 0.8, 0.55)      # рамка тёмных панелей/диалогов

static func style_button(b: Button) -> void:
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
	# Живой отклик: кнопка слегка «дышит» под курсором (масштаб 1.03).
	# Внутри ScrollContainer масштаб не применяем — тот клипует содержимое,
	# и увеличенная кнопка «обрезается» краем.
	b.mouse_entered.connect(func() -> void:
		if _inside_scroll(b) or GameConfig.touch_ui():   # на касании «дыхание» залипает
			return
		b.pivot_offset = b.size * 0.5
		var tw := b.create_tween()
		tw.tween_property(b, "scale", Vector2(1.03, 1.03), 0.12) \
			.set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT))
	b.mouse_exited.connect(func() -> void:
		if b.scale == Vector2.ONE:
			return
		var tw := b.create_tween()
		tw.tween_property(b, "scale", Vector2.ONE, 0.12) \
			.set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT))

static func _inside_scroll(n: Node) -> bool:
	var p := n.get_parent()
	while p != null:
		if p is ScrollContainer:
			return true
		p = p.get_parent()
	return false

# Кнопка «под ключ»: текст + размер + шрифт + стандартная стилистика + колбэк.
static func make_button(text: String, on_pressed: Callable, w: float = 300, h: float = 50, font_size: int = 24) -> Button:
	var b := Button.new()
	b.text = text
	# Палец крупнее курсора: на сенсорном интерфейсе кнопка не ниже 54.
	if GameConfig.touch_ui():
		h = maxf(h, 54.0)
	b.custom_minimum_size = Vector2(w, h)
	b.add_theme_font_size_override("font_size", font_size)
	if on_pressed.is_valid():
		b.pressed.connect(on_pressed)
	style_button(b)
	return b

# Тёмная панель с рамкой — фон для диалогов/оверлеев (О версиях, попапы и т.п.),
# та же стилистика, что у карточек навыков/алтаря/уровней.
static func panel_stylebox(border: Color = PANEL_BORDER) -> StyleBoxFlat:
	var sb := StyleBoxFlat.new()
	sb.bg_color = PANEL_BG
	sb.set_corner_radius_all(12)
	sb.set_border_width_all(2)
	sb.border_color = border
	sb.content_margin_left = 20
	sb.content_margin_right = 20
	sb.content_margin_top = 16
	sb.content_margin_bottom = 16
	return sb
