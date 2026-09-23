class_name InputSetup
extends RefCounted
## Registriert alle Eingabeaktionen zur Laufzeit (Tastatur + Maus, physische Tasten = layoutunabhängig).

const ACTIONS: Dictionary = {
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
	"map": [KEY_M],
	"pause": [KEY_ESCAPE],
	"debug_overlay": [KEY_F3],
	"recover_vehicle": [KEY_R],
	"retry": [KEY_ENTER],
}


static func register() -> void:
	for action: String in ACTIONS:
		if not InputMap.has_action(action):
			InputMap.add_action(action, 0.2)
		else:
			InputMap.action_erase_events(action)
		for key: int in ACTIONS[action]:
			var ev := InputEventKey.new()
			ev.physical_keycode = key as Key
			InputMap.action_add_event(action, ev)
