extends Control

# Динамический виртуальный джойстик: касание в левой половине экрана задаёт
# центр, перетаскивание — направление. Результат в output (Vector2, -1..1).

const RADIUS := 110.0

var output: Vector2 = Vector2.ZERO

var _touch_id: int = -1
var _origin: Vector2 = Vector2.ZERO
var _knob: Vector2 = Vector2.ZERO

func _ready() -> void:
	set_anchors_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_IGNORE

func _input(event: InputEvent) -> void:
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
		var off := event.position - _origin
		if off.length() > RADIUS:
			off = off.normalized() * RADIUS
		_knob = _origin + off
		output = off / RADIUS
		queue_redraw()

func _draw() -> void:
	if _touch_id == -1:
		return
	draw_circle(_origin, RADIUS, Color(1, 1, 1, 0.10))
	draw_arc(_origin, RADIUS, 0.0, TAU, 48, Color(1, 1, 1, 0.30), 3.0)
	draw_circle(_knob, 34.0, Color(1, 1, 1, 0.35))
