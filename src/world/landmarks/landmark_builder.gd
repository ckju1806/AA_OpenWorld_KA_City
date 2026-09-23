class_name LandmarkBuilder
extends RefCounted
## Individuell modellierte Orientierungspunkte (vereinfachte, eigene Interpretationen):
## Schloss mit Turm und Flügeln, Pyramide, Rathaus, Stadtkirche, Säule, Brunnen, U-Strab-Zugänge,
## Torbogen-Skulptur, Pavillon, Haltestelle.

const OCHRE: Color = Color(0.93, 0.8, 0.56)
const OCHRE_LIGHT: Color = Color(0.96, 0.9, 0.76)
const WHITE_STONE: Color = Color(0.93, 0.91, 0.86)
const SLATE: Color = Color(0.3, 0.33, 0.38)
const SANDSTONE: Color = Color(0.64, 0.36, 0.29)
const SANDSTONE_LIGHT: Color = Color(0.86, 0.74, 0.62)
const COPPER: Color = Color(0.36, 0.55, 0.47)


static func build(root: Node3D, g: CityGraph) -> void:
	var slab_h: float = float(g.layout.get("slab_height", 0.12))
	var container := Node3D.new()
	container.name = "Landmarken"
	root.add_child(container)
	for lm: Variant in g.layout.get("landmarks", []):
		var d: Dictionary = lm
		var pos: Vector2 = Vector2(float(d.pos[0]), float(d.pos[1]))
		var rot: float = deg_to_rad(float(d.get("rot", 0.0)))
		var kit := MeshKit.new()
		CityMaterials.apply(kit, ["facade", "roof", "stone", "flat", "water", "glass_dark", "lamp_glow"] as Array[String])
		var body := StaticBody3D.new()
		body.name = "LM_" + str(d.id)
		body.collision_layer = Layers.WORLD
		var node := Node3D.new()
		node.name = str(d.id)
		match str(d.type):
			"schloss":
				_schloss(kit, body, pos, slab_h)
			"pyramide":
				_pyramide(kit, body, pos, slab_h)
			"rathaus":
				_rathaus(kit, body, pos, slab_h)
			"stadtkirche":
				_stadtkirche(kit, body, pos, slab_h)
			"saeule":
				_saeule(kit, body, pos, slab_h)
			"brunnen":
				_brunnen(kit, body, pos, slab_h)
			"ustrab":
				_ustrab(kit, body, node, pos, rot, slab_h)
			"torbogen":
				_torbogen(kit, body, node, pos, rot, slab_h)
			"pavillon":
				_pavillon(kit, body, node, pos, slab_h)
			"haltestelle":
				_haltestelle(kit, body, node, pos, rot, slab_h)
		var mi := MeshInstance3D.new()
		mi.mesh = kit.commit()
		node.add_child(mi)
		container.add_child(node)
		container.add_child(body)


static func _box_col(body: StaticBody3D, center: Vector3, size: Vector3, yaw: float = 0.0) -> void:
	var cs := CollisionShape3D.new()
	var bs := BoxShape3D.new()
	bs.size = size
	cs.shape = bs
	cs.transform = Transform3D(Basis(Vector3.UP, yaw), center)
	body.add_child(cs)


static func _cyl_col(body: StaticBody3D, base: Vector3, radius: float, height: float) -> void:
	var cs := CollisionShape3D.new()
	var c := CylinderShape3D.new()
	c.radius = radius
	c.height = height
	cs.shape = c
	cs.position = base + Vector3(0, height * 0.5, 0)
	body.add_child(cs)


# ------------------------------------------------------------------ Schloss

