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
var animals: AnimalManager = null
var waypoint: Vector3 = Vector3.INF          ## vom Spieler gesetzter Wegpunkt (Auftragsliste/Karte)
var jobs: JobSystem = null
var mission_list: MissionList = null
var events: EventDirector = null
var transit: TransitSystem = null
var ride_info: String = ""                    ## HUD-Text während einer ÖPNV-Fahrt
var animals_in_tests: bool = false
var police: PoliceManager = null
var parked: ParkedCarManager = null
## Tests: geparkte Autos auch ohne Umgebungsleben
var parked_cars_in_tests: bool = false
## Streaming: synchron bauen (Tests, Screenshot-Tour) und Radius-Überschreibung (-1 = Einstellung)
var stream_sync: bool = false
var stream_radius: int = -1
## Umgebungsleben (Verkehr/Passanten/Streife); Tests können es abschalten
var ambient_life: bool = true
var pause_menu: PauseMenu = null
var map_overlay: MapOverlay = null
var cheat_console: CheatConsole = null
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
	add_to_group("game")
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
		jobs = JobSystem.new()
		jobs.name = "Jobs"
		add_child(jobs)
		jobs.setup(self)
		mission_list = MissionList.new()
		mission_list.name = "Auftragsliste"
		add_child(mission_list)
		mission_list.setup(self)
		_setup_maps(world as CityWorld)
	pause_menu = PauseMenu.new()
	pause_menu.name = "Pausenmenue"
	add_child(pause_menu)
	pause_menu.setup(self)
	cheat_console = CheatConsole.new()
	cheat_console.name = "CheatKonsole"
	add_child(cheat_console)
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
	if App.has_arg("--boot-check"):
		_boot_check.call_deferred()


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
		cw.synchronous_streaming = stream_sync or App.has_arg("--screenshot-tour")
		cw.stream_radius_override = stream_radius
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
	elif event.is_action_pressed("mission_list") and mission_list != null and not mission_list.is_open():
		mission_list.open()
		get_viewport().set_input_as_handled()
	elif event.is_action_pressed("cheat_console") and cheat_console != null and not cheat_console.is_open():
		cheat_console.open()
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
	if world is CityWorld:
		(world as CityWorld).ensure_loaded(xf.origin)
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
	if world is CityWorld and (world as CityWorld).is_inside_building(Vector2(pos.x, pos.z)):
		return false
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
	# Ampelmasten sektorweise mit dem Streaming ein-/aushängen
	var st: WorldStreamer = city.streamer
	for ij: Vector2i in st.loaded:
		lights.attach_sector(ij, city.world.sector_rect(ij), st.loaded[ij].node)
	st.sector_loaded.connect(func(ij: Vector2i, info: Dictionary) -> void: lights.attach_sector(ij, city.world.sector_rect(ij), info.node))
	st.sector_unloaded.connect(func(ij: Vector2i) -> void: lights.detach_sector(ij))
	parked = ParkedCarManager.new()
	parked.name = "Parkende_Autos"
	add_child(parked)
	parked.enabled = ambient_life or parked_cars_in_tests
	parked.setup(self, st)
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
	animals = AnimalManager.new()
	animals.name = "Tiere"
	add_child(animals)
	animals.setup(self, st)
	animals.enabled = ambient_life or animals_in_tests
	police = PoliceManager.new()
	police.name = "Polizei"
	add_child(police)
	police.setup(self, city.graph, lights)
	police.patrol_enabled = ambient_life
	events = EventDirector.new()
	events.name = "Ereignisse"
	add_child(events)
	events.setup(self, city, lights)
	events.enabled = ambient_life
	transit = TransitSystem.new()
	transit.name = "OePNV"
	add_child(transit)
	transit.setup(self, city)
	EventBus.player_busted.connect(_on_busted)
	EventBus.player_entered_vehicle.connect(_on_player_entered_vehicle)
	EventBus.vehicle_collision.connect(func(v: Node, dv: float, _o: Node) -> void:
		if player != null and v == player.current_vehicle and camera_rig != null:
			camera_rig.add_shake(clampf(dv / 12.0, 0.1, 0.8)))


