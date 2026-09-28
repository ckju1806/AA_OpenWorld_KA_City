class_name Autopilot
extends RefCounted
## Einfacher Wegpunkt-Folger (Pure Pursuit) für Fahrzeuge.
## Grundlage für Verkehrs-/Polizei-KI und automatisierte Fahrtests.

var waypoints: PackedVector3Array = PackedVector3Array()
var index: int = 0
var target_speed: float = 12.0      ## m/s
var lookahead: float = 5.0
var arrive_radius: float = 5.0
var finished: bool = false
var loop: bool = false
var corner_slowdown: bool = true
# Wendemanöver (Dreipunktwende): Phase 0 = aus, 1 = rückwärts, 2 = vorwärts mit Gegeneinschlag
var _turn_phase: int = 0
var _turn_t: float = 0.0
var _turn_stuck: float = 0.0
var _turn_side: float = 1.0
var _stall_t: float = 0.0
var _recover_t: float = 0.0


func set_path(points: PackedVector3Array, speed: float = 12.0) -> void:
	waypoints = points
	index = 0
	finished = points.is_empty()
	target_speed = speed


func current_target() -> Vector3:
	if waypoints.is_empty():
		return Vector3.ZERO
	return waypoints[mini(index, waypoints.size() - 1)]


## Wird vom Fahrzeug pro Physikschritt aufgerufen.
func update(v: Vehicle, _delta: float) -> void:
	if finished or waypoints.is_empty():
		v.set_controls(0.0, 1.0 if v.get_forward_speed() > 0.5 else 0.0, 0.0, v.get_forward_speed() < 0.5)
		return
	var pos: Vector3 = v.global_position
	# Wegpunkte weiterschalten
	while index < waypoints.size():
		var wp: Vector3 = waypoints[index]
		var d: float = Vector2(wp.x - pos.x, wp.z - pos.z).length()
		var is_last: bool = index == waypoints.size() - 1
		if d < (arrive_radius if is_last else maxf(arrive_radius, lookahead * 0.6)):
			if is_last:
				if loop:
					index = 0
				else:
					finished = true
					v.set_controls(0.0, 1.0, 0.0, false)
					return
			else:
				index += 1
		else:
			break
	var steer_target: Vector3 = _lookahead_point(pos, v.get_forward_speed())
	var to_t: Vector3 = steer_target - pos
	to_t.y = 0.0
	var fwd: Vector3 = -v.global_basis.z
	fwd.y = 0.0
	fwd = fwd.normalized()
	var right: Vector3 = fwd.cross(Vector3.UP)
	var ang: float = atan2(to_t.normalized().dot(right), to_t.normalized().dot(fwd))
	var steer: float = clampf(ang / deg_to_rad(maxf(v.spec.steer_max_deg * 0.8, 12.0)), -1.0, 1.0)

	var desired: float = target_speed
	if corner_slowdown:
		var fwd0: Vector3 = -v.global_basis.z
		fwd0.y = 0.0
		desired = minf(desired, _corner_speed(pos, fwd0.normalized()))
	# Zielnähe: abbremsen
	if index == waypoints.size() - 1 and not loop:
		var dl: float = pos.distance_to(waypoints[index])
		desired = minf(desired, maxf(3.0, dl * 0.6))
	# Starker Einschlag -> langsamer
	desired = minf(desired, lerpf(desired, 5.0, clampf(absf(ang) / 1.2, 0.0, 1.0)))
	var spd: float = v.get_forward_speed()
	var throttle: float = 0.0
	var brake: float = 0.0
	if _turn_phase == 0 and (ang > 2.2 or ang < -2.2):
		# Ziel liegt hinter dem Fahrzeug: Dreipunktwende beginnen
		_turn_phase = 1
		_turn_t = 0.0
		_turn_stuck = 0.0
		_turn_side = signf(ang) if ang != 0.0 else 1.0
	if _turn_phase != 0:
		if absf(ang) < 1.0:
			_turn_phase = 0
		else:
			_three_point_turn(v, _delta)
			return
	# Festgefahren (Gas, aber keine Bewegung): kurz mit Gegeneinschlag zurücksetzen
	if _recover_t > 0.0:
		_recover_t -= _delta
		v.set_controls(0.0, 0.7 if v.get_forward_speed() < 0.5 else 1.0, -steer, false)
		return
	if desired > 2.0 and absf(spd) < 0.4:
		_stall_t += _delta
		if _stall_t > 1.5:
			_stall_t = 0.0
			_recover_t = 1.3
	else:
		_stall_t = 0.0
	if spd < desired - 0.5:
		throttle = clampf((desired - spd) * 0.35 + 0.25, 0.0, 1.0)
	elif spd > desired + 1.0:
		brake = clampf((spd - desired) * 0.35, 0.0, 1.0)
	v.set_controls(throttle, brake, steer, false)


