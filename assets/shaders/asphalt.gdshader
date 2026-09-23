// Asphalt (eigenes Werk): feines Rauschen und großflächige Flicken, Weltkoordinaten.
shader_type spatial;
render_mode cull_back;

uniform vec3 base_color : source_color = vec3(0.2, 0.2, 0.215);

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
	float a = hash(i);
	float b = hash(i + vec2(1.0, 0.0));
	float c = hash(i + vec2(0.0, 1.0));
	float d = hash(i + vec2(1.0, 1.0));
	return mix(mix(a, b, f.x), mix(c, d, f.x), f.y);
}

void fragment() {
	float fine = hash(floor(wpos.xz * 9.0)) * 0.06;
	float patch = vnoise(wpos.xz * 0.045) * 0.1 + vnoise(wpos.xz * 0.21) * 0.05;
	ALBEDO = base_color * (0.9 + fine + patch);
	ROUGHNESS = 0.9 - patch;
}
