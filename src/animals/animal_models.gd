class_name AnimalModels
extends RefCounted
## Prozedurale Low-Poly-Tiermodelle (eigene Gestaltung) aus wenigen Grundkörpern mit Vertex-Farben.
## Aufbau: Wurzel „Tier“ -> „Koerper“ (Mesh) + Gelenkknoten „Bein_0..3“, „Fluegel_L/R“, „Kopf“ für die Animation.
## Meshes werden je Art und Teil gecacht (viele Tiere teilen dieselben Meshes).

static var _cache: Dictionary = {}
static var _species: Dictionary = {}
static var _mat: StandardMaterial3D


static func species() -> Dictionary:
	if _species.is_empty():
		var f: FileAccess = FileAccess.open("res://data/animals/species.json", FileAccess.READ)
		if f != null:
			var d: Variant = JSON.parse_string(f.get_as_text())
			if d is Dictionary:
				for k: String in d:
					if not k.begins_with("_"):
						_species[k] = d[k]
	return _species


static func _col(a: Variant) -> Color:
	var arr: Array = a
	return Color(float(arr[0]), float(arr[1]), float(arr[2]))


static func _material() -> StandardMaterial3D:
	if _mat == null:
		_mat = MatLib.vertex_color(0.8)
	return _mat


static func _mesh(key: String, build: Callable) -> ArrayMesh:
	if not _cache.has(key):
		var kit := MeshKit.new()
		kit.set_material("m", _material())
		build.call(kit)
		_cache[key] = kit.commit()
	return _cache[key]


static func _mi(parent: Node3D, mesh: ArrayMesh, node_name: String = "") -> MeshInstance3D:
	var mi := MeshInstance3D.new()
	mi.mesh = mesh
	if node_name != "":
		mi.name = node_name
	mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	parent.add_child(mi)
	return mi


## Modell einer Art bauen. Skalierung über „length“ der Art (Modelle sind auf 1 m Länge normiert).
static func build(sid: String) -> Node3D:
	var d: Dictionary = species().get(sid, {})
	var root := Node3D.new()
	root.name = "Tier_" + sid
	var body_c: Color = _col(d.get("body", [0.5, 0.5, 0.5]))
	var acc_c: Color = _col(d.get("accent", [0.3, 0.3, 0.3]))
	var shape: String = str(d.get("shape", "hund"))
	var L: float = float(d.get("length", 1.0))
	var H: float = float(d.get("height", 0.5))
	match shape:
		"vogel", "ente", "flamingo", "pinguin":
			_bird(root, sid, shape, L, H, body_c, acc_c)
		"robbe":
			_seal(root, sid, L, H, body_c, acc_c)
		"affe":
			_monkey(root, sid, L, H, body_c, acc_c)
		_:
			_quadruped(root, sid, shape, L, H, body_c, acc_c, d)
	return root


