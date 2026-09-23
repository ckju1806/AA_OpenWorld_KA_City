class_name GroundBuilder
extends RefCounted
## Boden der Stadt: Grundfläche + Wiese (Umland), Asphaltfläche innerhalb des Rundkurses,
## erhöhte Blockplatten (Gehwege, Höfe, Parks) mit Bordsteinen, erhöhte Fußgängerzonen,
## Fahrbahnmarkierungen und Zebrastreifen. Liefert Blockdaten für die Bebauung.

const MAX_SLAB: float = 0.12


static func build(root: Node3D, g: CityGraph) -> Array[Dictionary]:
	var slab_h: float = float(g.layout.get("slab_height", MAX_SLAB))
	var sidewalk: float = float(g.layout.get("sidewalk_width", 3.4))
	_ground(root, g)
	var blocks: Array[Dictionary] = []
	var body := StaticBody3D.new()
	body.name = "Bloecke"
	body.collision_layer = Layers.WORLD
	body.collision_mask = 0
	root.add_child(body)
	var kit := MeshKit.new()
	CityMaterials.apply(kit, ["sidewalk", "grass", "curb", "yard"] as Array[String])
	var faces_tris: PackedVector3Array = PackedVector3Array()
	for fi: int in g.faces.size():
		var f: Dictionary = g.faces[fi]
		var poly: PackedVector2Array = f.poly
		var edges: PackedInt32Array = f.edges
		var d1: PackedFloat32Array = PackedFloat32Array()
		var d2: PackedFloat32Array = PackedFloat32Array()
		for i: int in edges.size():
			var e: int = edges[i]
			d1.append(g.edge_width(e) * 0.5)
			d2.append(1.2 if g.is_pedestrian(e) else sidewalk)
		var curb: PackedVector2Array = PolyUtil.inset_per_edge(poly, d1)
		if curb.is_empty():
			curb = _fallback_inset(poly, _max(d1))
		if curb.is_empty():
			push_warning("Block %d konnte nicht aufgebaut werden." % fi)
			continue
		var line: PackedVector2Array = PolyUtil.inset_per_edge(curb, d2)
		var info: Dictionary = {"face": fi, "kind": f.kind, "curb": curb, "line": line, "edges": edges, "id": f.id}
		blocks.append(info)
		var top_key: String = "grass" if f.kind == "park" else "sidewalk"
		kit.add_polygon_xz(top_key, curb, slab_h, 1.0)
		kit.add_polygon_walls("curb", curb, 0.0, slab_h)
		_append_trimesh(faces_tris, curb, 0.0, slab_h)
	# Platzpflaster über Freiflächen (Marktplatz, Europaplatz, ...)
	kit.set_material("plaza", CityMaterials.get_mat("plaza"))
	for c: Variant in g.layout.get("clearings", []):
		var cpoly: PackedVector2Array = _clearing_poly(c)
		for b: Dictionary in blocks:
			if b.kind != "block":
				continue
			for part: PackedVector2Array in Geometry2D.intersect_polygons(PolyUtil.ensure_ccw(cpoly), b.curb):
				if part.size() >= 3:
					kit.add_polygon_xz("plaza", part, slab_h + 0.008, 1.0)
	var mi := MeshInstance3D.new()
	mi.name = "BlockPlatten"
	mi.mesh = kit.commit()
	root.add_child(mi)
	var cs := CollisionShape3D.new()
	var shape := ConcavePolygonShape3D.new()
	shape.set_faces(faces_tris)
	cs.shape = shape
	body.add_child(cs)
	_pedestrian_areas(root, g, slab_h)
	_markings(root, g)
	return blocks


static func _max(a: PackedFloat32Array) -> float:
	var m: float = 0.0
	for v: float in a:
		m = maxf(m, v)
	return m


static func _fallback_inset(poly: PackedVector2Array, d: float) -> PackedVector2Array:
	var res: Array[PackedVector2Array] = Geometry2D.offset_polygon(poly, -d, Geometry2D.JOIN_MITER)
	var best: PackedVector2Array = PackedVector2Array()
	for r: PackedVector2Array in res:
		if PolyUtil.area(r) > PolyUtil.area(best):
			best = r
	return PolyUtil.ensure_ccw(best) if best.size() >= 3 else PackedVector2Array()


