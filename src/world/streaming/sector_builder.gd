class_name SectorBuilder
extends RefCounted
## Baut einen 256-m-Sektor aus seinen Daten: Bodenflächen, Straßen mit Markierungen, Blockplatten mit Bordstein,
## Gebäude (Fassadenshader, Dächer), Stadtmobiliar, Vegetation, Bahngleise, Landmarken.
## Läuft ohne Szenenbaum (Worker-Thread geeignet); das Ergebnis wird im Hauptthread eingehängt.
## Materialien müssen vorher im Hauptthread erzeugt sein (warm_up()).

const SLAB_H: float = 0.12
const WALL_COLORS: Array[Color] = [
	Color(0.93, 0.88, 0.76), Color(0.87, 0.79, 0.63), Color(0.86, 0.69, 0.45), Color(0.95, 0.87, 0.62),
	Color(0.9, 0.69, 0.58), Color(0.8, 0.8, 0.77), Color(0.71, 0.45, 0.36), Color(0.74, 0.77, 0.64),
	Color(0.72, 0.77, 0.81), Color(0.95, 0.94, 0.9), Color(0.84, 0.6, 0.52), Color(0.9, 0.82, 0.7),
]
const MODERN_COLORS: Array[Color] = [Color(0.86, 0.86, 0.84), Color(0.7, 0.72, 0.74), Color(0.62, 0.64, 0.66), Color(0.9, 0.88, 0.82)]
const ROOF_COLORS: Array[Color] = [Color(0.6, 0.26, 0.19), Color(0.47, 0.27, 0.21), Color(0.33, 0.35, 0.39), Color(0.55, 0.3, 0.22)]
## Bodenflächen: Materialschlüssel und Höhe je Art (Reihenfolge wie area_kinds)
const AREA_MAT: Dictionary = {
	"water": ["water", -0.02], "forest": ["forest_floor", -0.012], "park": ["grass", -0.01], "zoo": ["grass", -0.01],
	"garden": ["grass", -0.01], "cemetery": ["grass", -0.01], "sports": ["turf", -0.01], "rail": ["gravel", -0.008],
	"plaza": ["plaza", -0.006], "industry_yard": ["yard", -0.008], "field": ["field", -0.014], "urban": ["sidewalk", -0.006],
	"parking": ["asphalt", -0.004],
}
const SLAB_TOP: Dictionary = {"urban": "sidewalk", "plaza": "plaza", "park": "grass", "zoo": "grass", "garden": "grass",
	"cemetery": "grass", "sports": "turf", "industry_yard": "yard"}
const VEG_SPACING: Dictionary = {"forest": 8.5, "park": 17.0, "zoo": 13.0, "garden": 12.0, "cemetery": 11.0}

static var _prop_meshes: Dictionary = {}


## Materialien und Prop-Meshes im Hauptthread vorbereiten.
static func warm_up() -> void:
	for k: String in ["facade", "roof", "flat", "stone", "sidewalk", "grass", "curb", "yard", "plaza", "gravel", "asphalt", "water",
			"vertex", "vertex_metal", "marking", "lamp_glow", "glass_dark", "forest_floor", "field", "turf", "rail_steel"]:
		CityMaterials.get_mat(k)
	if _prop_meshes.is_empty():
		_prop_meshes["lamp"] = PropLib.lamp_mesh()
		_prop_meshes["tree_a"] = PropLib.tree_mesh(false)
		_prop_meshes["tree_b"] = PropLib.tree_mesh(true)
		_prop_meshes["tree_c"] = PropLib.conifer_mesh()


