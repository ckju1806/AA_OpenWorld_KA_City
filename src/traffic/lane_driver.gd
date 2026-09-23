class_name LaneDriver
extends RefCounted
## Basis-Fahrlogik für KI-Fahrzeuge auf dem Straßengraphen (Rechtsverkehr):
## Spurfolge (Pure Pursuit), Kurven-/Ampel-/Vorfahrtsverhalten, Hinderniserkennung (Physikabfrage),
## Festfahr-Behandlung. Unterklassen bestimmen die Route (choose_next / replan).

const LANE_OFFSET: float = 2.6
const STOP_DECEL: float = 4.5

var graph: CityGraph
var lights: TrafficLights
var mode: String = "traffic"          ## Graph-Modus für Routen
var plan: Array[int] = []             ## Knotenfolge, plan[0] = Start der aktuellen Kante
var points: PackedVector3Array = PackedVector3Array()
var personality: float = 1.0
var speed_limit_override: float = -1.0
var obstacle_dist: float = INF
var wants_despawn: bool = false
var stuck_count: int = 0
var ignore_lights: bool = false

var _stuck_t: float = 0.0
var _reverse_t: float = 0.0
var _yield_t: float = 0.0
var _check_t: float = 0.0
var _frame_offset: int = 0
var _seg_cursor: int = 0


func setup(g: CityGraph, l: TrafficLights, start_plan: Array[int]) -> void:
	graph = g
	lights = l
	plan = start_plan
	_frame_offset = randi() % 4
	_extend_plan()
	_rebuild_points()


## Unterklassen: nächster Knoten nach plan[-1] (oder -1).
func choose_next(_prev: int, _cur: int) -> int:
	return -1


func _extend_plan() -> void:
	var guard: int = 0
	while plan.size() < 4 and guard < 6:
		guard += 1
		var cur: int = plan[plan.size() - 1]
		var prev: int = plan[plan.size() - 2] if plan.size() >= 2 else -1
		var nxt: int = choose_next(prev, cur)
		if nxt < 0:
			break
		plan.append(nxt)


func _rebuild_points() -> void:
	points = graph.lane_path(PackedInt32Array(plan), LANE_OFFSET, 0.0, 10.0)
	_seg_cursor = 0


func current_edge() -> int:
	if plan.size() < 2:
		return -1
	return graph.find_edge(plan[0], plan[1])


## Pro Physikschritt vom Fahrzeug aufgerufen.
func update(v: Vehicle, delta: float) -> void:
	if plan.size() < 2 or points.size() < 2:
		v.set_controls(0.0, 1.0, 0.0, true)
		wants_despawn = true
		return
	var pos: Vector3 = v.global_position
	_advance_plan(pos)
	if plan.size() < 2:
		return
	# Rückwärts-Manöver beim Festfahren
	if _reverse_t > 0.0:
		_reverse_t -= delta
		v.set_controls(0.0, 0.8, -_steer_to(v, _lookahead(v, pos)), false)
		return
	var desired: float = _desired_speed(v, pos, delta)
	var steer: float = _steer_to(v, _lookahead(v, pos))
	_drive(v, desired, steer)
	_update_stuck(v, desired, delta)


func _advance_plan(pos: Vector3) -> void:
	var a: Vector2 = graph.node_pos[plan[0]]
	var b: Vector2 = graph.node_pos[plan[1]]
	var ab: Vector2 = b - a
	var len2: float = ab.length_squared()
	var p2: Vector2 = Vector2(pos.x, pos.z)
	var t: float = (p2 - a).dot(ab) / maxf(len2, 0.01)
	var near_node: bool = p2.distance_to(b) < 5.5
	if t > 1.0 - 2.0 / maxf(sqrt(len2), 1.0) or near_node:
		plan.pop_front()
		_extend_plan()
		_rebuild_points()


