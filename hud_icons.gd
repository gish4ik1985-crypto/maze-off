class_name HudIcon
extends Control

## Неоновая контурная иконка для HUD. Рисуется кодом в _draw() — свечение в три
## прохода (широкий тусклый ореол → средний → яркая нить), под стать граням стен
## в textures.gd. Масштабируется под size узла; цвет — col, тип — kind.
##   kind: heart | shard | key | clock | bulb | boost | adapt | spark

@export var kind: String = "heart"
@export var col: Color = Color(1, 1, 1)

func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	pivot_offset = size * 0.5

# Разовый «пинок» масштаба — отклик на подбор осколка/ключа (не фоновая анимация).
func pop(strength: float = 0.35) -> void:
	pivot_offset = size * 0.5
	var t := create_tween()
	t.tween_property(self, "scale", Vector2.ONE * (1.0 + strength), 0.08) \
		.set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	t.tween_property(self, "scale", Vector2.ONE, 0.18) \
		.set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)

func _u() -> float:
	return minf(size.x, size.y)

# Контур со свечением: широкий тусклый ореол → средний → яркая нить.
func _glow_poly(pts: PackedVector2Array, w: float, closed: bool) -> void:
	var p := pts
	if closed and p.size() > 1:
		p = p.duplicate()
		p.append(p[0])
	draw_polyline(p, Color(col.r, col.g, col.b, 0.10), w * 3.0, true)
	draw_polyline(p, Color(col.r, col.g, col.b, 0.24), w * 1.8, true)
	draw_polyline(p, col, w, true)

func _glow_arc(center: Vector2, radius: float, a0: float, a1: float, w: float) -> void:
	draw_arc(center, radius, a0, a1, 32, Color(col.r, col.g, col.b, 0.10), w * 3.0, true)
	draw_arc(center, radius, a0, a1, 32, Color(col.r, col.g, col.b, 0.24), w * 1.8, true)
	draw_arc(center, radius, a0, a1, 32, col, w, true)

func _draw() -> void:
	match kind:
		"heart": _draw_heart()
		"shard": _draw_shard()
		"key":   _draw_key()
		"clock": _draw_clock()
		"bulb":  _draw_bulb()
		"boost": _draw_cycle(false)
		"adapt": _draw_cycle(true)
		"spark": _draw_spark()

func _draw_heart() -> void:
	var u := _u()
	var c := size * 0.5
	var w := maxf(1.5, u * 0.09)
	var n := 48
	var raw: Array[Vector2] = []
	var mn := Vector2(INF, INF)
	var mx := Vector2(-INF, -INF)
	for i in n:
		var t := float(i) / float(n) * TAU
		var hx := pow(sin(t), 3.0) * 16.0
		# математический y (вверх) — на экране переворачиваем, чтобы остриё было снизу
		var hy := -(13.0 * cos(t) - 5.0 * cos(2.0 * t) - 2.0 * cos(3.0 * t) - cos(4.0 * t))
		var v := Vector2(hx, hy)
		raw.append(v)
		mn = Vector2(minf(mn.x, v.x), minf(mn.y, v.y))
		mx = Vector2(maxf(mx.x, v.x), maxf(mx.y, v.y))
	var span := maxf(mx.x - mn.x, mx.y - mn.y)
	var sc := (u * 0.92) / span
	var mid := (mn + mx) * 0.5
	var pts := PackedVector2Array()
	for v in raw:
		pts.append(c + (v - mid) * sc)
	draw_colored_polygon(pts, Color(col.r, col.g, col.b, 0.55))
	_glow_poly(pts, w, true)

func _draw_shard() -> void:
	var u := _u()
	var c := size * 0.5
	var w := maxf(1.5, u * 0.085)
	var rx := u * 0.27
	var ry := u * 0.42
	var sh := ry * 0.42
	var pts := PackedVector2Array([
		c + Vector2(0, -ry),
		c + Vector2(rx, -sh),
		c + Vector2(rx, sh),
		c + Vector2(0, ry),
		c + Vector2(-rx, sh),
		c + Vector2(-rx, -sh),
	])
	draw_colored_polygon(pts, Color(col.r, col.g, col.b, 0.22))
	_glow_poly(pts, w, true)
	# грань-«столик» и центральное ребро (огранка кристалла)
	_glow_poly(PackedVector2Array([c + Vector2(-rx, -sh), c + Vector2(rx, -sh)]), w * 0.7, false)
	_glow_poly(PackedVector2Array([c + Vector2(0, -ry), c + Vector2(0, ry)]), w * 0.6, false)

