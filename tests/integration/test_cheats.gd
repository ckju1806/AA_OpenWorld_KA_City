extends GameTestCase
## Cheat-Manager: Codes per Konsole und per Tippen, Schalt-Cheats, Sperre in den Optionen, Rücksetzen, Teleport.


func before_each() -> void:
	await start_city_game()
	Settings.cheats_enabled = true
	CheatManager.reset_all()


func after_each() -> void:
	CheatManager.reset_all()
	Settings.cheats_enabled = true
	await stop_game()


func test_unknown_code_and_disabled() -> void:
	assert_eq(CheatManager.enter("GIBTESNICHT"), "", "Unbekannter Code -> keine Wirkung")
	Settings.cheats_enabled = false
	var money0: int = GameState.money
	var msg: String = CheatManager.enter("GELDREGEN")
	assert_true(msg.contains("deaktiviert"), "Hinweis bei deaktivierten Cheats")
	assert_eq(GameState.money, money0, "Kein Geld bei deaktivierten Cheats")


func test_money_health_and_flag() -> void:
	var money0: int = GameState.money
	CheatManager.enter("geldregen")
	assert_eq(GameState.money, money0 + 10000, "Geldregen")
	game.player.set_health(20.0)
	CheatManager.enter("GESUNDBRUNNEN")
	assert_near(game.player.health, Player.MAX_HEALTH, 0.01, "Volle Gesundheit")
	assert_true(bool(GameState.get_flag("cheats_used")), "Cheat-Nutzung vermerkt")


func test_toggle_invulnerable_and_reset() -> void:
	CheatManager.enter("UNVERWUNDBAR")
	assert_true(CheatManager.is_active("UNVERWUNDBAR"), "Schalter an")
	game.player.take_damage(50.0, "Test")
	assert_near(game.player.health, Player.MAX_HEALTH, 0.01, "Kein Schaden")
	CheatManager.enter("UNVERWUNDBAR")
	assert_false(CheatManager.is_active("UNVERWUNDBAR"), "Schalter aus")
	game.player.take_damage(50.0, "Test")
	assert_lt(game.player.health, Player.MAX_HEALTH, "Wieder Schaden")
	CheatManager.enter("ZEITSTOPP")
	CheatManager.enter("SUPERSPRUNG")
	CheatManager.enter("ALLESZURUECK")
	assert_true(CheatManager.active.is_empty(), "Alle Schalter zurückgesetzt")
	assert_false(WorldClock.paused, "Zeitstopp aufgehoben")


func test_typing_activates_code() -> void:
	var money0: int = GameState.money
	for ch: String in "xxGELDREGEN":
		var ev := InputEventKey.new()
		ev.pressed = true
		ev.unicode = ch.unicode_at(0)
		CheatManager._unhandled_input(ev)
	assert_eq(GameState.money, money0 + 10000, "Code per Tippen erkannt")


func test_time_weather_and_density() -> void:
	CheatManager.enter("KARLSRUHESCHLAEFT")
	assert_true(WorldClock.is_night(), "Nacht gesetzt")
	CheatManager.enter("DAUERREGEN")
	assert_eq(GameState.weather, "regen", "Regen gesetzt")
	CheatManager.enter("LEERESTADT")
	assert_eq(Settings.max_traffic(), 0, "Leere Stadt: kein Verkehr")
	CheatManager.enter("RUSHHOUR")
	assert_false(CheatManager.is_active("LEERESTADT"), "Dichte-Cheats schließen sich aus")
	assert_gt(float(Settings.max_traffic()), 20.0, "Berufsverkehr: mehr Verkehr")
	WorldClock.set_weather("klar", true)
	WorldClock.set_time(19.5)


func test_spawn_car_and_teleport() -> void:
	var n0: int = get_tree().get_nodes_in_group("vehicles").size()
	CheatManager.enter("FAECHERFLITZER")
	await wait_physics(5)
	assert_eq(get_tree().get_nodes_in_group("vehicles").size(), n0 + 1, "Sportwagen erzeugt")
	CheatManager.enter("ZUMBAHNHOF")
	await wait_physics(5)
	var hbf: Vector2 = Vector2.ZERO
	for lm: Variant in city().graph.layout.landmarks:
		if str(lm.type) == "hauptbahnhof":
			hbf = Vector2(float(lm.pos[0]), float(lm.pos[1]))
	var pp: Vector3 = game.player.global_position
	assert_lt(Vector2(pp.x, pp.z).distance_to(hbf), 150.0, "Teleport zum Hauptbahnhof")
	assert_gt(pp.y, -0.5, "Nicht unter dem Boden")
