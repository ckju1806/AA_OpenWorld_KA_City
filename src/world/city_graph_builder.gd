class_name CityGraphBuilder
extends RefCounted
## Baut aus karlsruhe_layout.json einen planaren Straßengraphen:
## 1) Straßen -> Polylinien (Geraden, Kreisbögen, Fächerstrahlen)
## 2) Schnittpunkte/Einmündungen -> Teilungspunkte, Knoten-Snapping
## 3) Kanten mit Straßenattributen
## 4) Flächen (Faces) = Häuserblöcke/Parks per Halbkanten-Umlauf

const SNAP: float = 0.8
const GRID: float = 60.0
const LAYOUT_PATH: String = "res://data/world/karlsruhe_layout.json"


static func load_layout(path: String = LAYOUT_PATH) -> Dictionary:
	var f: FileAccess = FileAccess.open(path, FileAccess.READ)
	if f == null:
		push_error("Kartendaten fehlen: %s" % path)
		return {}
	var parsed: Variant = JSON.parse_string(f.get_as_text())
	if not parsed is Dictionary:
		push_error("Kartendaten ungültig: %s" % path)
		return {}
	return parsed


static func build_from_file(path: String = LAYOUT_PATH) -> CityGraph:
	return build(load_layout(path))


static func build(layout: Dictionary) -> CityGraph:
	var g := CityGraph.new()
	g.layout = layout
	var kinds: Dictionary = layout.get("street_kinds", {})
	var polylines: Array[Dictionary] = []
	for sd: Variant in layout.get("streets", []):
		var d: Dictionary = sd
		var kind: String = str(d.get("kind", "street"))
		var kd: Dictionary = kinds.get(kind, {})
		var info: Dictionary = {
			"id": str(d.get("id", "")), "name": str(d.get("name", "")), "kind": kind,
			"width": float(kd.get("width", 10.0)), "speed": float(kd.get("speed", 11.0)),
			"drivable": bool(kd.get("drivable", true)), "traffic": bool(kd.get("traffic", true)),
			"parking": bool(kd.get("parking", false)),
		}
		g.streets.append(info)
		var sidx: int = g.streets.size() - 1
		for pl: PackedVector2Array in _expand(d):
			if pl.size() >= 2:
				polylines.append({"pts": pl, "street": sidx})
	_planarize(g, polylines)
	_extract_faces(g)
	return g


## Straßendefinition -> eine oder mehrere Polylinien.
static func _expand(d: Dictionary) -> Array[PackedVector2Array]:
	var out: Array[PackedVector2Array] = []
	if d.has("points"):
		var pl: PackedVector2Array = PackedVector2Array()
		for p: Variant in d.points:
			pl.append(Vector2(float(p[0]), float(p[1])))
		out.append(pl)
	elif d.has("arc"):
		var a: Dictionary = d.arc
		var c: Vector2 = Vector2(float(a.center[0]), float(a.center[1]))
		var r: float = float(a.radius)
		var from_deg: float = float(a.from)
		var to_deg: float = float(a.to)
		var step: float = absf(float(a.get("step", 5.0)))
		var n: int = maxi(1, int(round(absf(to_deg - from_deg) / step)))
		var pl2: PackedVector2Array = PackedVector2Array()
		for i: int in n + 1:
			pl2.append(PolyUtil.polar(c, r, lerpf(from_deg, to_deg, float(i) / float(n))))
		out.append(pl2)
	elif d.has("ray"):
		var ry: Dictionary = d.ray
		var ang: float = float(ry.angle)
		var r0: float = float(ry.r0)
		var to_z: float = float(ry.to_z)
		var r_end: float = to_z / cos(deg_to_rad(ang))
		var start: Vector2 = PolyUtil.polar(Vector2.ZERO, r0, ang)
		var end: Vector2 = PolyUtil.polar(Vector2.ZERO, r_end, ang)
		end.y = to_z
		out.append(PackedVector2Array([start, end]))
		if d.has("continue_south_to"):
			out.append(PackedVector2Array([end, Vector2(end.x, float(d.continue_south_to))]))
	return out


