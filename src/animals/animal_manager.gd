class_name AnimalManager
extends Node
## Tiere in der Stadt (W6): Zoo-Gehege (bei Annäherung an den Zoo), Enten auf Gewässern, Tauben auf Plätzen,
## Spatzen und Eichhörnchen in Parks, Hunde bei Passanten, Katzen in Wohnstraßen. Obergrenze nach Qualitätsstufe
## und Einstellung „Tiere“. Lärm (Hupe, Unfall) schreckt Tiere in der Nähe auf.

const ZOO_SPAWN_DIST: float = 480.0
const ZOO_DESPAWN_DIST: float = 650.0
const HABITAT_SPAWN_DIST: float = 150.0
const HABITAT_DESPAWN_DIST: float = 240.0

var game: Node
var enabled: bool = true
var animals: Array[AnimalAgent] = []
var zoo_animals: Array[AnimalAgent] = []
var _habitats: Dictionary = {}        ## Vector2i -> Array[Dictionary]
var _habitat_animals: Dictionary = {} ## Schlüssel "i,j,k" -> Array[AnimalAgent]
var _habitat_cooldown: Dictionary = {}
var _timer: float = 0.0
var _rng := RandomNumberGenerator.new()
var _root: Node3D


func setup(p_game: Node, streamer: WorldStreamer) -> void:
	game = p_game
	_rng.seed = 7171
	_root = Node3D.new()
	_root.name = "Tiere"
	(game.get("entities") as Node3D).add_child(_root)
	streamer.sector_loaded.connect(func(ij: Vector2i, info: Dictionary) -> void: _habitats[ij] = info.get("habitats", []))
	streamer.sector_unloaded.connect(_on_unloaded)
	for ij: Vector2i in streamer.loaded:
		_habitats[ij] = streamer.loaded[ij].get("habitats", [])
	EventBus.horn.connect(func(pos: Vector3) -> void: scare_near(pos, 28.0))
	EventBus.vehicle_collision.connect(func(v: Node, dv: float, _o: Node) -> void:
		if dv > 4.0 and v is Node3D:
			scare_near((v as Node3D).global_position, 30.0))


func cap() -> int:
	return int(round([20.0, 40.0, 70.0, 100.0][Settings.level()] * Settings.animal_density))


func count() -> int:
	return animals.size() + zoo_animals.size()


func scare_near(pos: Vector3, r: float) -> void:
	for a: AnimalAgent in animals:
		if is_instance_valid(a) and a.global_position.distance_to(pos) < r:
			a.scare(pos)


func _physics_process(delta: float) -> void:
	var pl: Player = game.get("player") as Player
	if pl == null:
		return
	var threat: Node3D = pl.current_vehicle if pl.is_in_vehicle() else pl
	var tpos: Vector3 = threat.global_position
	var tspeed: float = (pl.current_vehicle as Vehicle).linear_velocity.length() if pl.is_in_vehicle() else pl.velocity.length()
	var cam: Camera3D = get_viewport().get_camera_3d()
	var cpos: Vector3 = cam.global_position if cam != null else tpos
	for i: int in range(animals.size() - 1, -1, -1):
		var a: AnimalAgent = animals[i]
		if not is_instance_valid(a):
			animals.remove_at(i)
			continue
		a.tick(delta, tpos, tspeed, a.global_position.distance_to(cpos))
		if a.gone:
			a.queue_free()
			animals.remove_at(i)
	for z: AnimalAgent in zoo_animals:
		if is_instance_valid(z):
			z.tick(delta, tpos, 0.0, z.global_position.distance_to(cpos))
	_timer -= delta
	if _timer > 0.0:
		return
	_timer = 0.7
	if not enabled or Settings.animal_density <= 0.0:
		_clear_all()
		return
	_update_zoo(tpos)
	_update_habitats(tpos)
	_update_street_animals(tpos)
	# gelegentliche Tierlaute im Zoo
	if not zoo_animals.is_empty() and _rng.randf() < 0.12:
		var z: AnimalAgent = zoo_animals[_rng.randi() % zoo_animals.size()]
		var snd: String = str(z.data.get("sound", ""))
		if snd != "" and z.global_position.distance_to(tpos) < 90.0:
			AudioManager.play_3d(snd, z.global_position, -6.0, _rng.randf_range(0.9, 1.1))


