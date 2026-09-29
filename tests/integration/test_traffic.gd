extends GameTestCase
## Straßenverkehr: Obergrenze, Stabilität, Spurtreue, Ampeln, Abstandhalten, Umfahren stehender Hindernisse,
## begrenzte Objektmenge.


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
	# Ampelkreuzung nahe der Innenstadt mit gerader Zufahrt (≥ 45 m) – quellenunabhängig gesucht
	var pick: Array = _signal_approach(g)
	assert_false(pick.is_empty(), "Ampelkreuzung mit Zufahrt gefunden")
	if pick.is_empty():
		return
	var node: int = pick[0]
	var from_node: int = pick[1]
	load_at(g.pos3(node))
	load_at(g.pos3(from_node))
	assert_true(game.lights.is_signalized(node), "Kreuzung ist ampelgeregelt")
	var e: int = g.find_edge(from_node, node)
	assert_gt(float(e), -1.0, "Zufahrtskante vorhanden")
	# Ampel für diese Zufahrt auf Rot stellen (Zeit so wählen, dass die Gruppe ~20 s rot bleibt)
	for k: int in 300:
		game.lights.time = float(k) * 0.1
		if game.lights.light_for(node, e) == TrafficLights.Light.RED and _red_for(node, e, 15.0):
			break
	assert_eq(game.lights.light_for(node, e), TrafficLights.Light.RED, "Ampel rot")
	var dir: Vector2 = (g.node_pos[node] - g.node_pos[from_node]).normalized()
	var back: float = minf(55.0, g.node_pos[node].distance_to(g.node_pos[from_node]) - 3.0)
	var start: Vector2 = g.node_pos[node] - dir * back + Vector2(-dir.y, dir.x) * g.lane_offset(e)
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


## [Kreuzungsknoten, Vorgängerknoten] der ampelgeregelten Kreuzung, die dem Schloss am nächsten liegt und eine gerade,
## befahrbare Zufahrt von mindestens 45 m hat.
func _signal_approach(g: CityGraph) -> Array:
	var best: Array = []
	var best_d: float = INF
	for n: int in g.node_count():
		if not game.lights.is_signalized(n) or g.node_pos[n].length() > 3500.0 or g.node_pos[n].length() >= best_d:
			continue
		for e: int in g.node_edges_mode(n, "traffic"):
			var o: int = g.other_node(e, n)
			if g.edge_length(e) >= 45.0 and g.can_leave(e, o) and not g.is_bridge(e):
				best = [n, o]
				best_d = g.node_pos[n].length()
				break
	return best


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
	# Gerade Strecke ohne Einmündungen (quellenunabhängig gesucht): Hindernis auf der Spur
	var chain: Array[int] = _straight_chain(g, 120.0)
	assert_gt(float(chain.size()), 1.0, "Gerade Strecke gefunden")
	if chain.size() < 2:
		return
	var a: int = chain[0]
	for n: int in chain:
		load_at(g.pos3(n))
	var dir: Vector2 = (g.node_pos[chain[chain.size() - 1]] - g.node_pos[a]).normalized()
	var right: Vector2 = Vector2(-dir.y, dir.x)
	var off: float = g.lane_offset(g.find_edge(chain[0], chain[1]))
	var obst2: Vector2 = g.node_pos[a] + dir * 80.0 + right * off
	var obstacle: Vehicle = game.spawn_vehicle("transporter", Vector3(obst2.x, 0, obst2.y), atan2(-dir.x, -dir.y))
	var start2: Vector2 = g.node_pos[a] + dir * 12.0 + right * off
	var v: Vehicle = game.spawn_vehicle("kompakt", Vector3(start2.x, 0, start2.y), atan2(-dir.x, -dir.y))
	var drv := TrafficDriver.new(9)
	drv.setup(g, game.lights, chain)
	v.ai_controller = drv
	v.driver = Vehicle.Driver.AI
	var h0: float = v.health
	# bis zum Stillstand hinter dem Hindernis (danach darf es nach einigen Sekunden vorbeifahren, siehe unten)
	var t: float = 0.0
	while t < 15.0 and not (v.linear_velocity.length() < 1.0 and v.global_position.distance_to(obstacle.global_position) < 16.0):
		await wait_seconds(0.25)
		t += 0.25
	var gap: float = v.global_position.distance_to(obstacle.global_position)
	assert_lt(v.linear_velocity.length(), 1.0, "Fahrzeug hält hinter dem Hindernis")
	assert_gt(gap, 5.5, "Sicherheitsabstand (%.1f m)" % gap)
	assert_near(v.health, h0, 0.1, "Kein Auffahrunfall")


