class_name PropsBuilder
extends RefCounted
## Stadtmobiliar und Grün: Laternen und Bäume (MultiMesh), Bänke, Fahrräder, Poller, Mülleimer,
## Litfaßsäulen, Kioske, Schlossplatz-Gestaltung, Baustelle, Hofinventar, Schilder.
## Alle Platzierungen deterministisch.

const LAMP_SPACING: float = 30.0
const SHOP_NAMES: Array[String] = [
	"Schuhhaus Sohle", "Café Fächerblick", "Optik Weitblick", "Buchladen Seitenwind", "Drogerie Glanz",
	"Mode Laufsteg", "Uhren Zeitlos", "Spielwaren Kreisel", "Blumen Stängel", "Metzgerei Wurzel",
	"Eiscafé Kugelrund", "Hut & Haube", "Brillen Scharf", "Teeladen Aufguss", "Radhaus Speiche",
	"Feinkost Gaumen", "Parfümerie Duftnote", "Schreibwaren Tinte", "Juwelier Funkel", "Döner Eck 7",
]

static var lamp_heads: PackedVector3Array = PackedVector3Array()


static func build(root: Node3D, g: CityGraph, blocks: Array[Dictionary]) -> void:
	lamp_heads.clear()
	var slab_h: float = float(g.layout.get("slab_height", 0.12))
	var container := Node3D.new()
	container.name = "Ausstattung"
	root.add_child(container)
	var body := StaticBody3D.new()
	body.name = "AusstattungKollision"
	body.collision_layer = Layers.WORLD
	container.add_child(body)
	var furn := MeshKit.new()
	CityMaterials.apply(furn, ["vertex", "vertex_metal", "lamp_glow", "water", "glass_dark"] as Array[String])
	furn.set_material("gravel", CityMaterials.get_mat("gravel"))

	var lamp_xf: Array[Transform3D] = []
	var tree_a: Array[Transform3D] = []
	var tree_b: Array[Transform3D] = []
	_street_lamps_and_alleys(g, slab_h, lamp_xf, tree_a, body)
	_park(g, furn, slab_h, tree_a, tree_b, body)
	_forest(tree_b)
	_pedestrian_furniture(g, furn, slab_h, tree_a, body)
	_plazas(g, furn, slab_h, tree_a, body)
	_construction_and_yards(g, furn, slab_h, body)
	_mm(container, "Laternen", _lamp_mesh(), lamp_xf, Settings.prop_visibility() * 1.6)
	_mm(container, "Baeume_Linde", _tree_mesh(false), tree_a, 0.0)
	_mm(container, "Baeume_Pappel", _tree_mesh(true), tree_b, 0.0)
	for t: Transform3D in tree_a + tree_b:
		if absf(t.origin.x) < 700.0 and absf(t.origin.z - 50.0) < 760.0:
			_cyl(body, t.origin, 0.3, 3.0)
	var mi := MeshInstance3D.new()
	mi.name = "Moebel"
	mi.mesh = furn.commit()
	container.add_child(mi)
	_signs(container, g, slab_h)


static func _mm(parent: Node3D, n: String, mesh: Mesh, xfs: Array[Transform3D], vis_end: float) -> void:
	if xfs.is_empty():
		return
	var mm := MultiMesh.new()
	mm.transform_format = MultiMesh.TRANSFORM_3D
	mm.mesh = mesh
	mm.instance_count = xfs.size()
	for i: int in xfs.size():
		mm.set_instance_transform(i, xfs[i])
	var mmi := MultiMeshInstance3D.new()
	mmi.name = n
	mmi.multimesh = mm
	if vis_end > 0.0:
		mmi.visibility_range_end = vis_end
		mmi.visibility_range_end_margin = 20.0
	parent.add_child(mmi)


static func _cyl(body: StaticBody3D, base: Vector3, r: float, h: float) -> void:
	var cs := CollisionShape3D.new()
	var c := CylinderShape3D.new()
	c.radius = r
	c.height = h
	cs.shape = c
	cs.position = base + Vector3(0, h * 0.5, 0)
	body.add_child(cs)


