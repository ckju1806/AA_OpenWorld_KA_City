class_name PoliceManager
extends Node
## Polizei und Fahndung: bewertet gemeldete Taten (Zeugen/Sicht), steuert Einheitenzahl je Stufe,
## Wahrnehmung per Sichtlinie (gestaffelt), Festnahme, Spawn außerhalb der Sicht.

const UNITS_BY_LEVEL: Array[int] = [1, 2, 3, 4]
const SEE_RANGE: Array[float] = [55.0, 60.0, 70.0, 80.0]
const ARREST_DIST: float = 7.0
const ARREST_TIME: float = 2.8

var game: Node
var graph: CityGraph
var lights: TrafficLights
var wanted: WantedLogic = WantedLogic.new()
var units: Array[Vehicle] = []
var arrest_progress: float = 0.0
var enabled: bool = true
var patrol_enabled: bool = true

var _spawn_t: float = 0.0
var _see_t: float = 0.0
var _see_index: int = 0
var _rng: RandomNumberGenerator = DetRng.make_rng(110)
var _any_seen: bool = false


func setup(p_game: Node, g: CityGraph, l: TrafficLights) -> void:
	game = p_game
	graph = g
	lights = l
	EventBus.crime_reported.connect(_on_crime)
	EventBus.vehicle_collision.connect(_on_vehicle_collision)
	wanted.level_changed.connect(func(lv: int) -> void:
		EventBus.wanted_changed.emit(lv)
		if lv > 0:
			AudioManager.play_2d("wanted_up", -4.0))
	wanted.state_changed.connect(func(s: String) -> void: EventBus.wanted_state_changed.emit(s))


func wanted_level() -> int:
	return wanted.level


## Ziel der Polizei: nur die zuletzt bekannte Position (keine Allwissenheit).
func police_goal() -> Vector3:
	return wanted.last_known


## Ziel je Einheit: bei Sichtkontakt die bekannte Position, in der Suchphase ein eigener Punkt im Suchgebiet
## (Radius wächst mit der Suchdauer) – die Einheiten verteilen sich statt alle zum selben Punkt zu fahren.
func police_goal_for(u: Node) -> Vector3:
	if wanted.state != "suche":
		return wanted.last_known
	var r: float = clampf(30.0 + wanted.search_time * 4.0, 30.0, 140.0)
	var h: int = u.get_instance_id()
	var ang: float = DetRng.hash01(h & 0xFFFF, int(wanted.search_time / 8.0), 3) * TAU
	var dist: float = r * (0.35 + 0.65 * DetRng.hash01(h & 0xFFFF, int(wanted.search_time / 8.0), 5))
	return wanted.last_known + Vector3(cos(ang), 0.0, sin(ang)) * dist


## Einsatz zu einem Ereignis (W7): eine Streife fährt mit Blaulicht hin und bleibt duration Sekunden.
var dispatch_units: Array[Vehicle] = []


func dispatch(pos: Vector3, duration: float) -> void:
	if not enabled:
		return
	var before: int = units.size()
	if not _try_spawn(pos):
		return
	var u: Vehicle = units.pop_back()
	if units.size() != before:
		return
	var drv: PoliceDriver = u.ai_controller as PoliceDriver
	drv.dispatch_goal = pos
	drv.dispatch_until = Time.get_ticks_msec() / 1000.0 + 35.0 + duration
	u.set_siren(true)
	dispatch_units.append(u)


## Straßensperren ab Fahndungsstufe 3: zwei Streifenwagen quer auf der Fahrbahn vor dem Spieler.
var roadblocks: Array[Vehicle] = []
var _roadblock_t: float = 20.0


