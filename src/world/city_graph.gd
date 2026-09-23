class_name CityGraph
extends RefCounted
## Gemeinsame Datenbasis der Stadt: planarer Straßengraph (Knoten/Kanten), Häuserblöcke (Faces),
## Plätze, POIs. Wird von Weltaufbau, Verkehr, Polizei, Missionen und Karte gemeinsam genutzt.

var layout: Dictionary = {}
var streets: Array[Dictionary] = []          ## id, name, kind, width, speed, drivable, traffic, parking
var node_pos: PackedVector2Array = PackedVector2Array()
var node_edges: Array[PackedInt32Array] = []
var edge_a: PackedInt32Array = PackedInt32Array()
var edge_b: PackedInt32Array = PackedInt32Array()
var edge_street: PackedInt32Array = PackedInt32Array()
var faces: Array[Dictionary] = []            ## poly, nodes, edges, area, kind (block/park), id
var outer_boundary: PackedVector2Array = PackedVector2Array()

var _astar_drive: AStar2D
var _astar_traffic: AStar2D
var _astar_police: AStar2D


# ------------------------------------------------------------ Knoten / Kanten

func edge_count() -> int:
	return edge_a.size()


func node_count() -> int:
	return node_pos.size()


func street_of(e: int) -> Dictionary:
	return streets[edge_street[e]]


func edge_width(e: int) -> float:
	return float(streets[edge_street[e]].width)


func edge_kind(e: int) -> String:
	return str(streets[edge_street[e]].kind)


func is_drivable(e: int) -> bool:
	return bool(streets[edge_street[e]].drivable)


func is_traffic(e: int) -> bool:
	return bool(streets[edge_street[e]].traffic)


func is_pedestrian(e: int) -> bool:
	return edge_kind(e) == "pedestrian"


func edge_speed(e: int) -> float:
	return float(streets[edge_street[e]].speed)


func other_node(e: int, n: int) -> int:
	return edge_b[e] if edge_a[e] == n else edge_a[e]


func edge_length(e: int) -> float:
	return node_pos[edge_a[e]].distance_to(node_pos[edge_b[e]])


func edge_dir(e: int, from_node: int) -> Vector2:
	var to: int = other_node(e, from_node)
	return (node_pos[to] - node_pos[from_node]).normalized()


func find_edge(a: int, b: int) -> int:
	for e: int in node_edges[a]:
		if other_node(e, a) == b:
			return e
	return -1


## Kanten eines Knotens nach Modus: "drive" (befahrbar), "traffic" (Verkehrs-KI), "walk" (alle)
func node_edges_mode(n: int, mode: String) -> PackedInt32Array:
	var out: PackedInt32Array = PackedInt32Array()
	for e: int in node_edges[n]:
		if _edge_ok(e, mode):
			out.append(e)
	return out


func _edge_ok(e: int, mode: String) -> bool:
	match mode:
		"drive":
			return is_drivable(e)
		"traffic":
			return is_traffic(e)
		"police":
			return true
		_:
			return true


func degree(n: int, mode: String = "all") -> int:
	return node_edges_mode(n, mode).size()


## Maximale halbe Straßenbreite an einem Knoten (für Kreuzungsbereiche).
func node_radius(n: int, mode: String = "drive") -> float:
	var r: float = 0.0
	for e: int in node_edges[n]:
		if _edge_ok(e, mode):
			r = maxf(r, edge_width(e) * 0.5)
	return r


func pos3(n: int, y: float = 0.0) -> Vector3:
	return Vector3(node_pos[n].x, y, node_pos[n].y)


# ------------------------------------------------------------ Suche

