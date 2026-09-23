class_name Pedestrian
extends Node3D
## Passant: bewegt sich kinematisch auf dem Gehwegnetz oder in Flanierbereichen.
## Zustände: Gehen, Warten, Ausweichen, Flucht, Umgestoßen. Blockiert keine Fahrzeuge physikalisch,
## wird aber über eine Area erkannt (Fahrzeug-KI bremst, Zusammenstöße werden gemeldet).

enum State { WALK, WAIT, AVOID, FLEE, DOWN }

var manager: Node = null
var net: SidewalkNetwork
var state: State = State.WALK
var walk_speed: float = 1.4
var rng: RandomNumberGenerator

## Gehweg-Modus
var loop_i: int = -1
var vert_i: int = 0
var dir_sign: int = 1
## Querung / Flanieren: explizites Ziel
var target: Vector2 = Vector2.INF
var crossing: bool = false
var cross_to: Array = []
var wander_area: int = -1

var rig: HumanoidRig
var area: Area3D
var _state_t: float = 0.0
var _flee_dir: Vector2 = Vector2.ZERO
var _ground_t: float = 0.0
var _anim_skip: int = 0
var _speed_now: float = 0.0
var _y: float = 0.12
var _wall_t: float = 0.0


func setup(p_manager: Node, p_net: SidewalkNetwork, seed_value: int) -> void:
	manager = p_manager
	net = p_net
	rng = DetRng.make_rng(seed_value)
	walk_speed = rng.randf_range(1.15, 1.65)
	rig = HumanoidRig.new()
	add_child(rig)
	rig.build(_random_look())
	area = Area3D.new()
	area.collision_layer = Layers.NPC
	area.collision_mask = Layers.VEHICLE
	area.monitoring = true
	area.monitorable = true
	var cs := CollisionShape3D.new()
	var cap := CapsuleShape3D.new()
	cap.radius = 0.35
	cap.height = 1.75
	cs.shape = cap
	cs.position = Vector3(0, 0.9, 0)
	area.add_child(cs)
	add_child(area)
	area.body_entered.connect(_on_body_entered)


func _random_look() -> Dictionary:
	var skins: Array[Color] = [Color(0.96, 0.8, 0.68), Color(0.87, 0.67, 0.52), Color(0.72, 0.52, 0.38), Color(0.5, 0.35, 0.25), Color(0.36, 0.25, 0.18)]
	var clothes: Array[Color] = [Color(0.2, 0.3, 0.5), Color(0.6, 0.15, 0.15), Color(0.2, 0.45, 0.3), Color(0.85, 0.8, 0.7), Color(0.15, 0.15, 0.17),
		Color(0.55, 0.45, 0.3), Color(0.7, 0.55, 0.2), Color(0.45, 0.25, 0.45), Color(0.9, 0.9, 0.92), Color(0.3, 0.55, 0.65)]
	var pants: Array[Color] = [Color(0.15, 0.17, 0.25), Color(0.1, 0.1, 0.1), Color(0.35, 0.3, 0.25), Color(0.25, 0.3, 0.4), Color(0.5, 0.45, 0.38)]
	var hair: Array[Color] = [Color(0.1, 0.08, 0.06), Color(0.35, 0.22, 0.12), Color(0.7, 0.55, 0.3), Color(0.55, 0.55, 0.55), Color(0.5, 0.2, 0.1)]
	var d: Dictionary = {
		"skin": skins[rng.randi() % skins.size()], "shirt": clothes[rng.randi() % clothes.size()],
		"pants": pants[rng.randi() % pants.size()], "shoes": Color(0.12, 0.1, 0.09),
		"hair": hair[rng.randi() % hair.size()], "hair_style": rng.randi() % 3,
		"height": rng.randf_range(0.9, 1.06),
	}
	if rng.randf() < 0.45:
		d["jacket"] = clothes[rng.randi() % clothes.size()]
	return d


## Auf einer Gehwegschleife platzieren.
func place_on_loop(li: int, vi: int, t: float) -> void:
	loop_i = li
	vert_i = vi
	dir_sign = 1 if rng.randf() < 0.5 else -1
	wander_area = -1
	crossing = false
	var lp: PackedVector2Array = net.loops[li]
	var a: Vector2 = lp[vi]
	var b: Vector2 = lp[(vi + 1) % lp.size()]
	var p: Vector2 = a.lerp(b, t)
	target = b if dir_sign > 0 else a
	if dir_sign < 0:
		vert_i = vi
	else:
		vert_i = (vi + 1) % lp.size()
	_reset_at(p)


