class_name GameTestCase
extends TestCase
## Hilfen für Spiel-Integrationstests: Stadtspiel starten, über das Straßennetz fahren (Autopilot),
## zu Fuß zu einem Ziel gehen, Interaktionen auslösen.

var game: Game


func start_city_game(ambient: bool = false) -> void:
	GameState.reset_new_game()
	game = (load("res://scenes/game.tscn") as PackedScene).instantiate() as Game
	game.world_mode = "city"
	game.ambient_life = ambient
	# Streaming in Tests synchron und mit 3x3 Sektoren (deterministisch, schnell)
	game.stream_sync = true
	game.stream_radius = 1
	game.parked_cars_in_tests = true
	add_child(game)
	game.player.use_sim_input = true
	if game.missions != null:
		game.missions.auto_skip_dialog = true
	await wait_physics(20)


func stop_game() -> void:
	if is_instance_valid(game):
		game.queue_free()
	await wait_physics(3)


func city() -> CityWorld:
	return game.get_city()


## Zu einem POI fahren (A* über das Straßennetz, danach direkt zum Zielpunkt).
func drive_to_poi(v: Vehicle, poi_id: String, speed: float = 13.0, radius: float = 7.0, timeout: float = 240.0) -> bool:
	var p: Vector3 = city().graph.poi_pos3(poi_id)
	return await drive_to(v, Vector3(p.x, 0.0, p.z), PackedVector3Array(), speed, radius, timeout)


## Fahrzeuge ohne sektorweise geparkte Autos (die mit dem Streaming kommen und gehen).
func own_vehicle_count() -> int:
	var n: int = 0
	for v: Node in get_tree().get_nodes_in_group("vehicles"):
		if not v.is_in_group("parked_cars") and not v.is_queued_for_deletion():
			n += 1
	return n


func poi(poi_id: String) -> Vector3:
	return city().poi_position(poi_id)


## Nachbarknoten von n entlang einer Straße mit Namen (oder -1).
func neighbor_on(n: int, street: String) -> int:
	var g: CityGraph = city().graph
	for e: int in g.node_edges[n]:
		if g.edge_name(e) == street:
			return g.other_node(e, n)
	return -1


## Sektoren um eine Position sofort laden (vor Teleports in Tests).
func load_at(p: Vector3) -> void:
	city().ensure_loaded(p)


## Spieler an eine Position setzen (Sektoren werden vorher geladen).
func teleport_player(p: Vector3) -> void:
	load_at(p)
	game.player.global_position = p
	game.player.velocity = Vector3.ZERO


## Spieler direkt neben ein Fahrzeug stellen und einsteigen.
func enter(v: Vehicle) -> bool:
	var p: Player = game.player
	var side: Vector3 = v.global_basis.x * -(v.spec.width * 0.5 + 0.9)
	p.global_position = v.global_position + side + Vector3.UP * 0.15
	await wait_physics(12)
	return p.toggle_vehicle()


## Fährt das Fahrzeug über explizite Wegpunkte und anschließend per A* zum Ziel (rechte Spur).
func drive_to(v: Vehicle, target: Vector3, pre_waypoints: PackedVector3Array = PackedVector3Array(),
		speed: float = 13.0, radius: float = 6.0, timeout: float = 150.0, start_hint: Vector3 = Vector3.INF) -> bool:
	var g: CityGraph = city().graph
	var start_p: Vector3 = v.global_position if start_hint == Vector3.INF else start_hint
	if not pre_waypoints.is_empty():
		start_p = pre_waypoints[pre_waypoints.size() - 1]
	var n1: int = g.nearest_node(Vector2(target.x, target.z), "drive")
	var n0: int = _best_start(g, start_p, n1) if pre_waypoints.is_empty() else _node_ahead(g, start_p, Vector3.ZERO)
	var path: PackedInt32Array = g.find_path(n0, n1, "drive")
	var pts: PackedVector3Array = pre_waypoints.duplicate()
	pts.append_array(g.lane_path(path, 2.6))
	pts.append(target)
	_face_route(v, pts)
	var ap := Autopilot.new()
	ap.set_path(pts, speed)
	ap.arrive_radius = 4.0
	v.ai_controller = ap
	v.driver = Vehicle.Driver.AI
	var ok: bool = await wait_until(func() -> bool:
		return Vector2(v.global_position.x - target.x, v.global_position.z - target.z).length() < radius or ap.finished, timeout)
	# Anhalten und Kontrolle an den Spieler zurückgeben
	v.ai_controller = null
	v.driver = Vehicle.Driver.PLAYER
	v.set_controls(0.0, 1.0, 0.0, true)
	await wait_until(func() -> bool: return v.linear_velocity.length() < 0.8, 6.0)
	return ok and Vector2(v.global_position.x - target.x, v.global_position.z - target.z).length() < radius + 4.0