## Nächster Punkt auf einer Kante (Modus-Filter). Rückgabe: { edge, point: Vector2, dist, t }
func nearest_edge_point(p: Vector2, mode: String = "drive") -> Dictionary:
	var best: Dictionary = {"edge": -1, "point": p, "dist": INF, "t": 0.0}
	for e: int in edge_count():
		if not _edge_ok(e, mode):
			continue
		var a: Vector2 = node_pos[edge_a[e]]
		var b: Vector2 = node_pos[edge_b[e]]
		var q: Vector2 = PolyUtil.closest_on_segment(p, a, b)
		var d: float = q.distance_to(p)
		if d < best.dist:
			var ab: float = a.distance_to(b)
			best = {"edge": e, "point": q, "dist": d, "t": (q.distance_to(a) / ab) if ab > 0.0 else 0.0}
	return best


func nearest_node(p: Vector2, mode: String = "drive") -> int:
	var best: int = -1
	var best_d: float = INF
	for n: int in node_count():
		if mode != "all" and degree(n, mode) == 0:
			continue
		var d: float = node_pos[n].distance_squared_to(p)
		if d < best_d:
			best_d = d
			best = n
	return best


## Kürzester Weg (Knotenfolge) über A*. mode: drive | traffic | police
func find_path(from_node: int, to_node: int, mode: String = "drive") -> PackedInt32Array:
	var astar: AStar2D = _get_astar(mode)
	if astar == null or not astar.has_point(from_node) or not astar.has_point(to_node):
		return PackedInt32Array()
	var ids: PackedInt64Array = astar.get_id_path(from_node, to_node)
	var out: PackedInt32Array = PackedInt32Array()
	for id: int in ids:
		out.append(id)
	return out


## Wegpunkte auf der rechten Fahrspur (Rechtsverkehr) entlang einer Knotenfolge.
## An Kreuzungen: Eckpunkt = Schnitt der versetzten Spurlinien, darüber eine Bézier-Abbiegekurve,
## damit Fahrzeuge in ihrer Spur bleiben und keine Bordsteinecken schneiden.
func lane_path(path: PackedInt32Array, offset: float = 2.6, y: float = 0.0, sample: float = 18.0) -> PackedVector3Array:
	var out: PackedVector3Array = PackedVector3Array()
	var n: int = path.size()
	if n < 2:
		return out
	var zones: Array[float] = []   # Länge der Abbiegezone je Knoten
	var turn_pts: Array[PackedVector2Array] = []
	for i: int in n:
		var p: Vector2 = node_pos[path[i]]
		var pts: PackedVector2Array = PackedVector2Array()
		var zone: float = 0.0
		if i == 0 or i == n - 1:
			var d: Vector2 = (node_pos[path[1]] - p).normalized() if i == 0 else (p - node_pos[path[i - 1]]).normalized()
			pts.append(p + Vector2(-d.y, d.x) * offset)
		else:
			var d_in: Vector2 = (p - node_pos[path[i - 1]]).normalized()
			var d_out: Vector2 = (node_pos[path[i + 1]] - p).normalized()
			var r_in: Vector2 = Vector2(-d_in.y, d_in.x)
			var r_out: Vector2 = Vector2(-d_out.y, d_out.x)
			var cr: float = d_in.cross(d_out)
			if absf(cr) < 0.17:
				if d_in.dot(d_out) > 0.0:
					# nahezu geradeaus
					pts.append(p + ((r_in + r_out) * 0.5).normalized() * offset)
				else:
					# Wende (nur in Sonderfällen)
					pts.append(p + r_in * offset + d_in * 3.0)
					pts.append(p + d_in * 5.0)
					pts.append(p - r_in * offset + d_in * 3.0)
					zone = 5.0
			else:
				var a: Vector2 = p + r_in * offset
				var b: Vector2 = p + r_out * offset
				var t: float = (b - a).cross(d_out) / cr
				var corner: Vector2 = a + d_in * t
				var k: float = clampf(node_radius(path[i], "all") + 1.5, 4.0, 11.0)
				var s0: Vector2 = corner - d_in * k
				var s1: Vector2 = corner + d_out * k
				for j: int in 5:
					var u: float = float(j) / 4.0
					pts.append(s0.lerp(corner, u).lerp(corner.lerp(s1, u), u))
				zone = k + absf(t)
		zones.append(zone)
		turn_pts.append(pts)
	for i2: int in n:
		for q: Vector2 in turn_pts[i2]:
			out.append(Vector3(q.x, y, q.y))
		if i2 < n - 1:
			var a2: Vector2 = node_pos[path[i2]]
			var b2: Vector2 = node_pos[path[i2 + 1]]
			var seg: float = a2.distance_to(b2)
			var dd: Vector2 = (b2 - a2) / maxf(seg, 0.001)
			var rr: Vector2 = Vector2(-dd.y, dd.x) * offset
			var t0: float = zones[i2] + 2.0
			var t1: float = seg - zones[i2 + 1] - 2.0
			var tt: float = t0 + sample
			while tt < t1:
				var m: Vector2 = a2 + dd * tt + rr
				out.append(Vector3(m.x, y, m.y))
				tt += sample
	return out


