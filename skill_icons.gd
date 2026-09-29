extends RefCounted
class_name SkillIcons

# Фабрика пиктограмм навыков (HUD, меню навыков, реликвии, алтарь).
#
# [v6.0] Переписана целиком. Раньше глифы рисовались попиксельными линиями
# квадратной кисточкой и выходили «квадратными и пиксельными»; к тому же пять
# разных навыков делили один и тот же рисунок колец. Теперь:
#   • у каждого навыка свой глиф, нарисованный в единичных координатах (−1..1);
#   • рисуем в 4× разрешении круглой кистью и сжимаем Lanczos'ом — гладкие линии;
#   • неоновая нить: цветной контур + светлая сердцевина + мягкое свечение
#     (размытие — обычным ресайзом, то есть силами движка, а не циклом по пикселям);
#   • «бусина»: тёмный стеклянный диск с ободком и бликом.
# Приглушённые детали рисуются не альфой, а цветом, смешанным с фоном диска:
# повторные штампы кисти с альфой копились бы и темнели в местах перекрытия.
# Результат кэшируется по (навык, размер): меню перестраиваются часто.

const COLORS := {
	"flash":  Color(1.00, 0.88, 0.15),
	"dash":   Color(0.30, 0.65, 1.00),
	"sonar":  Color(0.30, 0.92, 1.00),
	"shield": Color(0.45, 0.72, 1.00),
	"guide":  Color(1.00, 0.58, 0.18),
	"reveal": Color(0.95, 0.95, 1.00),
	"pulse":  Color(1.00, 0.62, 0.85),
	"apex":   Color(1.00, 0.20, 0.30),
	"smother": Color(0.60, 0.50, 0.85),   # Тление — приглушённый фиолет
	"mirage":  Color(0.80, 0.70, 1.00),   # дары боссов
	"breach":  Color(1.00, 0.55, 0.30),
	"chrono":  Color(0.40, 0.95, 0.90),
	"mark":    Color(1.00, 0.55, 0.15),   # Горящая метка — тёплый огонёк, как у самой метки в мире
	# Пассивки (ветви колеса Апекса)
	"save":     Color(0.25, 0.92, 0.42),
	"capacity": Color(0.72, 0.38, 1.00),
	"charge":   Color(1.00, 0.90, 0.18),
	"range":    Color(1.00, 0.48, 0.28),
	"legs":     Color(0.25, 0.90, 0.72),
	"magic":    Color(1.00, 0.38, 0.82),
	"deceit":   Color(0.85, 0.65, 1.00),
	"crush":    Color(1.00, 0.60, 0.25),
	"stasis":   Color(0.45, 0.90, 0.95),
	"echo":     Color(1.00, 0.62, 0.85),
	# Товары алтаря Накала
	"life":     Color(1.00, 0.42, 0.52),
	"light":    Color(1.00, 0.86, 0.35),
	"star":     Color(1.00, 0.84, 0.30),
}

const SS := 4            # суперсэмплинг: рисуем в 4× и сжимаем
const GLYPH_R := 0.29    # радиус глифа (доля стороны иконки): глиф вписан в «бусину»
const W := 0.15          # основная толщина нити (доля радиуса глифа)

static var _cache: Dictionary = {}
static var _brushes: Dictionary = {}

static func color_of(skill_id: String) -> Color:
	return COLORS.get(skill_id, Color.WHITE)

# Иконки рисуются одним конвейером на любой размер; make_hd оставлен ради
# прежних вызовов (раньше он отличался только суперсэмплингом).
static func make_hd(skill_id: String, size: int) -> ImageTexture:
	return make(skill_id, size)

static func make(skill_id: String, size: int) -> ImageTexture:
	var key := "%s:%d" % [skill_id, size]
	if _cache.has(key):
		return _cache[key]
	var tex := _render(skill_id, size)
	_cache[key] = tex
	return tex

