extends Node2D

# [GAMEDESIGN §32 «Награда в моменте»] Всплывающая надпись на месте события:
# «+94 XP» у подобранного осколка, «+30 XP» у убитого врага и т.п.
#
# Зачем: до этого ВСЯ награда игры (XP, SP, ранг, множители) раскрывалась
# только в МЕНЮ и на экране результатов — то есть после того, как момент уже
# прошёл. В самом действии игрок не получал никакого подтверждения, что оно
# что-то стоило, и сбор осколков ощущался как обязанность, а не как награда.
#
# Самоудаляющийся эффект в стиле проекта: параметры выставляются ДО add_child.

var text: String = ""
var color: Color = Color(1.0, 0.9, 0.5)
var dur: float = 1.15
var rise: float = 46.0          # на сколько пикселей поднимется за жизнь
var font_size: int = 16

var _t: float = 0.0
var _label: Label
var _y0: float = 0.0

func _ready() -> void:
	z_index = 60
	_y0 = position.y
	_label = Label.new()
	_label.text = text
	_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_label.add_theme_font_size_override("font_size", font_size)
	_label.add_theme_color_override("font_color", color)
	# Обводка обязательна: надпись всплывает поверх тёмного пола И поверх
	# светлых стен рядом с игроком, без контура читается только на одном из них.
	_label.add_theme_color_override("font_outline_color", Color(0.02, 0.02, 0.05, 0.9))
	_label.add_theme_constant_override("outline_size", 5)
	# Центрируем надпись по точке события: ширина фиксированная, текст по центру.
	_label.custom_minimum_size = Vector2(160, 0)
	_label.position = Vector2(-80, -10)
	add_child(_label)

func _process(delta: float) -> void:
	_t += delta
	var k: float = clampf(_t / dur, 0.0, 1.0)
	# Подъём с замедлением: быстро отрывается от места и мягко останавливается.
	position.y = _y0 - rise * ease(k, 0.4)
	if _label:
		# Первые 15% жизни — проявление, дальше плавное угасание: мгновенно
		# появившийся текст рядом с золотым всплеском осколка теряется.
		var a: float = clampf(k / 0.15, 0.0, 1.0) if k < 0.15 else (1.0 - (k - 0.15) / 0.85)
		_label.modulate.a = clampf(a, 0.0, 1.0)
	if _t >= dur:
		queue_free()
