extends GameTestCase
## Mission 1 "Erste Schicht": vollständiger automatischer Durchlauf, einmalige Belohnung,
## Fehlschlag + Wiederholung ohne Objektwachstum.

const M1: String = "m01_erste_schicht"


func before_each() -> void:
	await start_city_game()


func after_each() -> void:
	await stop_game()


func _talk_to_giver() -> bool:
	var giver: MissionGiver = game.missions.givers[M1]
	var p: Player = game.player
	p.global_position = giver.global_position + (-giver.global_basis.z) * 2.0 + Vector3.UP * 0.1
	await wait_physics(10)
	return interact_nearest()


func test_m01_full_playthrough() -> void:
	var ms: MissionSystem = game.missions
	var money0: int = GameState.money
	assert_true(ms.is_available(M1), "Mission 1 verfügbar")
	assert_false(ms.is_available("m02_faecher_runde"), "Mission 2 erst nach Mission 1")
	assert_true(await _talk_to_giver(), "Auftrag über Interaktion angenommen")
	assert_true(ms.active != null and ms.active.id == M1, "Mission aktiv")
	# Dialog läuft automatisch durch, Lieferwagen wird erzeugt
	assert_true(await wait_until(func() -> bool: return ms.mission_vehicle("van") != null and str(ms._step.get("type", "")) == "enter_vehicle", 20.0), "Lieferwagen bereit")
	var van: Vehicle = ms.mission_vehicle("van")
	assert_eq(van.spec.id, "transporter", "Lieferwagen ist Transporter")
	assert_true(await enter(van), "In Lieferwagen eingestiegen")
	await wait_physics(5)
	assert_eq(str(ms._step.get("type", "")), "goto", "Schritt: zur Bäckerei fahren")
	# Aus dem Hof auf die Waldstraße, dann über das Straßennetz zur Bäckerei
	var gate: PackedVector3Array = PackedVector3Array([Vector3(-306, 0, 500), Vector3(-326.5, 0, 497)])
	var bakery: Vector3 = city().poi_position("baeckerei_parken")
	assert_true(await drive_to(van, Vector3(218.0, 0, 500), gate, 13.0, 7.0), "Bäckerei erreicht")
	assert_true(await wait_until(func() -> bool: return str(ms._step.get("type", "")) == "goto" and ms.step_index >= 6, 12.0), "Sendung eingeladen (Haltezone)")
	# Zur Kanzlei
	assert_true(await drive_to(van, Vector3(20.0, 0, 462.6), PackedVector3Array(), 12.0, 7.0), "Kanzlei erreicht")
	assert_true(await wait_until(func() -> bool: return str(ms._step.get("type", "")) == "exit_vehicle", 8.0), "Schritt: aussteigen")
	assert_true(game.player.toggle_vehicle(), "Ausgestiegen")
	await wait_physics(20)
	assert_true(await wait_until(func() -> bool: return str(ms._step.get("type", "")) == "interact", 5.0), "Schritt: abgeben")
	var door: Vector3 = city().poi_position("kanzlei")
	assert_true(await walk_to(door, 1.5, 40.0), "Zur Kanzleitür gegangen")
	await wait_physics(8)
	assert_true(interact_nearest(), "Sendung abgegeben (E)")
	assert_true(await wait_until(func() -> bool: return ms.active == null, 20.0), "Mission beendet")
	assert_true(GameState.is_mission_completed(M1), "Mission als abgeschlossen gespeichert")
	assert_eq(GameState.money, money0 + 250, "Belohnung 250 €")
	assert_eq(get_tree().get_nodes_in_group("mission_vehicles").size(), 0, "Keine Missionsfahrzeuge mehr aktiv")
	# Keine erneute Annahme / Belohnung
	assert_false(ms.is_available(M1), "Mission 1 nicht erneut verfügbar")
	assert_false(ms.start_mission(M1), "Kein erneuter Start")
	assert_eq(GameState.money, money0 + 250, "Keine doppelte Belohnung")
	assert_true(ms.is_available("m02_faecher_runde") or not ms.definitions.has("m02_faecher_runde"), "Mission 2 freigeschaltet")
	print("        Mission 1 durchgespielt, Spielzeit %.0f s simuliert" % GameState.play_time)


func test_m01_fail_and_retry_without_growth() -> void:
	var ms: MissionSystem = game.missions
	var vehicles0: int = get_tree().get_nodes_in_group("vehicles").size()
	assert_true(await _talk_to_giver(), "Auftrag angenommen")
	for round_i: int in 3:
		assert_true(await wait_until(func() -> bool: return ms.mission_vehicle("van") != null and ms.step_index >= 2, 20.0), "Lieferwagen da (Runde %d)" % round_i)
		var van: Vehicle = ms.mission_vehicle("van")
		assert_true(await enter(van), "Eingestiegen (Runde %d)" % round_i)
		await wait_physics(5)
		van.apply_damage(99999.0)
		assert_true(await wait_until(func() -> bool: return ms.awaiting_retry, 5.0), "Fehlschlag erkannt (Runde %d)" % round_i)
		assert_true(ms.fail_reason.contains("Fahrzeug"), "Fehlergrund nennt Fahrzeug")
		assert_false(game.player.is_in_vehicle(), "Spieler nicht mehr im Wrack")
		await wait_physics(5)
		ms.retry()
		await wait_physics(5)
		assert_true(ms.active != null, "Mission neu gestartet (Runde %d)" % round_i)
	await wait_physics(10)
	var vehicles1: int = get_tree().get_nodes_in_group("vehicles").size()
	assert_eq(vehicles1, vehicles0 + 1, "Genau ein Missionsfahrzeug nach 3 Wiederholungen")
	assert_eq(GameState.money, GameState.START_MONEY, "Keine Belohnung bei Fehlschlägen")
	ms.fail("Test-Ende")
	ms.abort()
	await wait_physics(5)
	assert_eq(get_tree().get_nodes_in_group("vehicles").size(), vehicles0, "Nach Abbruch keine Missionsfahrzeuge übrig")


func test_mission_data_valid() -> void:
	for d: MissionDefinition in game.missions.definitions.values():
		var errs: Array[String] = d.validate(city().graph)
		assert_true(errs.is_empty(), "Missionsdaten %s: %s" % [d.id, ", ".join(errs)])