static func _quadruped(root: Node3D, sid: String, shape: String, L: float, H: float, bc: Color, ac: Color, d: Dictionary) -> void:
	var leg_h: float = H * (0.45 if shape != "giraffe" else 0.42)
	if shape in ["nager", "katze", "baer"]:
		leg_h = H * 0.4
	if shape == "elefant":
		leg_h = H * 0.42
	var body_h: float = H - leg_h - (0.0 if shape != "giraffe" else H * 0.38)
	if shape == "giraffe":
		body_h = H * 0.22
	var body_l: float = L * 0.72
	var body_w: float = body_h * (1.05 if shape in ["elefant", "baer"] else 0.8)
	var stripes: bool = bool(d.get("stripes", false))
	var body: ArrayMesh = _mesh(sid + ":body", func(k: MeshKit) -> void:
		k.color = bc
		k.add_sphere("m", Vector3(0, 0, 0), Vector3(body_w * 0.5, body_h * 0.5, body_l * 0.5), 5, 8)
		if stripes:
			k.color = ac
			for i: int in 6:
				var z: float = -body_l * 0.4 + float(i) * body_l * 0.16
				k.add_box("m", Vector3(0, body_h * 0.06, z), Vector3(body_w * 1.02, body_h * 0.75, body_l * 0.05))
		if shape == "giraffe":
			k.color = ac
			for i2: int in 8:
				var ang: float = float(i2) * 0.8
				k.add_sphere("m", Vector3(cos(ang) * body_w * 0.45, sin(ang * 1.3) * body_h * 0.2, -body_l * 0.3 + float(i2) * body_l * 0.08),
					Vector3(0.12, 0.1, 0.12), 3, 5)
		# Schwanz
		k.color = ac if shape != "elefant" else bc
		k.add_cylinder("m", Vector3(0, body_h * 0.1, body_l * 0.48), 0.03 * H + 0.01, 0.01, L * 0.3, 5,
			Basis(Vector3.RIGHT, deg_to_rad(120.0))))
	var body_mi: MeshInstance3D = _mi(root, body, "Koerper")
	body_mi.position = Vector3(0, leg_h + body_h * 0.45, 0)
	# Kopf (vorne = -Z)
	var head := Node3D.new()
	head.name = "Kopf"
	root.add_child(head)
	var head_s: float = body_h * (0.55 if shape != "elefant" else 0.75)
	var neck_len: float = 0.0
	if shape == "giraffe":
		neck_len = H * 0.45
	elif shape == "pferd":
		neck_len = body_h * 0.7
	head.position = Vector3(0, leg_h + body_h * (0.75 if neck_len == 0.0 else 0.6), -body_l * 0.48)
	var hm: ArrayMesh = _mesh(sid + ":head", func(k: MeshKit) -> void:
		k.color = bc
		if neck_len > 0.0:
			k.add_cylinder("m", Vector3.ZERO, body_w * 0.22, body_w * 0.16, neck_len, 6, Basis(Vector3.RIGHT, deg_to_rad(-25.0)))
		var hp: Vector3 = Vector3(0, neck_len * 0.9, -neck_len * 0.42 - head_s * 0.3)
		k.add_sphere("m", hp, Vector3(head_s * 0.42, head_s * 0.42, head_s * 0.6), 4, 7)
		# Schnauze
		k.color = bc.darkened(0.15)
		k.add_sphere("m", hp + Vector3(0, -head_s * 0.1, -head_s * 0.45), Vector3(head_s * 0.25, head_s * 0.22, head_s * 0.3), 3, 6)
		# Ohren
		k.color = bc.darkened(0.08)
		var ear: float = head_s * (0.55 if shape == "elefant" else 0.18)
		for s: float in [-1.0, 1.0]:
			if shape == "elefant":
				k.add_box("m", hp + Vector3(s * head_s * 0.5, 0, head_s * 0.1), Vector3(0.06, ear * 1.2, ear), Basis(Vector3.UP, s * 0.3))
			else:
				k.add_pyramid("m", hp + Vector3(s * head_s * 0.25, head_s * 0.3, 0), ear, ear * 1.4)
		# Rüssel / Mähne / Hörnchen
		if shape == "elefant":
			k.color = bc
			k.add_cylinder("m", hp + Vector3(0, -head_s * 0.2, -head_s * 0.5), head_s * 0.16, head_s * 0.08, head_s * 1.6, 6,
				Basis(Vector3.RIGHT, deg_to_rad(-160.0)))
			k.color = ac
			for s2: float in [-1.0, 1.0]:
				k.add_cylinder("m", hp + Vector3(s2 * head_s * 0.2, -head_s * 0.25, -head_s * 0.4), 0.05, 0.02, head_s * 0.6, 5,
					Basis(Vector3.RIGHT, deg_to_rad(-120.0)))
		if bool(d.get("mane", false)):
			k.color = ac
			k.add_sphere("m", hp + Vector3(0, 0, head_s * 0.15), Vector3(head_s * 0.7, head_s * 0.7, head_s * 0.45), 4, 8)
			k.color = bc
			k.add_sphere("m", hp + Vector3(0, 0, -head_s * 0.1), Vector3(head_s * 0.4, head_s * 0.4, head_s * 0.5), 4, 7)
		if shape == "giraffe":
			k.color = ac
			for s3: float in [-1.0, 1.0]:
				k.add_cylinder("m", hp + Vector3(s3 * 0.08, head_s * 0.35, 0.05), 0.03, 0.04, 0.2, 5)
		# Augen
		k.color = Color(0.05, 0.05, 0.05)
		for s4: float in [-1.0, 1.0]:
			k.add_sphere("m", hp + Vector3(s4 * head_s * 0.3, head_s * 0.12, -head_s * 0.35), Vector3.ONE * head_s * 0.06, 2, 4))
	_mi(head, hm)
	# Beine (Gelenk oben)
	var leg_r: float = body_w * (0.13 if shape != "elefant" else 0.2)
	var lm: ArrayMesh = _mesh(sid + ":leg", func(k: MeshKit) -> void:
		k.color = bc if not stripes else bc.darkened(0.05)
		k.add_cylinder("m", Vector3(0, -leg_h, 0), leg_r * 0.8, leg_r, leg_h, 6)
		k.color = ac.darkened(0.3) if shape != "katze" else bc
		k.add_cylinder("m", Vector3(0, -leg_h, 0), leg_r * 0.85, leg_r * 0.85, leg_h * 0.1, 6))
	var lx: float = body_w * 0.3
	var lz: float = body_l * 0.33
	var idx: int = 0
	for sz: float in [-1.0, 1.0]:
		for sx: float in [-1.0, 1.0]:
			var pivot := Node3D.new()
			pivot.name = "Bein_%d" % idx
			pivot.position = Vector3(sx * lx, leg_h + body_h * 0.1, sz * lz)
			root.add_child(pivot)
			_mi(pivot, lm)
			idx += 1


