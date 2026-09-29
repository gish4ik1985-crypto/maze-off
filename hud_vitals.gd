class_name HudVitals
extends Control

## Орб жизненных сил (HUD «Фонарь», v6.0). Внешнее кольцо — Свет (это и есть жизнь),
## внутреннее — Воля (топливо навыков), в центре — лампа: чем меньше Света, тем
## она тусклее. Ниже трети Света дуга и лампа краснеют и пульсируют — тот же
## порог, что у красной кромки экрана (main.gd, LOW_LIGHT_THRESHOLD).
## Рисуется кодом в том же неоновом языке, что HudIcon: три прохода свечения.

const SWEEP := TAU             # полное кольцо: без разрыва (разрыв читался тёмным «клином»)
const A0 := -PI * 0.5          # старт сверху, идём по часовой
const LOW := 0.3               # порог тревоги (доля Света)
const LIGHT_COL := Color(1.0, 0.85, 0.3)
const LOW_COL := Color(0.95, 0.18, 0.18)
const WILL_COL := Color(0.3, 0.9, 0.95)

var light: float = 1.0         # цель 0..1 — выставляет main.gd
var will: float = 1.0
var _light_v: float = 1.0      # то, что нарисовано: плавно догоняет цель
var _will_v: float = 1.0
var _t: float = 0.0
var _glow: Texture2D

func _ready() -> void:
	custom_minimum_size = Vector2(68, 68)
	size = Vector2(68, 68)
	mouse_filter = Control.MOUSE_FILTER_STOP
	_glow = MazeTextures.make_light(64)

# Мгновенно выставить нарисованные значения (иллюстрации в Кодексе).
func snap() -> void:
	_light_v = light
	_will_v = will
	queue_redraw()

func _process(delta: float) -> void:
	_t += delta
	var k := 1.0 - exp(-delta * 9.0)
	var lv := lerpf(_light_v, light, k)
	var wv := lerpf(_will_v, will, k)
	var moved := absf(lv - _light_v) > 0.0004 or absf(wv - _will_v) > 0.0004
	_light_v = lv
	_will_v = wv
	# В тревоге лампа пульсирует — перерисовываем каждый кадр; иначе только при сдвиге.
	if moved or _light_v < LOW:
		queue_redraw()

func _arc_glow(c: Vector2, radius: float, frac: float, col: Color, w: float) -> void:
	if frac <= 0.002:
		return
	var a1 := A0 + SWEEP * clampf(frac, 0.0, 1.0)
	draw_arc(c, radius, A0, a1, 40, Color(col.r, col.g, col.b, 0.05), w * 2.4, true)
	draw_arc(c, radius, A0, a1, 40, Color(col.r, col.g, col.b, 0.15), w * 1.6, true)
	draw_arc(c, radius, A0, a1, 40, col, w, true)
	# яркая «бусина» на конце дуги — по ней уровень читается мгновенно (у полной
	# шкалы конец и так упирается в край, там она только мешает)
	if frac < 0.985:
		var tip := c + Vector2(cos(a1), sin(a1)) * radius
		draw_circle(tip, w * 0.7, Color(1, 1, 1, 0.85))

func _draw() -> void:
	var c := size * 0.5
	var low := clampf(1.0 - _light_v / LOW, 0.0, 1.0)
	var pulse := 0.5 + 0.5 * sin(_t * 7.0)
	var lc := LIGHT_COL.lerp(LOW_COL, low)
	# подложка: тёмное стекло с тонким ободком
	draw_circle(c, 33.0, Color(0.02, 0.03, 0.06, 0.66))
	draw_arc(c, 32.4, 0.0, TAU, 64, Color(0.45, 0.6, 0.9, 0.22), 1.2, true)
	# мягкий свет внутри стекла
	draw_texture_rect(_glow, Rect2(c - Vector2(31, 31), Vector2(62, 62)), false,
		Color(lc.r, lc.g, lc.b, 0.10 + 0.12 * _light_v))
	# треки (пустые части дуг)
	draw_arc(c, 26.0, A0, A0 + SWEEP, 40, Color(0.14, 0.17, 0.25, 0.9), 5.0, true)
	draw_arc(c, 19.0, A0, A0 + SWEEP, 40, Color(0.12, 0.17, 0.2, 0.9), 3.0, true)
	# заполнение: Свет снаружи, Воля внутри
	_arc_glow(c, 26.0, _light_v, lc, 5.0)
	_arc_glow(c, 19.0, _will_v, WILL_COL, 3.0)
	# лампа в центре: яркость и размер = остаток Света, в тревоге — пульс
	var k := 0.25 + 0.75 * _light_v
	var rr := 8.0 + 8.0 * k + 3.0 * pulse * low
	draw_texture_rect(_glow, Rect2(c - Vector2(rr, rr), Vector2(rr, rr) * 2.0), false,
		Color(lc.r, lc.g, lc.b, 0.9 * k))
	draw_circle(c, 2.6 + 2.2 * k, Color(1.0, 1.0, 0.92, 0.35 + 0.65 * k))
