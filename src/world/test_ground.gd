class_name TestGround
extends Node3D
## Kleines Testgelände (Teststraße, Bordstein, Rampe, Wände) für Entwicklung und automatisierte Tests.

var spawn_position: Vector3 = Vector3(0, 0.1, 6)


func build() -> void:
	var body := StaticBody3D.new()
	body.name = "Ground"
	body.collision_layer = Layers.WORLD
	body.collision_mask = 0
	add_child(body)
	var kit := MeshKit.new()
	kit.set_material("asphalt", MatLib.solid(Color(0.23, 0.23, 0.25), 0.95))
	kit.set_material("walk", MatLib.solid(Color(0.55, 0.52, 0.48), 0.9))
	kit.set_material("wall", MatLib.solid(Color(0.75, 0.62, 0.48), 0.9))
	kit.set_material("mark", MatLib.solid(Color(0.92, 0.92, 0.88), 0.7))
	# Boden
	_box(body, kit, "asphalt", Vector3(0, -0.5, 0), Vector3(600, 1.0, 600))
	# Mittelmarkierung der Teststraße (in Z-Richtung)
	for i: int in range(-40, 40):
		kit.add_box("mark", Vector3(0, 0.005, float(i) * 6.0), Vector3(0.15, 0.01, 3.0))
	# Gehweg mit Bordstein (0,12 m hoch)
	_box(body, kit, "walk", Vector3(9.5, 0.06, 0), Vector3(5.0, 0.12, 240))
	_box(body, kit, "walk", Vector3(-9.5, 0.06, 0), Vector3(5.0, 0.12, 240))
	# Wände (Häuserfronten)
	_box(body, kit, "wall", Vector3(14.5, 5.0, 0), Vector3(5.0, 10.0, 240))
	_box(body, kit, "wall", Vector3(-14.5, 5.0, 0), Vector3(5.0, 10.0, 240))
	# Rampe
	var ramp_basis: Basis = Basis(Vector3.RIGHT, deg_to_rad(-8.0))
	_box(body, kit, "walk", Vector3(40, 0.8, -40), Vector3(8.0, 0.4, 16.0), ramp_basis)
	# Hindernis-Block
	_box(body, kit, "wall", Vector3(40, 1.5, 20), Vector3(6.0, 3.0, 6.0))
	var mi := MeshInstance3D.new()
	mi.mesh = kit.commit()
	add_child(mi)
	_add_light()


func _box(body: StaticBody3D, kit: MeshKit, mat: String, center: Vector3, size: Vector3, basis: Basis = Basis.IDENTITY) -> void:
	kit.add_box(mat, center, size, basis)
	var cs := CollisionShape3D.new()
	var shape := BoxShape3D.new()
	shape.size = size
	cs.shape = shape
	cs.transform = Transform3D(basis, center)
	body.add_child(cs)


func _add_light() -> void:
	var sun := DirectionalLight3D.new()
	sun.rotation_degrees = Vector3(-40, 35, 0)
	sun.shadow_enabled = true
	add_child(sun)
	var env := WorldEnvironment.new()
	var e := Environment.new()
	e.background_mode = Environment.BG_SKY
	var sky := Sky.new()
	sky.sky_material = ProceduralSkyMaterial.new()
	e.sky = sky
	e.ambient_light_source = Environment.AMBIENT_SOURCE_SKY
	env.environment = e
	add_child(env)


## Geparkte Fahrzeuge auf der Teststraße (drei Typen).
func get_parked_vehicles() -> Array[Dictionary]:
	return [
		{"spec": "kompakt", "position": Vector3(3.0, 0, 0), "yaw": 0.0},
		{"spec": "sport", "position": Vector3(-3.0, 0, 12), "yaw": PI},
		{"spec": "transporter", "position": Vector3(3.0, 0, 22), "yaw": 0.0, "livery": "Fächerblitz Kurier"},
		{"spec": "polizei", "position": Vector3(-3.0, 0, 30), "yaw": PI, "ownership": Vehicle.Ownership.POLICE},
	]


func get_spawn() -> Transform3D:
	return Transform3D(Basis.IDENTITY, spawn_position)
