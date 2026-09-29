class_name LandmarksExtra
extends RefCounted
## Detailmodelle der Prioritätsorte (Meilenstein W3), eigene vereinfachte Interpretationen:
## Hauptbahnhof (Empfangsgebäude, Uhrturm, Bahnsteighallen), Zoologischer Stadtgarten (Eingang, Gehege),
## Stadion am Wildpark, Gewächshäuser im Botanischen Garten, Hafenkräne, Turmberg (Aussichtsturm + Fernsilhouette),
## Staatstheater. Alle Maße in Metern; lokales System: x = rechts, z = hinten (vor Drehung um rot).

const SAND: Color = Color(0.84, 0.72, 0.58)
const SAND_LIGHT: Color = Color(0.9, 0.82, 0.7)
const RED_SAND: Color = Color(0.62, 0.36, 0.29)
const SLATE: Color = Color(0.3, 0.33, 0.38)
const COPPER: Color = Color(0.36, 0.55, 0.47)
const STEEL: Color = Color(0.42, 0.45, 0.48)
const DARK_STEEL: Color = Color(0.22, 0.24, 0.26)
const CONCRETE: Color = Color(0.72, 0.72, 0.7)
const WHITE: Color = Color(0.93, 0.93, 0.9)
const CRANE: Color = Color(0.86, 0.52, 0.16)
const GREEN_ROOF: Color = Color(0.28, 0.42, 0.3)

static var _zoo: Dictionary = {}


## Lokaler Punkt -> Welt (XZ)
static func _w(p: Vector2, rot: float, lx: float, lz: float) -> Vector2:
	return p + Vector2(lx * cos(rot) + lz * sin(rot), -lx * sin(rot) + lz * cos(rot))


static func _w3(p: Vector2, rot: float, lx: float, y: float, lz: float) -> Vector3:
	var q: Vector2 = _w(p, rot, lx, lz)
	return Vector3(q.x, y, q.y)


static func _box_col(body: StaticBody3D, center: Vector3, size: Vector3, yaw: float = 0.0) -> void:
	var cs := CollisionShape3D.new()
	var bs := BoxShape3D.new()
	bs.size = size
	cs.shape = bs
	cs.transform = Transform3D(Basis(Vector3.UP, yaw), center)
	body.add_child(cs)


## Tonnendach (halber Zylinder) über einer Grundfläche lx0..lx1 x lz0..lz1, First entlang z.
static func _barrel(kit: MeshKit, key: String, p: Vector2, rot: float, cx: float, lz0: float, lz1: float, span: float, y: float,
		rise: float, col: Color, segs: int = 10) -> void:
	var prof: PackedVector2Array = PackedVector2Array()
	for i: int in segs + 1:
		var a: float = PI * float(i) / float(segs)
		prof.append(Vector2(cos(a) * span * 0.5, y + sin(a) * rise))
	kit.color = col
	var basis := Basis(Vector3.UP, rot)
	for i2: int in segs:
		var a0: Vector2 = prof[i2]
		var a1: Vector2 = prof[i2 + 1]
		var p00: Vector3 = _w3(p, rot, cx + a0.x, a0.y, lz0)
		var p01: Vector3 = _w3(p, rot, cx + a0.x, a0.y, lz1)
		var p10: Vector3 = _w3(p, rot, cx + a1.x, a1.y, lz0)
		var p11: Vector3 = _w3(p, rot, cx + a1.x, a1.y, lz1)
		var mid: float = PI * (float(i2) + 0.5) / float(segs)
		var n: Vector3 = basis * Vector3(cos(mid), sin(mid), 0.0).normalized()
		kit.add_quad(key, p00, p01, p11, p10, n)
		kit.add_quad(key, p10, p11, p01, p00, -n)
	kit.color = Color.WHITE


# ================================================================== Hauptbahnhof

