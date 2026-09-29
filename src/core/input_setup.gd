class_name InputSetup
extends RefCounted
## Registriert alle Eingabeaktionen zur Laufzeit (Tastatur + Maus, physische Tasten = layoutunabhängig).
## Belegung kommt aus den Einstellungen (Settings.bindings, frei belegbar); Standard siehe DEFAULTS.

const DEFAULTS: Dictionary = {
	"move_forward": [KEY_W, KEY_UP],
	"move_back": [KEY_S, KEY_DOWN],
	"move_left": [KEY_A, KEY_LEFT],
	"move_right": [KEY_D, KEY_RIGHT],
	"sprint": [KEY_SHIFT],
	"jump": [KEY_SPACE],
	"handbrake": [KEY_SPACE],
	"interact": [KEY_E],
	"enter_exit": [KEY_F],
	"horn": [KEY_H],
	"lights": [KEY_L],
	"look_behind": [KEY_C],
	"map": [KEY_M],
	"mission_list": [KEY_J],
	"cheat_console": [KEY_QUOTELEFT],
	"pause": [KEY_ESCAPE],
	"debug_overlay": [KEY_F3],
	"recover_vehicle": [KEY_R],
	"retry": [KEY_ENTER],
}

## Anzeigename und Kategorie je Aktion (Optionsmenü)
const LABELS: Dictionary = {
	"move_forward": ["Vorwärts / Gas", "Bewegung"], "move_back": ["Rückwärts / Bremse", "Bewegung"],
	"move_left": ["Links", "Bewegung"], "move_right": ["Rechts", "Bewegung"], "sprint": ["Sprinten", "Bewegung"],
	"jump": ["Springen", "Bewegung"], "handbrake": ["Handbremse", "Fahrzeug"], "enter_exit": ["Ein-/Aussteigen", "Fahrzeug"],
	"horn": ["Hupe", "Fahrzeug"], "lights": ["Licht", "Fahrzeug"], "recover_vehicle": ["Fahrzeug bergen", "Fahrzeug"],
	"look_behind": ["Nach hinten schauen", "Fahrzeug"], "interact": ["Interagieren", "Allgemein"], "map": ["Karte", "Allgemein"],
	"mission_list": ["Auftragsliste", "Allgemein"], "cheat_console": ["Cheat-Konsole", "Allgemein"],
	"pause": ["Pause / Menü", "Allgemein"], "debug_overlay": ["Entwickleranzeige", "Allgemein"], "retry": ["Auftrag wiederholen", "Allgemein"],
}

## Aktionen, die sich eine Taste teilen dürfen (unterschiedlicher Kontext: zu Fuß / im Fahrzeug)
const SHAREABLE: Array = [["jump", "handbrake"], ["interact", "enter_exit"]]

## Nicht belegbar (feste Systemtasten)
const LOCKED: Array[String] = ["pause"]


static func default_bindings() -> Dictionary:
	var out: Dictionary = {}
	for a: String in DEFAULTS:
		var keys: Array[int] = []
		for k: int in DEFAULTS[a]:
			keys.append(k)
		out[a] = keys
	return out


static func may_share(a: String, b: String) -> bool:
	for pair: Array in SHAREABLE:
		if pair.has(a) and pair.has(b):
			return true
	return false


static func register(bindings: Dictionary = {}) -> void:
	var b: Dictionary = bindings if not bindings.is_empty() else default_bindings()
	for action: String in DEFAULTS:
		if not InputMap.has_action(action):
			InputMap.add_action(action, 0.2)
		else:
			InputMap.action_erase_events(action)
		var keys: Array = b.get(action, DEFAULTS[action])
		if action in LOCKED:
			keys = DEFAULTS[action]
		for key: Variant in keys:
			var ev := InputEventKey.new()
			ev.physical_keycode = int(key) as Key
			InputMap.action_add_event(action, ev)


static func key_name(key: int) -> String:
	if key <= 0:
		return "—"
	# Anzeige im aktuellen Tastaturlayout (ohne Anzeigeserver, z. B. in Tests: US-Namen)
	var s: String = ""
	if DisplayServer.get_name() not in ["headless", "Headless"]:
		s = OS.get_keycode_string(DisplayServer.keyboard_get_keycode_from_physical(key as Key))
	return s if s != "" else OS.get_keycode_string(key as Key)