func _manage_roadblocks(delta: float, p: Player, ppos: Vector3) -> void:
	for i: int in range(roadblocks.size() - 1, -1, -1):
		var rb: Vehicle = roadblocks[i]
		if not is_instance_valid(rb):
			roadblocks.remove_at(i)
			continue
		if (wanted.level < 3 or rb.global_position.distance_to(ppos) > 380.0) and not _visible(rb.global_position):
			rb.queue_free()
			roadblocks.remove_at(i)
	_roadblock_t -= delta
	if wanted.level < 3 or not p.is_in_vehicle() or _roadblock_t > 0.0 or roadblocks.size() >= 4:
		return
	_roadblock_t = 35.0
	var v: Vehicle = p.current_vehicle as Vehicle
	var fwd: Vector3 = v.linear_velocity
	fwd.y = 0.0
	if fwd.length() < 5.0:
		return
	var ahead: Vector3 = ppos + fwd.normalized() * 200.0
	var ne: Dictionary = graph.nearest_edge_point(Vector2(ahead.x, ahead.z), "drive", 60.0)
	if int(ne.edge) < 0:
		return
	var e: int = int(ne.edge)
	var pt: Vector2 = ne.point
	var p3: Vector3 = Vector3(pt.x, 0.3, pt.y)
	var city: CityWorld = game.call("get_city")
	if _visible(p3) or (city != null and not city.is_loaded_at(p3)):
		return
	var dir: Vector2 = (graph.node_pos[graph.edge_b[e]] - graph.node_pos[graph.edge_a[e]]).normalized()
	var right: Vector2 = Vector2(-dir.y, dir.x)
	var half: float = graph.edge_width(e) * 0.25
	for s: float in [-1.0, 1.0]:
		var c: Vector2 = pt + right * half * s
		var yaw: float = atan2(-right.x, -right.y) + (0.35 * s)
		var u: Vehicle = game.call("spawn_vehicle", "polizei", Vector3(c.x, 0.3, c.y), yaw, Color(-1, 0, 0), Vehicle.Ownership.POLICE, "") as Vehicle
		u.add_to_group("police")
		u.add_to_group("roadblock")
		u.set_lights(true)
		u.set_siren(true)
		u.driver = Vehicle.Driver.NONE
		roadblocks.append(u)
	EventBus.notify.emit("Straßensperre voraus!", "warnung")


func _player() -> Player:
	return game.get("player") as Player


func _player_pos() -> Vector3:
	var p: Player = _player()
	return p.current_vehicle.global_position if p.is_in_vehicle() else p.global_position


func _on_crime(kind: String, pos: Vector3, witnessed: bool) -> void:
	if CheatManager.is_active("UNSICHTBAR"):
		return
	var w: bool = witnessed
	if not w:
		w = police_can_see(pos)
	if not w and game.get("peds") != null:
		w = int((game.get("peds") as PedestrianManager).count_witnesses(pos, 25.0)) > 0
	var before: int = wanted.level
	wanted.report_crime(kind, pos, w)
	if wanted.level > before:
		EventBus.notify.emit("Fahndung: %s" % wanted.last_reason, "warnung")


func _on_vehicle_collision(v: Node, impulse: float, other: Node) -> void:
	if impulse < 3.0 or not v is Vehicle:
		return
	var pv: Vehicle = v as Vehicle
	if pv.driver == Vehicle.Driver.PLAYER and other is Vehicle and (other as Vehicle).ownership == Vehicle.Ownership.POLICE:
		EventBus.crime_reported.emit("polizei_rammen", pv.global_position, true)


func set_wanted(level: int, reason: String, pos: Vector3) -> void:
	wanted.force_level(level, pos, reason)


func reset_wanted() -> void:
	wanted.clear()
	arrest_progress = 0.0


func police_within(pos: Vector3, radius: float) -> bool:
	for u: Vehicle in units:
		if is_instance_valid(u) and u.global_position.distance_to(pos) < radius:
			return true
	return false


## Kann irgendeine Einheit die Position sehen (Distanz + freie Sichtlinie)?
func police_can_see(pos: Vector3) -> bool:
	for u: Vehicle in units + dispatch_units + roadblocks:
		if is_instance_valid(u) and _unit_sees(u, pos):
			return true
	return false