## Ergebnis: { node: Node3D, lamps: PackedVector3Array, cars: Array[Dictionary] }
static func build(w: WorldData, g: CityGraph, ij: Vector2i, data: Dictionary, quality: int) -> Dictionary:
	var root := Node3D.new()
	root.name = "Sektor_%d_%d" % [ij.x, ij.y]
	var col_faces: PackedVector3Array = PackedVector3Array()
	var body := StaticBody3D.new()
	body.name = "Kollision"
	body.collision_layer = Layers.WORLD
	body.collision_mask = 0
	root.add_child(body)
	var ground := MeshKit.new()
	CityMaterials.apply(ground, ["water", "forest_floor", "grass", "turf", "gravel", "plaza", "yard", "field", "sidewalk", "curb",
		"asphalt", "marking", "rail_steel"] as Array[String])
	var seed_base: int = ij.x * 7919 + ij.y * 104729
	# 1) Bodenflächen
	for a: Variant in data.get("a", []):
		var kind: String = w.area_kinds[int(a[0])]
		var mat: Array = AREA_MAT.get(kind, ["field", -0.014])
		var poly: PackedVector2Array = w.pts(a[1])
		if poly.size() >= 3:
			ground.add_polygon_xz(str(mat[0]), poly, float(mat[1]), 1.0)
	# 2) Straßen
	_roads(ground, g, data)
	# 3) Blockplatten mit Bordstein
	for k: Variant in data.get("k", []):
		var kind2: String = w.area_kinds[int(k[0])]
		var poly2: PackedVector2Array = w.pts(k[1])
		if poly2.size() < 3:
			continue
		ground.add_polygon_xz(str(SLAB_TOP.get(kind2, "sidewalk")), poly2, SLAB_H, 1.0)
		ground.add_polygon_walls("curb", poly2, 0.0, SLAB_H)
		_append_slab_collision(col_faces, poly2)
	# 4) Bahngleise
	for r: Variant in data.get("r", []):
		_rail(ground, int(r[0]), w.pts(r[1]), int(r[2]) if (r as Array).size() > 2 else 0)
	var gm := MeshInstance3D.new()
	gm.name = "Boden"
	gm.mesh = ground.commit()
	gm.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	root.add_child(gm)
	# 5) Gebäude
	var bk := MeshKit.new()
	CityMaterials.apply(bk, ["facade", "roof", "flat"] as Array[String])
	for b: Variant in data.get("b", []):
		_building(bk, w, b, col_faces)
	if not bk.is_empty():
		var bm := MeshInstance3D.new()
		bm.name = "Gebaeude"
		bm.mesh = bk.commit()
		root.add_child(bm)
	# 6) Props
	var lamps: PackedVector3Array = PackedVector3Array()
	var cars: Array[Dictionary] = []
	_props(root, body, w, data.get("p", {}), lamps, cars, quality)
	# 7) Vegetation in Parks/Wald
	_vegetation(root, w, data, seed_base, quality)
	# 8) Landmarken
	for li: Variant in data.get("lm", []):
		var lm: Dictionary = w.landmarks[int(li)]
		root.add_child(LandmarkBuilder.build_one(lm, SLAB_H))
	if not col_faces.is_empty():
		var cs := CollisionShape3D.new()
		var shape := ConcavePolygonShape3D.new()
		shape.set_faces(col_faces)
		cs.shape = shape
		body.add_child(cs)
	return {"node": root, "lamps": lamps, "cars": cars, "habitats": _habitats(w, data)}


## Lebensräume für Tiere (W6): Wasser, Parks/Gärten, Plätze – Polygon, Art, Bodenhöhe, Fläche.
static func _habitats(w: WorldData, data: Dictionary) -> Array:
	var out: Array = []
	for a: Variant in data.get("a", []):
		var kind: String = w.area_kinds[int(a[0])]
		if kind == "water" or kind == "zoo":
			continue
		if kind in ["park", "garden", "forest"]:
			var poly: PackedVector2Array = w.pts(a[1])
			var ar: float = absf(PolyUtil.signed_area(poly))
			if ar > 600.0:
				out.append({"kind": "park", "poly": poly, "y": 0.0, "area": ar})
	for a2: Variant in data.get("a", []):
		if w.area_kinds[int(a2[0])] == "water":
			var poly2: PackedVector2Array = w.pts(a2[1])
			var ar2: float = absf(PolyUtil.signed_area(poly2))
			if ar2 > 200.0:
				out.append({"kind": "water", "poly": poly2, "y": -0.02, "area": ar2})
	for k: Variant in data.get("k", []):
		var kind3: String = w.area_kinds[int(k[0])]
		if kind3 in ["plaza", "park", "garden"]:
			var poly3: PackedVector2Array = w.pts(k[1])
			var ar3: float = absf(PolyUtil.signed_area(poly3))
			if ar3 > 300.0:
				out.append({"kind": "plaza" if kind3 == "plaza" else "park", "poly": poly3, "y": SLAB_H, "area": ar3})
	return out