func _lookahead_point(pos: Vector3, speed: float) -> Vector3:
	var la: float = lookahead + absf(speed) * 0.35
	var prev: Vector3 = pos
	var remaining: float = la
	for i: int in range(index, waypoints.size()):
		var wp: Vector3 = waypoints[i]
		var seg: float = Vector2(wp.x - prev.x, wp.z - prev.z).length()
		if seg >= remaining:
			return prev.lerp(wp, remaining / maxf(seg, 0.001))
		remaining -= seg
		prev = wp
	return waypoints[waypoints.size() - 1]


## Kurvengeschwindigkeit: für jeden Wegpunkt der nächsten ~70 m die aufsummierte Richtungsänderung
## über die folgenden 20 m (geglättete Kurven bestehen aus vielen kleinen Knicken); Bremsweg berücksichtigt.
func _corner_speed(pos: Vector3, fwd: Vector3 = Vector3.ZERO) -> float:
	var n: int = waypoints.size()
	if index + 1 >= n:
		return target_speed
	var result: float = target_speed
	# Bereits begonnene Kurve: Winkel zwischen Fahrzeugrichtung und dem Weg in ~12 m
	if fwd != Vector3.ZERO:
		var ahead: Vector3 = _lookahead_point(pos, 12.0 / 0.35 - lookahead / 0.35)
		var to_a: Vector2 = Vector2(ahead.x - pos.x, ahead.z - pos.z)
		if to_a.length() > 2.0:
			var heading_turn: float = absf(Vector2(fwd.x, fwd.z).angle_to(to_a)) * 2.0
			result = minf(result, lerpf(target_speed, 6.0, clampf(heading_turn / 1.5, 0.0, 1.0)))
	var dist: float = Vector2(waypoints[index].x - pos.x, waypoints[index].z - pos.z).length()
	var k: int = index
	while k + 1 < n and dist < 70.0:
		var turn: float = 0.0
		var span: float = 0.0
		var m: int = k
		while m + 2 < n and span < 20.0:
			var a: Vector2 = Vector2(waypoints[m + 1].x - waypoints[m].x, waypoints[m + 1].z - waypoints[m].z)
			var b: Vector2 = Vector2(waypoints[m + 2].x - waypoints[m + 1].x, waypoints[m + 2].z - waypoints[m + 1].z)
			if a.length() > 0.3 and b.length() > 0.3:
				turn += absf(a.angle_to(b))
			span += a.length()
			m += 1
		var v_corner: float = lerpf(target_speed, 6.0, clampf(turn / 1.5, 0.0, 1.0))
		result = minf(result, sqrt(v_corner * v_corner + 2.0 * 4.5 * dist))
		dist += Vector2(waypoints[k + 1].x - waypoints[k].x, waypoints[k + 1].z - waypoints[k].z).length()
		k += 1
	return result


## Wechselt zwischen Rückwärts (Einschlag zur Gegenseite) und Vorwärts (Einschlag zur Zielseite),
## bis das Ziel vor dem Fahrzeug liegt. Phasenwechsel nach Zeit oder wenn das Fahrzeug festhängt.
func _three_point_turn(v: Vehicle, delta: float) -> void:
	_turn_t += delta
	var spd: float = absf(v.get_forward_speed())
	if _turn_t > 0.6 and spd < 0.3:
		_turn_stuck += delta
	else:
		_turn_stuck = 0.0
	if _turn_t > (2.0 if _turn_phase == 1 else 3.0) or _turn_stuck > 0.5:
		_turn_phase = 2 if _turn_phase == 1 else 1
		_turn_t = 0.0
		_turn_stuck = 0.0
	# Fahrzeuglogik: Bremse im Stand bzw. bei Rückwärtsfahrt = Rückwärtsgas, Gas bei Rückwärtsfahrt = Bremsen
	if _turn_phase == 1:
		if v.get_forward_speed() > 0.5:
			v.set_controls(0.0, 1.0, -_turn_side, false)
		else:
			v.set_controls(0.0, 0.6, -_turn_side, false)
	else:
		v.set_controls(0.55, 0.0, _turn_side, false)
