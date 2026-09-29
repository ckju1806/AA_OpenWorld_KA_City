extends Node
## Spieleinstellungen v2 (lokal in user://settings.cfg). Kategorien: A Grafik, B Audio, C Steuerung (inkl. Tastenbelegung),
## D Spielablauf, E Barrierefreiheit/Anzeige. Fehlende/ungültige Werte -> Standardwerte; v1-Dateien werden übernommen.

signal changed

const PATH: String = "user://settings.cfg"
const VERSION: int = 2
const QUALITY_NAMES: Array[String] = ["Niedrig", "Mittel", "Hoch", "Ultra", "Benutzerdefiniert"]
const AA_NAMES: Array[String] = ["Aus", "FXAA", "TAA", "MSAA 2x", "MSAA 4x"]
const SHADOW_NAMES: Array[String] = ["Aus", "Niedrig", "Mittel", "Hoch"]
const WINDOW_NAMES: Array[String] = ["Fenster", "Vollbild", "Randloses Fenster"]
const WEATHER_NAMES: Array[String] = ["Wechselnd", "Klar", "Bewölkt", "Regen", "Nebel"]
const DIFFICULTY_NAMES: Array[String] = ["Leicht", "Normal", "Schwer"]
const COLORBLIND_NAMES: Array[String] = ["Aus", "Deuteranopie", "Protanopie", "Tritanopie"]
const FPS_LIMITS: Array[int] = [0, 30, 60, 90, 120, 144]

# ---------------------------------------------------------------- A Grafik
var quality: int = 1                       ## Voreinstellung 0..3; 4 = benutzerdefiniert
var window_mode: int = 0
var vsync: bool = true
var fps_limit: int = 0                     ## 0 = unbegrenzt
var render_scale: float = 1.0              ## 0.5 .. 1.0
var antialias: int = 1
var shadows: int = 2
var view_distance_m: float = 750.0         ## 350 .. 1600
var ssao: bool = false
var ssil: bool = false
var glow: bool = true
var volumetric_fog: bool = false
var vegetation: float = 1.0                ## 0.0 .. 1.5
var fov: float = 70.0                      ## 55 .. 100
var show_fps: bool = false
# ---------------------------------------------------------------- B Audio
var master_volume: float = 0.8
var music_volume: float = 0.5
var sfx_volume: float = 0.8
var ambience_volume: float = 0.7
var ui_volume: float = 0.8
# ---------------------------------------------------------------- C Steuerung
var mouse_sensitivity: float = 0.22        ## Grad pro Pixel
var invert_y: bool = false
var camera_autocenter: bool = true         ## Kamera folgt beim Fahren automatisch
var bindings: Dictionary = {}              ## Aktion -> Array[int] (physische Tastencodes)
# ---------------------------------------------------------------- D Spielablauf
var traffic_density: float = 1.0           ## 0.25 .. 1.5
var pedestrian_density: float = 1.0        ## 0.25 .. 1.5
var animal_density: float = 1.0            ## 0.0 .. 1.5
var police_difficulty: int = 1
var events_gangs: bool = true
var events_unrest: bool = true
var events_police: bool = true
var event_frequency: float = 1.0           ## 0.25 .. 2.0
var cheats_enabled: bool = true
var time_speed: float = 1.0                ## Spielminuten pro Echtsekunde (0 = Zeit angehalten)
var weather_mode: int = 0
var autosave: bool = true
var speed_mph: bool = false
var assist_markers: bool = true
var simplified_missions: bool = false
# ---------------------------------------------------------------- E Barrierefreiheit / Anzeige
var subtitles: bool = true
var ui_scale: float = 1.0                  ## 0.8 .. 1.5
var hud_opacity: float = 1.0               ## 0.3 .. 1.0
var minimap: bool = true
var camera_shake: bool = true
var colorblind: int = 0

## Kompatibilität (v1-Name)
var fullscreen: bool:
	get:
		return window_mode == 1
	set(v):
		window_mode = 1 if v else 0


func _enter_tree() -> void:
	bindings = InputSetup.default_bindings()
	load_settings()
	InputSetup.register(bindings)


func _ready() -> void:
	apply()


## Voreinstellung übernehmen (setzt die abhängigen Grafikwerte).
func apply_preset(q: int) -> void:
	quality = clampi(q, 0, 4)
	if quality == 4:
		return
	var p: Dictionary = preset_values(quality)
	for k: String in p:
		set(k, p[k])