# ------------------------------------------------------------------ Straßen

static func _roads(kit: MeshKit, g: CityGraph, data: Dictionary) -> void:
	for ev: Variant in data.get("e", []):
		var e: int = int(ev)
		var a: Vector2 = g.node_pos[g.edge_a[e]]
		var b: Vector2 = g.node_pos[g.edge_b[e]]
		var d: Vector2 = b - a
		var L: float = d.length()
		if L < 0.05:
			continue
		var dir: Vector2 = d / L
		var r: Vector2 = Vector2(-dir.y, dir.x)
		var hw: float = g.edge_width(e) * 0.5
		var ped: bool = g.is_pedestrian(e)
		var key: String = "plaza" if ped else "asphalt"
		var y: float = 0.0 if not ped else 0.004
		kit.add_polygon_xz(key, PackedVector2Array([a - r * hw, b - r * hw, b + r * hw, a + r * hw]), y, 1.0)
		if ped:
			continue
		# Mittellinie (gestrichelt; bei Hauptstraßen durchgezogen) und Randlinien
		var cls: String = g.edge_kind(e)
		kit.color = Color(0.9, 0.9, 0.86)
		var oneway: bool = g.is_oneway(e)
		if (oneway and hw * 2.0 >= 6.4) or (not oneway and cls in ["motorway", "trunk", "primary", "secondary", "tertiary"]):
			# Einbahnfahrbahn: gestrichelte Spurtrennung; Gegenverkehr: Mittellinie
			var solid: bool = not oneway and cls in ["motorway", "trunk", "primary"]
			var t: float = 1.5
			while t < L - 1.5:
				var t1: float = minf(L - 1.5, t + (L if solid else 3.0))
				var p0: Vector2 = a + dir * t
				var p1: Vector2 = a + dir * t1
				var w2: float = 0.08
				kit.add_polygon_xz("marking", PackedVector2Array([p0 - r * w2, p1 - r * w2, p1 + r * w2, p0 + r * w2]), 0.008, 1.0)
				t = t1 + 6.0
			for s: float in [-1.0, 1.0]:
				var o: Vector2 = r * (hw - 0.45) * s
				kit.add_polygon_xz("marking", PackedVector2Array([a + o - r * 0.07, b + o - r * 0.07, b + o + r * 0.07, a + o + r * 0.07]), 0.008, 1.0)
		kit.color = Color.WHITE
	# Kreuzungsflächen
	for nv: Variant in data.get("n", []):
		var n: int = int(nv)
		var rad: float = g.node_radius(n, "all")
		if rad <= 0.0:
			continue
		var c: Vector2 = g.node_pos[n]
		var circ: PackedVector2Array = PackedVector2Array()
		for i: int in 14:
			var ang: float = TAU * float(i) / 14.0
			circ.append(c + Vector2(cos(ang), sin(ang)) * rad)
		kit.add_polygon_xz("asphalt", PolyUtil.ensure_ccw(circ), 0.002, 1.0)


## kind: 0 = Eisenbahn mit Schotterbett, 1 = Straßenbahn auf eigenem Gleiskörper, 2 = Straßenbahn in der Fahrbahn (bündig)
static func _rail(kit: MeshKit, tracks: int, line: PackedVector2Array, kind: int = 0) -> void:
	var width: float = float(tracks) * 4.5 + 2.0 if kind == 0 else float(tracks) * 3.2 + 0.4
	for i: int in line.size() - 1:
		var a: Vector2 = line[i]
		var b: Vector2 = line[i + 1]
		var L: float = a.distance_to(b)
		if L < 0.1:
			continue
		var dir: Vector2 = (b - a) / L
		var r: Vector2 = Vector2(-dir.y, dir.x)
		if kind != 2:
			kit.add_polygon_xz("gravel", PackedVector2Array([a - r * width * 0.5, b - r * width * 0.5, b + r * width * 0.5, a + r * width * 0.5]), 0.03, 1.0)
		kit.color = Color(0.35, 0.33, 0.32) if kind != 2 else Color(0.5, 0.5, 0.52)
		for t: int in tracks:
			var off: float = (float(t) - float(tracks - 1) * 0.5) * (4.5 if kind == 0 else 3.2)
			for s: float in [-0.72, 0.72]:
				var o: Vector2 = r * (off + s)
				var m: Vector2 = (a + b) * 0.5 + o
				if kind == 2:
					kit.add_polygon_xz("rail_steel", PackedVector2Array([a + o - r * 0.05, b + o - r * 0.05, b + o + r * 0.05, a + o + r * 0.05]), 0.011, 1.0)
				else:
					kit.add_box("rail_steel", Vector3(m.x, 0.12, m.y), Vector3(0.08, 0.16, L), Basis(Vector3.UP, atan2(dir.x, dir.y)))
		kit.color = Color.WHITE


