class_name PolyUtil
extends RefCounted
## 2D-Polygonhilfen (XZ-Ebene als Vector2(x, z)).


## Vorzeichenbehaftete Fläche (positiv = gegen den Uhrzeigersinn im mathematischen Sinn).
static func signed_area(poly: PackedVector2Array) -> float:
	var a: float = 0.0
	var n: int = poly.size()
	for i: int in n:
		var p: Vector2 = poly[i]
		var q: Vector2 = poly[(i + 1) % n]
		a += p.x * q.y - q.x * p.y
	return a * 0.5


static func area(poly: PackedVector2Array) -> float:
	return absf(signed_area(poly))


static func centroid(poly: PackedVector2Array) -> Vector2:
	var a: float = signed_area(poly)
	if absf(a) < 0.0001:
		var s: Vector2 = Vector2.ZERO
		for p: Vector2 in poly:
			s += p
		return s / maxf(1.0, float(poly.size()))
	var cx: float = 0.0
	var cy: float = 0.0
	var n: int = poly.size()
	for i: int in n:
		var p: Vector2 = poly[i]
		var q: Vector2 = poly[(i + 1) % n]
		var f: float = p.x * q.y - q.x * p.y
		cx += (p.x + q.x) * f
		cy += (p.y + q.y) * f
	return Vector2(cx, cy) / (6.0 * a)


static func ensure_ccw(poly: PackedVector2Array) -> PackedVector2Array:
	if signed_area(poly) < 0.0:
		var r: PackedVector2Array = poly.duplicate()
		r.reverse()
		return r
	return poly


## Entfernt nahezu doppelte und kollineare Punkte.
static func simplify(poly: PackedVector2Array, eps: float = 0.05) -> PackedVector2Array:
	var out: PackedVector2Array = PackedVector2Array()
	for p: Vector2 in poly:
		if out.is_empty() or out[out.size() - 1].distance_to(p) > eps:
			out.append(p)
	if out.size() > 1 and out[0].distance_to(out[out.size() - 1]) <= eps:
		out.remove_at(out.size() - 1)
	var changed: bool = true
	while changed and out.size() > 3:
		changed = false
		for i: int in out.size():
			var a: Vector2 = out[(i - 1 + out.size()) % out.size()]
			var b: Vector2 = out[i]
			var c: Vector2 = out[(i + 1) % out.size()]
			var cr: float = (b - a).cross(c - b)
			if absf(cr) < eps * maxf(0.01, (c - a).length()) * 0.2:
				out.remove_at(i)
				changed = true
				break
	return out


## Versetzt ein CCW-Polygon nach innen; dists[i] gilt für die Kante i -> i+1.
## Gibt ein leeres Array zurück, wenn das Ergebnis degeneriert (Umklappen/zu klein).
static func inset_per_edge(poly: PackedVector2Array, dists: PackedFloat32Array, miter_limit: float = 4.0) -> PackedVector2Array:
	var n: int = poly.size()
	if n < 3:
		return PackedVector2Array()
	var lines_p: Array[Vector2] = []
	var lines_d: Array[Vector2] = []
	for i: int in n:
		var a: Vector2 = poly[i]
		var b: Vector2 = poly[(i + 1) % n]
		var d: Vector2 = (b - a).normalized()
		var inward: Vector2 = Vector2(-d.y, d.x)  # links der Kante = innen bei CCW
		lines_p.append(a + inward * dists[i])
		lines_d.append(d)
	var out: PackedVector2Array = PackedVector2Array()
	for i: int in n:
		var prev: int = (i - 1 + n) % n
		var p1: Vector2 = lines_p[prev]
		var d1: Vector2 = lines_d[prev]
		var p2: Vector2 = lines_p[i]
		var d2: Vector2 = lines_d[i]
		var denom: float = d1.cross(d2)
		var v: Vector2
		if absf(denom) < 0.0001:
			v = p2
		else:
			var t: float = (p2 - p1).cross(d2) / denom
			v = p1 + d1 * t
		var orig: Vector2 = poly[i]
		var maxd: float = maxf(dists[prev], dists[i]) * miter_limit
		if v.distance_to(orig) > maxd:
			v = orig + (v - orig).normalized() * maxd
		out.append(v)
	# Validierung: Orientierung und Kantenrichtungen müssen erhalten bleiben
	if signed_area(out) <= 1.0:
		return PackedVector2Array()
	for i: int in n:
		var e0: Vector2 = poly[(i + 1) % n] - poly[i]
		var e1: Vector2 = out[(i + 1) % n] - out[i]
		if e0.dot(e1) < 0.0:
			return PackedVector2Array()
	if not Geometry2D.triangulate_polygon(out).size() > 0:
		return PackedVector2Array()
	return out


static func point_in_polygon(p: Vector2, poly: PackedVector2Array) -> bool:
	return Geometry2D.is_point_in_polygon(p, poly)


## Abstand Punkt zu Strecke.
static func dist_point_segment(p: Vector2, a: Vector2, b: Vector2) -> float:
	var ab: Vector2 = b - a
	var l2: float = ab.length_squared()
	if l2 < 0.000001:
		return p.distance_to(a)
	var t: float = clampf((p - a).dot(ab) / l2, 0.0, 1.0)
	return p.distance_to(a + ab * t)


static func closest_on_segment(p: Vector2, a: Vector2, b: Vector2) -> Vector2:
	var ab: Vector2 = b - a
	var l2: float = ab.length_squared()
	if l2 < 0.000001:
		return a
	var t: float = clampf((p - a).dot(ab) / l2, 0.0, 1.0)
	return a + ab * t


## Minimaler Abstand eines Punkts zum Polygonrand.
static func dist_to_boundary(p: Vector2, poly: PackedVector2Array) -> float:
	var best: float = INF
	var n: int = poly.size()
	for i: int in n:
		best = minf(best, dist_point_segment(p, poly[i], poly[(i + 1) % n]))
	return best


## Punkt auf einem Kreisbogen (Ursprung = Schlossturm). theta_deg: 0 = Süden (+Z), 90 = Osten (+X).
static func polar(center: Vector2, radius: float, theta_deg: float) -> Vector2:
	var t: float = deg_to_rad(theta_deg)
	return center + Vector2(sin(t), cos(t)) * radius
