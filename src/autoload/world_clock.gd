extends Node
## Spielzeit (Tageszeit) und Wetter. Zustand liegt in GameState (time_of_day, day, weather) und wird gespeichert.
## Tempo: Settings.time_speed Spielminuten pro Echtsekunde (Standard 1 -> ein Tag = 24 Minuten).
## Wetter: „Wechselnd“ (zufällige Übergänge) oder fest aus den Einstellungen; Übergänge werden weich überblendet.
## Abgeleitete Größen für Grafik/KI: night_factor, sun_elevation, rain, fog, cloud, wetness.

signal hour_changed(hour: int)
signal weather_changed(kind: String)

const KINDS: Array[String] = ["klar", "bewoelkt", "regen", "nebel"]
const LABELS: Dictionary = {"klar": "Klar", "bewoelkt": "Bewölkt", "regen": "Regen", "nebel": "Nebel"}
## Zielwerte je Wetter: Bewölkung, Regen, Nebel
const PROFILE: Dictionary = {
	"klar": [0.0, 0.0, 0.0], "bewoelkt": [0.75, 0.0, 0.15], "regen": [1.0, 1.0, 0.35], "nebel": [0.55, 0.0, 1.0],
}

var paused: bool = false                   ## Zeit angehalten (Cheat/Test)
var speed_mult: float = 1.0                ## zusätzlicher Faktor (Cheat „Zeitraffer“)
var cloud: float = 0.0
var rain: float = 0.0
var fog: float = 0.0
var wetness: float = 0.0                   ## Nässe der Straßen (trocknet langsam ab)
var _weather_timer: float = 600.0
var _last_hour: int = -1
var _rng := RandomNumberGenerator.new()


func _ready() -> void:
	_rng.seed = 424242
	snap_weather()


func _process(delta: float) -> void:
	if get_tree().paused:
		return
	advance(delta)


## Zeit und Wetter um delta Echtsekunden fortschreiben (auch von Tests aufrufbar).
func advance(delta: float) -> void:
	if not paused and Settings.time_speed > 0.0:
		var t: float = GameState.time_of_day + delta * Settings.time_speed * speed_mult / 60.0
		if t >= 24.0:
			GameState.day += 1
		GameState.time_of_day = fposmod(t, 24.0)
	var h: int = int(GameState.time_of_day)
	if h != _last_hour:
		_last_hour = h
		hour_changed.emit(h)
	# Wetterwechsel
	var forced: String = forced_weather()
	if forced != "" and forced != GameState.weather:
		set_weather(forced)
	elif forced == "":
		_weather_timer -= delta
		if _weather_timer <= 0.0:
			_weather_timer = _rng.randf_range(300.0, 900.0)
			var r: float = _rng.randf()
			set_weather("klar" if r < 0.45 else ("bewoelkt" if r < 0.72 else ("regen" if r < 0.9 else "nebel")))
	var target: Array = PROFILE.get(GameState.weather, PROFILE.klar)
	var k: float = clampf(delta * 0.12, 0.0, 1.0)
	cloud = lerpf(cloud, float(target[0]), k)
	rain = lerpf(rain, float(target[1]), k)
	fog = lerpf(fog, float(target[2]), k)
	if rain > 0.2:
		wetness = minf(1.0, wetness + delta * 0.05 * rain)
	else:
		wetness = maxf(0.0, wetness - delta * 0.004)


## Festes Wetter aus den Einstellungen (leer = wechselnd).
func forced_weather() -> String:
	return "" if Settings.weather_mode <= 0 else KINDS[clampi(Settings.weather_mode - 1, 0, 3)]


func set_weather(kind: String, immediate: bool = false) -> void:
	if not kind in KINDS:
		return
	GameState.weather = kind
	if immediate:
		snap_weather()
	weather_changed.emit(kind)


## Wetterwerte sofort auf das Ziel setzen (Laden, Cheats, Tests).
func snap_weather() -> void:
	var target: Array = PROFILE.get(GameState.weather, PROFILE.klar)
	cloud = float(target[0])
	rain = float(target[1])
	fog = float(target[2])
	wetness = 1.0 if rain > 0.5 else 0.0


func set_time(hours: float) -> void:
	GameState.time_of_day = fposmod(hours, 24.0)
	_last_hour = -1


## Sonnenhöhe in Grad (-90..90): Aufgang ~6:00, Untergang ~20:00, Höchststand ~13:00 (Mitteleuropa, Sommerzeit).
func sun_elevation() -> float:
	var d: float = fposmod(GameState.time_of_day - 13.0 + 12.0, 24.0) - 12.0   # Stunden seit Mittag, -12..12
	return 58.0 * cos(d / 7.0 * PI * 0.5)


## Sonnenazimut in Grad (0 = Norden, 90 = Osten, 180 = Süden, 270 = Westen).
func sun_azimuth() -> float:
	return fposmod(180.0 + (GameState.time_of_day - 13.0) * 15.0, 360.0)


## 0 = Tag, 1 = Nacht (weicher Übergang in der Dämmerung).
func night_factor() -> float:
	return clampf(inverse_lerp(6.0, -8.0, sun_elevation()), 0.0, 1.0)


func is_night() -> bool:
	return night_factor() > 0.5


func time_text() -> String:
	var t: float = GameState.time_of_day
	return "%02d:%02d" % [int(t), int(fmod(t, 1.0) * 60.0)]