# ------------------------------------------------------------------ Schnittstellen für Missionen/Systeme

func get_wanted_level() -> int:
	return police.wanted_level() if police != null else 0


func set_wanted(level: int, reason: String, pos: Vector3) -> void:
	if police != null:
		police.set_wanted(level, reason, pos)


## Spieler (bzw. sein Fahrzeug) an eine Position versetzen; Sektoren werden vorher geladen.
func teleport_player(pos: Vector3) -> void:
	var cw: CityWorld = get_city()
	if cw != null:
		cw.ensure_loaded(pos)
		pos.y = cw.ground_y(Vector2(pos.x, pos.z)) + 0.2
	if player.is_riding() and transit != null:
		transit.cancel_ride()
		player.end_ride(pos)
	elif player.is_in_vehicle():
		var v: Vehicle = player.current_vehicle as Vehicle
		v.teleport_to(pos + Vector3.UP * 0.3, v.rotation.y)
	else:
		player.global_position = pos
		player.velocity = Vector3.ZERO
		player.reset_physics_interpolation()
	camera_rig.snap()


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
	if world is CityWorld and player != null:
		(world as CityWorld).update_focus(player.current_vehicle.global_position if player.is_in_vehicle() else player.global_position)
		# Wegpunkt erreicht -> löschen
		if waypoint != Vector3.INF and Vector2(player.global_position.x - waypoint.x, player.global_position.z - waypoint.z).length() < 15.0:
			waypoint = Vector3.INF
			EventBus.notify.emit("Wegpunkt erreicht.", "info")
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
	if autosave_enabled and Settings.autosave:
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
	if CheatManager.is_active("MONDFAHRT"):
		v.gravity_scale = 0.35
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


func _cam_station(tour: ScreenshotTour, station_name: String, player_pos: Vector3, yaw_deg: float, pitch: float, frames: int = 40,
		pre: Callable = Callable(), cam_dist: float = 4.2) -> void:
	tour.add_station(station_name, func() -> void:
		if pre.is_valid():
			pre.call()
		if world is CityWorld:
			(world as CityWorld).ensure_loaded(player_pos)
		if player.is_in_vehicle():
			player.force_leave_vehicle(player_pos)
		player.global_position = player_pos
		player.velocity = Vector3.ZERO
		camera_rig.yaw = deg_to_rad(yaw_deg)
		camera_rig.pitch = pitch
		camera_rig._target_distance = cam_dist
		camera_rig.snap()
	, frames)


## Station mit gesetzter Tageszeit und Wetter (Umgebung sofort aktualisiert).
func _weather_station(tour: ScreenshotTour, station_name: String, player_pos: Vector3, yaw_deg: float, pitch: float, hour: float,
		weather: String) -> void:
	_cam_station(tour, station_name, player_pos, yaw_deg, pitch, 60, func() -> void:
		WorldClock.set_time(hour)
		WorldClock.set_weather(weather, true)
		var cw: CityWorld = get_city()
		if cw != null and cw.env != null:
			cw.env.update_environment(true))


## Station relativ zu einer Landmarke aus den Weltdaten (lokaler Versatz vor Drehung), Blick auf die Landmarke.
func _lm_station(tour: ScreenshotTour, station_name: String, lm_type: String, offset: Vector2, y: float, pitch: float,
		look_at_local: Vector2 = Vector2.ZERO, cam_dist: float = 4.2) -> void:
	var v: Dictionary = _lm_view(lm_type, offset, look_at_local)
	if not v.is_empty():
		_cam_station(tour, station_name, Vector3(v.pos.x, y, v.pos.y), v.yaw, pitch, 40, Callable(), cam_dist)


