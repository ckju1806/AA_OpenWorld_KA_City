extends Node
## Lokales Speichern/Laden mit atomischem Schreiben und Sicherungskopie.
## Speicherort: user://  (Windows: %APPDATA%\Faecherstadt\)

signal saved(ok: bool, message: String)

var save_path: String = "user://savegame.json"
var backup_path: String = "user://savegame.bak.json"
var tmp_path: String = "user://savegame.tmp"


func set_paths(main_path: String, backup: String, tmp: String) -> void:
	save_path = main_path
	backup_path = backup
	tmp_path = tmp


func has_save() -> bool:
	return FileAccess.file_exists(save_path) or FileAccess.file_exists(backup_path)


func save_game(player_data: Dictionary) -> bool:
	var text: String = SaveCodec.encode(GameState.to_dict(), player_data,
		str(ProjectSettings.get_setting("application/config/version", "0.1.0")))
	var f: FileAccess = FileAccess.open(tmp_path, FileAccess.WRITE)
	if f == null:
		var msg: String = "Speichern fehlgeschlagen: %s" % error_string(FileAccess.get_open_error())
		saved.emit(false, msg)
		return false
	f.store_string(text)
	f.flush()
	f.close()
	var abs_main: String = ProjectSettings.globalize_path(save_path)
	var abs_bak: String = ProjectSettings.globalize_path(backup_path)
	var abs_tmp: String = ProjectSettings.globalize_path(tmp_path)
	if FileAccess.file_exists(save_path):
		if FileAccess.file_exists(backup_path):
			DirAccess.remove_absolute(abs_bak)
		DirAccess.rename_absolute(abs_main, abs_bak)
	var err: Error = DirAccess.rename_absolute(abs_tmp, abs_main)
	if err != OK:
		saved.emit(false, "Speichern fehlgeschlagen: %s" % error_string(err))
		return false
	saved.emit(true, "Spiel gespeichert.")
	return true


## Lädt den Spielstand. Rückgabe: { ok, data, source ("haupt"/"sicherung"), message, warnings }.
func load_game() -> Dictionary:
	var primary: Dictionary = _load_file(save_path)
	if primary.ok:
		primary["source"] = "haupt"
		primary["message"] = ""
		return primary
	var backup: Dictionary = _load_file(backup_path)
	if backup.ok:
		backup["source"] = "sicherung"
		backup["message"] = "Hauptspielstand nicht lesbar (%s) – Sicherungskopie geladen." % primary.error
		return backup
	return {"ok": false, "data": {}, "source": "", "warnings": [],
		"message": "Kein gültiger Spielstand gefunden. %s" % primary.error, "error": primary.error}


func _load_file(path: String) -> Dictionary:
	if not FileAccess.file_exists(path):
		return {"ok": false, "error": "Datei fehlt.", "data": {}, "warnings": []}
	var f: FileAccess = FileAccess.open(path, FileAccess.READ)
	if f == null:
		return {"ok": false, "error": "Datei nicht lesbar.", "data": {}, "warnings": []}
	var text: String = f.get_as_text()
	f.close()
	return SaveCodec.decode(text)


func delete_save() -> void:
	for p: String in [save_path, backup_path, tmp_path]:
		if FileAccess.file_exists(p):
			DirAccess.remove_absolute(ProjectSettings.globalize_path(p))
