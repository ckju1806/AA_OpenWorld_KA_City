extends GameTestCase
## Straßenverkehr: Obergrenze, Stabilität, Spurtreue, Ampeln, Abstandhalten, begrenzte Objektmenge.


func after_each() -> void:
	await stop_game()


func _near_road_ratio() -> float:
	var g: CityGraph = city().graph
	var ok: int = 0
	var n: int = 0
	for v: Vehicle in game.traffic.vehicles:
		if not is_instance_valid(v):
			continue
		n += 1
		var ne: Dictionary = g.nearest_edge_point(Vector2(v.global_position.x, v.global_position.z), "drive")
		if float(ne.dist) < g.edge_width(int(ne.edge)) * 0.5 + 2.0:
			ok += 1
	return float(ok) / float(maxi(n, 1))


func test_traffic_spawns_and_drives() -> void:
	await start_city_game(true)
	game.police.patrol_enabled = false
	var ok: bool = await wait_until(func() -> bool: return game.traffic.active_count() >= game.traffic.max_vehicles, 20.0)
	assert_true(ok, "Verkehr erreicht Sollanzahl (%d/%d)" % [game.traffic.active_count(), game.traffic.max_vehicles])
	await wait_seconds(40.0)
	assert_lt(float(game.traffic.active_count()), float(game.traffic.max_vehicles) + 0.5, "Obergrenze eingehalten")
	var flipped: int = 0
	var moving: int = 0
	for v: Vehicle in game.traffic.vehicles:
		if is_instance_valid(v):
			if v.is_flipped():
				flipped += 1
			if v.linear_velocity.length() > 1.0:
				moving += 1
	assert_eq(flipped, 0, "Kein Verkehrsfahrzeug überschlagen")
	assert_gt(float(moving), float(game.traffic.active_count()) * 0.3, "Verkehr ist in Bewegung (%d fahren)" % moving)
	assert_gt(_near_road_ratio(), 0.9, "Mind. 90 % der Fahrzeuge auf Fahrbahnen")
	print("        Verkehr: %d aktiv, %d gesamt erzeugt, %d entfernt" % [game.traffic.active_count(), game.traffic.spawned_total, game.traffic.despawned_total])


func test_stops_at_red_light() -> void:
	await start_city_game(false)
	var g: CityGraph = city().graph
	# Signalisierte Kreuzung Karlstraße/Kanzleistraße suchen
	var node: int = g.nearest_node(Vector2(-470, 460), "drive")
	assert_true(game.lights.is_signalized(node), "Kreuzung ist ampelgeregelt")
	var from_node: int = g.nearest_node(Vector2(-470, 330), "drive")
	var e: int = g.find_edge(from_node, node)
	assert_gt(float(e), -1.0, "Zufahrtskante vorhanden")
	# Ampel für diese Zufahrt auf Rot stellen (Zeit so wählen, dass die Gruppe ~20 s rot bleibt)
	for k: int in 300:
		game.lights.time = float(k) * 0.1
		if game.lights.light_for(node, e) == TrafficLights.Light.RED and _red_for(node, e, 15.0):
			break
	assert_eq(game.lights.light_for(node, e), TrafficLights.Light.RED, "Ampel rot")
	var dir: Vector2 = (g.node_pos[node] - g.node_pos[from_node]).normalized()
	var start: Vector2 = g.node_pos[node] - dir * 70.0 + Vector2(-dir.y, dir.x) * LaneDriver.LANE_OFFSET
	var v: Vehicle = game.spawn_vehicle("kompakt", Vector3(start.x, 0, start.y), atan2(-dir.x, -dir.y))
	var drv := TrafficDriver.new(5)
	drv.setup(g, game.lights, [from_node, node] as Array[int])
	v.ai_controller = drv
	v.driver = Vehicle.Driver.AI
	await wait_seconds(9.0)
	var dist: float = Vector2(v.global_position.x, v.global_position.z).distance_to(g.node_pos[node])
	assert_lt(v.linear_velocity.length(), 1.0, "Fahrzeug steht an der roten Ampel")
	assert_gt(dist, g.node_radius(node, "all") + 0.5, "Fahrzeug hält vor der Kreuzung (%.1f m)" % dist)
	assert_lt(dist, g.node_radius(node, "all") + 12.0, "Fahrzeug ist bis zur Haltelinie vorgefahren")


func _red_for(node: int, e: int, seconds: float) -> bool:
	var t0: float = game.lights.time
	var ok: bool = true
	var t: float = 0.0
	while t < seconds:
		game.lights.time = t0 + t
		if game.lights.light_for(node, e) != TrafficLights.Light.RED:
			ok = false
			break
		t += 0.5
	game.lights.time = t0
	return ok


func test_keeps_distance_to_obstacle() -> void:
	await start_city_game(false)
	var g: CityGraph = city().graph
	# Gerade Strecke auf der Kriegsstraße (ohne Ampel dazwischen): Hindernis auf der Spur
	var a: int = g.nearest_node(Vector2(-330, 640), "drive")
	var b: int = g.nearest_node(Vector2(-220.5, 640), "drive")
	var dir: Vector2 = (g.node_pos[b] - g.node_pos[a]).normalized()
	var right: Vector2 = Vector2(-dir.y, dir.x)
	var obst2: Vector2 = g.node_pos[a] + dir * 80.0 + right * LaneDriver.LANE_OFFSET
	var obstacle: Vehicle = game.spawn_vehicle("transporter", Vector3(obst2.x, 0, obst2.y), atan2(-dir.x, -dir.y))
	var start2: Vector2 = g.node_pos[a] + dir * 12.0 + right * LaneDriver.LANE_OFFSET
	var v: Vehicle = game.spawn_vehicle("kompakt", Vector3(start2.x, 0, start2.y), atan2(-dir.x, -dir.y))
	var drv := TrafficDriver.new(9)
	drv.setup(g, game.lights, [a, b] as Array[int])
	v.ai_controller = drv
	v.driver = Vehicle.Driver.AI
	var h0: float = v.health
	await wait_seconds(12.0)
	var gap: float = v.global_position.distance_to(obstacle.global_position)
	assert_lt(v.linear_velocity.length(), 1.0, "Fahrzeug hält hinter dem Hindernis")
	assert_gt(gap, 5.5, "Sicherheitsabstand (%.1f m)" % gap)
	assert_near(v.health, h0, 0.1, "Kein Auffahrunfall")


func test_object_count_bounded_after_teleports() -> void:
	await start_city_game(true)
	game.police.patrol_enabled = false
	await wait_seconds(10.0)
	var spots: Array[Vector3] = [Vector3(-500, 0.2, 100), Vector3(400, 0.2, 600), Vector3(0, 0.2, 470), Vector3(-300, 0.2, 640)]
	for s: Vector3 in spots:
		game.player.global_position = s
		await wait_seconds(8.0)
	var total: int = get_tree().get_nodes_in_group("vehicles").size()
	var parked: int = city().graph.layout.get("parked_vehicles", []).size()
	assert_lt(float(game.traffic.active_count()), float(game.traffic.max_vehicles) + 0.5, "Verkehr begrenzt")
	assert_lt(float(total), float(parked + game.traffic.max_vehicles + 2), "Gesamtzahl Fahrzeuge begrenzt (%d)" % total)
	assert_lt(float(game.peds.active_count()), float(game.peds.max_peds) + 0.5, "Passanten begrenzt")