## Kamerastandpunkt relativ zu einer Landmarke: { pos: Vector2, yaw: Grad } oder leer.
func _lm_view(lm_type: String, offset: Vector2, look_at_local: Vector2 = Vector2.ZERO) -> Dictionary:
	for lm: Variant in get_city().graph.layout.landmarks:
		if str(lm.type) != lm_type:
			continue
		var c: Vector2 = Vector2(float(lm.pos[0]), float(lm.pos[1]))
		var rot: float = deg_to_rad(float(lm.get("rot", 0.0)))
		var o: Vector2 = Vector2(offset.x * cos(rot) + offset.y * sin(rot), -offset.x * sin(rot) + offset.y * cos(rot))
		var pp: Vector2 = c + o
		var t: Vector2 = c + Vector2(look_at_local.x * cos(rot) + look_at_local.y * sin(rot), -look_at_local.x * sin(rot) + look_at_local.y * cos(rot))
		return {"pos": pp, "yaw": rad_to_deg(atan2(-(t.x - pp.x), -(t.y - pp.y)))}
	return {}


## Kamerastandpunkt am Rand der benannten Straße (nächster Abschnitt zu „near“), Blick entlang der Straße Richtung „face“.
func _street_view(street: String, near: Vector2, face: Vector2) -> Dictionary:
	var g: CityGraph = get_city().graph
	var best_e: int = -1
	var best_q: Vector2 = near
	var best_d: float = INF
	for e: int in g.edge_a.size():
		if g.edge_name(e) != street:
			continue
		var q: Vector2 = PolyUtil.closest_on_segment(near, g.node_pos[g.edge_a[e]], g.node_pos[g.edge_b[e]])
		if q.distance_to(near) < best_d:
			best_d = q.distance_to(near)
			best_e = e
			best_q = q
	if best_e < 0:
		print("[screenshot] Straße nicht gefunden: %s" % street)
		return {}
	var dir: Vector2 = (g.node_pos[g.edge_b[best_e]] - g.node_pos[g.edge_a[best_e]]).normalized()
	if dir.dot(face) < 0.0:
		dir = -dir
	var pp: Vector2 = best_q + Vector2(-dir.y, dir.x) * (g.edge_width(best_e) * 0.5 + 1.5)
	return {"pos": pp, "yaw": rad_to_deg(atan2(-dir.x, -dir.y))}


## Fahrweg für Tour-Fahrten: Spurpunkte über das Verkehrsnetz ab der Straße „street“ (nahe „near“) Richtung „face“.
func _tour_route(street: String, near: Vector2, face: Vector2, dist: float) -> PackedVector3Array:
	var v: Dictionary = _street_view(street, near, face)
	if v.is_empty():
		return PackedVector3Array()
	var g: CityGraph = get_city().graph
	var yaw: float = deg_to_rad(float(v.yaw))
	var dir: Vector2 = Vector2(-sin(yaw), -cos(yaw))
	var a: int = g.nearest_node(v.pos, "traffic")
	var b: int = g.nearest_node(v.pos + dir * dist, "traffic")
	if a < 0 or b < 0 or a == b:
		return PackedVector3Array()
	return g.lane_path(g.find_path(a, b, "traffic"), 2.6)


## Nächste Ampelkreuzung (oder -1).
func _signal_node_near(p: Vector2) -> int:
	var best: int = -1
	var best_d: float = INF
	if lights == null:
		return -1
	for n: Variant in lights.signals:
		var d: float = get_city().graph.node_pos[int(n)].distance_to(p)
		if d < best_d:
			best_d = d
			best = int(n)
	return best


func _view_station(tour: ScreenshotTour, station_name: String, v: Dictionary, y: float, pitch: float) -> void:
	if not v.is_empty():
		_cam_station(tour, station_name, Vector3(v.pos.x, y, v.pos.y), v.yaw, pitch)


func _view_weather(tour: ScreenshotTour, station_name: String, v: Dictionary, y: float, pitch: float, hour: float,
		weather: String) -> void:
	if not v.is_empty():
		_weather_station(tour, station_name, Vector3(v.pos.x, y, v.pos.y), v.yaw, pitch, hour, weather)


