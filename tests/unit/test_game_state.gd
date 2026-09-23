extends TestCase
## GameState: Geld, einmalige Belohnungen, Bestzeiten, Serialisierung.


func before_each() -> void:
	GameState.reset_new_game()


func test_start_money() -> void:
	assert_eq(GameState.money, GameState.START_MONEY, "Startgeld")


func test_reward_only_once() -> void:
	var first: bool = GameState.complete_mission("m01", 250)
	var second: bool = GameState.complete_mission("m01", 250)
	assert_true(first, "Erster Abschluss muss als erster erkannt werden")
	assert_false(second, "Zweiter Abschluss darf nicht erneut belohnt werden")
	assert_eq(GameState.money, GameState.START_MONEY + 250, "Geld nach doppeltem Abschluss")


func test_money_never_negative() -> void:
	GameState.add_money(-100000)
	assert_eq(GameState.money, 0, "Geld nicht negativ")


func test_best_time_only_improves() -> void:
	assert_true(GameState.submit_best_time("m02", 90.0), "Erste Zeit ist Rekord")
	assert_false(GameState.submit_best_time("m02", 95.0), "Schlechtere Zeit kein Rekord")
	assert_true(GameState.submit_best_time("m02", 80.5), "Bessere Zeit ist Rekord")
	assert_near(GameState.get_best_time("m02"), 80.5, 0.001, "Bestzeit")
	assert_false(GameState.submit_best_time("m02", -1.0), "Ungültige Zeit")


func test_roundtrip_dict() -> void:
	GameState.complete_mission("m01", 250)
	GameState.submit_best_time("m02", 77.0)
	var d: Dictionary = GameState.to_dict()
	GameState.reset_new_game()
	GameState.from_dict(d)
	assert_true(GameState.is_mission_completed("m01"), "Mission nach Laden abgeschlossen")
	assert_near(GameState.get_best_time("m02"), 77.0, 0.001, "Bestzeit nach Laden")
	assert_eq(GameState.money, GameState.START_MONEY + 250, "Geld nach Laden")


func test_from_dict_tolerates_garbage() -> void:
	GameState.from_dict({"money": "abc", "completed_missions": "kaputt", "best_times": [1, 2], "play_time": -5})
	assert_eq(GameState.money, 0, "Ungültiges Geld -> 0 (int('abc') = 0)")
	assert_eq(GameState.completed_missions.size(), 0, "Keine Missionen aus Müll")
	assert_eq(GameState.best_times.size(), 0, "Keine Bestzeiten aus Müll")