static func _planarize(g: CityGraph, polylines: Array[Dictionary]) -> void:
	# Segmentliste
	var segs: Array[Dictionary] = []
	for pi: int in polylines.size():
		var pts: PackedVector2Array = polylines[pi].pts
		for si: int in pts.size() - 1:
			segs.append({"p": pi, "s": si, "a": pts[si], "b": pts[si + 1]})
	# Teilungsparameter je Polylinie/Segment
	var splits: Dictionary = {}  # "pi:si" -> Array[float]
	# Raster zur Beschleunigung
	var grid: Dictionary = {}
	for i: int in segs.size():
		var a: Vector2 = segs[i].a
		var b: Vector2 = segs[i].b
		var mn: Vector2i = Vector2i(int(floor(minf(a.x, b.x) / GRID)), int(floor(minf(a.y, b.y) / GRID)))
		var mx: Vector2i = Vector2i(int(floor(maxf(a.x, b.x) / GRID)), int(floor(maxf(a.y, b.y) / GRID)))
		for gx: int in range(mn.x, mx.x + 1):
			for gy: int in range(mn.y, mx.y + 1):
				var key: Vector2i = Vector2i(gx, gy)
				if not grid.has(key):
					grid[key] = []
				(grid[key] as Array).append(i)
	var tested: Dictionary = {}
	for key: Vector2i in grid:
		var cell: Array = grid[key]
		for ii: int in cell.size():
			for jj: int in range(ii + 1, cell.size()):
				var i: int = cell[ii]
				var j: int = cell[jj]
				var pair: int = mini(i, j) * 100000 + maxi(i, j)
				if tested.has(pair):
					continue
				tested[pair] = true
				var si: Dictionary = segs[i]
				var sj: Dictionary = segs[j]
				if si.p == sj.p and absi(int(si.s) - int(sj.s)) <= 1:
					continue
				_intersect(si, sj, splits)
	# Knoten und Kanten erzeugen
	var node_grid: Dictionary = {}
	for pi: int in polylines.size():
		var pts: PackedVector2Array = polylines[pi].pts
		var seq: PackedVector2Array = PackedVector2Array()
		for si: int in pts.size() - 1:
			var a: Vector2 = pts[si]
			var b: Vector2 = pts[si + 1]
			seq.append(a)
			var key: String = "%d:%d" % [pi, si]
			if splits.has(key):
				var ts: Array = splits[key]
				ts.sort()
				for t: float in ts:
					if t > 0.0001 and t < 0.9999:
						seq.append(a.lerp(b, t))
		seq.append(pts[pts.size() - 1])
		var prev: int = -1
		for p: Vector2 in seq:
			var n: int = _node_for(g, node_grid, p)
			if prev >= 0 and n != prev and g.find_edge(prev, n) < 0:
				g.edge_a.append(prev)
				g.edge_b.append(n)
				g.edge_street.append(int(polylines[pi].street))
				var e: int = g.edge_a.size() - 1
				g.node_edges[prev].append(e)
				g.node_edges[n].append(e)
			if n != prev:
				prev = n


static func _intersect(si: Dictionary, sj: Dictionary, splits: Dictionary) -> void:
	var a1: Vector2 = si.a
	var b1: Vector2 = si.b
	var a2: Vector2 = sj.a
	var b2: Vector2 = sj.b
	var ip: Variant = Geometry2D.segment_intersects_segment(a1, b1, a2, b2)
	if ip != null:
		var p: Vector2 = ip
		_add_split(splits, si, _t_on(p, a1, b1))
		_add_split(splits, sj, _t_on(p, a2, b2))
		return
	# Einmündungen (Endpunkt nahe am anderen Segment)
	for pair: Array in [[a1, sj, a2, b2], [b1, sj, a2, b2], [a2, si, a1, b1], [b2, si, a1, b1]]:
		var p2: Vector2 = pair[0]
		var target: Dictionary = pair[1]
		var ta: Vector2 = pair[2]
		var tb: Vector2 = pair[3]
		if PolyUtil.dist_point_segment(p2, ta, tb) < SNAP:
			_add_split(splits, target, _t_on(p2, ta, tb))