## Startknoten: das Ende der aktuellen Kante, über das der Gesamtweg zum Ziel kürzer ist
## (vermeidet Wenden am Knoten vor dem Fahrzeug; _face_route dreht das Fahrzeug bei Bedarf).
func _best_start(g: CityGraph, pos: Vector3, goal: int) -> int:
	var p2: Vector2 = Vector2(pos.x, pos.z)
	var ne: Dictionary = g.nearest_edge_point(p2, "drive", 60.0)
	if int(ne.edge) < 0:
		return g.nearest_node(p2, "drive")
	var best: int = -1
	var best_len: float = INF
	for n: int in [g.edge_a[int(ne.edge)], g.edge_b[int(ne.edge)]]:
		var path: PackedInt32Array = g.find_path(n, goal, "drive")
		if path.is_empty() and n != goal:
			continue
		var total: float = p2.distance_to(g.node_pos[n])
		for i: int in range(1, path.size()):
			total += g.node_pos[path[i - 1]].distance_to(g.node_pos[path[i]])
		if total < best_len:
			best_len = total
			best = n
	return best if best >= 0 else g.nearest_node(p2, "drive")


func _path_len(g: CityGraph, a: int, b: int) -> float:
	var path: PackedInt32Array = g.find_path(a, b, "drive")
	if path.is_empty():
		return INF
	var total: float = 0.0
	for i: int in range(1, path.size()):
		total += g.node_pos[path[i - 1]].distance_to(g.node_pos[path[i]])
	return total


func _node_ahead(g: CityGraph, pos: Vector3, fwd: Vector3) -> int:
	var p2: Vector2 = Vector2(pos.x, pos.z)
	if fwd == Vector3.ZERO:
		return g.nearest_node(p2, "drive")
	var f2: Vector2 = Vector2(fwd.x, fwd.z).normalized()
	var best: int = -1
	var best_d: float = INF
	for n: int in g.node_count():
		if g.degree(n, "drive") == 0:
			continue
		var d: Vector2 = g.node_pos[n] - p2
		if d.length() < 6.0 or d.normalized().dot(f2) < 0.3:
			continue
		if d.length() < best_d:
			best_d = d.length()
			best = n
	return best if best >= 0 else g.nearest_node(p2, "drive")


## Geht zu Fuß (simulierte Eingabe) zum Ziel. Kamera-Gier = 0, damit Eingabe = Weltrichtung.
func walk_to(target: Vector3, radius: float = 1.5, timeout: float = 30.0) -> bool:
	var p: Player = game.player
	game.camera_rig.yaw = 0.0
	var ok: bool = await wait_until(func() -> bool:
		var d: Vector3 = target - p.global_position
		d.y = 0.0
		if d.length() < radius:
			p.sim_move = Vector2.ZERO
			return true
		var n: Vector3 = d.normalized()
		p.sim_move = Vector2(n.x, n.z)
		return false, timeout, 1)
	p.sim_move = Vector2.ZERO
	return ok


