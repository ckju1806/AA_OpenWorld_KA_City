class_name TestErrorCounter
extends Logger
## Zählt Engine-/Skriptfehler während der Tests (Godot >= 4.5 Logger-API).
## Laufzeitfehler in Testcode brechen GDScript-Koroutinen nicht ab – ohne diesen Zähler
## würde ein Test mit Skriptfehler fälschlich als bestanden gelten.

var _mutex: Mutex = Mutex.new()
var _errors: int = 0
var _last: Array[String] = []


func _log_error(function: String, file: String, line: int, code: String, rationale: String,
		_editor_notify: bool, error_type: int, _script_backtraces: Array[ScriptBacktrace]) -> void:
	if error_type == ERROR_TYPE_WARNING:
		return
	_mutex.lock()
	_errors += 1
	var msg: String = rationale if rationale != "" else code
	_last.append("%s (%s:%d %s)" % [msg, file.get_file(), line, function])
	if _last.size() > 5:
		_last.pop_front()
	_mutex.unlock()


func _log_message(_message: String, _error: bool) -> void:
	pass


func error_count() -> int:
	_mutex.lock()
	var c: int = _errors
	_mutex.unlock()
	return c


func last_errors() -> Array[String]:
	_mutex.lock()
	var l: Array[String] = _last.duplicate()
	_mutex.unlock()
	return l