# Глиф без «бусины»: светящаяся неоновая нить на прозрачном фоне (сердца-жизни
# в HUD и т.п.). Окрашивается modulate'ом.
static func make_glyph(skill_id: String, size: int) -> ImageTexture:
	var key := "g:%s:%d" % [skill_id, size]
	if _cache.has(key):
		return _cache[key]
	var tex := _render(skill_id, size, false)
	_cache[key] = tex
	return tex

# ── Холст: единичные координаты, круглая кисть, два слоя (цвет + светлая нить) ──
class _Canvas:
	var n: int
	var r: float
	var accent: Color
	var bg: Color
	var hot_col: Color
	var main: Image
	var hot: Image
	var wscale: float = 1.0

	func _init(px: int, col: Color, glyph_r: float = SkillIcons.GLYPH_R) -> void:
		n = px
		r = px * glyph_r
		accent = col
		bg = Color(col.r * 0.10, col.g * 0.10, col.b * 0.10)
		hot_col = col.lerp(Color.WHITE, 0.72)
		main = Image.create_empty(px, px, false, Image.FORMAT_RGBA8)
		main.fill(Color(col.r, col.g, col.b, 0.0))
		hot = Image.create_empty(px, px, false, Image.FORMAT_RGBA8)
		hot.fill(Color(hot_col.r, hot_col.g, hot_col.b, 0.0))

	func pt(u: Vector2) -> Vector2:
		return Vector2(n * 0.5, n * 0.5) + u * r

	# Приглушённый тон: смесь с цветом диска вместо альфы (см. шапку файла).
	func tone(a: float) -> Color:
		return bg.lerp(accent, clampf(a, 0.0, 1.0))

	func _stamp(img: Image, col: Color, d: int, p: Vector2) -> void:
		var b: Image = SkillIcons._brush(d, col)
		img.blend_rect(b, Rect2i(0, 0, d, d), Vector2i(int(roundf(p.x - d * 0.5)), int(roundf(p.y - d * 0.5))))

	func stroke(us: PackedVector2Array, w: float, a: float = 1.0, closed: bool = false) -> void:
		var d: int = maxi(2, int(roundf(w * r * wscale)))
		var hd: int = maxi(2, int(roundf(d * 0.42)))
		var col := tone(a)
		var lit := a >= 0.85
		var count := us.size()
		var segs := count if closed else count - 1
		for i in segs:
			var p0 := pt(us[i])
			var p1 := pt(us[(i + 1) % count])
			var seg_len := p0.distance_to(p1)
			var steps := maxi(1, int(ceilf(seg_len / (d * 0.3))))
			for s in steps + 1:
				var p := p0.lerp(p1, float(s) / float(steps))
				_stamp(main, col, d, p)
				if lit:
					_stamp(hot, hot_col, hd, p)

	func line(a: Vector2, b: Vector2, w: float, al: float = 1.0) -> void:
		stroke(PackedVector2Array([a, b]), w, al)

	func arc(c: Vector2, rad: float, a0: float, a1: float, w: float, al: float = 1.0) -> void:
		var segs := maxi(6, int(ceilf(absf(a1 - a0) / 0.10)))
		var pts := PackedVector2Array()
		for i in segs + 1:
			var ang := lerpf(a0, a1, float(i) / float(segs))
			pts.append(c + Vector2(cos(ang), sin(ang)) * rad)
		stroke(pts, w, al)

	func ring(c: Vector2, rad: float, w: float, al: float = 1.0) -> void:
		arc(c, rad, 0.0, TAU, w, al)

	func dot(c: Vector2, rad: float, al: float = 1.0) -> void:
		var d: int = maxi(2, int(roundf(rad * 2.0 * r)))
		var p := pt(c)
		_stamp(main, tone(al), d, p)
		if al >= 0.85:
			_stamp(hot, hot_col, maxi(2, int(d * 0.5)), p)

	# Заливка многоугольника построчно (в hi-res): полупрозрачный «стеклянный» тон.
	func fill(us: PackedVector2Array, al: float) -> void:
		var col := tone(al)
		var ps := PackedVector2Array()
		for u in us:
			ps.append(pt(u))
		var ymin := INF
		var ymax := -INF
		for p in ps:
			ymin = minf(ymin, p.y)
			ymax = maxf(ymax, p.y)
		for y in range(maxi(0, int(ymin)), mini(n - 1, int(ymax)) + 1):
			var yc := float(y) + 0.5
			var xs: Array[float] = []
			for i in ps.size():
				var a := ps[i]
				var b := ps[(i + 1) % ps.size()]
				if (a.y <= yc and b.y > yc) or (b.y <= yc and a.y > yc):
					xs.append(a.x + (yc - a.y) / (b.y - a.y) * (b.x - a.x))
			xs.sort()
			var k := 0
			while k + 1 < xs.size():
				var x0 := maxi(0, int(roundf(xs[k])))
				var x1 := mini(n, int(roundf(xs[k + 1])))
				if x1 > x0:
					main.fill_rect(Rect2i(x0, y, x1 - x0, 1), col)
				k += 2