# ------------------------------------------------------------------ Blockplatten

static func _append_slab_collision(out: PackedVector3Array, poly: PackedVector2Array) -> void:
	var idx: PackedInt32Array = Geometry2D.triangulate_polygon(poly)
	for i: int in range(0, idx.size(), 3):
		var a: Vector2 = poly[idx[i]]
		var b: Vector2 = poly[idx[i + 1]]
		var c: Vector2 = poly[idx[i + 2]]
		out.append_array(PackedVector3Array([Vector3(a.x, SLAB_H, a.y), Vector3(b.x, SLAB_H, b.y), Vector3(c.x, SLAB_H, c.y)]))
	var n: int = poly.size()
	for i2: int in n:
		var p: Vector2 = poly[i2]
		var q: Vector2 = poly[(i2 + 1) % n]
		out.append_array(PackedVector3Array([Vector3(p.x, 0, p.y), Vector3(q.x, 0, q.y), Vector3(q.x, SLAB_H, q.y),
			Vector3(p.x, 0, p.y), Vector3(q.x, SLAB_H, q.y), Vector3(p.x, SLAB_H, p.y)]))


# ------------------------------------------------------------------ Gebäude

static func _building(kit: MeshKit, w: WorldData, b: Array, col_faces: PackedVector3Array) -> void:
	var poly: PackedVector2Array = w.pts(b[0])
	var n: int = poly.size()
	if n < 3:
		return
	var codes: String = str(b[1])
	var floors: int = int(b[2])
	var h: float = float(b[3]) / w.q
	var style: int = int(b[4])
	var shop: bool = int(b[5]) == 1
	var roof: String = str(b[6])
	var ci: int = int(b[7])
	var seed: float = float(b[8]) / 1000.0
	var modern: bool = style in [1, 4, 5]
	var wall_col: Color = MODERN_COLORS[ci % MODERN_COLORS.size()] if modern else WALL_COLORS[ci % WALL_COLORS.size()]
	var fstyle: float = ArchKit.STYLE_MODERN if modern else ArchKit.STYLE_NORMAL
	var fh: float = 3.2
	if style == 3:
		wall_col = Color(0.62, 0.64, 0.66).lerp(wall_col, 0.2)
		fstyle = ArchKit.STYLE_MODERN
		fh = 4.5
	elif style == 6:
		wall_col = wall_col.lerp(Color(0.96, 0.95, 0.92), 0.4)
	var y0: float = SLAB_H
	var y1: float = y0 + h
	for i: int in n:
		var a: Vector2 = poly[i]
		var c: Vector2 = poly[(i + 1) % n]
		var code: int = int(codes[i]) if i < codes.length() else 3
		match code:
			1:
				ArchKit.wall(kit, a, c, y0, y1, wall_col, seed, shop, seed, fstyle, fh)
			2:
				ArchKit.wall(kit, a, c, y0, y1, wall_col.darkened(0.04), seed, false, 0.0, fstyle, fh)
			3:
				ArchKit.wall(kit, a, c, y0, y1, wall_col.darkened(0.03), seed, false, 0.0, fstyle, fh)
			_:
				ArchKit.wall(kit, a, c, y0, y1, wall_col.darkened(0.08), seed, false, 0.0, ArchKit.STYLE_BLANK, fh)
		col_faces.append_array(PackedVector3Array([Vector3(a.x, y0, a.y), Vector3(c.x, y0, c.y), Vector3(c.x, y1, c.y),
			Vector3(a.x, y0, a.y), Vector3(c.x, y1, c.y), Vector3(a.x, y1, a.y)]))
	var roof_col: Color = ROOF_COLORS[(ci + int(seed * 7.0)) % ROOF_COLORS.size()]
	if (roof == "g" or roof == "h") and n == 4:
		var depth: float = ((poly[0] + poly[1]) * 0.5).distance_to((poly[2] + poly[3]) * 0.5)
		var rh: float = clampf(depth * 0.42, 2.2, 6.0)
		ArchKit.gable_roof(kit, poly[0], poly[1], poly[2], poly[3], y1, rh, roof_col, wall_col, seed)
	elif roof == "m" and n == 4:
		var center: Vector2 = (poly[0] + poly[1] + poly[2] + poly[3]) * 0.25
		var size: Vector2 = Vector2(poly[0].distance_to(poly[1]), poly[1].distance_to(poly[2]))
		var yaw: float = -atan2(poly[1].y - poly[0].y, poly[1].x - poly[0].x)
		ArchKit.mansard_roof(kit, center, size, yaw, y1, 2.6, 1.2, 0.9, ROOF_COLORS[2])
	else:
		ArchKit.flat_roof(kit, poly, y1, Color(0.45, 0.44, 0.42), wall_col.darkened(0.15))


