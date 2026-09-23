extends GameTestCase
## Mission 2 "Die Fächer-Runde": Freischaltung, vollständige Runde per Autopilot über alle Kontrollpunkte,
## Bestzeit, Wiederholung ohne doppelte Belohnung, Zeitlimit-Fehlschlag + Wiederholung ohne Objektwachstum.

const M1: String = "m01_erste_schicht"
const M2: String = "m02_faecher_runde"


func before_each() -> void:
	await start_city_game()


func after_each() -> void:
	await stop_game()


func _start_via_giver() -> bool:
	var giver: MissionGiver = game.missions.givers[M2]
	var p: Player = game.player
	if p.is_in_vehicle():
		await wait_until(func() -> bool: return (p.current_vehicle as Vehicle).linear_velocity.length() < 1.0, 6.0)
		assert_true(p.toggle_vehicle(), "Ausgestiegen")
		await wait_physics(5)
	p.global_position = giver.global_position + (-giver.global_basis.z) * 2.0 + Vector3.UP * 0.1
	await wait_physics(10)
	return interact_nearest()


## Bis zum Start der Kontrollpunkte: Dialog, Fahrzeug, Einsteigen, Countdown.
func _to_race_start() -> Vehicle:
	var ms: MissionSystem = game.missions
	var ok: bool = await wait_until(func() -> bool: return ms.mission_vehicle("gt") != null and str(ms._step.get("type", "")) == "enter_vehicle", 20.0)
	assert_true(ok, "Rennwagen bereit")
	var gt: Vehicle = ms.mission_vehicle("gt")
	assert_true(await enter(gt), "In den Fächer GT eingestiegen")
	assert_true(await wait_until(func() -> bool: return str(ms._step.get("type", "")) == "checkpoints", 8.0), "Countdown abgelaufen")
	assert_true(game.player.input_enabled, "Steuerung nach Countdown frei")
	return gt


func _checkpoints() -> Array[Vector2]:
	var out: Array[Vector2] = []
	for s: Dictionary in game.missions.definitions[M2].steps:
		if str(s.get("type", "")) == "checkpoints":
			for c: Variant in s.points:
				out.append(Vector2(float(c[0]), float(c[1])))
	return out


func test_m02_locked_until_m01() -> void:
	var ms: MissionSystem = game.missions
	assert_false(ms.is_available(M2), "Mission 2 ohne Mission 1 gesperrt")
	assert_false(ms.start_mission(M2), "Kein Start ohne Voraussetzung")
	GameState.complete_mission(M1, 0)
	assert_true(ms.is_available(M2), "Mission 2 nach Mission 1 verfügbar")


func test_m02_full_race_best_time_and_repeat() -> void:
	var ms: MissionSystem = game.missions
	GameState.complete_mission(M1, 0)
	var money0: int = GameState.money
	assert_true(await _start_via_giver(), "Zeitfahren über Toni gestartet")
	var gt: Vehicle = await _to_race_start()
	assert_eq(gt.spec.id, "sport", "Missionsfahrzeug ist der Sportwagen")
	var cps: Array[Vector2] = _checkpoints()
	assert_gt(float(cps.size()), 9.5, "Mindestens 10 Kontrollpunkte")
	# Runde per Autopilot über das Straßennetz durch alle Kontrollpunkte
	var pts: PackedVector3Array = route_through(gt.global_position, -gt.global_basis.z, cps)
	var reached: Array[int] = [0]
	var ok: bool = await follow_until(gt, pts, 21.0, func() -> bool:
		reached[0] = maxi(reached[0], int(ms._st.get("idx", reached[0])) if ms.active != null else reached[0])
		return ms.active == null or ms.awaiting_retry, 260.0)
	assert_true(ok, "Runde beendet (erreicht: %d Kontrollpunkte)" % reached[0])
	assert_false(ms.awaiting_retry, "Kein Fehlschlag (%s)" % ms.fail_reason)
	assert_true(await wait_until(func() -> bool: return ms.active == null, 20.0), "Abschlussdialog beendet")
	var best: float = GameState.get_best_time("faecher_runde")
	assert_gt(best, 30.0, "Bestzeit gespeichert (%.1f s)" % best)
	assert_lt(best, 210.0, "Bestzeit innerhalb des Zeitlimits")
	assert_eq(GameState.money, money0 + 400, "Belohnung 400 € beim ersten Abschluss")
	assert_true(GameState.is_mission_completed(M2), "Als abgeschlossen gespeichert")
	print("        Fächer-Runde per Autopilot: %.1f s" % best)
	# Wiederholung: Mission bleibt verfügbar, keine erneute Belohnung, schnellere Zeit ersetzt Bestzeit
	assert_true(ms.is_available(M2), "Zeitfahren wiederholbar")
	await wait_physics(10)
	assert_true(await _start_via_giver(), "Erneut gestartet")
	var gt2: Vehicle = await _to_race_start()
	for c: Vector2 in cps:
		gt2.teleport_to(Vector3(c.x, city().ground_y(c) + 0.2, c.y), gt2.rotation.y)
		await wait_physics(12)
	assert_true(await wait_until(func() -> bool: return ms.active == null, 20.0), "Zweite Runde beendet")
	assert_eq(GameState.money, money0 + 400, "Keine doppelte Belohnung")
	var best2: float = GameState.get_best_time("faecher_runde")
	assert_lt(best2, best, "Schnellere Zeit ersetzt Bestzeit (%.1f < %.1f)" % [best2, best])
	assert_eq(get_tree().get_nodes_in_group("mission_vehicles").size(), 0, "Keine Missionsfahrzeuge aktiv")


func test_m02_time_limit_fail_and_retry() -> void:
	var ms: MissionSystem = game.missions
	GameState.complete_mission(M1, 0)
	var money0: int = GameState.money
	var vehicles0: int = get_tree().get_nodes_in_group("vehicles").size()
	assert_true(await _start_via_giver(), "Gestartet")
	for round_i: int in 2:
		await _to_race_start()
		ms._st["time"] = 209.5
		assert_true(await wait_until(func() -> bool: return ms.awaiting_retry, 3.0), "Zeitlimit überschritten (Runde %d)" % round_i)
		assert_true(ms.fail_reason.contains("Zeit"), "Grund: Zeit")
		await wait_physics(5)
		ms.retry()
		await wait_physics(5)
		assert_true(ms.active != null, "Neu gestartet (Runde %d)" % round_i)
	await wait_physics(10)
	assert_eq(get_tree().get_nodes_in_group("vehicles").size(), vehicles0 + 1, "Genau ein Missionsfahrzeug nach Wiederholungen")
	assert_lt(GameState.get_best_time("faecher_runde"), 0.0, "Keine Bestzeit bei Fehlschlag")
	assert_eq(GameState.money, money0, "Keine Belohnung bei Fehlschlag")
