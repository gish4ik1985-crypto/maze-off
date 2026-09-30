shader_type canvas_item;

// Цветокоррекция всего экрана (v6.9, пресеты «Мягкий» / «Минимальный»): снимает
// часть насыщенности, прижимает самые яркие света и слегка приподнимает чёрный
// тёмно-синим — чтобы неон меньше резал глаза при долгой игре. Накладывается
// поверх всего (меню, мир, HUD) одним слоем; «Стандарт» его просто выключает.

uniform sampler2D screen_tex : hint_screen_texture, filter_linear;
uniform float saturation = 1.0;    // 1 — как есть
uniform float peak = 1.0;          // во сколько раз ослабить самые яркие света
uniform float lift = 0.0;          // подъём чёрного
uniform vec3 lift_color : source_color = vec3(0.05, 0.07, 0.13);

void fragment() {
	vec3 c = texture(screen_tex, SCREEN_UV).rgb;
	float l = dot(c, vec3(0.299, 0.587, 0.114));
	c = mix(vec3(l), c, saturation);
	// Мягкое плечо: яркое сжимается сильнее, тёмное почти не меняется.
	float k = 1.0 - peak;
	c = c * (1.0 - k * smoothstep(0.35, 1.0, max(c.r, max(c.g, c.b))));
	c += lift_color * lift * (1.0 - c);
	COLOR = vec4(c, 1.0);
}
