class_name SidewalkNetwork
extends RefCounted
## Gehwegnetz aus den Häuserblöcken: je Block eine Gehweg-Schleife (Mittellinie des Gehwegs),
## Querungen an Kreuzungsecken zwischen benachbarten Blöcken, Flanierbereiche (Fußgängerzonen, Plätze).

const PATH_INSET: float = 2.6

var loops: Array[PackedVector2Array] = []
var crossings: Dictionary = {}         ## "loop:vertex" -> Array[[loop, vertex]]
var wander_areas: Array[Dictionary] = []  ## { center: Vector2, half: Vector2, yaw: float } oder { center, radius }
var slab_h: float = 0.12


func build(g: CityGraph, blocks: Array[Dictionary], p_slab_h: float) -> void:
	slab_h = p_slab_h
	for b: Dictionary in blocks:
		if b.kind != "block":
			continue
		var curb: PackedVector2Array = b.curb
		var inset: PackedVector2Array = PolyUtil.inset_per_edge(curb, _uniform(curb.size(), PATH_INSET))
		if inset.size() >= 3 and PolyUtil.area(inset) > 200.0:
			loops.append(PolyUtil.simplify(inset, 0.5))
	# Querungen: Eckpunkte benachbarter Blöcke über eine Straße hinweg (8–30 m)
	for li: int in loops.size():
		for vi: int in loops[li].size():
			var p: Vector2 = loops[li][vi]
			var cand: Array = []
			for lj: int in loops.size():
				if lj == li:
					continue
				for vj: int in loops[lj].size():
					var d: float = p.distance_to(loops[lj][vj])
					if d > 8.0 and d < 30.0:
						cand.append([lj, vj, d])
			cand.sort_custom(func(x: Array, y: Array) -> bool: return float(x[2]) < float(y[2]))
			var picks: Array = []
			for c: Array in cand.slice(0, 2):
				picks.append([int(c[0]), int(c[1])])
			if not picks.is_empty():
				crossings["%d:%d" % [li, vi]] = picks
	# Flanierbereiche
	for e: int in g.edge_count():
		if g.is_pedestrian(e):
			var a: Vector2 = g.node_pos[g.edge_a[e]]
			var b2: Vector2 = g.node_pos[g.edge_b[e]]
			var dir: Vector2 = (b2 - a).normalized()
			var ta: float = g.node_radius(g.edge_a[e], "drive") + 3.0
			var tb: float = g.node_radius(g.edge_b[e], "drive") + 3.0
			var pa: Vector2 = a + dir * ta
			var pb: Vector2 = b2 - dir * tb
			if (pb - pa).dot(dir) > 8.0:
				wander_areas.append({"center": (pa + pb) * 0.5, "half": Vector2(pa.distance_to(pb) * 0.5, 4.5), "dir": dir})
	for c2: Variant in g.layout.get("clearings", []):
		var cd: Dictionary = c2
		if cd.has("circle"):
			var ci: Array = cd.circle
			wander_areas.append({"center": Vector2(float(ci[0]), float(ci[1])), "radius": float(ci[2]) * 0.5})
		elif cd.has("rect"):
			var r: Array = cd.rect
			var cen: Vector2 = Vector2((float(r[0]) + float(r[2])) * 0.5, (float(r[1]) + float(r[3])) * 0.5)
			wander_areas.append({"center": cen, "half": Vector2((float(r[2]) - float(r[0])) * 0.35, (float(r[3]) - float(r[1])) * 0.35), "dir": Vector2(1, 0)})


static func _uniform(n: int, d: float) -> PackedFloat32Array:
	var a: PackedFloat32Array = PackedFloat32Array()
	a.resize(n)
	a.fill(d)
	return a


func random_wander_point(area: Dictionary, rng: RandomNumberGenerator) -> Vector2:
	var c: Vector2 = area.center
	if area.has("radius"):
		var ang: float = rng.randf() * TAU
		return c + Vector2(cos(ang), sin(ang)) * sqrt(rng.randf()) * float(area.radius)
	var h: Vector2 = area.half
	var dir: Vector2 = area.dir
	var perp: Vector2 = Vector2(-dir.y, dir.x)
	return c + dir * rng.randf_range(-h.x, h.x) + perp * rng.randf_range(-h.y, h.y)


func area_contains(area: Dictionary, p: Vector2) -> bool:
	var c: Vector2 = area.center
	if area.has("radius"):
		return p.distance_to(c) < float(area.radius) * 1.3
	var d: Vector2 = p - c
	var dir: Vector2 = area.dir
	return absf(d.dot(dir)) < float((area.half as Vector2).x) + 4.0 and absf(d.dot(Vector2(-dir.y, dir.x))) < float((area.half as Vector2).y) + 3.0
