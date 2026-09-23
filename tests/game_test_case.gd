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
	var n0: int = _node_ahead(g, start_p, -v.global_basis.z if pre_waypoints.is_empty() else Vector3.ZERO)
	var n1: int = g.nearest_node(Vector2(target.x, target.z), "drive")
	var path: PackedInt32Array = g.find_path(n0, n1, "drive")
	var pts: PackedVector3Array = pre_waypoints.duplicate()
	pts.append_array(g.lane_path(path, 2.6))
	pts.append(target)
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
	var cur: int = _node_ahead(g, start, fwd)
	var nodes: PackedInt32Array = PackedInt32Array([cur])
	for t: Vector2 in targets:
		var nk: int = g.nearest_node(t, "drive")
		if nk == cur:
			continue
		var seg: PackedInt32Array = g.find_path(cur, nk, "drive")
		for i: int in range(1, seg.size()):
			nodes.append(seg[i])
		cur = nk
	var pts: PackedVector3Array = PackedVector3Array([start])
	pts.append_array(g.lane_path(nodes, 2.6))
	return pts


## Lässt das Fahrzeug per Autopilot einer Wegpunktliste folgen, bis done() wahr ist.
func follow_until(v: Vehicle, pts: PackedVector3Array, speed: float, done: Callable, timeout: float) -> bool:
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