static func _schloss(kit: MeshKit, body: StaticBody3D, p: Vector2, y0: float) -> void:
	var main_c: Vector2 = p + Vector2(0, 12)
	var main_size: Vector2 = Vector2(72, 20)
	ArchKit.block(kit, main_c, main_size, 0.0, y0, y0 + 17.0, OCHRE, 0.31, ArchKit.STYLE_PALACE, 5.0)
	ArchKit.mansard_roof(kit, main_c, main_size, 0.0, y0 + 17.0, 4.2, 2.0, 1.3, SLATE)
	_box_col(body, Vector3(main_c.x, y0 + 11, main_c.y), Vector3(main_size.x, 22, main_size.y))
	# Mittelrisalit mit Säulenportikus und Dreiecksgiebel
	var ris: Vector2 = p + Vector2(0, 24.5)
	ArchKit.block(kit, ris, Vector2(24, 5), 0.0, y0, y0 + 19.0, OCHRE_LIGHT, 0.52, ArchKit.STYLE_PALACE, 5.0)
	for i: int in 6:
		var x: float = -9.0 + float(i) * 3.6
		ArchKit.column(kit, Vector3(p.x + x, y0, p.y + 29.0), 0.6, 13.0, WHITE_STONE)
		_cyl_col(body, Vector3(p.x + x, y0, p.y + 29.0), 0.6, 13.0)
	kit.color = WHITE_STONE
	kit.add_box("stone", Vector3(p.x, y0 + 13.7, p.y + 28.2), Vector3(24.0, 1.4, 4.2))
	kit.color = Color.WHITE
	ArchKit.pediment(kit, Vector3(p.x - 12.5, y0 + 14.4, p.y + 28.2), Vector3(p.x + 12.5, y0 + 14.4, p.y + 28.2), 4.5, 2.0, WHITE_STONE)
	_box_col(body, Vector3(ris.x, y0 + 9.5, ris.y), Vector3(24, 19, 5))
	# Seitenflügel entlang der Fächerstrahlen
	for side: float in [-1.0, 1.0]:
		var start: Vector2 = p + Vector2(side * 34.0, 14.0)
		var ang: float = deg_to_rad(side * 55.0)
		var dir: Vector2 = Vector2(sin(ang), cos(ang))
		var length: float = 92.0
		var yaw: float = atan2(-dir.y, dir.x)
		var center: Vector2 = start + dir * (length * 0.5)
		ArchKit.block(kit, center, Vector2(length, 16), yaw, y0, y0 + 15.0, OCHRE, 0.4 + side * 0.1, ArchKit.STYLE_PALACE, 5.0)
		ArchKit.mansard_roof(kit, center, Vector2(length, 16), yaw, y0 + 15.0, 3.8, 1.6, 1.2, SLATE)
		_box_col(body, Vector3(center.x, y0 + 9.5, center.y), Vector3(length, 19, 16), yaw)
		var pav: Vector2 = start + dir * (length + 6.0)
		ArchKit.block(kit, pav, Vector2(14, 22), yaw, y0, y0 + 17.0, OCHRE_LIGHT, 0.6, ArchKit.STYLE_PALACE, 5.0)
		ArchKit.mansard_roof(kit, pav, Vector2(14, 22), yaw, y0 + 17.0, 4.0, 2.2, 1.2, SLATE)
		_box_col(body, Vector3(pav.x, y0 + 11, pav.y), Vector3(14, 22, 22), yaw)
	# Schlossturm (achteckig) mit Kuppel und Laterne – Mittelpunkt des Fächers
	var tc: Vector2 = p + Vector2(0, -3)
	var r: float = 7.5
	var oct: PackedVector2Array = PackedVector2Array()
	for i2: int in 8:
		var a: float = TAU * float(i2) / 8.0 + PI / 8.0
		oct.append(tc + Vector2(cos(a), sin(a)) * r)
	oct = PolyUtil.ensure_ccw(oct)
	var th: float = 43.0
	for i3: int in 8:
		ArchKit.wall(kit, oct[i3], oct[(i3 + 1) % 8], y0, y0 + th, OCHRE_LIGHT, 0.2, false, 0.0, ArchKit.STYLE_PALACE, 5.0)
	kit.color = WHITE_STONE
	kit.add_cylinder("stone", Vector3(tc.x, y0 + th, tc.y), r + 0.6, r + 0.6, 1.0, 8)
	kit.color = COPPER
	kit.add_sphere("stone", Vector3(tc.x, y0 + th + 1.0, tc.y), Vector3(r, 6.0, r), 5, 8)
	kit.color = OCHRE_LIGHT
	kit.add_cylinder("stone", Vector3(tc.x, y0 + th + 6.5, tc.y), 2.0, 2.0, 3.5, 8)
	kit.color = COPPER
	kit.add_sphere("stone", Vector3(tc.x, y0 + th + 10.0, tc.y), Vector3(2.2, 1.8, 2.2), 4, 8)
	kit.add_cylinder("stone", Vector3(tc.x, y0 + th + 11.5, tc.y), 0.35, 0.05, 4.0, 6)
	kit.color = Color.WHITE
	_cyl_col(body, Vector3(tc.x, y0, tc.y), r, th + 6.0)