static func _bird(root: Node3D, sid: String, shape: String, L: float, H: float, bc: Color, ac: Color) -> void:
	var leg_h: float = H * (0.55 if shape == "flamingo" else (0.12 if shape == "pinguin" else 0.2))
	var body_r: float = L * (0.28 if shape != "pinguin" else 0.35)
	var upright: bool = shape == "pinguin"
	var body: ArrayMesh = _mesh(sid + ":body", func(k: MeshKit) -> void:
		k.color = bc
		if upright:
			k.add_sphere("m", Vector3.ZERO, Vector3(body_r, H * 0.45, body_r * 0.9), 5, 8)
			k.color = ac
			k.add_sphere("m", Vector3(0, -H * 0.02, -body_r * 0.35), Vector3(body_r * 0.8, H * 0.38, body_r * 0.6), 4, 7)
		else:
			k.add_sphere("m", Vector3.ZERO, Vector3(body_r * 0.8, body_r * 0.75, L * 0.45), 4, 8)
			k.color = bc.darkened(0.2)
			k.add_pyramid("m", Vector3(0, body_r * 0.1, L * 0.42), body_r * 0.7, L * 0.25, Basis(Vector3.RIGHT, deg_to_rad(80.0))))
	var body_mi: MeshInstance3D = _mi(root, body, "Koerper")
	body_mi.position = Vector3(0, leg_h + (H * 0.45 if upright else body_r * 0.7), 0)
	var head := Node3D.new()
	head.name = "Kopf"
	root.add_child(head)
	var neck: float = H * 0.35 if shape == "flamingo" else 0.0
	head.position = Vector3(0, leg_h + (H * 0.85 if upright else body_r * 1.2 + neck), -L * (0.05 if upright else 0.38))
	var hs: float = body_r * (0.55 if shape != "flamingo" else 0.4)
	var hm: ArrayMesh = _mesh(sid + ":head", func(k: MeshKit) -> void:
		if neck > 0.0:
			k.color = bc
			k.add_cylinder("m", Vector3(0, -neck, 0.05), hs * 0.25, hs * 0.2, neck, 5)
		k.color = ac if shape == "ente" else bc
		k.add_sphere("m", Vector3.ZERO, Vector3.ONE * hs, 3, 6)
		k.color = Color(0.95, 0.7, 0.15) if shape in ["ente", "pinguin", "vogel"] else Color(0.15, 0.12, 0.12)
		k.add_cylinder("m", Vector3(0, -hs * 0.1, -hs * 0.7), hs * 0.25, hs * 0.05, hs * 0.9, 5, Basis(Vector3.RIGHT, deg_to_rad(-90.0)))
		k.color = Color(0.05, 0.05, 0.05)
		for s: float in [-1.0, 1.0]:
			k.add_sphere("m", Vector3(s * hs * 0.55, hs * 0.2, -hs * 0.45), Vector3.ONE * hs * 0.14, 2, 4))
	_mi(head, hm)
	var wing: ArrayMesh = _mesh(sid + ":wing", func(k: MeshKit) -> void:
		k.color = bc.darkened(0.12)
		k.add_box("m", Vector3(body_r * 0.9, 0, 0), Vector3(body_r * 1.8, 0.02 + L * 0.02, L * 0.4)))
	for s2: float in [-1.0, 1.0]:
		var w := Node3D.new()
		w.name = "Fluegel_" + ("L" if s2 < 0 else "R")
		w.position = body_mi.position + Vector3(s2 * body_r * 0.6, body_r * 0.2, 0)
		w.scale = Vector3(s2, 1, 1)
		root.add_child(w)
		_mi(w, wing)
	var lm: ArrayMesh = _mesh(sid + ":leg", func(k: MeshKit) -> void:
		k.color = Color(0.9, 0.6, 0.3) if shape != "flamingo" else bc.darkened(0.2)
		k.add_cylinder("m", Vector3(0, -leg_h, 0), 0.012 + L * 0.02, 0.012 + L * 0.02, leg_h, 4)
		k.add_box("m", Vector3(0, -leg_h + 0.01, -L * 0.05), Vector3(L * 0.12, 0.015, L * 0.14)))
	for i: int in 2:
		var pv := Node3D.new()
		pv.name = "Bein_%d" % i
		pv.position = Vector3((float(i) - 0.5) * body_r * 0.7, leg_h, 0)
		root.add_child(pv)
		_mi(pv, lm)