## W11: Stehendes Hindernis (abgestelltes Fahrzeug) auf einer Straße mit Gegenverkehrsspur wird links umfahren.
func test_bypasses_parked_obstacle() -> void:
	await start_city_game(false)
	var g: CityGraph = city().graph
	var chain: Array[int] = _straight_chain(g, 190.0)
	assert_gt(float(chain.size()), 2.0, "Gerade Zweirichtungsstrecke ≥ 190 m gefunden")
	if chain.size() < 3:
		return
	var a: int = chain[0]
	var b: int = chain[1]
	for n: int in chain:
		load_at(g.pos3(n))
	var dir: Vector2 = (g.node_pos[chain[chain.size() - 1]] - g.node_pos[a]).normalized()
	var right: Vector2 = Vector2(-dir.y, dir.x)
	var off: float = g.lane_offset(g.find_edge(a, b))
	var obst2: Vector2 = g.node_pos[a] + dir * 90.0 + right * off
	var obstacle: Vehicle = game.spawn_vehicle("transporter", Vector3(obst2.x, 0, obst2.y), atan2(-dir.x, -dir.y))
	var start2: Vector2 = g.node_pos[a] + dir * 30.0 + right * off
	var v: Vehicle = game.spawn_vehicle("kompakt", Vector3(start2.x, 0, start2.y), atan2(-dir.x, -dir.y))
	var drv := TrafficDriver.new(9)
	drv.setup(g, game.lights, chain)
	v.ai_controller = drv
	v.driver = Vehicle.Driver.AI
	var h0: float = v.health
	var o0: Vector3 = obstacle.global_position
	var passed: bool = false
	var t: float = 0.0
	while t < 40.0 and not passed:
		await wait_seconds(0.5)
		t += 0.5
		var along: float = Vector2(v.global_position.x, v.global_position.z).dot(dir) - obst2.dot(dir)
		passed = along > 12.0
	assert_true(passed, "Hindernis umfahren (%.0f s)" % t)
	assert_near(v.health, h0, 0.1, "Ohne Zusammenstoß")
	assert_lt(obstacle.global_position.distance_to(o0), 0.5, "Hindernis nicht verschoben")
	await wait_seconds(4.0)
	var lat: float = (Vector2(v.global_position.x, v.global_position.z) - g.node_pos[a]).dot(right)
	assert_gt(lat, 0.0, "Zurück auf der rechten Spur (%.1f m)" % lat)


## Knotenfolge einer geraden, zweispurig befahrbaren Strecke ohne Einmündungen (Knoten mit Grad 2), nahe der Innenstadt.
func _straight_chain(g: CityGraph, min_len: float) -> Array[int]:
	var best: Array[int] = []
	var best_d: float = INF
	for e: int in g.edge_a.size():
		if not g.is_traffic(e) or g.is_oneway(e) or g.edge_width(e) < 8.0 or g.is_bridge(e):
			continue
		var a: int = g.edge_a[e]
		var chain: Array[int] = [a, g.edge_b[e]]
		var total: float = g.edge_length(e)
		var d0: Vector2 = (g.node_pos[chain[1]] - g.node_pos[a]).normalized()
		while total < min_len:
			var cur: int = chain[chain.size() - 1]
			if g.degree(cur, "drive") != 2:
				break
			var nxt: int = -1
			for e2: int in g.node_edges[cur]:
				var o: int = g.other_node(e2, cur)
				if o != chain[chain.size() - 2] and g.is_traffic(e2) and not g.is_oneway(e2) and g.edge_width(e2) >= 8.0 \
						and (g.node_pos[o] - g.node_pos[cur]).normalized().dot(d0) > 0.995:
					nxt = o
					total += g.edge_length(e2)
			if nxt < 0:
				break
			chain.append(nxt)
		if total >= min_len and g.degree(a, "drive") <= 2:
			var m: Vector2 = g.node_pos[a]
			if m.length() < best_d:
				best_d = m.length()
				best = chain
	return best


func test_object_count_bounded_after_teleports() -> void:
	await start_city_game(true)
	game.police.patrol_enabled = false
	await wait_seconds(10.0)
	var spots: Array[Vector3] = [Vector3(-1900, 0.2, 300), Vector3(1900, 0.2, 200), Vector3(-18, 0.2, 505), Vector3(5190, 0.2, 1600),
		Vector3(-180, 0.2, 2150), Vector3(-18, 0.2, 505)]
	for s: Vector3 in spots:
		teleport_player(s)
		await wait_seconds(8.0)
	var total: int = get_tree().get_nodes_in_group("vehicles").size()
	var parked: int = get_tree().get_nodes_in_group("parked_cars").size()
	assert_lt(float(game.traffic.active_count()), float(game.traffic.max_vehicles) + 0.5, "Verkehr begrenzt")
	assert_lt(float(parked), float(ParkedCarManager.MAX_TOTAL) + 0.5, "Geparkte Autos begrenzt (%d)" % parked)
	assert_lt(float(total), float(ParkedCarManager.MAX_TOTAL + game.traffic.max_vehicles + 8), "Gesamtzahl Fahrzeuge begrenzt (%d)" % total)
	assert_lt(float(city().streamer.loaded.size()), 26.0, "Geladene Sektoren begrenzt (%d)" % city().streamer.loaded.size())
	assert_lt(float(game.peds.active_count()), float(game.peds.max_peds) + 0.5, "Passanten begrenzt")
