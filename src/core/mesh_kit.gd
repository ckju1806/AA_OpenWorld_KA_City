class_name MeshKit
extends RefCounted
## Sammelt prozedurale Geometrie nach Material-Schlüssel und erzeugt ein ArrayMesh
## mit wenigen Oberflächen (eine pro Material). Dreiecke werden automatisch so
## orientiert, dass ihre Vorderseite zur angegebenen Normalen zeigt (Godot: Uhrzeigersinn).

var _tools: Dictionary = {}      # String -> SurfaceTool
var _materials: Dictionary = {}  # String -> Material
var _custom: Dictionary = {}     # String -> bool (CUSTOM0 aktiv)
var _counts: Dictionary = {}     # String -> int (Vertices)

## Aktuelle Vertex-Attribute (werden auf neue Vertices angewendet)
var color: Color = Color.WHITE
var custom0: Color = Color(0, 0, 0, 0)
var uv2: Vector2 = Vector2.ZERO


func set_material(key: String, mat: Material, uses_custom0: bool = false) -> void:
	_materials[key] = mat
	_custom[key] = uses_custom0


func _st(key: String) -> SurfaceTool:
	if not _tools.has(key):
		var st := SurfaceTool.new()
		st.begin(Mesh.PRIMITIVE_TRIANGLES)
		if _custom.get(key, false):
			st.set_custom_format(0, SurfaceTool.CUSTOM_RGBA_FLOAT)
		_tools[key] = st
		_counts[key] = 0
	return _tools[key]


func is_empty() -> bool:
	for k: String in _counts:
		if int(_counts[k]) > 0:
			return false
	return true


## Einzelnes Dreieck; n = gewünschte Außen-Normale.
func add_tri(key: String, a: Vector3, b: Vector3, c: Vector3, n: Vector3,
		uva: Vector2 = Vector2.ZERO, uvb: Vector2 = Vector2.ZERO, uvc: Vector2 = Vector2.ZERO) -> void:
	var fn: Vector3 = (b - a).cross(c - a)
	if fn.dot(n) > 0.0:
		# Reihenfolge tauschen, damit die Vorderseite (Uhrzeigersinn) zur Normalen zeigt
		var tb: Vector3 = b
		b = c
		c = tb
		var tuv: Vector2 = uvb
		uvb = uvc
		uvc = tuv
	var st: SurfaceTool = _st(key)
	var use_custom: bool = _custom.get(key, false)
	for i: int in 3:
		var p: Vector3 = a if i == 0 else (b if i == 1 else c)
		var uv: Vector2 = uva if i == 0 else (uvb if i == 1 else uvc)
		st.set_normal(n)
		st.set_color(color)
		st.set_uv(uv)
		st.set_uv2(uv2)
		if use_custom:
			st.set_custom(0, custom0)
		st.add_vertex(p)
	_counts[key] = int(_counts[key]) + 3


## Viereck p0..p3 (beliebiger Umlaufsinn), n = Außen-Normale.
func add_quad(key: String, p0: Vector3, p1: Vector3, p2: Vector3, p3: Vector3, n: Vector3,
		uv0: Vector2 = Vector2(0, 0), uv1: Vector2 = Vector2(1, 0),
		uv2_: Vector2 = Vector2(1, 1), uv3: Vector2 = Vector2(0, 1)) -> void:
	add_tri(key, p0, p1, p2, n, uv0, uv1, uv2_)
	add_tri(key, p0, p2, p3, n, uv0, uv2_, uv3)


