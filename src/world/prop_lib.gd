class_name PropLib
extends RefCounted
## Bibliothek für Stadtmobiliar und Vegetation (eigene, prozedurale Modelle): Laterne, Laub-, Pappel- und
## Nadelbaum, Bank, Mülleimer, Fahrrad, Poller, Litfaßsäule. Platzierung erfolgt über die Weltdaten (SectorBuilder).

const SHOP_NAMES: Array[String] = [
	"Schuhhaus Sohle", "Café Fächerblick", "Optik Weitblick", "Buchladen Seitenwind", "Drogerie Glanz",
	"Mode Laufsteg", "Uhren Zeitlos", "Spielwaren Kreisel", "Blumen Stängel", "Metzgerei Wurzel",
	"Eiscafé Kugelrund", "Hut & Haube", "Brillen Scharf", "Teeladen Aufguss", "Radhaus Speiche",
	"Feinkost Gaumen", "Parfümerie Duftnote", "Schreibwaren Tinte", "Juwelier Funkel", "Döner Eck 7",
]


static func multimesh(parent: Node3D, n: String, mesh: Mesh, xfs: Array[Transform3D], vis_end: float) -> void:
	if xfs.is_empty():
		return
	var mm := MultiMesh.new()
	mm.transform_format = MultiMesh.TRANSFORM_3D
	mm.mesh = mesh
	mm.instance_count = xfs.size()
	for i: int in xfs.size():
		mm.set_instance_transform(i, xfs[i])
	var mmi := MultiMeshInstance3D.new()
	mmi.name = n
	mmi.multimesh = mm
	if vis_end > 0.0:
		mmi.visibility_range_end = vis_end
		mmi.visibility_range_end_margin = 30.0
		mmi.visibility_range_fade_mode = GeometryInstance3D.VISIBILITY_RANGE_FADE_SELF
	parent.add_child(mmi)


static func conifer_mesh() -> ArrayMesh:
	var kit := MeshKit.new()
	kit.set_material("v", CityMaterials.get_mat("vertex"))
	kit.color = Color(0.3, 0.22, 0.16)
	kit.add_cylinder("v", Vector3.ZERO, 0.22, 0.14, 4.0, 6)
	for i: int in 3:
		kit.color = Color(0.13, 0.26 + float(i) * 0.03, 0.16)
		kit.add_cylinder("v", Vector3(0, 3.0 + float(i) * 2.6, 0), 2.6 - float(i) * 0.7, 0.2, 4.2 - float(i) * 0.6, 7)
	return kit.commit()


static func lamp_mesh() -> ArrayMesh:
	var kit := MeshKit.new()
	kit.set_material("v", CityMaterials.get_mat("vertex_metal"))
	kit.set_material("g", CityMaterials.get_mat("lamp_glow"))
	kit.color = Color(0.16, 0.2, 0.19)
	kit.add_cylinder("v", Vector3(0, 0, 0), 0.13, 0.09, 0.5, 8)
	kit.add_cylinder("v", Vector3(0, 0.5, 0), 0.08, 0.06, 5.0, 8)
	kit.add_box("v", Vector3(0.55, 5.45, 0), Vector3(1.2, 0.08, 0.08))
	kit.add_box("v", Vector3(1.1, 5.35, 0), Vector3(0.5, 0.18, 0.34))
	kit.color = Color.WHITE
	kit.add_box("g", Vector3(1.1, 5.23, 0), Vector3(0.4, 0.06, 0.26))
	return kit.commit()


static func tree_mesh(tall: bool) -> ArrayMesh:
	var kit := MeshKit.new()
	kit.set_material("v", CityMaterials.get_mat("vertex"))
	kit.color = Color(0.33, 0.24, 0.17)
	if tall:
		kit.add_cylinder("v", Vector3.ZERO, 0.24, 0.16, 5.0, 7)
		kit.color = Color(0.2, 0.33, 0.14)
		kit.add_sphere("v", Vector3(0, 7.0, 0), Vector3(1.9, 4.2, 1.9), 5, 7)
		kit.color = Color(0.24, 0.38, 0.16)
		kit.add_sphere("v", Vector3(0.4, 9.5, 0.2), Vector3(1.4, 2.8, 1.4), 4, 7)
	else:
		kit.add_cylinder("v", Vector3.ZERO, 0.26, 0.2, 3.4, 7)
		kit.color = Color(0.25, 0.4, 0.17)
		kit.add_sphere("v", Vector3(0, 5.2, 0), Vector3(3.0, 2.5, 3.0), 5, 8)
		kit.color = Color(0.3, 0.45, 0.2)
		kit.add_sphere("v", Vector3(1.2, 6.0, 0.6), Vector3(2.0, 1.8, 2.0), 4, 7)
		kit.color = Color(0.21, 0.35, 0.15)
		kit.add_sphere("v", Vector3(-1.0, 5.8, -0.8), Vector3(2.1, 1.9, 2.1), 4, 7)
	return kit.commit()


