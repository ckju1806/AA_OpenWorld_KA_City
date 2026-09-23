class_name Autopilot
extends RefCounted
## Einfacher Wegpunkt-Folger (Pure Pursuit) für Fahrzeuge.
## Grundlage für Verkehrs-/Polizei-KI und automatisierte Fahrtests.

var waypoints: PackedVector3Array = PackedVector3Array()
var index: int = 0
var target_speed: float = 12.0      ## m/s
var lookahead: float = 7.0
var arrive_radius: float = 5.0
var finished: bool = false
var loop: bool = false
var corner_slowdown: bool = true


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
		desired = minf(desired, _corner_speed(pos))
	# Zielnähe: abbremsen
	if index == waypoints.size() - 1 and not loop:
		var dl: float = pos.distance_to(waypoints[index])
		desired = minf(desired, maxf(3.0, dl * 0.6))
	# Starker Einschlag -> langsamer
	desired = minf(desired, lerpf(desired, 5.0, clampf(absf(ang) / 1.2, 0.0, 1.0)))
	var spd: float = v.get_forward_speed()
	var throttle: float = 0.0
	var brake: float = 0.0
	if ang > 2.2 or ang < -2.2:
		# Ziel liegt hinter dem Fahrzeug: rückwärts wenden
		v.set_controls(0.0, 0.6, -steer, false)
		return
	if spd < desired - 0.5:
		throttle = clampf((desired - spd) * 0.35 + 0.25, 0.0, 1.0)
	elif spd > desired + 1.5:
		brake = clampf((spd - desired) * 0.15, 0.0, 1.0)
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


## Kurvengeschwindigkeit aus dem Knickwinkel der nächsten Wegpunkte.
func _corner_speed(pos: Vector3) -> float:
	if index + 1 >= waypoints.size():
		return target_speed
	var a: Vector3 = waypoints[index] - pos
	var b: Vector3 = waypoints[index + 1] - waypoints[index]
	a.y = 0.0
	b.y = 0.0
	if a.length() < 0.5 or b.length() < 0.5:
		return target_speed
	var turn: float = a.normalized().angle_to(b.normalized())
	var dist: float = a.length()
	var v_corner: float = lerpf(target_speed, 6.0, clampf(turn / 1.5, 0.0, 1.0))
	# Bremsweg berücksichtigen
	return minf(target_speed, sqrt(v_corner * v_corner + 2.0 * 6.0 * dist))
