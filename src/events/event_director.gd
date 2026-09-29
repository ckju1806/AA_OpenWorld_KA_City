class_name EventDirector
extends Node
## Ereignis-Direktor (W7): startet fiktive Zufallsereignisse in der Nähe des Spielers – Rangelei/Revierstreit,
## Taschendiebstahl, Straßenrennen, Kundgebung (ggf. Unruhe), Polizeikontrolle. Steuerung über Budget (max. gleichzeitige
## Ereignisse), Abkühlzeiten (global und je Art), Risikoprofil des Viertels (data/world/gangs.json) und die Optionen
## (Banden/Unruhen/Polizei an/aus, Häufigkeit) sowie Cheats (CHAOSTAG, RUHETAG).

const CATEGORY: Dictionary = {"scuffle": "gangs", "theft": "gangs", "race": "gangs", "rally": "unrest", "police_check": "police"}

var game: Node
var city: CityWorld
var graph: CityGraph
var lights: TrafficLights
var root: Node3D
var enabled: bool = true
var events: Array[GameEvent] = []
var cooldown: float = 30.0
var type_cooldown: Dictionary = {}
var started_total: int = 0
var data: Dictionary = {}
var _tick: float = 0.0
var _rng := RandomNumberGenerator.new()


func setup(p_game: Node, p_city: CityWorld, p_lights: TrafficLights) -> void:
	game = p_game
	city = p_city
	graph = p_city.graph
	lights = p_lights
	_rng.seed = 5150
	root = Node3D.new()
	root.name = "Ereignisse"
	(game.get("entities") as Node3D).add_child(root)
	var f: FileAccess = FileAccess.open("res://data/world/gangs.json", FileAccess.READ)
	if f != null:
		var d: Variant = JSON.parse_string(f.get_as_text())
		data = d if d is Dictionary else {}


func player_pos() -> Vector3:
	var pl: Player = game.get("player") as Player
	if pl == null:
		return Vector3.ZERO
	return pl.current_vehicle.global_position if pl.is_in_vehicle() else pl.global_position


func max_active() -> int:
	return 3 if CheatManager.is_active("CHAOSTAG") else 2


func _physics_process(delta: float) -> void:
	var pp: Vector3 = player_pos()
	for i: int in range(events.size() - 1, -1, -1):
		var ev: GameEvent = events[i]
		ev.tick(delta, pp)
		if ev.done:
			ev.cleanup()
			events.remove_at(i)
	cooldown -= delta
	for k: String in type_cooldown.keys():
		type_cooldown[k] = float(type_cooldown[k]) - delta
	_tick -= delta
	if _tick > 0.0:
		return
	_tick = 2.0 if CheatManager.is_active("CHAOSTAG") else 6.0
	if not enabled or CheatManager.is_active("RUHETAG") or events.size() >= max_active() or cooldown > 0.0:
		return
	var pl: Player = game.get("player") as Player
	if pl == null or pl.is_dead:
		return
	var ms: MissionSystem = game.get("missions") as MissionSystem
	var zone: Dictionary = zone_at(pp)
	var chance: float = float(zone.get("risk", 0.2)) * 0.3 * Settings.event_frequency
	if CheatManager.is_active("CHAOSTAG"):
		chance = 0.9
	if ms != null and ms.has_active():
		chance *= 0.4
	if _rng.randf() > chance:
		return
	var kind: String = _pick_kind(zone)
	if kind != "":
		start_event(kind, pp)


func _pick_kind(zone: Dictionary) -> String:
	var weights: Dictionary = zone.get("events", {})
	var opts: Array[String] = []
	var ws: Array[float] = []
	for k: String in weights:
		if not category_enabled(str(CATEGORY.get(k, ""))) or float(type_cooldown.get(k, 0.0)) > 0.0:
			continue
		opts.append(k)
		ws.append(float(weights[k]))
	if opts.is_empty():
		return ""
	var total: float = 0.0
	for w: float in ws:
		total += w
	var r: float = _rng.randf() * total
	for i: int in opts.size():
		r -= ws[i]
		if r <= 0.0:
			return opts[i]
	return opts[opts.size() - 1]


