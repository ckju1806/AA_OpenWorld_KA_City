class_name SidewalkNetwork
extends RefCounted
## Gehwegnetz aus den Weltdaten (tools/worldgen): je Block eine Gehweg-Schleife (Mittellinie des Gehwegs),
## Querungen zwischen benachbarten Blöcken über Straßen hinweg, Flanierbereiche (Plätze, Parks, Fußgängerzonen).
## Räumlicher Index (64-m-Raster) für schnelle Abfragen in der Nähe des Spielers.

const CELL: float = 64.0

var loops: Array[PackedVector2Array] = []
var crossings: Dictionary = {}         ## "loop:vertex" -> Array[[loop, vertex]]
var wander_areas: Array[Dictionary] = []  ## { center: Vector2, radius } oder { center, half, dir }
var slab_h: float = 0.12
var _grid: Dictionary = {}             ## Vector2i -> PackedInt32Array (li * 4096 + vi)


func build_from_world(w: WorldData, g: CityGraph, p_slab_h: float) -> void:
	slab_h = p_slab_h
	var walk: Dictionary = w.meta.get("walk", {})
	for lp: Variant in walk.get("loops", []):
		loops.append(w.pts(lp))
	var cr: Array = walk.get("cross", [])
	for i: int in range(0, cr.size(), 4):
		var key: String = "%d:%d" % [int(cr[i]), int(cr[i + 1])]
		if not crossings.has(key):
			crossings[key] = []
		(crossings[key] as Array).append([int(cr[i + 2]), int(cr[i + 3])])
	var wa: Array = walk.get("wander", [])
	var inv: float = 1.0 / w.q
	for i2: int in range(0, wa.size(), 4):
		wander_areas.append({"center": Vector2(float(wa[i2]) * inv, float(wa[i2 + 1]) * inv), "radius": float(wa[i2 + 2]) * inv})
	# Fußgängerzonen als Flanierbereiche
	for e: int in g.edge_count():
		if g.is_pedestrian(e):
			var a: Vector2 = g.node_pos[g.edge_a[e]]
			var b2: Vector2 = g.node_pos[g.edge_b[e]]
			var dir: Vector2 = (b2 - a).normalized()
			if a.distance_to(b2) > 12.0:
				wander_areas.append({"center": (a + b2) * 0.5, "half": Vector2(a.distance_to(b2) * 0.5, 4.5), "dir": dir})
	for li: int in loops.size():
		for vi: int in loops[li].size():
			var c: Vector2i = _cell(loops[li][vi])
			var arr: PackedInt32Array = _grid.get(c, PackedInt32Array())
			arr.append(li * 4096 + vi)
			_grid[c] = arr


func _cell(p: Vector2) -> Vector2i:
	return Vector2i(int(floor(p.x / CELL)), int(floor(p.y / CELL)))


## Zufälliger Gehwegpunkt im Ring [rmin, rmax] um p. Rückgabe [li, vi] oder [].
func random_point_near(p: Vector2, rmin: float, rmax: float, rng: RandomNumberGenerator) -> Array:
	var c0: Vector2i = _cell(p - Vector2(rmax, rmax))
	var c1: Vector2i = _cell(p + Vector2(rmax, rmax))
	for attempt: int in 12:
		var c: Vector2i = Vector2i(rng.randi_range(c0.x, c1.x), rng.randi_range(c0.y, c1.y))
		var arr: PackedInt32Array = _grid.get(c, PackedInt32Array())
		if arr.is_empty():
			continue
		var code: int = arr[rng.randi() % arr.size()]
		var li: int = code / 4096
		var vi: int = code % 4096
		var d: float = loops[li][vi].distance_to(p)
		if d >= rmin and d <= rmax:
			return [li, vi]
	return []


## Flanierbereiche im Umkreis.
func wander_near(p: Vector2, r: float) -> Array[int]:
	var out: Array[int] = []
	for i: int in wander_areas.size():
		if (wander_areas[i].center as Vector2).distance_to(p) < r:
			out.append(i)
	return out


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
