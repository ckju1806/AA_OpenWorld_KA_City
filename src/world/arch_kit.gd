class_name ArchKit
extends RefCounted
## Architektur-Bausteine auf Basis von MeshKit: Fassadenwände (mit Shader-Parametern),
## Sattel-/Mansard-/Flachdächer, Säulen, Giebel. Material-Schlüssel siehe CityMaterials.

const STYLE_NORMAL: float = 0.0
const STYLE_PALACE: float = 1.0
const STYLE_MODERN: float = 2.0
const STYLE_BLANK: float = 3.0


## Fassadenwand von a nach b (XZ), von y0 bis y1. Außen = rechts der Richtung a->b
## (bei gegen den Uhrzeigersinn umlaufenden Grundrissen).
static func wall(kit: MeshKit, a: Vector2, b: Vector2, y0: float, y1: float, wall_color: Color, seed: float,
		shop: bool = false, sign_hue: float = 0.0, style: float = STYLE_NORMAL, floor_h: float = 3.3) -> void:
	var d: Vector2 = b - a
	var length: float = d.length()
	if length < 0.05:
		return
	var out2: Vector2 = Vector2(d.y, -d.x) / length
	var n: Vector3 = Vector3(out2.x, 0.0, out2.y)
	var h: float = y1 - y0
	kit.color = Color(wall_color.r, wall_color.g, wall_color.b, seed)
	kit.custom0 = Color(1.0 if shop else 0.0, sign_hue, style, floor_h)
	kit.uv2 = Vector2(length, h)
	kit.add_quad("facade", Vector3(a.x, y0, a.y), Vector3(b.x, y0, b.y), Vector3(b.x, y1, b.y), Vector3(a.x, y1, a.y), n,
		Vector2(0, 0), Vector2(length, 0), Vector2(length, h), Vector2(0, h))
	kit.color = Color.WHITE
	kit.custom0 = Color(0, 0, 0, 0)
	kit.uv2 = Vector2.ZERO


## Satteldach über einem Viereck (a0, a1 vorne; b1, b0 hinten), First parallel zur Vorderkante.
static func gable_roof(kit: MeshKit, a0: Vector2, a1: Vector2, b1: Vector2, b0: Vector2, y: float, roof_h: float,
		roof_color: Color, wall_color: Color, seed: float) -> void:
	var m0: Vector2 = (a0 + b0) * 0.5
	var m1: Vector2 = (a1 + b1) * 0.5
	var r0: Vector3 = Vector3(m0.x, y + roof_h, m0.y)
	var r1: Vector3 = Vector3(m1.x, y + roof_h, m1.y)
	var A0: Vector3 = Vector3(a0.x, y, a0.y)
	var A1: Vector3 = Vector3(a1.x, y, a1.y)
	var B0: Vector3 = Vector3(b0.x, y, b0.y)
	var B1: Vector3 = Vector3(b1.x, y, b1.y)
	# Dachüberstand leicht nach außen
	var front_dir: Vector3 = (A0 - r0)
	front_dir.y = 0.0
	var back_dir: Vector3 = (B0 - r0)
	back_dir.y = 0.0
	var ov: float = 0.35
	var A0o: Vector3 = A0 + front_dir.normalized() * ov - Vector3(0, ov * roof_h / maxf(front_dir.length(), 0.1), 0)
	var A1o: Vector3 = A1 + front_dir.normalized() * ov - Vector3(0, ov * roof_h / maxf(front_dir.length(), 0.1), 0)
	var B0o: Vector3 = B0 + back_dir.normalized() * ov - Vector3(0, ov * roof_h / maxf(back_dir.length(), 0.1), 0)
	var B1o: Vector3 = B1 + back_dir.normalized() * ov - Vector3(0, ov * roof_h / maxf(back_dir.length(), 0.1), 0)
	kit.color = roof_color
	var nf: Vector3 = (A1 - A0).cross(r0 - A0).normalized()
	if nf.y < 0.0:
		nf = -nf
	var slope_f: float = r0.distance_to(A0o)
	var lf: float = A0.distance_to(A1)
	kit.add_quad("roof", A0o, A1o, r1, r0, nf, Vector2(0, slope_f), Vector2(lf, slope_f), Vector2(lf, 0), Vector2(0, 0))
	var nb: Vector3 = (B1 - B0).cross(r0 - B0).normalized()
	if nb.y < 0.0:
		nb = -nb
	var slope_b: float = r0.distance_to(B0o)
	var lb: float = B0.distance_to(B1)
	kit.add_quad("roof", B0o, B1o, r1, r0, nb, Vector2(0, slope_b), Vector2(lb, slope_b), Vector2(lb, 0), Vector2(0, 0))
	kit.color = Color.WHITE
	# Giebeldreiecke (Brandwand-Stil)
	for tri: Array in [[a1, b1, r1], [b0, a0, r0]]:
		var p: Vector2 = tri[0]
		var q: Vector2 = tri[1]
		var apex: Vector3 = tri[2]
		var d: Vector2 = q - p
		var out2: Vector2 = Vector2(d.y, -d.x).normalized()
		kit.color = Color(wall_color.r, wall_color.g, wall_color.b, seed)
		kit.custom0 = Color(0, 0, STYLE_BLANK, 3.3)
		kit.uv2 = Vector2(d.length(), roof_h)
		kit.add_tri("facade", Vector3(p.x, y, p.y), Vector3(q.x, y, q.y), apex, Vector3(out2.x, 0, out2.y),
			Vector2(0, 1), Vector2(d.length(), 1), Vector2(d.length() * 0.5, roof_h + 1))
	kit.color = Color.WHITE
	kit.custom0 = Color(0, 0, 0, 0)
	kit.uv2 = Vector2.ZERO


