// Bäume/Sträucher (eigenes Werk): Vertex-Farben als Albedo, Windbewegung der Krone (Höhe über Stamm),
// Phase je Instanz aus der Weltposition (MultiMesh), Nässe dunkelt leicht ab.
shader_type spatial;
render_mode cull_back;

uniform float wind = 0.35;      // 0 = windstill, 1 = stürmisch (von EnvironmentSetup nach Wetter gesetzt)
uniform float wetness = 0.0;
uniform float crown_start = 2.2; // ab dieser Höhe (Modellraum) bewegt sich das Laub

void vertex() {
	vec3 origin = MODEL_MATRIX[3].xyz;
	float h = max(VERTEX.y - crown_start, 0.0);
	float ph = origin.x * 0.13 + origin.z * 0.17;
	float sway = sin(TIME * 1.3 + ph) * 0.6 + sin(TIME * 2.9 + ph * 1.7) * 0.25;
	float flutter = sin(TIME * 7.0 + VERTEX.x * 3.0 + VERTEX.z * 2.0 + ph) * 0.02;
	VERTEX.x += (sway * 0.045 + flutter) * wind * h;
	VERTEX.z += (cos(TIME * 1.1 + ph * 1.3) * 0.03 + flutter) * wind * h;
}

void fragment() {
	ALBEDO = COLOR.rgb * (1.0 - wetness * 0.22);
	ROUGHNESS = 0.85 - wetness * 0.3;
}
