class_name MazeTextures
extends RefCounted

# Общие генераторы текстур, чтобы не дублировать код в игроке и станциях.
#
# Текстуры кэшируются по параметрам и переиспользуются всеми экземплярами: один
# и тот же гем/свет/враг просят десятки раз (до ~160 станций на уровень) — это
# идентичные ресурсы. Кэш статический и переживает перезагрузку сцены: ключи
# ограничены небольшим набором (фиксированные цвета/радиусы из констант), так
# что словарь не растёт. Вернувшиеся текстуры ОБЩИЕ — их нельзя мутировать
# (никто и не мутирует: цвет/масштаб задаются на узле, а не на текстуре).
# make_wall_tile здесь НЕ кэшируется — цвет стен зависит от уровня, их кэш
# живёт в main.gd (_wall_tex_cache) и сбрасывается при сборке уровня.
static var _cache: Dictionary = {}

static func make_ball(radius: int, color: Color = Color.WHITE) -> ImageTexture:
	var ck := "ball_%d_%s" % [radius, color.to_html(true)]
	if _cache.has(ck):
		return _cache[ck]
	var d := radius * 2
	var img := Image.create_empty(d, d, false, Image.FORMAT_RGBA8)
	for y in d:
		for x in d:
			var dist := Vector2(x - radius, y - radius).length()
			if dist <= radius:
				var a: float = clampf(1.0 - (dist - (radius - 2.0)) / 2.0, 0.0, 1.0)
				img.set_pixel(x, y, Color(color.r, color.g, color.b, a))
			else:
				img.set_pixel(x, y, Color(color.r, color.g, color.b, 0.0))
	var tex := ImageTexture.create_from_image(img)
	_cache[ck] = tex
	return tex

static func make_light(size: int) -> GradientTexture2D:
	var ck := "light_%d" % size
	if _cache.has(ck):
		return _cache[ck]
	var grad := Gradient.new()
	grad.set_color(0, Color(1, 1, 1, 1))
	grad.set_color(1, Color(1, 1, 1, 0))
	var tex := GradientTexture2D.new()
	tex.gradient = grad
	tex.fill = GradientTexture2D.FILL_RADIAL
	tex.fill_from = Vector2(0.5, 0.5)
	tex.fill_to = Vector2(1.0, 0.5)
	tex.width = size
	tex.height = size
	_cache[ck] = tex
	return tex

static func make_ring(size: int) -> GradientTexture2D:
	# Светящееся кольцо: яркая полоса ближе к краю (для сонара).
	var ck := "ring_%d" % size
	if _cache.has(ck):
		return _cache[ck]
	var grad := Gradient.new()
	grad.offsets = PackedFloat32Array([0.0, 0.62, 0.82, 1.0])
	grad.colors = PackedColorArray([
		Color(1, 1, 1, 0),
		Color(1, 1, 1, 0),
		Color(1, 1, 1, 1),
		Color(1, 1, 1, 0),
	])
	var tex := GradientTexture2D.new()
	tex.gradient = grad
	tex.fill = GradientTexture2D.FILL_RADIAL
	tex.fill_from = Vector2(0.5, 0.5)
	tex.fill_to = Vector2(1.0, 0.5)
	tex.width = size
	tex.height = size
	_cache[ck] = tex
	return tex

# ============================================================================
# 2.5D-стена в неоновом стиле Tron.
# Возвращает CanvasTexture (albedo + normal map). Тёмная тонированная «крышка»
# блока + светящаяся грань вдоль ОТКРЫТЫХ сторон: бело-горячая нить у самого
# края и мягкий цветной ореол вглубь. Грань совпадает с бевелем normal map,
# поэтому свет игрока вживую «зажигает» её и лепит 2.5D-объём.
# open_mask — какие стороны клетки открыты в проход: N=1, E=2, S=4, W=8.
# base — НЕОНОВЫЙ цвет темы уровня (яркий). Тёмную крышку и нить выводим из него.
# Конвенция normal map проверена по исходнику GLES3 (ny = 1 - 2G):
#   верх (смотрит вверх по экрану) -> зелёный ЯРКИЙ; низ -> тёмный;
#   восток -> красный яркий; запад -> тёмный. Плоскость = (0.5,0.5,1).
static func make_wall_tile(size: int, open_mask: int, base: Color) -> CanvasTexture:
	var dimg := Image.create_empty(size, size, false, Image.FORMAT_RGBA8)
	var nimg := Image.create_empty(size, size, false, Image.FORMAT_RGBA8)
	var n := (open_mask & 1) != 0
	var e := (open_mask & 2) != 0
	var s := (open_mask & 4) != 0
	var w := (open_mask & 8) != 0
	# Выпуклые углы: диагональ открыта в проход, а оба смежных кардинала — стена.
	# Без них на стыках остаются чёрные квадратики (угловые «пеньки» без ореола).
	var c_ne := (open_mask & 16) != 0 and not n and not e
	var c_se := (open_mask & 32) != 0 and not s and not e
	var c_sw := (open_mask & 64) != 0 and not s and not w
	var c_nw := (open_mask & 128) != 0 and not n and not w

	# Тёмная тонированная крышка блока (видна даже без света — снимает «провал в ноль»).
	var top := Color(base.r * 0.15 + 0.010, base.g * 0.16 + 0.014, base.b * 0.17 + 0.020, 1.0)
	# Насыщенный неон для ореола грани.
	var neon := Color(minf(1.0, base.r * 1.85 + 0.08), minf(1.0, base.g * 1.85 + 0.08), minf(1.0, base.b * 1.85 + 0.08), 1.0)
	var hot := Color(0.92, 0.97, 1.0, 1.0)     # бело-горячая нить у самого края
	var bw := maxf(3.0, float(size) * 0.24)    # ширина бевеля/ореола (px)
	var tilt := 0.78                           # сила наклона нормали на бевеле

	for y in size:
		for x in size:
			# Линейные «рампы» 1->0 от каждого ОТКРЫТОГО края вглубь на bw.
			var dn := float(y)
			var ds := float(size - 1 - y)
			var de := float(size - 1 - x)
			var dw := float(x)
			var rn: float = (1.0 - dn / bw) if (n and dn < bw) else 0.0
			var rs: float = (1.0 - ds / bw) if (s and ds < bw) else 0.0
			var re: float = (1.0 - de / bw) if (e and de < bw) else 0.0
			var rw: float = (1.0 - dw / bw) if (w and dw < bw) else 0.0
			# Угловые рампы (радиус от соответствующего угла плитки)
			var rne := 0.0
			var rse := 0.0
			var rsw := 0.0
			var rnw := 0.0
			if c_ne:
				var d_ne := Vector2(de, dn).length()
				if d_ne < bw: rne = 1.0 - d_ne / bw
			if c_se:
				var d_se := Vector2(de, ds).length()
				if d_se < bw: rse = 1.0 - d_se / bw
			if c_sw:
				var d_sw := Vector2(dw, ds).length()
				if d_sw < bw: rsw = 1.0 - d_sw / bw
			if c_nw:
				var d_nw := Vector2(dw, dn).length()
				if d_nw < bw: rnw = 1.0 - d_nw / bw
			var rim: float = maxf(maxf(maxf(rn, rs), maxf(re, rw)), maxf(maxf(rne, rse), maxf(rsw, rnw)))

			# --- Albedo: тёмная крышка -> цветной ореол -> бело-горячая нить ---
			var glow: float = rim                                # цветной ореол (линейный спад вглубь)
			var line: float = smoothstep(0.62, 1.0, rim)         # тонкая яркая нить у самого края
			var c := top.lerp(neon, clampf(glow * 0.82, 0.0, 1.0))
			c = c.lerp(hot, line * 0.9)
			c.a = 1.0
			dimg.set_pixel(x, y, c)

			# --- Normal map (экранное пространство: x вправо, y вниз, z к зрителю) ---
			# Углы наклоняют нормаль по диагонали, чтобы свет «зажигал» и их.
			var nx_screen := (re - rw + rne + rse - rnw - rsw) * tilt
			var ny_screen := (rs - rn + rse + rsw - rne - rnw) * tilt   # юг = +вниз, север = -вверх
			var nv := Vector3(nx_screen, ny_screen, 1.0).normalized()
			# Кодируем под декодер GLES3: R=(nx+1)/2, G=(1-ny)/2, B=(nz+1)/2
			nimg.set_pixel(x, y, Color(
				nv.x * 0.5 + 0.5,
				(1.0 - nv.y) * 0.5,
				nv.z * 0.5 + 0.5,
				1.0))

	var ct := CanvasTexture.new()
	ct.diffuse_texture = ImageTexture.create_from_image(dimg)
	ct.normal_texture = ImageTexture.create_from_image(nimg)
	return ct