func _draw_key() -> void:
	var u := _u()
	var c := size * 0.5
	var w := maxf(1.5, u * 0.09)
	var br := u * 0.17
	var bow := Vector2(c.x - u * 0.20, c.y)
	_glow_arc(bow, br, 0.0, TAU, w)
	var shaft_a := bow + Vector2(br, 0)
	var shaft_b := Vector2(c.x + u * 0.42, c.y)
	_glow_poly(PackedVector2Array([shaft_a, shaft_b]), w, false)
	_glow_poly(PackedVector2Array([shaft_b, shaft_b + Vector2(0, u * 0.16)]), w, false)
	var t2 := shaft_b - Vector2(u * 0.13, 0)
	_glow_poly(PackedVector2Array([t2, t2 + Vector2(0, u * 0.11)]), w, false)

func _draw_clock() -> void:
	var u := _u()
	var c := size * 0.5
	var w := maxf(1.5, u * 0.09)
	var r := u * 0.37
	_glow_arc(c, r, 0.0, TAU, w)
	_glow_poly(PackedVector2Array([c, c + Vector2(0, -r * 0.60)]), w, false)
	_glow_poly(PackedVector2Array([c, c + Vector2(r * 0.44, r * 0.12)]), w, false)

func _draw_bulb() -> void:
	var u := _u()
	var c := size * 0.5
	var w := maxf(1.4, u * 0.085)
	var gc := Vector2(c.x, c.y - u * 0.10)
	var r := u * 0.27
	_glow_arc(gc, r, 0.0, TAU, w)
	var by := gc.y + r
	_glow_poly(PackedVector2Array([Vector2(c.x - r * 0.55, by + u * 0.02), Vector2(c.x + r * 0.55, by + u * 0.02)]), w * 0.7, false)
	_glow_poly(PackedVector2Array([Vector2(c.x - r * 0.42, by + u * 0.11), Vector2(c.x + r * 0.42, by + u * 0.11)]), w * 0.7, false)
	_glow_poly(PackedVector2Array([Vector2(c.x - r * 0.30, gc.y + r * 0.05), Vector2(c.x, gc.y - r * 0.22), Vector2(c.x + r * 0.30, gc.y + r * 0.05)]), w * 0.6, false)

# Кольцевая стрелка (накопительная пассивка). reverse — другое направление.
func _draw_cycle(reverse: bool) -> void:
	var u := _u()
	var c := size * 0.5
	var w := maxf(1.5, u * 0.09)
	var r := u * 0.33
	var sweep := TAU * 0.72
	var dir := -1.0 if reverse else 1.0
	var a0 := (PI + PI * 0.62) if reverse else (-PI * 0.62)
	var a1 := a0 + sweep * dir
	_glow_arc(c, r, minf(a0, a1), maxf(a0, a1), w)
	var tip := c + Vector2(cos(a1), sin(a1)) * r
	var tang := Vector2(-sin(a1), cos(a1)) * dir     # касательная по ходу стрелки
	var rad := (tip - c).normalized()
	var hl := u * 0.17
	var p1 := tip - tang * hl + rad * hl * 0.55
	var p2 := tip - tang * hl - rad * hl * 0.55
	_glow_poly(PackedVector2Array([p1, tip, p2]), w, false)

func _draw_spark() -> void:
	var u := _u()
	var c := size * 0.5
	var w := maxf(1.4, u * 0.09)
	var r := u * 0.40
	var rr := r * 0.4
	var pts := PackedVector2Array([
		c + Vector2(0, -r), c + Vector2(rr, -rr),
		c + Vector2(r, 0), c + Vector2(rr, rr),
		c + Vector2(0, r), c + Vector2(-rr, rr),
		c + Vector2(-r, 0), c + Vector2(-rr, -rr),
	])
	draw_colored_polygon(pts, Color(col.r, col.g, col.b, 0.25))
	_glow_poly(pts, w, true)