func category_enabled(cat: String) -> bool:
	match cat:
		"gangs":
			return Settings.events_gangs
		"unrest":
			return Settings.events_unrest
		"police":
			return Settings.events_police
	return false


## Ereignis starten (auch für Tests/Cheats). Liefert das Ereignis oder null.
func start_event(kind: String, near: Vector3) -> GameEvent:
	var ev: GameEvent = EventsBasic.create(kind)
	if ev == null:
		return null
	ev.director = self
	ev.rng.seed = _rng.randi()
	var p: Vector3 = _location_for(kind, near)
	if p == Vector3.INF:
		return null
	ev.pos = p
	if not ev.start():
		ev.cleanup()
		return null
	events.append(ev)
	started_total += 1
	GameState.add_stat("ereignisse")
	cooldown = (18.0 if CheatManager.is_active("CHAOSTAG") else 55.0) / maxf(Settings.event_frequency, 0.25)
	type_cooldown[kind] = 150.0 / maxf(Settings.event_frequency, 0.25)
	return ev


func _location_for(kind: String, near: Vector3) -> Vector3:
	var peds: PedestrianManager = game.get("peds") as PedestrianManager
	match kind:
		"scuffle", "theft":
			if peds == null or peds.net == null:
				return Vector3.INF
			for attempt: int in 6:
				var hit: Array = peds.net.random_point_near(Vector2(near.x, near.z), 45.0, 140.0, _rng)
				if not hit.is_empty():
					var q: Vector2 = peds.net.loops[hit[0]][hit[1]]
					var p3: Vector3 = Vector3(q.x, 0.0, q.y)
					if city.is_loaded_at(p3):
						return p3
			return Vector3.INF
		"rally":
			var best: Vector3 = Vector3.INF
			var best_d: float = INF
			var wander: Array = city.world.meta.get("walk", {}).get("wander", [])
			var qf: float = 1.0 / city.world.q
			for i: int in range(0, wander.size(), 4):
				var c: Vector3 = Vector3(float(wander[i]) * qf, 0.0, float(wander[i + 1]) * qf)
				var d: float = c.distance_to(near)
				if d > 40.0 and d < 260.0 and d < best_d and city.is_loaded_at(c):
					best = c
					best_d = d
			return best
		_:
			return near


# ------------------------------------------------------------------ Hilfen für Ereignisse

func zone_at(p: Vector3) -> Dictionary:
	var zones: Dictionary = data.get("zones", {})
	var did: String = district_at(p)
	return zones.get(did, zones.get("_default", {"risk": 0.2, "events": {}}))


func district_at(p: Vector3) -> String:
	var p2: Vector2 = Vector2(p.x, p.z)
	for d: Variant in graph.layout.get("districts", []):
		var poly: PackedVector2Array = city.world.pts(d.poly)
		if Geometry2D.is_point_in_polygon(p2, poly):
			return str(d.id)
	return ""


## Bis zu zwei Gruppen, deren Revier hier liegt (bzw. benachbart).
func gangs_near(p: Vector3) -> Array:
	var did: String = district_at(p)
	var out: Array = []
	for g: Variant in data.get("groups", []):
		if did in (g.turf as Array):
			out.append(str(g.id))
	for g2: Variant in data.get("groups", []):
		if out.size() >= 2:
			break
		if not out.has(str(g2.id)) and _rng.randf() < 0.5:
			out.append(str(g2.id))
	return out


func gang_color(gid: String) -> Color:
	for g: Variant in data.get("groups", []):
		if str(g.id) == gid:
			var c: Array = g.color
			return Color(float(c[0]), float(c[1]), float(c[2]))
	return Color(-1, 0, 0)


func line(key: String) -> String:
	var arr: Array = data.get(key, ["…"])
	return str(arr[_rng.randi() % arr.size()])


func police_near(p: Vector3, r: float) -> bool:
	for v: Node in get_tree().get_nodes_in_group("police"):
		if (v as Node3D).global_position.distance_to(p) < r:
			return true
	return false