# ============================================================================
# Передняя (южная, обращённая к зрителю) грань стены-блока для ¾-вида.
# Тёмная вертикальная грань: чуть светлее у верхнего ребра (стык с крышкой),
# затухает к основанию. Тонкая неоновая нить по нижнему краю — там грань
# встречается с полом прохода (продолжение ореола крышки). Normal map смотрит
# «на зрителя/вниз экрана», чтобы свет игрока снизу зажигал грань вживую.
static func make_wall_face(w: int, h: int, base: Color) -> CanvasTexture:
	var dimg := Image.create_empty(w, h, false, Image.FORMAT_RGBA8)
	var nimg := Image.create_empty(w, h, false, Image.FORMAT_RGBA8)
	# Грань темнее крышки: блок стоит, свет сверху — бок в полутени.
	var top_c := Color(base.r * 0.10 + 0.008, base.g * 0.11 + 0.010, base.b * 0.12 + 0.016, 1.0)
	var bot_c := Color(base.r * 0.05 + 0.004, base.g * 0.055 + 0.005, base.b * 0.06 + 0.008, 1.0)
	var neon := Color(minf(1.0, base.r * 1.85 + 0.08), minf(1.0, base.g * 1.85 + 0.08), minf(1.0, base.b * 1.85 + 0.08), 1.0)
	# Нормаль всей грани — на зрителя и вниз экрана (грань «стоит» вертикально).
	var nv := Vector3(0.0, 0.85, 1.0).normalized()
	var enc := Color(nv.x * 0.5 + 0.5, (1.0 - nv.y) * 0.5, nv.z * 0.5 + 0.5, 1.0)
	for y in h:
		var t := float(y) / maxf(float(h - 1), 1.0)   # 0 верх -> 1 низ
		var c := top_c.lerp(bot_c, t)
		# Неоновая нить у самого основания (последние ~2px).
		var line := clampf((float(y) - float(h - 3)) / 2.0, 0.0, 1.0)
		c = c.lerp(neon, line * 0.75)
		for x in w:
			dimg.set_pixel(x, y, c)
			nimg.set_pixel(x, y, enc)
	var ct := CanvasTexture.new()
	ct.diffuse_texture = ImageTexture.create_from_image(dimg)
	ct.normal_texture = ImageTexture.create_from_image(nimg)
	return ct

# ============================================================================
# [TILEMAP-1.8] Совмещённая текстура тайла для TileMapLayer: крышка
# (make_wall_tile) + южная грань снизу (make_wall_face, только когда
# with_face) в ОДНОЙ CanvasTexture. Раньше это были две ноды (Sprite2D vis +
# Sprite2D face) — у TileSet один тайл на клетку, поэтому склеиваем оба слоя в
# одно изображение. Высота ВСЕГДА size+wall_h (даже без грани — там просто
# прозрачная полоса), чтобы TileData.texture_origin сдвигал крышку вверх на
# wall_h ОДИНАКОВО для всех тайлов — так же, как раньше делал
# vis.position=(0,-WALL_H) у Sprite2D независимо от наличия грани (main.gd).
static func make_wall_tile_combined(size: int, wall_h: int, open_mask: int, base: Color, with_face: bool) -> CanvasTexture:
	var cap := make_wall_tile(size, open_mask, base)
	if wall_h <= 0:
		return cap
	var dimg := Image.create_empty(size, size + wall_h, false, Image.FORMAT_RGBA8)
	var nimg := Image.create_empty(size, size + wall_h, false, Image.FORMAT_RGBA8)
	dimg.blit_rect(cap.diffuse_texture.get_image(), Rect2i(0, 0, size, size), Vector2i(0, 0))
	nimg.blit_rect(cap.normal_texture.get_image(), Rect2i(0, 0, size, size), Vector2i(0, 0))
	if with_face:
		var face := make_wall_face(size, wall_h, base)
		dimg.blit_rect(face.diffuse_texture.get_image(), Rect2i(0, 0, size, wall_h), Vector2i(0, size))
		nimg.blit_rect(face.normal_texture.get_image(), Rect2i(0, 0, size, wall_h), Vector2i(0, size))
	# Без грани — прозрачная полоса снизу (нижняя полоса alpha=0 по умолчанию
	# у Image.create_empty), чтобы под сдвинутой крышкой было видно проход/пол.
	var ct := CanvasTexture.new()
	ct.diffuse_texture = ImageTexture.create_from_image(dimg)
	ct.normal_texture = ImageTexture.create_from_image(nimg)
	return ct

