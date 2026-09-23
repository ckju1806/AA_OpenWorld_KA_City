// Dachziegel (eigenes Werk): Reihen entlang UV.y (Meter hangabwärts), versetzte Fugen.
shader_type spatial;
render_mode cull_back;

void fragment() {
	float row_h = 0.34;
	float tile_w = 0.30;
	float row = floor(UV.y / row_h);
	float lx = fract(UV.x / tile_w + row * 0.5);
	float ly = fract(UV.y / row_h);
	float shade = 0.78 + 0.22 * smoothstep(0.0, 0.35, ly);
	if (lx < 0.05) { shade *= 0.82; }
	float n = fract(sin(dot(vec2(floor(UV.x / tile_w + row * 0.5), row), vec2(12.9898, 78.233))) * 43758.5453);
	ALBEDO = COLOR.rgb * shade * (0.92 + n * 0.16);
	ROUGHNESS = 0.8;
}