## ÖPNV-Stationen: Bahn an der Haltestelle, Rampenportal, Mitfahrt in U-Station und Tunnel, Bus.
func _transit_stations(tour: ScreenshotTour, y: float) -> void:
	if transit == null or not transit.has_lines():
		return
	tour.add_station("oepnv_bahn_haltestelle", func() -> void:
		WorldClock.set_time(12.0)
		var vh: Dictionary = transit.debug_place_at_stop("Durlacher Tor", "tram")
		if vh.is_empty():
			return
		var f: Node3D = vh.segs[0]
		var side: Vector3 = f.global_basis.x
		var pp: Vector3 = f.global_position + side * 14.0 - f.global_basis.z * 6.0
		(world as CityWorld).ensure_loaded(pp)
		player.global_position = Vector3(pp.x, y, pp.z)
		var to: Vector3 = f.global_position + f.global_basis.z * 10.0 - player.global_position
		camera_rig.yaw = atan2(-to.x, -to.z)
		camera_rig.pitch = -0.08
		camera_rig.snap()
	, 60)
	tour.add_station("oepnv_ustrab_rampe", func() -> void:
		for ln: Dictionary in transit.lines:
			if (ln.tun as Array).is_empty() or ln.mode != "tram":
				continue
			var r1: float = float(ln.tun[0][1])
			if r1 + TransitSystem.RAMP + 40.0 > float(ln.len):
				continue
			var pd: Array = transit.point_at(ln, r1 + TransitSystem.RAMP + 28.0)
			var d: Vector2 = pd[1]
			var p2: Vector2 = (pd[0] as Vector2) + Vector2(-d.y, d.x) * 9.0
			(world as CityWorld).ensure_loaded(Vector3(p2.x, 0, p2.y))
			player.global_position = Vector3(p2.x, y, p2.y)
			camera_rig.yaw = atan2(d.x, d.y)
			camera_rig.pitch = -0.1
			camera_rig.snap()
			return
	, 60)
	tour.add_station("oepnv_mitfahrt_ustation", func() -> void:
		var vh: Dictionary = transit.debug_place_at_stop("Marktplatz", "tram")
		if vh.is_empty():
			return
		player.global_position = transit.stop_world_pos(int(transit.lines[int(vh.line)].stops[int(vh.stop_k)])) + Vector3.UP * 0.2
		transit.board(vh)
		camera_rig.yaw = (vh.segs[0] as Node3D).rotation.y + 0.35
		camera_rig.pitch = -0.12
		camera_rig.snap()
	, 60)
	tour.add_station("oepnv_mitfahrt_tunnel", func() -> void:
		if not transit.is_riding():
			return
		var vh: Dictionary = transit.ride.veh
		vh.dwell = 0.0
		vh.stop_k = int(vh.stop_k) + 1
		vh.s = float(vh.s) + 150.0
		vh.v = 11.0
		camera_rig.yaw = (vh.segs[0] as Node3D).rotation.y
		camera_rig.pitch = -0.1
		camera_rig.snap()
	, 50)
	tour.add_station("oepnv_bus_hbf", func() -> void:
		if transit.is_riding():
			transit.cancel_ride()
			player.end_ride(Vector3(0, y, 520))
		var vh: Dictionary = transit.debug_place_at_stop("Hauptbahnhof", "bus")
		if vh.is_empty():
			return
		var f: Node3D = vh.segs[0]
		var pp: Vector3 = f.global_position + f.global_basis.x * 12.0 - f.global_basis.z * 10.0
		(world as CityWorld).ensure_loaded(pp)
		player.global_position = Vector3(pp.x, y, pp.z)
		var to: Vector3 = f.global_position - player.global_position
		camera_rig.yaw = atan2(-to.x, -to.z)
		camera_rig.pitch = -0.08
		camera_rig.snap()
	, 60)


