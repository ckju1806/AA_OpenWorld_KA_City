// Wasser (eigenes Werk): bewegte Normalen aus überlagerten Wellen, Weltkoordinaten; Tiefe über Fresnel angedeutet.
shader_type spatial;
render_mode cull_back;

uniform vec3 deep_color : source_color = vec3(0.1, 0.19, 0.24);
uniform vec3 shallow_color : source_color = vec3(0.2, 0.32, 0.36);
uniform float wave_scale = 0.35;
uniform float speed = 0.6;
uniform float rain = 0.0;

varying vec3 wpos;

void vertex() {
	wpos = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xyz;
}

float h(vec2 p) {
	return fract(sin(dot(p, vec2(127.1, 311.7))) * 43758.5453);
}

void fragment() {
	vec2 p = wpos.xz * wave_scale;
	float t = TIME * speed;
	float dx = cos(p.x * 1.7 + t) * 0.5 + cos(p.x * 3.1 - p.y * 1.3 + t * 1.4) * 0.3 + cos((p.x + p.y) * 5.3 + t * 2.1) * 0.12;
	float dz = sin(p.y * 1.9 - t * 1.1) * 0.5 + sin(p.y * 2.9 + p.x * 1.1 - t * 1.7) * 0.3 + sin((p.y - p.x) * 5.7 - t * 2.3) * 0.12;
	// Regentropfen: kleine, schnelle Störungen
	float drops = rain * (h(floor(wpos.xz * 3.0) + floor(TIME * 6.0)) > 0.93 ? 1.0 : 0.0);
	vec3 n = normalize(vec3(dx * 0.12 + drops * 0.2, 1.0, dz * 0.12));
	NORMAL = normalize((VIEW_MATRIX * vec4(n, 0.0)).xyz);
	float fres = pow(1.0 - clamp(dot(NORMAL, VIEW), 0.0, 1.0), 3.0);
	ALBEDO = mix(deep_color, shallow_color, fres);
	ROUGHNESS = 0.04;
	METALLIC = 0.35;
	SPECULAR = 0.8;
}
