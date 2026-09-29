// Farbfilter für Farbfehlsichtigkeit (Daltonisierung, eigenes Werk nach dem bekannten LMS-Verfahren):
// Farben werden so verschoben, dass Unterschiede für Deuteranopie/Protanopie/Tritanopie besser erkennbar sind.
shader_type canvas_item;

uniform sampler2D screen_tex : hint_screen_texture, filter_linear;
uniform int mode = 0;   // 1 Deuteranopie, 2 Protanopie, 3 Tritanopie

void fragment() {
	vec3 c = texture(screen_tex, SCREEN_UV).rgb;
	mat3 rgb2lms = mat3(vec3(17.8824, 3.45565, 0.0299566), vec3(43.5161, 27.1554, 0.184309), vec3(4.11935, 3.86714, 1.46709));
	mat3 lms2rgb = inverse(rgb2lms);
	vec3 lms = rgb2lms * c;
	vec3 sim = lms;
	if (mode == 1) {
		sim = vec3(lms.x, 0.494207 * lms.x + 1.24827 * lms.z, lms.z);
	} else if (mode == 2) {
		sim = vec3(2.02344 * lms.y - 2.52581 * lms.z, lms.y, lms.z);
	} else if (mode == 3) {
		sim = vec3(lms.x, lms.y, -0.395913 * lms.x + 0.801109 * lms.y);
	}
	vec3 err = c - lms2rgb * sim;
	vec3 shift = vec3(0.0, 0.7 * err.r + err.g, 0.7 * err.r + err.b);
	COLOR = vec4(clamp(c + shift, 0.0, 1.0), 1.0);
}