static func _box(body: StaticBody3D, center: Vector3, size: Vector3, yaw: float = 0.0) -> void:
	var cs := CollisionShape3D.new()
	var b := BoxShape3D.new()
	b.size = size
	cs.shape = b
	cs.transform = Transform3D(Basis(Vector3.UP, yaw), center)
	body.add_child(cs)


# ------------------------------------------------------------------ Meshes

static func _lamp_mesh() -> ArrayMesh:
	var kit := MeshKit.new()
	kit.set_material("v", CityMaterials.get_mat("vertex_metal"))
	kit.set_material("g", CityMaterials.get_mat("lamp_glow"))
	kit.color = Color(0.16, 0.2, 0.19)
	kit.add_cylinder("v", Vector3(0, 0, 0), 0.13, 0.09, 0.5, 8)
	kit.add_cylinder("v", Vector3(0, 0.5, 0), 0.08, 0.06, 5.0, 8)
	kit.add_box("v", Vector3(0.55, 5.45, 0), Vector3(1.2, 0.08, 0.08))
	kit.add_box("v", Vector3(1.1, 5.35, 0), Vector3(0.5, 0.18, 0.34))
	kit.color = Color.WHITE
	kit.add_box("g", Vector3(1.1, 5.23, 0), Vector3(0.4, 0.06, 0.26))
	return kit.commit()


static func _tree_mesh(tall: bool) -> ArrayMesh:
	var kit := MeshKit.new()
	kit.set_material("v", CityMaterials.get_mat("vertex"))
	kit.color = Color(0.33, 0.24, 0.17)
	if tall:
		kit.add_cylinder("v", Vector3.ZERO, 0.24, 0.16, 5.0, 7)
		kit.color = Color(0.2, 0.33, 0.14)
		kit.add_sphere("v", Vector3(0, 7.0, 0), Vector3(1.9, 4.2, 1.9), 5, 7)
		kit.color = Color(0.24, 0.38, 0.16)
		kit.add_sphere("v", Vector3(0.4, 9.5, 0.2), Vector3(1.4, 2.8, 1.4), 4, 7)
	else:
		kit.add_cylinder("v", Vector3.ZERO, 0.26, 0.2, 3.4, 7)
		kit.color = Color(0.25, 0.4, 0.17)
		kit.add_sphere("v", Vector3(0, 5.2, 0), Vector3(3.0, 2.5, 3.0), 5, 8)
		kit.color = Color(0.3, 0.45, 0.2)
		kit.add_sphere("v", Vector3(1.2, 6.0, 0.6), Vector3(2.0, 1.8, 2.0), 4, 7)
		kit.color = Color(0.21, 0.35, 0.15)
		kit.add_sphere("v", Vector3(-1.0, 5.8, -0.8), Vector3(2.1, 1.9, 2.1), 4, 7)
	return kit.commit()


static func _bench(kit: MeshKit, pos: Vector3, yaw: float) -> void:
	var b := Basis(Vector3.UP, yaw)
	kit.color = Color(0.45, 0.3, 0.18)
	kit.add_box("vertex", pos + b * Vector3(0, 0.45, 0), Vector3(1.8, 0.07, 0.45), b)
	kit.add_box("vertex", pos + b * Vector3(0, 0.8, 0.22), Vector3(1.8, 0.35, 0.06), b)
	kit.color = Color(0.15, 0.16, 0.17)
	for sx: float in [-0.75, 0.75]:
		kit.add_box("vertex_metal", pos + b * Vector3(sx, 0.22, 0), Vector3(0.06, 0.45, 0.45), b)
	kit.color = Color.WHITE


