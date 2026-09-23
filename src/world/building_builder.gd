class_name BuildingBuilder
extends RefCounted
## Blockrandbebauung: je Häuserblock ein Ring aus Parzellen (Tiefe ~12 m) um einen Innenhof.
## Deterministisch (Hash aus Block- und Kantenindex), Freiflächen für Plätze, Landmarken,
## Hofeinfahrten und Baulücken. Ein Mesh + ein StaticBody pro Block.

const DEPTH: float = 12.5
const WALL_COLORS: Array[Color] = [
	Color(0.93, 0.88, 0.76), Color(0.87, 0.79, 0.63), Color(0.86, 0.69, 0.45), Color(0.95, 0.87, 0.62),
	Color(0.9, 0.69, 0.58), Color(0.8, 0.8, 0.77), Color(0.71, 0.45, 0.36), Color(0.74, 0.77, 0.64),
	Color(0.72, 0.77, 0.81), Color(0.95, 0.94, 0.9), Color(0.84, 0.6, 0.52), Color(0.9, 0.82, 0.7),
]
const ROOF_COLORS: Array[Color] = [Color(0.6, 0.26, 0.19), Color(0.47, 0.27, 0.21), Color(0.33, 0.35, 0.39), Color(0.55, 0.3, 0.22)]

## Ergebnis für andere Systeme (Schilder, Missionen, Tests)
static var lots: Array[Dictionary] = []


static func build(root: Node3D, g: CityGraph, blocks: Array[Dictionary]) -> void:
	lots.clear()
	var slab_h: float = float(g.layout.get("slab_height", 0.12))
	var reserves: Array[Rect2] = []
	for lm: Variant in g.layout.get("landmarks", []):
		var d: Dictionary = lm
		if d.has("reserve"):
			var r: Array = d.reserve
			reserves.append(Rect2(Vector2(float(r[0]), float(r[1])), Vector2(float(r[2]) - float(r[0]), float(r[3]) - float(r[1]))))
	var clearings: Array[Dictionary] = []
	for c: Variant in g.layout.get("clearings", []):
		clearings.append(c)
	var yard_faces: Dictionary = {}
	for y: Variant in g.layout.get("yards", []):
		var yd: Dictionary = y
		var fi: int = g.face_at(Vector2(float(yd.seed[0]), float(yd.seed[1])))
		if fi >= 0:
			yard_faces[fi] = yd
	var constructions: Array[Vector2] = []
	for cst: Variant in g.layout.get("construction_sites", []):
		constructions.append(Vector2(float(cst.near[0]), float(cst.near[1])))

	var container := Node3D.new()
	container.name = "Gebaeude"
	root.add_child(container)
	for b: Dictionary in blocks:
		if b.kind != "block":
			continue
		var line: PackedVector2Array = b.line
		if line.size() < 3:
			continue
		var fi2: int = int(b.face)
		var court: PackedVector2Array = PolyUtil.inset_per_edge(line, _uniform(line.size(), DEPTH))
		if court.is_empty() or PolyUtil.area(court) < 120.0:
			court = PolyUtil.inset_per_edge(line, _uniform(line.size(), 9.0))
		var block_lots: Array[Dictionary] = []
		if court.is_empty() or PolyUtil.area(court) < 60.0:
			block_lots.append(_solid_lot(g, b, line, fi2))
		else:
			block_lots = _ring_lots(g, b, line, court, fi2)
		# Freiflächen anwenden
		for lot: Dictionary in block_lots:
			var cen: Vector2 = lot.centroid
			for c2: Dictionary in clearings:
				if _in_clearing(cen, c2) or _in_clearing(lot.front_mid, c2):
					lot.removed = "platz"
			for r2: Rect2 in reserves:
				if r2.has_point(cen) or r2.has_point(lot.front_mid):
					lot.removed = "landmarke"
		if yard_faces.has(fi2):
			_open_gate(block_lots, yard_faces[fi2])
		for cp: Vector2 in constructions:
			var nearest: Dictionary = {}
			var nd: float = 40.0
			for lot2: Dictionary in block_lots:
				var dd: float = (lot2.centroid as Vector2).distance_to(cp)
				if dd < nd and lot2.removed == "":
					nd = dd
					nearest = lot2
			if not nearest.is_empty():
				nearest.removed = "baustelle"
		# Zufällige Baulücken (nicht an Fußgängerzonen)
		for lot3: Dictionary in block_lots:
			if lot3.removed == "" and not lot3.shop_street and DetRng.hash01(fi2, int(lot3.index), 77) < 0.04 and not lot3.corner:
				lot3.removed = "luecke"
		_emit_block(container, g, block_lots, slab_h, fi2)
		for lot4: Dictionary in block_lots:
			lot4["face"] = fi2
			lots.append(lot4)


static func _uniform(n: int, d: float) -> PackedFloat32Array:
	var a: PackedFloat32Array = PackedFloat32Array()
	a.resize(n)
	a.fill(d)
	return a