# ------------------------------------------------------------------ Marktplatz

static func _pyramide(kit: MeshKit, body: StaticBody3D, p: Vector2, y0: float) -> void:
	kit.color = SANDSTONE.darkened(0.1)
	kit.add_box("stone", Vector3(p.x, y0 + 0.3, p.y), Vector3(8.2, 0.6, 8.2))
	kit.color = SANDSTONE
	kit.add_pyramid("stone", Vector3(p.x, y0 + 0.6, p.y), 6.4, 6.8)
	kit.color = Color.WHITE
	var cs := CollisionShape3D.new()
	var cps := ConvexPolygonShape3D.new()
	var pts: PackedVector3Array = PackedVector3Array()
	for s: Vector2 in [Vector2(-1, -1), Vector2(1, -1), Vector2(1, 1), Vector2(-1, 1)]:
		pts.append(Vector3(p.x + s.x * 4.1, y0, p.y + s.y * 4.1))
		pts.append(Vector3(p.x + s.x * 3.2, y0 + 0.6, p.y + s.y * 3.2))
	pts.append(Vector3(p.x, y0 + 7.4, p.y))
	cps.points = pts
	cs.shape = cps
	body.add_child(cs)


static func _rathaus(kit: MeshKit, body: StaticBody3D, p: Vector2, y0: float) -> void:
	# Klassizistischer Baukörper, Front nach Osten (zum Marktplatz)
	var c: Vector2 = p + Vector2(-2, 0)
	var size: Vector2 = Vector2(30, 60)
	ArchKit.block(kit, c, size, 0.0, y0, y0 + 15.5, SANDSTONE_LIGHT, 0.45, ArchKit.STYLE_PALACE, 5.0)
	ArchKit.mansard_roof(kit, c, size, 0.0, y0 + 15.5, 2.6, 1.0, 1.2, SLATE)
	_box_col(body, Vector3(c.x, y0 + 9, c.y), Vector3(size.x, 18, size.y))
	var front_x: float = c.x + size.x * 0.5
	for i: int in 4:
		var z: float = p.y - 7.5 + float(i) * 5.0
		ArchKit.column(kit, Vector3(front_x + 3.0, y0, z), 0.55, 11.0, WHITE_STONE)
		_cyl_col(body, Vector3(front_x + 3.0, y0, z), 0.55, 11.0)
	kit.color = WHITE_STONE
	kit.add_box("stone", Vector3(front_x + 2.0, y0 + 11.6, p.y), Vector3(4.4, 1.2, 20.0))
	kit.color = Color.WHITE
	ArchKit.pediment(kit, Vector3(front_x + 2.0, y0 + 12.2, p.y - 10.0), Vector3(front_x + 2.0, y0 + 12.2, p.y + 10.0), 3.2, 2.1, WHITE_STONE)
	# Rathausturm
	var tc: Vector2 = c + Vector2(-8, 0)
	ArchKit.block(kit, tc, Vector2(7, 7), 0.0, y0 + 15.5, y0 + 31.0, SANDSTONE_LIGHT, 0.7, ArchKit.STYLE_PALACE, 5.0)
	kit.color = COPPER
	kit.add_sphere("stone", Vector3(tc.x, y0 + 31.0, tc.y), Vector3(3.6, 3.0, 3.6), 4, 8)
	kit.add_cylinder("stone", Vector3(tc.x, y0 + 33.5, tc.y), 0.2, 0.05, 2.5, 6)
	kit.color = Color.WHITE
	var lbl := Label3D.new()
	lbl.text = "RATHAUS"
	lbl.font_size = 72
	lbl.pixel_size = 0.012
	lbl.modulate = Color(0.25, 0.2, 0.18)
	lbl.position = Vector3(front_x + 0.05, y0 + 13.5, p.y)
	lbl.rotation = Vector3(0, PI * 0.5, 0)
	body.add_child(lbl)


