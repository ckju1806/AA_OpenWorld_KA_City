extends Node
## Minimaler Testrunner (ohne externe Abhängigkeiten).
## Aufruf: godot --headless --path . --fixed-fps 60 res://tests/test_runner.tscn -- [--filter=unit|integration|<name>]
## Exit-Code: 0 = alle Tests bestanden, 1 = Fehler.

const DIRS: Array[String] = ["res://tests/unit", "res://tests/integration"]

var _total: int = 0
var _failed: int = 0
var _lines: Array[String] = []


func _ready() -> void:
	# Testläufe dürfen den echten Spielstand/Einstellungen nicht verändern
	SaveManager.set_paths("user://test_savegame.json", "user://test_savegame.bak.json", "user://test_savegame.tmp")
	_run.call_deferred()


func _run() -> void:
	var filter: String = ""
	for a: String in OS.get_cmdline_user_args():
		if a.begins_with("--filter="):
			filter = a.substr(9)
	var t0: int = Time.get_ticks_msec()
	_log("=== Fächer-City Tests (Godot %s) ===" % Engine.get_version_info().string)
	for dir_path: String in DIRS:
		var files: Array[String] = _list_tests(dir_path)
		for f: String in files:
			var full: String = dir_path + "/" + f
			if filter != "" and not full.contains(filter):
				continue
			await _run_file(full)
	var dt: float = float(Time.get_ticks_msec() - t0) / 1000.0
	_log("=== Ergebnis: %d Tests, %d fehlgeschlagen, %.1f s ===" % [_total, _failed, dt])
	_write_report()
	get_tree().quit(1 if _failed > 0 else 0)


func _list_tests(dir_path: String) -> Array[String]:
	var out: Array[String] = []
	var d: DirAccess = DirAccess.open(dir_path)
	if d == null:
		return out
	for f: String in d.get_files():
		var name_only: String = f.trim_suffix(".remap")
		if name_only.begins_with("test_") and name_only.ends_with(".gd") and not out.has(name_only):
			out.append(name_only)
	out.sort()
	return out


func _run_file(path: String) -> void:
	var script: GDScript = load(path) as GDScript
	if script == null:
		_failed += 1
		_log("FEHLER  %s konnte nicht geladen werden" % path)
		return
	var methods: Array[String] = []
	for m: Dictionary in script.get_script_method_list():
		var mname: String = str(m.name)
		if mname.begins_with("test_") and not methods.has(mname):
			methods.append(mname)
	for mname: String in methods:
		var inst: TestCase = script.new() as TestCase
		if inst == null:
			_failed += 1
			_log("FEHLER  %s ist kein TestCase" % path)
			return
		inst.name = path.get_file().get_basename()
		add_child(inst)
		inst.current_test = mname
		_total += 1
		var t0: int = Time.get_ticks_msec()
		if inst.has_method("before_each"):
			await inst.call("before_each")
		await inst.call(mname)
		if inst.has_method("after_each"):
			await inst.call("after_each")
		var ms: int = Time.get_ticks_msec() - t0
		if inst.failures.is_empty():
			_log("OK      %s::%s (%d ms)" % [path.get_file(), mname, ms])
		else:
			_failed += 1
			_log("FEHLER  %s::%s (%d ms)" % [path.get_file(), mname, ms])
			for fmsg: String in inst.failures:
				_log("        - " + fmsg)
		inst.queue_free()
		await get_tree().process_frame
		await get_tree().process_frame


func _log(s: String) -> void:
	print(s)
	_lines.append(s)


func _write_report() -> void:
	var f: FileAccess = FileAccess.open("user://last_test_report.txt", FileAccess.WRITE)
	if f != null:
		f.store_string("\n".join(_lines) + "\n")
		f.close()