static func _bike(kit: MeshKit, pos: Vector3, yaw: float, col: Color) -> void:
	var b := Basis(Vector3.UP, yaw)
	var wheel_basis := b * Basis(Vector3(0, 0, 1), PI * 0.5)
	kit.color = Color(0.08, 0.08, 0.08)
	for sz: float in [-0.52, 0.52]:
		kit.add_cylinder("vertex", pos + b * Vector3(-0.02, 0.34, sz), 0.34, 0.34, 0.04, 10, wheel_basis, false)
	kit.color = col
	kit.add_box("vertex_metal", pos + b * Vector3(0, 0.55, 0), Vector3(0.04, 0.05, 0.9), b)
	kit.add_box("vertex_metal", pos + b * Vector3(0, 0.62, 0.1), Vector3(0.04, 0.5, 0.05), b * Basis(Vector3(1, 0, 0), 0.4))
	kit.color = Color(0.1, 0.1, 0.1)
	kit.add_box("vertex", pos + b * Vector3(0, 0.88, 0.25), Vector3(0.12, 0.05, 0.22), b)
	kit.add_box("vertex_metal", pos + b * Vector3(0, 0.95, -0.45), Vector3(0.5, 0.03, 0.03), b)
	kit.color = Color.WHITE


static func _litfass(kit: MeshKit, body: StaticBody3D, pos: Vector3, seed: int) -> void:
	kit.color = Color(0.2, 0.25, 0.22)
	kit.add_cylinder("vertex", pos, 0.7, 0.7, 0.3, 12)
	var posters: Array[Color] = [Color(0.85, 0.3, 0.2), Color(0.95, 0.8, 0.3), Color(0.25, 0.45, 0.7), Color(0.9, 0.9, 0.85), Color(0.4, 0.6, 0.3)]
	for i: int in 3:
		kit.color = posters[(seed + i) % posters.size()]
		kit.add_cylinder("vertex", pos + Vector3(0, 0.3 + float(i) * 0.9, 0), 0.62, 0.62, 0.9, 12, Basis.IDENTITY, false)
	kit.color = Color(0.2, 0.25, 0.22)
	kit.add_cylinder("vertex", pos + Vector3(0, 3.0, 0), 0.72, 0.4, 0.35, 12)
	kit.add_sphere("vertex", pos + Vector3(0, 3.45, 0), Vector3(0.18, 0.18, 0.18), 3, 6)
	kit.color = Color.WHITE
	_cyl(body, pos, 0.65, 3.3)


static func _bollard(kit: MeshKit, pos: Vector3) -> void:
	kit.color = Color(0.25, 0.27, 0.28)
	kit.add_cylinder("vertex_metal", pos, 0.1, 0.09, 0.85, 8)
	kit.color = Color(0.85, 0.85, 0.82)
	kit.add_cylinder("vertex", pos + Vector3(0, 0.62, 0), 0.105, 0.105, 0.08, 8, Basis.IDENTITY, false)
	kit.color = Color.WHITE


static func _bin(kit: MeshKit, pos: Vector3) -> void:
	kit.color = Color(0.9, 0.45, 0.1)
	kit.add_cylinder("vertex", pos, 0.25, 0.22, 0.85, 8)
	kit.color = Color.WHITE


# ------------------------------------------------------------------ Platzierung

