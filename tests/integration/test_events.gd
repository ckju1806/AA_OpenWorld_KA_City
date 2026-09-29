extends GameTestCase
## Ereignis-Direktor (W7): Ereignisse starten und räumen sich auf, Optionen/Cheats schalten sie ab,
## Taschendieb stellen gibt Finderlohn, Anfahren von Beteiligten ist eine Straftat, Polizei-Einsatz und Straßensperre.


func before_each() -> void:
	await start_city_game(true)
	game.traffic.enabled = false
	Settings.events_gangs = true
	Settings.events_unrest = true
	Settings.events_police = true


func after_each() -> void:
	CheatManager.reset_all()
	await stop_game()


func _count_actors() -> int:
	return get_tree().get_nodes_in_group("event_actors").size()


func test_each_event_kind_starts_and_cleans_up() -> void:
	var ed: EventDirector = game.events
	ed.enabled = false
	var started: int = 0
	for kind: String in ["scuffle", "theft", "rally", "police_check", "race"]:
		var ev: GameEvent = ed.start_event(kind, game.player.global_position)
		if ev == null:
			fail("Ereignis %s nicht gestartet" % kind)
			continue
		started += 1
		await wait_physics(30)
		assert_false(ev.actors.is_empty() and ev.vehicles.is_empty(), "%s erzeugt Beteiligte" % kind)
		ev.done = true
		await wait_physics(3)
	assert_eq(started, 5, "Alle fünf Ereignisarten gestartet")
	assert_eq(ed.events.size(), 0, "Alle Ereignisse beendet")
	await wait_physics(3)
	assert_eq(_count_actors(), 0, "Keine Beteiligten übrig")


func test_disabled_by_settings_and_cheat() -> void:
	var ed: EventDirector = game.events
	Settings.events_gangs = false
	Settings.events_unrest = false
	Settings.events_police = false
	assert_eq(ed._pick_kind(ed.zone_at(game.player.global_position)), "", "Alle Kategorien aus -> kein Ereignis")
	Settings.events_gangs = true
	CheatManager.enter("RUHETAG")
	ed.cooldown = 0.0
	ed._tick = 0.0
	await wait_physics(30)
	assert_eq(ed.events.size(), 0, "Ruhetag: keine Zufallsereignisse")


func test_chaos_mode_triggers_events() -> void:
	var ed: EventDirector = game.events
	CheatManager.enter("CHAOSTAG")
	ed.cooldown = 0.0
	await wait_seconds(20.0)
	assert_gt(float(ed.started_total), 0.0, "Chaos-Modus startet Ereignisse")


func test_catch_thief_gives_reward_without_crime() -> void:
	var ed: EventDirector = game.events
	ed.enabled = false
	var money0: int = GameState.money
	var ev: EventsBasic.Theft = ed.start_event("theft", game.player.global_position) as EventsBasic.Theft
	assert_true(ev != null, "Diebstahl gestartet")
	await wait_physics(10)
	ev.thief.knock_down(true)
	await wait_physics(10)
	assert_eq(GameState.money, money0 + 80, "Finderlohn 80 €")
	assert_eq(game.get_wanted_level(), 0, "Dieb stellen ist keine Straftat")


func test_hitting_bystander_is_crime_and_police_dispatch() -> void:
	var ed: EventDirector = game.events
	ed.enabled = false
	var ev: GameEvent = ed.start_event("rally", game.player.global_position)
	if ev == null:
		ev = ed.start_event("scuffle", game.player.global_position)
	assert_true(ev != null, "Ereignis mit Beteiligten gestartet")
	await wait_physics(10)
	ev.actors[0].knock_down(true)
	await wait_physics(10)
	assert_gt(float(game.get_wanted_level()), 0.0, "Anfahren eines Beteiligten -> Fahndung")
	game.reset_wanted()
	var before: int = game.police.dispatch_units.size()
	game.police.dispatch(ev.pos, 20.0)
	assert_eq(game.police.dispatch_units.size(), before + 1, "Streife zum Einsatzort geschickt")