func place_in_area(ai: int) -> void:
	wander_area = ai
	loop_i = -1
	crossing = false
	var p: Vector2 = net.random_wander_point(net.wander_areas[ai], rng)
	target = net.random_wander_point(net.wander_areas[ai], rng)
	_reset_at(p)


func _reset_at(p: Vector2) -> void:
	state = State.WALK
	_state_t = 0.0
	_y = net.slab_h
	global_position = Vector3(p.x, _y, p.y)
	rig.visible = true
	visible = true
	reset_physics_interpolation()


func _physics_process(delta: float) -> void:
	_state_t += delta
	var pos2: Vector2 = Vector2(global_position.x, global_position.z)
	var speed: float = 0.0
	var move_dir: Vector2 = Vector2.ZERO
	match state:
		State.DOWN:
			if _state_t > 4.5:
				state = State.WALK
				_state_t = 0.0
		State.WAIT:
			if _state_t > float(rng.randf_range(2.0, 6.0)) or (crossing and _crossing_clear(pos2)):
				state = State.WALK
				_state_t = 0.0
		State.FLEE:
			speed = 4.6
			move_dir = _flee_dir
			if _state_t > 4.0:
				state = State.WALK
				_state_t = 0.0
				_retarget_after_flee(pos2)
		State.AVOID:
			speed = 3.2
			move_dir = _flee_dir
			if _state_t > 0.9:
				state = State.WALK
				_state_t = 0.0
				_retarget_after_flee(pos2)
		State.WALK:
			speed = walk_speed * (1.35 if crossing else 1.0)
			if target == Vector2.INF:
				_pick_next(pos2)
			var to: Vector2 = target - pos2
			if to.length() < 0.4:
				_pick_next(pos2)
				to = target - pos2
			move_dir = to.normalized() if to.length() > 0.01 else Vector2.ZERO
	if move_dir.length() > 0.01 and speed > 0.0:
		_wall_t -= delta
		if _wall_t <= 0.0:
			_wall_t = 0.2
			if _blocked(pos2, move_dir):
				if state == State.WALK:
					dir_sign = -dir_sign
					_retarget_after_flee(pos2)
					if loop_i >= 0:
						var lp2: PackedVector2Array = net.loops[loop_i]
						vert_i = (vert_i + dir_sign + lp2.size()) % lp2.size()
						target = lp2[vert_i]
				else:
					var alt: Vector2 = Vector2(-move_dir.y, move_dir.x)
					if _blocked(pos2, alt):
						alt = -alt
					if _blocked(pos2, alt):
						state = State.WAIT
						_state_t = 0.0
						alt = Vector2.ZERO
					_flee_dir = alt
				move_dir = Vector2.ZERO
	if move_dir.length() > 0.01 and speed > 0.0:
		var step: Vector2 = move_dir * speed * delta
		pos2 += step
		var yaw: float = atan2(-move_dir.x, -move_dir.y)
		rotation.y = lerp_angle(rotation.y, yaw, clampf(delta * 8.0, 0.0, 1.0))
	_speed_now = speed if move_dir.length() > 0.01 else 0.0
	_ground_t -= delta
	if _ground_t <= 0.0:
		_ground_t = 0.35
		_y = _ground_height(pos2)
	global_position = Vector3(pos2.x, lerpf(global_position.y, _y, clampf(delta * 10.0, 0.0, 1.0)), pos2.y)
	_animate(delta)


func _animate(delta: float) -> void:
	var cam_d: float = float(manager.call("camera_distance", global_position)) if manager != null else 0.0
	if cam_d > 110.0:
		rig.visible = false
		return
	rig.visible = true
	var skip: int = 1 if cam_d < 40.0 else 3
	_anim_skip = (_anim_skip + 1) % skip
	if _anim_skip != 0:
		return
	var pose: HumanoidRig.Pose = HumanoidRig.Pose.IDLE
	if state == State.DOWN:
		pose = HumanoidRig.Pose.DOWN
	elif _speed_now > 3.0:
		pose = HumanoidRig.Pose.RUN
	elif _speed_now > 0.2:
		pose = HumanoidRig.Pose.WALK
	rig.animate(delta * float(skip), _speed_now, pose)