func path_to_points(path: PackedInt32Array, y: float = 0.0) -> PackedVector3Array:
	var out: PackedVector3Array = PackedVector3Array()
	for n: int in path:
		out.append(pos3(n, y))
	return out


func _get_astar(mode: String) -> AStar2D:
	match mode:
		"traffic":
			if _astar_traffic == null:
				_astar_traffic = _build_astar("traffic", 1.0)
			return _astar_traffic
		"police":
			if _astar_police == null:
				_astar_police = _build_astar("police", 3.0)
			return _astar_police
		_:
			if _astar_drive == null:
				_astar_drive = _build_astar("drive", 1.0)
			return _astar_drive


func _build_astar(mode: String, ped_weight: float) -> AStar2D:
	var a := AStar2D.new()
	for n: int in node_count():
		var edges: PackedInt32Array = node_edges_mode(n, mode)
		if edges.is_empty():
			continue
		var only_ped: bool = true
		for e: int in edges:
			if not is_pedestrian(e):
				only_ped = false
		a.add_point(n, node_pos[n], ped_weight if only_ped else 1.0)
	for e: int in edge_count():
		if not _edge_ok(e, mode):
			continue
		if a.has_point(edge_a[e]) and a.has_point(edge_b[e]):
			a.connect_points(edge_a[e], edge_b[e], true)
	return a


## Anzahl zusammenhängender Komponenten im Modus (für Tests: befahrbares Netz = 1).
func component_count(mode: String) -> int:
	var seen: Dictionary = {}
	var comps: int = 0
	for n: int in node_count():
		if seen.has(n) or degree(n, mode) == 0:
			continue
		comps += 1
		var stack: Array[int] = [n]
		seen[n] = true
		while not stack.is_empty():
			var cur: int = stack.pop_back()
			for e: int in node_edges_mode(cur, mode):
				var o: int = other_node(e, cur)
				if not seen.has(o):
					seen[o] = true
					stack.append(o)
	return comps


# ------------------------------------------------------------ Layout-Zugriff

func get_poi(poi_id: String) -> Dictionary:
	for p: Variant in layout.get("pois", []):
		if p is Dictionary and str(p.id) == poi_id:
			return p
	return {}


func poi_pos3(poi_id: String, y: float = 0.0) -> Vector3:
	var p: Dictionary = get_poi(poi_id)
	if p.is_empty():
		push_warning("POI fehlt: %s" % poi_id)
		return Vector3.ZERO
	return Vector3(float(p.pos[0]), y, float(p.pos[1]))


func poi_yaw(poi_id: String) -> float:
	var p: Dictionary = get_poi(poi_id)
	return deg_to_rad(float(p.get("yaw", 0.0)))


func face_at(p: Vector2) -> int:
	for i: int in faces.size():
		if Geometry2D.is_point_in_polygon(p, faces[i].poly):
			return i
	return -1