## Flachdach mit Attika.
static func flat_roof(kit: MeshKit, poly: PackedVector2Array, y: float, roof_color: Color, parapet_color: Color) -> void:
	kit.color = roof_color
	kit.add_polygon_xz("flat", poly, y + 0.05, 1.0)
	kit.color = parapet_color
	var n: int = poly.size()
	for i: int in n:
		var a: Vector2 = poly[i]
		var b: Vector2 = poly[(i + 1) % n]
		var mid: Vector2 = (a + b) * 0.5
		var d: Vector2 = b - a
		var basis := Basis(Vector3.UP, atan2(-d.y, d.x))
		kit.add_box("flat", Vector3(mid.x, y + 0.35, mid.y), Vector3(d.length() + 0.3, 0.7, 0.3), basis)
	kit.color = Color.WHITE


## Mansarddach über einem Rechteck (Mittelpunkt, Größe, Drehung).
static func mansard_roof(kit: MeshKit, center: Vector2, size: Vector2, yaw: float, y: float, h1: float, h2: float,
		inset1: float, roof_color: Color) -> void:
	var basis := Basis(Vector3.UP, yaw)
	var hx: float = size.x * 0.5
	var hz: float = size.y * 0.5
	var c3: Vector3 = Vector3(center.x, y, center.y)
	var lower: Array[Vector3] = []
	var mid: Array[Vector3] = []
	var top: Array[Vector3] = []
	for s: Vector2 in [Vector2(-1, -1), Vector2(1, -1), Vector2(1, 1), Vector2(-1, 1)]:
		lower.append(c3 + basis * Vector3(s.x * (hx + 0.3), 0, s.y * (hz + 0.3)))
		mid.append(c3 + basis * Vector3(s.x * (hx - inset1), h1, s.y * (hz - inset1)))
		top.append(c3 + basis * Vector3(s.x * (hx - inset1 * 2.2), h1 + h2, s.y * (hz - inset1 * 2.2)))
	kit.color = roof_color
	for i: int in 4:
		var j: int = (i + 1) % 4
		var nrm: Vector3 = ((lower[i] + lower[j]) * 0.5 - c3)
		nrm.y = 0.0
		nrm = nrm.normalized()
		var l: float = lower[i].distance_to(lower[j])
		kit.add_quad("roof", lower[i], lower[j], mid[j], mid[i], (nrm + Vector3.UP * 0.35).normalized(),
			Vector2(0, 4), Vector2(l, 4), Vector2(l, 0), Vector2(0, 0))
		kit.add_quad("roof", mid[i], mid[j], top[j], top[i], (nrm * 0.4 + Vector3.UP).normalized(),
			Vector2(0, 4), Vector2(l, 4), Vector2(l, 0), Vector2(0, 0))
	kit.add_quad("roof", top[0], top[1], top[2], top[3], Vector3.UP)
	kit.color = Color.WHITE


