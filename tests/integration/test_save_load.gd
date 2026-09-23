extends GameTestCase
## Speichern/Laden im Spiel: Rundreise (Geld, Aufträge, Bestzeiten, Position), sicherer Fortsetzungspunkt
## bei laufendem Auftrag und bei Fahndung, blockierte Position, Autosave, Pause und Karte.

const M1: String = "m01_erste_schicht"


func before_each() -> void:
	SaveManager.delete_save()
	await start_city_game()


func after_each() -> void:
	get_tree().paused = false
	await stop_game()
	App.pending_load = {}
	App.pending_message = ""
	SaveManager.delete_save()


## Simuliert "Fortsetzen" aus dem Hauptmenü, ohne die Testszene zu wechseln.
func _continue_into_new_game() -> Array[String]:
	await stop_game()
	var r: Dictionary = SaveManager.load_game()
	assert_true(r.ok, "Spielstand lesbar (%s)" % str(r.get("message", "")))
	GameState.reset_new_game()
	GameState.from_dict((r.data as Dictionary).get("state", {}))
	App.pending_load = (r.data as Dictionary).get("player", {})
	var notes: Array[String] = []
	var cb: Callable = func(t: String, _k: String) -> void: notes.append(t)
	EventBus.notify.connect(cb)
	game = (load("res://scenes/game.tscn") as PackedScene).instantiate() as Game
	game.world_mode = "city"
	game.ambient_life = false
	add_child(game)
	game.player.use_sim_input = true
	game.missions.auto_skip_dialog = true
	await wait_physics(20)
	EventBus.notify.disconnect(cb)
	return notes


func test_save_and_continue_roundtrip() -> void:
	GameState.add_money(333)
	GameState.complete_mission(M1, 250)
	GameState.submit_best_time("faecher_runde", 123.4)
	var target: Vector3 = Vector3(-20, city().ground_y(Vector2(-20, 470)), 470)
	game.player.global_position = target + Vector3.UP * 0.2
	await wait_seconds(1.5)
	var saved_pos: Vector3 = game.player.global_position
	var money: int = GameState.money
	var r: Dictionary = game.save_now()
	assert_true(r.ok, "Speichern erfolgreich")
	var notes: Array[String] = await _continue_into_new_game()
	assert_eq(GameState.money, money, "Geld wiederhergestellt")
	assert_true(GameState.is_mission_completed(M1), "Abgeschlossener Auftrag wiederhergestellt")
	assert_near(GameState.get_best_time("faecher_runde"), 123.4, 0.01, "Bestzeit wiederhergestellt")
	assert_lt(game.player.global_position.distance_to(saved_pos), 1.0, "Position wiederhergestellt")
	assert_false(game.missions.is_available(M1), "Auftrag 1 bleibt erledigt")
	assert_true(game.missions.is_available("m02_faecher_runde"), "Auftrag 2 bleibt freigeschaltet")
	assert_true(notes.has("Spielstand geladen."), "Meldung beim Laden (%s)" % str(notes))


func test_save_during_mission_restarts_at_giver() -> void:
	assert_true(game.missions.start_mission(M1), "Auftrag 1 läuft")
	await wait_until(func() -> bool: return game.missions.mission_vehicle("van") != null, 20.0)
	await enter(game.missions.mission_vehicle("van"))
	game.missions.mission_vehicle("van").teleport_to(Vector3(100, 0.2, 462.6), -PI * 0.5)
	await wait_physics(10)
	assert_true(game.save_now().ok, "Speichern während des Auftrags")
	var notes: Array[String] = await _continue_into_new_game()
	var giver_xf: Transform3D = game.missions.giver_start_transform(M1)
	assert_lt(game.player.global_position.distance_to(giver_xf.origin), 1.5, "Fortsetzung beim Auftraggeber")
	assert_false(game.player.is_in_vehicle(), "Zu Fuß")
	assert_true(game.missions.active == null, "Auftrag läuft nicht automatisch weiter")
	assert_true(game.missions.is_available(M1), "Auftrag kann neu begonnen werden")
	var found: bool = false
	for n: String in notes:
		if n.contains("Erste Schicht"):
			found = true
	assert_true(found, "Hinweis auf den unterbrochenen Auftrag (%s)" % str(notes))
	assert_eq(get_tree().get_nodes_in_group("mission_vehicles").size(), 0, "Kein altes Missionsfahrzeug")


