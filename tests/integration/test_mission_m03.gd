extends GameTestCase
## Mission 3 "Die falsche Lieferung": Abholung am Lager, geskriptete Fahndung Stufe 2, Abschütteln
## (ohne Sicht, Suchphase läuft ab), Abgabe in der Werkstatt nur ohne Fahndung und ohne Polizei in der Nähe.

const M1: String = "m01_erste_schicht"
const M3: String = "m03_falsche_lieferung"


func before_each() -> void:
	await start_city_game()
	GameState.complete_mission(M1, 0)


func after_each() -> void:
	await stop_game()


func _step_type() -> String:
	return str(game.missions._step.get("type", ""))


func _start_and_enter() -> Vehicle:
	var ms: MissionSystem = game.missions
	var giver: MissionGiver = ms.givers[M3]
	var p: Player = game.player
	p.global_position = giver.global_position + (-giver.global_basis.z) * 2.0 + Vector3.UP * 0.1
	await wait_physics(10)
	assert_true(interact_nearest(), "Auftrag bei Ewald angenommen")
	assert_true(await wait_until(func() -> bool: return ms.mission_vehicle("limo") != null and _step_type() == "enter_vehicle", 20.0), "Limousine bereit")
	var limo: Vehicle = ms.mission_vehicle("limo")
	assert_eq(limo.spec.id, "limousine", "Missionsfahrzeug ist die Limousine")
	assert_true(await enter(limo), "Eingestiegen")
	await wait_physics(5)
	return limo


## Abholung am Lager bis zur ausgelösten Fahndung. fast = direkt in die Zone versetzen.
func _pickup(limo: Vehicle, fast: bool) -> void:
	var ms: MissionSystem = game.missions
	var lager: Vector3 = city().poi_position("lager")
	if fast:
		limo.teleport_to(Vector3(-474, lager.y + 0.2, 590), PI * 0.5)
	else:
		# Aus dem Hof auf die Kutschergasse, dann über das Straßennetz zum Lagerhof
		var gate: PackedVector3Array = PackedVector3Array([Vector3(468, 0, 250), Vector3(451, 0, 250), Vector3(442.4, 0, 262)])
		assert_true(await drive_to(limo, Vector3(-474, 0, 590), gate, 13.0, 7.0, 170.0), "Lagerhof erreicht")
	assert_true(await wait_until(func() -> bool: return _step_type() == "lose_wanted", 15.0), "Kiste geladen, Fahndung ausgelöst")
	assert_eq(game.get_wanted_level(), 2, "Geskriptete Fahndungsstufe 2")


func test_m03_locked_until_m01() -> void:
	GameState.reset_new_game()
	assert_false(game.missions.is_available(M3), "Mission 3 ohne Mission 1 gesperrt")


func test_m03_full_playthrough() -> void:
	var ms: MissionSystem = game.missions
	game.police.patrol_enabled = false
	var money0: int = GameState.money
	var limo: Vehicle = await _start_and_enter()
	await _pickup(limo, false)
	# Polizei rückt an (außer Sicht erzeugt)
	assert_true(await wait_until(func() -> bool: return game.police.active_units() >= 1, 10.0), "Polizei rückt an")
	# Abschütteln: weit weg ohne Sichtkontakt, Suchphase an der zuletzt bekannten Position läuft ab
	limo.teleport_to(Vector3(563.5, 0.2, 120), 0.0)
	await wait_physics(30)
	assert_gt(game.police.police_goal().distance_to(limo.global_position), 300.0, "Polizei sucht nicht am neuen Ort")
	assert_true(await wait_until(func() -> bool: return _step_type() == "goto", 60.0), "Fahndung abgeschüttelt")
	assert_eq(game.get_wanted_level(), 0, "Fahndungsstufe 0")
	# Zur Werkstatt Mäule (Hof an der Karlstraße)
	var pts: PackedVector3Array = route_through(limo.global_position, -limo.global_basis.z, [Vector2(-470, 80)] as Array[Vector2])
	pts.append(Vector3(-472.6, 0, 66))
	pts.append(Vector3(-490, 0, 80))
	pts.append(Vector3(-505, 0, 80))
	var ok: bool = await follow_until(limo, pts, 14.0, func() -> bool: return ms.active == null or ms.awaiting_retry, 200.0)
	assert_true(ok, "Werkstatt erreicht und Mission beendet (Fahrzeug bei %s, Schritt %s, Ziel '%s')" % [str(limo.global_position.round()), _step_type(), ms.objective])
	assert_false(ms.awaiting_retry, "Kein Fehlschlag (%s)" % ms.fail_reason)
	assert_true(GameState.is_mission_completed(M3), "Als abgeschlossen gespeichert")
	assert_eq(GameState.money, money0 + 800, "Belohnung 800 €")
	assert_false(ms.is_available(M3), "Nicht erneut verfügbar")
	assert_false(ms.start_mission(M3), "Kein erneuter Start")
	assert_eq(GameState.money, money0 + 800, "Keine doppelte Belohnung")


