extends Control
class_name SkillHudIcon

# HUD-иконка навыка: пиктограмма (как в меню навыков) + keycap снизу + кольцо
# перезарядки вокруг пиктограммы (как шкала восстановления у станции).

const ICON_D := 24.0      # диаметр пиктограммы
const RING_R := 14.0      # радиус кольца перезарядки

var icon_tex: Texture2D
var accent: Color = Color.WHITE
var ready_frac: float = 1.0   # 1 = готов; <1 = доля до готовности (кольцо заполняется)
var low_energy: bool = false  # не хватает света — иконка краснеет
var glow_pulse: bool = false  # пульс готового заряда (Озарение)

var _key_label: Label
var _center := Vector2(16, 15)
var _pulse_t: float = 0.0

func _ready() -> void:
	custom_minimum_size = Vector2(32, 42)
	size = Vector2(32, 42)
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	_key_label = Label.new()
	_key_label.add_theme_font_size_override("font_size", 10)
	_key_label.add_theme_color_override("font_color", Color(0.85, 0.93, 1.0))
	_key_label.add_theme_constant_override("outline_size", 3)
	_key_label.add_theme_color_override("font_outline_color", Color(0, 0, 0, 0.8))
	_key_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_key_label.position = Vector2(-4, 30)
	_key_label.size = Vector2(40, 12)
	_key_label.custom_minimum_size = Vector2(40, 12)
	_key_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(_key_label)

func _process(delta: float) -> void:
	if glow_pulse:
		_pulse_t += delta
		queue_redraw()

func set_key(t: String) -> void:
	if _key_label:
		_key_label.text = t

func _draw() -> void:
	var frac := clampf(ready_frac, 0.0, 1.0)
	# Тусклое фоновое кольцо
	draw_arc(_center, RING_R, 0.0, TAU, 48, Color(0.22, 0.27, 0.34, 0.7), 3.0, true)
	# Пиктограмма (тускнеет на кулдауне / краснеет при нехватке света)
	if icon_tex:
		var mod := Color(1, 1, 1, 1)
		if frac < 0.999:
			mod = Color(0.5, 0.5, 0.56, 1.0)
		elif low_energy:
			mod = Color(0.95, 0.6, 0.55, 1.0)
		draw_texture_rect(icon_tex,
			Rect2(_center - Vector2(ICON_D * 0.5, ICON_D * 0.5), Vector2(ICON_D, ICON_D)),
			false, mod)
	# Кольцо готовности: на кулдауне — дуга от верха по часовой; готов — полное кольцо
	var ring_col := Color(accent.r, accent.g, accent.b, 0.95)
	if frac >= 0.999:
		if glow_pulse:
			var p: float = 0.55 + 0.45 * sin(_pulse_t * 4.5)
			ring_col = Color(accent.r, accent.g, accent.b, 0.5 + 0.5 * p)
		draw_arc(_center, RING_R, 0.0, TAU, 48, ring_col, 3.0, true)
	else:
		draw_arc(_center, RING_R, -PI * 0.5, -PI * 0.5 + TAU * frac, 48, ring_col, 3.0, true)
