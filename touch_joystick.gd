extends Control

# Динамический виртуальный джойстик: касание в левой половине экрана задаёт
# центр, перетаскивание — направление. Результат в output (Vector2, -1..1).

const RADIUS := 110.0

var output: Vector2 = Vector2.ZERO
var allow_mouse: bool = false   # тест на ПК: левая кнопка мыши тоже ведёт джойстик

var _touch_id: int = -1
var _origin: Vector2 = Vector2.ZERO
var _knob: Vector2 = Vector2.ZERO

func _ready() -> void:
	set_anchors_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_IGNORE

func _input(event: InputEvent) -> void:
	if allow_mouse and event.device != InputEvent.DEVICE_ID_EMULATION:
		if event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT:
			if event.pressed:
				if _touch_id == -1 and event.position.x < get_viewport_rect().size.x * 0.5:
					_touch_id = 99
					_origin = event.position
					_knob = event.position
					queue_redraw()
			elif _touch_id == 99:
				_touch_id = -1
				output = Vector2.ZERO
				queue_redraw()
			return
		if event is InputEventMouseMotion and _touch_id == 99:
			var moff: Vector2 = event.position - _origin
			if moff.length() > RADIUS:
				moff = moff.normalized() * RADIUS
			_knob = _origin + moff
			output = moff / RADIUS
			queue_redraw()
			return
	if event is InputEventScreenTouch:
		if event.pressed:
			if _touch_id == -1 and event.position.x < get_viewport_rect().size.x * 0.5:
				_touch_id = event.index
				_origin = event.position
				_knob = event.position
				queue_redraw()
		elif event.index == _touch_id:
			_touch_id = -1
			output = Vector2.ZERO
			queue_redraw()
	elif event is InputEventScreenDrag and event.index == _touch_id:
		var off: Vector2 = event.position - _origin
		if off.length() > RADIUS:
			off = off.normalized() * RADIUS
		_knob = _origin + off
		output = off / RADIUS
		queue_redraw()

func _draw() -> void:
	if _touch_id == -1:
		return
	var neon := Color(0.45, 0.85, 1.0)
	draw_circle(_origin, RADIUS, Color(neon.r, neon.g, neon.b, 0.07))
	draw_arc(_origin, RADIUS, 0.0, TAU, 64, Color(neon.r, neon.g, neon.b, 0.12), 8.0, true)
	draw_arc(_origin, RADIUS, 0.0, TAU, 64, Color(neon.r, neon.g, neon.b, 0.55), 2.5, true)
	draw_circle(_knob, 34.0, Color(neon.r, neon.g, neon.b, 0.18))
	draw_arc(_knob, 34.0, 0.0, TAU, 40, Color(neon.r, neon.g, neon.b, 0.85), 2.5, true)