static func hauptbahnhof(kit: MeshKit, body: StaticBody3D, p: Vector2, rot: float, y0: float) -> void:
	# Empfangsgebäude (Front nach Norden = -z): Mittelhalle mit großem Bogenfenster, Uhrturm, Seitenflügel
	var hall_w: float = 44.0
	var hall_d: float = 30.0
	var hall_h: float = 21.0
	var hc: Vector2 = _w(p, rot, 0, 0)
	ArchKit.block(kit, hc, Vector2(hall_w, hall_d), rot, y0, y0 + hall_h, SAND, 0.3, ArchKit.STYLE_PALACE, 6.0)
	_barrel(kit, "roof", p, rot, 0.0, -hall_d * 0.5 - 0.4, hall_d * 0.5 + 0.4, hall_w + 0.8, y0 + hall_h, 9.0, COPPER)
	_box_col(body, Vector3(hc.x, y0 + hall_h * 0.5 + 2.0, hc.y), Vector3(hall_w, hall_h + 4.0, hall_d), rot)
	# Bogenfenster in der Giebelfläche (vorne): Glasbogen + Sprossen
	var arch_r: float = 17.0
	var fz: float = -hall_d * 0.5 - 0.35
	for i: int in 16:
		var a0: float = PI * float(i) / 16.0
		var a1: float = PI * float(i + 1) / 16.0
		var q0: Vector3 = _w3(p, rot, cos(a0) * arch_r, y0 + hall_h - 2.0 + sin(a0) * 8.0, fz)
		var q1: Vector3 = _w3(p, rot, cos(a1) * arch_r, y0 + hall_h - 2.0 + sin(a1) * 8.0, fz)
		var b0: Vector3 = _w3(p, rot, cos(a0) * arch_r, y0 + 6.0, fz)
		var b1: Vector3 = _w3(p, rot, cos(a1) * arch_r, y0 + 6.0, fz)
		kit.add_quad("glass_dark", b0, b1, q1, q0, Basis(Vector3.UP, rot) * Vector3(0, 0, -1))
	kit.color = SAND_LIGHT
	for i3: int in 9:
		var lx: float = -arch_r + float(i3) * arch_r * 2.0 / 8.0
		var top: float = hall_h - 2.0 + sqrt(maxf(0.0, 1.0 - pow(lx / arch_r, 2.0))) * 8.0
		kit.add_box("stone", _w3(p, rot, lx, y0 + 6.0 + (top - 6.0) * 0.5, fz - 0.2), Vector3(0.5, top - 6.0, 0.4), Basis(Vector3.UP, rot))
	kit.add_box("stone", _w3(p, rot, 0, y0 + 12.0, fz - 0.2), Vector3(arch_r * 2.0, 0.5, 0.4), Basis(Vector3.UP, rot))
	# Vordach über den Eingängen
	kit.color = DARK_STEEL
	kit.add_box("stone", _w3(p, rot, 0, y0 + 5.2, fz - 4.0), Vector3(30.0, 0.5, 8.0), Basis(Vector3.UP, rot))
	for sx: float in [-13.0, -4.5, 4.5, 13.0]:
		kit.add_cylinder("stone", _w3(p, rot, sx, y0, fz - 7.2), 0.2, 0.2, 5.2, 8)
	# Uhrturm (östlich der Halle)
	var tx: float = hall_w * 0.5 + 6.0
	var tc: Vector2 = _w(p, rot, tx, -6.0)
	ArchKit.block(kit, tc, Vector2(10, 10), rot, y0, y0 + 42.0, SAND, 0.7, ArchKit.STYLE_PALACE, 6.0)
	kit.color = SLATE
	kit.add_pyramid("roof", Vector3(tc.x, y0 + 42.0, tc.y), 11.5, 9.0, Basis(Vector3.UP, rot))
	kit.color = WHITE
	for face: int in 4:
		var ang: float = rot + float(face) * PI * 0.5
		var off: Vector2 = Vector2(sin(ang), cos(ang)) * 5.15
		kit.add_cylinder("lamp_glow", Vector3(tc.x + off.x, y0 + 36.0, tc.y + off.y), 2.2, 2.2, 0.12, 16,
			Basis(Vector3.UP, ang) * Basis(Vector3.RIGHT, PI * 0.5))
	kit.color = Color.WHITE
	_box_col(body, Vector3(tc.x, y0 + 25.0, tc.y), Vector3(10, 50, 10), rot)
	# Seitenflügel
	for side: float in [-1.0, 1.0]:
		var wc: Vector2 = _w(p, rot, side * (hall_w * 0.5 + (16.0 if side > 0 else 0.0) + 45.0), 2.0)
		ArchKit.block(kit, wc, Vector2(90, 18), rot, y0, y0 + 14.0, SAND, 0.45 + side * 0.1, ArchKit.STYLE_PALACE, 5.0)
		ArchKit.mansard_roof(kit, wc, Vector2(90, 18), rot, y0 + 14.0, 3.4, 1.4, 1.1, SLATE)
		_box_col(body, Vector3(wc.x, y0 + 9.0, wc.y), Vector3(90, 18, 18), rot)
	# Bahnsteighallen (drei Tonnenhallen aus Stahl und Glas) südlich des Empfangsgebäudes
	for k: int in 3:
		var cx: float = -52.0 + float(k) * 52.0
		_barrel(kit, "vertex_metal", p, rot, cx, 24.0, 210.0, 46.0, y0 + 9.0, 8.0, STEEL, 12)
		kit.color = DARK_STEEL
		var zz: float = 30.0
		while zz <= 204.0:
			for sx2: float in [-22.5, 22.5]:
				var cb: Vector3 = _w3(p, rot, cx + sx2, y0, zz)
				kit.add_cylinder("vertex_metal", cb, 0.3, 0.25, 9.0, 8)
				var cs := CollisionShape3D.new()
				var cyl := CylinderShape3D.new()
				cyl.radius = 0.3
				cyl.height = 9.0
				cs.shape = cyl
				cs.position = cb + Vector3(0, 4.5, 0)
				body.add_child(cs)
			zz += 18.0
		kit.color = Color.WHITE


