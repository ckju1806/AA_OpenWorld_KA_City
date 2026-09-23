// Rasen/Wiese (eigenes Werk), Weltkoordinaten-basiert.
shader_type spatial;
render_mode cull_back;

uniform vec3 color_a : source_color = vec3(0.24, 0.36, 0.14);
uniform vec3 color_b : source_color = vec3(0.33, 0.42, 0.18);

varying vec3 wpos;

void vertex() {
	wpos = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xyz;
}

float hash(vec2 p) {
	return fract(sin(dot(p, vec2(127.1, 311.7))) * 43758.5453);
}

float vnoise(vec2 p) {
	vec2 i = floor(p);
	vec2 f = fract(p);
	f = f * f * (3.0 - 2.0 * f);
	return mix(mix(hash(i), hash(i + vec2(1, 0)), f.x), mix(hash(i + vec2(0, 1)), hash(i + vec2(1, 1)), f.x), f.y);
}

void fragment() {
	float n = vnoise(wpos.xz * 0.08) * 0.6 + vnoise(wpos.xz * 0.7) * 0.4;
	float fine = hash(floor(wpos.xz * 12.0)) * 0.08;
	ALBEDO = mix(color_a, color_b, n) * (0.95 + fine);
	ROUGHNESS = 0.95;
}
