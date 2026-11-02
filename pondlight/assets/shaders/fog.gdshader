// Drifting low fog with dithered alpha steps (Frostmere).
shader_type canvas_item;

uniform float density = 0.22;
uniform vec4 fog_color : source_color = vec4(0.92, 0.96, 1.0, 1.0);
const vec2 SIZE = vec2(640.0, 360.0);

float hash(vec2 p) {
	return fract(sin(dot(p, vec2(41.3, 289.1))) * 15731.743);
}

float vnoise(vec2 p) {
	vec2 i = floor(p);
	vec2 f = fract(p);
	f = f * f * (3.0 - 2.0 * f);
	float a = hash(i);
	float b = hash(i + vec2(1.0, 0.0));
	float c = hash(i + vec2(0.0, 1.0));
	float d = hash(i + vec2(1.0, 1.0));
	return mix(mix(a, b, f.x), mix(c, d, f.x), f.y);
}

float bayer4(vec2 p) {
	const float m[16] = {0.0, 8.0, 2.0, 10.0, 12.0, 4.0, 14.0, 6.0, 3.0, 11.0, 1.0, 9.0, 15.0, 7.0, 13.0, 5.0};
	int x = int(mod(p.x, 4.0));
	int y = int(mod(p.y, 4.0));
	return (m[x + y * 4] + 0.5) / 16.0;
}

void fragment() {
	vec2 px = floor(UV * SIZE);
	vec2 q = vec2(px.x * 0.012 + TIME * 0.03, px.y * 0.03);
	float n = vnoise(q) * 0.6 + vnoise(q * 2.3 + vec2(-TIME * 0.05, 3.0)) * 0.4;
	float a = smoothstep(0.42, 0.85, n) * density * (0.5 + 0.5 * smoothstep(80.0, 300.0, px.y));
	a = floor(a * 6.0 + bayer4(px)) / 6.0;
	COLOR = vec4(fog_color.rgb, a);
}