static func preset_values(q: int) -> Dictionary:
	match q:
		0:
			return {"shadows": 1, "view_distance_m": 450.0, "ssao": false, "ssil": false, "glow": false, "volumetric_fog": false,
				"antialias": 1, "render_scale": 0.8, "vegetation": 0.6}
		1:
			return {"shadows": 2, "view_distance_m": 750.0, "ssao": false, "ssil": false, "glow": true, "volumetric_fog": false,
				"antialias": 1, "render_scale": 1.0, "vegetation": 1.0}
		2:
			return {"shadows": 3, "view_distance_m": 1100.0, "ssao": true, "ssil": false, "glow": true, "volumetric_fog": false,
				"antialias": 2, "render_scale": 1.0, "vegetation": 1.2}
		_:
			return {"shadows": 3, "view_distance_m": 1500.0, "ssao": true, "ssil": true, "glow": true, "volumetric_fog": true,
				"antialias": 2, "render_scale": 1.0, "vegetation": 1.5}


## Stufe für interne Budgets (0..3); bei „benutzerdefiniert“ aus der Sichtweite abgeleitet.
func level() -> int:
	if quality < 4:
		return quality
	return 0 if view_distance_m < 600.0 else (1 if view_distance_m < 950.0 else (2 if view_distance_m < 1300.0 else 3))


func load_settings(path: String = PATH) -> void:
	var cf := ConfigFile.new()
	if cf.load(path) != OK:
		apply_preset(quality)
		return
	var ver: int = int(cf.get_value("meta", "version", 1))
	# A Grafik
	quality = clampi(int(cf.get_value("video", "quality", quality)), 0, 4)
	apply_preset(quality)
	if ver >= 2:
		window_mode = clampi(int(cf.get_value("video", "window_mode", window_mode)), 0, 2)
		fps_limit = int(cf.get_value("video", "fps_limit", fps_limit))
		if not FPS_LIMITS.has(fps_limit):
			fps_limit = 0
		render_scale = clampf(float(cf.get_value("video", "render_scale", render_scale)), 0.5, 1.0)
		antialias = clampi(int(cf.get_value("video", "antialias", antialias)), 0, 4)
		shadows = clampi(int(cf.get_value("video", "shadows", shadows)), 0, 3)
		view_distance_m = clampf(float(cf.get_value("video", "view_distance", view_distance_m)), 350.0, 1600.0)
		ssao = bool(cf.get_value("video", "ssao", ssao))
		ssil = bool(cf.get_value("video", "ssil", ssil))
		glow = bool(cf.get_value("video", "glow", glow))
		volumetric_fog = bool(cf.get_value("video", "volumetric_fog", volumetric_fog))
		fov = clampf(float(cf.get_value("video", "fov", fov)), 55.0, 100.0)
	else:
		window_mode = 1 if bool(cf.get_value("video", "fullscreen", false)) else 0
	vsync = bool(cf.get_value("video", "vsync", vsync))
	show_fps = bool(cf.get_value("video", "show_fps", show_fps))
	vegetation = clampf(float(cf.get_value("video", "vegetation", vegetation)), 0.0, 1.5)
	# B Audio
	master_volume = clampf(float(cf.get_value("audio", "master", master_volume)), 0.0, 1.0)
	music_volume = clampf(float(cf.get_value("audio", "music", music_volume)), 0.0, 1.0)
	sfx_volume = clampf(float(cf.get_value("audio", "sfx", sfx_volume)), 0.0, 1.0)
	ambience_volume = clampf(float(cf.get_value("audio", "ambience", ambience_volume)), 0.0, 1.0)
	ui_volume = clampf(float(cf.get_value("audio", "ui", ui_volume)), 0.0, 1.0)
	# C Steuerung
	mouse_sensitivity = clampf(float(cf.get_value("input", "mouse_sensitivity", mouse_sensitivity)), 0.02, 1.0)
	invert_y = bool(cf.get_value("input", "invert_y", invert_y))
	camera_autocenter = bool(cf.get_value("input", "camera_autocenter", camera_autocenter))
	if cf.has_section("keys"):
		for action: String in cf.get_section_keys("keys"):
			if not bindings.has(action):
				continue
			var v: Variant = cf.get_value("keys", action, [])
			if v is Array:
				var keys: Array[int] = []
				for k: Variant in v:
					if int(k) > 0:
						keys.append(int(k))
				bindings[action] = keys
	# D Spielablauf
	traffic_density = clampf(float(cf.get_value("game", "traffic_density", traffic_density)), 0.25, 1.5)
	pedestrian_density = clampf(float(cf.get_value("game", "pedestrian_density", pedestrian_density)), 0.25, 1.5)
	animal_density = clampf(float(cf.get_value("game", "animal_density", animal_density)), 0.0, 1.5)
	police_difficulty = clampi(int(cf.get_value("game", "police_difficulty", police_difficulty)), 0, 2)
	events_gangs = bool(cf.get_value("game", "events_gangs", events_gangs))
	events_unrest = bool(cf.get_value("game", "events_unrest", events_unrest))
	events_police = bool(cf.get_value("game", "events_police", events_police))
	event_frequency = clampf(float(cf.get_value("game", "event_frequency", event_frequency)), 0.25, 2.0)
	cheats_enabled = bool(cf.get_value("game", "cheats_enabled", cheats_enabled))
	time_speed = clampf(float(cf.get_value("game", "time_speed", time_speed)), 0.0, 10.0)
	weather_mode = clampi(int(cf.get_value("game", "weather_mode", weather_mode)), 0, 4)
	autosave = bool(cf.get_value("game", "autosave", autosave))
	speed_mph = bool(cf.get_value("game", "speed_mph", speed_mph))
	assist_markers = bool(cf.get_value("game", "assist_markers", assist_markers))
	simplified_missions = bool(cf.get_value("game", "simplified_missions", simplified_missions))
	# E Barrierefreiheit
	subtitles = bool(cf.get_value("access", "subtitles", subtitles))
	ui_scale = clampf(float(cf.get_value("access", "ui_scale", ui_scale)), 0.8, 1.5)
	hud_opacity = clampf(float(cf.get_value("access", "hud_opacity", hud_opacity)), 0.3, 1.0)
	minimap = bool(cf.get_value("access", "minimap", minimap))
	camera_shake = bool(cf.get_value("access", "camera_shake", camera_shake))
	colorblind = clampi(int(cf.get_value("access", "colorblind", colorblind)), 0, 3)


