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
	if world_mode == "test":
		var tg := TestGround.new()
		tg.name = "World"
		add_child(tg)
		tg.build()
		world = tg
	else:
		var cw := CityWorld.new()
		cw.name = "World"
		add_child(cw)
		cw.build()
		world = cw


func get_city() -> CityWorld:
	return world as CityWorld


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
			var v: Vehicle = spawn_vehicle(str(pv.spec), pv.position, float(pv.yaw), pv.get("color", Color(-1, 0, 0)),
				int(pv.get("ownership", Vehicle.Ownership.PUBLIC)), str(pv.get("livery", "")))
			v.locked = bool(pv.get("locked", false))


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
	if world_mode != "test":
		_register_city_stations(tour)
		return
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


func _cam_station(tour: ScreenshotTour, station_name: String, player_pos: Vector3, yaw_deg: float, pitch: float, frames: int = 40) -> void:
	tour.add_station(station_name, func() -> void:
		if player.is_in_vehicle():
			player.force_leave_vehicle(player_pos)
		player.global_position = player_pos
		player.velocity = Vector3.ZERO
		camera_rig.yaw = deg_to_rad(yaw_deg)
		camera_rig.pitch = pitch
		camera_rig.snap()
	, frames)


func _register_city_stations(tour: ScreenshotTour) -> void:
	var cw: CityWorld = get_city()
	var y: float = cw.slab_h + 0.05
	_cam_station(tour, "start_marktplatz_blick_schloss", cw.get_spawn().origin, 0.0, -0.12)
	_cam_station(tour, "marktplatz_pyramide", Vector3(0, y, 385), 0.0, -0.05)
	_cam_station(tour, "rathaus", Vector3(-8, y, 416), 90.0, -0.08)
	_cam_station(tour, "stadtkirche", Vector3(8, y, 416), 270.0, -0.08)
	_cam_station(tour, "schlossplatz", Vector3(0, y, 150), 0.0, -0.08)
	_cam_station(tour, "kaiserstrasse", Vector3(-150, y, 330), 90.0, -0.08)
	_cam_station(tour, "faecherstrasse_zirkel", Vector3(-110, 0.05, 258), 146.0, -0.1)
	_cam_station(tour, "europaplatz", Vector3(-430, y, 345), 270.0, -0.08)
	_cam_station(tour, "durlacher_tor", Vector3(575, 0.05, 345), 70.0, -0.1)
	_cam_station(tour, "kriegsstrasse", Vector3(60, 0.05, 646), 90.0, -0.06)
	tour.add_station("luftbild_faecher", func() -> void:
		player.global_position = Vector3(0, y, 250)
		camera_rig.yaw = 0.0
		camera_rig.pitch = -1.2
		camera_rig._target_distance = 60.0
		camera_rig.snap()
	, 40)