# ============================================================================
# Боковая (восточная/западная) грань стены-блока для ¾-вида с перспективой от
# игрока. dir = -1 — западная грань (внутреннее ребро справа, у тела стены),
# dir = +1 — восточная (внутреннее ребро слева). Тёмный горизонтальный градиент
# от тела наружу + неоновая нить по внешнему краю (стык с полом прохода).
static func make_wall_side(w: int, h: int, base: Color, dir: int) -> CanvasTexture:
	var dimg := Image.create_empty(w, h, false, Image.FORMAT_RGBA8)
	var nimg := Image.create_empty(w, h, false, Image.FORMAT_RGBA8)
	var in_c := Color(base.r * 0.09 + 0.007, base.g * 0.10 + 0.009, base.b * 0.11 + 0.014, 1.0)
	var out_c := Color(base.r * 0.045 + 0.003, base.g * 0.05 + 0.004, base.b * 0.055 + 0.007, 1.0)
	var neon := Color(minf(1.0, base.r * 1.85 + 0.08), minf(1.0, base.g * 1.85 + 0.08), minf(1.0, base.b * 1.85 + 0.08), 1.0)
	# Нормаль грани смотрит наружу по X (и чуть на зрителя).
	var nv := Vector3(-0.85 if dir < 0 else 0.85, 0.0, 1.0).normalized()
	var enc := Color(nv.x * 0.5 + 0.5, 0.5, nv.z * 0.5 + 0.5, 1.0)
	for x in w:
		# t: 0 у тела стены -> 1 у внешнего края (для запада внешний край слева).
		var t := (float(w - 1 - x) / maxf(float(w - 1), 1.0)) if dir < 0 else (float(x) / maxf(float(w - 1), 1.0))
		var c := in_c.lerp(out_c, t)
		var line := clampf((t - 0.75) * 4.0, 0.0, 1.0)
		# Нить приглушена (0.22, была 0.7): яркая дублировала неоновую кромку
		# крышки, и на углах/швах их пересечение вспыхивало «квадратиком» —
		# главный визуальный артефакт при движении вдоль стен.
		c = c.lerp(neon, line * 0.22)
		for y in h:
			dimg.set_pixel(x, y, c)
			nimg.set_pixel(x, y, enc)
	var ct := CanvasTexture.new()
	ct.diffuse_texture = ImageTexture.create_from_image(dimg)
	ct.normal_texture = ImageTexture.create_from_image(nimg)
	return ct

# Светящийся «энергетический» кристалл: вертикальный гранёный шестиугольник
# с бело-горячим ядром и мягким цветным ореолом вокруг силуэта. Используется
# для осколков, станций, выхода и дверей. Сам предмет ещё подсвечивается своим
# PointLight2D; здесь запекаем тело + ауру, чтобы кристалл «горел» и в полутьме.
static func make_gem(radius: int, color: Color) -> ImageTexture:
	var ck := "gem_%d_%s" % [radius, color.to_html(true)]
	if _cache.has(ck):
		return _cache[ck]
	var halo := int(round(radius * 0.85))        # поле под ауру свечения
	var bw := radius * 2                          # ширина тела
	var bh := int(round(radius * 3.0))            # высота тела
	var wdt := bw + halo * 2
	var hgt := bh + halo * 2
	var img := Image.create_empty(wdt, hgt, false, Image.FORMAT_RGBA8)
	var cx := wdt * 0.5
	var cy := hgt * 0.5
	var halfw := float(radius)

	var y_top := halo + bh * 0.04      # верхняя вершина (в координатах изображения)
	var y_us := halo + bh * 0.30       # верхние «плечи» (макс. ширина)
	var y_ls := halo + bh * 0.62       # нижние «плечи»
	var y_bot := halo + bh * 0.97      # нижняя вершина
	var y_table := halo + bh * 0.16    # линия верхней грани (table)

	var aura := Color(minf(1.0, color.r * 1.3 + 0.05), minf(1.0, color.g * 1.3 + 0.05), minf(1.0, color.b * 1.3 + 0.05), 1.0)

	for y in hgt:
		for x in wdt:
			var fy := float(y)
			var in_body := fy >= y_top and fy <= y_bot
			var hw := 0.0
			if in_body:
				if fy < y_us:
					hw = halfw * (fy - y_top) / maxf(y_us - y_top, 1.0)
				elif fy < y_ls:
					hw = halfw
				else:
					hw = halfw * (y_bot - fy) / maxf(y_bot - y_ls, 1.0)
			var dx := float(x) - cx
			var adx := absf(dx)
			var edge := hw - adx
			var a: float = clampf((edge + 1.2) / 1.2, 0.0, 1.0) if in_body else 0.0

			if a > 0.0:
				# --- Тело кристалла: грани + бело-горячее ядро ---
				var b := 0.0
				var ridge := 1.0 - clampf(adx / maxf(hw, 1.0), 0.0, 1.0)
				b += ridge * 0.30
				b += (-dx / maxf(hw, 1.0)) * 0.12
				if fy < y_table:
					b += 0.34
				elif fy < y_us:
					b += 0.12
				elif fy > y_ls:
					b -= 0.20 * ((fy - y_ls) / maxf(y_bot - y_ls, 1.0))
				else:
					b -= 0.04
				b += 0.10
				var cc := color.lightened(clampf(b, 0.0, 1.0)) if b >= 0.0 else color.darkened(clampf(-b, 0.0, 1.0))
				# Бело-горячее ядро в центре тела (энергия).
				var core := clampf(1.0 - Vector2(dx, fy - cy).length() / maxf(radius * 0.95, 1.0), 0.0, 1.0)
				cc = cc.lerp(Color(1, 1, 1, 1), core * core * 0.7)
				# Верхний блик.
				var spec := Vector2(float(x) - (cx - halfw * 0.18), fy - y_table * 0.92).length()
				if spec < radius * 0.18:
					cc = cc.lerp(Color(1, 1, 1, 1), (1.0 - spec / (radius * 0.18)) * 0.85)
				cc.a = a
				img.set_pixel(x, y, cc)
			else:
				# --- Внешняя аура: мягкий эллиптический спад вокруг тела ---
				var gx := dx / (halfw + halo)
				var gy := (fy - cy) / (bh * 0.5 + halo)
				var gd := sqrt(gx * gx + gy * gy)
				var ga := clampf(1.0 - gd, 0.0, 1.0)
				ga = ga * ga * 0.55
				img.set_pixel(x, y, Color(aura.r, aura.g, aura.b, ga))
	var tex := ImageTexture.create_from_image(img)
	_cache[ck] = tex
	return tex