## Wand/Hindernis in Bewegungsrichtung (Hauswände, Stadtmobiliar)?
func _blocked(p: Vector2, dir: Vector2) -> bool:
	var space: PhysicsDirectSpaceState3D = get_world_3d().direct_space_state
	var from: Vector3 = Vector3(p.x, global_position.y + 1.0, p.y)
	var to: Vector3 = from + Vector3(dir.x, 0.0, dir.y) * 1.1
	var q := PhysicsRayQueryParameters3D.create(from, to, Layers.WORLD)
	return not space.intersect_ray(q).is_empty()


func _ground_height(p: Vector2) -> float:
	var space: PhysicsDirectSpaceState3D = get_world_3d().direct_space_state
	var q := PhysicsRayQueryParameters3D.create(Vector3(p.x, 2.5, p.y), Vector3(p.x, -0.5, p.y), Layers.WORLD)
	var hit: Dictionary = space.intersect_ray(q)
	if hit.is_empty():
		return 0.0
	var y: float = (hit.position as Vector3).y
	return y if y < 0.6 else _y


func _pick_next(pos2: Vector2) -> void:
	if wander_area >= 0:
		if rng.randf() < 0.25:
			state = State.WAIT
			_state_t = 0.0
		target = net.random_wander_point(net.wander_areas[wander_area], rng)
		return
	if loop_i < 0:
		target = Vector2.INF
		return
	var lp: PackedVector2Array = net.loops[loop_i]
	if crossing:
		crossing = false
	# An Ecken ggf. die Straße queren
	var key: String = "%d:%d" % [loop_i, vert_i]
	if net.crossings.has(key) and rng.randf() < 0.3:
		var opts: Array = net.crossings[key]
		var pick: Array = opts[rng.randi() % opts.size()]
		cross_to = pick
		var dest: Vector2 = net.loops[int(pick[0])][int(pick[1])]
		crossing = true
		loop_i = int(pick[0])
		vert_i = int(pick[1])
		target = dest
		if not _crossing_clear(pos2):
			state = State.WAIT
			_state_t = 0.0
		return
	if rng.randf() < 0.06:
		state = State.WAIT
		_state_t = 0.0
	vert_i = (vert_i + dir_sign + lp.size()) % lp.size()
	target = lp[vert_i]


func _crossing_clear(pos2: Vector2) -> bool:
	if manager == null:
		return true
	return not bool(manager.call("vehicle_near", Vector3(pos2.x, 0, pos2.y), 16.0, 2.5))


func _retarget_after_flee(pos2: Vector2) -> void:
	if wander_area >= 0:
		target = net.random_wander_point(net.wander_areas[wander_area], rng)
		return
	if loop_i >= 0:
		var lp: PackedVector2Array = net.loops[loop_i]
		var best: int = 0
		var bd: float = INF
		for i: int in lp.size():
			var d: float = lp[i].distance_to(pos2)
			if d < bd:
				bd = d
				best = i
		vert_i = best
		target = lp[best]
		crossing = false


## Reaktion auf Gefahr (Hupe, Unfall, nahende Fahrzeuge).
func scare(from: Vector3, strong: bool) -> void:
	if state == State.DOWN:
		return
	var away: Vector2 = Vector2(global_position.x - from.x, global_position.z - from.z)
	if away.length() < 0.01:
		away = Vector2(1, 0)
	_flee_dir = away.normalized()
	state = State.FLEE if strong else State.AVOID
	_state_t = 0.0


func dodge(vehicle_pos: Vector3, vehicle_vel: Vector3) -> void:
	if state == State.DOWN or state == State.FLEE:
		return
	var vdir: Vector2 = Vector2(vehicle_vel.x, vehicle_vel.z).normalized()
	var rel: Vector2 = Vector2(global_position.x - vehicle_pos.x, global_position.z - vehicle_pos.z)
	var side: Vector2 = Vector2(-vdir.y, vdir.x)
	if rel.dot(side) < 0.0:
		side = -side
	_flee_dir = side
	state = State.AVOID
	_state_t = 0.0


func _on_body_entered(body: Node3D) -> void:
	if state == State.DOWN or not body is Vehicle:
		return
	var v: Vehicle = body as Vehicle
	var spd: float = v.linear_velocity.length()
	if spd < 2.5:
		scare(v.global_position, false)
		return
	state = State.DOWN
	_state_t = 0.0
	AudioManager.play_3d("crash", global_position, -10.0, 1.4)
	if manager != null:
		manager.call("on_pedestrian_hit", self, v)


func is_down() -> bool:
	return state == State.DOWN