static func _stadtkirche(kit: MeshKit, body: StaticBody3D, p: Vector2, y0: float) -> void:
	# Kirchenschiff, Portikus mit sechs Säulen nach Westen (zum Marktplatz), Turm darüber
	var c: Vector2 = p + Vector2(2, 0)
	var size: Vector2 = Vector2(30, 52)
	ArchKit.block(kit, c, size, 0.0, y0, y0 + 16.0, SANDSTONE_LIGHT, 0.55, ArchKit.STYLE_PALACE, 7.0)
	ArchKit.mansard_roof(kit, c, size, 0.0, y0 + 16.0, 4.5, 0.8, 1.0, SLATE)
	_box_col(body, Vector3(c.x, y0 + 10, c.y), Vector3(size.x, 20, size.y))
	var front_x: float = c.x - size.x * 0.5
	for i: int in 6:
		var z: float = p.y - 12.5 + float(i) * 5.0
		ArchKit.column(kit, Vector3(front_x - 3.5, y0, z), 0.7, 14.0, WHITE_STONE)
		_cyl_col(body, Vector3(front_x - 3.5, y0, z), 0.7, 14.0)
	kit.color = WHITE_STONE
	kit.add_box("stone", Vector3(front_x - 2.4, y0 + 14.7, p.y), Vector3(5.0, 1.4, 29.0))
	kit.color = Color.WHITE
	ArchKit.pediment(kit, Vector3(front_x - 2.4, y0 + 15.4, p.y - 14.5), Vector3(front_x - 2.4, y0 + 15.4, p.y + 14.5), 4.6, 2.4, WHITE_STONE)
	# Turm: quadratischer Schaft, Glockengeschoss, Spitzhelm
	var tc: Vector2 = Vector2(front_x + 6.0, p.y)
	ArchKit.block(kit, tc, Vector2(9, 9), 0.0, y0 + 16.0, y0 + 36.0, SANDSTONE_LIGHT, 0.65, ArchKit.STYLE_PALACE, 6.0)
	ArchKit.block(kit, tc, Vector2(7, 7), 0.0, y0 + 36.0, y0 + 42.0, WHITE_STONE, 0.66, ArchKit.STYLE_PALACE, 6.0)
	kit.color = COPPER
	kit.add_pyramid("stone", Vector3(tc.x, y0 + 42.0, tc.y), 7.4, 11.0)
	kit.add_cylinder("stone", Vector3(tc.x, y0 + 53.0, tc.y), 0.15, 0.05, 2.2, 6)
	kit.color = Color.WHITE
	_box_col(body, Vector3(tc.x, y0 + 29, tc.y), Vector3(9, 26, 9))


# ------------------------------------------------------------------ Kleinere Landmarken

static func _saeule(kit: MeshKit, body: StaticBody3D, p: Vector2, y0: float) -> void:
	kit.color = SANDSTONE.darkened(0.08)
	kit.add_box("stone", Vector3(p.x, y0 + 0.4, p.y), Vector3(4.0, 0.8, 4.0))
	kit.add_box("stone", Vector3(p.x, y0 + 2.0, p.y), Vector3(2.4, 2.4, 2.4))
	kit.color = SANDSTONE
	kit.add_cylinder("stone", Vector3(p.x, y0 + 3.2, p.y), 0.95, 0.6, 12.0, 4, Basis(Vector3.UP, PI / 4.0))
	kit.add_pyramid("stone", Vector3(p.x, y0 + 15.2, p.y), 0.85, 1.4)
	kit.color = Color.WHITE
	_box_col(body, Vector3(p.x, y0 + 1.6, p.y), Vector3(4.0, 3.2, 4.0))
	_cyl_col(body, Vector3(p.x, y0 + 3.2, p.y), 0.9, 12.0)


