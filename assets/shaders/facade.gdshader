// Fassaden-Shader (eigenes Werk): Fenstergitter, Ladenzone mit Schild, Türen, Gesimse,
// abendlich beleuchtete Fenster. Parameter pro Fassade über Vertex-Daten:
//   COLOR.rgb = Wandfarbe, COLOR.a = Zufallswert
//   UV = (Meter entlang der Fassade, Meter über Gebäudesockel)
//   UV2 = (Fassadenlänge, Gebäudehöhe)
//   CUSTOM0 = (Laden 0/1, Schild-Farbton 0..1, Stil 0 normal/1 Palast/2 modern/3 Brandwand, Geschosshöhe)
shader_type spatial;
render_mode cull_back, diffuse_burley, specular_schlick_ggx;

uniform float night = 0.75;
uniform vec3 lit_color : source_color = vec3(1.0, 0.76, 0.42);
uniform vec3 glass_color : source_color = vec3(0.09, 0.12, 0.16);
uniform vec3 trim_color : source_color = vec3(0.93, 0.91, 0.86);

varying vec4 v_custom;
varying vec2 v_dims;

void vertex() {
	v_custom = CUSTOM0;
	v_dims = UV2;
}

float hash(vec2 p) {
	return fract(sin(dot(p, vec2(127.1, 311.7))) * 43758.5453);
}

void fragment() {
	vec3 wall = COLOR.rgb;
	float seed = COLOR.a;
	float shop = v_custom.x;
	float sign_hue = v_custom.y;
	float style = v_custom.z;
	float fh = v_custom.w > 0.5 ? v_custom.w : 3.3;
	float L = max(v_dims.x, 0.5);
	float H = max(v_dims.y, 0.5);
	float u = UV.x;
	float v = UV.y;
	float grain = hash(floor(vec2(u, v) * 3.0) + seed * 13.0) * 0.05 - 0.025;
	vec3 col = wall * (1.0 + grain);
	float rough = 0.92;
	float metal = 0.0;
	vec3 emit = vec3(0.0);

	bool palace = style > 0.5 && style < 1.5;
	bool modern = style > 1.5 && style < 2.5;
	bool blank = style > 2.5;
	float gf = shop > 0.5 ? 4.3 : fh + 0.3;
	if (palace) { gf = 5.2; }

	if (!blank) {
		float cell_w = palace ? 4.2 : (modern ? 2.4 : 2.8 + seed * 0.9);
		float cells = max(1.0, floor(L / cell_w));
		float cw = L / cells;
		float cu = mod(u, cw) / cw;
		float ci = floor(u / cw);
		float top = H - (palace ? 1.6 : 1.0);
		// Obergeschosse
		if (v > gf && v < top) {
			float ffh = palace ? 5.0 : fh;
			float fv = mod(v - gf, ffh);
			float fi = floor((v - gf) / ffh);
			float wh = palace ? 3.0 : (modern ? ffh - 1.0 : 1.75);
			float ww = palace ? 1.5 : (modern ? cw - 0.35 : 1.25);
			float hx = clamp(ww / cw * 0.5, 0.05, 0.47);
			float wy0 = (ffh - wh) * 0.55;
			bool in_win = abs(cu - 0.5) < hx && fv > wy0 && fv < wy0 + wh;
			if (in_win) {
				float lit = step(1.0 - night * 0.5, hash(vec2(ci + seed * 31.0, fi + seed * 7.0)));
				col = glass_color;
				rough = 0.12;
				metal = 0.35;
				float lx = abs(cu - 0.5) * cw;
				float ly = abs(fv - (wy0 + wh * 0.62));
				if (!modern && (lx < 0.035 || ly < 0.035)) {
					col = trim_color * 0.95;
					rough = 0.6;
					metal = 0.0;
				} else {
					emit = lit_color * lit * 1.6;
				}
			} else {
				bool frame = abs(cu - 0.5) < hx + 0.04 && fv > wy0 - 0.14 && fv < wy0 + wh + 0.08;
				if (frame && !modern) { col = mix(wall, trim_color, 0.65); }
				if (fv < 0.14 && !modern) { col *= 0.86; }
			}
		}
		// Erdgeschoss
		if (v <= gf) {
			if (shop > 0.5) {
				if (v > gf - 0.8 && v < gf - 0.12) {
					vec3 sc = 0.5 + 0.5 * cos(6.2831 * (sign_hue + vec3(0.0, 0.33, 0.67)));
					col = sc * 0.8;
					rough = 0.45;
					emit = sc * 0.45 * night;
				} else if (v > 0.5 && v < gf - 1.0 && cu > 0.07 && cu < 0.93) {
					// Schaufenster: dunkles Glas, warmer Innenraum mit Verlauf, Sprossen
					float grad = clamp((v - 0.5) / max(gf - 1.5, 0.5), 0.0, 1.0);
					vec3 inner = mix(vec3(0.34, 0.27, 0.2), vec3(0.16, 0.14, 0.13), grad);
					col = mix(vec3(0.07, 0.08, 0.09), inner, 0.55);
					rough = 0.32;
					metal = 0.0;
					emit = vec3(1.0, 0.8, 0.55) * (0.2 - grad * 0.12) * night;
					// Auslagen (angedeutete Waren im unteren Drittel)
					float slot = floor(u * 1.4);
					if (v < 1.5 && fract(u * 1.4) < 0.55) {
						vec3 ware = 0.5 + 0.5 * cos(6.2831 * (hash(vec2(slot, seed * 9.0)) + vec3(0.0, 0.33, 0.67)));
						col = ware * 0.45;
						emit = ware * 0.12 * night;
					}
					if (abs(cu - 0.5) < 0.012 || v < 0.62) {
						col = vec3(0.18, 0.18, 0.19);
						emit = vec3(0.0);
					}
				} else {
					col = wall * 0.8;
				}
			} else {
				bool door = mod(ci + floor(seed * 7.0), 4.0) < 1.0;
				if (door && cu > 0.3 && cu < 0.7 && v > 0.45 && v < 2.6) {
					col = vec3(0.30, 0.19, 0.11);
					rough = 0.6;
					if (v > 2.2) { emit = lit_color * 0.3 * night; }
				} else if (!door && abs(cu - 0.5) < 0.2 && v > 1.1 && v < 2.8) {
					col = glass_color;
					rough = 0.12;
					metal = 0.35;
				}
			}
			if (v < 0.45) { col = wall * 0.6; }
		}
		// Traufgesims
		if (v > H - 0.55) { col = mix(wall, trim_color, 0.55) * 0.95; }
	} else {
		if (v < 0.45) { col = wall * 0.6; }
	}
	ALBEDO = col;
	ROUGHNESS = rough;
	METALLIC = metal;
	EMISSION = emit;
}
