extends TestCase
## Tageszeit und Wetter (WorldClock): Zeitlauf, Tageswechsel, Tag/Nacht-Faktor, Wetterübergänge, feste Wettervorgabe.

var _speed: float
var _mode: int


func before_each() -> void:
	GameState.reset_new_game()
	_speed = Settings.time_speed
	_mode = Settings.weather_mode
	WorldClock.paused = false
	WorldClock.speed_mult = 1.0


func after_each() -> void:
	Settings.time_speed = _speed
	Settings.weather_mode = _mode
	WorldClock.set_time(19.5)
	WorldClock.set_weather("klar", true)


func test_time_advances_and_day_rolls_over() -> void:
	Settings.time_speed = 1.0
	WorldClock.set_time(23.9)
	var d0: int = GameState.day
	WorldClock.advance(12.0)   # 12 Spielminuten
	assert_near(GameState.time_of_day, 0.1, 0.01, "Uhrzeit nach Mitternacht")
	assert_eq(GameState.day, d0 + 1, "Neuer Tag")


func test_paused_time_does_not_advance() -> void:
	WorldClock.set_time(10.0)
	WorldClock.paused = true
	WorldClock.advance(60.0)
	assert_near(GameState.time_of_day, 10.0, 0.0001, "Zeit angehalten")
	WorldClock.paused = false


func test_day_night_factor() -> void:
	WorldClock.set_time(13.0)
	assert_near(WorldClock.night_factor(), 0.0, 0.001, "Mittag = Tag")
	assert_gt(WorldClock.sun_elevation(), 50.0, "Sonne hoch am Mittag")
	WorldClock.set_time(23.5)
	assert_gt(WorldClock.night_factor(), 0.95, "Nacht um 23:30")
	WorldClock.set_time(20.3)
	var dusk: float = WorldClock.night_factor()
	assert_true(dusk > 0.0 and dusk < 1.0, "Dämmerung weich (%.2f)" % dusk)
	assert_true(WorldClock.sun_azimuth() > 240.0 and WorldClock.sun_azimuth() < 300.0, "Sonne im Westen am Abend (%.0f°)" % WorldClock.sun_azimuth())


func test_weather_transition_and_wetness() -> void:
	Settings.weather_mode = 0
	WorldClock.set_weather("klar", true)
	assert_near(WorldClock.rain, 0.0, 0.001, "Kein Regen bei klarem Wetter")
	WorldClock.set_weather("regen")
	for i: int in 60:
		WorldClock.advance(1.0)
	assert_gt(WorldClock.rain, 0.9, "Regen blendet ein")
	assert_gt(WorldClock.wetness, 0.5, "Straßen werden nass")
	WorldClock.set_weather("klar")
	for i2: int in 120:
		WorldClock.advance(1.0)
	assert_lt(WorldClock.rain, 0.05, "Regen hört auf")
	assert_gt(WorldClock.wetness, 0.0, "Straßen trocknen langsam")


func test_forced_weather_from_settings() -> void:
	Settings.weather_mode = 4   # Nebel
	WorldClock.advance(0.1)
	assert_eq(GameState.weather, "nebel", "Feste Wettervorgabe greift")
	Settings.weather_mode = 0
	assert_eq(WorldClock.forced_weather(), "", "Wechselnd = keine Vorgabe")


func test_state_in_save_dict() -> void:
	WorldClock.set_time(8.25)
	WorldClock.set_weather("bewoelkt", true)
	var d: Dictionary = GameState.to_dict()
	GameState.reset_new_game()
	GameState.from_dict(d)
	assert_near(GameState.time_of_day, 8.25, 0.001, "Uhrzeit gespeichert")
	assert_eq(GameState.weather, "bewoelkt", "Wetter gespeichert")