# ============================================================================
# Осколок-«ключ» (v1.9): петля (как ушко ключа) слитая с сужающимся лезвием —
# ОДНА текстура, не гем + отдельное кольцо поверх (то давало «плавающий
# ореол»-артефакт, петля и тело рендерились разными узлами не в одном пикселе).
# Силуэт нарочно не похож на гем (make_gem, применяется для станций) — читается
# как ключ, а не как самоцвет.
static func make_key_crystal(radius: int, color: Color) -> ImageTexture:
	var ck := "keycrystal_%d_%s" % [radius, color.to_html(true)]
	if _cache.has(ck):
		return _cache[ck]
	var ring_r := radius * 0.52
	var ring_w := radius * 0.20
	var blade_h := radius * 2.1
	var halo := int(round(radius * 0.6))
	var wdt := int(ring_r * 2.0 + halo * 2)
	var hgt := int(ring_r * 2.0 + blade_h + halo * 2)
	var img := Image.create_empty(wdt, hgt, false, Image.FORMAT_RGBA8)
	var cx := wdt * 0.5
	var ring_cy := halo + ring_r
	var blade_top := ring_cy + ring_r * 0.55
	var blade_bot := hgt - halo * 0.5
	var bright := Color(minf(1.0, color.r * 1.6 + 0.25), minf(1.0, color.g * 1.6 + 0.25), minf(1.0, color.b * 1.6 + 0.25), 1.0)

	for y in hgt:
		for x in wdt:
			var fx := float(x)
			var fy := float(y)
			var a := 0.0
			var cc := color

			# --- Петля (ушко ключа): кольцо у верхушки ---
			var rd := Vector2(fx - cx, fy - ring_cy).length()
			var ring_edge := ring_w * 0.5 - absf(rd - (ring_r - ring_w * 0.5))
			if ring_edge > -1.0:
				var ra := clampf((ring_edge + 1.0) / 1.0, 0.0, 1.0)
				var rc := color.lerp(bright, clampf(1.0 - absf(rd - (ring_r - ring_w * 0.5)) / (ring_w * 0.5), 0.0, 1.0) * 0.7)
				a = ra
				cc = rc

			# --- Лезвие: сужающееся тело от петли к острию ---
			if fy >= blade_top and fy <= blade_bot:
				var t := (fy - blade_top) / maxf(blade_bot - blade_top, 1.0)
				var hw := lerpf(ring_w * 1.15, radius * 0.05, t)
				var dx := fx - cx
				var edge := hw - absf(dx)
				var ba := clampf((edge + 1.0) / 1.0, 0.0, 1.0)
				if ba > 0.0:
					var bc := color.lightened(clampf(0.32 * (1.0 - t), 0.0, 1.0))
					bc = bc.lerp(Color(1, 1, 1, 1), clampf(1.0 - absf(dx) / maxf(hw, 1.0), 0.0, 1.0) * 0.35)
					if ba > a:
						a = ba
						cc = bc

			# --- Зубец ключа: небольшая насечка сбоку лезвия ---
			var notch_y0 := blade_top + (blade_bot - blade_top) * 0.55
			var notch_y1 := notch_y0 + radius * 0.22
			if fy >= notch_y0 and fy <= notch_y1:
				var t2 := (fy - blade_top) / maxf(blade_bot - blade_top, 1.0)
				var hw2 := lerpf(ring_w * 1.15, radius * 0.05, t2)
				var dx2 := fx - cx
				if dx2 > 0.0 and dx2 <= hw2 + radius * 0.22:
					a = maxf(a, clampf((hw2 + radius * 0.22 - dx2 + 1.0) / 1.0, 0.0, 1.0))
					cc = color.lightened(0.1)

			if a > 0.0:
				cc.a = a
				img.set_pixel(x, y, cc)
	var tex := ImageTexture.create_from_image(img)
	_cache[ck] = tex
	return tex