static func _t_on(p: Vector2, a: Vector2, b: Vector2) -> float:
	var ab: Vector2 = b - a
	var l2: float = ab.length_squared()
	if l2 < 0.000001:
		return 0.0
	return clampf((p - a).dot(ab) / l2, 0.0, 1.0)


static func _add_split(splits: Dictionary, seg: Dictionary, t: float) -> void:
	var key: String = "%d:%d" % [int(seg.p), int(seg.s)]
	if not splits.has(key):
		splits[key] = []
	(splits[key] as Array).append(t)


static func _node_for(g: CityGraph, node_grid: Dictionary, p: Vector2) -> int:
	var cx: int = int(floor(p.x / SNAP))
	var cy: int = int(floor(p.y / SNAP))
	for dx: int in range(-1, 2):
		for dy: int in range(-1, 2):
			var key: Vector2i = Vector2i(cx + dx, cy + dy)
			if node_grid.has(key):
				for n: int in node_grid[key]:
					if g.node_pos[n].distance_to(p) < SNAP:
						return n
	g.node_pos.append(p)
	g.node_edges.append(PackedInt32Array())
	var n2: int = g.node_pos.size() - 1
	var k2: Vector2i = Vector2i(cx, cy)
	if not node_grid.has(k2):
		node_grid[k2] = []
	(node_grid[k2] as Array).append(n2)
	return n2


## Flächen per Halbkanten-Umlauf. Halbkante h = 2*e + dir (0: a->b, 1: b->a).
static func _extract_faces(g: CityGraph) -> void:
	var sorted_out: Array[PackedInt32Array] = []
	for n: int in g.node_count():
		var hes: Array[int] = []
		for e: int in g.node_edges[n]:
			hes.append(e * 2 if g.edge_a[e] == n else e * 2 + 1)
		hes.sort_custom(func(h1: int, h2: int) -> bool:
			return _he_angle(g, h1) < _he_angle(g, h2))
		sorted_out.append(PackedInt32Array(hes))
	var visited: Dictionary = {}
	var total: int = g.edge_count() * 2
	for h0: int in total:
		if visited.has(h0):
			continue
		var nodes: PackedInt32Array = PackedInt32Array()
		var edges: PackedInt32Array = PackedInt32Array()
		var poly: PackedVector2Array = PackedVector2Array()
		var h: int = h0
		var guard: int = 0
		while not visited.has(h) and guard < 5000:
			guard += 1
			visited[h] = true
			var o: int = _he_origin(g, h)
			nodes.append(o)
			edges.append(h >> 1)
			poly.append(g.node_pos[o])
			var v: int = _he_target(g, h)
			var twin: int = h ^ 1
			var lst: PackedInt32Array = sorted_out[v]
			var idx: int = lst.find(twin)
			h = lst[(idx - 1 + lst.size()) % lst.size()]
		var area: float = PolyUtil.signed_area(poly)
		if area > 1.0:
			g.faces.append({"poly": poly, "nodes": nodes, "edges": edges, "area": area, "kind": "block", "id": "block_%d" % g.faces.size()})
		elif area < -1.0 and absf(area) > PolyUtil.area(g.outer_boundary):
			g.outer_boundary = poly
	# Parks markieren
	for pk: Variant in g.layout.get("parks", []):
		var seed: Vector2 = Vector2(float(pk.seed[0]), float(pk.seed[1]))
		var fi: int = g.face_at(seed)
		if fi >= 0:
			g.faces[fi].kind = "park"
			g.faces[fi].id = str(pk.id)
			g.faces[fi].name = str(pk.get("name", ""))


static func _he_origin(g: CityGraph, h: int) -> int:
	var e: int = h >> 1
	return g.edge_a[e] if (h & 1) == 0 else g.edge_b[e]


static func _he_target(g: CityGraph, h: int) -> int:
	var e: int = h >> 1
	return g.edge_b[e] if (h & 1) == 0 else g.edge_a[e]


static func _he_angle(g: CityGraph, h: int) -> float:
	var d: Vector2 = g.node_pos[_he_target(g, h)] - g.node_pos[_he_origin(g, h)]
	return atan2(d.y, d.x)