static func _brush(d: int, col: Color) -> Image:
	var key := "%d:%d" % [d, col.to_rgba32()]
	if _brushes.has(key):
		return _brushes[key]
	var im := Image.create_empty(d, d, false, Image.FORMAT_RGBA8)
	var rad := d * 0.5
	for y in d:
		for x in d:
			var dist := Vector2(x + 0.5 - rad, y + 0.5 - rad).length()
			var a := clampf(rad - dist + 0.5, 0.0, 1.0)
			if a > 0.0:
				im.set_pixel(x, y, Color(col.r, col.g, col.b, a))
	_brushes[key] = im
	return im

# Сглаживание Catmull-Rom: органичные контуры (пламя, капля, щит) из десятка точек.
static func _smooth(pts: Array, closed: bool, sub: int = 8) -> PackedVector2Array:
	var out := PackedVector2Array()
	var cnt := pts.size()
	var segs := cnt if closed else cnt - 1
	for i in segs:
		var p0: Vector2 = pts[(i - 1 + cnt) % cnt] if (closed or i > 0) else pts[i]
		var p1: Vector2 = pts[i]
		var p2: Vector2 = pts[(i + 1) % cnt]
		var p3: Vector2 = pts[(i + 2) % cnt] if (closed or i + 2 < cnt) else pts[(i + 1) % cnt]
		for s in sub:
			var t := float(s) / float(sub)
			out.append(0.5 * ((2.0 * p1) + (-p0 + p2) * t
				+ (2.0 * p0 - 5.0 * p1 + 4.0 * p2 - p3) * t * t
				+ (-p0 + 3.0 * p1 - 3.0 * p2 + p3) * t * t * t))
	if not closed:
		out.append(pts[cnt - 1])
	return out

static func _bez(a: Vector2, b: Vector2, c: Vector2, steps: int = 16) -> PackedVector2Array:
	var out := PackedVector2Array()
	for i in steps + 1:
		var t := float(i) / float(steps)
		out.append(a.lerp(b, t).lerp(b.lerp(c, t), t))
	return out

# «Бусина»: тёмный стеклянный диск, светлеющий к центру, с тонким ободком и бликом.
static func _disc(img: Image, size: int, col: Color) -> void:
	var c := size * 0.5
	var rad := size * 0.5 - 0.6
	for y in size:
		for x in size:
			var off := Vector2(x + 0.5 - c, y + 0.5 - c)
			var d := off.length()
			var a := clampf(rad - d + 0.5, 0.0, 1.0)
			if a <= 0.0:
				continue
			var t := d / rad
			var k := lerpf(0.24, 0.07, t * t)
			var rim := clampf(1.0 - absf(d - (rad - 1.2)) / 1.4, 0.0, 1.0) * 0.6
			var spec := clampf(1.0 - (off - Vector2(-rad * 0.38, -rad * 0.46)).length() / (rad * 0.50), 0.0, 1.0)
			spec = spec * spec * 0.10
			img.set_pixel(x, y, Color(
				col.r * k + col.r * rim + spec,
				col.g * k + col.g * rim + spec,
				col.b * k + col.b * rim + spec, a * 0.96))

