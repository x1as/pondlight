// Northern lights curtains, hidden behind anything opaque in the occluder (mountains, trees).
shader_type canvas_item;
render_mode blend_add;

uniform sampler2D occluder : filter_nearest;
uniform float strength = 0.0;
const vec2 SIZE = vec2(640.0, 360.0);

float bayer4(vec2 p) {
	const float m[16] = {0.0, 8.0, 2.0, 10.0, 12.0, 4.0, 14.0, 6.0, 3.0, 11.0, 1.0, 9.0, 15.0, 7.0, 13.0, 5.0};
	int x = int(mod(p.x, 4.0));
	int y = int(mod(p.y, 4.0));
	return (m[x + y * 4] + 0.5) / 16.0;
}

void fragment() {
	vec2 px = floor(UV * SIZE);
	if (strength <= 0.001 || px.y > 90.0 || texture(occluder, UV).a > 0.5) {
		discard;
	}
	float t = TIME;
	float center = 14.0 + sin(px.x * 0.012 + t * 0.18) * 6.0 + sin(px.x * 0.031 - t * 0.11) * 3.0;
	float d = px.y - center;
	// curtain: sharp-ish lower hem fading upward... and a long glow hanging below it
	float band = exp(-max(d, 0.0) * 0.045) * smoothstep(-5.0, 0.0, d);
	float folds = 0.62 + 0.38 * sin(px.x * 0.07 + t * 0.35 + sin(px.x * 0.019 + t * 0.15) * 4.0);
	float streaks = 0.82 + 0.18 * sin(px.x * 0.55 + t * 0.8);
	float a = band * folds * streaks * strength * 0.85;
	a = floor(a * 5.0 + bayer4(px) * 0.999) / 5.0;
	vec3 green = vec3(0.30, 1.0, 0.62);
	vec3 teal = vec3(0.25, 0.85, 0.95);
	vec3 violet = vec3(0.72, 0.42, 1.0);
	vec3 col = mix(green, teal, smoothstep(0.0, 18.0, d));
	col = mix(violet, col, smoothstep(-12.0, -2.0, d));
	COLOR = vec4(col * a, a);
}
