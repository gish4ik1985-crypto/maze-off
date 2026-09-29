class_name HudStance
extends Control

## Стойка света (Z / X / колесо): три светящихся «пилюли», горит выбранная
## (GAMEDESIGN §29). Цвет — цвет стойки (Тусклая / Ровная / Яркая).

var idx: int = 1
var col: Color = Color(1.0, 0.85, 0.3)

func _ready() -> void:
	custom_minimum_size = Vector2(50, 14)
	size = Vector2(50, 14)
	mouse_filter = Control.MOUSE_FILTER_IGNORE

func _draw() -> void:
	for i in 3:
		var r := Rect2(float(i) * 17.0, 4.0, 14.0, 6.0)
		var sb := StyleBoxFlat.new()
		sb.set_corner_radius_all(3)
		if i == idx:
			sb.bg_color = col
			sb.shadow_color = Color(col.r, col.g, col.b, 0.55)
			sb.shadow_size = 5
		else:
			sb.bg_color = Color(col.r, col.g, col.b, 0.16)
		draw_style_box(sb, r)