static func _in_clearing(p: Vector2, c: Dictionary) -> bool:
	if c.has("circle"):
		var ci: Array = c.circle
		return p.distance_to(Vector2(float(ci[0]), float(ci[1]))) < float(ci[2])
	if c.has("rect"):
		var r: Array = c.rect
		return p.x > float(r[0]) and p.x < float(r[2]) and p.y > float(r[1]) and p.y < float(r[3])
	return false


static func _street_style(g: CityGraph, e: int) -> Dictionary:
	var kind: String = g.edge_kind(e)
	var sid: String = str(g.street_of(e).id)
	var floors_min: int = 4
	var floors_max: int = 5
	var shop_p: float = 0.15
	match kind:
		"pedestrian":
			floors_min = 4
			floors_max = 6
			shop_p = 1.0
		"ring", "main":
			floors_min = 4
			floors_max = 6
			shop_p = 0.45
		"narrow":
			floors_min = 3
			floors_max = 4
			shop_p = 0.2
	if sid == "zirkel" or sid.begins_with("schlossallee"):
		floors_min = 3
		floors_max = 4
		shop_p = 0.1
	return {"fmin": floors_min, "fmax": floors_max, "shop": shop_p, "ped": kind == "pedestrian"}


static func _ring_lots(g: CityGraph, b: Dictionary, line: PackedVector2Array, court: PackedVector2Array, fi: int) -> Array[Dictionary]:
	var out: Array[Dictionary] = []
	var edges: PackedInt32Array = b.edges
	var n: int = line.size()
	var idx: int = 0
	for i: int in n:
		var p0: Vector2 = line[i]
		var p1: Vector2 = line[(i + 1) % n]
		var q0: Vector2 = court[i]
		var q1: Vector2 = court[(i + 1) % n]
		var length: float = p0.distance_to(p1)
		if length < 2.0:
			continue
		var st: Dictionary = _street_style(g, edges[i])
		var lot_w: float = 10.0 + DetRng.hash01(fi, i, 3) * 7.0
		var count: int = maxi(1, int(round(length / lot_w)))
		var cuts: Array[float] = [0.0]
		for k: int in range(1, count):
			var jitter: float = (DetRng.hash01(fi, i, k + 11) - 0.5) * 0.22 / float(count)
			cuts.append(float(k) / float(count) + jitter)
		cuts.append(1.0)
		for k2: int in count:
			var t0: float = cuts[k2]
			var t1: float = cuts[k2 + 1]
			var a0: Vector2 = p0.lerp(p1, t0)
			var a1: Vector2 = p0.lerp(p1, t1)
			var b1: Vector2 = q0.lerp(q1, t1)
			var b0: Vector2 = q0.lerp(q1, t0)
			var h01: float = DetRng.hash01(fi, idx, 5)
			var floors: int = int(st.fmin) + int(floor(h01 * float(int(st.fmax) - int(st.fmin) + 1)))
			var shop: bool = DetRng.hash01(fi, idx, 9) < float(st.shop)
			var modern: bool = DetRng.hash01(fi, idx, 13) < 0.12 and not bool(st.ped)
			out.append({
				"index": idx, "edge": edges[i], "quad": PackedVector2Array([a0, a1, b1, b0]),
				"centroid": (a0 + a1 + b1 + b0) * 0.25, "front_mid": (a0 + a1) * 0.5,
				"floors": floors, "shop": shop, "modern": modern, "shop_street": bool(st.ped),
				"corner": k2 == 0 or k2 == count - 1, "removed": "", "solid": false,
				"color_i": int(DetRng.hash01(fi, idx, 17) * WALL_COLORS.size()) % WALL_COLORS.size(),
				"roof_i": int(DetRng.hash01(fi, idx, 19) * ROOF_COLORS.size()) % ROOF_COLORS.size(),
				"flat": modern or DetRng.hash01(fi, idx, 23) < 0.18,
				"seed": DetRng.hash01(fi, idx, 29),
			})
			idx += 1
	return out


static func _solid_lot(g: CityGraph, b: Dictionary, line: PackedVector2Array, fi: int) -> Dictionary:
	var edges: PackedInt32Array = b.edges
	var st: Dictionary = _street_style(g, edges[0])
	var cen: Vector2 = PolyUtil.centroid(line)
	return {
		"index": 0, "edge": edges[0], "quad": line, "centroid": cen, "front_mid": (line[0] + line[1]) * 0.5,
		"floors": int(st.fmin), "shop": bool(st.ped), "modern": false, "shop_street": bool(st.ped), "corner": false,
		"removed": "", "solid": true, "color_i": fi % WALL_COLORS.size(), "roof_i": 0, "flat": true,
		"seed": DetRng.hash01(fi, 0, 29),
	}


