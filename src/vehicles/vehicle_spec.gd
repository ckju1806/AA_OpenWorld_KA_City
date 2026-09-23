class_name VehicleSpec
extends RefCounted
## Konfigurierbare Fahrzeugparameter (aus data/vehicles/vehicles.json).

const DATA_PATH: String = "res://data/vehicles/vehicles.json"

var id: String = ""
var display_name: String = ""
var category: String = ""
var body_style: String = "kompakt"
var mass: float = 1200.0
var length: float = 4.0
var width: float = 1.8
var height: float = 1.5
var wheelbase: float = 2.5
var track: float = 1.5
var wheel_radius: float = 0.32
var engine_force: float = 6000.0
var max_speed: float = 40.0
var reverse_speed: float = 9.0
var brake_decel: float = 10.0
var steer_max_deg: float = 34.0
var steer_min_deg: float = 7.0
var steer_speed_ref: float = 34.0
var steer_rate: float = 4.0
var grip_front: float = 1.1
var grip_rear: float = 1.1
var handbrake_grip: float = 0.3
var spring_hz: float = 1.6
var damping_ratio: float = 0.45
var rest_length: float = 0.35
var com_height: float = 0.42
var drive: String = "front"
var health: float = 1000.0
var camera_distance: float = 6.5
var camera_height: float = 2.0
var engine_sound: String = "engine_kompakt"
var engine_pitch: float = 1.0
var colors: Array[Color] = []

static var _catalog: Dictionary = {}


static func from_dict(d: Dictionary) -> VehicleSpec:
	var s := VehicleSpec.new()
	s.id = str(d.get("id", ""))
	s.display_name = str(d.get("name", s.id))
	s.category = str(d.get("kategorie", ""))
	s.body_style = str(d.get("body_style", "kompakt"))
	for key: String in ["mass", "length", "width", "height", "wheelbase", "track", "wheel_radius",
			"engine_force", "max_speed", "reverse_speed", "brake_decel", "steer_max_deg", "steer_min_deg",
			"steer_speed_ref", "steer_rate", "grip_front", "grip_rear", "handbrake_grip", "spring_hz",
			"damping_ratio", "rest_length", "com_height", "health", "camera_distance", "camera_height",
			"engine_pitch"]:
		if d.has(key):
			s.set(key, float(d[key]))
	s.drive = str(d.get("drive", "front"))
	s.engine_sound = str(d.get("engine_sound", "engine_kompakt"))
	for c: Variant in d.get("colors", []):
		s.colors.append(Color.html(str(c)))
	if s.colors.is_empty():
		s.colors.append(Color(0.6, 0.6, 0.6))
	return s


## Prüft physikalische Plausibilität. Rückgabe: Liste von Fehlern (leer = gültig).
func validate() -> Array[String]:
	var e: Array[String] = []
	if id.is_empty():
		e.append("id fehlt")
	if mass < 300.0 or mass > 20000.0:
		e.append("%s: Masse unplausibel" % id)
	if wheelbase >= length or wheelbase <= 1.0:
		e.append("%s: Radstand passt nicht zur Länge" % id)
	if track >= width or track <= 0.8:
		e.append("%s: Spurweite passt nicht zur Breite" % id)
	if max_speed <= reverse_speed:
		e.append("%s: Höchstgeschwindigkeit <= Rückwärts" % id)
	if steer_min_deg > steer_max_deg:
		e.append("%s: Lenkwinkel min > max" % id)
	if engine_force / mass < 2.0:
		e.append("%s: zu schwache Beschleunigung" % id)
	if not ["front", "rear", "all"].has(drive):
		e.append("%s: unbekannter Antrieb" % id)
	return e


## Federsteifigkeit pro Rad (N/m) aus Eigenfrequenz.
func spring_k() -> float:
	var m_corner: float = mass * 0.25
	var w: float = TAU * spring_hz
	return m_corner * w * w


func damper_c() -> float:
	var m_corner: float = mass * 0.25
	return 2.0 * damping_ratio * sqrt(spring_k() * m_corner)


## Statische Einfederung (m) unter Eigengewicht.
func static_compression() -> float:
	return mass * 0.25 * 9.8 / spring_k()


## Höhe des Radaufhängungspunkts über dem Boden in Ruhelage.
func mount_height() -> float:
	return rest_length + wheel_radius - static_compression()


static func load_catalog() -> Dictionary:
	if not _catalog.is_empty():
		return _catalog
	var f: FileAccess = FileAccess.open(DATA_PATH, FileAccess.READ)
	if f == null:
		push_error("Fahrzeugdaten fehlen: %s" % DATA_PATH)
		return _catalog
	var parsed: Variant = JSON.parse_string(f.get_as_text())
	if parsed is Dictionary:
		for v: Variant in (parsed as Dictionary).get("vehicles", []):
			if v is Dictionary:
				var s: VehicleSpec = VehicleSpec.from_dict(v)
				_catalog[s.id] = s
	return _catalog


static func get_spec(spec_id: String) -> VehicleSpec:
	var cat: Dictionary = load_catalog()
	if cat.has(spec_id):
		return cat[spec_id]
	push_warning("Unbekannter Fahrzeugtyp '%s' – verwende Kompaktwagen." % spec_id)
	return cat.get("kompakt", VehicleSpec.new())