static func _render(id: String, size: int, with_disc: bool = true) -> ImageTexture:
	var col := color_of(id)
	var cv := _Canvas.new(size * SS, col, GLYPH_R if with_disc else 0.4)
	cv.wscale = 1.0 if size >= 48 else (1.22 if size >= 32 else 1.4)
	_glyph(cv, id)
	cv.main.resize(size, size, Image.INTERPOLATE_LANCZOS)
	cv.hot.resize(size, size, Image.INTERPOLATE_LANCZOS)
	var out := Image.create_empty(size, size, false, Image.FORMAT_RGBA8)
	if with_disc:
		_disc(out, size, col)
	# Свечение: размытие силами движка — уменьшить и растянуть обратно.
	# Уменьшаем вдвое за шаг (честное усреднение, без «квадратиков» от прореживания).
	var glow: Image = cv.main.duplicate()
	var gw := size
	while gw > size / 5 + 1 and gw > 4:
		gw = maxi(gw / 2, 4)
		glow.resize(gw, gw, Image.INTERPOLATE_BILINEAR)
	glow.resize(size, size, Image.INTERPOLATE_CUBIC)
	var full := Rect2i(0, 0, size, size)
	out.blend_rect(glow, full, Vector2i.ZERO)
	out.blend_rect(cv.main, full, Vector2i.ZERO)
	out.blend_rect(cv.hot, full, Vector2i.ZERO)
	return ImageTexture.create_from_image(out)

static func _v(x: float, y: float) -> Vector2:
	return Vector2(x, y)

# Пламя: контур по ширине hw(t) — капля с лёгким наклоном языка. Возвращает
# замкнутый контур в единичных координатах, уже сдвинутый и масштабированный.
static func _flame_pts(sc: float, off: Vector2) -> PackedVector2Array:
	var right: Array = []
	var left: Array = []
	var steps := 14
	for i in steps + 1:
		var t := float(i) / float(steps)
		var y := lerpf(-1.0, 0.92, t)
		var hw := 0.62 * sqrt(maxf(0.0, sin(PI * pow(t, 1.55))))
		var lean := 0.14 * sin(t * PI * 1.4) * (1.0 - t)
		right.append(_v(hw + lean, y))
		left.append(_v(-hw + lean, y))
	left.reverse()
	var pts: Array = []
	pts.append_array(right)
	pts.append_array(left.slice(1, left.size() - 1))
	var out := PackedVector2Array()
	for p in pts:
		out.append(p * sc + off)
	return out

static func _star_pts(points: int, ro: float, ri: float, rot: float = -PI * 0.5) -> PackedVector2Array:
	var out := PackedVector2Array()
	for i in points * 2:
		var rr := ro if i % 2 == 0 else ri
		var ang := rot + PI * float(i) / float(points)
		out.append(_v(cos(ang) * rr, sin(ang) * rr))
	return out

