// Prismatic fish: a holographic foil. Hue bands slide across the sprite in pixel-stepped diagonals,
// a bright shine sweeps over it now and then. Works on the sprite's own pixel grid (no blur).
shader_type canvas_item;

uniform float strength = 0.38;
uniform float band = 6.0;

vec3 hue(float h) {
	h = fract(h);
	vec3 k = abs(fract(vec3(h) + vec3(0.0, 2.0 / 3.0, 1.0 / 3.0)) * 6.0 - 3.0) - 1.0;
	return clamp(k, 0.0, 1.0);
}

void fragment() {
	vec4 c = texture(TEXTURE, UV);
	vec2 px = floor(UV / TEXTURE_PIXEL_SIZE);
	float lum = dot(c.rgb, vec3(0.3, 0.59, 0.11));
	float h = floor((px.x + px.y - TIME * 18.0) / band) * 0.09 + lum * 0.4;
	vec3 foil = mix(vec3(lum), hue(h), 0.75) * (0.45 + lum * 0.9);
	vec3 col = mix(c.rgb, foil, strength * step(0.08, lum));
	float diag = px.x - px.y * 0.6 - mod(TIME * 60.0, 260.0) + 40.0;
	if (diag > 0.0 && diag < 3.0) {
		col = mix(col, vec3(1.0), 0.7);
	}
	COLOR = vec4(col, c.a);
}