# ============================================================================
# Супербосс (GAMEDESIGN.md §25) — механическое «тело»: реакторное ядро с
# концентрическими кольцами в центре + N сегментных лап-манипуляторов с
# суставами и когтями на концах, расходящихся радиально. Раньше был обычным
# make_gem (гем/ромб) — та же ошибка, что уже правили у осколка/маяка/выхода
# (см. §22-24): нужен силуэт, который не спутать ни с чем другим в игре, и
# который читается как «высокотехнологичная машина», а не самоцвет.
static func make_superboss_body(radius: int, color: Color) -> ImageTexture:
	var ck := "superboss_%d_%s" % [radius, color.to_html(true)]
	if _cache.has(ck):
		return _cache[ck]
	var core_r := radius * 0.62
	var leg_len := radius * 1.9
	var halo := int(round(radius * 0.35))
	var d := int((radius + leg_len) * 2.0 + halo * 2.0)
	var img := Image.create_empty(d, d, false, Image.FORMAT_RGBA8)
	var c := d * 0.5
	var bright := Color(minf(1.0, color.r * 1.7 + 0.25), minf(1.0, color.g * 1.7 + 0.25), minf(1.0, color.b * 1.7 + 0.25), 1.0)
	var dark_metal := Color(0.12, 0.10, 0.16, 1.0)

	var n_legs := 7
	var leg_angles: Array[float] = []
	for i in n_legs:
		# Детерминированный «случайный» разброс углов (не randf — текстура
		# должна быть кэшируемой/воспроизводимой) — золотой угол даёт
		# несимметричную, механически правдоподобную расстановку конечностей.
		var jitter: float = sin(float(i) * 2.399963) * 0.18
		leg_angles.append(float(i) / float(n_legs) * TAU + jitter)

	for y in d:
		for x in d:
			var dx := float(x) - c
			var dy := float(y) - c
			var r := sqrt(dx * dx + dy * dy)
			var a := 0.0
			var cc := color

			# --- Реакторное ядро ---
			if r <= core_r:
				var t := r / core_r
				var ring := 0.5 + 0.5 * sin(t * 16.0)
				var shade := clampf(1.0 - t, 0.0, 1.0)
				cc = color.lerp(bright, shade * 0.6 + ring * 0.15)
				var core_bright := clampf(1.0 - r / maxf(core_r * 0.35, 1.0), 0.0, 1.0)
				cc = cc.lerp(Color(1, 1, 1, 1), core_bright * core_bright * 0.85)
				a = 1.0
			elif r <= core_r + radius * 0.14:
				a = 1.0
				cc = dark_metal.lightened(0.28)

			# --- Лапы-манипуляторы: сегменты с суставами, коготь на конце ---
			for ang in leg_angles:
				var dir := Vector2(cos(ang), sin(ang))
				var perp := Vector2(-dir.y, dir.x)
				var u := dx * dir.x + dy * dir.y
				var v := dx * perp.x + dy * perp.y
				if u < core_r * 0.8 or u > leg_len:
					continue
				var t2 := (u - core_r * 0.8) / maxf(leg_len - core_r * 0.8, 1.0)
				var hw := lerpf(radius * 0.22, radius * 0.05, t2)
				if t2 > 0.92:
					hw *= lerpf(1.0, 2.3, (t2 - 0.92) / 0.08)
				var edge := hw - absf(v)
				if edge < -1.0:
					continue
				var la := clampf((edge + 1.0) / 1.0, 0.0, 1.0)
				# Тёмные полосы-суставы через равные интервалы вдоль лапы.
				var seg := absf(sin(t2 * 16.0))
				var lc := dark_metal.lightened(0.12 + 0.18 * (1.0 - t2))
				if seg > 0.88:
					lc = lc.darkened(0.4)
				var rim := clampf(1.0 - absf(v) / maxf(hw, 1.0), 0.0, 1.0)
				lc = lc.lerp(color, rim * 0.35)
				if la > a:
					a = la
					cc = lc

			if a <= 0.001:
				continue
			cc.a = a
			img.set_pixel(x, y, cc)
	var tex := ImageTexture.create_from_image(img)
	_cache[ck] = tex
	return tex

# ============================================================================
# Станция зарядки (v1.9) — раньше был обычный гем (тот же силуэт, что у
# осколков/выхода/маяка — см. §22-24 в GAMEDESIGN.md, повторяющаяся жалоба
# «опять ромбик»). Теперь — «энергокапсула»: металлическая рамка с
# заключённой внутри светящейся энергией, пьедестал снизу, два коротких
# приёмных «уса»-антенны сверху. Читается как техническое устройство, не
# самоцвет.
static func make_charge_station(radius: int, color: Color) -> ImageTexture:
	var ck := "chargestation_%d_%s" % [radius, color.to_html(true)]
	if _cache.has(ck):
		return _cache[ck]
	var w := radius * 1.6
	var cap_h := radius * 2.0
	var base_h := radius * 0.65
	var prong_len := radius * 0.75
	var halo := int(round(radius * 0.55))
	var wdt := int(w + halo * 2.0)
	var hgt := int(cap_h + base_h + prong_len + halo * 2.0)
	var img := Image.create_empty(wdt, hgt, false, Image.FORMAT_RGBA8)
	var cx := wdt * 0.5
	var cap_top := halo * 0.5 + prong_len
	var cap_bot := cap_top + cap_h
	var base_top := cap_bot
	var base_bot := base_top + base_h
	var metal := Color(0.52, 0.56, 0.62, 1.0)
	var bright := Color(minf(1.0, color.r * 1.7 + 0.25), minf(1.0, color.g * 1.7 + 0.25), minf(1.0, color.b * 1.7 + 0.25), 1.0)
	var hw := w * 0.5
	var frame_w := radius * 0.10
	var prong_base := Vector2(cx, cap_top)

	for y in hgt:
		for x in wdt:
			var fx := float(x)
			var fy := float(y)
			var dx := fx - cx
			var a := 0.0
			var cc := color

			# --- Капсула энергии: скруглённый прямоугольник, металлическая рамка + свечение внутри ---
			if fy >= cap_top and fy <= cap_bot:
				var round_r := hw
				var edge_top := cap_top + round_r
				var edge_bot := cap_bot - round_r
				var inside := false
				var local_dx := dx
				if fy < edge_top:
					inside = Vector2(dx, fy - edge_top).length() <= round_r
				elif fy > edge_bot:
					inside = Vector2(dx, fy - edge_bot).length() <= round_r
				else:
					inside = absf(dx) <= hw
				if inside:
					if absf(local_dx) >= hw - frame_w:
						cc = metal
						a = 1.0
					else:
						var core := clampf(1.0 - absf(local_dx) / maxf(hw - frame_w, 1.0), 0.0, 1.0)
						cc = color.lerp(bright, core * core)
						a = 0.92

			# --- Пьедестал: металлическая трапеция, шире книзу ---
			if fy >= base_top and fy <= base_bot:
				var t := (fy - base_top) / maxf(base_bot - base_top, 1.0)
				var hw2 := lerpf(w * 0.32, w * 0.58, t)
				if absf(dx) <= hw2:
					a = 1.0
					cc = metal.darkened(0.18 * (1.0 - t))

			# --- Приёмные усы-антенны: две тонкие линии, расходящиеся вверх от капсулы ---
			for side in [-1.0, 1.0]:
				var tip := prong_base + Vector2(side * prong_len * 0.62, -prong_len)
				var seg := tip - prong_base
				var seg_len2: float = maxf(seg.length_squared(), 1.0)
				var pt := Vector2(fx, fy) - prong_base
				var proj := clampf(pt.dot(seg) / seg_len2, 0.0, 1.0)
				var closest: Vector2 = seg * proj
				var d := (pt - closest).length()
				if d <= radius * 0.05:
					a = maxf(a, clampf((radius * 0.05 - d + 1.0) / 1.0, 0.0, 1.0))
					cc = metal.lightened(0.2)
				# Огонёк на кончике уса
				if proj > 0.96 and pt.distance_to(seg) <= radius * 0.12:
					a = maxf(a, 1.0)
					cc = bright

			if a <= 0.001:
				continue
			cc.a = a
			img.set_pixel(x, y, cc)
	var tex := ImageTexture.create_from_image(img)
	_cache[ck] = tex
	return tex