func _lookahead(v: Vehicle, pos: Vector3) -> Vector3:
	var la: float = 4.5 + absf(v.get_forward_speed()) * 0.35
	var p2: Vector2 = Vector2(pos.x, pos.z)
	# Segment-Cursor läuft nur vorwärts (verhindert Zielpunkte hinter dem Fahrzeug)
	var best_i: int = _seg_cursor
	var best_d: float = INF
	var last: int = mini(points.size() - 2, _seg_cursor + 6)
	for i: int in range(_seg_cursor, last + 1):
		var q: Vector2 = PolyUtil.closest_on_segment(p2, Vector2(points[i].x, points[i].z), Vector2(points[i + 1].x, points[i + 1].z))
		var d: float = q.distance_to(p2)
		if d < best_d - 0.01:
			best_d = d
			best_i = i
	_seg_cursor = best_i
	# Projektion auf das beste Segment, dann entlang der Polylinie vorausschauen
	var a: Vector2 = Vector2(points[best_i].x, points[best_i].z)
	var b: Vector2 = Vector2(points[best_i + 1].x, points[best_i + 1].z)
	var cur2: Vector2 = PolyUtil.closest_on_segment(p2, a, b)
	var remaining: float = la
	for j: int in range(best_i + 1, points.size()):
		var nxt: Vector2 = Vector2(points[j].x, points[j].z)
		var seg: float = cur2.distance_to(nxt)
		if seg >= remaining:
			var r2: Vector2 = cur2.lerp(nxt, remaining / maxf(seg, 0.001))
			return Vector3(r2.x, 0.0, r2.y)
		remaining -= seg
		cur2 = nxt
	return points[points.size() - 1]


func _steer_to(v: Vehicle, target: Vector3) -> float:
	var to_t: Vector3 = target - v.global_position
	to_t.y = 0.0
	var fwd: Vector3 = -v.global_basis.z
	fwd.y = 0.0
	fwd = fwd.normalized()
	var right: Vector3 = fwd.cross(Vector3.UP)
	var dn: Vector3 = to_t.normalized()
	var ang: float = atan2(dn.dot(right), dn.dot(fwd))
	return clampf(ang / deg_to_rad(maxf(v.spec.steer_max_deg * 0.75, 12.0)), -1.0, 1.0)


func _desired_speed(v: Vehicle, pos: Vector3, _delta: float) -> float:
	var e: int = current_edge()
	var base: float = (graph.edge_speed(e) if e >= 0 else 10.0) * personality
	if base < 3.0:
		base = 7.0
	if speed_limit_override > 0.0:
		base = speed_limit_override
	var n1: int = plan[1]
	var n1p: Vector2 = graph.node_pos[n1]
	var dist_node: float = Vector2(pos.x, pos.z).distance_to(n1p)
	var r: float = graph.node_radius(n1, "all")
	var desired: float = base
	# Kurven
	if plan.size() >= 3:
		var d1: Vector2 = (n1p - graph.node_pos[plan[0]]).normalized()
		var d2: Vector2 = (graph.node_pos[plan[2]] - n1p).normalized()
		var turn: float = absf(d1.angle_to(d2))
		if turn > 0.4:
			var v_turn: float = lerpf(base, 5.0, clampf(turn / 1.6, 0.0, 1.0))
			desired = minf(desired, sqrt(v_turn * v_turn + 2.0 * STOP_DECEL * maxf(dist_node - r, 0.0)))
	# Ampel
	var dist_stop: float = dist_node - (r + 2.2)
	if lights != null and not ignore_lights and lights.is_signalized(n1) and e >= 0:
		var l: TrafficLights.Light = lights.light_for(n1, e)
		var must_stop: bool = l == TrafficLights.Light.RED or (l == TrafficLights.Light.YELLOW and dist_stop > 10.0)
		if must_stop and dist_stop > -0.5:
			desired = minf(desired, sqrt(2.0 * STOP_DECEL * maxf(dist_stop - 0.5, 0.0)))
	elif not ignore_lights and graph.degree(n1, "drive") >= 3 and dist_stop < 18.0 and dist_stop > -1.0:
		# Ungeregelte Kreuzung: langsam heranfahren, Kreuzungsbereich frei? (vereinfacht "rechts vor links")
		desired = minf(desired, 6.5)
		if dist_stop < 6.0 and _junction_busy(v, n1p, r):
			_yield_t += 1.0 / 60.0
			if _yield_t < 3.5:
				desired = 0.0
		else:
			_yield_t = 0.0
	# Hindernisse (alle 4 Frames aktualisiert)
	_check_t -= 1.0
	if _check_t <= 0.0:
		_check_t = 4.0
		obstacle_dist = _scan_obstacles(v)
	if obstacle_dist < INF:
		desired = minf(desired, maxf(0.0, (obstacle_dist - 3.5) * 0.8))
	return desired


