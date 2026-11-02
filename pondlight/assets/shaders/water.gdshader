// Pixel-art water: palette-respecting shimmer dashes, slow dithered swell and shore foam.
// Everything is computed on the 640x360 pixel grid, so it never produces sub-pixel blur.
shader_type canvas_item;

uniform sampler2D flow_tex : filter_nearest;
uniform vec4 hi_color : source_color = vec4(0.769, 0.961, 0.886, 1.0);
uniform vec4 mid_color : source_color = vec4(0.498, 0.863, 0.761, 1.0);
uniform vec4 foam_color : source_color = vec4(0.91, 1.0, 0.96, 1.0);
uniform float rain = 0.0;
uniform float speed = 1.0;
const vec2 SIZE = vec2(640.0, 360.0);

float hash(vec2 p) {
	return fract(sin(dot(p, vec2(127.1, 311.7))) * 43758.5453);
}

float bayer4(vec2 p) {
	const float m[16] = {0.0, 8.0, 2.0, 10.0, 12.0, 4.0, 14.0, 6.0, 3.0, 11.0, 1.0, 9.0, 15.0, 7.0, 13.0, 5.0};
	int x = int(mod(p.x, 4.0));
	int y = int(mod(p.y, 4.0));
	return (m[x + y * 4] + 0.5) / 16.0;
}

void fragment() {
	vec2 px = floor(UV * SIZE);
	vec4 base = texture(TEXTURE, UV);
	if (base.a < 0.5) {
		discard;
	}
	vec4 fl = texture(flow_tex, UV);
	float t = TIME * speed;
	vec3 col = base.rgb;
	float bay = bayer4(px);

	// broad slow swell, dithered so it stays in the pixel-art idiom
	float swell = sin(px.x * 0.045 + px.y * 0.23 - t * 0.8) * 0.55 + sin(px.x * 0.12 - px.y * 0.08 + t * 0.55) * 0.45;
	if (swell > 0.62 + bay * 0.3) {
		col = mix(col, mid_color.rgb, 0.22 * fl.r);
	}

	// shimmer dashes: short horizontal highlights that blink in and out
	float drift = floor(t * 1.5);
	vec2 cell = vec2(floor((px.x + drift) / 11.0), floor(px.y / 5.0));
	float h = hash(cell);
	float life = fract(t * (0.18 + h * 0.3) + h * 13.0);
	float wx = mod(px.x + drift, 11.0);
	float wy = mod(px.y, 5.0);
	float len = 2.0 + floor(h * 4.0);
	if (h > 0.42 && wy == 2.0 && wx >= 3.0 && wx < 3.0 + len && life < 0.32) {
		col = mix(col, life < 0.12 ? hi_color.rgb : mid_color.rgb, fl.r);
	}

	// rain darkens and roughens the surface a little
	col *= 1.0 - rain * 0.08;
	if (rain > 0.0 && hash(px + floor(t * 8.0)) > 0.994) {
		col = mix(col, mid_color.rgb, 0.8);
	}

	// shore foam that laps in and out
	if (fl.g > 0.5) {
		float lap = sin(px.x * 0.35 + px.y * 0.2 + t * 1.7) * 0.5 + 0.5;
		if (lap > 0.35 + bay * 0.5) {
			col = mix(col, foam_color.rgb, 0.7);
		}
	}
	COLOR = vec4(col, 1.0);
}