# ------------------------------------------------------------------ Props

static func _props(root: Node3D, body: StaticBody3D, w: WorldData, p: Dictionary, lamps: PackedVector3Array,
		cars: Array[Dictionary], quality: int) -> void:
	var inv: float = 1.0 / w.q
	var furn := MeshKit.new()
	CityMaterials.apply(furn, ["vertex", "vertex_metal"] as Array[String])
	var lamp_xf: Array[Transform3D] = []
	var tree_xf: Array[Transform3D] = []
	for kind: String in p.keys():
		var arr: Array = p[kind]
		for i: int in range(0, arr.size(), 4):
			var pos: Vector3 = Vector3(float(arr[i]) * inv, SLAB_H, float(arr[i + 1]) * inv)
			var yaw: float = float(arr[i + 2]) / 1000.0
			var variant: int = int(arr[i + 3])
			match kind:
				"lamp":
					lamp_xf.append(Transform3D(Basis(Vector3.UP, yaw), pos))
					lamps.append(pos + Basis(Vector3.UP, yaw) * Vector3(1.1, 5.1, 0))
					_cyl(body, pos, 0.12, 5.0)
				"tree":
					var s: float = 0.85 + DetRng.hash01(int(pos.x * 10.0), int(pos.z * 10.0), 3) * 0.4
					tree_xf.append(Transform3D(Basis(Vector3.UP, yaw + float(i)).scaled(Vector3(s, s, s)), pos))
					_cyl(body, pos, 0.28, 3.0)
				"bench":
					PropLib.bench(furn, pos, yaw)
					_box(body, pos + Vector3(0, 0.45, 0), Vector3(1.8, 0.9, 0.5), yaw)
				"bin":
					PropLib.bin(furn, pos)
				"bike":
					PropLib.bike(furn, pos, yaw, Color.from_hsv(float(variant % 100) / 100.0, 0.6, 0.7))
				"bollard":
					PropLib.bollard(furn, pos)
					_cyl(body, pos, 0.1, 0.85)
				"car":
					cars.append({"position": Vector3(pos.x, 0.0, pos.z), "yaw": yaw, "variant": variant})
	var vis: float = [110.0, 170.0, 240.0, 320.0][clampi(quality, 0, 3)]
	PropLib.multimesh(root, "Laternen", _prop_meshes["lamp"], lamp_xf, vis * 1.6)
	PropLib.multimesh(root, "Strassenbaeume", _prop_meshes["tree_a"], tree_xf, vis * 2.2)
	if not furn.is_empty():
		var mi := MeshInstance3D.new()
		mi.name = "Moebel"
		mi.mesh = furn.commit()
		mi.visibility_range_end = vis
		root.add_child(mi)


