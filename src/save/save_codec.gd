class_name SaveCodec
extends RefCounted
## Versioniertes Speicherformat (JSON). Reine Logik, ohne Dateizugriff -> gut testbar.
##
## Format v1:
## { "format": "faecherstadt-save", "version": 1, "game_version": "0.1.0", "saved_at": "...",
##   "state": { money, completed_missions[], best_times{}, mission_attempts{}, play_time },
##   "player": { "position": [x, y, z], "yaw": float, "health": float, "mission": String } }

const FORMAT_ID: String = "faecherstadt-save"
const CURRENT_VERSION: int = 1
const WORLD_LIMIT_XZ: float = 1500.0
const WORLD_MIN_Y: float = -20.0
const WORLD_MAX_Y: float = 200.0


static func encode(state: Dictionary, player: Dictionary, game_version: String = "0.1.0") -> String:
	var doc: Dictionary = {
		"format": FORMAT_ID,
		"version": CURRENT_VERSION,
		"game_version": game_version,
		"saved_at": Time.get_datetime_string_from_system(true),
		"state": state,
		"player": player,
	}
	return JSON.stringify(doc, "  ")


## Liefert { ok: bool, error: String, data: Dictionary, warnings: Array[String] }.
static func decode(text: String) -> Dictionary:
	var result: Dictionary = {"ok": false, "error": "", "data": {}, "warnings": []}
	if text.strip_edges().is_empty():
		result.error = "Spielstand ist leer."
		return result
	var json := JSON.new()
	if json.parse(text) != OK:
		result.error = "Spielstand ist beschädigt (JSON-Fehler in Zeile %d)." % json.get_error_line()
		return result
	var doc: Variant = json.data
	if not doc is Dictionary:
		result.error = "Spielstand hat ein unbekanntes Format."
		return result
	var d: Dictionary = doc
	if str(d.get("format", "")) != FORMAT_ID:
		result.error = "Datei ist kein Fächer-City-Spielstand."
		return result
	var version: int = int(d.get("version", 0))
	if version <= 0:
		result.error = "Spielstand ohne gültige Versionsnummer."
		return result
	if version > CURRENT_VERSION:
		result.error = "Spielstand stammt aus einer neueren Spielversion (v%d)." % version
		return result
	d = migrate(d, version)
	var state: Dictionary = {}
	if d.get("state") is Dictionary:
		state = d.state
	else:
		result.warnings.append("Spielfortschritt fehlte – Standardwerte verwendet.")
	var player: Dictionary = {}
	if d.get("player") is Dictionary:
		player = validate_player(d.player, result.warnings)
	else:
		result.warnings.append("Spielerposition fehlte – Startpunkt wird verwendet.")
	result.data = {"state": state, "player": player, "version": CURRENT_VERSION,
		"saved_at": str(d.get("saved_at", ""))}
	result.ok = true
	return result


## Hebt ältere Formate auf die aktuelle Version an (derzeit nur v1 vorhanden).
static func migrate(d: Dictionary, from_version: int) -> Dictionary:
	var out: Dictionary = d.duplicate(true)
	var v: int = from_version
	while v < CURRENT_VERSION:
		# Platz für zukünftige Migrationsschritte v -> v+1
		v += 1
	out["version"] = v
	return out


static func validate_player(p: Dictionary, warnings: Array) -> Dictionary:
	var out: Dictionary = {}
	var pos: Variant = p.get("position")
	if pos is Array and (pos as Array).size() == 3:
		var arr: Array = pos
		var ok: bool = true
		for v: Variant in arr:
			if not (v is float or v is int) or is_nan(float(v)) or is_inf(float(v)):
				ok = false
		if ok:
			var v3 := Vector3(float(arr[0]), float(arr[1]), float(arr[2]))
			if absf(v3.x) <= WORLD_LIMIT_XZ and absf(v3.z) <= WORLD_LIMIT_XZ and v3.y >= WORLD_MIN_Y and v3.y <= WORLD_MAX_Y:
				out["position"] = v3
			else:
				warnings.append("Gespeicherte Position lag außerhalb der Welt – Startpunkt wird verwendet.")
		else:
			warnings.append("Gespeicherte Position ungültig – Startpunkt wird verwendet.")
	out["yaw"] = wrapf(float(p.get("yaw", 0.0)), -PI, PI) if (p.get("yaw") is float or p.get("yaw") is int) else 0.0
	var hp: float = float(p.get("health", 100.0)) if (p.get("health") is float or p.get("health") is int) else 100.0
	out["health"] = clampf(hp, 10.0, 100.0)
	# Beim Speichern laufender Auftrag (beginnt nach dem Laden beim Auftraggeber neu)
	out["mission"] = str(p.get("mission", "")) if p.get("mission") is String else ""
	return out


static func vec3_to_array(v: Vector3) -> Array:
	return [snappedf(v.x, 0.01), snappedf(v.y, 0.01), snappedf(v.z, 0.01)]