func dispatch_police(p: Vector3, duration: float) -> void:
	var pm: PoliceManager = game.get("police") as PoliceManager
	if pm != null:
		pm.dispatch(p, duration)


## Zwei Startplätze für ein Rennen auf einer Verkehrskante 110–220 m entfernt, außer Sicht.
func race_start(near: Vector3) -> Array:
	var cand: PackedInt32Array = graph.edges_near(Vector2(near.x, near.z), 220.0)
	for attempt: int in 20:
		if cand.is_empty():
			break
		var e: int = cand[_rng.randi() % cand.size()]
		if not graph.is_traffic(e) or graph.edge_length(e) < 40.0 or graph.edge_width(e) < 7.0:
			continue
		var a: int = graph.edge_a[e]
		var b: int = graph.edge_b[e]
		if not graph.is_oneway(e) and _rng.randf() < 0.5:
			var tmp: int = a
			a = b
			b = tmp
		var pa: Vector2 = graph.node_pos[a]
		var pb: Vector2 = graph.node_pos[b]
		var dir: Vector2 = (pb - pa).normalized()
		var right: Vector2 = Vector2(-dir.y, dir.x)
		var mid: Vector2 = pa.lerp(pb, 0.35)
		var p3: Vector3 = Vector3(mid.x, 0, mid.y)
		var d: float = p3.distance_to(near)
		if d < 110.0 or d > 220.0 or not city.is_loaded_at(p3):
			continue
		var yaw: float = atan2(-dir.x, -dir.y)
		var off: float = graph.lane_offset(e, 2.6)
		var plan: Array[int] = [a, b]
		return [{"pos": Vector3(mid.x + right.x * off, 0.3, mid.y + right.y * off), "yaw": yaw, "plan": plan},
			{"pos": Vector3(mid.x - dir.x * 9.0 + right.x * off, 0.3, mid.y - dir.y * 9.0 + right.y * off), "yaw": yaw, "plan": plan.duplicate()}]
	return []


## Parkposition am Fahrbahnrand (rechts) nahe p.
func curb_spot(near: Vector3) -> Dictionary:
	var cand: PackedInt32Array = graph.edges_near(Vector2(near.x, near.z), 160.0)
	for attempt: int in 20:
		if cand.is_empty():
			break
		var e: int = cand[_rng.randi() % cand.size()]
		if not graph.is_drivable(e) or graph.edge_length(e) < 30.0 or graph.edge_width(e) < 8.0:
			continue
		var pa: Vector2 = graph.node_pos[graph.edge_a[e]]
		var pb: Vector2 = graph.node_pos[graph.edge_b[e]]
		var dir: Vector2 = (pb - pa).normalized()
		var right: Vector2 = Vector2(-dir.y, dir.x)
		var mid: Vector2 = pa.lerp(pb, 0.4) + right * (graph.edge_width(e) * 0.5 - 1.4)
		var p3: Vector3 = Vector3(mid.x, 0.3, mid.y)
		var d: float = p3.distance_to(near)
		if d < 50.0 or d > 160.0 or not city.is_loaded_at(p3):
			continue
		return {"pos": p3, "yaw": atan2(-dir.x, -dir.y)}
	return {}


func on_actor_down(actor: EventActor, by_player: bool) -> void:
	if not by_player:
		return
	# Den flüchtenden Dieb zu stellen ist keine Straftat
	for ev: GameEvent in events:
		if ev is EventsBasic.Theft and (ev as EventsBasic.Theft).thief == actor:
			return
	var peds: PedestrianManager = game.get("peds") as PedestrianManager
	var witnessed: bool = peds != null and peds.count_witnesses(actor.global_position, 35.0) > 0
	for a: Node in get_tree().get_nodes_in_group("event_actors"):
		if a != actor and (a as Node3D).global_position.distance_to(actor.global_position) < 30.0:
			witnessed = true
	EventBus.crime_reported.emit("fussgaenger", actor.global_position, witnessed)


func clear_all() -> void:
	for ev: GameEvent in events:
		ev.cleanup()
	events.clear()