func _drive(v: Vehicle, desired: float, steer: float) -> void:
	var spd: float = v.get_forward_speed()
	var throttle: float = 0.0
	var brake: float = 0.0
	if desired < 0.3 and spd < 0.6:
		v.set_controls(0.0, 0.0, steer, true)
		return
	if spd < desired - 0.4:
		throttle = clampf((desired - spd) * 0.35 + 0.2, 0.0, 1.0)
	elif spd > desired + 0.8:
		brake = clampf((spd - desired) * 0.25, 0.1, 1.0)
	v.set_controls(throttle, brake, steer, false)


func _update_stuck(v: Vehicle, desired: float, delta: float) -> void:
	if desired > 2.0 and absf(v.get_forward_speed()) < 0.5 and obstacle_dist > 6.0:
		_stuck_t += delta
		if _stuck_t > 3.5:
			_stuck_t = 0.0
			_reverse_t = 1.6
			stuck_count += 1
			if stuck_count > 3:
				wants_despawn = true
	else:
		_stuck_t = maxf(0.0, _stuck_t - delta)
		if v.get_forward_speed() > 4.0:
			stuck_count = 0
	if v.is_flipped() or v.is_destroyed:
		wants_despawn = true


## Physikabfrage: Box auf der eigenen Spur vor dem Fahrzeug (Fahrzeuge, Spieler, Passanten).
func _scan_obstacles(v: Vehicle) -> float:
	var space: PhysicsDirectSpaceState3D = v.get_world_3d().direct_space_state
	var fwd: Vector3 = -v.global_basis.z
	fwd.y = 0.0
	fwd = fwd.normalized()
	var length: float = 26.0
	var box := BoxShape3D.new()
	box.size = Vector3(2.4, 1.6, length)
	var q := PhysicsShapeQueryParameters3D.new()
	q.shape = box
	var center: Vector3 = v.global_position + fwd * (v.spec.length * 0.5 + length * 0.5) + Vector3.UP * 1.0
	q.transform = Transform3D(Basis.looking_at(fwd, Vector3.UP), center)
	q.collision_mask = Layers.VEHICLE | Layers.PLAYER | Layers.NPC
	q.collide_with_areas = true
	q.exclude = [v.get_rid()]
	var hits: Array[Dictionary] = space.intersect_shape(q, 8)
	var best: float = INF
	for h: Dictionary in hits:
		var c: Object = h.collider
		if c is Node3D:
			var other_half: float = 0.4
			if c is Vehicle:
				other_half = (c as Vehicle).spec.length * 0.5
			# Abstand eigene Front -> Heck/Rand des Hindernisses
			var d: float = ((c as Node3D).global_position - v.global_position).dot(fwd) - v.spec.length * 0.5 - other_half
			best = minf(best, maxf(d, 0.0))
	return best


func _junction_busy(v: Vehicle, center: Vector2, r: float) -> bool:
	var space: PhysicsDirectSpaceState3D = v.get_world_3d().direct_space_state
	var s := SphereShape3D.new()
	s.radius = r + 1.5
	var q := PhysicsShapeQueryParameters3D.new()
	q.shape = s
	q.transform = Transform3D(Basis.IDENTITY, Vector3(center.x, 1.0, center.y))
	q.collision_mask = Layers.VEHICLE
	q.exclude = [v.get_rid()]
	return not space.intersect_shape(q, 1).is_empty()