func test_m03_no_completion_with_police_nearby() -> void:
	var ms: MissionSystem = game.missions
	game.police.patrol_enabled = false
	var limo: Vehicle = await _start_and_enter()
	await _pickup(limo, true)
	# Mit aktiver Fahndung in die Werkstatt: kein Abschluss
	var yard: Vector3 = city().poi_position("maeule")
	limo.teleport_to(Vector3(-500, yard.y + 0.2, 80), PI * 0.5)
	await wait_seconds(2.0)
	assert_eq(_step_type(), "lose_wanted", "Mit Fahndung kein Fortschritt")
	assert_true(ms.active != null, "Mission läuft weiter")
	# Fahndung weg, aber Streifenwagen < 60 m vor dem Hof: weiterhin kein Abschluss
	game.reset_wanted()
	var cop: Vehicle = game.spawn_vehicle("polizei", Vector3(-466.5, 0.1, 110), 0.0, Color(-1, 0, 0), Vehicle.Ownership.POLICE)
	game.police.units.append(cop)
	await wait_seconds(3.0)
	assert_eq(_step_type(), "goto", "Schritt: zur Werkstatt")
	assert_true(game.police_within(game.player.global_position, 60.0), "Polizei in der Nähe erkannt (Spielerposition folgt dem Fahrzeug)")
	assert_true(ms.active != null and _step_type() == "goto", "Kein Abschluss bei Polizei in der Nähe")
	assert_true(ms.objective.contains("Polizei"), "Hinweis: Polizei zu nah (%s)" % ms.objective)
	assert_false(GameState.is_mission_completed(M3), "Noch nicht abgeschlossen")
	# Streifenwagen fährt weg -> Abschluss
	game.police.units.erase(cop)
	cop.queue_free()
	assert_true(await wait_until(func() -> bool: return ms.active == null, 20.0), "Abschluss, sobald die Polizei weg ist")
	assert_true(GameState.is_mission_completed(M3), "Mission 3 abgeschlossen")


func test_m03_busted_fails_and_retry() -> void:
	var ms: MissionSystem = game.missions
	game.police.patrol_enabled = false
	var limo: Vehicle = await _start_and_enter()
	await _pickup(limo, true)
	EventBus.player_busted.emit()
	assert_true(await wait_until(func() -> bool: return ms.awaiting_retry, 5.0), "Festnahme -> Fehlschlag")
	await wait_seconds(4.0)
	ms.retry()
	await wait_physics(10)
	assert_true(ms.active != null and ms.active.id == M3, "Wiederholung gestartet")
	assert_eq(game.get_wanted_level(), 0, "Keine Fahndung nach Wiederholung")
	assert_true(await wait_until(func() -> bool: return ms.mission_vehicle("limo") != null, 5.0), "Neue Limousine bereit")