## Quader mit Mittelpunkt, Größe und optionaler Drehung (Basis).
func add_box(key: String, center: Vector3, size: Vector3, basis: Basis = Basis.IDENTITY,
		skip_bottom: bool = true) -> void:
	var h: Vector3 = size * 0.5
	var ax: Vector3 = basis.x.normalized()
	var ay: Vector3 = basis.y.normalized()
	var az: Vector3 = basis.z.normalized()
	var corners: Array[Vector3] = []
	for i: int in 8:
		var sx: float = -1.0 if (i & 1) == 0 else 1.0
		var sy: float = -1.0 if (i & 2) == 0 else 1.0
		var sz: float = -1.0 if (i & 4) == 0 else 1.0
		corners.append(center + ax * h.x * sx + ay * h.y * sy + az * h.z * sz)
	# +X, -X
	add_quad(key, corners[1], corners[3], corners[7], corners[5], ax,
		Vector2(0, 0), Vector2(0, size.y), Vector2(size.z, size.y), Vector2(size.z, 0))
	add_quad(key, corners[0], corners[2], corners[6], corners[4], -ax,
		Vector2(0, 0), Vector2(0, size.y), Vector2(size.z, size.y), Vector2(size.z, 0))
	# +Y, -Y
	add_quad(key, corners[2], corners[3], corners[7], corners[6], ay,
		Vector2(0, 0), Vector2(size.x, 0), Vector2(size.x, size.z), Vector2(0, size.z))
	if not skip_bottom:
		add_quad(key, corners[0], corners[1], corners[5], corners[4], -ay)
	# +Z, -Z
	add_quad(key, corners[4], corners[5], corners[7], corners[6], az,
		Vector2(0, 0), Vector2(size.x, 0), Vector2(size.x, size.y), Vector2(0, size.y))
	add_quad(key, corners[0], corners[1], corners[3], corners[2], -az,
		Vector2(0, 0), Vector2(size.x, 0), Vector2(size.x, size.y), Vector2(0, size.y))


## Zylinder (optional Kegelstumpf) entlang der lokalen Y-Achse der Basis.
func add_cylinder(key: String, base_center: Vector3, radius_bottom: float, radius_top: float,
		height: float, segments: int = 12, basis: Basis = Basis.IDENTITY, caps: bool = true) -> void:
	var ay: Vector3 = basis.y.normalized()
	var ax: Vector3 = basis.x.normalized()
	var az: Vector3 = basis.z.normalized()
	var top_center: Vector3 = base_center + ay * height
	for i: int in segments:
		var a0: float = TAU * float(i) / float(segments)
		var a1: float = TAU * float(i + 1) / float(segments)
		var d0: Vector3 = ax * cos(a0) + az * sin(a0)
		var d1: Vector3 = ax * cos(a1) + az * sin(a1)
		var b0: Vector3 = base_center + d0 * radius_bottom
		var b1: Vector3 = base_center + d1 * radius_bottom
		var t0: Vector3 = top_center + d0 * radius_top
		var t1: Vector3 = top_center + d1 * radius_top
		var n: Vector3 = ((d0 + d1) * 0.5).normalized()
		var slope: float = (radius_bottom - radius_top) / maxf(height, 0.001)
		n = (n + ay * slope).normalized()
		var u0: float = float(i) / float(segments)
		var u1: float = float(i + 1) / float(segments)
		add_quad(key, b0, b1, t1, t0, n, Vector2(u0, 0), Vector2(u1, 0), Vector2(u1, 1), Vector2(u0, 1))
		if caps:
			if radius_top > 0.001:
				add_tri(key, top_center, t0, t1, ay)
			if radius_bottom > 0.001:
				add_tri(key, base_center, b0, b1, -ay)


## Grobe Kugel/Ellipsoid (Low-Poly), z. B. für Baumkronen und Köpfe.
func add_sphere(key: String, center: Vector3, radii: Vector3, rings: int = 6, segments: int = 8) -> void:
	for r: int in rings:
		var v0: float = PI * float(r) / float(rings)
		var v1: float = PI * float(r + 1) / float(rings)
		for s: int in segments:
			var h0: float = TAU * float(s) / float(segments)
			var h1: float = TAU * float(s + 1) / float(segments)
			var p00: Vector3 = _sph(v0, h0)
			var p01: Vector3 = _sph(v0, h1)
			var p10: Vector3 = _sph(v1, h0)
			var p11: Vector3 = _sph(v1, h1)
			var n: Vector3 = (p00 + p01 + p10 + p11).normalized()
			var q00: Vector3 = center + p00 * radii
			var q01: Vector3 = center + p01 * radii
			var q10: Vector3 = center + p10 * radii
			var q11: Vector3 = center + p11 * radii
			if r == 0:
				add_tri(key, q00, q10, q11, n)
			elif r == rings - 1:
				add_tri(key, q00, q01, q10, n)
			else:
				add_quad(key, q00, q01, q11, q10, n)