static func _street_lamps_and_alleys(g: CityGraph, slab_h: float, lamps: Array[Transform3D], trees: Array[Transform3D], body: StaticBody3D) -> void:
	for e: int in g.edge_count():
		var na: int = g.edge_a[e]
		var nb: int = g.edge_b[e]
		var a: Vector2 = g.node_pos[na]
		var b: Vector2 = g.node_pos[nb]
		var length: float = a.distance_to(b)
		if length < 6.0:
			continue
		var dir: Vector2 = (b - a) / length
		var perp: Vector2 = Vector2(-dir.y, dir.x)
		var hw: float = g.edge_width(e) * 0.5
		var ped: bool = g.is_pedestrian(e)
		var off: float = (hw - 2.2) if ped else (hw + 0.55)
		var start: float = (g.node_radius(na, "all") + 6.0) if g.degree(na, "all") >= 3 else 5.0
		var stop: float = length - ((g.node_radius(nb, "all") + 6.0) if g.degree(nb, "all") >= 3 else 5.0)
		var t: float = start + fmod(float(e) * 7.3, LAMP_SPACING * 0.5)
		var side_toggle: int = e % 2
		while t < stop:
			for side: int in 2:
				if not ped and (side + side_toggle) % 2 == 1 and hw < 7.0:
					continue  # schmale Straßen: Laternen wechselseitig
				var s: float = -1.0 if side == 0 else 1.0
				var p: Vector2 = a + dir * t + perp * off * s
				var yaw: float = atan2(-(-perp * s).y, (-perp * s).x)
				var xf := Transform3D(Basis(Vector3.UP, yaw), Vector3(p.x, slab_h, p.y))
				lamps.append(xf)
				lamp_heads.append(xf * Vector3(1.1, 5.1, 0))
				_cyl(body, Vector3(p.x, slab_h, p.y), 0.12, 5.2)
			t += LAMP_SPACING
			side_toggle += 1
		# Alleebäume an Ring- und Hauptstraßen
		var kind: String = g.edge_kind(e)
		var sid: String = str(g.street_of(e).id)
		if kind == "ring" or sid == "karlstrasse" or sid == "zirkel":
			var tt: float = start + 8.0
			while tt < stop - 4.0:
				for s2: float in [-1.0, 1.0]:
					var q: Vector2 = a + dir * tt + perp * (hw + 2.0) * s2
					var rot: float = DetRng.hash01(e, int(tt), 3) * TAU
					var sc: float = 0.85 + DetRng.hash01(e, int(tt), 4) * 0.35
					trees.append(Transform3D(Basis(Vector3.UP, rot).scaled(Vector3.ONE * sc), Vector3(q.x, slab_h, q.y)))
				tt += 17.0


static func _park(g: CityGraph, kit: MeshKit, slab_h: float, trees_a: Array[Transform3D], trees_b: Array[Transform3D], body: StaticBody3D) -> void:
	var y: float = slab_h + 0.012
	# Kiesfläche vor dem Schloss (Halbkreis) und Wege entlang der Fächerstrahlen
	var fore: PackedVector2Array = PackedVector2Array()
	fore.append(Vector2(0, 0))
	for i: int in 25:
		var th: float = lerpf(-80.0, 80.0, float(i) / 24.0)
		fore.append(PolyUtil.polar(Vector2.ZERO, 88.0, th))
	kit.color = Color.WHITE
	kit.add_polygon_xz("gravel", PolyUtil.ensure_ccw(fore), y, 1.0)
	for k: int in range(-8, 9):
		var ang: float = float(k) * 11.25
		var p0: Vector2 = PolyUtil.polar(Vector2.ZERO, 86.0, ang)
		var p1: Vector2 = PolyUtil.polar(Vector2.ZERO, 192.0, ang)
		var d: Vector2 = (p1 - p0).normalized()
		var perp: Vector2 = Vector2(-d.y, d.x) * 1.6
		kit.add_polygon_xz("gravel", PolyUtil.ensure_ccw(PackedVector2Array([p0 - perp, p1 - perp, p1 + perp, p0 + perp])), y + 0.002, 1.0)
		# Baumreihen zwischen den Wegen
		if k < 8:
			var mid_ang: float = ang + 5.625
			for r: float in [112.0, 140.0, 168.0]:
				var tp: Vector2 = PolyUtil.polar(Vector2.ZERO, r, mid_ang)
				trees_a.append(Transform3D(Basis(Vector3.UP, DetRng.hash01(k, int(r), 1) * TAU), Vector3(tp.x, slab_h, tp.y)))
		# Bänke am Rand des Vorplatzes
		if absi(k) < 8 and k % 2 == 0:
			var bp: Vector2 = PolyUtil.polar(Vector2.ZERO, 92.0, ang + 5.625)
			var yaw: float = deg_to_rad(ang + 5.625) + PI
			_bench(kit, Vector3(bp.x, slab_h, bp.y), yaw)
	# Schlossgarten: See und verstreute Bäume
	var lake: PackedVector2Array = PackedVector2Array()
	for i2: int in 20:
		var a: float = TAU * float(i2) / 20.0
		lake.append(Vector2(-190, -250) + Vector2(cos(a) * 48.0, sin(a) * 26.0))
	kit.add_polygon_xz("water", PolyUtil.ensure_ccw(lake), slab_h + 0.03, 1.0)
	var rng := DetRng.make_rng(4711)
	var placed: int = 0
	var guard: int = 0
	while placed < 170 and guard < 2000:
		guard += 1
		var p: Vector2 = Vector2(rng.randf_range(-520, 520), rng.randf_range(-540, -30))
		if p.length() > 535.0 or p.length() < 60.0:
			continue
		if absf(p.x) < 8.0:
			continue  # Sichtachse nach Norden frei
		if p.distance_to(Vector2(-190, -250)) < 58.0:
			continue
		var tall: bool = rng.randf() < 0.4
		var sc: float = rng.randf_range(0.85, 1.3)
		var xf := Transform3D(Basis(Vector3.UP, rng.randf() * TAU).scaled(Vector3.ONE * sc), Vector3(p.x, slab_h, p.y))
		if tall:
			trees_b.append(xf)
		else:
			trees_a.append(xf)
		placed += 1


