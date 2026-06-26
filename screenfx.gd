extends CanvasLayer

# Экранные эффекты «сочности» (в духе Super Meat Boy):
#  • золотая виньетка по краям при получении энергии (импульс при подборе
#    осколка + мягкое «дыхание», пока заряжаешься на станции);
#  • красная тревожная виньетка, нарастающая на низком свете;
#  • полноэкранные вспышки при подборе/уроне/победе.
# Тряску камеры делает сам игрок (player.add_shake) — у него камера.

const GOLD := Color(1.0, 0.82, 0.38)
const RED := Color(1.0, 0.25, 0.2)

var _shader: Shader
var _gold_mat: ShaderMaterial
var _danger_mat: ShaderMaterial
var _flash: ColorRect

var _gold_pulse: float = 0.0      # импульс золота (гаснет сам)
var _gold_sustain: float = 0.0    # цель «заряда» (ставится снаружи каждый кадр)
var _gold_sustain_s: float = 0.0  # сглаженное значение
var _danger_level: float = 0.0    # цель тревоги (ставится снаружи)
var _danger_s: float = 0.0        # сглаженная тревога
var _danger_pulse: float = 0.0    # короткий всплеск тревоги (удар врага)
var _flash_a: float = 0.0
var _t: float = 0.0

func _ready() -> void:
	layer = 3  # поверх мира и HUD
	_shader = load("res://vignette.gdshader")

	_gold_mat = _make_mat(GOLD, 0.45)
	_danger_mat = _make_mat(RED, 0.32)
	_make_rect(_gold_mat)
	_make_rect(_danger_mat)

	_flash = ColorRect.new()
	_flash.set_anchors_preset(Control.PRESET_FULL_RECT)
	_flash.color = Color(1, 1, 1, 0)
	_flash.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(_flash)

	get_viewport().size_changed.connect(_update_aspect)
	_update_aspect()

func _make_mat(c: Color, inner: float) -> ShaderMaterial:
	var m := ShaderMaterial.new()
	m.shader = _shader
	m.set_shader_parameter("tint", c)
	m.set_shader_parameter("intensity", 0.0)
	m.set_shader_parameter("inner", inner)
	return m

func _make_rect(mat: ShaderMaterial) -> void:
	var r := ColorRect.new()
	r.set_anchors_preset(Control.PRESET_FULL_RECT)
	r.mouse_filter = Control.MOUSE_FILTER_IGNORE
	r.material = mat
	add_child(r)

func _update_aspect() -> void:
	var s := get_viewport().get_visible_rect().size
	var a: float = (s.x / s.y) if s.y > 0.0 else 1.777
	_gold_mat.set_shader_parameter("aspect", a)
	_danger_mat.set_shader_parameter("aspect", a)

# --- Публичный интерфейс (вызывается из main.gd) ---

# Короткий золотой всплеск по краям (подбор осколка, победа и т.п.)
func gold_pulse(strength: float) -> void:
	_gold_pulse = maxf(_gold_pulse, strength)

# Уровень «заряда» 0..1 — мягкое золотое свечение, пока идёт зарядка
func set_charge(level: float) -> void:
	_gold_sustain = clampf(level, 0.0, 1.0)

# Уровень тревоги 0..1 — красная пульсирующая виньетка на низком свете
func set_danger(level: float) -> void:
	_danger_level = clampf(level, 0.0, 1.0)

# Короткий красный всплеск по углам (удар врага)
func danger_pulse(strength: float) -> void:
	_danger_pulse = maxf(_danger_pulse, strength)

# Полноэкранная вспышка заданного цвета, которая быстро гаснет
func flash(color: Color, strength: float) -> void:
	var a := clampf(strength, 0.0, 1.0)
	_flash.color = Color(color.r, color.g, color.b, a)
	_flash_a = a

func _process(delta: float) -> void:
	_t += delta

	# Золото: импульс гаснет; плюс сглаженный «заряд» с лёгким дыханием
	_gold_pulse = lerpf(_gold_pulse, 0.0, 1.0 - exp(-6.0 * delta))
	_gold_sustain_s = lerpf(_gold_sustain_s, _gold_sustain, 1.0 - exp(-5.0 * delta))
	var gbreathe: float = 0.8 + 0.2 * sin(_t * 5.0)
	_gold_mat.set_shader_parameter("intensity", _gold_pulse + _gold_sustain_s * 0.6 * gbreathe)

	# Тревога: плавно следует за уровнем, пульсирует; плюс короткий всплеск от удара
	_danger_s = lerpf(_danger_s, _danger_level, 1.0 - exp(-4.0 * delta))
	_danger_pulse = lerpf(_danger_pulse, 0.0, 1.0 - exp(-5.5 * delta))
	var dbreathe: float = 0.75 + 0.25 * sin(_t * 7.0)
	_danger_mat.set_shader_parameter("intensity", _danger_s * 1.2 * dbreathe + _danger_pulse * 1.6)

	# Вспышка гаснет
	_flash_a = lerpf(_flash_a, 0.0, 1.0 - exp(-6.5 * delta))
	_flash.color.a = _flash_a