# ============================================================================
# Портал между этажами: светящееся закрученное кольцо с тёмной воронкой в центре
# и мягкой аурой. Узел двери медленно вращает спрайт — получается «крутящийся
# портал», визуально явно отличный от кристаллов (станции/осколки/выход).
static func make_portal(radius: int, color: Color) -> ImageTexture:
	var ck := "portal_%d_%s" % [radius, color.to_html(true)]
	if _cache.has(ck):
		return _cache[ck]
	var glow := int(round(radius * 1.5))
	var d := (radius + glow) * 2
	var c := d * 0.5
	var img := Image.create_empty(d, d, false, Image.FORMAT_RGBA8)
	var bright := Color(minf(1.0, color.r * 1.7 + 0.25), minf(1.0, color.g * 1.7 + 0.25), minf(1.0, color.b * 1.7 + 0.25), 1.0)
	var void_col := Color(0.02, 0.03, 0.06, 1.0)
	for y in d:
		for x in d:
			var vx := float(x) - c
			var vy := float(y) - c
			var dist := sqrt(vx * vx + vy * vy)
			var t := dist / float(radius)               # 1.0 — внешний край кольца
			var ang := atan2(vy, vx)
			var col := color
			var a := 0.0
			if t <= 1.0:
				var swirl := 0.5 + 0.5 * sin(ang * 2.0 + t * 10.0)   # закрученные рукава
				var ring := exp(-pow((t - 0.82) / 0.16, 2.0))        # яркое кольцо у края
				var fill := clampf(1.0 - t, 0.0, 1.0)                # заливка к центру
				var lum := ring + fill * (0.16 + 0.24 * swirl)
				col = color.lerp(bright, clampf(ring, 0.0, 1.0))
				col = col.lerp(void_col, clampf(0.52 - t, 0.0, 0.52) * 1.1)  # тёмная воронка
				a = clampf(lum, 0.0, 1.0)
			else:
				var g := clampf(1.0 - (t - 1.0) / (float(glow) / float(radius)), 0.0, 1.0)
				col = color
				a = g * g * 0.5
			col.a = clampf(a, 0.0, 1.0)
			img.set_pixel(x, y, col)
	var tex := ImageTexture.create_from_image(img)
	_cache[ck] = tex
	return tex

# ============================================================================
# Маяк-вышка (v1.9): узкий сигнальный шпиль с ярким огоньком на вершине —
# силуэт нарочно не похож ни на кристалл (make_gem — осколки/выход), ни на
# кольцо-воронку (make_portal — двери) — узкий треугольный столб.
static func make_beacon(radius: int, color: Color) -> ImageTexture:
	var ck := "beacon_%d_%s" % [radius, color.to_html(true)]
	if _cache.has(ck):
		return _cache[ck]
	var w := radius * 2
	var h := int(round(radius * 3.4))
	var halo := int(round(radius * 0.7))
	var wdt := w + halo * 2
	var hgt := h + halo * 2
	var img := Image.create_empty(wdt, hgt, false, Image.FORMAT_RGBA8)
	var cx := wdt * 0.5
	var top_y := halo * 0.5
	var base_y := hgt - halo * 0.5
	var bright := Color(minf(1.0, color.r * 1.6 + 0.2), minf(1.0, color.g * 1.6 + 0.2), minf(1.0, color.b * 1.6 + 0.2), 1.0)
	for y in hgt:
		for x in wdt:
			var fy := float(y)
			var dx := float(x) - cx
			var adx := absf(dx)
			var in_range := fy >= top_y and fy <= base_y
			var t := clampf((fy - top_y) / maxf(base_y - top_y, 1.0), 0.0, 1.0)
			var hw := lerpf(radius * 0.10, radius * 0.55, t)
			var edge := hw - adx
			var body_a := clampf((edge + 1.0) / 1.0, 0.0, 1.0) if in_range else 0.0
			# Наконечник — яркий огонёк над самой вышкой.
			var tip_d := Vector2(dx, fy - top_y * 0.55).length()
			var tip_a := clampf(1.0 - tip_d / (radius * 0.5), 0.0, 1.0)
			var a: float = maxf(body_a, tip_a * 0.9)
			if a <= 0.001:
				continue
			var cc := color.lerp(bright, clampf(1.0 - t, 0.0, 1.0) * 0.7)
			if tip_a > 0.0:
				cc = cc.lerp(Color(1, 1, 1, 1), tip_a * tip_a * 0.85)
			cc.a = a
			img.set_pixel(x, y, cc)
	var tex := ImageTexture.create_from_image(img)
	_cache[ck] = tex
	return tex

# ============================================================================
# Значок замка (v1.9) — индикатор «портал заперт» над выходом, пока не
# собраны все осколки уровня.
static func make_lock(size: int, color: Color) -> ImageTexture:
	var ck := "lock_%d_%s" % [size, color.to_html(true)]
	if _cache.has(ck):
		return _cache[ck]
	var img := Image.create_empty(size, size, false, Image.FORMAT_RGBA8)
	var cx := size * 0.5
	var body_w := size * 0.56
	var body_y0 := size * 0.46
	var body_y1 := body_y0 + size * 0.42
	var shackle_r := size * 0.22
	for y in size:
		for x in size:
			var fx := float(x)
			var fy := float(y)
			var a := 0.0
			if fy >= body_y0 and fy <= body_y1 and absf(fx - cx) <= body_w * 0.5:
				a = 1.0
			var dd := Vector2(fx - cx, fy - body_y0).length()
			if fy <= body_y0 + 1.0 and dd >= shackle_r - size * 0.09 and dd <= shackle_r:
				a = 1.0
			if a > 0.0:
				img.set_pixel(x, y, Color(color.r, color.g, color.b, a))
	var tex := ImageTexture.create_from_image(img)
	_cache[ck] = tex
	return tex

