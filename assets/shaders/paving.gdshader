// Pflaster/Gehwegplatten (eigenes Werk), Weltkoordinaten-basiert (nahtlos zwischen Meshes).
shader_type spatial;
render_mode cull_back;

uniform vec3 base_color : source_color = vec3(0.62, 0.6, 0.57);
uniform vec3 grout_color : source_color = vec3(0.42, 0.41, 0.4);
uniform vec2 tile = vec2(0.8, 0.8);
uniform float variation = 0.08;
uniform float grout = 0.04;

varying vec3 wpos;

void vertex() {
	wpos = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xyz;
}

void fragment() {
	vec2 p = wpos.xz / tile;
	float row = floor(p.y);
	p.x += row * 0.5;
	vec2 cell = floor(p);
	vec2 f = fract(p);
	float g = grout / min(tile.x, tile.y);
	float edge = step(f.x, g) + step(f.y, g);
	float n = fract(sin(dot(cell, vec2(12.9898, 78.233))) * 43758.5453);
	vec3 col = base_color * (1.0 - variation + n * variation * 2.0);
	if (abs(NORMAL.y) < 0.5) {
		col = base_color * 1.08;
	} else if (edge > 0.0) {
		col = grout_color;
	}
	ALBEDO = col;
	ROUGHNESS = 0.88;
}
