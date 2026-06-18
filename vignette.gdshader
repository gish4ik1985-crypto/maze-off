shader_type canvas_item;
render_mode blend_add;

// Аддитивная виньетка по краям экрана: к центру эффекта нет, к краям —
// свечение цвета tint. Сила задаётся intensity (может быть > 1 для пущего
// свечения). aspect выравнивает форму под соотношение сторон окна.

uniform vec4 tint : source_color = vec4(1.0, 0.82, 0.38, 1.0);
uniform float intensity : hint_range(0.0, 4.0) = 0.0;
uniform float inner : hint_range(0.0, 1.5) = 0.45;
uniform float outer : hint_range(0.0, 2.0) = 1.05;
uniform float aspect = 1.777;

void fragment() {
	vec2 p = UV - vec2(0.5);
	p.x *= aspect;
	float maxd = length(vec2(0.5 * aspect, 0.5));
	float d = length(p) / maxd;
	float v = smoothstep(inner, outer, d);
	COLOR = vec4(tint.rgb, v * intensity);
}
