class_name MatLib
extends RefCounted
## Zentraler Material-Cache: gleiche Parameter -> gleiche Material-Instanz (Wiederverwendung).

static var _cache: Dictionary = {}


## Einfaches PBR-Material mit fester Farbe.
static func solid(col: Color, roughness: float = 0.85, metallic: float = 0.0) -> StandardMaterial3D:
	var key: String = "s_%s_%.2f_%.2f" % [col.to_html(), roughness, metallic]
	if _cache.has(key):
		return _cache[key]
	var m := StandardMaterial3D.new()
	m.albedo_color = col
	m.roughness = roughness
	m.metallic = metallic
	_cache[key] = m
	return m


## Material, das Vertex-Farben als Albedo nutzt (viele Farben, ein Material).
static func vertex_color(roughness: float = 0.85, metallic: float = 0.0) -> StandardMaterial3D:
	var key: String = "vc_%.2f_%.2f" % [roughness, metallic]
	if _cache.has(key):
		return _cache[key]
	var m := StandardMaterial3D.new()
	m.vertex_color_use_as_albedo = true
	m.roughness = roughness
	m.metallic = metallic
	_cache[key] = m
	return m


## Leuchtendes Material (Laternen, Scheinwerfer, Blaulicht).
static func emissive(col: Color, energy: float = 2.0) -> StandardMaterial3D:
	var key: String = "e_%s_%.2f" % [col.to_html(), energy]
	if _cache.has(key):
		return _cache[key]
	var m := StandardMaterial3D.new()
	m.albedo_color = col
	m.emission_enabled = true
	m.emission = col
	m.emission_energy_multiplier = energy
	m.roughness = 0.4
	_cache[key] = m
	return m


## Halbtransparentes, unbeleuchtetes Material (Markierungen, Missionsziele).
static func glow_transparent(col: Color) -> StandardMaterial3D:
	var key: String = "g_%s" % col.to_html()
	if _cache.has(key):
		return _cache[key]
	var m := StandardMaterial3D.new()
	m.albedo_color = col
	m.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	m.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	m.cull_mode = BaseMaterial3D.CULL_DISABLED
	m.no_depth_test = false
	_cache[key] = m
	return m


## Glas (Fahrzeugscheiben).
static func glass(col: Color = Color(0.12, 0.16, 0.2, 0.85)) -> StandardMaterial3D:
	var key: String = "gl_%s" % col.to_html()
	if _cache.has(key):
		return _cache[key]
	var m := StandardMaterial3D.new()
	m.albedo_color = col
	m.roughness = 0.08
	m.metallic = 0.6
	m.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	_cache[key] = m
	return m


static func shader_material(key: String, shader_path: String, params: Dictionary = {}) -> ShaderMaterial:
	if _cache.has(key):
		return _cache[key]
	var m := ShaderMaterial.new()
	m.shader = load(shader_path) as Shader
	for p: String in params:
		m.set_shader_parameter(p, params[p])
	_cache[key] = m
	return m
