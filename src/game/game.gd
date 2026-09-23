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
var hud: Hud = null
var missions: MissionSystem = null
var lights: TrafficLights = null
var traffic: TrafficManager = null
var peds: PedestrianManager = null
var police: PoliceManager = null
## Umgebungsleben (Verkehr/Passanten/Streife); Tests können es abschalten
var ambient_life: bool = true
var pause_menu: PauseMenu = null
var map_overlay: MapOverlay = null
var minimap: MapView = null
var dev_overlay: DevOverlay = null
## Autosave nach Missionsabschluss (Tests leiten den Speicherort um)
var autosave_enabled: bool = true
var _player_vehicles: Array[Vehicle] = []
var _respawn_t: float = -1.0
var _respawn_kind: String = "klinik"
## Letzter sicherer Fortsetzungspunkt (zu Fuß, am Boden, ohne Fahndung, ohne laufenden Auftrag)
var _safe_xf: Transform3D = Transform3D.IDENTITY
var _safe_t: float = 0.0


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
	hud = Hud.new()
	hud.name = "HUD"
	add_child(hud)
	hud.setup(self)
	if world is CityWorld:
		_setup_city_systems(world as CityWorld)
		missions = MissionSystem.new()
		missions.name = "Missionen"
		add_child(missions)
		missions.setup(self)
		_setup_maps(world as CityWorld)
	pause_menu = PauseMenu.new()
	pause_menu.name = "Pausenmenue"
	add_child(pause_menu)
	pause_menu.setup(self)
	dev_overlay = DevOverlay.new()
	dev_overlay.name = "Entwickleranzeige"
	add_child(dev_overlay)
	dev_overlay.setup(self)
	_safe_xf = player.global_transform
	player.died.connect(_on_player_died)
	App.set_mouse_captured(true)
	AudioManager.play_ambience("ambience_city")
	AudioManager.stop_music()
	_apply_pending_load()
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
	if pause_menu != null and not pause_menu.is_open() and not App.has_arg("--screenshot-tour"):
		if map_overlay != null and map_overlay.is_open():
			map_overlay.close()
		pause_menu.open()


func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed("pause"):
		request_pause()
		get_viewport().set_input_as_handled()
	elif event.is_action_pressed("map") and map_overlay != null and not player.is_dead:
		map_overlay.open()
		get_viewport().set_input_as_handled()


func _setup_maps(city: CityWorld) -> void:
	minimap = MapView.new()
	minimap.name = "Minikarte"
	minimap.set_anchors_preset(Control.PRESET_BOTTOM_LEFT)
	minimap.offset_left = 36
	minimap.offset_right = 36 + 300
	minimap.offset_bottom = -136
	minimap.offset_top = -136 - 300
	hud.root.add_child(minimap)
	minimap.setup(self, city.graph, false)
	map_overlay = MapOverlay.new()
	map_overlay.name = "Karte"
	add_child(map_overlay)
	map_overlay.setup(self, city.graph)


# ------------------------------------------------------------------ Speichern / Laden

## Spielerdaten für den Spielstand. Gespeichert wird immer ein sicherer Punkt:
## laufender Auftrag -> Auftraggeber (Auftrag beginnt neu), Fahndung -> letzter sicherer Punkt.
func make_player_save() -> Dictionary:
	var xf: Transform3D = _safe_xf
	var mission_id: String = ""
	if missions != null and missions.active != null:
		mission_id = missions.active.id
		xf = missions.giver_start_transform(mission_id)
	elif get_wanted_level() == 0 and not player.is_dead:
		if player.is_in_vehicle():
			var ex: Dictionary = (player.current_vehicle as Vehicle).find_exit_position()
			if ex.ok:
				xf = Transform3D(Basis(Vector3.UP, player.current_vehicle.global_rotation.y), ex.position)
		elif player.is_on_floor():
			xf = player.global_transform
	return {"position": SaveCodec.vec3_to_array(xf.origin), "yaw": xf.basis.get_euler().y,
		"health": player.health, "mission": mission_id}


## Speichert sofort. Rückgabe { ok, message }.
func save_now() -> Dictionary:
	if world_mode != "city":
		return {"ok": false, "message": "Auf dem Testgelände wird nicht gespeichert."}
	var ok: bool = SaveManager.save_game(make_player_save())
	var msg: String = "Spiel gespeichert." if ok else "Speichern fehlgeschlagen – siehe Protokoll."
	return {"ok": ok, "message": msg}