static func _seal(root: Node3D, sid: String, L: float, H: float, bc: Color, ac: Color) -> void:
	var m: ArrayMesh = _mesh(sid + ":body", func(k: MeshKit) -> void:
		k.color = bc
		k.add_sphere("m", Vector3(0, H * 0.4, 0), Vector3(L * 0.2, H * 0.4, L * 0.5), 5, 8)
		k.add_sphere("m", Vector3(0, H * 0.75, -L * 0.42), Vector3(L * 0.12, L * 0.12, L * 0.14), 4, 7)
		k.color = ac
		for s: float in [-1.0, 1.0]:
			k.add_box("m", Vector3(s * L * 0.2, H * 0.12, -L * 0.15), Vector3(L * 0.18, 0.04, L * 0.12), Basis(Vector3.UP, s * 0.5))
		k.add_box("m", Vector3(0, H * 0.15, L * 0.52), Vector3(L * 0.28, 0.04, L * 0.12))
		k.color = Color(0.05, 0.05, 0.05)
		for s2: float in [-1.0, 1.0]:
			k.add_sphere("m", Vector3(s2 * L * 0.06, H * 0.82, -L * 0.52), Vector3.ONE * 0.025, 2, 4))
	_mi(root, m, "Koerper")


static func _monkey(root: Node3D, sid: String, L: float, H: float, bc: Color, ac: Color) -> void:
	var m: ArrayMesh = _mesh(sid + ":body", func(k: MeshKit) -> void:
		k.color = bc
		k.add_sphere("m", Vector3(0, H * 0.5, 0), Vector3(H * 0.18, H * 0.26, H * 0.15), 4, 7)
		k.add_sphere("m", Vector3(0, H * 0.86, -0.02), Vector3.ONE * H * 0.14, 4, 7)
		k.color = ac
		k.add_sphere("m", Vector3(0, H * 0.84, -H * 0.1), Vector3(H * 0.09, H * 0.08, H * 0.05), 3, 6)
		k.color = bc
		k.add_cylinder("m", Vector3(0, H * 0.35, H * 0.12), 0.025, 0.015, H * 0.7, 5, Basis(Vector3.RIGHT, deg_to_rad(140.0)))
		for s: float in [-1.0, 1.0]:
			k.add_cylinder("m", Vector3(s * H * 0.2, H * 0.28, 0), 0.03, 0.025, H * 0.4, 5, Basis(Vector3.FORWARD, s * 0.25)))
	_mi(root, m, "Koerper")
	var lm: ArrayMesh = _mesh(sid + ":leg", func(k: MeshKit) -> void:
		k.color = bc
		k.add_cylinder("m", Vector3(0, -H * 0.32, 0), 0.03, 0.035, H * 0.32, 5))
	for i: int in 2:
		var pv := Node3D.new()
		pv.name = "Bein_%d" % i
		pv.position = Vector3((float(i) - 0.5) * H * 0.18, H * 0.32, 0)
		root.add_child(pv)
		_mi(pv, lm)