# ================================================================== Zoo

static func _zoo_layout() -> Dictionary:
	if _zoo.is_empty():
		var f: FileAccess = FileAccess.open("res://data/world/zoo_layout.json", FileAccess.READ)
		if f != null:
			var d: Variant = JSON.parse_string(f.get_as_text())
			_zoo = d if d is Dictionary else {}
	return _zoo


## Gehege-Anordnung aus den Weltdaten übernehmen (vom Generator an die reale Zoofläche angepasst, OSM-Quelle);
## ohne Angabe gilt wieder die Standarddatei.
static func use_zoo_layout_from(landmarks: Array) -> void:
	_zoo = {}
	for lmv: Variant in landmarks:
		if lmv is Dictionary and str((lmv as Dictionary).get("type", "")) == "zoo" and (lmv as Dictionary).has("enclosures"):
			_zoo = {"entrance": (lmv as Dictionary).get("entrance", [0, 250]), "enclosures": (lmv as Dictionary).enclosures}


## Gehegedaten (lokale Koordinaten) für Tiere (W6).
static func zoo_enclosures() -> Array:
	return _zoo_layout().get("enclosures", [])


static func zoo(kit: MeshKit, body: StaticBody3D, p: Vector2, rot: float, y0: float) -> void:
	var lay: Dictionary = _zoo_layout()
	# Eingangsgebäude mit Torbögen
	var ent: Array = lay.get("entrance", [0, 250])
	var ex: float = float(ent[0])
	var ez: float = float(ent[1])
	for side: float in [-1.0, 1.0]:
		var bc: Vector2 = _w(p, rot, ex + side * 14.0, ez)
		ArchKit.block(kit, bc, Vector2(12, 9), rot, y0, y0 + 7.5, SAND_LIGHT, 0.2, ArchKit.STYLE_NORMAL, 3.8)
		ArchKit.flat_roof(kit, ArchKit.rect_poly(bc, Vector2(12, 9), rot), y0 + 7.5, SLATE, SAND)
		_box_col(body, Vector3(bc.x, y0 + 3.75, bc.y), Vector3(12, 7.5, 9), rot)
	kit.color = SAND
	kit.add_box("stone", _w3(p, rot, ex, y0 + 8.0, ez), Vector3(18.0, 1.4, 3.0), Basis(Vector3.UP, rot))
	kit.color = Color(0.95, 0.85, 0.3)
	kit.add_box("stone", _w3(p, rot, ex, y0 + 8.0, ez - 1.6), Vector3(9.0, 0.9, 0.1), Basis(Vector3.UP, rot))
	kit.color = Color.WHITE
	# Gehege: Zaun (Pfosten + Handlauf), Unterstand, Wasserbecken, Felsen
	for encv: Variant in lay.get("enclosures", []):
		var enc: Dictionary = encv
		var c: Array = enc.center
		var s: Array = enc.size
		var cx: float = float(c[0])
		var cz: float = float(c[1])
		var hx: float = float(s[0]) * 0.5
		var hz: float = float(s[1]) * 0.5
		var corners: Array[Vector2] = [Vector2(cx - hx, cz - hz), Vector2(cx + hx, cz - hz), Vector2(cx + hx, cz + hz), Vector2(cx - hx, cz + hz)]
		for i: int in 4:
			var a: Vector2 = corners[i]
			var b: Vector2 = corners[(i + 1) % 4]
			var L: float = a.distance_to(b)
			var n: int = maxi(2, int(L / 3.0))
			kit.color = Color(0.36, 0.3, 0.22)
			for k: int in n + 1:
				var q: Vector2 = a.lerp(b, float(k) / float(n))
				kit.add_box("stone", _w3(p, rot, q.x, y0 + 0.75, q.y), Vector3(0.14, 1.5, 0.14), Basis(Vector3.UP, rot))
			var m: Vector2 = (a + b) * 0.5
			var yaw: float = rot + atan2(b.x - a.x, b.y - a.y)
			for hgt: float in [0.7, 1.35]:
				kit.add_box("stone", _w3(p, rot, m.x, y0 + hgt, m.y), Vector3(0.06, 0.08, L), Basis(Vector3.UP, yaw))
			var wc: Vector2 = _w(p, rot, m.x, m.y)
			_box_col(body, Vector3(wc.x, y0 + 0.9, wc.y), Vector3(0.2, 1.8, L), yaw)
		kit.color = Color.WHITE
		if enc.has("house"):
			var h: Array = enc.house
			var hc: Vector2 = _w(p, rot, cx + hx - float(h[0]) * 0.5 - 1.0, cz + hz - float(h[1]) * 0.5 - 1.0)
			ArchKit.block(kit, hc, Vector2(float(h[0]), float(h[1])), rot, y0, y0 + float(h[2]), Color(0.72, 0.62, 0.48), 0.15,
				ArchKit.STYLE_BLANK, 4.0)
			ArchKit.flat_roof(kit, ArchKit.rect_poly(hc, Vector2(float(h[0]), float(h[1])), rot), y0 + float(h[2]), GREEN_ROOF,
				Color(0.5, 0.44, 0.36))
			_box_col(body, Vector3(hc.x, y0 + float(h[2]) * 0.5, hc.y), Vector3(float(h[0]), float(h[2]), float(h[1])), rot)
		if enc.has("water"):
			var wv: Array = enc.water
			var wcx: float = cx - hx * 0.35
			var wcz: float = cz - hz * 0.3
			var poly: PackedVector2Array = PackedVector2Array()
			for i2: int in 14:
				var ang: float = TAU * float(i2) / 14.0
				poly.append(_w(p, rot, wcx + cos(ang) * float(wv[0]) * 0.5, wcz + sin(ang) * float(wv[1]) * 0.5))
			kit.add_polygon_xz("water", PolyUtil.ensure_ccw(poly), y0 + 0.02, 1.0)
		for r: int in int(enc.get("rocks", 0)):
			var rx: float = cx + (DetRng.hash01(r, int(cx), 1) - 0.5) * hx * 1.4
			var rz: float = cz + (DetRng.hash01(r, int(cz), 2) - 0.5) * hz * 1.4
			var rs: float = 1.2 + DetRng.hash01(r, 3, int(cx)) * 1.8
			kit.color = Color(0.5, 0.47, 0.44)
			kit.add_sphere("stone", _w3(p, rot, rx, y0 + rs * 0.4, rz), Vector3(rs * 1.3, rs * 0.9, rs), 4, 7)
		for t: int in int(enc.get("climb", 0)):
			var tx: float = cx - hx * 0.5 + float(t) * hx * 0.5
			kit.color = Color(0.42, 0.3, 0.2)
			kit.add_cylinder("stone", _w3(p, rot, tx, y0, cz), 0.25, 0.2, 7.0, 6)
			kit.add_box("stone", _w3(p, rot, tx, y0 + 5.0, cz), Vector3(4.0, 0.2, 0.2), Basis(Vector3.UP, rot))
		kit.color = Color.WHITE
		# Schild mit Tiername
		kit.color = Color(0.2, 0.32, 0.22)
		kit.add_box("stone", _w3(p, rot, cx, y0 + 1.6, cz - hz - 1.2), Vector3(2.4, 0.9, 0.1), Basis(Vector3.UP, rot))
		kit.add_box("stone", _w3(p, rot, cx, y0 + 0.6, cz - hz - 1.2), Vector3(0.1, 1.2, 0.1), Basis(Vector3.UP, rot))
		kit.color = Color.WHITE