## Dreiecke für Kollision: Oberseite + Seitenwände.
static func _append_trimesh(out: PackedVector3Array, poly: PackedVector2Array, y0: float, y1: float) -> void:
	var idx: PackedInt32Array = Geometry2D.triangulate_polygon(poly)
	for i: int in range(0, idx.size(), 3):
		var a: Vector2 = poly[idx[i]]
		var b: Vector2 = poly[idx[i + 1]]
		var c: Vector2 = poly[idx[i + 2]]
		out.append(Vector3(a.x, y1, a.y))
		out.append(Vector3(b.x, y1, b.y))
		out.append(Vector3(c.x, y1, c.y))
	var n: int = poly.size()
	for i: int in n:
		var a2: Vector2 = poly[i]
		var b2: Vector2 = poly[(i + 1) % n]
		var p0: Vector3 = Vector3(a2.x, y0, a2.y)
		var p1: Vector3 = Vector3(b2.x, y0, b2.y)
		var p2: Vector3 = Vector3(b2.x, y1, b2.y)
		var p3: Vector3 = Vector3(a2.x, y1, a2.y)
		out.append_array(PackedVector3Array([p0, p1, p2, p0, p2, p3]))


static func _ground(root: Node3D, g: CityGraph) -> void:
	var body := StaticBody3D.new()
	body.name = "Boden"
	body.collision_layer = Layers.WORLD
	body.collision_mask = 0
	var cs := CollisionShape3D.new()
	var bs := BoxShape3D.new()
	bs.size = Vector3(4000, 2, 4000)
	cs.shape = bs
	cs.position = Vector3(0, -1, 0)
	body.add_child(cs)
	root.add_child(body)
	# Wiese (Umland) etwas unter Null, Asphalt innerhalb des Rundkurses auf Null
	var kit := MeshKit.new()
	CityMaterials.apply(kit, ["grass", "asphalt"] as Array[String])
	var big: float = 2000.0
	kit.add_quad("grass", Vector3(-big, -0.03, -big), Vector3(big, -0.03, -big), Vector3(big, -0.03, big), Vector3(-big, -0.03, big), Vector3.UP)
	var outer: PackedVector2Array = PolyUtil.ensure_ccw(g.outer_boundary)
	var grown: Array[PackedVector2Array] = Geometry2D.offset_polygon(outer, 8.5, Geometry2D.JOIN_MITER)
	var best: PackedVector2Array = PackedVector2Array()
	for r: PackedVector2Array in grown:
		if PolyUtil.area(r) > PolyUtil.area(best):
			best = r
	if best.size() >= 3:
		kit.add_polygon_xz("asphalt", best, 0.0, 1.0)
	var mi := MeshInstance3D.new()
	mi.name = "Grundflaeche"
	mi.mesh = kit.commit()
	root.add_child(mi)
	# Unsichtbare Weltgrenze (Spieler bleibt in der Nähe der Stadt)
	var wall_body := StaticBody3D.new()
	wall_body.name = "Weltgrenze"
	wall_body.collision_layer = Layers.WORLD
	for spec: Array in [[Vector3(0, 20, -900), Vector3(2000, 60, 4)], [Vector3(0, 20, 1000), Vector3(2000, 60, 4)],
			[Vector3(-900, 20, 50), Vector3(4, 60, 2000)], [Vector3(900, 20, 50), Vector3(4, 60, 2000)]]:
		var wcs := CollisionShape3D.new()
		var wb := BoxShape3D.new()
		wb.size = spec[1]
		wcs.shape = wb
		wcs.position = spec[0]
		wall_body.add_child(wcs)
	root.add_child(wall_body)


## Fußgängerzonen: auf Gehweghöhe angehobene, gepflasterte Flächen entlang Fußgänger-Kanten.
static func _pedestrian_areas(root: Node3D, g: CityGraph, slab_h: float) -> void:
	var body := StaticBody3D.new()
	body.name = "Fussgaengerzonen"
	body.collision_layer = Layers.WORLD
	root.add_child(body)
	var kit := MeshKit.new()
	CityMaterials.apply(kit, ["plaza", "curb"] as Array[String])
	for e: int in g.edge_count():
		if not g.is_pedestrian(e):
			continue
		var a: Vector2 = g.node_pos[g.edge_a[e]]
		var b: Vector2 = g.node_pos[g.edge_b[e]]
		var w: float = g.edge_width(e)
		var dir: Vector2 = (b - a).normalized()
		var ta: float = _end_trim(g, g.edge_a[e], w)
		var tb: float = _end_trim(g, g.edge_b[e], w)
		var pa: Vector2 = a + dir * ta
		var pb: Vector2 = b - dir * tb
		if (pb - pa).dot(dir) < 1.0:
			continue
		var center: Vector2 = (pa + pb) * 0.5
		var length: float = pa.distance_to(pb)
		var yaw: float = atan2(-dir.y, dir.x)
		var basis := Basis(Vector3.UP, yaw)
		var poly: PackedVector2Array = ArchKit.rect_poly(center, Vector2(length, w), yaw)
		kit.add_polygon_xz("plaza", poly, slab_h, 1.0)
		kit.add_polygon_walls("curb", poly, 0.0, slab_h)
		var cs := CollisionShape3D.new()
		var bs := BoxShape3D.new()
		bs.size = Vector3(length, slab_h, w)
		cs.shape = bs
		cs.transform = Transform3D(basis, Vector3(center.x, slab_h * 0.5, center.y))
		body.add_child(cs)
	var mi := MeshInstance3D.new()
	mi.name = "FussgaengerzonenMesh"
	mi.mesh = kit.commit()
	root.add_child(mi)


