class_name Game
extends Node3D
## Spielszene: baut Welt, Spieler, Kamera, Oberfläche und Systeme auf und verbindet sie.
## world_mode: "city" (Karlsruhe) oder "test" (Testgelände für Tests/Entwicklung).

var world_mode: String = "city"
var world: Node3D = null
var player: Player = null
var camera_rig: PlayerCamera = null
var entities: Node3D = null      ## Fahrzeuge, Passanten usw.
var paused_by_menu: bool = false


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_PAUSABLE
	if App.has_arg("--world=test"):
		world_mode = "test"
	entities = Node3D.new()
	entities.name = "Entities"
	_build_world()
	add_child(entities)
	_spawn_player()
	_spawn_initial_vehicles()
	App.set_mouse_captured(true)
	if App.has_arg("--screenshot-tour"):
		var tour := ScreenshotTour.new()
		tour.game = self
		add_child(tour)


func _build_world() -> void:
	var tg := TestGround.new()
	tg.name = "World"
	add_child(tg)
	tg.build()
	world = tg


func get_spawn_transform() -> Transform3D:
	if world != null and world.has_method("get_spawn"):
		return world.call("get_spawn")
	return Transform3D(Basis.IDENTITY, Vector3(0, 1, 0))


func _spawn_player() -> void:
	camera_rig = PlayerCamera.new()
	camera_rig.name = "CameraRig"
	add_child(camera_rig)
	player = Player.new()
	player.name = "Player"
	player.camera_rig = camera_rig
	var t: Transform3D = get_spawn_transform()
	entities.add_child(player)
	player.global_transform = t
	camera_rig.follow_player(player)
	camera_rig.yaw = player.rotation.y
	camera_rig.snap()


func request_pause() -> void:
	pass


func _spawn_initial_vehicles() -> void:
	if world != null and world.has_method("get_parked_vehicles"):
		for pv: Dictionary in world.call("get_parked_vehicles"):
			spawn_vehicle(str(pv.spec), pv.position, float(pv.yaw), pv.get("color", Color(-1, 0, 0)),
				int(pv.get("ownership", Vehicle.Ownership.PUBLIC)), str(pv.get("livery", "")))


## Erzeugt ein Fahrzeug in der Welt.
func spawn_vehicle(spec_id: String, pos: Vector3, yaw: float, color: Color = Color(-1, 0, 0),
		ownership: int = Vehicle.Ownership.PUBLIC, livery: String = "") -> Vehicle:
	var v := Vehicle.new()
	v.setup(VehicleSpec.get_spec(spec_id), color)
	v.ownership = ownership as Vehicle.Ownership
	v.livery_text = livery
	v.name = "Fahrzeug_%s_%d" % [spec_id, v.get_instance_id()]
	entities.add_child(v)
	v.global_transform = Transform3D(Basis(Vector3.UP, yaw), pos + Vector3.UP * 0.15)
	v.reset_physics_interpolation()
	return v


## Bergungspunkt: delegiert an die Welt (Straßennetz); Testgelände: aufrichten an Ort und Stelle.
func find_recovery_point(pos: Vector3, spec: VehicleSpec) -> Dictionary:
	if world != null and world.has_method("find_recovery_point"):
		return world.call("find_recovery_point", pos, spec)
	return {"ok": true, "position": Vector3(pos.x, 0.0, pos.z), "yaw": 0.0}


## Stationen der Screenshot-Tour (visuelle Kontrolle).
func register_screenshot_stations(tour: ScreenshotTour) -> void:
	tour.add_station("spieler_idle", func() -> void:
		camera_rig.yaw = 0.6
		camera_rig.pitch = -0.2
		camera_rig.snap()
	)
	tour.add_station("spieler_rennt", func() -> void:
		player.use_sim_input = true
		player.sim_move = Vector2(0, -1)
		player.sim_sprint = true
		camera_rig.yaw = PI * 0.5
		camera_rig.pitch = -0.1
	, 30)
	tour.add_station("kamera_an_wand", func() -> void:
		player.sim_move = Vector2.ZERO
		player.global_position = Vector3(11.3, 0.2, 0)
		camera_rig.yaw = PI * 0.5
		camera_rig.pitch = -0.15
		camera_rig.snap()
	)
	tour.add_station("fahrzeuge_uebersicht", func() -> void:
		player.global_position = Vector3(-6, 0.2, 8)
		camera_rig.yaw = -2.3
		camera_rig.pitch = -0.35
		camera_rig.snap()
	)
	tour.add_station("fahrzeug_fahrt", func() -> void:
		var vs: Array[Node] = get_tree().get_nodes_in_group("vehicles")
		if vs.is_empty():
			return
		var v: Vehicle = vs[0] as Vehicle
		player.global_position = v.global_position + Vector3(-2.0, 0.1, 0)
		v.enter(player)
		v.set_lights(true)
		var ap := Autopilot.new()
		ap.set_path(PackedVector3Array([Vector3(3, 0, -60), Vector3(3, 0, -160)]), 14.0)
		v.ai_controller = ap
		v.driver = Vehicle.Driver.AI
	, 150)
