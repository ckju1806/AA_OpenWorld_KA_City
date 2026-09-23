class_name PedestrianManager
extends Node
## Verwaltet Passanten als Pool (keine wachsende Objektmenge): Spawn außerhalb der Sicht,
## Wiederverwendung weit entfernter Figuren, Reaktionen auf Hupe/Unfälle/nahende Fahrzeuge, Zeugen.

const SPAWN_MIN: float = 35.0
const SPAWN_MAX: float = 120.0
const RECYCLE_DIST: float = 150.0

var game: Node
var net: SidewalkNetwork
var peds: Array[Pedestrian] = []
var max_peds: int = 26
var enabled: bool = true
var _rng: RandomNumberGenerator = DetRng.make_rng(1989)
var _timer: float = 0.0
var _danger_t: float = 0.0
var _cam_pos: Vector3 = Vector3.ZERO
var _seed: int = 100


func setup(p_game: Node, city: CityWorld) -> void:
	game = p_game
	net = SidewalkNetwork.new()
	net.build(city.graph, city.blocks, city.slab_h)
	max_peds = Settings.max_pedestrians()
	Settings.changed.connect(func() -> void: max_peds = Settings.max_pedestrians())
	EventBus.horn.connect(_on_horn)
	EventBus.vehicle_collision.connect(_on_collision)


func camera_distance(pos: Vector3) -> float:
	return _cam_pos.distance_to(pos)


func _physics_process(delta: float) -> void:
	var cam: Camera3D = get_viewport().get_camera_3d()
	if cam != null:
		_cam_pos = cam.global_position
	_danger_t -= delta
	if _danger_t <= 0.0:
		_danger_t = 0.25
		_danger_scan()
	_timer -= delta
	if _timer > 0.0:
		return
	_timer = 0.6
	var focus: Vector3 = _focus_pos()
	var budget: int = 3
	for p: Pedestrian in peds:
		if p.global_position.distance_to(focus) > RECYCLE_DIST and not _visible(p.global_position) and budget > 0:
			if _place(p, focus):
				budget -= 1
	while enabled and peds.size() < max_peds and budget > 0:
		_seed += 1
		var p2 := Pedestrian.new()
		p2.name = "Passant_%d" % _seed
		add_child(p2)
		p2.setup(self, net, _seed * 7919)
		if not _place(p2, focus):
			p2.queue_free()
			break
		peds.append(p2)
		budget -= 1
	# Überzählige (z. B. nach Qualitätsänderung) entfernen
	while peds.size() > max_peds:
		var last: Pedestrian = peds.pop_back()
		last.queue_free()


func _focus_pos() -> Vector3:
	var pl: Player = game.get("player") as Player
	if pl == null:
		return Vector3.ZERO
	return pl.current_vehicle.global_position if pl.is_in_vehicle() else pl.global_position


func _visible(pos: Vector3) -> bool:
	var cam: Camera3D = get_viewport().get_camera_3d()
	return cam != null and cam.is_position_in_frustum(pos + Vector3.UP) and cam.global_position.distance_to(pos) < 70.0


func _place(p: Pedestrian, focus: Vector3) -> bool:
	for attempt: int in 10:
		if _rng.randf() < 0.35 and not net.wander_areas.is_empty():
			var ai: int = _rng.randi() % net.wander_areas.size()
			var c: Vector2 = net.wander_areas[ai].center
			var d: float = Vector2(focus.x, focus.z).distance_to(c)
			if d > SPAWN_MAX:
				continue
			p.place_in_area(ai)
		else:
			if net.loops.is_empty():
				return false
			var li: int = _rng.randi() % net.loops.size()
			var lp: PackedVector2Array = net.loops[li]
			var vi: int = _rng.randi() % lp.size()
			var pos: Vector2 = lp[vi]
			var dist: float = Vector2(focus.x, focus.z).distance_to(pos)
			if dist < SPAWN_MIN or dist > SPAWN_MAX:
				continue
			p.place_on_loop(li, vi, _rng.randf())
		var gp: Vector3 = p.global_position
		if gp.distance_to(focus) < SPAWN_MIN * 0.6 or (_visible(gp) and gp.distance_to(focus) < 55.0):
			continue
		return true
	return false


## Fußgänger weichen schnell nahenden Fahrzeugen aus.
func _danger_scan() -> void:
	var vehicles: Array[Node] = get_tree().get_nodes_in_group("vehicles")
	for vn: Node in vehicles:
		var v: Vehicle = vn as Vehicle
		var vel: Vector3 = v.linear_velocity
		var spd: float = vel.length()
		if spd < 4.0:
			continue
		var vp: Vector3 = v.global_position
		var dir: Vector3 = vel / spd
		for p: Pedestrian in peds:
			var rel: Vector3 = p.global_position - vp
			if rel.length_squared() > 196.0:
				continue
			var ahead: float = rel.dot(dir)
			if ahead < 0.0 or ahead > spd * 1.3:
				continue
			var lateral: float = (rel - dir * ahead).length()
			if lateral < 2.2:
				p.dodge(vp, vel)


func _on_horn(pos: Vector3) -> void:
	for p: Pedestrian in peds:
		if p.global_position.distance_to(pos) < 11.0:
			p.scare(pos, false)


func _on_collision(v: Node, impulse: float, _other: Node) -> void:
	if impulse < 6.0 or not v is Node3D:
		return
	var pos: Vector3 = (v as Node3D).global_position
	for p: Pedestrian in peds:
		if p.global_position.distance_to(pos) < 18.0:
			p.scare(pos, true)


func on_pedestrian_hit(ped: Pedestrian, v: Vehicle) -> void:
	for p: Pedestrian in peds:
		if p != ped and p.global_position.distance_to(ped.global_position) < 20.0:
			p.scare(ped.global_position, true)
	if v.driver == Vehicle.Driver.PLAYER:
		var witnessed: bool = count_witnesses(ped.global_position, 35.0, ped) > 0
		if game.has_method("police_can_see"):
			witnessed = witnessed or bool(game.call("police_can_see", ped.global_position))
		EventBus.crime_reported.emit("fussgaenger", ped.global_position, witnessed)


func vehicle_near(pos: Vector3, radius: float, min_speed: float) -> bool:
	for vn: Node in get_tree().get_nodes_in_group("vehicles"):
		var v: Vehicle = vn as Vehicle
		if v.global_position.distance_to(pos) < radius and v.linear_velocity.length() > min_speed:
			return true
	return false


func count_witnesses(pos: Vector3, radius: float, exclude: Node = null) -> int:
	var n: int = 0
	for p: Pedestrian in peds:
		if p != exclude and not p.is_down() and p.global_position.distance_to(pos) < radius:
			n += 1
	return n


## Opfer eines Fahrzeugraubs: flüchtender Passant an der Fahrertür.
func spawn_victim(pos: Vector3, threat: Vector3) -> void:
	var p: Pedestrian = null
	if peds.size() >= max_peds and not peds.is_empty():
		# weitest entfernten wiederverwenden
		var best_d: float = -1.0
		for q: Pedestrian in peds:
			var d: float = q.global_position.distance_to(pos)
			if d > best_d:
				best_d = d
				p = q
	else:
		_seed += 1
		p = Pedestrian.new()
		add_child(p)
		p.setup(self, net, _seed * 7919)
		peds.append(p)
	p.loop_i = -1
	p.wander_area = -1
	p.global_position = pos
	p.reset_physics_interpolation()
	p.scare(threat, true)


func active_count() -> int:
	return peds.size()