static func _brunnen(kit: MeshKit, body: StaticBody3D, p: Vector2, y0: float) -> void:
	kit.color = Color(0.7, 0.68, 0.64)
	kit.add_cylinder("stone", Vector3(p.x, y0, p.y), 4.6, 4.6, 0.6, 16)
	kit.color = Color.WHITE
	kit.add_cylinder("water", Vector3(p.x, y0 + 0.05, p.y), 4.2, 4.2, 0.5, 16)
	kit.color = Color(0.4, 0.42, 0.44)
	kit.add_cylinder("stone", Vector3(p.x, y0 + 0.5, p.y), 0.5, 0.35, 2.2, 8)
	kit.add_sphere("stone", Vector3(p.x, y0 + 2.9, p.y), Vector3(0.9, 0.6, 0.9), 4, 8)
	kit.color = Color.WHITE
	_cyl_col(body, Vector3(p.x, y0, p.y), 4.6, 0.6)


static func _ustrab(kit: MeshKit, body: StaticBody3D, node: Node3D, p: Vector2, rot: float, y0: float) -> void:
	var basis := Basis(Vector3.UP, rot)
	kit.color = Color(0.25, 0.27, 0.3)
	kit.add_box("stone", Vector3(p.x, y0 + 1.4, p.y), Vector3(7.0, 0.15, 3.2), basis)
	kit.add_box("stone", Vector3(p.x, y0 + 2.9, p.y), Vector3(7.4, 0.25, 3.6), basis)
	for sx: float in [-3.4, 3.4]:
		kit.add_box("stone", Vector3(p.x, y0, p.y) + basis * Vector3(sx, 1.45, 0), Vector3(0.15, 2.9, 3.2), basis)
	kit.color = Color.WHITE
	kit.add_box("glass_dark", Vector3(p.x, y0, p.y) + basis * Vector3(0, 1.45, 1.55), Vector3(6.6, 2.7, 0.06), basis)
	kit.color = Color(0.12, 0.12, 0.13)
	kit.add_box("stone", Vector3(p.x, y0 + 0.02, p.y) + basis * Vector3(0, 0, -0.2), Vector3(5.8, 0.04, 2.4), basis)
	kit.color = Color.WHITE
	_box_col(body, Vector3(p.x, y0 + 1.5, p.y), Vector3(7.4, 3.0, 3.6), rot)
	var sign := Label3D.new()
	sign.text = "U"
	sign.font_size = 160
	sign.pixel_size = 0.006
	sign.modulate = Color(1, 1, 1)
	sign.outline_size = 36
	sign.outline_modulate = Color(0.1, 0.3, 0.75)
	sign.billboard = BaseMaterial3D.BILLBOARD_FIXED_Y
	sign.position = Vector3(p.x, y0 + 3.9, p.y)
	node.add_child(sign)


static func _torbogen(kit: MeshKit, body: StaticBody3D, node: Node3D, p: Vector2, rot: float, y0: float) -> void:
	var basis := Basis(Vector3.UP, rot)
	var c: Vector3 = Vector3(p.x, y0, p.y)
	kit.color = SANDSTONE
	for sx: float in [-3.6, 3.6]:
		kit.add_box("stone", c + basis * Vector3(sx, 3.5, 0), Vector3(1.6, 7.0, 1.6), basis)
		_box_col(body, c + basis * Vector3(sx, 3.5, 0), Vector3(1.6, 7.0, 1.6), rot)
	kit.add_box("stone", c + basis * Vector3(0, 7.6, 0), Vector3(9.6, 1.4, 1.8), basis)
	kit.color = SANDSTONE.darkened(0.2)
	kit.add_box("stone", c + basis * Vector3(0, 8.6, 0), Vector3(6.0, 0.6, 1.4), basis)
	kit.color = Color.WHITE
	var lbl := Label3D.new()
	lbl.text = "Durlacher Tor"
	lbl.font_size = 64
	lbl.pixel_size = 0.01
	lbl.modulate = Color(0.95, 0.9, 0.8)
	lbl.outline_size = 10
	lbl.outline_modulate = Color(0.2, 0.1, 0.08)
	lbl.position = c + basis * Vector3(0, 7.6, 0.95)
	lbl.rotation = Vector3(0, rot, 0)
	node.add_child(lbl)


