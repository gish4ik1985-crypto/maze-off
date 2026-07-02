extends RefCounted
class_name SkillIcons

# Статическая фабрика пиктограмм активных навыков для HUD (и где угодно).
# Рисунки совпадают со стилем меню навыков (skills_menu.gd). Возвращает ImageTexture.

const COLORS := {
	"flash":  Color(1.00, 0.88, 0.15),
	"dash":   Color(0.30, 0.65, 1.00),
	"sonar":  Color(0.30, 0.92, 1.00),
	"shield": Color(0.45, 0.72, 1.00),
	"guide":  Color(1.00, 0.58, 0.18),
	"reveal": Color(0.95, 0.95, 1.00),
	"apex":   Color(1.00, 0.20, 0.30),
	"smother": Color(0.60, 0.50, 0.85),   # Тление — приглушённый фиолет
	"mirage":  Color(0.80, 0.70, 1.00),   # дары боссов
	"breach":  Color(1.00, 0.55, 0.30),
	"chrono":  Color(0.40, 0.95, 0.90),
}

static func color_of(skill_id: String) -> Color:
	return COLORS.get(skill_id, Color.WHITE)

static func make(skill_id: String, size: int) -> ImageTexture:
	var img := Image.create_empty(size, size, false, Image.FORMAT_RGBA8)
	var col: Color = COLORS.get(skill_id, Color.WHITE)
	_bg_circle(img, size, col)
	match skill_id:
		"flash":  _star(img, size, col, 8)
		"dash":   _arrow(img, size, col)
		"sonar":  _rings(img, size, col)
		"shield": _shield(img, size, col)
		"guide":  _flame(img, size, col)
		"reveal": _eye(img, size, col)
		"apex":   _apex(img, size, col)
		"smother": _star(img, size, col, 4)   # тусклая 4-лучевая искра-уголёк
		"mirage":  _eye(img, size, col)
		"breach":  _arrow(img, size, col)
		"chrono":  _rings(img, size, col)
		_:        _star(img, size, col, 6)
	return ImageTexture.create_from_image(img)

static func _bg_circle(img: Image, size: int, col: Color) -> void:
	var cx := size * 0.5; var cy := size * 0.5; var r := size * 0.5 - 1.0
	for y in size:
		for x in size:
			var d := Vector2(x - cx + 0.5, y - cy + 0.5).length()
			if d < r:
				var edge := clampf(1.0 - maxf(0.0, d - (r - 2.0)) / 2.0, 0.0, 1.0)
				img.set_pixel(x, y, Color(col.r * 0.16, col.g * 0.16, col.b * 0.16, edge))

static func _px(img: Image, x: int, y: int, c: Color) -> void:
	if x >= 0 and x < img.get_width() and y >= 0 and y < img.get_height():
		var bg := img.get_pixel(x, y)
		img.set_pixel(x, y, Color(
			lerpf(bg.r, c.r, c.a), lerpf(bg.g, c.g, c.a),
			lerpf(bg.b, c.b, c.a), maxf(bg.a, c.a)))

static func _line(img: Image, x0: int, y0: int, x1: int, y1: int, c: Color, w: int = 1) -> void:
	var dx := absi(x1 - x0); var dy := absi(y1 - y0)
	var sx := 1 if x0 < x1 else -1; var sy := 1 if y0 < y1 else -1
	var err := dx - dy; var x := x0; var y := y0
	while true:
		for oy in range(-w, w + 1):
			for ox in range(-w, w + 1):
				_px(img, x + ox, y + oy, c)
		if x == x1 and y == y1: break
		var e2 := 2 * err
		if e2 > -dy: err -= dy; x += sx
		if e2 < dx:  err += dx; y += sy

static func _star(img: Image, size: int, col: Color, pts: int) -> void:
	var cx := size * 0.5; var cy := size * 0.5
	var ro := size * 0.36; var ri := size * 0.15
	for i in pts:
		var ao := TAU * i / pts - PI * 0.5
		var ai := ao + TAU / (pts * 2)
		var an := ao + TAU / pts
		_line(img, int(cx), int(cy), int(cx + cos(ao)*ro), int(cy + sin(ao)*ro), col, 1)
		_line(img, int(cx + cos(ao)*ro), int(cy + sin(ao)*ro), int(cx + cos(ai)*ri), int(cy + sin(ai)*ri), col, 1)
		_line(img, int(cx + cos(ai)*ri), int(cy + sin(ai)*ri), int(cx + cos(an)*ro), int(cy + sin(an)*ro), col, 1)

static func _arrow(img: Image, size: int, col: Color) -> void:
	var m := size / 2; var l := size / 6; var r := size * 5 / 6
	_line(img, l, m, r, m, col, 2)
	_line(img, r, m, int(r - size * 0.22), int(m - size * 0.22), col, 2)
	_line(img, r, m, int(r - size * 0.22), int(m + size * 0.22), col, 2)

static func _rings(img: Image, size: int, col: Color) -> void:
	var cx := size * 0.5; var cy := size * 0.5
	for ri_f: float in [0.13, 0.24, 0.37]:
		var rad: float = size * ri_f
		for deg in 360:
			var a := deg_to_rad(float(deg))
			var x := int(cx + cos(a) * rad); var y := int(cy + sin(a) * rad)
			_px(img, x, y, col); _px(img, x+1, y, col)

static func _shield(img: Image, size: int, col: Color) -> void:
	var cx := size / 2; var t := size / 6; var b := size * 5 / 6; var hw := size * 3 / 8
	_line(img, cx - hw, t, cx + hw, t, col, 1)
	_line(img, cx - hw, t, cx - hw, size / 2, col, 1)
	_line(img, cx + hw, t, cx + hw, size / 2, col, 1)
	_line(img, cx - hw, size / 2, cx, b, col, 1)
	_line(img, cx + hw, size / 2, cx, b, col, 1)
	_line(img, cx - hw + 4, t + 4, cx + hw - 4, t + 4, Color(col.r, col.g, col.b, 0.45), 1)

static func _flame(img: Image, size: int, col: Color) -> void:
	var cx := size * 0.5
	for y in size:
		for x in size:
			var fx := float(x) - cx; var fy := float(y) - size * 0.18
			var d := (fx*fx) / pow(size*0.14, 2) + (fy*fy) / pow(size*0.34, 2)
			if d < 1.0:
				_px(img, x, y, Color(col.r, col.g, col.b, clampf(1.2 - d, 0.0, 1.0)))

static func _eye(img: Image, size: int, col: Color) -> void:
	var cx := size * 0.5; var cy := size * 0.5
	for deg in 360:
		var a := deg_to_rad(float(deg))
		var x := int(cx + cos(a) * size * 0.36); var y := int(cy + sin(a) * size * 0.20)
		_px(img, x, y, col); _px(img, x+1, y, col)
	for y in size:
		for x in size:
			if Vector2(x - cx + 0.5, y - cy + 0.5).length() < size * 0.10:
				_px(img, x, y, col)

static func _apex(img: Image, size: int, col: Color) -> void:
	var cx := size * 0.5; var cy := size * 0.5
	for deg in 360:
		var a := deg_to_rad(float(deg))
		_px(img, int(cx + cos(a) * size * 0.40), int(cy + sin(a) * size * 0.40), col)
	_star(img, size, col, 5)