## Kürzung an Knoten: an befahrbaren Kreuzungen bis zum Bordstein, sonst Überlappung für nahtlose Übergänge.
static func _end_trim(g: CityGraph, n: int, w: float) -> float:
	var r: float = g.node_radius(n, "drive")
	if r > 0.0:
		return r
	return -w * 0.5


## Fahrbahnmarkierungen: gestrichelte Mittellinie, Zebrastreifen an Fußgängerquerungen, Gleise Kriegsstraße.
static func _markings(root: Node3D, g: CityGraph) -> void:
	var kit := MeshKit.new()
	kit.set_material("m", CityMaterials.get_mat("marking"))
	kit.set_material("rail", MatLib.solid(Color(0.45, 0.45, 0.47), 0.3, 0.8))
	var white: Color = Color(0.9, 0.9, 0.86)
	var y: float = 0.012
	for e: int in g.edge_count():
		if not g.is_drivable(e):
			continue
		var na: int = g.edge_a[e]
		var nb: int = g.edge_b[e]
		var a: Vector2 = g.node_pos[na]
		var b: Vector2 = g.node_pos[nb]
		var length: float = a.distance_to(b)
		var dir: Vector2 = (b - a) / maxf(length, 0.001)
		var yaw: float = atan2(-dir.y, dir.x)
		var basis := Basis(Vector3.UP, yaw)
		var start: float = (g.node_radius(na, "all") + 2.0) if g.degree(na, "all") >= 3 else 0.0
		var stop: float = length - ((g.node_radius(nb, "all") + 2.0) if g.degree(nb, "all") >= 3 else 0.0)
		kit.color = white
		var t: float = start + 1.5
		while t + 3.0 < stop:
			var c: Vector2 = a + dir * (t + 1.5)
			kit.add_box("m", Vector3(c.x, y, c.y), Vector3(3.0, 0.01, 0.15), basis)
			t += 9.0
		# Straßenbahngleise (dekorativ, ohne Linienbehauptung) auf der Kriegsstraße
		if str(g.street_of(e).id) == "kriegsstrasse":
			var perp: Vector2 = Vector2(-dir.y, dir.x)
			var mid: Vector2 = (a + b) * 0.5
			for off: float in [-2.6, -1.18, 1.18, 2.6]:
				var c2: Vector2 = mid + perp * off
				kit.color = Color.WHITE
				kit.add_box("rail", Vector3(c2.x, 0.015, c2.y), Vector3(length, 0.02, 0.08), basis)
	# Zebrastreifen: befahrbare Kanten an Knoten mit Fußgänger-Kanten
	for n: int in g.node_count():
		var has_ped: bool = false
		for e2: int in g.node_edges[n]:
			if g.is_pedestrian(e2):
				has_ped = true
		if not has_ped:
			continue
		for e3: int in g.node_edges[n]:
			if not g.is_drivable(e3):
				continue
			var dir2: Vector2 = g.edge_dir(e3, n)
			var w: float = g.edge_width(e3)
			var ped_r: float = 0.0
			for e4: int in g.node_edges[n]:
				if g.is_pedestrian(e4):
					ped_r = maxf(ped_r, g.edge_width(e4) * 0.5)
			var c3: Vector2 = g.node_pos[n] + dir2 * (ped_r + 2.2)
			var perp2: Vector2 = Vector2(-dir2.y, dir2.x)
			var yaw2: float = atan2(-dir2.y, dir2.x)
			var basis2 := Basis(Vector3.UP, yaw2)
			var count: int = int(w / 1.0)
			for k: int in count:
				var off2: float = -w * 0.5 + 0.5 + float(k) * 1.0
				var p: Vector2 = c3 + perp2 * off2
				kit.color = white
				kit.add_box("m", Vector3(p.x, y, p.y), Vector3(3.2, 0.01, 0.5), basis2)
	var mi := MeshInstance3D.new()
	mi.name = "Markierungen"
	mi.mesh = kit.commit()
	mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	root.add_child(mi)


static func _clearing_poly(c: Dictionary) -> PackedVector2Array:
	var out: PackedVector2Array = PackedVector2Array()
	if c.has("circle"):
		var ci: Array = c.circle
		for i: int in 28:
			var a: float = TAU * float(i) / 28.0
			out.append(Vector2(float(ci[0]), float(ci[1])) + Vector2(cos(a), sin(a)) * float(ci[2]))
	elif c.has("rect"):
		var r: Array = c.rect
		out = PackedVector2Array([Vector2(float(r[0]), float(r[1])), Vector2(float(r[2]), float(r[1])),
			Vector2(float(r[2]), float(r[3])), Vector2(float(r[0]), float(r[3]))])
	return out