## Hardtwald-Kulisse außerhalb des Rundkurses (Norden) und lockere Bäume im Umland.
static func _forest(trees: Array[Transform3D]) -> void:
	var rng := DetRng.make_rng(1715)
	for i: int in 420:
		var ang: float = rng.randf_range(-PI, PI)
		var r: float = rng.randf_range(600.0, 860.0)
		var p: Vector2 = Vector2(sin(ang) * r, -absf(cos(ang)) * r * 0.95)
		if rng.randf() < 0.35:
			p = Vector2(rng.randf_range(-850, 850), rng.randf_range(690, 900))
			if absf(p.x) < 620.0 and p.y < 720.0:
				continue
		trees.append(Transform3D(Basis(Vector3.UP, rng.randf() * TAU).scaled(Vector3.ONE * rng.randf_range(0.9, 1.5)), Vector3(p.x, -0.03, p.y)))


static func _pedestrian_furniture(g: CityGraph, kit: MeshKit, slab_h: float, trees: Array[Transform3D], body: StaticBody3D) -> void:
	var bike_cols: Array[Color] = [Color(0.7, 0.1, 0.1), Color(0.1, 0.3, 0.6), Color(0.15, 0.15, 0.15), Color(0.2, 0.55, 0.3), Color(0.85, 0.85, 0.8)]
	var market: Rect2 = Rect2(Vector2(-46, 334), Vector2(92, 120))
	for e: int in g.edge_count():
		if not g.is_pedestrian(e):
			continue
		var na: int = g.edge_a[e]
		var nb: int = g.edge_b[e]
		var a: Vector2 = g.node_pos[na]
		var b: Vector2 = g.node_pos[nb]
		var length: float = a.distance_to(b)
		var dir: Vector2 = (b - a) / maxf(length, 0.01)
		var perp: Vector2 = Vector2(-dir.y, dir.x)
		var yaw_along: float = atan2(-dir.y, dir.x)
		var ta: float = g.node_radius(na, "drive") + 4.0
		var tb: float = length - g.node_radius(nb, "drive") - 4.0
		# Sichtachse Schloss–Marktplatz (Karl-Friedrich-Straße) freihalten: nur seitliche Baumreihen
		if str(g.street_of(e).id).begins_with("kfstrasse"):
			var tt: float = ta + 6.0
			while tt < tb:
				for s3: float in [-1.0, 1.0]:
					var tp: Vector2 = a + dir * tt + perp * 6.2 * s3
					if not market.has_point(tp):
						trees.append(Transform3D(Basis(Vector3.UP, tt).scaled(Vector3.ONE * 0.8), Vector3(tp.x, slab_h, tp.y)))
				tt += 18.0
			continue
		# Poller an Einfahrten in die Fußgängerzone
		for end: Array in [[na, ta, 1.0], [nb, tb, -1.0]]:
			if g.degree(int(end[0]), "drive") > 0:
				for k: int in range(-2, 3):
					var bp: Vector2 = a + dir * float(end[1]) + perp * float(k) * 3.4
					_bollard(kit, Vector3(bp.x, slab_h, bp.y))
					_cyl(body, Vector3(bp.x, slab_h, bp.y), 0.1, 0.85)
		var t: float = ta + 10.0
		var i: int = 0
		while t < tb - 6.0:
			var c: Vector2 = a + dir * t
			match i % 4:
				0:
					for s: float in [-1.0, 1.0]:
						var p: Vector2 = c + perp * 0.6 * s
						_bench(kit, Vector3(p.x, slab_h, p.y), yaw_along + (0.0 if s > 0.0 else PI))
						_box(body, Vector3(p.x, slab_h + 0.45, p.y), Vector3(1.8, 0.9, 0.5), yaw_along)
					_bin(kit, Vector3(c.x + dir.x * 1.6, slab_h, c.y + dir.y * 1.6))
				1:
					trees.append(Transform3D(Basis(Vector3.UP, float(e + i)).scaled(Vector3.ONE * 0.7), Vector3(c.x, slab_h + 0.5, c.y)))
					kit.color = Color(0.55, 0.53, 0.5)
					kit.add_box("vertex", Vector3(c.x, slab_h + 0.25, c.y), Vector3(2.0, 0.5, 2.0), Basis(Vector3.UP, yaw_along))
					kit.color = Color.WHITE
					_box(body, Vector3(c.x, slab_h + 0.25, c.y), Vector3(2.0, 0.5, 2.0), yaw_along)
				2:
					for s2: float in [-1.0, 1.0]:
						for k2: int in 4:
							var p2: Vector2 = c + perp * (g.edge_width(e) * 0.5 - 0.6) * s2 + dir * (float(k2) * 0.75 - 1.1)
							if DetRng.hash01(e, i, k2 + int(s2 * 7.0)) < 0.75:
								_bike(kit, Vector3(p2.x, slab_h, p2.y), yaw_along + PI * 0.5, bike_cols[(e + i + k2) % bike_cols.size()])
				3:
					if (e + i) % 3 == 0:
						_litfass(kit, body, Vector3(c.x + perp.x * 7.2, slab_h, c.y + perp.y * 7.2), e + i)
			t += 21.0
			i += 1


