class_name MazeTextures
extends RefCounted

# Общие генераторы текстур, чтобы не дублировать код в игроке и станциях.

static func make_ball(radius: int, color: Color = Color.WHITE) -> ImageTexture:
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
	return ImageTexture.create_from_image(img)

static func make_light(size: int) -> GradientTexture2D:
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
	return tex

static func make_ring(size: int) -> GradientTexture2D:
	# Светящееся кольцо: яркая полоса ближе к краю (для сонара).
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
	return tex

# ============================================================================
# 2.5D-стена: «выдавленный» каменный блок, освещённый сверху.
# Возвращает CanvasTexture (albedo + normal map) — реальный PointLight2D вживую
# лепит бевели (свет остаётся честным; глубина не запекается жёстко).
# open_mask — какие стороны клетки открыты в проход: N=1, E=2, S=4, W=8.
# Сторона, прилегающая к другой стене, остаётся плоской — соседние блоки
# сливаются в единый массив без швов.
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

	var top := base.lightened(0.10)            # плоская верхняя грань блока
	var bw := maxf(2.0, float(size) * 0.18)    # ширина бевеля (px)
	var tilt := 0.6                            # сила наклона нормали на бевеле (больше => грани ярче вспыхивают)

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

			# --- Albedo: лёгкий направленный тон (основное делает свет) ---
			var bright := rn * 0.30 - rs * 0.34 + rw * 0.12 - re * 0.14
			if rs > 0.0:
				bright = minf(bright, -rs * 0.34)   # нижние углы всегда тёмные
			var c := top.lightened(bright) if bright >= 0.0 else top.darkened(-bright)
			c.a = 1.0
			dimg.set_pixel(x, y, c)

			# --- Normal map (экранное пространство: x вправо, y вниз, z к зрителю) ---
			var nx_screen := (re - rw) * tilt
			var ny_screen := (rs - rn) * tilt   # юг = +вниз, север = -вверх
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

# Гранёный кристалл (вертикальный шестиугольник), освещённый сверху. Используется
# для осколков, станций, выхода и дверей вместо плоского шарика. Текстура выше,
# чем шире; центр кристалла — в центре изображения. Свечение даёт PointLight2D
# самого предмета (как раньше), поэтому здесь только тело кристалла.
static func make_gem(radius: int, color: Color) -> ImageTexture:
	var wdt := radius * 2
	var hgt := int(round(radius * 3.0))
	var img := Image.create_empty(wdt, hgt, false, Image.FORMAT_RGBA8)
	var cx := wdt * 0.5
	var halfw := float(radius)

	var y_top := hgt * 0.04      # верхняя вершина
	var y_us := hgt * 0.30       # верхние «плечи» (макс. ширина)
	var y_ls := hgt * 0.62       # нижние «плечи»
	var y_bot := hgt * 0.97      # нижняя вершина
	var y_table := hgt * 0.16    # линия верхней грани (table)

	for y in hgt:
		for x in wdt:
			var fy := float(y)
			if fy < y_top or fy > y_bot:
				img.set_pixel(x, y, Color(color.r, color.g, color.b, 0.0))
				continue
			# Полуширина силуэта на этой строке (линейно между вершинами).
			var hw := 0.0
			if fy < y_us:
				hw = halfw * (fy - y_top) / (y_us - y_top)
			elif fy < y_ls:
				hw = halfw
			else:
				hw = halfw * (y_bot - fy) / (y_bot - y_ls)

			var dx := float(x) - cx
			var adx := absf(dx)
			var edge := hw - adx
			if edge <= -1.2:
				img.set_pixel(x, y, Color(color.r, color.g, color.b, 0.0))
				continue
			var a := clampf((edge + 1.2) / 1.2, 0.0, 1.0)   # сглаженный край

			# --- Грани ---
			var b := 0.0
			var ridge := 1.0 - clampf(adx / maxf(hw, 1.0), 0.0, 1.0)
			b += ridge * 0.28                                   # центральный блик-ребро
			b += (-dx / maxf(hw, 1.0)) * 0.12                   # левые грани чуть ярче
			if fy < y_table:
				b += 0.30                                        # верхняя грань (table)
			elif fy < y_us:
				b += 0.10
			elif fy > y_ls:
				b -= 0.22 * ((fy - y_ls) / maxf(y_bot - y_ls, 1.0))
			else:
				b -= 0.06
			b += 0.06                                            # слабое внутреннее свечение

			var cc := color.lightened(clampf(b, 0.0, 1.0)) if b >= 0.0 else color.darkened(clampf(-b, 0.0, 1.0))

			# Яркая точка-блик у верхушки.
			var spec := Vector2(float(x) - (cx - halfw * 0.18), fy - y_table * 0.9).length()
			if spec < radius * 0.16:
				cc = cc.lerp(Color(1, 1, 1, 1), (1.0 - spec / (radius * 0.16)) * 0.85)

			cc.a = a
			img.set_pixel(x, y, cc)
	return ImageTexture.create_from_image(img)
