class_name AnimalAgent
extends Node3D
## Einzelnes Tier: Zustände Ruhe / Umherstreifen / Flucht / Fliegen / Folgen, Aufenthaltsbereich (Rechteck, Polygon, Kreis)
## oder Halter (Hund). Einfache prozedurale Animation (Beine, Flügel, Kopf). Keine Kollision (Tiere blockieren nichts).

enum State { IDLE, WANDER, FLEE, FLY, FOLLOW }

var sid: String = ""
var data: Dictionary = {}
var state: State = State.IDLE
var speed: float = 1.0
var flee_dist: float = 0.0
var can_fly: bool = false
var swims: bool = false
var ground_y: float = 0.0
## Aufenthaltsbereich
var area_kind: String = "circle"             ## rect | poly | circle | follow
var area_center: Vector2 = Vector2.ZERO
var area_half: Vector2 = Vector2(5, 5)       ## rect: halbe Ausdehnung (lokal); circle: x = Radius
var area_rot: float = 0.0
var area_poly: PackedVector2Array = PackedVector2Array()
var follow_target: Node3D = null
var gone: bool = false                        ## weggeflogen -> Manager entfernt/ersetzt

var _target: Vector2 = Vector2.ZERO
var _timer: float = 0.0
var _phase: float = 0.0
var _fly_h: float = 0.0
var _legs: Array[Node3D] = []
var _wings: Array[Node3D] = []
var _head: Node3D
var _rng := RandomNumberGenerator.new()
var _anim_lod: bool = true


func setup(species_id: String, seed_value: int) -> void:
	sid = species_id
	data = AnimalModels.species().get(sid, {})
	speed = float(data.get("speed", 1.0))
	flee_dist = float(data.get("flee", 0.0))
	can_fly = bool(data.get("fly", false))
	swims = bool(data.get("swim", false))
	_rng.seed = seed_value
	var model: Node3D = AnimalModels.build(sid)
	add_child(model)
	for c: Node in model.get_children():
		if c.name.begins_with("Bein_"):
			_legs.append(c)
		elif c.name.begins_with("Fluegel_"):
			_wings.append(c)
		elif c.name == "Kopf":
			_head = c
	_timer = _rng.randf_range(0.5, 3.0)
	_phase = _rng.randf() * TAU


func in_area(p: Vector2) -> bool:
	match area_kind:
		"rect":
			var d: Vector2 = (p - area_center).rotated(area_rot)
			return absf(d.x) <= area_half.x and absf(d.y) <= area_half.y
		"poly":
			return Geometry2D.is_point_in_polygon(p, area_poly)
		"circle":
			return p.distance_to(area_center) <= area_half.x
	return true


func random_point() -> Vector2:
	for i: int in 12:
		var p: Vector2
		match area_kind:
			"rect":
				p = area_center + Vector2(_rng.randf_range(-area_half.x, area_half.x) * 0.9, _rng.randf_range(-area_half.y, area_half.y) * 0.9).rotated(-area_rot)
			"poly":
				var bb: Rect2 = Rect2(area_poly[0], Vector2.ZERO)
				for q: Vector2 in area_poly:
					bb = bb.expand(q)
				p = Vector2(_rng.randf_range(bb.position.x, bb.end.x), _rng.randf_range(bb.position.y, bb.end.y))
			_:
				p = area_center + Vector2.from_angle(_rng.randf() * TAU) * _rng.randf() * area_half.x
		if in_area(p):
			return p
	return area_center


## Schreck durch Lärm (Hupe, Unfall): Vögel fliegen auf, scheue Tiere fliehen.
func scare(from: Vector3) -> void:
	if can_fly and state != State.FLY:
		_start_fly()
	elif flee_dist > 0.0 and state != State.FLEE and state != State.FOLLOW:
		_flee_from(Vector2(from.x, from.z))