func interact_nearest() -> bool:
	var p: Player = game.player
	var it: Node3D = Interactables.find_best(p)
	if it == null:
		return false
	it.call("interact", p)
	return true


## Wegpunkte über das Straßennetz durch eine Folge von Punkten (je nächster Knoten), rechte Spur.
func route_through(start: Vector3, fwd: Vector3, targets: Array[Vector2]) -> PackedVector3Array:
	var g: CityGraph = city().graph
	var cur: int = _best_start(g, start, g.nearest_node(targets[0], "drive")) if not targets.is_empty() else _node_ahead(g, start, fwd)
	var nodes: PackedInt32Array = PackedInt32Array([cur])
	for ti: int in targets.size():
		var t: Vector2 = targets[ti]
		# Über die Kante fahren, auf der der Zielpunkt liegt; Richtung so wählen, dass der Weg vom aktuellen Knoten
		# über die Kante zum nächsten Ziel am kürzesten ist
		var ne: Dictionary = g.nearest_edge_point(t, "drive", 80.0)
		var legs: Array[int] = []
		if int(ne.edge) >= 0:
			var a: int = g.edge_a[int(ne.edge)]
			var b: int = g.edge_b[int(ne.edge)]
			var nxt: int = g.nearest_node(targets[ti + 1], "drive") if ti + 1 < targets.size() else -1
			var cost_ab: float = (0.0 if cur == a else _path_len(g, cur, a)) + (_path_len(g, b, nxt) if nxt >= 0 and nxt != b else 0.0)
			var cost_ba: float = (0.0 if cur == b else _path_len(g, cur, b)) + (_path_len(g, a, nxt) if nxt >= 0 and nxt != a else 0.0)
			if cost_ab <= cost_ba:
				legs = [a, b]
			else:
				legs = [b, a]
		else:
			legs = [g.nearest_node(t, "drive")]
		for nk: int in legs:
			if nk == cur:
				continue
			var seg: PackedInt32Array = g.find_path(cur, nk, "drive")
			for i: int in range(1, seg.size()):
				nodes.append(seg[i])
			cur = nk
	var pts: PackedVector3Array = PackedVector3Array([start])
	pts.append_array(g.lane_path(nodes, 2.6))
	return pts


## Testvereinfachung: zeigt die Route anfangs nach hinten, wird das stehende Fahrzeug in Fahrtrichtung
## gedreht (statt Wendemanöver in engen Straßen). Nur in Test-Hilfen verwendet.
func _face_route(v: Vehicle, pts: PackedVector3Array) -> void:
	var p0: Vector3 = v.global_position
	for q: Vector3 in pts:
		var d: Vector3 = q - p0
		d.y = 0.0
		if d.length() < 10.0:
			continue
		var fwd: Vector3 = -v.global_basis.z
		fwd.y = 0.0
		if fwd.normalized().dot(d.normalized()) < -0.2:
			var ne: Dictionary = city().graph.nearest_edge_point(Vector2(p0.x, p0.z), "drive", 40.0)
			var base: Vector2 = ne.point if int(ne.edge) >= 0 else Vector2(p0.x, p0.z)
			v.teleport_to(Vector3(base.x, p0.y + 0.2, base.y), atan2(-d.x, -d.z))
		return


## Lässt das Fahrzeug per Autopilot einer Wegpunktliste folgen, bis done() wahr ist.
func follow_until(v: Vehicle, pts: PackedVector3Array, speed: float, done: Callable, timeout: float) -> bool:
	_face_route(v, pts)
	var ap := Autopilot.new()
	ap.set_path(pts, speed)
	ap.arrive_radius = 4.0
	v.ai_controller = ap
	v.driver = Vehicle.Driver.AI
	var ok: bool = await wait_until(done, timeout)
	v.ai_controller = null
	v.driver = Vehicle.Driver.PLAYER
	v.set_controls(0.0, 1.0, 0.0, true)
	return ok