func _unit_sees(u: Vehicle, pos: Vector3) -> bool:
	var range_m: float = SEE_RANGE[clampi(wanted.level, 0, 3)]
	var from: Vector3 = u.global_position + Vector3.UP * 1.5
	var to: Vector3 = pos + Vector3.UP * 1.0
	if from.distance_to(to) > range_m:
		return false
	if from.distance_to(to) < 12.0:
		return true
	var space: PhysicsDirectSpaceState3D = get_viewport().get_world_3d().direct_space_state
	var q := PhysicsRayQueryParameters3D.create(from, to, Layers.WORLD)
	return space.intersect_ray(q).is_empty()


func _physics_process(delta: float) -> void:
	if game == null:
		return
	var p: Player = _player()
	if p == null:
		return
	var ppos: Vector3 = _player_pos()
	# Wahrnehmung (gestaffelt: pro Takt eine Einheit)
	_see_t -= delta
	if _see_t <= 0.0 and not units.is_empty():
		_see_t = 0.3 / float(units.size())
		_see_index = (_see_index + 1) % units.size()
		var u: Vehicle = units[_see_index]
		if is_instance_valid(u) and u.ai_controller is PoliceDriver:
			var drv: PoliceDriver = u.ai_controller as PoliceDriver
			drv.sees_player = wanted.level > 0 and not p.is_dead and _unit_sees(u, ppos)
			drv.chase_target = ppos + ((p.current_vehicle as Vehicle).linear_velocity * 0.5 if p.is_in_vehicle() else Vector3.ZERO)
	_any_seen = false
	for u2: Vehicle in units:
		if is_instance_valid(u2) and u2.ai_controller is PoliceDriver and (u2.ai_controller as PoliceDriver).sees_player:
			_any_seen = true
	wanted.update(delta, _any_seen, ppos)
	_update_arrest(delta, p, ppos)
	_spawn_t -= delta
	if _spawn_t <= 0.0:
		_spawn_t = 0.8
		_manage_units(ppos)
		_manage_dispatch(ppos)
	_manage_roadblocks(delta, p, ppos)


func _update_arrest(delta: float, p: Player, ppos: Vector3) -> void:
	if wanted.level == 0 or p.is_dead:
		arrest_progress = 0.0
		return
	var slow: bool = true
	if p.is_in_vehicle():
		slow = (p.current_vehicle as Vehicle).linear_velocity.length() < 1.5
	var close: bool = false
	for u: Vehicle in units:
		if is_instance_valid(u) and u.ai_controller is PoliceDriver and u.global_position.distance_to(ppos) < ARREST_DIST and (u.ai_controller as PoliceDriver).sees_player:
			close = true
	if close and slow:
		arrest_progress += delta / ARREST_TIME
		if arrest_progress >= 1.0:
			arrest_progress = 0.0
			_bust()
	else:
		arrest_progress = maxf(0.0, arrest_progress - delta * 0.8)


func _bust() -> void:
	wanted.clear()
	EventBus.player_busted.emit()


func _manage_units(ppos: Vector3) -> void:
	for i: int in range(units.size() - 1, -1, -1):
		var u: Vehicle = units[i]
		if not is_instance_valid(u) or u.driver == Vehicle.Driver.PLAYER:
			units.remove_at(i)
			continue
		var drv: PoliceDriver = u.ai_controller as PoliceDriver
		var d: float = u.global_position.distance_to(ppos)
		var surplus: bool = units.size() > _target_units()
		var stuck: bool = drv == null or drv.wants_despawn
		if (d > 320.0 or ((surplus or stuck) and d > 60.0)) and not _visible(u.global_position):
			u.queue_free()
			units.remove_at(i)
	if not enabled:
		return
	if units.size() < _target_units():
		_try_spawn(ppos)


func _manage_dispatch(ppos: Vector3) -> void:
	var now: float = Time.get_ticks_msec() / 1000.0
	for i: int in range(dispatch_units.size() - 1, -1, -1):
		var u: Vehicle = dispatch_units[i]
		if not is_instance_valid(u) or u.driver == Vehicle.Driver.PLAYER:
			dispatch_units.remove_at(i)
			continue
		var drv: PoliceDriver = u.ai_controller as PoliceDriver
		var over: bool = drv == null or now > drv.dispatch_until
		if (over or u.global_position.distance_to(ppos) > 380.0) and not _visible(u.global_position):
			u.queue_free()
			dispatch_units.remove_at(i)