func _apply_pending_load() -> void:
	var data: Dictionary = App.pending_load
	var message: String = App.pending_message
	App.pending_load = {}
	App.pending_message = ""
	if data.is_empty() or world_mode != "city":
		if message != "":
			EventBus.notify.emit(message, "warnung")
		return
	var xf: Transform3D = get_spawn_transform()
	if data.has("position"):
		xf = Transform3D(Basis(Vector3.UP, float(data.get("yaw", 0.0))), data.position)
	var mission_id: String = str(data.get("mission", ""))
	if mission_id != "" and missions != null and missions.definitions.has(mission_id):
		xf = missions.giver_start_transform(mission_id)
		var title: String = (missions.definitions[mission_id] as MissionDefinition).title
		message = ("%s " % message if message != "" else "") + "Der Auftrag „%s“ lief beim Speichern – sprich erneut mit dem Auftraggeber." % title
	player.set_health(float(data.get("health", player.MAX_HEALTH)))
	_place_player(xf)
	# Kollisionsformen sind erst nach einem Physikschritt abfragbar
	await get_tree().physics_frame
	if not _position_is_free(xf.origin):
		_place_player(get_spawn_transform())
		message = ("%s " % message if message != "" else "") + "Gespeicherte Position war blockiert – Start am Marktplatz."
	if message != "":
		EventBus.notify.emit(message, "hinweis")
	else:
		EventBus.notify.emit("Spielstand geladen.", "erfolg")


func _place_player(xf: Transform3D) -> void:
	player.global_transform = xf
	player.velocity = Vector3.ZERO
	player.reset_physics_interpolation()
	camera_rig.yaw = xf.basis.get_euler().y
	camera_rig.snap()
	_safe_xf = xf


## Boden vorhanden und kein Hindernis in Körperhöhe?
func _position_is_free(pos: Vector3) -> bool:
	var space: PhysicsDirectSpaceState3D = get_world_3d().direct_space_state
	var ray := PhysicsRayQueryParameters3D.create(pos + Vector3.UP * 1.0, pos + Vector3.DOWN * 3.0, Layers.WORLD)
	if space.intersect_ray(ray).is_empty():
		return false
	var cap := CapsuleShape3D.new()
	cap.radius = 0.35
	cap.height = 1.6
	var q := PhysicsShapeQueryParameters3D.new()
	q.shape = cap
	q.transform = Transform3D(Basis.IDENTITY, pos + Vector3.UP * 1.0)
	q.collision_mask = Layers.WORLD | Layers.VEHICLE
	return space.intersect_shape(q, 1).is_empty()


func _update_safe_point(delta: float) -> void:
	_safe_t -= delta
	if _safe_t > 0.0:
		return
	_safe_t = 1.0
	if player.is_dead or player.is_in_vehicle() or not player.is_on_floor() or get_wanted_level() > 0:
		return
	if missions != null and missions.has_active():
		return
	_safe_xf = player.global_transform


func _setup_city_systems(city: CityWorld) -> void:
	if App.has_arg("--no-ambient"):
		ambient_life = false
	lights = TrafficLights.new()
	lights.name = "Ampeln"
	city.add_child(lights)
	lights.setup(city.graph, city.slab_h)
	traffic = TrafficManager.new()
	traffic.name = "Verkehr"
	add_child(traffic)
	traffic.setup(self, city.graph, lights)
	traffic.enabled = ambient_life
	peds = PedestrianManager.new()
	peds.name = "Passanten"
	add_child(peds)
	peds.setup(self, city)
	peds.enabled = ambient_life
	police = PoliceManager.new()
	police.name = "Polizei"
	add_child(police)
	police.setup(self, city.graph, lights)
	police.patrol_enabled = ambient_life
	EventBus.player_busted.connect(_on_busted)
	EventBus.player_entered_vehicle.connect(_on_player_entered_vehicle)


# ------------------------------------------------------------------ Schnittstellen für Missionen/Systeme

func get_wanted_level() -> int:
	return police.wanted_level() if police != null else 0


func set_wanted(level: int, reason: String, pos: Vector3) -> void:
	if police != null:
		police.set_wanted(level, reason, pos)


func reset_wanted() -> void:
	if police != null:
		police.reset_wanted()


func police_within(pos: Vector3, radius: float) -> bool:
	return police != null and police.police_within(pos, radius)


func police_can_see(pos: Vector3) -> bool:
	return police != null and police.police_can_see(pos)


func clear_area(pos: Vector3, radius: float) -> void:
	if traffic != null:
		traffic.clear_area(pos, radius)


func on_driver_ejected(v: Vehicle) -> void:
	if peds != null:
		var door: Vector3 = v.global_position + v.global_basis.x * -(v.spec.width * 0.5 + 1.0)
		peds.spawn_victim(door, player.global_position)


func _on_busted() -> void:
	EventBus.big_message.emit("FESTGENOMMEN", "Ab aufs Revier – das kostet Gebühren.", 3.0)
	player.input_enabled = false
	_respawn_kind = "revier"
	_respawn_t = 3.0


