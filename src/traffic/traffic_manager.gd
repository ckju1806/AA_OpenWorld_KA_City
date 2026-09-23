class_name TrafficManager
extends Node
## Straßenverkehr: hält eine konfigurierbare Anzahl KI-Fahrzeuge im Umkreis des Spielers.
## Spawn nur außerhalb des Blickfelds bzw. in größerer Distanz, Despawn weit weg/festgefahren/außer Sicht.
## Obergrenze -> keine wachsenden Objektmengen.

const SPAWN_MIN: float = 75.0
const SPAWN_MAX: float = 230.0
const DESPAWN_DIST: float = 270.0
const SPECS: Array[String] = ["kompakt", "kompakt", "limousine", "limousine", "transporter", "sport"]

var game: Node
var graph: CityGraph
var lights: TrafficLights
var max_vehicles: int = 14
var vehicles: Array[Vehicle] = []
var enabled: bool = true
var spawned_total: int = 0
var despawned_total: int = 0

var _timer: float = 0.0
var _rng: RandomNumberGenerator = DetRng.make_rng(20260923)
var _traffic_edges: Array[int] = []
var _edge_weights: Array[float] = []
var _total_len: float = 0.0


func setup(p_game: Node, g: CityGraph, l: TrafficLights) -> void:
	game = p_game
	graph = g
	lights = l
	max_vehicles = Settings.max_traffic()
	Settings.changed.connect(func() -> void: max_vehicles = Settings.max_traffic())
	for e: int in g.edge_count():
		if g.is_traffic(e):
			_traffic_edges.append(e)
			_total_len += g.edge_length(e)
			_edge_weights.append(_total_len)


func _physics_process(delta: float) -> void:
	_timer -= delta
	if _timer > 0.0:
		return
	_timer = 0.5
	var p: Node3D = _focus()
	if p == null:
		return
	# Despawn
	for i: int in range(vehicles.size() - 1, -1, -1):
		var v: Vehicle = vehicles[i]
		if not is_instance_valid(v):
			vehicles.remove_at(i)
			continue
		if v.driver == Vehicle.Driver.PLAYER:
			# vom Spieler übernommen -> nicht mehr Teil des Verkehrs
			vehicles.remove_at(i)
			continue
		var drv: LaneDriver = v.ai_controller as LaneDriver
		var d: float = v.global_position.distance_to(p.global_position)
		var abandoned: bool = v.driver == Vehicle.Driver.NONE
		if d > DESPAWN_DIST or ((drv == null or drv.wants_despawn or abandoned) and not _visible(v.global_position) and d > 35.0):
			_despawn(v)
			vehicles.remove_at(i)
	# Spawn (max. 2 pro Takt)
	if not enabled:
		return
	var spawned: int = 0
	while vehicles.size() < max_vehicles and spawned < 2:
		if not _try_spawn(p.global_position):
			break
		spawned += 1


func _focus() -> Node3D:
	var pl: Player = game.get("player") as Player
	if pl == null:
		return null
	return pl.current_vehicle if pl.is_in_vehicle() else pl


func _visible(pos: Vector3) -> bool:
	var cam: Camera3D = get_viewport().get_camera_3d()
	if cam == null:
		return false
	return cam.is_position_in_frustum(pos) and cam.global_position.distance_to(pos) < 180.0


func _try_spawn(center: Vector3) -> bool:
	for attempt: int in 6:
		var e: int = _pick_edge()
		var a: int = graph.edge_a[e]
		var b: int = graph.edge_b[e]
		if _rng.randf() < 0.5:
			var tmp: int = a
			a = b
			b = tmp
		var pa: Vector2 = graph.node_pos[a]
		var pb: Vector2 = graph.node_pos[b]
		var length: float = pa.distance_to(pb)
		if length < 25.0:
			continue
		var t: float = _rng.randf_range(0.25, 0.75)
		var dir: Vector2 = (pb - pa) / length
		var right: Vector2 = Vector2(-dir.y, dir.x)
		var p2: Vector2 = pa.lerp(pb, t) + right * LaneDriver.LANE_OFFSET
		var pos: Vector3 = Vector3(p2.x, 0.0, p2.y)
		var d: float = pos.distance_to(center)
		if d < SPAWN_MIN or d > SPAWN_MAX:
			continue
		if _visible(pos) and d < 150.0:
			continue
		var yaw: float = atan2(-dir.x, -dir.y)
		var spec_id: String = SPECS[_rng.randi() % SPECS.size()]
		var spec: VehicleSpec = VehicleSpec.get_spec(spec_id)
		if not _space_free(pos, yaw, spec):
			continue
		var v: Vehicle = game.call("spawn_vehicle", spec_id, pos, yaw, spec.colors[_rng.randi() % spec.colors.size()],
			Vehicle.Ownership.TRAFFIC, "") as Vehicle
		var drv := TrafficDriver.new(_rng.randi())
		drv.setup(graph, lights, [a, b] as Array[int])
		v.ai_controller = drv
		v.driver = Vehicle.Driver.AI
		v.add_to_group("traffic")
		v.linear_velocity = Vector3(dir.x, 0, dir.y) * 6.0
		vehicles.append(v)
		spawned_total += 1
		return true
	return false


func _pick_edge() -> int:
	var r: float = _rng.randf() * _total_len
	var lo: int = 0
	var hi: int = _edge_weights.size() - 1
	while lo < hi:
		var mid: int = (lo + hi) / 2
		if _edge_weights[mid] < r:
			lo = mid + 1
		else:
			hi = mid
	return _traffic_edges[lo]


func _space_free(pos: Vector3, yaw: float, spec: VehicleSpec) -> bool:
	var space: PhysicsDirectSpaceState3D = get_viewport().get_world_3d().direct_space_state
	var box := BoxShape3D.new()
	box.size = Vector3(spec.width + 1.0, 1.6, spec.length + 8.0)
	var q := PhysicsShapeQueryParameters3D.new()
	q.shape = box
	q.transform = Transform3D(Basis(Vector3.UP, yaw), pos + Vector3.UP * 1.1)
	q.collision_mask = Layers.WORLD | Layers.VEHICLE | Layers.PLAYER
	return space.intersect_shape(q, 1).is_empty()


func _despawn(v: Vehicle) -> void:
	despawned_total += 1
	v.queue_free()


## Entfernt KI-Fahrzeuge in einem Bereich (z. B. für Missions-Spawnpunkte).
func clear_area(pos: Vector3, radius: float) -> void:
	for i: int in range(vehicles.size() - 1, -1, -1):
		var v: Vehicle = vehicles[i]
		if is_instance_valid(v) and v.global_position.distance_to(pos) < radius and v.driver != Vehicle.Driver.PLAYER:
			_despawn(v)
			vehicles.remove_at(i)


func active_count() -> int:
	return vehicles.size()