func _target_units() -> int:
	if wanted.level == 0:
		return 1 if patrol_enabled else 0
	var n: int = UNITS_BY_LEVEL[clampi(wanted.level, 0, 3)]
	if Settings.police_difficulty == 0 or (Settings.simplified_missions and game.get("missions") != null and (game.get("missions") as MissionSystem).has_active()):
		n = maxi(1, n - 1)
	elif Settings.police_difficulty == 2:
		n += 1
	return n


func _visible(pos: Vector3) -> bool:
	var cam: Camera3D = get_viewport().get_camera_3d()
	if cam == null:
		return false
	if not cam.is_position_in_frustum(pos + Vector3.UP):
		return false
	if cam.global_position.distance_to(pos) > 220.0:
		return false
	var space: PhysicsDirectSpaceState3D = get_viewport().get_world_3d().direct_space_state
	var q := PhysicsRayQueryParameters3D.create(cam.global_position, pos + Vector3.UP * 1.2, Layers.WORLD)
	return space.intersect_ray(q).is_empty()


## Spawn auf einer Fahrspur 110–240 m vom Spieler entfernt, außerhalb der Sicht.
func _try_spawn(ppos: Vector3) -> bool:
	var dmin: float = 90.0 if wanted.level >= 3 else 110.0
	var near: PackedInt32Array = graph.edges_near_where(Vector2(ppos.x, ppos.z), 240.0, false, 25.0)
	if near.is_empty():
		return false
	for attempt: int in 16:
		var e: int = near[_rng.randi() % near.size()]
		var a: int = graph.edge_a[e]
		var b: int = graph.edge_b[e]
		if _rng.randf() < 0.5:
			var t2: int = a
			a = b
			b = t2
		var pa: Vector2 = graph.node_pos[a]
		var pb: Vector2 = graph.node_pos[b]
		var dir: Vector2 = (pb - pa).normalized()
		var p2: Vector2 = pa.lerp(pb, _rng.randf_range(0.3, 0.7)) + Vector2(-dir.y, dir.x) * graph.lane_offset(e, LaneDriver.LANE_OFFSET)
		var pos: Vector3 = Vector3(p2.x, 0.0, p2.y)
		var d: float = pos.distance_to(ppos)
		if d < dmin or d > 240.0 or _visible(pos):
			continue
		var city: CityWorld = game.call("get_city")
		if city != null and not city.is_loaded_at(pos):
			continue
		var spec: VehicleSpec = VehicleSpec.get_spec("polizei")
		var space: PhysicsDirectSpaceState3D = get_viewport().get_world_3d().direct_space_state
		var box := BoxShape3D.new()
		box.size = Vector3(spec.width + 1.0, 1.6, spec.length + 6.0)
		var q := PhysicsShapeQueryParameters3D.new()
		q.shape = box
		q.transform = Transform3D(Basis(Vector3.UP, atan2(-dir.x, -dir.y)), pos + Vector3.UP * 1.1)
		q.collision_mask = Layers.WORLD | Layers.VEHICLE | Layers.PLAYER
		if not space.intersect_shape(q, 1).is_empty():
			continue
		var u: Vehicle = game.call("spawn_vehicle", "polizei", pos, atan2(-dir.x, -dir.y), spec.colors[0], Vehicle.Ownership.POLICE, "") as Vehicle
		u.add_to_group("police")
		var drv := PoliceDriver.new(_rng.randi())
		drv.manager = self
		drv.setup(graph, lights, [a, b] as Array[int])
		u.ai_controller = drv
		u.driver = Vehicle.Driver.AI
		u.set_lights(true)
		units.append(u)
		return true
	return false


func active_units() -> int:
	return units.size()
