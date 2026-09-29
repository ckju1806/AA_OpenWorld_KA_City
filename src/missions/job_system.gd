class_name JobSystem
extends Node
## Wiederholbare Jobs (W8): Kurierfahrt, Taxifahrt, Lieferrunde. Erzeugt jeweils eine Missionsdefinition mit
## zufälligen Orten am Fahrbahnrand (in der Nähe des Spielers bzw. quer durch die Stadt); Bezahlung nach Entfernung,
## bei jedem Abschluss (pay_always). Gestartet über die Auftragsliste (Taste J).

const KINDS: Dictionary = {
	"job_kurier": {"title": "Kurierfahrt", "desc": "Sendung abholen und zustellen."},
	"job_taxi": {"title": "Taxifahrt", "desc": "Fahrgast abholen und ans Ziel bringen."},
	"job_lieferung": {"title": "Lieferrunde", "desc": "Drei Abgaben unter Zeitdruck."},
}

var game: Node
var _rng := RandomNumberGenerator.new()


func setup(p_game: Node) -> void:
	game = p_game
	_rng.seed = 90210


func _city() -> CityWorld:
	return game.call("get_city") as CityWorld


func _player_pos() -> Vector3:
	var p: Player = game.get("player") as Player
	return p.current_vehicle.global_position if p.is_in_vehicle() else p.global_position


## Punkt am rechten Fahrbahnrand einer befahrbaren Kante im Abstandsring um p. Rückgabe {pos:[x,z], yaw} oder {}.
func curb_point(p: Vector3, dmin: float, dmax: float) -> Dictionary:
	var g: CityGraph = _city().graph
	for attempt: int in 40:
		var ang: float = _rng.randf() * TAU
		var r: float = _rng.randf_range(dmin, dmax)
		var q: Vector2 = Vector2(p.x, p.z) + Vector2(cos(ang), sin(ang)) * r
		var ne: Dictionary = g.nearest_edge_point(q, "traffic", 150.0)
		if int(ne.edge) < 0:
			continue
		var e: int = int(ne.edge)
		if g.edge_length(e) < 20.0 or g.edge_width(e) < 6.0:
			continue
		var a: Vector2 = g.node_pos[g.edge_a[e]]
		var b: Vector2 = g.node_pos[g.edge_b[e]]
		var dir: Vector2 = (b - a).normalized()
		var right: Vector2 = Vector2(-dir.y, dir.x)
		var pt: Vector2 = (ne.point as Vector2) + right * (g.edge_width(e) * 0.5 - 1.2)
		if not _city().world.bounds.grow(-100.0).has_point(pt):
			continue
		return {"pos": [snappedf(pt.x, 0.1), snappedf(pt.y, 0.1)], "yaw": atan2(-dir.x, -dir.y)}
	return {}


## Neuen Job erzeugen und als Missionsdefinition registrieren. Liefert die ID oder "".
func create_job(kind: String) -> String:
	var ms: MissionSystem = game.get("missions") as MissionSystem
	if ms == null or ms.has_active():
		return ""
	var pp: Vector3 = _player_pos()
	var car: Dictionary = curb_point(pp, 12.0, 60.0)
	if car.is_empty():
		return ""
	var steps: Array = []
	var reward: int = 0
	var spec: String = "transporter" if kind != "job_taxi" else "limousine"
	var livery: String = "Fächerblitz Kurier" if kind != "job_taxi" else "Fächer-Taxi"
	var col: String = "#f2f1ec" if kind != "job_taxi" else "#f2c21a"
	steps.append({"type": "spawn_vehicle", "tag": "job", "spec": spec, "pos": car.pos, "yaw": car.yaw, "color": col, "livery": livery})
	steps.append({"type": "enter_vehicle", "tag": "job", "text": "Steig in das Jobfahrzeug."})
	match kind:
		"job_kurier":
			var a: Dictionary = curb_point(pp, 250.0, 900.0)
			var b: Dictionary = curb_point(Vector3(float(a.get("pos", [0, 0])[0]), 0, float(a.get("pos", [0, 0])[1])), 700.0, 2200.0) if not a.is_empty() else {}
			if a.is_empty() or b.is_empty():
				return ""
			steps.append({"type": "goto", "pos": a.pos, "radius": 9, "vehicle": "job", "marker": "abholung", "text": "Hol die Sendung ab."})
			steps.append({"type": "wait_zone", "pos": a.pos, "radius": 9, "vehicle": "job", "seconds": 2.0, "max_speed": 2.0, "text": "Kurz halten – Sendung einladen.", "progress": "Einladen"})
			steps.append({"type": "goto", "pos": b.pos, "radius": 9, "vehicle": "job", "marker": "ziel", "text": "Stelle die Sendung zu."})
			steps.append({"type": "wait_zone", "pos": b.pos, "radius": 9, "vehicle": "job", "seconds": 2.0, "max_speed": 2.0, "text": "Kurz halten – Sendung abgeben.", "progress": "Abgeben"})
			reward = 60 + int(_dist(pp, a.pos) / 25.0 + _dist2(a.pos, b.pos) / 18.0)
		"job_taxi":
			var pick: Dictionary = curb_point(pp, 150.0, 600.0)
			var dest: Dictionary = curb_point(Vector3(float(pick.get("pos", [0, 0])[0]), 0, float(pick.get("pos", [0, 0])[1])), 800.0, 2600.0) if not pick.is_empty() else {}
			if pick.is_empty() or dest.is_empty():
				return ""
			steps.append({"type": "taxi", "pickup": pick.pos, "dest": dest.pos, "radius": 9, "text": "Hol den Fahrgast ab.",
				"board_text": "Warte, bis der Fahrgast eingestiegen ist.", "drive_text": "Bring den Fahrgast ans Ziel."})
			reward = 40 + int(_dist2(pick.pos, dest.pos) / 14.0)
		"job_lieferung":
			var drops: Array = []
			var cur: Vector3 = pp
			var total: float = 0.0
			for i: int in 3:
				var d: Dictionary = curb_point(cur, 300.0, 900.0)
				if d.is_empty():
					return ""
				drops.append(d.pos)
				var nxt: Vector3 = Vector3(float(d.pos[0]), 0, float(d.pos[1]))
				total += cur.distance_to(nxt)
				cur = nxt
			var limit: float = 40.0 + total / 8.5
			steps.append({"type": "multi_drop", "drops": drops, "radius": 10, "wait": 2.0, "time_limit": snappedf(limit, 1.0), "vehicle": "job",
				"text": "Liefere alle drei Sendungen aus (kurz anhalten)."})
			reward = 90 + int(total / 12.0)
	var d2: Dictionary = {"id": kind, "title": str(KINDS[kind].title), "order": 900, "reward": reward, "repeatable": true, "pay_always": true,
		"chapter": "Jobs", "summary": str(KINDS[kind].desc), "giver": {}, "fail_vehicle": "job", "steps": steps}
	ms.definitions[kind] = MissionDefinition.from_dict(d2)
	return kind


func start_job(kind: String) -> bool:
	var id: String = create_job(kind)
	if id == "":
		EventBus.notify.emit("Gerade kein passender Job in der Nähe.", "warnung")
		return false
	var ms: MissionSystem = game.get("missions") as MissionSystem
	return ms.start_mission(id)


func _dist(p: Vector3, a: Array) -> float:
	return Vector2(p.x, p.z).distance_to(Vector2(float(a[0]), float(a[1])))


func _dist2(a: Array, b: Array) -> float:
	return Vector2(float(a[0]), float(a[1])).distance_to(Vector2(float(b[0]), float(b[1])))