# ================================================================== Stadion

static func stadion(kit: MeshKit, body: StaticBody3D, p: Vector2, rot: float, y0: float) -> void:
	var pw: float = 110.0   # Spielfeld inkl. Rand (x)
	var pd: float = 74.0    # (z)
	var turf: PackedVector2Array = ArchKit.rect_poly(p, Vector2(pw, pd), rot)
	kit.add_polygon_xz("turf", turf, y0 + 0.01, 1.0)
	kit.color = Color(0.95, 0.95, 0.95)
	kit.add_box("stone", _w3(p, rot, 0, y0 + 0.02, 0), Vector3(0.15, 0.02, 68.0), Basis(Vector3.UP, rot))
	kit.color = Color.WHITE
	# vier Tribünen: gestufte Ränge (Profil) + Dach; Ecken offen (Zugang)
	var stands: Array = [[0.0, -pd * 0.5, pw, 0.0], [0.0, pd * 0.5, pw, PI], [-pw * 0.5, 0.0, pd, PI * 0.5], [pw * 0.5, 0.0, pd, -PI * 0.5]]
	for st: Array in stands:
		var sx: float = st[0]
		var sz: float = st[1]
		var length: float = st[2]
		var face: float = st[3]
		var basis := Basis(Vector3.UP, rot + face)
		var origin: Vector3 = _w3(p, rot, sx, y0, sz)
		# Profil in (z_rueckwaerts, y): Stufen nach hinten ansteigend (lokal -z = zum Feld)
		var prof: PackedVector2Array = PackedVector2Array([Vector2(0, 0)])
		for k: int in 9:
			prof.append(Vector2(-(1.0 + float(k) * 2.4), 1.0 + float(k) * 1.9))
			prof.append(Vector2(-(1.0 + float(k + 1) * 2.4), 1.0 + float(k) * 1.9))
		prof.append(Vector2(-(1.0 + 9.0 * 2.4), 0.0))
		kit.color = CONCRETE
		kit.add_extruded_profile("stone", prof, -length * 0.5, length * 0.5, [], basis, origin)
		# Sitzreihen farbig
		kit.color = Color(0.72, 0.14, 0.12) if face == 0.0 or face == PI else Color(0.12, 0.28, 0.6)
		for k2: int in 9:
			var zc: float = -(1.0 + float(k2) * 2.4 + 1.2)
			kit.add_box("stone", origin + basis * Vector3(0, 1.0 + float(k2) * 1.9 + 0.25, zc), Vector3(length - 2.0, 0.5, 0.8), basis)
		# Dach
		kit.color = WHITE
		kit.add_box("stone", origin + basis * Vector3(0, 22.0, -14.0), Vector3(length + 6.0, 0.8, 30.0), basis)
		kit.color = DARK_STEEL
		for k3: int in 6:
			var xk: float = -length * 0.5 + float(k3) * length / 5.0
			kit.add_box("stone", origin + basis * Vector3(xk, 11.0, -24.5), Vector3(0.8, 22.0, 0.8), basis)
		kit.color = Color.WHITE
		# Kollision: Tribünenkörper (Rückwand) – das Innere bleibt über die Ecken erreichbar
		var cc: Vector3 = origin + basis * Vector3(0, 9.5, -12.0)
		_box_col(body, cc, Vector3(length, 19.0, 22.0), rot + face)
	# Flutlicht-Masten in den Ecken
	for sx2: float in [-1.0, 1.0]:
		for sz2: float in [-1.0, 1.0]:
			var mb: Vector3 = _w3(p, rot, sx2 * (pw * 0.5 + 18.0), y0, sz2 * (pd * 0.5 + 18.0))
			kit.color = STEEL
			kit.add_cylinder("vertex_metal", mb, 0.6, 0.4, 38.0, 8)
			kit.color = WHITE
			kit.add_box("lamp_glow", mb + Vector3(0, 38.5, 0), Vector3(5.0, 3.0, 0.6), Basis(Vector3.UP, rot + atan2(-sx2, -sz2)))
			var cs := CollisionShape3D.new()
			var cyl := CylinderShape3D.new()
			cyl.radius = 0.6
			cyl.height = 38.0
			cs.shape = cyl
			cs.position = mb + Vector3(0, 19.0, 0)
			body.add_child(cs)
	kit.color = Color.WHITE