static func _plazas(g: CityGraph, kit: MeshKit, slab_h: float, trees: Array[Transform3D], body: StaticBody3D) -> void:
	for c: Variant in g.layout.get("clearings", []):
		var cd: Dictionary = c
		if not cd.has("circle"):
			continue
		var ci: Array = cd.circle
		var center: Vector2 = Vector2(float(ci[0]), float(ci[1]))
		var r: float = float(ci[2])
		for k: int in 6:
			var ang: float = TAU * float(k) / 6.0 + 0.3
			var tp: Vector2 = center + Vector2(cos(ang), sin(ang)) * r * 0.82
			if _on_block_surface(g, tp):
				trees.append(Transform3D(Basis(Vector3.UP, ang), Vector3(tp.x, slab_h, tp.y)))
			var bp: Vector2 = center + Vector2(cos(ang + 0.5), sin(ang + 0.5)) * r * 0.62
			if _on_block_surface(g, bp):
				_bench(kit, Vector3(bp.x, slab_h, bp.y), -ang)
		var lp: Vector2 = center + Vector2(r * 0.45, -r * 0.45)
		if _on_block_surface(g, lp):
			_litfass(kit, body, Vector3(lp.x, slab_h, lp.y), int(r))
	# Kioske
	for kd: Array in [[Vector2(236, 368), "Kiosk Fächerblick"], [Vector2(-490, 352), "Kiosk Europa"]]:
		var p: Vector2 = kd[0]
		kit.color = Color(0.25, 0.4, 0.35)
		kit.add_box("vertex", Vector3(p.x, slab_h + 1.4, p.y), Vector3(3.2, 2.8, 2.4))
		kit.color = Color(0.85, 0.3, 0.25)
		kit.add_box("vertex", Vector3(p.x, slab_h + 2.6, p.y + 1.5), Vector3(3.4, 0.1, 1.0), Basis(Vector3.RIGHT, -0.3))
		kit.color = Color.WHITE
		_box(body, Vector3(p.x, slab_h + 1.4, p.y), Vector3(3.2, 2.8, 2.4))