## Vom Spieler benutzte, zurückgelassene Fahrzeuge begrenzen (keine wachsende Objektmenge).
func _on_player_entered_vehicle(v: Node) -> void:
	var veh: Vehicle = v as Vehicle
	if veh == null or _player_vehicles.has(veh):
		return
	_player_vehicles.append(veh)
	var cam: Camera3D = get_viewport().get_camera_3d()
	while _player_vehicles.size() > 5:
		var old: Vehicle = _player_vehicles[0]
		_player_vehicles.remove_at(0)
		if not is_instance_valid(old) or old == player.current_vehicle or old.ownership == Vehicle.Ownership.MISSION:
			continue
		var visible: bool = cam != null and cam.is_position_in_frustum(old.global_position) and cam.global_position.distance_to(old.global_position) < 150.0
		if not visible and old.global_position.distance_to(player.global_position) > 60.0:
			old.queue_free()


func _physics_process(delta: float) -> void:
	_update_safe_point(delta)
	if _respawn_t > 0.0:
		_respawn_t -= delta
		if _respawn_t <= 0.0:
			_respawn_player()


func _on_player_died(cause: String) -> void:
	EventBus.big_message.emit("AUSGESCHALTET", cause if cause != "" else "Das war knapp daneben.", 3.0)
	_respawn_kind = "klinik"
	_respawn_t = 3.5


## Wiederbelebung an der Klinik bzw. nach Festnahme am Revier (mit Gebühr).
func _respawn_player() -> void:
	player.input_enabled = true
	reset_wanted()
	var xf: Transform3D = get_spawn_transform()
	if world is CityWorld:
		xf = (world as CityWorld).respawn_point(_respawn_kind)
	player.revive(xf.origin, xf.basis.get_euler().y)
	camera_rig.yaw = xf.basis.get_euler().y
	camera_rig.snap()
	var fee: int = 100 if _respawn_kind == "klinik" else 150
	var paid: int = mini(fee, GameState.money)
	GameState.add_money(-paid)
	var place: String = "St.-Fächer-Klinik" if _respawn_kind == "klinik" else "Polizeirevier Innenstadt"
	EventBus.notify.emit("%s: %s bezahlt." % [place, UiStyle.money(paid)], "warnung")
	EventBus.player_respawned.emit()


## Vor einem Missions-Neustart: Spieler zum Auftraggeber, Zustand bereinigen.
func prepare_mission_retry(_mission_id: String, xf: Transform3D) -> void:
	_respawn_t = -1.0
	if player.is_dead:
		player.revive(xf.origin, xf.basis.get_euler().y)
	elif player.is_in_vehicle():
		player.force_leave_vehicle(xf.origin)
	player.global_position = xf.origin
	player.rotation = Vector3(0, xf.basis.get_euler().y, 0)
	player.velocity = Vector3.ZERO
	player.reset_physics_interpolation()
	if has_method("reset_wanted"):
		call("reset_wanted")
	camera_rig.yaw = player.rotation.y
	camera_rig.snap()