# ================================================================== Gewächshäuser

static func gewaechshaus(kit: MeshKit, body: StaticBody3D, p: Vector2, rot: float, y0: float) -> void:
	var houses: Array = [[0.0, 0.0, 32.0, 20.0, 7.0, 8.0], [-30.0, 4.0, 24.0, 12.0, 5.0, 4.5], [30.0, 4.0, 24.0, 12.0, 5.0, 4.5]]
	for hv: Array in houses:
		var lx: float = hv[0]
		var lz: float = hv[1]
		var w: float = hv[2]
		var d: float = hv[3]
		var wall_h: float = hv[4]
		var rise: float = hv[5]
		var c: Vector2 = _w(p, rot, lx, lz)
		var poly: PackedVector2Array = ArchKit.rect_poly(c, Vector2(w, d), rot)
		kit.color = Color(0.85, 0.85, 0.82)
		kit.add_box("stone", Vector3(c.x, y0 + 0.4, c.y), Vector3(w + 0.4, 0.8, d + 0.4), Basis(Vector3.UP, rot))
		kit.color = Color.WHITE
		for i: int in 4:
			var a: Vector2 = poly[i]
			var b: Vector2 = poly[(i + 1) % 4]
			var dd: Vector2 = b - a
			var n2: Vector2 = Vector2(dd.y, -dd.x).normalized()
			kit.add_quad("glass", Vector3(a.x, y0 + 0.8, a.y), Vector3(b.x, y0 + 0.8, b.y), Vector3(b.x, y0 + wall_h, b.y),
				Vector3(a.x, y0 + wall_h, a.y), Vector3(n2.x, 0, n2.y))
			# Sprossen
			var L: float = dd.length()
			kit.color = WHITE
			var k: int = int(L / 2.5)
			for j: int in k + 1:
				var q: Vector2 = a.lerp(b, float(j) / float(maxi(k, 1)))
				kit.add_box("stone", Vector3(q.x, y0 + wall_h * 0.5 + 0.4, q.y), Vector3(0.12, wall_h - 0.8, 0.12))
			kit.color = Color.WHITE
		# gewölbtes Glasdach (Tonnendach entlang der kurzen Seite)
		_barrel(kit, "glass", p, rot, lx, lz - d * 0.5, lz + d * 0.5, w, y0 + wall_h, rise, Color.WHITE, 10)
		kit.color = WHITE
		var zz: float = lz - d * 0.5
		while zz <= lz + d * 0.5 + 0.01:
			for s: int in 10:
				var a0: float = PI * float(s) / 10.0
				var a1: float = PI * float(s + 1) / 10.0
				var q0: Vector3 = _w3(p, rot, lx + cos(a0) * w * 0.5, y0 + wall_h + sin(a0) * rise, zz)
				var q1: Vector3 = _w3(p, rot, lx + cos(a1) * w * 0.5, y0 + wall_h + sin(a1) * rise, zz)
				var mid: Vector3 = (q0 + q1) * 0.5
				var len2: float = q0.distance_to(q1)
				kit.add_box("stone", mid, Vector3(0.1, 0.1, len2), Basis.looking_at((q1 - q0).normalized(), Vector3.UP))
			zz += 3.0
		kit.color = Color.WHITE
		_box_col(body, Vector3(c.x, y0 + (wall_h + rise) * 0.5, c.y), Vector3(w, wall_h + rise, d), rot)