static func _add_blocker(poly: PackedVector2Array, blk: Array[PackedVector2Array], blk_r: Array[Rect2]) -> void:
	if poly.size() < 3:
		return
	var r: Rect2 = Rect2(poly[0], Vector2.ZERO)
	for q: Vector2 in poly:
		r = r.expand(q)
	blk.append(poly)
	blk_r.append(r.grow(1.5))


## Punkt in einer Sperrfläche (Rechteck-Vorfilter, dann Polygon; 1,5 m Rand für Baumkronen am Rand).
static func _blocked(pt: Vector2, blk: Array[PackedVector2Array], blk_r: Array[Rect2]) -> bool:
	for i: int in blk.size():
		if blk_r[i].has_point(pt) and Geometry2D.is_point_in_polygon(pt, blk[i]):
			return true
	return false


static func _vegetation(root: Node3D, w: WorldData, data: Dictionary, seed_base: int, quality: int) -> void:
	var density: float = [0.45, 0.7, 1.0, 1.0][clampi(quality, 0, 3)] * Settings.vegetation_density()
	if density <= 0.01:
		return
	var xfa: Array[Transform3D] = []
	var xfb: Array[Transform3D] = []
	var xfc: Array[Transform3D] = []
	# Keine Bäume in Gebäuden, Gewässern und Landmarken-Grundrissen (Parks/Zoo enthalten solche Flächen)
	var blk: Array[PackedVector2Array] = []
	var blk_r: Array[Rect2] = []
	for a2: Variant in data.get("a", []):
		if w.area_kinds[int(a2[0])] == "water":
			_add_blocker(w.pts(a2[1]), blk, blk_r)
	for b: Variant in data.get("b", []):
		_add_blocker(w.pts(b[0]), blk, blk_r)
	for i: int in w.veg_block.size():
		blk.append(w.veg_block[i])
		blk_r.append(w.veg_block_rect[i])
	for a: Variant in data.get("a", []):
		var kind: String = w.area_kinds[int(a[0])]
		if not VEG_SPACING.has(kind):
			continue
		var poly: PackedVector2Array = w.pts(a[1])
		if poly.size() < 3:
			continue
		var sp: float = float(VEG_SPACING[kind]) / sqrt(density)
		var r: Rect2 = Rect2(poly[0], Vector2.ZERO)
		for q: Vector2 in poly:
			r = r.expand(q)
		var gx0: int = int(floor(r.position.x / sp))
		var gz0: int = int(floor(r.position.y / sp))
		var gx1: int = int(ceil(r.end.x / sp))
		var gz1: int = int(ceil(r.end.y / sp))
		for gx: int in range(gx0, gx1):
			for gz: int in range(gz0, gz1):
				var h1: float = DetRng.hash01(gx, gz, 11)
				if kind != "forest" and h1 < 0.35:
					continue
				var pt: Vector2 = Vector2((float(gx) + DetRng.hash01(gx, gz, 1)) * sp, (float(gz) + DetRng.hash01(gx, gz, 2)) * sp)
				if not Geometry2D.is_point_in_polygon(pt, poly) or _blocked(pt, blk, blk_r):
					continue
				var s: float = 0.75 + DetRng.hash01(gx, gz, 4) * 0.6
				var xf: Transform3D = Transform3D(Basis(Vector3.UP, h1 * TAU).scaled(Vector3(s, s, s)), Vector3(pt.x, 0.0, pt.y))
				var t: float = DetRng.hash01(gx, gz, 5)
				if kind == "forest":
					if t < 0.45:
						xfc.append(xf)
					elif t < 0.8:
						xfa.append(xf)
					else:
						xfb.append(xf)
				else:
					if t < 0.7:
						xfa.append(xf)
					else:
						xfb.append(xf)
	var vis: float = [260.0, 420.0, 600.0, 800.0][clampi(quality, 0, 3)]
	PropLib.multimesh(root, "Baeume_Laub", _prop_meshes["tree_a"], xfa, vis)
	PropLib.multimesh(root, "Baeume_Pappel", _prop_meshes["tree_b"], xfb, vis)
	PropLib.multimesh(root, "Baeume_Nadel", _prop_meshes["tree_c"], xfc, vis)


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