# ------------------------------------------------------------------ Zoo

func _zoo_landmark() -> Dictionary:
	var cw: CityWorld = game.call("get_city")
	if cw == null:
		return {}
	for lm: Variant in cw.graph.layout.landmarks:
		if str(lm.type) == "zoo":
			return lm
	return {}


func _update_zoo(p: Vector3) -> void:
	var lm: Dictionary = _zoo_landmark()
	if lm.is_empty():
		return
	var c: Vector2 = Vector2(float(lm.pos[0]), float(lm.pos[1]))
	var d: float = Vector2(p.x, p.z).distance_to(c)
	if zoo_animals.is_empty() and d < ZOO_SPAWN_DIST:
		_spawn_zoo(c, deg_to_rad(float(lm.get("rot", 0.0))))
	elif not zoo_animals.is_empty() and d > ZOO_DESPAWN_DIST:
		for z: AnimalAgent in zoo_animals:
			if is_instance_valid(z):
				z.queue_free()
		zoo_animals.clear()


func _spawn_zoo(c: Vector2, rot: float) -> void:
	var cw: CityWorld = game.call("get_city")
	var y: float = cw.slab_h
	var k: int = 0
	for encv: Variant in LandmarksExtra.zoo_enclosures():
		var enc: Dictionary = encv
		var lc: Array = enc.center
		var ls: Array = enc.size
		var wc: Vector2 = c + Vector2(float(lc[0]) * cos(rot) + float(lc[1]) * sin(rot), -float(lc[0]) * sin(rot) + float(lc[1]) * cos(rot))
		var n: int = maxi(1, int(round(float(enc.get("count", 2)) * minf(Settings.animal_density, 1.0))))
		for i: int in n:
			var a := AnimalAgent.new()
			a.setup(str(enc.species), 1000 + k)
			a.area_kind = "rect"
			a.area_center = wc
			a.area_half = Vector2(float(ls[0]) * 0.5 - 1.5, float(ls[1]) * 0.5 - 1.5)
			a.area_rot = rot
			a.ground_y = y
			_root.add_child(a)
			var p: Vector2 = a.random_point()
			a.global_position = Vector3(p.x, y, p.y)
			a.rotation.y = _rng.randf() * TAU
			zoo_animals.append(a)
			k += 1


# ------------------------------------------------------------------ Lebensräume (Wasser, Plätze, Parks)

func _update_habitats(p: Vector3) -> void:
	var p2: Vector2 = Vector2(p.x, p.z)
	var now: float = Time.get_ticks_msec() / 1000.0
	# entfernte Gruppen abbauen
	for key: String in _habitat_animals.keys():
		var arr: Array = _habitat_animals[key]
		var alive: Array = []
		var far: bool = true
		for a: Variant in arr:
			if is_instance_valid(a):
				alive.append(a)
				if (a as AnimalAgent).global_position.distance_to(p) < HABITAT_DESPAWN_DIST:
					far = false
		if alive.is_empty() or far:
			for a2: Variant in alive:
				animals.erase(a2)
				(a2 as Node).queue_free()
			_habitat_animals.erase(key)
			_habitat_cooldown[key] = now + (40.0 if alive.is_empty() else 5.0)
	if count() >= cap():
		return
	for ij: Vector2i in _habitats:
		var hs: Array = _habitats[ij]
		for k: int in hs.size():
			var h: Dictionary = hs[k]
			var key2: String = "%d,%d,%d" % [ij.x, ij.y, k]
			if _habitat_animals.has(key2) or float(_habitat_cooldown.get(key2, 0.0)) > now:
				continue
			var poly: PackedVector2Array = h.poly
			var cen: Vector2 = PolyUtil.centroid(poly)
			if cen.distance_to(p2) > HABITAT_SPAWN_DIST:
				continue
			var hv: float = DetRng.hash01(ij.x, ij.y, k)
			var spec: String = ""
			var n: int = 0
			match str(h.kind):
				"water":
					spec = "ente"
					n = 2 + int(hv * 4.0)
				"plaza":
					if hv < 0.75:
						spec = "taube"
						n = 5 + int(hv * 8.0)
				"park":
					spec = "spatz" if hv < 0.6 else "eichhoernchen"
					n = (3 + int(hv * 3.0)) if spec == "spatz" else 1
			if spec == "" or n <= 0:
				_habitat_animals[key2] = []
				continue
			n = maxi(1, int(round(float(n) * minf(Settings.animal_density, 1.5))))
			var group: Array = []
			for i: int in n:
				if count() >= cap():
					break
				var a := AnimalAgent.new()
				a.setup(spec, int(hv * 100000.0) + i)
				a.area_kind = "poly"
				a.area_poly = poly
				a.ground_y = float(h.y)
				_root.add_child(a)
				var pt: Vector2 = a.random_point()
				a.global_position = Vector3(pt.x, float(h.y), pt.y)
				a.rotation.y = _rng.randf() * TAU
				animals.append(a)
				group.append(a)
			_habitat_animals[key2] = group