# ================================================================== Hafenkräne

static func hafenkran(kit: MeshKit, body: StaticBody3D, p: Vector2, rot: float, y0: float) -> void:
	for i: int in 4:
		var lx: float = -60.0 + float(i) * 40.0
		var jib: float = deg_to_rad(20.0 + DetRng.hash01(i, 5, 1) * 25.0)
		var turn: float = (DetRng.hash01(i, 9, 2) - 0.5) * 1.2
		kit.color = CRANE
		# Portal (4 Beine) über dem Kaigleis
		for sx: float in [-4.0, 4.0]:
			for sz: float in [-4.0, 4.0]:
				var leg: Vector3 = _w3(p, rot, lx + sx, y0, sz)
				kit.add_box("vertex_metal", leg + Vector3(0, 6.0, 0), Vector3(0.8, 12.0, 0.8), Basis(Vector3.UP, rot))
				_box_col(body, leg + Vector3(0, 6.0, 0), Vector3(0.8, 12.0, 0.8), rot)
		kit.add_box("vertex_metal", _w3(p, rot, lx, y0 + 12.5, 0), Vector3(10.0, 1.2, 10.0), Basis(Vector3.UP, rot))
		# Drehteil mit Kabine und Ausleger
		var top: Vector3 = _w3(p, rot, lx, y0 + 13.0, 0)
		var b := Basis(Vector3.UP, rot + turn)
		kit.add_box("vertex_metal", top + b * Vector3(0, 2.5, 1.5), Vector3(4.5, 5.0, 7.0), b)
		kit.color = Color(0.2, 0.25, 0.3)
		kit.add_box("glass_dark", top + b * Vector3(0, 3.0, -2.2), Vector3(3.6, 2.4, 0.2), b)
		kit.color = CRANE
		var boom_len: float = 32.0
		var dir: Vector3 = b * Vector3(0, sin(jib), -cos(jib))
		var boom_c: Vector3 = top + Vector3(0, 4.0, 0) + dir * boom_len * 0.5
		kit.add_box("vertex_metal", boom_c, Vector3(1.2, 1.2, boom_len), Basis.looking_at(dir, Vector3.UP))
		kit.color = DARK_STEEL
		var tip: Vector3 = top + Vector3(0, 4.0, 0) + dir * boom_len
		kit.add_box("vertex_metal", tip - Vector3(0, (tip.y - y0 - 6.0) * 0.5, 0), Vector3(0.08, tip.y - y0 - 6.0, 0.08))
		kit.add_box("vertex_metal", Vector3(tip.x, y0 + 6.0, tip.z), Vector3(1.5, 0.6, 1.5))
		kit.color = Color.WHITE