func save_settings(path: String = PATH) -> void:
	var cf := ConfigFile.new()
	cf.set_value("meta", "version", VERSION)
	for pair: Array in [["quality", quality], ["window_mode", window_mode], ["vsync", vsync], ["fps_limit", fps_limit],
			["render_scale", render_scale], ["antialias", antialias], ["shadows", shadows], ["view_distance", view_distance_m],
			["ssao", ssao], ["ssil", ssil], ["glow", glow], ["volumetric_fog", volumetric_fog], ["vegetation", vegetation],
			["fov", fov], ["show_fps", show_fps]]:
		cf.set_value("video", pair[0], pair[1])
	for pair2: Array in [["master", master_volume], ["music", music_volume], ["sfx", sfx_volume], ["ambience", ambience_volume],
			["ui", ui_volume]]:
		cf.set_value("audio", pair2[0], pair2[1])
	cf.set_value("input", "mouse_sensitivity", mouse_sensitivity)
	cf.set_value("input", "invert_y", invert_y)
	cf.set_value("input", "camera_autocenter", camera_autocenter)
	for action: String in bindings:
		cf.set_value("keys", action, bindings[action])
	for pair3: Array in [["traffic_density", traffic_density], ["pedestrian_density", pedestrian_density],
			["animal_density", animal_density], ["police_difficulty", police_difficulty], ["events_gangs", events_gangs],
			["events_unrest", events_unrest], ["events_police", events_police], ["event_frequency", event_frequency],
			["cheats_enabled", cheats_enabled], ["time_speed", time_speed], ["weather_mode", weather_mode], ["autosave", autosave],
			["speed_mph", speed_mph], ["assist_markers", assist_markers], ["simplified_missions", simplified_missions]]:
		cf.set_value("game", pair3[0], pair3[1])
	for pair4: Array in [["subtitles", subtitles], ["ui_scale", ui_scale], ["hud_opacity", hud_opacity], ["minimap", minimap],
			["camera_shake", camera_shake], ["colorblind", colorblind]]:
		cf.set_value("access", pair4[0], pair4[1])
	var err: Error = cf.save(path)
	if err != OK:
		push_warning("Einstellungen konnten nicht gespeichert werden: %s" % error_string(err))