# ------------------------------------------------------------------ Hunde und Katzen

func _update_street_animals(p: Vector3) -> void:
	var dogs: int = 0
	var cats: int = 0
	for a: AnimalAgent in animals:
		if not is_instance_valid(a):
			continue
		if a.sid == "hund":
			dogs += 1
			if a.global_position.distance_to(p) > 220.0:
				a.gone = true
		elif a.sid == "katze":
			cats += 1
			if a.global_position.distance_to(p) > 180.0:
				a.gone = true
	if count() >= cap():
		return
	# Hund zu einem Passanten
	if dogs < int(round(3.0 * Settings.animal_density)):
		var best: Node3D = null
		for n: Node in get_tree().get_nodes_in_group("pedestrians"):
			var ped: Node3D = n as Node3D
			if ped == null or ped.has_meta("dog"):
				continue
			var d: float = ped.global_position.distance_to(p)
			if d > 25.0 and d < 110.0 and _rng.randf() < 0.25:
				best = ped
				break
		if best != null:
			var dog := AnimalAgent.new()
			dog.setup("hund", _rng.randi())
			dog.state = AnimalAgent.State.FOLLOW
			dog.area_kind = "follow"
			dog.follow_target = best
			dog.ground_y = best.global_position.y
			_root.add_child(dog)
			dog.global_position = best.global_position + best.global_basis.x * 0.8
			best.set_meta("dog", true)
			animals.append(dog)
	# Katze in der Nähe (Gehweg)
	if cats < int(round(2.0 * Settings.animal_density)) and _rng.randf() < 0.3:
		var peds: PedestrianManager = game.get("peds") as PedestrianManager
		if peds != null and peds.net != null:
			var hit: Array = peds.net.random_point_near(Vector2(p.x, p.z), 35.0, 90.0, _rng)
			if not hit.is_empty():
				var q: Vector2 = peds.net.loops[hit[0]][hit[1]]
				var cat := AnimalAgent.new()
				cat.setup("katze", _rng.randi())
				cat.area_kind = "circle"
				cat.area_center = q
				cat.area_half = Vector2(12.0, 12.0)
				var cw: CityWorld = game.call("get_city")
				cat.ground_y = cw.ground_y(q) if cw != null else 0.12
				_root.add_child(cat)
				cat.global_position = Vector3(q.x, cat.ground_y, q.y)
				animals.append(cat)


func _on_unloaded(ij: Vector2i) -> void:
	_habitats.erase(ij)
	var prefix: String = "%d,%d," % [ij.x, ij.y]
	for key: String in _habitat_animals.keys():
		if key.begins_with(prefix):
			for a: Variant in _habitat_animals[key]:
				if is_instance_valid(a):
					animals.erase(a)
					(a as Node).queue_free()
			_habitat_animals.erase(key)


func _clear_all() -> void:
	for a: AnimalAgent in animals + zoo_animals:
		if is_instance_valid(a):
			a.queue_free()
	animals.clear()
	zoo_animals.clear()
	_habitat_animals.clear()