static func _on_block_surface(g: CityGraph, p: Vector2) -> bool:
	var nearest: Dictionary = g.nearest_edge_point(p, "all")
	if nearest.edge < 0:
		return true
	return float(nearest.dist) > g.edge_width(int(nearest.edge)) * 0.5 + 0.8


static func _construction_and_yards(g: CityGraph, kit: MeshKit, slab_h: float, body: StaticBody3D) -> void:
	for lot: Dictionary in BuildingBuilder.lots:
		if lot.removed != "baustelle":
			continue
		var q: PackedVector2Array = lot.quad
		for i: int in q.size():
			var a: Vector2 = q[i]
			var b: Vector2 = q[(i + 1) % q.size()]
			var length: float = a.distance_to(b)
			var dir: Vector2 = (b - a) / maxf(length, 0.01)
			var yaw: float = atan2(-dir.y, dir.x)
			var n: int = int(length / 2.2)
			for k: int in n:
				var p: Vector2 = a + dir * (float(k) + 0.5) * (length / float(maxi(n, 1)))
				kit.color = Color(0.85, 0.1, 0.1) if k % 2 == 0 else Color(0.95, 0.95, 0.95)
				kit.add_box("vertex", Vector3(p.x, slab_h + 0.8, p.y), Vector3(length / float(maxi(n, 1)) - 0.1, 0.35, 0.05), Basis(Vector3.UP, yaw))
				kit.color = Color(0.3, 0.3, 0.3)
				kit.add_box("vertex_metal", Vector3(p.x, slab_h + 0.5, p.y), Vector3(0.05, 1.0, 0.05))
			_box(body, Vector3((a.x + b.x) * 0.5, slab_h + 0.6, (a.y + b.y) * 0.5), Vector3(length, 1.2, 0.2), yaw)
		var cen: Vector2 = lot.centroid
		kit.color = Color(0.2, 0.45, 0.65)
		kit.add_box("vertex", Vector3(cen.x, slab_h + 1.3, cen.y), Vector3(6.0, 2.6, 2.5))
		kit.color = Color(0.95, 0.7, 0.1)
		kit.add_box("vertex", Vector3(cen.x + 2.5, slab_h + 1.0, cen.y + 3.0), Vector3(2.4, 1.6, 3.2))
		kit.add_box("vertex", Vector3(cen.x + 2.5, slab_h + 2.6, cen.y + 5.5), Vector3(0.4, 0.4, 4.0), Basis(Vector3.RIGHT, 0.5))
		kit.color = Color(1.0, 0.45, 0.05)
		for k2: int in 5:
			kit.add_cylinder("vertex", Vector3(cen.x - 3.0 + float(k2) * 1.2, slab_h, cen.y - 3.0), 0.2, 0.03, 0.7, 6)
		kit.color = Color.WHITE
		_box(body, Vector3(cen.x, slab_h + 1.3, cen.y), Vector3(6.0, 2.6, 2.5))
	# Hofinventar: Paletten/Pakete (Depot), Reifenstapel (Werkstatt), Kisten (Antiquitäten)
	var yard_items: Dictionary = {"depot_hof": Color(0.6, 0.45, 0.28), "maeule_hof": Color(0.1, 0.1, 0.1), "riegel_hof": Color(0.5, 0.35, 0.22), "lager_hof": Color(0.35, 0.4, 0.45)}
	for y: Variant in g.layout.get("yards", []):
		var yd: Dictionary = y
		var seed: Vector2 = Vector2(float(yd.seed[0]), float(yd.seed[1]))
		var col: Color = yard_items.get(str(yd.id), Color(0.5, 0.5, 0.5))
		for k3: int in 4:
			var p3: Vector2 = seed + Vector2(float(k3) * 2.2 - 3.3, 9.0)
			kit.color = col
			if str(yd.id) == "maeule_hof":
				for h: int in 3:
					kit.add_cylinder("vertex", Vector3(p3.x, slab_h + float(h) * 0.25, p3.y), 0.38, 0.38, 0.24, 10)
			else:
				kit.add_box("vertex", Vector3(p3.x, slab_h + 0.5, p3.y), Vector3(1.2, 1.0, 1.0))
			_box(body, Vector3(p3.x, slab_h + 0.5, p3.y), Vector3(1.2, 1.0, 1.0))
		kit.color = Color.WHITE


