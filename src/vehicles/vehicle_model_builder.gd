class_name VehicleModelBuilder
extends RefCounted
## Erzeugt stilisierte, eigene Fahrzeugmodelle aus Seitenprofilen (keine Fremdmodelle).
## Geometrie wird pro Karosserieform gecacht; Lackfarbe über Material-Override je Fahrzeug.
## Fahrzeugfront zeigt nach -Z, Ursprung = Bodenmitte in Ruhelage.

static var _cache: Dictionary = {}


## Rückgabe: { body: ArrayMesh, paint_surface: int, front_lights: ArrayMesh, rear_lights: ArrayMesh,
##             beacon: ArrayMesh (nur Polizei) }
static func get_model(spec: VehicleSpec) -> Dictionary:
	if _cache.has(spec.body_style):
		return _cache[spec.body_style]
	var model: Dictionary = _build(spec)
	_cache[spec.body_style] = model
	return model


static func _build(spec: VehicleSpec) -> Dictionary:
	var kit := MeshKit.new()
	kit.set_material("paint", MatLib.solid(Color(0.7, 0.7, 0.7), 0.35, 0.3))
	kit.set_material("glass", MatLib.glass())
	kit.set_material("trim", MatLib.solid(Color(0.06, 0.06, 0.07), 0.7))
	kit.set_material("chrome", MatLib.solid(Color(0.75, 0.76, 0.78), 0.25, 0.8))
	kit.set_material("plate", MatLib.solid(Color(0.92, 0.92, 0.9), 0.6))
	kit.set_material("accent", MatLib.solid(Color(0.1, 0.25, 0.6), 0.4, 0.2))
	var L: float = spec.length
	var W: float = spec.width
	var hl: float = L * 0.5
	var hw: float = W * 0.5
	var lower: PackedVector2Array
	var cabin: PackedVector2Array
	var cabin_bands: Array = []
	var cabin_inset: float = 0.08
	match spec.body_style:
		"sport":
			lower = PackedVector2Array([Vector2(-hl, 0.22), Vector2(hl, 0.22), Vector2(hl, 0.7), Vector2(hl - 0.12, 0.8),
				Vector2(1.2, 0.82), Vector2(-0.7, 0.82), Vector2(-hl + 0.15, 0.62), Vector2(-hl, 0.45)])
			cabin = PackedVector2Array([Vector2(-0.75, 0.81), Vector2(-0.02, 1.18), Vector2(0.72, 1.18), Vector2(1.95, 0.83)])
			cabin_bands = ["glass", "paint", "glass", "paint"]
			cabin_inset = 0.14
		"transporter":
			lower = PackedVector2Array([Vector2(-hl, 0.36), Vector2(hl, 0.36), Vector2(hl, 2.42), Vector2(-1.55, 2.42),
				Vector2(-2.28, 1.3), Vector2(-hl, 1.18), Vector2(-hl, 0.55)])
		"limousine", "polizei":
			lower = PackedVector2Array([Vector2(-hl, 0.3), Vector2(hl, 0.3), Vector2(hl, 0.86), Vector2(hl - 0.1, 0.96),
				Vector2(1.3, 0.98), Vector2(-1.0, 0.98), Vector2(-hl + 0.1, 0.8), Vector2(-hl, 0.62)])
			cabin = PackedVector2Array([Vector2(-1.05, 0.97), Vector2(-0.35, 1.45), Vector2(0.95, 1.45), Vector2(1.65, 0.97)])
			cabin_bands = ["glass", "paint", "glass", "paint"]
		_:  # kompakt
			lower = PackedVector2Array([Vector2(-hl, 0.3), Vector2(hl, 0.3), Vector2(hl, 0.92), Vector2(hl - 0.08, 1.0),
				Vector2(-0.95, 1.0), Vector2(-hl + 0.12, 0.8), Vector2(-hl, 0.62)])
			cabin = PackedVector2Array([Vector2(-0.95, 0.99), Vector2(-0.22, 1.47), Vector2(1.35, 1.47), Vector2(hl - 0.08, 0.99)])
			cabin_bands = ["glass", "paint", "glass", "paint"]

	# Unterbau
	if spec.body_style == "transporter":
		kit.add_extruded_profile("paint", lower, -hw, hw, ["trim", "paint", "paint", "paint", "glass", "paint", "trim"])
		# Seitenfenster Fahrerhaus
		for sx: float in [-1.0, 1.0]:
			kit.add_box("glass", Vector3(sx * (hw + 0.005), 1.75, -1.95), Vector3(0.02, 0.6, 0.62))
		# Schiebetür-Fuge und Griff
		for sx2: float in [-1.0, 1.0]:
			kit.add_box("trim", Vector3(sx2 * (hw + 0.006), 1.35, -0.2), Vector3(0.012, 1.8, 0.03))
			kit.add_box("chrome", Vector3(sx2 * (hw + 0.02), 1.3, 0.1), Vector3(0.03, 0.05, 0.22))
		# Hecktüren-Fuge
		kit.add_box("trim", Vector3(0, 1.38, hl + 0.006), Vector3(0.03, 1.95, 0.012))
	else:
		kit.add_extruded_profile("paint", lower, -hw, hw)
		kit.add_extruded_profile("glass", cabin, -hw + cabin_inset, hw - cabin_inset, cabin_bands)
		# Dachholme (B-Säule) für Fenstergliederung
		var roof_y: float = cabin[1].y
		var bz: float = (cabin[1].x + cabin[2].x) * 0.5 + 0.05
		for sx3: float in [-1.0, 1.0]:
			kit.add_box("paint", Vector3(sx3 * (hw - cabin_inset + 0.005), (cabin[0].y + roof_y) * 0.5, bz), Vector3(0.03, roof_y - cabin[0].y, 0.12))
		if spec.body_style == "sport":
			# Heckspoiler
			kit.add_box("trim", Vector3(0, 0.98, hl - 0.18), Vector3(W * 0.9, 0.05, 0.3))
			for sx4: float in [-0.6, 0.6]:
				kit.add_box("trim", Vector3(sx4, 0.9, hl - 0.2), Vector3(0.05, 0.14, 0.12))
			# Lufteinlässe
			for sx5: float in [-1.0, 1.0]:
				kit.add_box("trim", Vector3(sx5 * (hw + 0.004), 0.55, 0.55), Vector3(0.01, 0.16, 0.5))

	# Stoßfänger, Kühlergrill, Kennzeichen, Seitenspiegel
	var bumper_y: float = 0.42 if spec.body_style != "sport" else 0.34
	kit.add_box("trim", Vector3(0, bumper_y, -hl - 0.03), Vector3(W * 0.98, 0.22, 0.1))
	kit.add_box("trim", Vector3(0, bumper_y, hl + 0.03), Vector3(W * 0.98, 0.22, 0.1))
	kit.add_box("trim", Vector3(0, bumper_y + 0.25, -hl - 0.005), Vector3(W * 0.42, 0.14, 0.02))
	kit.add_box("plate", Vector3(0, bumper_y, -hl - 0.09), Vector3(0.52, 0.11, 0.02))
	kit.add_box("plate", Vector3(0, bumper_y + 0.28, hl + 0.01), Vector3(0.52, 0.11, 0.02))
	var mirror_z: float = -0.9 if spec.body_style != "transporter" else -2.05
	var mirror_y: float = 1.05 if spec.body_style != "transporter" else 1.9
	if spec.body_style == "sport":
		mirror_z = -0.6
		mirror_y = 0.88
	for sx6: float in [-1.0, 1.0]:
		kit.add_box("paint", Vector3(sx6 * (hw + 0.1), mirror_y, mirror_z), Vector3(0.18, 0.1, 0.12))
		# Radkästen (dunkel) über den Rädern
		for zz: float in [-spec.wheelbase * 0.5, spec.wheelbase * 0.5]:
			kit.add_box("trim", Vector3(sx6 * (hw - 0.02), spec.wheel_radius + 0.08, zz), Vector3(0.06, 0.2, spec.wheel_radius * 2.3))

	if spec.body_style == "polizei":
		# Blaue Seitenstreifen
		for sx7: float in [-1.0, 1.0]:
			kit.add_box("accent", Vector3(sx7 * (hw + 0.004), 0.68, 0.0), Vector3(0.012, 0.2, L * 0.92))
		kit.add_box("accent", Vector3(0, 0.99, -1.7), Vector3(W * 0.7, 0.02, 1.0))
		# Lichtbalken-Sockel
		kit.add_box("trim", Vector3(0, 1.49, 0.25), Vector3(1.2, 0.06, 0.28))

	var body: ArrayMesh = kit.commit()
	var paint_idx: int = int(kit.surface_index.get("paint", 0))

	# Scheinwerfer / Rückleuchten als eigene Meshes (Material wird zur Laufzeit gewechselt)
	var fk := MeshKit.new()
	fk.set_material("l", MatLib.solid(Color(0.9, 0.9, 0.85), 0.2))
	var light_y: float = 0.72 if spec.body_style != "sport" else 0.58
	if spec.body_style == "transporter":
		light_y = 0.95
	for sx8: float in [-1.0, 1.0]:
		fk.add_box("l", Vector3(sx8 * (hw - 0.28), light_y, -hl - 0.01), Vector3(0.34, 0.12, 0.04))
	var rk := MeshKit.new()
	rk.set_material("l", MatLib.solid(Color(0.5, 0.05, 0.05), 0.3))
	var rear_y: float = light_y + (0.1 if spec.body_style != "transporter" else 0.2)
	for sx9: float in [-1.0, 1.0]:
		rk.add_box("l", Vector3(sx9 * (hw - 0.2), rear_y, hl + 0.01), Vector3(0.3, 0.12, 0.04))
	var model: Dictionary = {
		"body": body,
		"paint_surface": paint_idx,
		"front_lights": fk.commit(),
		"rear_lights": rk.commit(),
		"front_light_y": light_y,
	}
	if spec.body_style == "polizei":
		var bk := MeshKit.new()
		bk.set_material("l", MatLib.solid(Color(0.1, 0.2, 0.7), 0.3))
		bk.add_box("l", Vector3(-0.3, 1.58, 0.25), Vector3(0.5, 0.12, 0.22))
		var bk2 := MeshKit.new()
		bk2.set_material("l", MatLib.solid(Color(0.1, 0.2, 0.7), 0.3))
		bk2.add_box("l", Vector3(0.3, 1.58, 0.25), Vector3(0.5, 0.12, 0.22))
		model["beacon_left"] = bk.commit()
		model["beacon_right"] = bk2.commit()
	return model


