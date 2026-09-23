class_name PoliceDriver
extends LaneDriver
## Polizei-KI: Streife (ohne Fahndung), Anfahrt zur zuletzt bekannten Position (A* über das Netz,
## Fußgängerzonen mit höheren Kosten erlaubt), direkte Verfolgung nur bei eigenem Sichtkontakt.

var manager: Node = null
var sees_player: bool = false
var chase_target: Vector3 = Vector3.INF
var _route: Array[int] = []
var _replan_t: float = 0.0
var _goal: Vector3 = Vector3.INF
var _rng: RandomNumberGenerator


func _init(seed_value: int) -> void:
	_rng = DetRng.make_rng(seed_value)
	mode = "police"
	personality = 1.0


func choose_next(prev: int, cur: int) -> int:
	if not _route.is_empty():
		var n: int = _route.pop_front()
		if graph.find_edge(cur, n) >= 0:
			return n
		_route.clear()
	# Streife / Suche: zufällige Nachbarn (bevorzugt geradeaus)
	var opts: Array[int] = []
	for e: int in graph.node_edges_mode(cur, "drive"):
		var o: int = graph.other_node(e, cur)
		if o != prev:
			opts.append(o)
	if opts.is_empty():
		return prev
	return opts[_rng.randi() % opts.size()]


func update(v: Vehicle, delta: float) -> void:
	var level: int = int(manager.call("wanted_level")) if manager != null else 0
	var pursuit: bool = level > 0
	ignore_lights = pursuit
	speed_limit_override = -1.0
	if pursuit:
		personality = 1.45
		if not v.siren_on:
			v.set_siren(true)
			v.set_lights(true)
	else:
		personality = 0.95
		if v.siren_on:
			v.set_siren(false)
	# Direkte Verfolgung bei eigenem Sichtkontakt in kurzer Distanz
	if pursuit and sees_player and chase_target != Vector3.INF and v.global_position.distance_to(chase_target) < 45.0:
		_direct_chase(v, delta)
		return
	if pursuit:
		_replan_t -= delta
		var goal: Vector3 = manager.call("police_goal") as Vector3
		if _replan_t <= 0.0 or (_goal != Vector3.INF and goal.distance_to(_goal) > 25.0):
			_replan_t = 2.0
			_replan(goal)
	super.update(v, delta)


func _replan(goal: Vector3) -> void:
	_goal = goal
	if plan.size() < 2:
		return
	var target_node: int = graph.nearest_node(Vector2(goal.x, goal.z), "police")
	var path: PackedInt32Array = graph.find_path(plan[1], target_node, "police")
	_route.clear()
	for i: int in range(1, path.size()):
		_route.append(path[i])
	plan = [plan[0], plan[1]]
	_extend_plan()
	_rebuild_points()
	if _route.is_empty() and path.size() <= 1:
		# Ziel erreicht: Suchfahrt um den Punkt
		pass


func _direct_chase(v: Vehicle, _delta: float) -> void:
	var tgt: Vector3 = chase_target
	var to_t: Vector3 = tgt - v.global_position
	to_t.y = 0.0
	var dist: float = to_t.length()
	var steer: float = _steer_to(v, tgt)
	var desired: float = clampf(dist * 0.9, 6.0, v.spec.max_speed * 0.95)
	if dist < 8.0:
		desired = 4.0
	var spd: float = v.get_forward_speed()
	var fwd: Vector3 = -v.global_basis.z
	if to_t.normalized().dot(fwd) < -0.3 and dist < 20.0:
		# Ziel hinter dem Fahrzeug -> zurücksetzen
		v.set_controls(0.0, 0.9, -steer, false)
		return
	if spd < desired:
		v.set_controls(1.0, 0.0, steer, false)
	else:
		v.set_controls(0.0, 0.5, steer, false)
	# Plan an aktuelle Position anpassen, damit die Netzfahrt danach nahtlos weitergeht
	_replan_t = 0.0