static func _glyph(c: _Canvas, id: String) -> void:
	match id:
		"flash":
			c.fill(_star_pts(8, 0.98, 0.30), 0.10)
			c.dot(Vector2.ZERO, 0.25)
			c.ring(Vector2.ZERO, 0.36, W * 0.55, 0.55)
			for i in 8:
				var ang := TAU * float(i) / 8.0 - PI * 0.5
				var dv := _v(cos(ang), sin(ang))
				var big: bool = i % 2 == 0
				c.line(dv * 0.52, dv * (1.0 if big else 0.76), W if big else W * 0.75)
		"dash":
			c.line(_v(-0.62, 0.0), _v(0.56, 0.0), W)
			c.stroke(PackedVector2Array([_v(0.06, -0.58), _v(0.76, 0.0), _v(0.06, 0.58)]), W)
			c.line(_v(-0.98, -0.44), _v(-0.34, -0.44), W * 0.75, 0.6)
			c.line(_v(-0.98, 0.44), _v(-0.34, 0.44), W * 0.75, 0.6)
			c.line(_v(-0.88, -0.22), _v(-0.52, -0.22), W * 0.55, 0.4)
			c.line(_v(-0.88, 0.22), _v(-0.52, 0.22), W * 0.55, 0.4)
		"sonar":
			c.ring(Vector2.ZERO, 0.96, W * 0.6, 0.4)
			c.ring(Vector2.ZERO, 0.62, W * 0.75, 0.7)
			c.line(Vector2.ZERO, _v(0.68, -0.68), W * 0.85)
			c.dot(Vector2.ZERO, 0.14)
			c.dot(_v(-0.34, 0.3), 0.08, 0.9)
			c.dot(_v(0.22, 0.52), 0.06, 0.6)
		"shield":
			var sh := _smooth([_v(-0.72, -0.78), _v(0.0, -0.92), _v(0.72, -0.78), _v(0.72, -0.05),
				_v(0.54, 0.52), _v(0.0, 0.98), _v(-0.54, 0.52), _v(-0.72, -0.05)], true, 8)
			c.fill(sh, 0.24)
			c.stroke(sh, W, 1.0, true)
			var sh2 := PackedVector2Array()
			for p in sh:
				sh2.append(p * 0.58 + _v(0.0, -0.06))
			c.stroke(sh2, W * 0.5, 0.45, true)
			c.line(_v(0.0, -0.5), _v(0.0, 0.5), W * 0.5, 0.5)
		"guide":
			var fo := _flame_pts(1.0, Vector2.ZERO)
			c.fill(fo, 0.22)
			c.stroke(fo, W, 1.0, true)
			var fi := _flame_pts(0.5, _v(0.0, 0.34))
			c.fill(fi, 0.5)
			c.stroke(fi, W * 0.55, 0.85, true)
		"reveal":
			var up := _bez(_v(-0.98, 0.0), _v(0.0, -0.9), _v(0.98, 0.0))
			var dn := _bez(_v(0.98, 0.0), _v(0.0, 0.9), _v(-0.98, 0.0))
			var eye := PackedVector2Array()
			eye.append_array(up)
			eye.append_array(dn)
			c.fill(eye, 0.14)
			c.stroke(eye, W, 1.0, true)
			c.ring(Vector2.ZERO, 0.31, W * 0.85)
			c.dot(Vector2.ZERO, 0.13)
			c.line(_v(0.0, -0.66), _v(0.0, -0.98), W * 0.6, 0.7)
			c.line(_v(-0.42, -0.6), _v(-0.58, -0.86), W * 0.6, 0.55)
			c.line(_v(0.42, -0.6), _v(0.58, -0.86), W * 0.6, 0.55)
		"pulse":
			c.stroke(PackedVector2Array([_v(-1.0, 0.06), _v(-0.56, 0.06), _v(-0.38, -0.5), _v(-0.12, 0.74),
				_v(0.1, -0.44), _v(0.25, 0.06), _v(1.0, 0.06)]), W)
			c.dot(_v(1.0, 0.06), 0.08, 0.6)
		"apex":
			var crown := PackedVector2Array([_v(-0.86, 0.56), _v(-0.86, -0.42), _v(-0.42, 0.08), _v(0.0, -0.82),
				_v(0.42, 0.08), _v(0.86, -0.42), _v(0.86, 0.56)])
			c.fill(crown, 0.22)
			c.stroke(crown, W, 1.0, true)
			c.line(_v(-0.86, 0.8), _v(0.86, 0.8), W * 0.9)
			c.dot(_v(-0.86, -0.42), 0.09)
			c.dot(_v(0.0, -0.82), 0.12)
			c.dot(_v(0.86, -0.42), 0.09)
		"smother":
			var ef := _flame_pts(0.46, _v(0.0, 0.5))
			c.fill(ef, 0.5)
			c.stroke(ef, W * 0.85, 1.0, true)
			c.stroke(_smooth([_v(0.02, -0.02), _v(-0.22, -0.3), _v(0.16, -0.56), _v(-0.12, -0.9)], false, 8), W * 0.6, 0.7)
			c.stroke(_smooth([_v(0.2, 0.0), _v(0.44, -0.24), _v(0.3, -0.5)], false, 8), W * 0.5, 0.42)
		"mirage":
			# Живая фигура и её бледный двойник — «обман» для врагов.
			for k in 2:
				var ox := -0.24 if k == 0 else 0.34
				var al := 1.0 if k == 0 else 0.45
				c.ring(_v(ox, -0.42), 0.24, W * 0.85, al)
				c.arc(_v(ox, 0.78), 0.78, PI * 1.2, PI * 1.8, W, al)
		"breach":
			c.line(_v(-1.0, 0.0), _v(-0.36, 0.0), W * 1.5, 0.55)
			c.line(_v(0.36, 0.0), _v(1.0, 0.0), W * 1.5, 0.55)
			c.stroke(PackedVector2Array([_v(0.1, -0.98), _v(-0.2, -0.5), _v(0.22, -0.16), _v(-0.16, 0.24), _v(0.14, 0.58), _v(-0.06, 0.98)]), W)
			c.dot(_v(-0.62, -0.42), 0.07, 0.85)
			c.dot(_v(0.6, -0.5), 0.05, 0.7)
			c.dot(_v(0.56, 0.46), 0.07, 0.85)
			c.dot(_v(-0.5, 0.56), 0.05, 0.7)
		"chrono":
			c.line(_v(-0.62, -0.92), _v(0.62, -0.92), W)
			c.line(_v(-0.62, 0.92), _v(0.62, 0.92), W)
			var gl := PackedVector2Array([_v(-0.5, -0.92), _v(-0.5, -0.56), _v(-0.08, -0.06), _v(-0.08, 0.06),
				_v(-0.5, 0.56), _v(-0.5, 0.92)])
			var gr := PackedVector2Array()
			for p in gl:
				gr.append(_v(-p.x, p.y))
			c.fill(PackedVector2Array([_v(-0.36, 0.86), _v(0.36, 0.86), _v(0.0, 0.34)]), 0.5)
			c.fill(PackedVector2Array([_v(-0.32, -0.6), _v(0.32, -0.6), _v(0.0, -0.22)]), 0.3)
			c.stroke(gl, W * 0.9)
			c.stroke(gr, W * 0.9)
			c.line(_v(0.0, -0.08), _v(0.0, 0.34), W * 0.4, 0.9)
		"mark":
			var pin := _smooth([_v(0.0, 0.98), _v(-0.42, 0.36), _v(-0.6, -0.12), _v(-0.5, -0.56),
				_v(-0.2, -0.84), _v(0.2, -0.84), _v(0.5, -0.56), _v(0.6, -0.12), _v(0.42, 0.36)], true, 8)
			c.fill(pin, 0.22)
			c.stroke(pin, W, 1.0, true)
			var mf := _flame_pts(0.3, _v(0.0, -0.22))
			c.fill(mf, 0.7)
			c.stroke(mf, W * 0.5, 1.0, true)
		"save":
			var bolt := PackedVector2Array([_v(0.2, -0.98), _v(-0.5, 0.12), _v(-0.05, 0.12), _v(-0.2, 0.98),
				_v(0.5, -0.18), _v(0.06, -0.18)])
			c.fill(bolt, 0.28)
			c.stroke(bolt, W, 1.0, true)
		"capacity":
			c.line(_v(-0.22, -0.96), _v(-0.22, -0.34), W)
			c.line(_v(0.22, -0.96), _v(0.22, -0.34), W)
			c.line(_v(-0.34, -0.96), _v(0.34, -0.96), W * 0.9)
			var bc := _v(0.0, 0.32)
			var liquid := PackedVector2Array()
			liquid.append(_v(0.67, 0.12))
			for i in 20:
				var ang := lerpf(-0.286, PI + 0.286, float(i) / 19.0)
				liquid.append(bc + _v(cos(ang), sin(ang)) * 0.7)
			c.fill(liquid, 0.45)
			c.arc(bc, 0.7, -1.25, PI + 1.25, W)
			c.stroke(PackedVector2Array([_v(-0.62, 0.14), _v(-0.3, 0.06), _v(0.0, 0.14), _v(0.3, 0.06), _v(0.62, 0.14)]), W * 0.5, 0.8)
		"charge":
			var body := PackedVector2Array()
			var cx0 := -0.8
			var cx1 := 0.56
			var cy0 := -0.44
			var cy1 := 0.44
			var cr := 0.14
			for q in 4:
				var qc := _v(cx1 - cr, cy0 + cr) if q == 0 else (_v(cx1 - cr, cy1 - cr) if q == 1 else (_v(cx0 + cr, cy1 - cr) if q == 2 else _v(cx0 + cr, cy0 + cr)))
				for i in 6:
					var ang := -PI * 0.5 + (float(q) + float(i) / 5.0) * PI * 0.5
					body.append(qc + _v(cos(ang), sin(ang)) * cr)
			c.stroke(body, W, 1.0, true)
			c.stroke(PackedVector2Array([_v(0.56, -0.17), _v(0.84, -0.17), _v(0.84, 0.17), _v(0.56, 0.17)]), W * 0.9)
			c.fill(PackedVector2Array([_v(-0.66, -0.24), _v(-0.4, -0.24), _v(-0.4, 0.24), _v(-0.66, 0.24)]), 0.95)
			c.fill(PackedVector2Array([_v(-0.3, -0.24), _v(-0.04, -0.24), _v(-0.04, 0.24), _v(-0.3, 0.24)]), 0.95)
			c.fill(PackedVector2Array([_v(0.06, -0.24), _v(0.32, -0.24), _v(0.32, 0.24), _v(0.06, 0.24)]), 0.35)
		"range":
			c.ring(Vector2.ZERO, 0.22, W * 0.85)
			for i in 4:
				var ang := TAU * float(i) / 4.0
				var dv := _v(cos(ang), sin(ang))
				var pv := _v(-dv.y, dv.x)
				var tip := dv * 0.94
				c.line(dv * 0.44, tip, W * 0.85)
				c.stroke(PackedVector2Array([tip - dv * 0.24 + pv * 0.2, tip, tip - dv * 0.24 - pv * 0.2]), W * 0.85)
		"legs":
			var base := _v(-0.76, 0.62)
			c.stroke(_smooth([base, _v(-0.5, -0.1), _v(-0.1, -0.6), _v(0.5, -0.86)], false, 8), W)
			c.stroke(_smooth([base, _v(-0.3, 0.16), _v(0.2, -0.24), _v(0.86, -0.36)], false, 8), W * 0.9, 0.9)
			c.stroke(_smooth([base, _v(-0.14, 0.4), _v(0.36, 0.14), _v(0.92, 0.1)], false, 8), W * 0.8, 0.75)
			c.stroke(_smooth([base, _v(0.04, 0.62), _v(0.42, 0.56), _v(0.78, 0.56)], false, 8), W * 0.7, 0.6)
			c.dot(base, 0.1)
		"magic":
			var big := _star_pts(4, 0.96, 0.17, -PI * 0.5)
			c.fill(big, 0.28)
			c.stroke(big, W, 1.0, true)
			for sp in [[_v(0.66, -0.66), 0.28], [_v(-0.68, 0.62), 0.2]]:
				var sm := PackedVector2Array()
				for p in _star_pts(4, 1.0, 0.18, -PI * 0.5):
					sm.append(p * float(sp[1]) + Vector2(sp[0]))
				c.stroke(sm, W * 0.6, 0.85, true)
		"deceit":
			var face := _smooth([_v(0.0, -0.96), _v(0.56, -0.72), _v(0.72, -0.1), _v(0.5, 0.56), _v(0.0, 0.98),
				_v(-0.5, 0.56), _v(-0.72, -0.1), _v(-0.56, -0.72)], true, 8)
			c.fill(face, 0.2)
			c.stroke(face, W, 1.0, true)
			c.stroke(PackedVector2Array([_v(-0.5, -0.2), _v(-0.2, -0.02), _v(-0.5, 0.0)]), W * 0.7)
			c.stroke(PackedVector2Array([_v(0.5, -0.2), _v(0.2, -0.02), _v(0.5, 0.0)]), W * 0.7)
			c.arc(_v(0.0, 0.2), 0.4, PI * 0.2, PI * 0.8, W * 0.75)
		"crush":
			var burst := _star_pts(8, 1.0, 0.5, -PI * 0.5)
			c.fill(burst, 0.24)
			c.stroke(burst, W * 0.9, 1.0, true)
			c.dot(Vector2.ZERO, 0.14)
		"stasis":
			for k in 3:
				var ang := PI * 0.5 + PI * float(k) / 3.0
				var dv := _v(cos(ang), sin(ang))
				c.line(dv * -0.96, dv * 0.96, W * 0.85)
				for sgn in [-1.0, 1.0]:
					var bp: Vector2 = dv * (0.56 * float(sgn))
					for sd in [-1.0, 1.0]:
						var bd := dv.rotated(deg_to_rad(38.0) * float(sd)) * float(sgn)
						c.line(bp, bp + bd * 0.26, W * 0.6, 0.85)
			c.ring(Vector2.ZERO, 0.16, W * 0.6, 0.7)
		"echo":
			c.dot(_v(-0.58, 0.0), 0.15)
			for i in 3:
				var rr := 0.46 + 0.36 * float(i)
				c.arc(_v(-0.58, 0.0), rr, -0.62, 0.62, W * (0.9 - 0.12 * float(i)), 1.0 - 0.24 * float(i))
		"life":
			var heart := PackedVector2Array()
			for i in 40:
				var t := float(i) / 40.0 * TAU
				var hx := pow(sin(t), 3.0) * 16.0
				var hy := -(13.0 * cos(t) - 5.0 * cos(2.0 * t) - 2.0 * cos(3.0 * t) - cos(4.0 * t))
				heart.append(_v(hx / 17.0, hy / 17.0 - 0.145))
			c.fill(heart, 0.4)
			c.stroke(heart, W, 1.0, true)
		"light":
			var gc := _v(0.0, -0.2)
			c.arc(gc, 0.56, PI * 0.72, PI * 2.28, W)
			c.stroke(PackedVector2Array([_v(-0.34, 0.5), _v(-0.22, 0.66)]), W * 0.9)
			c.stroke(PackedVector2Array([_v(0.34, 0.5), _v(0.22, 0.66)]), W * 0.9)
			c.line(_v(-0.24, 0.66), _v(0.24, 0.66), W * 0.9)
			c.line(_v(-0.2, 0.86), _v(0.2, 0.86), W * 0.9)
			c.stroke(PackedVector2Array([_v(-0.2, 0.3), _v(-0.1, -0.1), _v(0.0, 0.1), _v(0.1, -0.1), _v(0.2, 0.3)]), W * 0.6, 0.85)
			c.dot(gc, 0.18, 0.5)
		"star":
			var st := _star_pts(5, 1.0, 0.42, -PI * 0.5)
			c.fill(st, 0.3)
			c.stroke(st, W, 1.0, true)
		_:
			var dflt := _star_pts(6, 0.96, 0.4, -PI * 0.5)
			c.fill(dflt, 0.22)
			c.stroke(dflt, W, 1.0, true)
