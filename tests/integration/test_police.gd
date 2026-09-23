extends GameTestCase
## Polizei/Fahndung: Auslöser, Spawn außer Sicht, Suche ohne Allwissenheit, Abbau, Festnahme.


func after_each() -> void:
	await stop_game()


func test_witnessed_theft_triggers_wanted() -> void:
	await start_city_game(true)
	game.traffic.enabled = false
	game.police.patrol_enabled = false
	await wait_until(func() -> bool: return game.peds.active_count() >= 2, 10.0)
	# Nicht abgeschlossenes, geparktes Auto suchen und einen Zeugen danebenstellen
	var target: Vehicle = null
	for vn: Node in get_tree().get_nodes_in_group("vehicles"):
		var v: Vehicle = vn as Vehicle
		if v.ownership == Vehicle.Ownership.PARKED_FOREIGN and not v.locked:
			target = v
			break
	assert_true(target != null, "Offenes geparktes Fahrzeug gefunden")
	var w: Pedestrian = game.peds.peds[0]
	w.global_position = target.global_position + Vector3(6, 0.1, 6)
	w.state = Pedestrian.State.WAIT
	await wait_physics(5)
	assert_true(await enter(target), "Fahrzeug übernommen")
	assert_eq(game.get_wanted_level(), 1, "Beobachtete Übernahme -> Fahndungsstufe 1")


func test_unwitnessed_theft_no_wanted() -> void:
	await start_city_game(false)
	var target: Vehicle = null
	for vn: Node in get_tree().get_nodes_in_group("vehicles"):
		var v: Vehicle = vn as Vehicle
		if v.ownership == Vehicle.Ownership.PARKED_FOREIGN and not v.locked:
			target = v
			break
	assert_true(await enter(target), "Fahrzeug übernommen")
	assert_eq(game.get_wanted_level(), 0, "Unbeobachtet -> keine Fahndung")


func test_police_spawn_hidden_search_and_decay() -> void:
	await start_city_game(false)
	var p: Player = game.player
	p.global_position = Vector3(-300, 0.15, 470)
	await wait_physics(10)
	game.set_wanted(2, "Test", p.global_position)
	assert_eq(game.get_wanted_level(), 2, "Stufe 2 gesetzt")
	var cam: Camera3D = game.camera_rig.get_camera()
	var spawned_visible: int = 0
	var spawned: int = 0
	var seen_ids: Dictionary = {}
	for k: int in 30:
		await wait_physics(20)
		for u: Vehicle in game.police.units:
			if is_instance_valid(u) and not seen_ids.has(u.get_instance_id()):
				seen_ids[u.get_instance_id()] = true
				spawned += 1
				var d: float = u.global_position.distance_to(p.global_position)
				if d < 85.0:
					spawned_visible += 1
	assert_gt(float(spawned), 1.5, "Polizeieinheiten erscheinen (%d)" % spawned)
	assert_eq(spawned_visible, 0, "Keine Einheit erscheint direkt beim Spieler")
	# Spieler versteckt sich weit weg (ohne Sichtkontakt)
	var last_known: Vector3 = game.police.police_goal()
	p.global_position = Vector3(520, 0.15, -30)
	await wait_seconds(4.0)
	assert_eq(game.police.wanted.state, "suche", "Suchphase nach Sichtverlust")
	assert_lt(game.police.police_goal().distance_to(last_known), 30.0, "Polizei sucht an der zuletzt bekannten Position")
	assert_gt(game.police.police_goal().distance_to(p.global_position), 300.0, "Polizei kennt die neue Position nicht")
	var ok: bool = await wait_until(func() -> bool: return game.get_wanted_level() == 0, 45.0)
	assert_true(ok, "Fahndung endet nach der Suchphase")
	await wait_seconds(6.0)
	assert_lt(float(game.police.active_units()), 1.5, "Einheiten ziehen ab (%d)" % game.police.active_units())


func test_arrest_respawns_at_station_and_fails_mission() -> void:
	await start_city_game(false)
	var p: Player = game.player
	GameState.add_money(500)
	var money0: int = GameState.money
	var busted: Array[bool] = [false]
	EventBus.player_busted.connect(func() -> void: busted[0] = true)
	p.global_position = Vector3(-300, 0.15, 470)
	await wait_physics(10)
	assert_true(game.missions.start_mission("m01_erste_schicht"), "Mission 1 läuft")
	await wait_physics(30)
	p.global_position = Vector3(-300, 0.15, 470)
	await wait_physics(5)
	game.set_wanted(1, "Test", p.global_position)
	# Polizeifahrzeug direkt neben den Spieler setzen
	var u: Vehicle = game.spawn_vehicle("polizei", Vector3(-300, 0.1, 463), PI * 0.5, Color(-1, 0, 0), Vehicle.Ownership.POLICE)
	var drv := PoliceDriver.new(3)
	drv.manager = game.police
	var g: CityGraph = city().graph
	drv.setup(g, game.lights, [g.nearest_node(Vector2(-220, 460), "drive"), g.nearest_node(Vector2(-330, 460), "drive")] as Array[int])
	u.ai_controller = drv
	u.driver = Vehicle.Driver.AI
	game.police.units.append(u)
	var ok: bool = await wait_until(func() -> bool: return busted[0], 10.0)
	assert_true(ok, "Festnahme erfolgt")
	await wait_seconds(4.0)
	var revier: Vector3 = city().poi_position("revier")
	assert_lt(p.global_position.distance_to(revier), 3.0, "Rücksetzpunkt am Polizeirevier")
	assert_eq(game.get_wanted_level(), 0, "Fahndung nach Festnahme beendet")
	assert_eq(GameState.money, money0 - 150, "Gebühr 150 €")
	assert_true(p.input_enabled, "Steuerung wieder frei")
	assert_true(game.missions.awaiting_retry, "Mission nach Festnahme gescheitert (Wiederholung möglich)")
	assert_true(game.missions.fail_reason.contains("festgenommen"), "Grund: festgenommen")


func test_ramming_police_is_crime() -> void:
	await start_city_game(false)
	var crimes: Array[String] = []
	EventBus.crime_reported.connect(func(k: String, _p: Vector3, _w: bool) -> void: crimes.append(k))
	var cop: Vehicle = game.spawn_vehicle("polizei", Vector3(-200, 0.1, 640), 0.0, Color(-1, 0, 0), Vehicle.Ownership.POLICE)
	var car: Vehicle = game.spawn_vehicle("kompakt", Vector3(-240, 0.1, 642.6), -PI * 0.5)
	await wait_physics(10)
	await enter(car)
	car.set_controls(1.0, 0.0, 0.0, false)
	var ok: bool = await wait_until(func() -> bool: return crimes.has("polizei_rammen"), 10.0)
	assert_true(ok, "Rammen eines Streifenwagens wird gemeldet")
	assert_gt(float(game.get_wanted_level()), 0.5, "Fahndung nach Rammen")
