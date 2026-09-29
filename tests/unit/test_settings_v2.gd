extends TestCase
## Einstellungen v2: Voreinstellungen, Migration einer v1-Datei, Speichern/Laden, Tastenbelegung mit Konfliktprüfung.

const TMP: String = "user://test_settings_tmp.cfg"
var _backup: Dictionary = {}


func before_each() -> void:
	_backup = {}
	for prop: Dictionary in Settings.get_property_list():
		if prop.usage & PROPERTY_USAGE_SCRIPT_VARIABLE and prop.name != "fullscreen":
			var v: Variant = Settings.get(prop.name)
			_backup[prop.name] = v.duplicate(true) if v is Dictionary or v is Array else v


func after_each() -> void:
	for k: String in _backup:
		Settings.set(k, _backup[k])
	InputSetup.register(Settings.bindings)
	DirAccess.remove_absolute(ProjectSettings.globalize_path(TMP))


func test_presets() -> void:
	Settings.apply_preset(0)
	assert_eq(Settings.level(), 0, "Niedrig")
	assert_false(Settings.ssao, "Niedrig ohne SSAO")
	assert_eq(Settings.sector_radius(), 1, "Niedrig: Sektorradius 1")
	Settings.apply_preset(3)
	assert_true(Settings.ssil and Settings.volumetric_fog, "Ultra mit SSIL und Volumennebel")
	assert_eq(Settings.sector_radius(), 3, "Ultra: Sektorradius 3")
	assert_gt(float(Settings.max_traffic()), 20.0, "Ultra: mehr Verkehr")
	Settings.apply_preset(4)
	assert_eq(Settings.quality, 4, "Benutzerdefiniert behält Einzelwerte")


func test_migration_from_v1() -> void:
	var cf := ConfigFile.new()
	cf.set_value("audio", "master", 0.3)
	cf.set_value("video", "fullscreen", true)
	cf.set_value("video", "quality", 2)
	cf.set_value("game", "traffic_density", 0.5)
	cf.save(TMP)
	Settings.load_settings(TMP)
	assert_near(Settings.master_volume, 0.3, 0.001, "Lautstärke übernommen")
	assert_eq(Settings.window_mode, 1, "Vollbild -> Fenstermodus Vollbild")
	assert_eq(Settings.quality, 2, "Qualität übernommen")
	assert_true(Settings.ssao, "Voreinstellung Hoch angewendet")
	assert_near(Settings.traffic_density, 0.5, 0.001, "Verkehrsdichte übernommen")


func test_save_and_load_roundtrip() -> void:
	Settings.apply_preset(4)
	Settings.view_distance_m = 1234.0
	Settings.fov = 88.0
	Settings.colorblind = 2
	Settings.events_unrest = false
	var keys: Array[int] = [KEY_G]
	Settings.bindings["horn"] = keys
	Settings.save_settings(TMP)
	Settings.view_distance_m = 500.0
	Settings.fov = 70.0
	Settings.colorblind = 0
	Settings.events_unrest = true
	Settings.bindings["horn"] = [KEY_H] as Array[int]
	Settings.load_settings(TMP)
	assert_near(Settings.view_distance_m, 1234.0, 0.01, "Sichtweite")
	assert_near(Settings.fov, 88.0, 0.01, "Sichtfeld")
	assert_eq(Settings.colorblind, 2, "Farbfehlsichtigkeit")
	assert_false(Settings.events_unrest, "Unruhen aus")
	assert_eq(int(Settings.bindings["horn"][0]), KEY_G, "Tastenbelegung Hupe")


func test_invalid_values_clamped() -> void:
	var cf := ConfigFile.new()
	cf.set_value("meta", "version", 2)
	cf.set_value("video", "fov", 500.0)
	cf.set_value("video", "render_scale", 0.1)
	cf.set_value("video", "fps_limit", 77)
	cf.set_value("game", "police_difficulty", 9)
	cf.save(TMP)
	Settings.load_settings(TMP)
	assert_near(Settings.fov, 100.0, 0.01, "Sichtfeld begrenzt")
	assert_near(Settings.render_scale, 0.5, 0.01, "Renderskala begrenzt")
	assert_eq(Settings.fps_limit, 0, "Ungültiges FPS-Limit -> unbegrenzt")
	assert_eq(Settings.police_difficulty, 2, "Schwierigkeit begrenzt")


func test_binding_conflicts() -> void:
	Settings.bindings = InputSetup.default_bindings()
	assert_true(Settings.binding_conflicts("horn", KEY_E).has("interact"), "Konflikt Hupe/Interagieren erkannt")
	assert_true(Settings.binding_conflicts("jump", KEY_SPACE).is_empty(), "Springen/Handbremse dürfen teilen")
	var keys: Array[int] = [KEY_G]
	Settings.set_binding("horn", keys)
	var has_g: bool = false
	for ev: InputEvent in InputMap.action_get_events("horn"):
		if ev is InputEventKey and (ev as InputEventKey).physical_keycode == KEY_G:
			has_g = true
	assert_true(has_g, "Neue Belegung im InputMap aktiv")