# ================================================================== Turmberg

static func turmberg(kit: MeshKit, body: StaticBody3D, node: Node3D, p: Vector2, rot: float, y0: float) -> void:
	# Terrasse mit Treppe, mittelalterlicher Bergfried (Aussichtsturm) mit Zinnen
	var terrace: Vector2 = Vector2(12, 12)   # Straße (Reichardtstraße) führt real ≈ 10 m am Turm vorbei
	kit.color = RED_SAND.darkened(0.15)
	kit.add_box("stone", Vector3(p.x, y0 + 1.5, p.y), Vector3(terrace.x, 3.0, terrace.y), Basis(Vector3.UP, rot))
	_box_col(body, Vector3(p.x, y0 + 1.5, p.y), Vector3(terrace.x, 3.0, terrace.y), rot)
	for k: int in 6:
		kit.add_box("stone", _w3(p, rot, 0, y0 + 0.25 + float(k) * 0.5, -terrace.y * 0.5 - 3.0 + float(k) * 0.5),
			Vector3(5.0, 0.5, 0.5 + (6.0 - float(k)) * 0.5), Basis(Vector3.UP, rot))
	kit.color = Color.WHITE
	var t0: float = y0 + 3.0
	var th: float = 28.0
	ArchKit.block(kit, p, Vector2(9, 9), rot, t0, t0 + th, RED_SAND, 0.5, ArchKit.STYLE_BLANK, 4.0)
	kit.color = RED_SAND.lightened(0.05)
	for i: int in 4:
		for j: int in 4:
			var lx: float = -4.5 + 0.6 + float(j) * 2.6
			var ang: float = rot + float(i) * PI * 0.5
			var off: Vector2 = Vector2(sin(ang), cos(ang)) * 4.3
			var side: Vector2 = Vector2(cos(ang), -sin(ang)) * lx
			kit.add_box("stone", Vector3(p.x + off.x + side.x, t0 + th + 0.8, p.y + off.y + side.y), Vector3(1.2, 1.6, 0.8),
				Basis(Vector3.UP, ang))
	kit.color = Color.WHITE
	kit.add_polygon_xz("flat", ArchKit.rect_poly(p, Vector2(9, 9), rot), t0 + th, 1.0)
	_box_col(body, Vector3(p.x, t0 + th * 0.5, p.y), Vector3(9, th, 9), rot)
	# Fernsilhouette des Bergs (nur aus der Ferne sichtbar, ohne Kollision – die Spielwelt ist eben)
	var hill := MeshKit.new()
	hill.set_material("hill", CityMaterials.get_mat("forest_floor"))
	var hc: Vector3 = Vector3(p.x + 120.0, y0 - 2.0, p.y)
	var rings: int = 6
	var segs: int = 24
	var R: float = 520.0
	var H: float = 105.0
	for r: int in rings:
		var f0: float = float(r) / float(rings)
		var f1: float = float(r + 1) / float(rings)
		for s: int in segs:
			var a0: float = TAU * float(s) / float(segs)
			var a1: float = TAU * float(s + 1) / float(segs)
			var y_0: float = H * (1.0 - f0 * f0)
			var y_1: float = H * (1.0 - f1 * f1)
			var p00: Vector3 = hc + Vector3(cos(a0) * R * f0, y_0, sin(a0) * R * f0)
			var p01: Vector3 = hc + Vector3(cos(a1) * R * f0, y_0, sin(a1) * R * f0)
			var p10: Vector3 = hc + Vector3(cos(a0) * R * f1, y_1, sin(a0) * R * f1)
			var p11: Vector3 = hc + Vector3(cos(a1) * R * f1, y_1, sin(a1) * R * f1)
			hill.color = Color(0.2, 0.3, 0.2)
			hill.add_quad("hill", p00, p10, p11, p01, Vector3.UP)
	var hm := MeshInstance3D.new()
	hm.name = "Bergsilhouette"
	hm.mesh = hill.commit()
	hm.visibility_range_begin = 900.0
	hm.visibility_range_begin_margin = 150.0
	hm.visibility_range_fade_mode = GeometryInstance3D.VISIBILITY_RANGE_FADE_SELF
	hm.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	node.add_child(hm)


