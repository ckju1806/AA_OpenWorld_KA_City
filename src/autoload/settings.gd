extends Node
## Spieleinstellungen (lokal in user://settings.cfg). Fehlende/ungültige Werte -> Standardwerte.

signal changed

const PATH: String = "user://settings.cfg"
const QUALITY_NAMES: Array[String] = ["Niedrig", "Mittel", "Hoch"]

var master_volume: float = 0.8
var music_volume: float = 0.5
var sfx_volume: float = 0.8
var mouse_sensitivity: float = 0.22       ## Grad pro Pixel
var invert_y: bool = false
var fullscreen: bool = false
var vsync: bool = true
var quality: int = 1                       ## 0 niedrig, 1 mittel, 2 hoch
var show_fps: bool = false
var traffic_density: float = 1.0           ## 0.25 .. 1.5


func _enter_tree() -> void:
	InputSetup.register()
	load_settings()


func _ready() -> void:
	apply()


func load_settings() -> void:
	var cf := ConfigFile.new()
	if cf.load(PATH) != OK:
		return
	master_volume = clampf(float(cf.get_value("audio", "master", master_volume)), 0.0, 1.0)
	music_volume = clampf(float(cf.get_value("audio", "music", music_volume)), 0.0, 1.0)
	sfx_volume = clampf(float(cf.get_value("audio", "sfx", sfx_volume)), 0.0, 1.0)
	mouse_sensitivity = clampf(float(cf.get_value("input", "mouse_sensitivity", mouse_sensitivity)), 0.02, 1.0)
	invert_y = bool(cf.get_value("input", "invert_y", invert_y))
	fullscreen = bool(cf.get_value("video", "fullscreen", fullscreen))
	vsync = bool(cf.get_value("video", "vsync", vsync))
	quality = clampi(int(cf.get_value("video", "quality", quality)), 0, 2)
	show_fps = bool(cf.get_value("video", "show_fps", show_fps))
	traffic_density = clampf(float(cf.get_value("game", "traffic_density", traffic_density)), 0.25, 1.5)


func save_settings() -> void:
	var cf := ConfigFile.new()
	cf.set_value("audio", "master", master_volume)
	cf.set_value("audio", "music", music_volume)
	cf.set_value("audio", "sfx", sfx_volume)
	cf.set_value("input", "mouse_sensitivity", mouse_sensitivity)
	cf.set_value("input", "invert_y", invert_y)
	cf.set_value("video", "fullscreen", fullscreen)
	cf.set_value("video", "vsync", vsync)
	cf.set_value("video", "quality", quality)
	cf.set_value("video", "show_fps", show_fps)
	cf.set_value("game", "traffic_density", traffic_density)
	var err: Error = cf.save(PATH)
	if err != OK:
		push_warning("Einstellungen konnten nicht gespeichert werden: %s" % error_string(err))


func apply() -> void:
	_apply_bus("Master", master_volume)
	_apply_bus("Musik", music_volume)
	_apply_bus("Effekte", sfx_volume)
	_apply_bus("Umgebung", sfx_volume)
	if DisplayServer.get_name() != "headless":
		var mode: DisplayServer.WindowMode = DisplayServer.WINDOW_MODE_FULLSCREEN if fullscreen else DisplayServer.WINDOW_MODE_WINDOWED
		if DisplayServer.window_get_mode() != mode:
			DisplayServer.window_set_mode(mode)
		DisplayServer.window_set_vsync_mode(DisplayServer.VSYNC_ENABLED if vsync else DisplayServer.VSYNC_DISABLED)
	changed.emit()


func _apply_bus(bus_name: String, value: float) -> void:
	var idx: int = AudioServer.get_bus_index(bus_name)
	if idx < 0:
		return
	AudioServer.set_bus_volume_db(idx, linear_to_db(maxf(value, 0.0001)))
	AudioServer.set_bus_mute(idx, value <= 0.001)


## Qualitätsabhängige Werte (von Welt/Umgebung abgefragt).
func shadow_distance() -> float:
	return [80.0, 160.0, 260.0][quality]


func view_distance() -> float:
	return [450.0, 750.0, 1100.0][quality]


func prop_visibility() -> float:
	return [90.0, 160.0, 240.0][quality]


func max_traffic() -> int:
	return int(round([8.0, 14.0, 18.0][quality] * traffic_density))


func max_pedestrians() -> int:
	return int(round([14.0, 26.0, 34.0][quality] * traffic_density))