static func _signs(container: Node3D, g: CityGraph, slab_h: float) -> void:
	# POI-Schilder (Auftraggeber, Werkstätten)
	for pv: Variant in g.layout.get("pois", []):
		var p: Dictionary = pv
		if not p.has("sign"):
			continue
		var pos: Vector2 = Vector2(float(p.pos[0]), float(p.pos[1]))
		var yaw: float = deg_to_rad(float(p.get("yaw", 0.0)))
		var fwd: Vector3 = Basis(Vector3.UP, yaw) * Vector3(0, 0, -1)
		var lbl := Label3D.new()
		lbl.text = str(p.sign)
		lbl.font_size = 72
		lbl.pixel_size = 0.012
		lbl.modulate = Color(1.0, 0.92, 0.7)
		lbl.outline_size = 14
		lbl.outline_modulate = Color(0.15, 0.1, 0.08)
		lbl.billboard = BaseMaterial3D.BILLBOARD_FIXED_Y
		lbl.position = Vector3(pos.x, slab_h + 4.6, pos.y) - fwd * 1.5
		lbl.visibility_range_end = 120.0
		container.add_child(lbl)
	# Ladenschilder in der Fußgängerzone
	var n: int = 0
	for lot: Dictionary in BuildingBuilder.lots:
		if lot.removed != "" or not lot.shop or lot.solid:
			continue
		if not lot.shop_street and DetRng.hash01(int(lot.face), int(lot.index), 91) > 0.25:
			continue
		var q: PackedVector2Array = lot.quad
		var a: Vector2 = q[0]
		var b: Vector2 = q[1]
		var d: Vector2 = b - a
		if d.length() < 6.0:
			continue
		var out2: Vector2 = Vector2(d.y, -d.x).normalized()
		var mid: Vector2 = (a + b) * 0.5 + out2 * 0.06
		var lbl2 := Label3D.new()
		lbl2.text = SHOP_NAMES[(int(lot.face) * 7 + int(lot.index)) % SHOP_NAMES.size()]
		lbl2.font_size = 56
		lbl2.pixel_size = 0.009
		lbl2.modulate = Color(0.98, 0.97, 0.94)
		lbl2.outline_size = 10
		lbl2.outline_modulate = Color(0.08, 0.08, 0.1)
		lbl2.position = Vector3(mid.x, slab_h + 3.83, mid.y)
		lbl2.rotation = Vector3(0, atan2(out2.x, out2.y), 0)
		lbl2.double_sided = false
		lbl2.visibility_range_end = 90.0
		container.add_child(lbl2)
		n += 1
	# Straßennamensschilder an Kreuzungen
	var named: Dictionary = {}
	for e: int in g.edge_count():
		var st: Dictionary = g.street_of(e)
		var nm: String = str(st.name)
		var key: String = nm + str(int(g.node_pos[g.edge_a[e]].x / 150.0)) + str(int(g.node_pos[g.edge_a[e]].y / 150.0))
		if named.has(key) or g.degree(g.edge_a[e], "all") < 3:
			continue
		named[key] = true
		var na: int = g.edge_a[e]
		var dir2: Vector2 = g.edge_dir(e, na)
		var perp2: Vector2 = Vector2(-dir2.y, dir2.x)
		var sp: Vector2 = g.node_pos[na] + dir2 * (g.node_radius(na, "all") + 2.5) + perp2 * (g.edge_width(e) * 0.5 + 0.8)
		var sign := Label3D.new()
		sign.text = nm.replace(" (fiktiv)", "").replace(" (Fußgängerzone)", "")
		sign.font_size = 40
		sign.pixel_size = 0.008
		sign.modulate = Color(0.95, 0.96, 1.0)
		sign.outline_size = 12
		sign.outline_modulate = Color(0.1, 0.18, 0.45)
		sign.billboard = BaseMaterial3D.BILLBOARD_FIXED_Y
		sign.position = Vector3(sp.x, slab_h + 3.0, sp.y)
		sign.visibility_range_end = 70.0
		container.add_child(sign)