func _register_city_stations(tour: ScreenshotTour) -> void:
	var cw: CityWorld = get_city()
	var y: float = cw.slab_h + 0.05
	# Standpunkte aus den Weltdaten (Landmarken, Straßennamen) – gültig für OSM- und Näherungswelt
	var v_pyr: Dictionary = _lm_view("pyramide", Vector2(-10, 24))
	var v_kaiser: Dictionary = _street_view("Kaiserstraße", Vector2(-300, 430), Vector2(1, 0))
	var v_krieg: Dictionary = _street_view("Kriegsstraße", Vector2(-300, 890), Vector2(-1, 0))
	var v_schloss: Dictionary = _lm_view("schloss", Vector2(0, 190))
	# Ortsbilder bei Tageslicht (die Uhr läuft während der Tour weiter)
	_cam_station(tour, "start_marktplatz_blick_schloss", cw.get_spawn().origin, 0.0, -0.12, 40, func() -> void:
		WorldClock.set_time(10.5)
		WorldClock.set_weather("klar", true))
	_view_station(tour, "marktplatz_pyramide", v_pyr, y, -0.05)
	# Marktplatz real nur ≈ 38 m zwischen Rathaus und Kirche: Standpunkte schräg vom offenen Nordteil des Platzes
	_lm_station(tour, "rathaus", "rathaus", Vector2(30, 34), y, -0.3, Vector2.ZERO, 14.0)
	_lm_station(tour, "stadtkirche", "stadtkirche", Vector2(-32, 30), y, -0.3, Vector2.ZERO, 14.0)
	_view_station(tour, "schlossplatz", v_schloss, y, -0.08)
	_view_station(tour, "kaiserstrasse", v_kaiser, y, -0.08)
	_view_station(tour, "faecherstrasse_zirkel", _street_view("Karl-Friedrich-Straße", Vector2(-30, 330), Vector2(0, -1)), y, -0.06)
	_view_station(tour, "zirkel", _street_view("Zirkel", Vector2(-220, 190), Vector2(1, 0)), y, -0.08)
	_lm_station(tour, "europaplatz", "brunnen", Vector2(-16, 14), y, -0.3, Vector2.ZERO, 12.0)
	_lm_station(tour, "durlacher_tor", "torbogen", Vector2(-4, 22), y, -0.04)
	_view_station(tour, "kriegsstrasse", v_krieg, y, -0.06)
	_lm_station(tour, "hauptbahnhof", "hauptbahnhof", Vector2(-40, -95), y, -0.02)
	var ent: Array = LandmarksExtra._zoo_layout().get("entrance", [0, 250])
	_lm_station(tour, "zoo_eingang", "zoo", Vector2(float(ent[0]) + 6.0, float(ent[1]) + 34.0), y, -0.12,
		Vector2(float(ent[0]), float(ent[1])), 8.0)
	# Blick von Norden auf das Elefantengehege (Lage aus den Weltdaten, bei OSM an die reale Zoofläche angepasst)
	for encv: Variant in LandmarksExtra.zoo_enclosures():
		if str(encv.id) == "elefanten":
			var ec: Vector2 = Vector2(float(encv.center[0]), float(encv.center[1]))
			_lm_station(tour, "zoo_gehege", "zoo", ec + Vector2(-8, -34), y, -0.4, ec, 16.0)
	_lm_station(tour, "stadion", "stadion", Vector2(-50, 125), y, -0.2, Vector2.ZERO, 22.0)
	_lm_station(tour, "gewaechshaeuser", "gewaechshaus", Vector2(-6, 28), y, -0.55, Vector2.ZERO, 42.0)
	_lm_station(tour, "hafenkraene", "hafenkran", Vector2(-20, 70), y, 0.12)
	_lm_station(tour, "turmberg", "turmberg", Vector2(-25, -40), y, 0.15)
	_cam_station(tour, "weststadt", Vector3(-1900, y, 300), 90.0, -0.08)
	_view_station(tour, "durlach", _street_view("Pfinztalstraße", Vector2(5250, 1650), Vector2(1, 0)), y, -0.08)
	_cam_station(tour, "rheinhafen", Vector3(-5600, y, 330), 90.0, -0.12)
	_transit_stations(tour, y)
	tour.add_station("fahrzeuge_modelle", func() -> void:
		WorldClock.set_time(11.0)
		var base: Vector3 = Vector3(-30, y, 120)
		(world as CityWorld).ensure_loaded(base)
		var ids: Array[String] = ["kompakt", "limousine", "sport", "transporter", "polizei"]
		for i: int in ids.size():
			spawn_vehicle(ids[i], base + Vector3(float(i) * 3.6, 0.3, 0), deg_to_rad(-25.0))
		player.global_position = base + Vector3(9.0, 0, 9.0)
		camera_rig.yaw = deg_to_rad(15.0)
		camera_rig.pitch = -0.22
		camera_rig.snap()
	, 60)
	_view_weather(tour, "tageslicht_mittag", v_pyr, y, -0.05, 13.0, "klar")
	_view_weather(tour, "nacht_kaiserstrasse", v_kaiser, y, -0.06, 23.0, "klar")
	_view_weather(tour, "regen_nasse_strasse", v_krieg, y, -0.1, 15.0, "regen")
	_view_weather(tour, "nebel_morgen", v_schloss, y, -0.04, 7.5, "nebel")
	tour.add_station("mission_dialog", func() -> void:
		WorldClock.set_time(19.5)
		WorldClock.set_weather("klar", true)
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
	var r_van: PackedVector3Array = _tour_route("Kriegsstraße", Vector2(-450, 890), Vector2(1, 0), 450.0)
	tour.add_station("hud_fahrt_mit_ziel", func() -> void:
		var van: Vehicle = missions.mission_vehicle("van")
		if van == null or r_van.size() < 3:
			return
		var p0: Vector3 = Vector3(r_van[0].x, 0.0, r_van[0].z)
		var hd: float = atan2(-(r_van[1].x - p0.x), -(r_van[1].z - p0.z))
		(world as CityWorld).ensure_loaded(p0)
		van.teleport_to(p0, hd)
		player.global_position = van.global_position + Vector3(0, 0, -3)
		await get_tree().physics_frame
		van.enter(player)
		van.set_lights(true)
		var ap := Autopilot.new()
		ap.set_path(r_van.slice(1), 13.0)
		van.ai_controller = ap
		van.driver = Vehicle.Driver.AI
		camera_rig.yaw = hd
	, 120)
	var jn: int = _signal_node_near(Vector2(-535, 900))
	tour.add_station("verkehr_kreuzung", func() -> void:
		if missions.active != null:
			missions.fail("Tour")
			missions.abort()
		var jp: Vector2 = cw.graph.node_pos[jn] if jn >= 0 else Vector2(-535, 900)
		var sp: Vector3 = Vector3(jp.x + cw.graph.node_radius(maxi(jn, 0)) + 6.0, y, jp.y + cw.graph.node_radius(maxi(jn, 0)) + 6.0)
		(world as CityWorld).ensure_loaded(sp)
		player.force_leave_vehicle(sp)
		camera_rig.yaw = atan2(-(jp.x - sp.x), -(jp.y - sp.z))
		camera_rig.pitch = -0.28
		camera_rig._target_distance = 9.0
		camera_rig.snap()
		for i: int in 240:
			await get_tree().physics_frame
	, 30)
	tour.add_station("passanten_kaiserstrasse", func() -> void:
		if v_kaiser.is_empty():
			return
		camera_rig._target_distance = 4.2
		(world as CityWorld).ensure_loaded(Vector3(v_kaiser.pos.x, y, v_kaiser.pos.y))
		player.global_position = Vector3(v_kaiser.pos.x, y, v_kaiser.pos.y)
		camera_rig.yaw = deg_to_rad(float(v_kaiser.yaw))
		camera_rig.pitch = -0.12
		camera_rig.snap()
		for i: int in 180:
			await get_tree().physics_frame
	, 30)
	var r_chase: PackedVector3Array = _tour_route("Kriegsstraße", Vector2(-800, 890), Vector2(-1, 0), 300.0)
	tour.add_station("verfolgung_polizei", func() -> void:
		if r_chase.size() < 2:
			return
		var c0: Vector3 = Vector3(r_chase[0].x, 0.1, r_chase[0].z)
		(world as CityWorld).ensure_loaded(c0)
		var v: Vehicle = spawn_vehicle("sport", c0, atan2(-(r_chase[1].x - c0.x), -(r_chase[1].z - c0.z)))
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
	var r_m2: PackedVector3Array = _tour_route("Durlacher Allee", Vector2(1500, 540), Vector2(1, 0), 500.0)
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
		if r_m2.size() < 3:
			return
		var g0: Vector3 = Vector3(r_m2[0].x, 0.1, r_m2[0].z)
		var gh: float = atan2(-(r_m2[1].x - g0.x), -(r_m2[1].z - g0.z))
		(world as CityWorld).ensure_loaded(g0)
		gt.teleport_to(g0, gh)
		gt.set_lights(true)
		var ap := Autopilot.new()
		ap.set_path(r_m2.slice(1), 18.0)
		gt.ai_controller = ap
		gt.driver = Vehicle.Driver.AI
		camera_rig.yaw = gh
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
		player.force_leave_vehicle(cw.get_spawn().origin)
		missions.start_mission("m03_falsche_lieferung")
		for i: int in 30:
			await get_tree().physics_frame
		map_overlay.open()
	, 20)
	tour.add_station("pausenmenue", func() -> void:
		map_overlay.close()
		pause_menu.open()
	, 20)
	tour.add_station("optionen_grafik", func() -> void:
		pause_menu.call("_on_settings")
	, 20)
	tour.add_station("optionen_tastenbelegung", func() -> void:
		var sp: SettingsPanel = pause_menu.get("_settings") as SettingsPanel
		sp._tabs.current_tab = 3
	, 20)
	tour.add_station("cheat_konsole", func() -> void:
		(pause_menu.get("_settings") as SettingsPanel).close()
		pause_menu.close()
		cheat_console.open()
		cheat_console._submit("HILFE")
	, 20)
	tour.add_station("entwickleranzeige_minikarte", func() -> void:
		cheat_console.close()
		pause_menu.close()
		camera_rig.yaw = 0.0
		camera_rig.pitch = -0.12
		camera_rig._target_distance = 4.2
		camera_rig.snap()
		dev_overlay.toggle()
	, 40)
	tour.add_station("luftbild_faecher", func() -> void:
		dev_overlay.toggle()
		(world as CityWorld).ensure_loaded(Vector3(0, y, 350))
		player.global_position = Vector3(0, y, 350)
		camera_rig.yaw = 0.0
		camera_rig.pitch = -1.2
		camera_rig._target_distance = 140.0
		camera_rig.snap()
	, 40)


## Starttest für Build-Skripte (`-- --autostart --boot-check`): Welt, Graph, Missionen und ÖPNV geladen? Exit-Code 0/1.
func _boot_check() -> void:
	for i: int in 30:
		await get_tree().physics_frame
	var cw: CityWorld = get_city()
	var ok: bool = cw != null and cw.graph != null and cw.graph.node_count() > 100 and missions != null \
		and missions.definitions.size() >= 15 and transit != null and player != null
	print("[boot] %s: Knoten %d, Aufträge %d, ÖPNV-Linien %d, Quelle %s" % ["OK" if ok else "FEHLER",
		cw.graph.node_count() if cw != null and cw.graph != null else 0, missions.definitions.size() if missions != null else 0,
		transit.lines.size() if transit != null else 0, str(cw.world.meta.get("source", "?")) if cw != null and cw.world != null else "?"])
	get_tree().quit(0 if ok else 1)