# ================================================================== Staatstheater

static func staatstheater(kit: MeshKit, body: StaticBody3D, p: Vector2, rot: float, y0: float) -> void:
	# Gestaffelte Baukörper (Bühnenturm, Zuschauerhäuser) mit verglastem Foyer an der Front (-z)
	var parts: Array = [[0.0, 10.0, 70.0, 50.0, 16.0], [-22.0, 18.0, 30.0, 34.0, 24.0], [20.0, 20.0, 26.0, 30.0, 30.0], [0.0, 42.0, 60.0, 14.0, 12.0]]
	for pv: Array in parts:
		var c: Vector2 = _w(p, rot, pv[0], pv[1])
		var sz: Vector2 = Vector2(pv[2], pv[3])
		ArchKit.block(kit, c, sz, rot, y0, y0 + float(pv[4]), CONCRETE, 0.2, ArchKit.STYLE_MODERN, 4.0)
		ArchKit.flat_roof(kit, ArchKit.rect_poly(c, sz, rot), y0 + float(pv[4]), DARK_STEEL, CONCRETE.darkened(0.1))
		_box_col(body, Vector3(c.x, y0 + float(pv[4]) * 0.5, c.y), Vector3(sz.x, float(pv[4]), sz.y), rot)
	# Glasfoyer
	var fc: Vector2 = _w(p, rot, 0.0, -21.0)
	var fpoly: PackedVector2Array = ArchKit.rect_poly(fc, Vector2(64, 8), rot)
	for i: int in 4:
		var a: Vector2 = fpoly[i]
		var b: Vector2 = fpoly[(i + 1) % 4]
		var dd: Vector2 = b - a
		var n2: Vector2 = Vector2(dd.y, -dd.x).normalized()
		kit.add_quad("glass_dark", Vector3(a.x, y0, a.y), Vector3(b.x, y0, b.y), Vector3(b.x, y0 + 9.0, b.y), Vector3(a.x, y0 + 9.0, a.y),
			Vector3(n2.x, 0, n2.y))
	kit.color = WHITE
	kit.add_box("stone", Vector3(fc.x, y0 + 9.2, fc.y), Vector3(66, 0.5, 10), Basis(Vector3.UP, rot))
	kit.color = Color.WHITE
	_box_col(body, Vector3(fc.x, y0 + 4.5, fc.y), Vector3(64, 9, 8), rot)