## Rad (Reifen + Felge), Achse = X, Mittelpunkt im Ursprung.
static func get_wheel_mesh(radius: float) -> ArrayMesh:
	var key: String = "wheel_%.3f" % radius
	if _cache.has(key):
		return _cache[key]
	var kit := MeshKit.new()
	kit.set_material("tire", MatLib.solid(Color(0.05, 0.05, 0.05), 0.9))
	kit.set_material("rim", MatLib.solid(Color(0.68, 0.69, 0.7), 0.3, 0.7))
	var w: float = 0.24
	var basis := Basis(Vector3(0, 0, 1), -PI * 0.5)
	kit.add_cylinder("tire", Vector3(-w * 0.5, 0, 0), radius, radius, w, 16, basis)
	kit.add_cylinder("rim", Vector3(-w * 0.5 - 0.005, 0, 0), radius * 0.6, radius * 0.6, w + 0.01, 10, basis)
	# Speichen (sichtbare Drehung)
	for i: int in 3:
		var b := Basis(Vector3(1, 0, 0), PI * float(i) / 3.0)
		kit.add_box("tire", Vector3(0, 0, 0), Vector3(w + 0.03, radius * 1.05, 0.05), b)
	var m: ArrayMesh = kit.commit()
	_cache[key] = m
	return m
