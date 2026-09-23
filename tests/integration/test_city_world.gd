extends TestCase
## Stadtwelt: Aufbau, gültige Spawnpunkte/POIs, freie Fahrbahnen, Fahrzeuge, Landmarken, Bergung.

var game: Game


func before_each() -> void:
	game = (load("res://scenes/game.tscn") as PackedScene).instantiate() as Game
	game.world_mode = "city"
	add_child(game)
	await wait_physics(20)


func after_each() -> void:
	if is_instance_valid(game):
		game.queue_free()
	await wait_physics(2)


func _space() -> PhysicsDirectSpaceState3D:
	return game.get_world_3d().direct_space_state


func _capsule_free(pos: Vector3) -> bool:
	var cap := CapsuleShape3D.new()
	cap.radius = 0.34
	cap.height = 1.75
	var q := PhysicsShapeQueryParameters3D.new()
	q.shape = cap
	q.transform = Transform3D(Basis.IDENTITY, pos + Vector3.UP * 0.98)
	q.collision_mask = Layers.WORLD
	return _space().intersect_shape(q, 1).is_empty()


func test_city_builds_and_player_spawns() -> void:
	var cw: CityWorld = game.get_city()
	assert_true(cw != null, "Stadtwelt vorhanden")
	assert_lt(float(cw.build_ms), 15000.0, "Aufbauzeit < 15 s (headless)")
	await wait_seconds(1.5)
	assert_true(game.player.is_on_floor(), "Spieler steht")
	assert_near(game.player.global_position.y, cw.slab_h, 0.12, "Spieler auf Platzniveau")


func test_pois_on_free_walkable_ground() -> void:
	var cw: CityWorld = game.get_city()
	for pv: Variant in cw.graph.layout.get("pois", []):
		var p: Dictionary = pv
		var kind: String = str(p.get("kind", ""))
		var pos: Vector3 = cw.poi_position(str(p.id))
		var g2: Vector2 = Vector2(pos.x, pos.z)
		if kind == "fahrziel":
			var ne: Dictionary = cw.graph.nearest_edge_point(g2, "drive")
			var ok_road: bool = float(ne.dist) < cw.graph.edge_width(int(ne.edge)) * 0.5 + 12.0
			assert_true(ok_road, "Fahrziel %s nahe einer befahrbaren Straße" % p.id)
			assert_true(_capsule_free(pos), "Fahrziel %s frei von Hindernissen" % p.id)
		elif kind == "hofziel":
			assert_true(_capsule_free(pos), "Hofziel %s frei" % p.id)
			var gp: Vector2 = Vector2(float(p.gate[0]), float(p.gate[1]))
			var rq := PhysicsRayQueryParameters3D.create(Vector3(gp.x, 1.0, gp.y), Vector3(pos.x, 1.0, pos.z), Layers.WORLD)
			assert_true(_space().intersect_ray(rq).is_empty(), "Freie Zufahrt zum Hofziel %s" % p.id)
		elif kind == "fahrzeug":
			var box := BoxShape3D.new()
			box.size = Vector3(2.4, 1.6, 5.8)
			var q := PhysicsShapeQueryParameters3D.new()
			q.shape = box
			q.transform = Transform3D(Basis(Vector3.UP, deg_to_rad(float(p.get("yaw", 0.0)))), pos + Vector3.UP * 1.2)
			q.collision_mask = Layers.WORLD
			assert_true(_space().intersect_shape(q, 1).is_empty(), "Fahrzeug-POI %s hat Platz" % p.id)
		else:
			assert_true(_capsule_free(pos), "POI %s frei begehbar (%s)" % [p.id, str(pos)])
		assert_lt(absf(pos.y - cw.slab_h * 0.5), 0.2, "POI %s auf Boden-/Gehwegniveau" % p.id)


func test_drivable_roads_free_of_buildings() -> void:
	var cw: CityWorld = game.get_city()
	var g: CityGraph = cw.graph
	var box := BoxShape3D.new()
	box.size = Vector3(1.6, 1.4, 1.6)
	var blocked: int = 0
	var checked: int = 0
	for e: int in g.edge_count():
		if not g.is_drivable(e):
			continue
		var a: Vector2 = g.node_pos[g.edge_a[e]]
		var b: Vector2 = g.node_pos[g.edge_b[e]]
		var length: float = a.distance_to(b)
		var dir: Vector2 = (b - a) / maxf(length, 0.01)
		var perp: Vector2 = Vector2(-dir.y, dir.x)
		var t: float = 3.0
		while t < length - 3.0:
			for lane: float in [-2.6, 2.6]:
				var p: Vector2 = a + dir * t + perp * lane
				var q := PhysicsShapeQueryParameters3D.new()
				q.shape = box
				q.transform = Transform3D(Basis.IDENTITY, Vector3(p.x, 1.0, p.y))
				q.collision_mask = Layers.WORLD
				checked += 1
				if not _space().intersect_shape(q, 1).is_empty():
					blocked += 1
					if blocked <= 5:
						fail("Fahrspur blockiert bei %s (%s)" % [str(p), str(g.street_of(e).name)])
			t += 6.0
	print("        Fahrspurproben: %d, blockiert: %d" % [checked, blocked])
	assert_eq(blocked, 0, "Blockierte Fahrspurproben")


func test_parked_vehicles_stable() -> void:
	await wait_seconds(3.0)
	var count: int = 0
	for v: Node in get_tree().get_nodes_in_group("vehicles"):
		var veh: Vehicle = v as Vehicle
		count += 1
		assert_false(veh.is_flipped(), "%s aufrecht" % veh.name)
		assert_lt(veh.linear_velocity.length(), 0.4, "%s steht still" % veh.name)
		assert_lt(veh.global_position.y, 0.6, "%s nicht auf Hindernis gestapelt" % veh.name)
	assert_gt(float(count), 8.0, "Geparkte Fahrzeuge vorhanden")


func test_landmarks_present() -> void:
	var lm: Node = game.get_city().get_node_or_null("Landmarken")
	assert_true(lm != null, "Landmarken-Knoten")
	for id: String in ["schloss", "pyramide", "rathaus", "stadtkirche", "saeule"]:
		assert_true(lm.get_node_or_null(id) != null, "Landmarke vorhanden: " + id)
	# Schlossturm ist hoch und kollidierbar
	var q := PhysicsRayQueryParameters3D.create(Vector3(0, 80, -3), Vector3(0, 0, -3), Layers.WORLD)
	var hit: Dictionary = _space().intersect_ray(q)
	assert_false(hit.is_empty(), "Schlossturm getroffen")
	if not hit.is_empty():
		assert_gt((hit.position as Vector3).y, 40.0, "Schlossturm-Höhe")


func test_recovery_point_on_road() -> void:
	var cw: CityWorld = game.get_city()
	var spec: VehicleSpec = VehicleSpec.get_spec("kompakt")
	var res: Dictionary = cw.find_recovery_point(Vector3(-300, 0, 470), spec)
	assert_true(res.ok, "Bergungspunkt gefunden")
	var p: Vector3 = res.position
	var ne: Dictionary = cw.graph.nearest_edge_point(Vector2(p.x, p.z), "drive")
	assert_lt(float(ne.dist), 4.0, "Bergungspunkt auf Fahrspur")
	var far: Dictionary = cw.find_recovery_point(Vector3(0, 0, -300), spec)
	assert_false(far.ok, "Kein Bergungspunkt mitten im Schlossgarten")