## Quaderförmiger Baukörper mit Fassaden (Grundriss als gedrehtes Rechteck).
static func block(kit: MeshKit, center: Vector2, size: Vector2, yaw: float, y0: float, y1: float, wall_color: Color,
		seed: float, style: float = STYLE_NORMAL, floor_h: float = 3.3, shop: bool = false) -> PackedVector2Array:
	var poly: PackedVector2Array = rect_poly(center, size, yaw)
	for i: int in 4:
		wall(kit, poly[i], poly[(i + 1) % 4], y0, y1, wall_color, seed, shop, seed, style, floor_h)
	return poly


## Rechteck-Grundriss (CCW im XZ-Mathematiksinn), yaw in Radiant um die Y-Achse.
static func rect_poly(center: Vector2, size: Vector2, yaw: float) -> PackedVector2Array:
	var hx: float = size.x * 0.5
	var hz: float = size.y * 0.5
	var out: PackedVector2Array = PackedVector2Array()
	for s: Vector2 in [Vector2(-1, -1), Vector2(1, -1), Vector2(1, 1), Vector2(-1, 1)]:
		var local: Vector3 = Basis(Vector3.UP, yaw) * Vector3(s.x * hx, 0, s.y * hz)
		out.append(center + Vector2(local.x, local.z))
	return PolyUtil.ensure_ccw(out)


## Säule mit Basis und Kapitell (Vertex-Farbe).
static func column(kit: MeshKit, base: Vector3, radius: float, height: float, col: Color) -> void:
	kit.color = col
	kit.add_box("stone", base + Vector3(0, 0.25, 0), Vector3(radius * 2.6, 0.5, radius * 2.6))
	kit.add_cylinder("stone", base + Vector3(0, 0.5, 0), radius, radius * 0.88, height - 1.1, 12)
	kit.add_box("stone", base + Vector3(0, height - 0.3, 0), Vector3(radius * 2.8, 0.6, radius * 2.8))
	kit.color = Color.WHITE


## Dreiecksgiebel (Tympanon) über einer Kante a-b in Höhe y, Tiefe depth nach außen/innen.
static func pediment(kit: MeshKit, a: Vector3, b: Vector3, height: float, depth: float, col: Color) -> void:
	var mid: Vector3 = (a + b) * 0.5 + Vector3(0, height, 0)
	var along: Vector3 = (b - a).normalized()
	var out: Vector3 = along.cross(Vector3.UP).normalized()
	var off: Vector3 = out * depth
	kit.color = col
	kit.add_tri("stone", a + off, b + off, mid + off, out)
	kit.add_tri("stone", a - off, b - off, mid - off, -out)
	var n1: Vector3 = (mid - a).cross(out).normalized()
	if n1.y < 0.0:
		n1 = -n1
	kit.add_quad("stone", a + off, mid + off, mid - off, a - off, n1)
	var n2: Vector3 = (b - mid).cross(out).normalized()
	if n2.y < 0.0:
		n2 = -n2
	kit.add_quad("stone", mid + off, b + off, b - off, mid - off, n2)
	kit.color = Color.WHITE
