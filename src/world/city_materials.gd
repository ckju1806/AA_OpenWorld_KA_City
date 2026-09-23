class_name CityMaterials
extends RefCounted
## Zentrale Materialien der Stadt (einmal erzeugt, überall wiederverwendet).

static var _m: Dictionary = {}


static func get_mat(key: String) -> Material:
	if _m.has(key):
		return _m[key]
	var m: Material = _create(key)
	_m[key] = m
	return m


static func _create(key: String) -> Material:
	match key:
		"facade":
			return MatLib.shader_material("facade", "res://assets/shaders/facade.gdshader", {"night": 0.75})
		"roof":
			return MatLib.shader_material("roof", "res://assets/shaders/roof.gdshader")
		"asphalt":
			return MatLib.shader_material("asphalt", "res://assets/shaders/asphalt.gdshader")
		"grass":
			return MatLib.shader_material("grass", "res://assets/shaders/grass.gdshader")
		"sidewalk":
			return MatLib.shader_material("sidewalk", "res://assets/shaders/paving.gdshader",
				{"base_color": Color(0.6, 0.59, 0.56), "grout_color": Color(0.44, 0.43, 0.42), "tile": Vector2(0.9, 0.9), "variation": 0.05})
		"plaza":
			return MatLib.shader_material("plaza", "res://assets/shaders/paving.gdshader",
				{"base_color": Color(0.66, 0.6, 0.52), "grout_color": Color(0.46, 0.42, 0.38), "tile": Vector2(0.45, 0.3), "variation": 0.1, "grout": 0.03})
		"gravel":
			return MatLib.shader_material("gravel", "res://assets/shaders/paving.gdshader",
				{"base_color": Color(0.78, 0.72, 0.6), "grout_color": Color(0.7, 0.64, 0.53), "tile": Vector2(0.25, 0.25), "variation": 0.12, "grout": 0.02})
		"yard":
			return MatLib.shader_material("yard", "res://assets/shaders/paving.gdshader",
				{"base_color": Color(0.5, 0.49, 0.47), "grout_color": Color(0.38, 0.37, 0.36), "tile": Vector2(0.3, 0.3), "variation": 0.08, "grout": 0.03})
		"curb":
			return MatLib.solid(Color(0.72, 0.71, 0.68), 0.8)
		"vertex":
			return MatLib.vertex_color(0.85)
		"vertex_metal":
			return MatLib.vertex_color(0.35, 0.6)
		"stone":
			return MatLib.vertex_color(0.75)
		"flat":
			return MatLib.vertex_color(0.9)
		"marking":
			var mk := StandardMaterial3D.new()
			mk.vertex_color_use_as_albedo = true
			mk.roughness = 0.7
			return mk
		"lamp_glow":
			return MatLib.emissive(Color(1.0, 0.82, 0.55), 5.0)
		"water":
			var w := StandardMaterial3D.new()
			w.albedo_color = Color(0.16, 0.26, 0.32)
			w.roughness = 0.05
			w.metallic = 0.4
			return w
		"glass_dark":
			return MatLib.glass(Color(0.1, 0.13, 0.16, 0.8))
	push_warning("Unbekanntes Stadtmaterial: %s" % key)
	return MatLib.solid(Color.MAGENTA)


## Material-Schlüssel eines MeshKits mit den Stadtmaterialien belegen.
static func apply(kit: MeshKit, keys: Array[String]) -> void:
	for k: String in keys:
		kit.set_material(k, get_mat(k), k == "facade")