func _sph(v: float, h: float) -> Vector3:
	return Vector3(sin(v) * cos(h), cos(v), sin(v) * sin(h))


## Pyramide mit quadratischer Grundfläche.
func add_pyramid(key: String, base_center: Vector3, base_size: float, height: float, basis: Basis = Basis.IDENTITY) -> void:
	var hs: float = base_size * 0.5
	var ax: Vector3 = basis.x.normalized() * hs
	var az: Vector3 = basis.z.normalized() * hs
	var apex: Vector3 = base_center + basis.y.normalized() * height
	var c: Array[Vector3] = [base_center - ax - az, base_center + ax - az, base_center + ax + az, base_center - ax + az]
	for i: int in 4:
		var a: Vector3 = c[i]
		var b: Vector3 = c[(i + 1) % 4]
		var mid: Vector3 = (a + b) * 0.5
		var out: Vector3 = (mid - base_center).normalized()
		var n: Vector3 = (out * height + basis.y.normalized() * hs).normalized()
		add_tri(key, a, b, apex, n, Vector2(0, 0), Vector2(base_size, 0), Vector2(base_size * 0.5, height))


## Waagerechtes Polygon (Vielleck) in Höhe y, trianguliert, Normale nach oben.
func add_polygon_xz(key: String, poly: PackedVector2Array, y: float, uv_scale: float = 1.0, up: bool = true) -> void:
	var idx: PackedInt32Array = Geometry2D.triangulate_polygon(poly)
	var n: Vector3 = Vector3.UP if up else Vector3.DOWN
	for i: int in range(0, idx.size(), 3):
		var a: Vector2 = poly[idx[i]]
		var b: Vector2 = poly[idx[i + 1]]
		var c: Vector2 = poly[idx[i + 2]]
		add_tri(key, Vector3(a.x, y, a.y), Vector3(b.x, y, b.y), Vector3(c.x, y, c.y), n,
			a * uv_scale, b * uv_scale, c * uv_scale)


## Senkrechte Wand entlang eines Polygonrands von y0 bis y1 (Normale nach außen bei CCW-Polygon in XZ).
func add_polygon_walls(key: String, poly: PackedVector2Array, y0: float, y1: float) -> void:
	var cnt: int = poly.size()
	var area: float = PolyUtil.signed_area(poly)
	for i: int in cnt:
		var a: Vector2 = poly[i]
		var b: Vector2 = poly[(i + 1) % cnt]
		var d: Vector2 = (b - a)
		if d.length() < 0.001:
			continue
		var out2: Vector2 = Vector2(d.y, -d.x).normalized()
		if area < 0.0:
			out2 = -out2
		var n: Vector3 = Vector3(out2.x, 0, out2.y)
		add_quad(key, Vector3(a.x, y0, a.y), Vector3(b.x, y0, b.y), Vector3(b.x, y1, b.y), Vector3(a.x, y1, a.y), n,
			Vector2(0, y0), Vector2(d.length(), y0), Vector2(d.length(), y1), Vector2(0, y1))


func commit(existing: ArrayMesh = null) -> ArrayMesh:
	var mesh: ArrayMesh = existing if existing != null else ArrayMesh.new()
	var keys: Array = _tools.keys()
	keys.sort()
	for key: String in keys:
		if int(_counts[key]) == 0:
			continue
		var st: SurfaceTool = _tools[key]
		st.index()
		st.commit(mesh)
		var surf: int = mesh.get_surface_count() - 1
		if _materials.has(key):
			mesh.surface_set_material(surf, _materials[key])
	return mesh