func _start_fly() -> void:
	state = State.FLY
	_timer = _rng.randf_range(4.0, 7.0)
	var away: Vector2 = Vector2.from_angle(_rng.randf() * TAU)
	_target = Vector2(global_position.x, global_position.z) + away * 60.0
	AudioManager.play_3d(str(data.get("sound", "tier_flattern")), global_position, -14.0, _rng.randf_range(0.9, 1.2))


func _flee_from(src: Vector2) -> void:
	state = State.FLEE
	_timer = 2.5
	var p: Vector2 = Vector2(global_position.x, global_position.z)
	var dir: Vector2 = (p - src).normalized()
	if dir == Vector2.ZERO:
		dir = Vector2.RIGHT
	_target = p + dir * 12.0


func tick(delta: float, threat: Vector3, threat_speed: float, cam_dist: float) -> void:
	_anim_lod = cam_dist < 70.0
	var p: Vector2 = Vector2(global_position.x, global_position.z)
	var tp: Vector2 = Vector2(threat.x, threat.z)
	var move_speed: float = 0.0
	_timer -= delta
	match state:
		State.FOLLOW:
			if follow_target == null or not is_instance_valid(follow_target):
				gone = true
				return
			var ft: Vector3 = follow_target.global_position + follow_target.global_basis.x * 0.8 + follow_target.global_basis.z * 0.9
			_target = Vector2(ft.x, ft.z)
			var dist: float = p.distance_to(_target)
			move_speed = clampf(dist * 1.5, 0.0, speed * 2.5) if dist > 0.4 else 0.0
			ground_y = follow_target.global_position.y
		State.IDLE, State.WANDER:
			# Bedrohung (Spieler / schnelles Fahrzeug) in der Nähe?
			var fd: float = flee_dist * (1.8 if threat_speed > 4.0 else 1.0)
			if fd > 0.0 and p.distance_to(tp) < fd:
				if can_fly:
					_start_fly()
				else:
					_flee_from(tp)
				return
			if state == State.IDLE:
				if _timer <= 0.0:
					state = State.WANDER
					_target = random_point()
					_timer = 12.0
			else:
				move_speed = speed
				if p.distance_to(_target) < 0.4 or _timer <= 0.0:
					state = State.IDLE
					_timer = _rng.randf_range(1.5, 6.0)
		State.FLEE:
			move_speed = speed * 2.4
			if _timer <= 0.0 or p.distance_to(_target) < 0.5:
				state = State.IDLE
				_timer = _rng.randf_range(2.0, 4.0)
		State.FLY:
			move_speed = 7.0
			_fly_h = minf(_fly_h + delta * 3.0, 12.0)
			if _timer <= 0.0:
				gone = true
				return
	# Bewegen
	if move_speed > 0.0:
		var dir: Vector2 = _target - p
		var dl: float = dir.length()
		if dl > 0.01:
			var step: float = minf(dl, move_speed * delta)
			var np: Vector2 = p + dir / dl * step
			if state == State.FLY or state == State.FOLLOW or in_area(np) or not in_area(p):
				p = np
			else:
				_target = random_point()
			var yaw: float = atan2(-dir.x, -dir.y)
			rotation.y = lerp_angle(rotation.y, yaw, clampf(delta * 6.0, 0.0, 1.0))
	var y: float = ground_y + _fly_h + (-0.18 if swims and state != State.FLY and area_kind == "poly" else 0.0)
	global_position = Vector3(p.x, y, p.y)
	# Animation
	if _anim_lod:
		_phase += delta * (move_speed * 6.0 + (14.0 if state == State.FLY else 0.0))
		var amp: float = clampf(move_speed / maxf(speed, 0.1), 0.0, 1.0) * 0.5
		for i: int in _legs.size():
			_legs[i].rotation.x = sin(_phase + (PI if i % 2 == 0 else 0.0) + (PI * 0.5 if i >= 2 else 0.0)) * amp
		for w: Node3D in _wings:
			w.rotation.z = sin(_phase * 1.6) * 0.9 if state == State.FLY else 0.0
		if _head != null:
			_head.rotation.x = sin(_phase * 0.3) * 0.08 if state == State.IDLE else 0.0