# ============================================================================
# Гости лабиринта (v1.9) — раньше все три (Беглец/Кроты/Вор) рисовались тем же
# гемом (make_gem), что осколки/станции/выход — «тоже ромбики» неотличимы друг
# от друга и от прочих объектов. Три отдельных силуэта по смыслу гостя.

# Беглец: комета/искра — яркая голова + сужающийся хвост, читается как «бежит».
static func make_runner_spark(radius: int, color: Color) -> ImageTexture:
	var ck := "runner_%d_%s" % [radius, color.to_html(true)]
	if _cache.has(ck):
		return _cache[ck]
	var head_r := radius * 0.55
	var tail_len := radius * 2.6
	var halo := int(round(radius * 0.6))
	var wdt := int(tail_len + head_r * 2 + halo * 2)
	var hgt := int(head_r * 2.4 + halo * 2)
	var img := Image.create_empty(wdt, hgt, false, Image.FORMAT_RGBA8)
	var head_cx := wdt - halo - head_r
	var cy := hgt * 0.5
	var bright := Color(minf(1.0, color.r * 1.6 + 0.2), minf(1.0, color.g * 1.6 + 0.2), minf(1.0, color.b * 1.6 + 0.2), 1.0)
	var tail_start := head_cx - head_r
	for y in hgt:
		for x in wdt:
			var fx := float(x)
			var fy := float(y)
			var a := 0.0
			var cc := color
			var dhead := Vector2(fx - head_cx, fy - cy).length()
			if dhead <= head_r:
				a = 1.0
				var core := clampf(1.0 - dhead / head_r, 0.0, 1.0)
				cc = color.lerp(Color(1, 1, 1, 1), core * core * 0.7)
			if fx <= tail_start and fx >= tail_start - tail_len:
				var t := (tail_start - fx) / maxf(tail_len, 1.0)
				var hw := head_r * 0.85 * (1.0 - t)
				var edge := hw - absf(fy - cy)
				var ta := clampf((edge + 1.0) / 1.0, 0.0, 1.0) * (1.0 - t * 0.3)
				if ta > a:
					a = ta
					cc = color.lerp(bright, clampf(1.0 - t, 0.0, 1.0) * 0.5)
			if a > 0.0:
				cc.a = a
				img.set_pixel(x, y, cc)
	var tex := ImageTexture.create_from_image(img)
	_cache[ck] = tex
	return tex

# Кроты: земляной холмик-нора — купол с тёмным лазом у основания.
static func make_molehill(radius: int, color: Color) -> ImageTexture:
	var ck := "molehill_%d_%s" % [radius, color.to_html(true)]
	if _cache.has(ck):
		return _cache[ck]
	var w := radius * 2.4
	var h := radius * 1.7
	var halo := int(round(radius * 0.5))
	var wdt := int(w + halo * 2)
	var hgt := int(h + halo * 2)
	var img := Image.create_empty(wdt, hgt, false, Image.FORMAT_RGBA8)
	var cx := wdt * 0.5
	var base_y := hgt - halo
	var top_y := halo
	var dark := Color(0.05, 0.04, 0.03, 1.0)
	for y in hgt:
		for x in wdt:
			var fx := float(x)
			var fy := float(y)
			var a := 0.0
			var cc := color
			if fy <= base_y:
				var ex := (fx - cx) / (w * 0.5)
				var ey := (fy - base_y) / h
				var ed := ex * ex + ey * ey
				if ed <= 1.0:
					a = 1.0
					var shade := clampf(1.0 - (fy - top_y) / maxf(base_y - top_y, 1.0), 0.0, 1.0)
					cc = color.darkened(0.15 * (1.0 - shade)).lightened(0.15 * shade)
			var hd := Vector2((fx - cx) / (radius * 0.5), (fy - base_y + radius * 0.25) / (radius * 0.32)).length()
			if hd <= 1.0:
				a = maxf(a, clampf(1.0 - hd, 0.0, 1.0))
				cc = dark
			if a > 0.0:
				cc.a = a
				img.set_pixel(x, y, cc)
	var tex := ImageTexture.create_from_image(img)
	_cache[ck] = tex
	return tex

# Вор: мешок с добычей — узкое завязанное горлышко, раздутое книзу тело.
static func make_sack(radius: int, color: Color) -> ImageTexture:
	var ck := "sack_%d_%s" % [radius, color.to_html(true)]
	if _cache.has(ck):
		return _cache[ck]
	var w := radius * 2.0
	var h := radius * 2.3
	var halo := int(round(radius * 0.5))
	var wdt := int(w + halo * 2)
	var hgt := int(h + halo * 2)
	var img := Image.create_empty(wdt, hgt, false, Image.FORMAT_RGBA8)
	var cx := wdt * 0.5
	var top_y := halo + h * 0.12
	var bot_y := hgt - halo
	var bright := Color(minf(1.0, color.r * 1.5 + 0.2), minf(1.0, color.g * 1.5 + 0.2), minf(1.0, color.b * 1.5 + 0.2), 1.0)
	for y in hgt:
		for x in wdt:
			var fx := float(x)
			var fy := float(y)
			var a := 0.0
			var cc := color
			if fy >= top_y and fy <= bot_y:
				var t := (fy - top_y) / maxf(bot_y - top_y, 1.0)
				var hw := radius * 0.22 + radius * 0.62 * sin(t * PI * 0.5)
				var dx := fx - cx
				var edge := hw - absf(dx)
				a = clampf((edge + 1.0) / 1.0, 0.0, 1.0)
				if a > 0.0:
					var b := clampf(1.0 - absf(dx) / maxf(hw, 1.0), 0.0, 1.0)
					cc = color.lerp(bright, b * 0.4)
			var knot_d := Vector2(fx - cx, fy - top_y).length()
			if knot_d <= radius * 0.16:
				a = maxf(a, 1.0)
				cc = color.darkened(0.3)
			if a > 0.0:
				cc.a = a
				img.set_pixel(x, y, cc)
	var tex := ImageTexture.create_from_image(img)
	_cache[ck] = tex
	return tex

