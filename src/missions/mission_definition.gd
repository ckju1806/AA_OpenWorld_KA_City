class_name MissionDefinition
extends RefCounted
## Datengetriebene Missionsbeschreibung (data/missions/*.json).

const DIR: String = "res://data/missions/"
const STEP_TYPES: Array[String] = ["talk", "spawn_vehicle", "enter_vehicle", "goto", "wait_zone", "exit_vehicle",
	"interact", "countdown", "checkpoints", "trigger_wanted", "lose_wanted",
	"spawn_npc_vehicle", "follow", "protect", "escape_area", "observe", "collect", "multi_drop", "destroy", "taxi",
	"ride_transit", "reputation", "set_flag", "notify"]
const POI_LIST_KEYS: Array[String] = ["items", "drops"]
const POI_KEYS: Array[String] = ["poi", "dest", "pickup", "to_poi"]

var id: String = ""
var title: String = ""
var order: int = 0
var reward: int = 0
var repeatable: bool = false
var requires: Array[String] = []
var giver: Dictionary = {}
var steps: Array[Dictionary] = []
var fail_vehicle: String = ""
var best_time_key: String = ""
var giver_id: String = ""                  ## Auftraggeber (mehrere Missionen teilen sich eine Figur)
var chapter: String = ""                   ## Kapitel/Handlungsstrang für die Auftragsliste
var summary: String = ""
var reputation: Dictionary = {}            ## Gruppe -> Änderung beim ersten Abschluss
var pay_always: bool = false               ## Jobs: Bezahlung bei jedem Abschluss


static func from_dict(d: Dictionary) -> MissionDefinition:
	var m := MissionDefinition.new()
	m.id = str(d.get("id", ""))
	m.title = str(d.get("title", m.id))
	m.order = int(d.get("order", 0))
	m.reward = int(d.get("reward", 0))
	m.repeatable = bool(d.get("repeatable", false))
	for r: Variant in d.get("requires", []):
		m.requires.append(str(r))
	m.giver = d.get("giver", {})
	for s: Variant in d.get("steps", []):
		if s is Dictionary:
			m.steps.append(s)
	m.fail_vehicle = str(d.get("fail_vehicle", ""))
	m.best_time_key = str(d.get("best_time_key", ""))
	m.giver_id = str(d.get("giver_id", m.giver.get("poi", "")))
	m.chapter = str(d.get("chapter", ""))
	m.summary = str(d.get("summary", ""))
	m.reputation = d.get("reputation", {})
	m.pay_always = bool(d.get("pay_always", false))
	return m


static func load_all() -> Array[MissionDefinition]:
	var out: Array[MissionDefinition] = []
	var dir: DirAccess = DirAccess.open(DIR)
	if dir == null:
		push_error("Missionsordner fehlt: %s" % DIR)
		return out
	var files: PackedStringArray = dir.get_files()
	var names: Array[String] = []
	for f: String in files:
		var n: String = f.trim_suffix(".remap").trim_suffix(".import")
		if n.ends_with(".json") and not names.has(n):
			names.append(n)
	names.sort()
	for n2: String in names:
		var fa: FileAccess = FileAccess.open(DIR + n2, FileAccess.READ)
		if fa == null:
			continue
		var parsed: Variant = JSON.parse_string(fa.get_as_text())
		if parsed is Dictionary:
			out.append(from_dict(parsed))
		else:
			push_error("Mission ungültig: %s" % n2)
	out.sort_custom(func(a: MissionDefinition, b: MissionDefinition) -> bool: return a.order < b.order)
	return out


## Prüft Vollständigkeit gegen die Kartendaten. Rückgabe: Fehlerliste.
func validate(graph: CityGraph) -> Array[String]:
	var errs: Array[String] = []
	if id.is_empty():
		errs.append("Mission ohne id")
	if steps.is_empty():
		errs.append("%s: keine Schritte" % id)
	if graph.get_poi(str(giver.get("poi", ""))).is_empty():
		errs.append("%s: Auftraggeber-POI fehlt" % id)
	var tags: Dictionary = {}
	for i: int in steps.size():
		var s: Dictionary = steps[i]
		var t: String = str(s.get("type", ""))
		if not STEP_TYPES.has(t):
			errs.append("%s: Schritt %d hat unbekannten Typ '%s'" % [id, i, t])
		for k: String in POI_KEYS:
			if s.has(k) and graph.get_poi(str(s[k])).is_empty():
				errs.append("%s: Schritt %d verweist auf fehlenden POI '%s'" % [id, i, s[k]])
		for k2: String in POI_LIST_KEYS:
			for pv: Variant in s.get(k2, []):
				if graph.get_poi(str(pv)).is_empty():
					errs.append("%s: Schritt %d verweist auf fehlenden POI '%s'" % [id, i, pv])
		if t in ["follow", "protect"] and not tags.has(str(s.get("tag", ""))):
			errs.append("%s: Schritt %d: Fahrzeug '%s' unbekannt" % [id, i, s.get("tag", "")])
		if t == "spawn_vehicle" or t == "spawn_npc_vehicle":
			tags[str(s.get("tag", ""))] = true
		if s.has("vehicle") and not tags.has(str(s.vehicle)):
			errs.append("%s: Schritt %d nutzt Fahrzeug '%s' vor dessen Erzeugung" % [id, i, s.vehicle])
		if t == "enter_vehicle" and not tags.has(str(s.get("tag", ""))):
			errs.append("%s: Schritt %d: Fahrzeug '%s' unbekannt" % [id, i, s.get("tag", "")])
		if t == "checkpoints":
			var cps: Array = s.get("points", [])
			if cps.size() < 2:
				errs.append("%s: zu wenige Kontrollpunkte" % id)
			for ci: int in cps.size():
				var cp: Variant = cps[ci]
				if cp is String:
					if graph.get_poi(cp).is_empty():
						errs.append("%s: Kontrollpunkt %d verweist auf fehlenden POI '%s'" % [id, ci, cp])
					continue
				var c2: Vector2 = Vector2(float(cp[0]), float(cp[1]))
				var ne: Dictionary = graph.nearest_edge_point(c2, "drive")
				if int(ne.edge) < 0 or float(ne.dist) > graph.edge_width(int(ne.edge)) * 0.5 + 1.0:
					errs.append("%s: Kontrollpunkt %d liegt nicht auf einer Fahrbahn" % [id, ci])
	return errs