## Hofeinfahrt: alle Parzellen entfernen, die den Korridor Straße -> Hof schneiden.
static func _open_gate(block_lots: Array[Dictionary], yard: Dictionary) -> void:
	var gate: Vector2 = Vector2(float(yard.gate_toward[0]), float(yard.gate_toward[1]))
	var seed: Vector2 = Vector2(float(yard.seed[0]), float(yard.seed[1]))
	var width: float = float(yard.get("gate_width", 12.0))
	var d: Vector2 = (seed - gate).normalized()
	var perp: Vector2 = Vector2(-d.y, d.x) * width * 0.5
	var corridor: PackedVector2Array = PolyUtil.ensure_ccw(PackedVector2Array([gate - perp, seed - perp, seed + perp, gate + perp]))
	for lot: Dictionary in block_lots:
		if not Geometry2D.intersect_polygons(corridor, PolyUtil.ensure_ccw(lot.quad)).is_empty():
			lot.removed = "einfahrt"


static func _emit_block(container: Node3D, g: CityGraph, block_lots: Array[Dictionary], slab_h: float, fi: int) -> void:
	var kit := MeshKit.new()
	CityMaterials.apply(kit, ["facade", "roof", "flat", "stone"] as Array[String])
	var body := StaticBody3D.new()
	body.name = "Block_%d" % fi
	body.collision_layer = Layers.WORLD
	body.collision_mask = 0
	var any: bool = false
	# Seitenkanten, die von zwei bebauten Parzellen geteilt werden, sind Brandwände; sonst freiliegend
	var side_count: Dictionary = {}
	for lot0: Dictionary in block_lots:
		if lot0.removed != "" or lot0.solid:
			continue
		var q0: PackedVector2Array = lot0.quad
		for key: String in [_edge_key(q0[1], q0[2]), _edge_key(q0[3], q0[0])]:
			side_count[key] = int(side_count.get(key, 0)) + 1
	for lot: Dictionary in block_lots:
		if lot.removed != "":
			continue
		any = true
		var quad: PackedVector2Array = lot.quad
		var wall_col: Color = WALL_COLORS[int(lot.color_i)]
		if lot.modern:
			wall_col = Color(0.62, 0.63, 0.64).lerp(wall_col, 0.25)
		var shop: bool = lot.shop
		var gf: float = 4.3 if shop else 3.6
		var fh: float = 3.3
		var wall_h: float = gf + float(int(lot.floors) - 1) * fh
		var y0: float = slab_h
		var y1: float = slab_h + wall_h
		var style: float = ArchKit.STYLE_MODERN if lot.modern else ArchKit.STYLE_NORMAL
		var seed: float = float(lot.seed)
		var nq: int = quad.size()
		for i: int in nq:
			var a: Vector2 = quad[i]
			var b2: Vector2 = quad[(i + 1) % nq]
			if lot.solid:
				ArchKit.wall(kit, a, b2, y0, y1, wall_col, seed, shop, seed, style, fh)
			elif i == 0:
				ArchKit.wall(kit, a, b2, y0, y1, wall_col, seed, shop, seed, style, fh)
			elif i == 2:
				ArchKit.wall(kit, a, b2, y0, y1, wall_col, seed, false, seed, style, fh)
			else:
				var exposed: bool = int(side_count.get(_edge_key(a, b2), 0)) < 2
				ArchKit.wall(kit, a, b2, y0, y1, wall_col.darkened(0.04 if exposed else 0.08), seed, false, 0.0,
					style if exposed else ArchKit.STYLE_BLANK, fh)
		var roof_col: Color = ROOF_COLORS[int(lot.roof_i)]
		if lot.flat or lot.solid:
			ArchKit.flat_roof(kit, quad, y1, Color(0.45, 0.44, 0.42), wall_col.darkened(0.15))
		else:
			var depth: float = ((quad[0] + quad[1]) * 0.5).distance_to((quad[2] + quad[3]) * 0.5)
			var rh: float = clampf(depth * 0.42, 2.5, 5.5)
			ArchKit.gable_roof(kit, quad[0], quad[1], quad[2], quad[3], y1, rh, roof_col, wall_col, seed)
			lot["roof_h"] = rh
		lot["height"] = y1
		# Kollision: konvexes Prisma pro Parzelle
		var pts: PackedVector3Array = PackedVector3Array()
		for p: Vector2 in quad:
			pts.append(Vector3(p.x, y0, p.y))
			pts.append(Vector3(p.x, y1, p.y))
		var cs := CollisionShape3D.new()
		var shape := ConvexPolygonShape3D.new()
		shape.points = pts
		cs.shape = shape
		body.add_child(cs)
	if not any:
		body.free()
		return
	var mi := MeshInstance3D.new()
	mi.name = "BlockMesh_%d" % fi
	mi.mesh = kit.commit()
	container.add_child(mi)
	container.add_child(body)


static func _edge_key(a: Vector2, b: Vector2) -> String:
	var ka: String = "%.2f,%.2f" % [a.x, a.y]
	var kb: String = "%.2f,%.2f" % [b.x, b.y]
	return ka + "|" + kb if ka < kb else kb + "|" + ka