# ============================================================================
# Текстура-«прожектор»: апекс у левого-центра, луч веером вправо. Конус ярче по
# оси и спадает к краям и вдаль. Используется PointLight2D игрока с offset=
# (size/2,0), чтобы апекс совпал с позицией игрока; узел поворачивается в сторону
# движения. RGB=белый, A=интенсивность (как у make_light).
static func make_cone_light(size: int, half_angle_deg: float = 32.0) -> ImageTexture:
	var ck := "cone_%d_%.2f" % [size, half_angle_deg]
	if _cache.has(ck):
		return _cache[ck]
	var img := Image.create_empty(size, size, false, Image.FORMAT_RGBA8)
	var apex := Vector2(0.0, size * 0.5)
	var ha := deg_to_rad(half_angle_deg)
	for y in size:
		for x in size:
			var d := Vector2(float(x), float(y)) - apex
			var dist := d.length()
			var a := 0.0
			if dist > 1.0:
				var ang := absf(atan2(d.y, d.x))            # угол от оси +x
				if ang < ha:
					var ang_fall := 1.0 - ang / ha          # ярче по оси
					ang_fall = ang_fall * ang_fall
					var dist_fall := clampf(1.0 - dist / float(size), 0.0, 1.0)
					dist_fall = dist_fall * dist_fall
					a = ang_fall * dist_fall
			img.set_pixel(x, y, Color(1, 1, 1, clampf(a, 0.0, 1.0)))
	var tex := ImageTexture.create_from_image(img)
	_cache[ck] = tex
	return tex

# ============================================================================
# Враг: тёмное «ядро-пустота» с зубчатой светящейся короной, горячим ободком и
# глазом-зрачком + мягкая внешняя аура. Силуэт зависит от типа:
#   0 SLOW   — тяжёлый, 8 коротких шипов, фиолет
#   1 FAST   — рваный, 3 длинных шипа (наконечник стрелы), оранжевый
#   2 CYCLIC — пульсар, 6 шипов, бирюза
static func make_enemy(kind: int, radius: int) -> ImageTexture:
	var ck := "enemy_%d_%d" % [kind, radius]
	if _cache.has(ck):
		return _cache[ck]
	var col: Color
	var spikes: int
	var spikiness: float
	match kind:
		0:
			col = Color(0.80, 0.18, 1.0); spikes = 8; spikiness = 0.30
		1:
			col = Color(1.0, 0.34, 0.08); spikes = 3; spikiness = 0.55
		3:
			col = Color(0.75, 0.15, 0.25); spikes = 12; spikiness = 0.15   # Страж: зубчатая броня
		4:
			col = Color(0.75, 0.85, 1.0); spikes = 4; spikiness = 0.65    # Фантом: рваный клинок
		5:
			col = Color(0.45, 0.95, 0.25); spikes = 5; spikiness = 0.45   # Пиявка
		_:
			col = Color(0.10, 1.0, 0.80); spikes = 6; spikiness = 0.40
	var glow := int(round(radius * 1.15))
	var d := (radius + glow) * 2
	var c := d * 0.5
	var img := Image.create_empty(d, d, false, Image.FORMAT_RGBA8)
	for y in d:
		for x in d:
			var v := Vector2(float(x) - c, float(y) - c)
			var dist := v.length()
			var ang := atan2(v.y, v.x)
			var spike := 0.5 + 0.5 * cos(ang * spikes)          # 0..1 пульсация короны
			var r_edge := float(radius) * (1.0 - spikiness + spikiness * spike)
			var cc := col
			var a := 0.0
			if dist <= r_edge:
				var t := dist / maxf(r_edge, 1.0)               # 0 центр -> 1 край
				cc = col.lerp(Color(0, 0, 0, 1), clampf(1.0 - t * 1.7, 0.0, 1.0) * 0.85)  # тёмная сердцевина
				cc = cc.lerp(Color(1, 1, 1, 1), clampf((t - 0.68) / 0.32, 0.0, 1.0) * 0.6)  # горячий ободок
				a = 1.0
				if dist < radius * 0.24:                        # глаз-зрачок
					cc = col.lerp(Color(1, 1, 1, 1), 0.75)
			else:
				var g := clampf(1.0 - (dist - r_edge) / float(glow), 0.0, 1.0)
				cc = col
				a = g * g * 0.8
			cc.a = a
			img.set_pixel(x, y, cc)
	var tex := ImageTexture.create_from_image(img)
	_cache[ck] = tex
	return tex

# ============================================================================
# Игрок: энергетический шар — бело-горячее ядро, холодный энергетический ободок
# и мягкая аура. Сам игрок ещё несёт PointLight2D, так что это «тело» сущности.
static func make_player_orb(radius: int) -> ImageTexture:
	# Плотное бело-горячее ядро -> холодный ободок -> мягкое свечение. Альфа спадает
	# МОНОТОННО (без скачка ядро/ореол), поэтому никакой паразитной обводки-кольца.
	var ck := "orb_%d" % radius
	if _cache.has(ck):
		return _cache[ck]
	var rim := Color(0.6, 0.86, 1.0)
	var outer := int(round(radius * 2.4))        # полный радиус со свечением
	var d := outer * 2
	var c := d * 0.5
	var img := Image.create_empty(d, d, false, Image.FORMAT_RGBA8)
	for y in d:
		for x in d:
			var dist := Vector2(float(x) - c, float(y) - c).length()
			var col: Color
			var a: float
			if dist <= float(radius):
				# Тело: белое в центре, плавно к холодному ободку у края; альфа = 1
				col = Color(1, 1, 1, 1).lerp(rim, smoothstep(0.45, 1.0, dist / float(radius)))
				a = 1.0
			else:
				# Свечение наружу — продолжает ободок, альфа гаснет без скачка
				var h := clampf(1.0 - (dist - float(radius)) / float(outer - radius), 0.0, 1.0)
				col = rim
				a = pow(h, 2.4)
			col.a = clampf(a, 0.0, 1.0)
			img.set_pixel(x, y, col)
	var tex := ImageTexture.create_from_image(img)
	_cache[ck] = tex
	return tex