static func _pavillon(kit: MeshKit, body: StaticBody3D, node: Node3D, p: Vector2, y0: float) -> void:
	var c: Vector3 = Vector3(p.x, y0, p.y)
	kit.color = Color(0.85, 0.86, 0.88)
	kit.add_box("stone", c + Vector3(0, 4.1, 0), Vector3(16, 0.4, 10))
	for s: Vector2 in [Vector2(-7.6, -4.6), Vector2(7.6, -4.6), Vector2(7.6, 4.6), Vector2(-7.6, 4.6)]:
		kit.add_box("stone", c + Vector3(s.x, 2.0, s.y), Vector3(0.3, 4.0, 0.3))
		_box_col(body, c + Vector3(s.x, 2.0, s.y), Vector3(0.3, 4.0, 0.3))
	kit.color = Color.WHITE
	kit.add_box("glass_dark", c + Vector3(0, 1.9, 0), Vector3(12, 3.6, 6))
	_box_col(body, c + Vector3(0, 1.9, 0), Vector3(12, 3.6, 6))
	var lbl := Label3D.new()
	lbl.text = "Ettlinger Tor"
	lbl.font_size = 72
	lbl.pixel_size = 0.01
	lbl.modulate = Color(1, 0.95, 0.85)
	lbl.outline_size = 10
	lbl.outline_modulate = Color(0.1, 0.1, 0.12)
	lbl.position = c + Vector3(0, 4.9, 5.05)
	node.add_child(lbl)


static func _haltestelle(kit: MeshKit, body: StaticBody3D, node: Node3D, p: Vector2, rot: float, y0: float) -> void:
	var basis := Basis(Vector3.UP, rot)
	var c: Vector3 = Vector3(p.x, y0, p.y)
	kit.color = Color(0.3, 0.32, 0.35)
	kit.add_box("stone", c + basis * Vector3(0, 2.6, 0), Vector3(8.0, 0.15, 1.8), basis)
	for sx: float in [-3.8, 3.8]:
		kit.add_box("stone", c + basis * Vector3(sx, 1.3, -0.8), Vector3(0.12, 2.6, 0.12), basis)
	kit.color = Color.WHITE
	kit.add_box("glass_dark", c + basis * Vector3(0, 1.4, -0.85), Vector3(7.6, 2.2, 0.05), basis)
	kit.color = Color(0.45, 0.33, 0.22)
	kit.add_box("stone", c + basis * Vector3(0, 0.45, -0.5), Vector3(4.0, 0.08, 0.45), basis)
	kit.color = Color(0.9, 0.75, 0.1)
	kit.add_cylinder("stone", c + basis * Vector3(4.6, 0, 0.3), 0.06, 0.06, 3.0, 6)
	kit.color = Color.WHITE
	_box_col(body, c + basis * Vector3(0, 1.3, -0.85), Vector3(8.0, 2.6, 0.2), rot)
	var lbl := Label3D.new()
	lbl.text = "H  Haltestelle"
	lbl.font_size = 48
	lbl.pixel_size = 0.008
	lbl.modulate = Color(0.1, 0.4, 0.1)
	lbl.outline_size = 8
	lbl.outline_modulate = Color(1, 0.9, 0.2)
	lbl.billboard = BaseMaterial3D.BILLBOARD_FIXED_Y
	lbl.position = c + basis * Vector3(4.6, 3.2, 0.3)
	node.add_child(lbl)
