class_name TransitModels
extends RefCounted
## Eigene, vereinfachte Fahrzeugmodelle für den ÖPNV (W5): dreiteilige Stadtbahn (Teile folgen der Gleislinie)
## und Stadtbus. Farben je Linie (Linienfarbe aus den Daten als Akzentstreifen).

const TRAM_SEG: float = 12.0         ## Länge eines Wagenteils (m)
const TRAM_GAP: float = 0.8
const TRAM_W: float = 2.65
const TRAM_H: float = 3.4
const BUS_L: float = 12.0
const BUS_W: float = 2.55
const BUS_H: float = 3.1

static var _cache: Dictionary = {}


static func _mat() -> StandardMaterial3D:
	return MatLib.vertex_color(0.55)


static func segment_mesh(kind: String, accent: Color) -> ArrayMesh:
	var key: String = "%s:%s" % [kind, accent.to_html(false)]
	if _cache.has(key):
		return _cache[key]
	var kit := MeshKit.new()
	kit.set_material("m", _mat())
	kit.set_material("g", CityMaterials.get_mat("glass_dark"))
	kit.set_material("l", CityMaterials.get_mat("lamp_glow"))
	var L: float = TRAM_SEG if kind != "bus" else BUS_L
	var W: float = TRAM_W if kind != "bus" else BUS_W
	var H: float = TRAM_H if kind != "bus" else BUS_H
	var floor_y: float = 0.35 if kind != "bus" else 0.3
	var body: Color = Color(0.93, 0.9, 0.82) if kind != "bus" else Color(0.92, 0.92, 0.9)
	# Wagenkasten
	kit.color = body
	kit.add_box("m", Vector3(0, floor_y + (H - floor_y) * 0.5, 0), Vector3(W, H - floor_y, L))
	# Fensterband
	kit.add_box("g", Vector3(0, floor_y + H * 0.52, 0), Vector3(W + 0.04, H * 0.34, L - 0.8))
	# Akzentstreifen (Linienfarbe) und Schürze
	kit.color = accent
	kit.add_box("m", Vector3(0, floor_y + 0.55, 0), Vector3(W + 0.05, 0.5, L - 0.2))
	kit.color = Color(0.18, 0.18, 0.2)
	kit.add_box("m", Vector3(0, floor_y * 0.5, 0), Vector3(W - 0.2, floor_y, L - 1.0))
	# Türen (rechte Seite, +x)
	kit.color = Color(0.25, 0.27, 0.3)
	for dz: float in [-L * 0.28, L * 0.28]:
		kit.add_box("m", Vector3(W * 0.5 + 0.02, floor_y + 1.05, dz), Vector3(0.06, 2.0, 1.3))
	# Dach (Stromabnehmer nur Bahn)
	kit.color = Color(0.72, 0.72, 0.74)
	kit.add_box("m", Vector3(0, H + 0.08, 0), Vector3(W - 0.3, 0.16, L - 1.5))
	if kind == "tram_front":
		kit.color = Color(0.2, 0.2, 0.22)
		kit.add_box("m", Vector3(0, H + 0.45, 0), Vector3(0.1, 0.6, 1.4))
		kit.add_box("m", Vector3(0, H + 0.78, 0), Vector3(1.5, 0.06, 0.1))
	# Front/Heck mit Leuchten
	for sgn: float in [-1.0, 1.0]:
		kit.color = Color.WHITE
		for sx: float in [-W * 0.33, W * 0.33]:
			kit.add_box("l", Vector3(sx, floor_y + 0.75, sgn * (L * 0.5 + 0.02)), Vector3(0.35, 0.18, 0.05))
		kit.add_box("g", Vector3(0, floor_y + H * 0.55, sgn * (L * 0.5 + 0.02)), Vector3(W - 0.4, H * 0.4, 0.05))
	var m: ArrayMesh = kit.commit()
	_cache[key] = m
	return m


## Zugzielanzeige (Liniennummer + Ziel) als Label3D über der Front.
static func destination_label(ref: String, dest: String, accent: Color) -> Label3D:
	var l := Label3D.new()
	l.text = "%s  %s" % [ref, dest]
	l.font_size = 42
	l.pixel_size = 0.008
	l.modulate = Color(1.0, 0.75, 0.2)
	l.outline_size = 6
	l.outline_modulate = Color(0.05, 0.05, 0.05)
	l.double_sided = false
	l.visibility_range_end = 60.0
	return l


## Wartehäuschen mit Haltestellenschild.
static func stop_shelter(stop_name: String, underground: bool) -> Node3D:
	var root := Node3D.new()
	root.name = "Haltestelle"
	var kit := MeshKit.new()
	kit.set_material("m", _mat())
	kit.set_material("g", CityMaterials.get_mat("glass"))
	if underground:
		# Abgang zur unterirdischen Station (Treppenhaus mit Glasdach)
		kit.color = Color(0.3, 0.32, 0.36)
		kit.add_box("m", Vector3(0, 1.2, 0), Vector3(3.2, 2.4, 0.2))
		kit.add_box("m", Vector3(-1.6, 1.2, 2.5), Vector3(0.2, 2.4, 5.0))
		kit.add_box("m", Vector3(1.6, 1.2, 2.5), Vector3(0.2, 2.4, 5.0))
		kit.add_box("g", Vector3(0, 2.5, 2.5), Vector3(3.4, 0.08, 5.2))
	else:
		kit.color = Color(0.25, 0.27, 0.3)
		for x: float in [-1.8, 1.8]:
			kit.add_box("m", Vector3(x, 1.25, 0), Vector3(0.1, 2.5, 0.1))
		kit.add_box("m", Vector3(0, 2.55, 0.5), Vector3(4.0, 0.12, 1.6))
		kit.add_box("g", Vector3(0, 1.3, -0.25), Vector3(3.8, 2.0, 0.05))
		kit.color = Color(0.45, 0.3, 0.2)
		kit.add_box("m", Vector3(0, 0.5, 0.1), Vector3(2.4, 0.08, 0.45))
	# Schild (Mast mit „H“)
	kit.color = Color(0.3, 0.3, 0.32)
	kit.add_box("m", Vector3(2.6, 1.4, 0.3), Vector3(0.08, 2.8, 0.08))
	kit.color = Color(0.1, 0.5, 0.25)
	kit.add_box("m", Vector3(2.6, 2.75, 0.3), Vector3(0.6, 0.6, 0.06))
	var mi := MeshInstance3D.new()
	mi.mesh = kit.commit()
	root.add_child(mi)
	var h := Label3D.new()
	h.text = "H"
	h.font_size = 64
	h.pixel_size = 0.006
	h.modulate = Color(0.95, 0.85, 0.1)
	h.position = Vector3(2.6, 2.75, 0.34)
	root.add_child(h)
	var nl := Label3D.new()
	nl.text = stop_name
	nl.font_size = 36
	nl.pixel_size = 0.006
	nl.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	nl.outline_size = 6
	nl.position = Vector3(2.6, 3.35, 0.3)
	nl.visibility_range_end = 45.0
	root.add_child(nl)
	return root