## Alle Einstellungen auf Standard zurücksetzen (Tastenbelegung eingeschlossen).
func reset_to_defaults() -> void:
	var fresh: Node = (load("res://src/autoload/settings.gd") as GDScript).new()
	for prop: Dictionary in get_property_list():
		if prop.usage & PROPERTY_USAGE_SCRIPT_VARIABLE and prop.name != "fullscreen":
			set(prop.name, fresh.get(prop.name))
	fresh.free()
	bindings = InputSetup.default_bindings()
	apply_preset(1)


func set_binding(action: String, keys: Array[int]) -> void:
	bindings[action] = keys
	InputSetup.register(bindings)


## Aktionen, die dieselbe Taste nutzen würden (Konfliktprüfung; manche Paare sind erlaubt, z. B. Springen/Handbremse).
func binding_conflicts(action: String, key: int) -> Array[String]:
	var out: Array[String] = []
	for other: String in bindings:
		if other == action or InputSetup.may_share(action, other):
			continue
		if (bindings[other] as Array).has(key):
			out.append(other)
	return out


func apply() -> void:
	_apply_bus("Master", master_volume)
	_apply_bus("Musik", music_volume)
	_apply_bus("Effekte", sfx_volume)
	_apply_bus("Umgebung", sfx_volume * ambience_volume / 0.7 if ambience_volume > 0.0 else 0.0)
	_apply_bus("UI", ui_volume)
	Engine.max_fps = fps_limit
	if DisplayServer.get_name() != "headless":
		var mode: DisplayServer.WindowMode = DisplayServer.WINDOW_MODE_WINDOWED
		if window_mode == 1:
			mode = DisplayServer.WINDOW_MODE_EXCLUSIVE_FULLSCREEN
		elif window_mode == 2:
			mode = DisplayServer.WINDOW_MODE_FULLSCREEN
		if DisplayServer.window_get_mode() != mode:
			DisplayServer.window_set_mode(mode)
		DisplayServer.window_set_vsync_mode(DisplayServer.VSYNC_ENABLED if vsync else DisplayServer.VSYNC_DISABLED)
	var root: Window = get_tree().root if is_inside_tree() else null
	if root != null:
		root.scaling_3d_scale = render_scale
		root.screen_space_aa = Viewport.SCREEN_SPACE_AA_FXAA if antialias == 1 else Viewport.SCREEN_SPACE_AA_DISABLED
		root.use_taa = antialias == 2
		root.msaa_3d = Viewport.MSAA_2X if antialias == 3 else (Viewport.MSAA_4X if antialias == 4 else Viewport.MSAA_DISABLED)
		root.content_scale_factor = ui_scale
	InputSetup.register(bindings)
	changed.emit()


func _apply_bus(bus_name: String, value: float) -> void:
	var idx: int = AudioServer.get_bus_index(bus_name)
	if idx < 0:
		return
	AudioServer.set_bus_volume_db(idx, linear_to_db(maxf(value, 0.0001)))
	AudioServer.set_bus_mute(idx, value <= 0.001)


## Qualitätsabhängige Werte (von Welt/Umgebung abgefragt).
func shadow_distance() -> float:
	return [0.0, 90.0, 170.0, 280.0][shadows]


func view_distance() -> float:
	return view_distance_m


func prop_visibility() -> float:
	return [90.0, 160.0, 240.0, 320.0][level()]


func max_traffic() -> int:
	return int(round([8.0, 14.0, 18.0, 24.0][level()] * traffic_density * _cheat_density()))


func max_pedestrians() -> int:
	return int(round([14.0, 26.0, 34.0, 44.0][level()] * pedestrian_density * _cheat_density()))


func _cheat_density() -> float:
	var cm: Node = get_node_or_null("/root/CheatManager")
	return float(cm.call("density_mult")) if cm != null else 1.0


func vegetation_density() -> float:
	return vegetation


## Streaming: Sektorradius (vollständig gebaut) aus der Sichtweite.
func sector_radius() -> int:
	return 1 if view_distance_m < 600.0 else (2 if view_distance_m < 1300.0 else 3)


## Umrechnung Geschwindigkeit für die Anzeige.
func speed_text(mps: float) -> String:
	return "%d mph" % roundi(mps * 2.23694) if speed_mph else "%d km/h" % roundi(mps * 3.6)