func test_save_during_wanted_uses_safe_point() -> void:
	var safe: Vector3 = Vector3(-20, city().ground_y(Vector2(-20, 470)), 470)
	game.player.global_position = safe + Vector3.UP * 0.2
	await wait_seconds(2.0)
	var safe_actual: Vector3 = game.player.global_position
	game.player.global_position = Vector3(300, 0.2, 470)
	await wait_physics(10)
	game.set_wanted(2, "Test", game.player.global_position)
	var data: Dictionary = game.make_player_save()
	var p: Array = data.position
	assert_lt(Vector3(float(p[0]), float(p[1]), float(p[2])).distance_to(safe_actual), 1.0, "Bei Fahndung wird der letzte sichere Punkt gespeichert")


func test_blocked_position_falls_back_to_start() -> void:
	var inside: Vector3 = Vector3.INF
	for lot: Dictionary in BuildingBuilder.lots:
		if str(lot.get("removed", "")) == "" and not bool(lot.get("shop_street", false)):
			var c: Vector2 = lot.centroid
			inside = Vector3(c.x, 0.2, c.y)
			break
	assert_true(inside != Vector3.INF, "Gebäudeparzelle gefunden")
	var text: String = SaveCodec.encode(GameState.to_dict(), {"position": SaveCodec.vec3_to_array(inside), "yaw": 0.0, "health": 80.0})
	var f: FileAccess = FileAccess.open(SaveManager.save_path, FileAccess.WRITE)
	f.store_string(text)
	f.close()
	var notes: Array[String] = await _continue_into_new_game()
	var spawn: Vector3 = game.get_spawn_transform().origin
	assert_lt(game.player.global_position.distance_to(spawn), 1.5, "Blockierte Position -> Startpunkt")
	assert_near(game.player.health, 80.0, 3.0, "Lebenspunkte übernommen (inkl. Regeneration)")
	var found: bool = false
	for n: String in notes:
		if n.contains("blockiert"):
			found = true
	assert_true(found, "Hinweis auf blockierte Position")


func test_autosave_after_mission_completion() -> void:
	assert_false(SaveManager.has_save(), "Vorher kein Spielstand")
	GameState.complete_mission(M1, 250)
	game.on_mission_completed(M1)
	assert_true(SaveManager.has_save(), "Autosave geschrieben")
	var r: Dictionary = SaveManager.load_game()
	assert_true(r.ok, "Autosave lesbar")
	assert_true(((r.data as Dictionary).state.completed_missions as Array).has(M1), "Autosave enthält den Auftrag")


func test_pause_and_map_toggle() -> void:
	game.request_pause()
	await wait_physics(2)
	assert_true(game.pause_menu.is_open(), "Pausenmenü offen")
	assert_true(get_tree().paused, "Spiel pausiert")
	var p0: Vector3 = game.player.global_position
	game.player.sim_move = Vector2(0, -1)
	await wait_physics(30)
	assert_lt(game.player.global_position.distance_to(p0), 0.05, "Keine Bewegung während der Pause")
	game.player.sim_move = Vector2.ZERO
	game.pause_menu.close()
	assert_false(get_tree().paused, "Pause beendet")
	game.map_overlay.open()
	assert_true(get_tree().paused and game.map_overlay.is_open(), "Karte offen, Spiel pausiert")
	var s: Vector2 = game.map_overlay.view.world_to_screen(Vector2(0, 0))
	assert_true(Rect2(Vector2.ZERO, game.map_overlay.view.size).has_point(s) or game.map_overlay.view.size == Vector2.ZERO, "Schloss liegt im Kartenbereich")
	game.map_overlay.close()
	assert_false(get_tree().paused, "Karte geschlossen")
	assert_true(game.minimap != null and game.minimap.is_visible_in_tree(), "Minikarte sichtbar")