func on_mission_completed(_mission_id: String) -> void:
	if autosave_enabled:
		var r: Dictionary = save_now()
		EventBus.notify.emit("Automatisch gespeichert." if r.ok else str(r.message), "hinweis" if r.ok else "warnung")


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
	tour.add_station("mission_dialog", func() -> void:
		var giver: MissionGiver = missions.givers["m01_erste_schicht"]
		player.global_position = giver.global_position + (-giver.global_basis.z) * 2.2 + Vector3.UP * 0.1
		camera_rig.yaw = giver.rotation.y + PI + 0.5
		camera_rig.pitch = -0.15
		camera_rig.snap()
		await get_tree().physics_frame
		missions.start_mission("m01_erste_schicht")
	, 60)
	tour.add_station("mission_lieferwagen_markierung", func() -> void:
		missions.auto_skip_dialog = true
		for i: int in 30:
			await get_tree().physics_frame
		missions.auto_skip_dialog = false
		var van: Vehicle = missions.mission_vehicle("van")
		if van != null:
			player.global_position = van.global_position + Vector3(-9, 0.2, 4)
			camera_rig.yaw = deg_to_rad(-60.0)
			camera_rig.pitch = -0.25
			camera_rig.snap()
	, 50)
	tour.add_station("hud_fahrt_mit_ziel", func() -> void:
		var van: Vehicle = missions.mission_vehicle("van")
		if van == null:
			return
		van.teleport_to(Vector3(-150, 0, 462.6), -PI * 0.5)
		player.global_position = van.global_position + Vector3(0, 0, -3)
		await get_tree().physics_frame
		van.enter(player)
		van.set_lights(true)
		var ap := Autopilot.new()
		ap.set_path(PackedVector3Array([Vector3(-40, 0, 462.6), Vector3(200, 0, 462.6)]), 13.0)
		van.ai_controller = ap
		van.driver = Vehicle.Driver.AI
		camera_rig.yaw = -PI * 0.5
	, 120)
	tour.add_station("verkehr_kreuzung", func() -> void:
		if missions.active != null:
			missions.fail("Tour")
			missions.abort()
		player.force_leave_vehicle(Vector3(-482, y, 452))
		camera_rig.yaw = deg_to_rad(-135.0)
		camera_rig.pitch = -0.28
		camera_rig._target_distance = 9.0
		camera_rig.snap()
		for i: int in 240:
			await get_tree().physics_frame
	, 30)
	tour.add_station("passanten_kaiserstrasse", func() -> void:
		camera_rig._target_distance = 4.2
		player.global_position = Vector3(-80, y, 333)
		camera_rig.yaw = deg_to_rad(90.0)
		camera_rig.pitch = -0.12
		camera_rig.snap()
		for i: int in 180:
			await get_tree().physics_frame
	, 30)
	tour.add_station("verfolgung_polizei", func() -> void:
		var v: Vehicle = spawn_vehicle("sport", Vector3(-300, 0.1, 462.6), -PI * 0.5)
		await get_tree().physics_frame
		player.global_position = v.global_position + Vector3(0, 0, -3)
		v.enter(player)
		set_wanted(2, "Tour", player.global_position)
		for i: int in 400:
			await get_tree().physics_frame
			if police.units.size() > 0:
				var u: Vehicle = police.units[0]
				v.teleport_to(u.global_position + (-u.global_basis.z) * 16.0 + u.global_basis.x * 2.0, u.global_rotation.y)
				break
		camera_rig.yaw = v.global_rotation.y + PI
		camera_rig.pitch = -0.22
		camera_rig.snap()
		for i2: int in 60:
			await get_tree().physics_frame
	, 30)
	tour.add_station("m2_zeitfahren_kontrollpunkt", func() -> void:
		reset_wanted()
		police.enabled = false
		for u: Vehicle in police.units:
			u.queue_free()
		police.units.clear()
		player.force_leave_vehicle(missions.giver_start_transform("m02_faecher_runde").origin)
		GameState.complete_mission("m01_erste_schicht", 0)
		missions.auto_skip_dialog = true
		missions.start_mission("m02_faecher_runde")
		for i: int in 30:
			await get_tree().physics_frame
		var gt: Vehicle = missions.mission_vehicle("gt")
		if gt == null:
			return
		player.global_position = gt.global_position + gt.global_basis.x * -2.0
		await get_tree().physics_frame
		gt.enter(player)
		for i2: int in 260:
			await get_tree().physics_frame
		gt.teleport_to(Vector3(563.5, 0.1, 205), 0.0)
		gt.set_lights(true)
		var ap := Autopilot.new()
		ap.set_path(PackedVector3Array([Vector3(563.5, 0, 150), Vector3(563.5, 0, 20)]), 18.0)
		gt.ai_controller = ap
		gt.driver = Vehicle.Driver.AI
		camera_rig.yaw = 0.0
		camera_rig.pitch = -0.16
		camera_rig.snap()
	, 100)
	tour.add_station("m3_auftraggeber_ewald", func() -> void:
		if missions.active != null:
			missions.fail("Tour")
			missions.abort()
		missions.auto_skip_dialog = true
		player.force_leave_vehicle(missions.giver_start_transform("m03_falsche_lieferung").origin)
		missions.start_mission("m03_falsche_lieferung")
		for i: int in 40:
			await get_tree().physics_frame
		var giver: MissionGiver = missions.givers["m03_falsche_lieferung"]
		player.global_position = giver.global_position + Vector3(-4.5, 0.1, -2.0)
		camera_rig.yaw = deg_to_rad(-100.0)
		camera_rig.pitch = -0.2
		camera_rig._target_distance = 6.5
		camera_rig.snap()
	, 60)
	tour.add_station("karte_vollbild", func() -> void:
		if missions.active != null:
			missions.fail("Tour")
			missions.abort()
		player.force_leave_vehicle(Vector3(5, y, 447))
		missions.start_mission("m03_falsche_lieferung")
		for i: int in 30:
			await get_tree().physics_frame
		map_overlay.open()
	, 20)
	tour.add_station("pausenmenue", func() -> void:
		map_overlay.close()
		pause_menu.open()
	, 20)
	tour.add_station("entwickleranzeige_minikarte", func() -> void:
		pause_menu.close()
		camera_rig.yaw = 0.0
		camera_rig.pitch = -0.12
		camera_rig._target_distance = 4.2
		camera_rig.snap()
		dev_overlay.toggle()
	, 40)
	tour.add_station("luftbild_faecher", func() -> void:
		dev_overlay.toggle()
		player.global_position = Vector3(0, y, 250)
		camera_rig.yaw = 0.0
		camera_rig.pitch = -1.2
		camera_rig._target_distance = 60.0
		camera_rig.snap()
	, 40)
