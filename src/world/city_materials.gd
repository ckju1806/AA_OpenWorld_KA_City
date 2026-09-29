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
		"forest_floor":
			return MatLib.shader_material("forest_floor", "res://assets/shaders/grass.gdshader",
				{"color_a": Color(0.16, 0.22, 0.11), "color_b": Color(0.24, 0.26, 0.14)})
		"field":
			return MatLib.shader_material("field", "res://assets/shaders/grass.gdshader",
				{"color_a": Color(0.36, 0.4, 0.2), "color_b": Color(0.46, 0.44, 0.24)})
		"turf":
			return MatLib.shader_material("turf", "res://assets/shaders/grass.gdshader",
				{"color_a": Color(0.2, 0.42, 0.16), "color_b": Color(0.26, 0.48, 0.2)})
		"rail_steel":
			return MatLib.vertex_color(0.35, 0.7)
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
			return MatLib.shader_material("water", "res://assets/shaders/water.gdshader")
		"glass_dark":
			return MatLib.glass(Color(0.1, 0.13, 0.16, 0.8))
		"glass":
			return MatLib.glass(Color(0.72, 0.86, 0.9, 0.32))
	push_warning("Unbekanntes Stadtmaterial: %s" % key)
	return MatLib.solid(Color.MAGENTA)


## Tageszeit: erleuchtete Fenster (Fassaden-Shader) und leuchtende Laternenköpfe.
static func set_night(night: float) -> void:
	(get_mat("facade") as ShaderMaterial).set_shader_parameter("night", clampf(night, 0.0, 1.0))
	var lg: StandardMaterial3D = get_mat("lamp_glow") as StandardMaterial3D
	lg.emission_energy_multiplier = lerpf(0.15, 5.0, clampf(night * 1.5, 0.0, 1.0))


## Nässe der Straßen und Wege (Asphalt, Pflaster), Regen auf dem Wasser.
static func set_wetness(wet: float) -> void:
	for k: String in ["asphalt", "sidewalk", "plaza", "yard"]:
		(get_mat(k) as ShaderMaterial).set_shader_parameter("wetness", clampf(wet, 0.0, 1.0))
	(get_mat("water") as ShaderMaterial).set_shader_parameter("rain", 1.0 if WorldClock.rain > 0.3 else 0.0)


## Material-Schlüssel eines MeshKits mit den Stadtmaterialien belegen.
static func apply(kit: MeshKit, keys: Array[String]) -> void:
	for k: String in keys:
		kit.set_material(k, get_mat(k), k == "facade")