static func bench(kit: MeshKit, pos: Vector3, yaw: float) -> void:
	var b := Basis(Vector3.UP, yaw)
	kit.color = Color(0.45, 0.3, 0.18)
	kit.add_box("vertex", pos + b * Vector3(0, 0.45, 0), Vector3(1.8, 0.07, 0.45), b)
	kit.add_box("vertex", pos + b * Vector3(0, 0.8, 0.22), Vector3(1.8, 0.35, 0.06), b)
	kit.color = Color(0.15, 0.16, 0.17)
	for sx: float in [-0.75, 0.75]:
		kit.add_box("vertex_metal", pos + b * Vector3(sx, 0.22, 0), Vector3(0.06, 0.45, 0.45), b)
	kit.color = Color.WHITE


static func bike(kit: MeshKit, pos: Vector3, yaw: float, col: Color) -> void:
	var b := Basis(Vector3.UP, yaw)
	var wheel_basis := b * Basis(Vector3(0, 0, 1), PI * 0.5)
	kit.color = Color(0.08, 0.08, 0.08)
	for sz: float in [-0.52, 0.52]:
		kit.add_cylinder("vertex", pos + b * Vector3(-0.02, 0.34, sz), 0.34, 0.34, 0.04, 10, wheel_basis, false)
	kit.color = col
	kit.add_box("vertex_metal", pos + b * Vector3(0, 0.55, 0), Vector3(0.04, 0.05, 0.9), b)
	kit.add_box("vertex_metal", pos + b * Vector3(0, 0.62, 0.1), Vector3(0.04, 0.5, 0.05), b * Basis(Vector3(1, 0, 0), 0.4))
	kit.color = Color(0.1, 0.1, 0.1)
	kit.add_box("vertex", pos + b * Vector3(0, 0.88, 0.25), Vector3(0.12, 0.05, 0.22), b)
	kit.add_box("vertex_metal", pos + b * Vector3(0, 0.95, -0.45), Vector3(0.5, 0.03, 0.03), b)
	kit.color = Color.WHITE


static func litfass(kit: MeshKit, body: StaticBody3D, pos: Vector3, seed: int) -> void:
	kit.color = Color(0.2, 0.25, 0.22)
	kit.add_cylinder("vertex", pos, 0.7, 0.7, 0.3, 12)
	var posters: Array[Color] = [Color(0.85, 0.3, 0.2), Color(0.95, 0.8, 0.3), Color(0.25, 0.45, 0.7), Color(0.9, 0.9, 0.85), Color(0.4, 0.6, 0.3)]
	for i: int in 3:
		kit.color = posters[(seed + i) % posters.size()]
		kit.add_cylinder("vertex", pos + Vector3(0, 0.3 + float(i) * 0.9, 0), 0.62, 0.62, 0.9, 12, Basis.IDENTITY, false)
	kit.color = Color(0.2, 0.25, 0.22)
	kit.add_cylinder("vertex", pos + Vector3(0, 3.0, 0), 0.72, 0.4, 0.35, 12)
	kit.add_sphere("vertex", pos + Vector3(0, 3.45, 0), Vector3(0.18, 0.18, 0.18), 3, 6)
	kit.color = Color.WHITE
	


static func bollard(kit: MeshKit, pos: Vector3) -> void:
	kit.color = Color(0.25, 0.27, 0.28)
	kit.add_cylinder("vertex_metal", pos, 0.1, 0.09, 0.85, 8)
	kit.color = Color(0.85, 0.85, 0.82)
	kit.add_cylinder("vertex", pos + Vector3(0, 0.62, 0), 0.105, 0.105, 0.08, 8, Basis.IDENTITY, false)
	kit.color = Color.WHITE


static func bin(kit: MeshKit, pos: Vector3) -> void:
	kit.color = Color(0.9, 0.45, 0.1)
	kit.add_cylinder("vertex", pos, 0.25, 0.22, 0.85, 8)
	kit.color = Color.WHITE
